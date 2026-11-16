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
class Draft:
    data: dict
    model: str
    tokens_in: int
    tokens_out: int


# USD per 1M tokens; used to record cost per report (A20). Update when prices or models change.
PRICES = {"gpt-4o-mini": (0.15, 0.60), "gpt-4o": (2.50, 10.00)}


def cost_usd(model: str, tokens_in: int, tokens_out: int) -> float:
    pin, pout = PRICES.get(model, (0.0, 0.0))
    return round((tokens_in * pin + tokens_out * pout) / 1_000_000, 6)


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

    async def draft_report(self, system_prompt: str, evidence: dict) -> Draft: ...


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

    async def draft_report(self, system_prompt, evidence):
        s = get_settings()
        async with httpx.AsyncClient(timeout=120) as c:
            r = await c.post(
                f"{self.base}/chat/completions",
                headers=self.headers,
                json={
                    "model": s.openai_text_model,
                    "temperature": 0.2,
                    "response_format": {"type": "json_object"},
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": json.dumps(evidence, ensure_ascii=False, default=str)},
                    ],
                },
            )
            r.raise_for_status()
        body = r.json()
        usage = body.get("usage") or {}
        return Draft(
            data=json.loads(body["choices"][0]["message"]["content"]),
            model=body.get("model", s.openai_text_model),
            tokens_in=usage.get("prompt_tokens", 0),
            tokens_out=usage.get("completion_tokens", 0),
        )


_override: AIProvider | None = None


def get_ai() -> AIProvider | None:
    if _override is not None:
        return _override
    key = get_settings().openai_api_key
    return OpenAIProvider(key.get_secret_value()) if key else None


def set_ai_for_tests(provider: AIProvider | None) -> None:
    global _override
    _override = provider
