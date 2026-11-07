"""File storage behind one small interface.

- `r2`: Cloudflare R2 (S3-compatible). The app uploads straight to R2 with a presigned PUT URL;
  every link we hand out is a presigned GET that expires (default 15 minutes).
- `local`: a folder on disk, for your computer and the tests. The same flow works through two
  local-only endpoints (/api/v1/files/...) that check a signed, expiring token.

Tables only ever store the object key.
"""

import asyncio
import hashlib
from dataclasses import dataclass
from datetime import timedelta
from functools import lru_cache
from pathlib import Path

from app.core.config import get_settings
from app.core.security import create_link_token


@dataclass
class Presigned:
    url: str
    method: str
    headers: dict[str, str]


@dataclass
class StoredObject:
    size: int
    content_type: str | None


class Storage:
    async def presign_put(self, key: str, content_type: str, max_bytes: int) -> Presigned: ...
    def presign_get(self, key: str, filename: str | None = None) -> str: ...
    async def head(self, key: str) -> StoredObject | None: ...
    async def read(self, key: str) -> bytes: ...
    async def write(self, key: str, data: bytes, content_type: str) -> None: ...
    async def delete(self, key: str) -> None: ...


def _ttl() -> timedelta:
    return timedelta(seconds=get_settings().storage_signed_url_ttl_seconds)


class LocalStorage(Storage):
    def __init__(self, root: str):
        self.root = Path(root).resolve()

    def path(self, key: str) -> Path:
        p = (self.root / key).resolve()
        if self.root not in p.parents:  # never allow ../ tricks in a key
            raise ValueError("bad storage key")
        return p

    async def presign_put(self, key: str, content_type: str, max_bytes: int) -> Presigned:
        token = create_link_token("file_put", key, _ttl(), fingerprint=f"{content_type}|{max_bytes}")
        return Presigned(
            url=f"{get_settings().api_url}/api/v1/files/upload/{token}",
            method="PUT",
            headers={"Content-Type": content_type},
        )

    def presign_get(self, key: str, filename: str | None = None) -> str:
        token = create_link_token("file_get", key, _ttl(), fingerprint=filename or "")
        return f"{get_settings().api_url}/api/v1/files/{token}"

    async def head(self, key: str) -> StoredObject | None:
        p = self.path(key)
        if not p.exists():
            return None
        ct = p.with_suffix(p.suffix + ".type")
        return StoredObject(size=p.stat().st_size, content_type=ct.read_text() if ct.exists() else None)

    async def read(self, key: str) -> bytes:
        return await asyncio.to_thread(self.path(key).read_bytes)

    async def write(self, key: str, data: bytes, content_type: str) -> None:
        def _w() -> None:
            p = self.path(key)
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(data)
            p.with_suffix(p.suffix + ".type").write_text(content_type)

        await asyncio.to_thread(_w)

    async def delete(self, key: str) -> None:
        for p in (self.path(key), self.path(key + ".type")):
            p.unlink(missing_ok=True)


class R2Storage(Storage):
    def __init__(self) -> None:
        import boto3
        from botocore.config import Config

        s = get_settings()
        self.bucket = s.storage_bucket
        self.client = boto3.client(
            "s3",
            endpoint_url=s.storage_endpoint,
            aws_access_key_id=s.storage_access_key.get_secret_value(),
            aws_secret_access_key=s.storage_secret_key.get_secret_value(),
            region_name="auto",
            config=Config(signature_version="s3v4", retries={"max_attempts": 3}),
        )

    async def presign_put(self, key: str, content_type: str, max_bytes: int) -> Presigned:
        # S3 presigned PUT can't cap size; the confirm call checks the real size and rejects big files.
        url = self.client.generate_presigned_url(
            "put_object",
            Params={"Bucket": self.bucket, "Key": key, "ContentType": content_type},
            ExpiresIn=int(_ttl().total_seconds()),
        )
        return Presigned(url=url, method="PUT", headers={"Content-Type": content_type})

    def presign_get(self, key: str, filename: str | None = None) -> str:
        params = {"Bucket": self.bucket, "Key": key}
        if filename:
            params["ResponseContentDisposition"] = f'inline; filename="{filename}"'
        return self.client.generate_presigned_url(
            "get_object", Params=params, ExpiresIn=int(_ttl().total_seconds())
        )

    async def head(self, key: str) -> StoredObject | None:
        from botocore.exceptions import ClientError

        try:
            r = await asyncio.to_thread(self.client.head_object, Bucket=self.bucket, Key=key)
        except ClientError as e:
            if e.response.get("Error", {}).get("Code") in ("404", "NoSuchKey", "NotFound"):
                return None
            raise
        return StoredObject(size=r["ContentLength"], content_type=r.get("ContentType"))

    async def read(self, key: str) -> bytes:
        r = await asyncio.to_thread(self.client.get_object, Bucket=self.bucket, Key=key)
        return await asyncio.to_thread(r["Body"].read)

    async def write(self, key: str, data: bytes, content_type: str) -> None:
        await asyncio.to_thread(
            self.client.put_object, Bucket=self.bucket, Key=key, Body=data, ContentType=content_type
        )

    async def delete(self, key: str) -> None:
        await asyncio.to_thread(self.client.delete_object, Bucket=self.bucket, Key=key)


@lru_cache
def get_storage() -> Storage:
    s = get_settings()
    return R2Storage() if s.storage_provider == "r2" else LocalStorage(s.storage_local_dir)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()
