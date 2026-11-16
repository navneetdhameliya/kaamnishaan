"""AI calls (OpenAI, backend only): voice transcription and short translations.

`get_ai()` returns None when no key is set; callers then leave work waiting (voice notes stay
"uploaded", checklist translations stay "missing") instead of failing. Tests swap in a fake.
"""

import json
import math
from dataclasses import dataclass

import httpx

from app.core.config import get_settings

LANGUAGE_NAMES = {"en": "English", "hi": "Hindi", "gu": "Gujarati", "es": "Spanish", "fr": "French"}
# Whisper names languages in English words
WHISPER_CODES = {
    "english": "en",
    "hindi": "hi",
    "gujarati": "gu",
    "spanish": "es",
    "french": "fr",
    "marathi": "mr",
    "tamil": "ta",
    "telugu": "te",
    "bengali": "bn",
    "urdu": "ur",
    "punjabi": "pa",
}


@dataclass
class Transcript:
    text: str
    language: str | None
    confidence: float | None


class AIProvider:
    async def transcribe(
        self, data: bytes, filename: str, content_type: str, language_hint: str | None
    ) -> Transcript: ...

    async def translate(self, texts: list[str], target: str, source: str | None = None) -> list[str]: ...


class OpenAIProvider(AIProvider):
    base = "https://api.openai.com/v1"

    def __init__(self, key: str):
        self.headers = {"Authorization": f"Bearer {key}"}

    async def transcribe(self, data, filename, content_type, language_hint):
        s = get_settings()
        form = {"model": s.openai_transcribe_model, "response_format": "verbose_json"}
        if language_hint:
            form["language"] = language_hint
        async with httpx.AsyncClient(timeout=120) as c:
            r = await c.post(
                f"{self.base}/audio/transcriptions",
                headers=self.headers,
                data=form,
                files={"file": (filename, data, content_type)},
            )
            r.raise_for_status()
            body = r.json()
        segs = body.get("segments") or []
        conf = None
        if segs:
            conf = sum(math.exp(sg.get("avg_logprob", -1.0)) for sg in segs) / len(segs)
        lang = body.get("language")
        return Transcript(
            text=(body.get("text") or "").strip(),
            language=WHISPER_CODES.get(str(lang).lower(), lang) if lang else language_hint,
            confidence=round(conf, 3) if conf is not None else None,
        )

    async def translate(self, texts, target, source=None):
        if not texts:
            return []
        s = get_settings()
        prompt = (
            f"Translate each item into {LANGUAGE_NAMES.get(target, target)} "
            "for HVAC field technicians and their customers. "
            "Keep it short and plain, keep numbers and units, do not add anything. "
            'Answer as JSON: {"items": [...]} in the same order.'
        )
        async with httpx.AsyncClient(timeout=60) as c:
            r = await c.post(
                f"{self.base}/chat/completions",
                headers=self.headers,
                json={
                    "model": s.openai_text_model,
                    "temperature": 0,
                    "response_format": {"type": "json_object"},
                    "messages": [
                        {"role": "system", "content": prompt},
                        {"role": "user", "content": json.dumps({"items": texts}, ensure_ascii=False)},
                    ],
                },
            )
            r.raise_for_status()
        items = json.loads(r.json()["choices"][0]["message"]["content"]).get("items", [])
        if len(items) != len(texts):
            raise ValueError("translation came back with a different number of items")
        return [str(x) for x in items]


_override: AIProvider | None = None


def get_ai() -> AIProvider | None:
    if _override is not None:
        return _override
    key = get_settings().openai_api_key
    return OpenAIProvider(key.get_secret_value()) if key else None


def set_ai_for_tests(provider: AIProvider | None) -> None:
    global _override
    _override = provider
