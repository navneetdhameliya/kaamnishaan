"""Fails if shared/api/openapi.yaml is not valid OpenAPI 3.1 or has dangling $refs.
Usage: python shared/api/validate.py   (needs: pip install pyyaml openapi-spec-validator)
"""

import re
import sys
from pathlib import Path

import yaml
from openapi_spec_validator import validate

path = Path(__file__).with_name("openapi.yaml")
text = path.read_text(encoding="utf-8")
spec = yaml.safe_load(text)
validate(spec)
missing = sorted(
    {f"{a}/{b}" for a, b in re.findall(r"#/components/(\w+)/(\w+)", text) if b not in spec["components"].get(a, {})}
)
if missing:
    sys.exit("Unresolved $refs: " + ", ".join(missing))
ops = sum(1 for p in spec["paths"].values() for m in p if m in {"get", "post", "put", "patch", "delete"})
print(f"OpenAPI OK: {len(spec['paths'])} paths, {ops} operations, {len(spec['components']['schemas'])} schemas")
