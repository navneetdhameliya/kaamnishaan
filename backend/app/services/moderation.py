"""A37 review checks: hide phone numbers and emails, and spot abusive words in 5 languages.

Plain rules, not AI, so they are free, instant and predictable. A held review is not lost: KaamNishaan
staff publish or hide it in the admin panel.
"""

import re
import unicodedata

HIDDEN = "•••"

EMAIL = re.compile(r"[\w.+-]+@[\w-]+(?:\.[\w-]+)+")
# 8 or more digits, maybe with spaces, dots, dashes or brackets between them (phone numbers)
PHONE = re.compile(r"\+?\d(?:[\s().-]{0,2}\d){7,}")
DATE = re.compile(r"\d{1,2}[./-]\d{1,2}[./-]\d{2,4}")  # 12.11.2026 is a date, not a phone

# Words that make a review abusive. Kept short on purpose: insults, not complaints ("cheat" and "fraud"
# can be fair complaints and are left to the company to answer).
ABUSIVE = {
    # English
    "idiot", "idiots", "stupid", "moron", "bastard", "bitch", "fuck", "fucking", "fucked", "shit",
    "asshole", "dumbass", "retard",
    # Hindi (Devanagari and as typed in Latin letters)
    "बेवकूफ", "बेवक़ूफ़", "गधा", "कमीना", "कमीने", "हरामी", "चूतिया", "कुत्ता", "कुत्ते", "साला", "गांडू",
    "bewakoof", "bevkoof", "gadha", "kamina", "kamine", "harami", "chutiya", "kutta", "kutte", "saala",
    "gandu",
    # Gujarati
    "ગધેડો", "ગધેડા", "બેવકૂફ", "હરામી", "નાલાયક", "કૂતરો", "ચુતિયા", "gadhedo", "nalayak",
    # Spanish
    "idiota", "estupido", "imbecil", "mierda", "cabron", "pendejo", "gilipollas", "puta",
    # French
    "connard", "connasse", "merde", "imbecile", "salaud", "salope", "enfoire", "abruti",
}  # fmt: skip


def _plain(word: str) -> str:
    """Lower case without accents on Latin letters ("estúpido" -> "estupido"); Indian scripts unchanged."""
    w = word.lower()
    if w.isascii():
        return w
    out = []
    for ch in unicodedata.normalize("NFD", w):
        if unicodedata.category(ch) == "Mn" and out and out[-1].isascii():
            continue  # drop accents on Latin letters only; Indian vowel signs are part of the word
        out.append(ch)
    return unicodedata.normalize("NFC", "".join(out))


def _words(text: str) -> list[str]:
    # letters plus the vowel signs and marks of Indian scripts (\w alone splits Hindi words)
    return re.findall(r"[\wऀ-૿]+", text)


def hide_contact(text: str) -> tuple[str, bool]:
    """Returns the text with phone numbers and emails replaced, and whether anything was found."""
    out = EMAIL.sub(HIDDEN, text)
    out = PHONE.sub(lambda m: m.group() if DATE.fullmatch(m.group()) else HIDDEN, out)
    return out, out != text


def is_abusive(text: str) -> bool:
    return any(_plain(w) in ABUSIVE for w in _words(text))


ABUSIVE = {_plain(w) for w in ABUSIVE}  # same form as the words we compare
