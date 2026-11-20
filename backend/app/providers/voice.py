"""AI voice calls (A38 Day 5 review call). No provider is connected yet (D-115).

`get_voice()` returns None until one is added; the Day 5 step then sends the rating link by SMS
instead and the call log says why. Tests swap in a fake with `set_voice_for_tests`.

A provider places the call with the script and returns what happened. Real providers answer later
through a webhook; the fake answers at once.
"""

from dataclasses import dataclass, field


@dataclass
class CallRequest:
    to: str
    language: str  # en, hi, gu, es, fr: the language the agent speaks
    voice: str
    opening: str  # said first, word for word (AI and recording disclosure)
    steps: list[dict] = field(default_factory=list)  # the call script: [{key, text}]
    record: bool = True
    voicemail: bool = True  # leave a voicemail when nobody answers
    test: bool = False


@dataclass
class CallResult:
    outcome: str  # rated, voicemail, call_back, no_answer, opted_out, wrong_person, dnd
    seconds: int = 0
    cost_usd: float = 0.0
    rating: int | None = None
    comment: str | None = None
    wants_call_back: bool = False
    public_allowed: bool = False
    callback_in_minutes: int | None = None
    transcript: str | None = None
    provider_call_id: str | None = None


class VoiceProvider:
    name = "none"

    async def call(self, req: CallRequest) -> CallResult: ...


_override: VoiceProvider | None = None


def set_voice_for_tests(provider: VoiceProvider | None) -> None:
    global _override
    _override = provider


def get_voice() -> VoiceProvider | None:
    return _override  # a real provider is added here with its key (KN_VOICE_*), see docs/decisions.md D-115
