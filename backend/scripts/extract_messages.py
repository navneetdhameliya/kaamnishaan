"""Lists every error message the API can send (the English text of each AppError raise), so each one has
a translation in backend/app/content/messages/{lang}.json. `--check` fails when one is missing (CI)."""

from __future__ import annotations

import ast
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "app"
OUT = APP / "content" / "messages"
LANGS = ("hi", "gu", "es", "fr")
ERRORS = {"AppError", "Unauthorized", "Forbidden", "NotFound", "Conflict", "Gone", "PlanLimit", "RateLimited"}

# messages the API builds outside a raise (the generic ones in app/core/errors.py)
EXTRA = ["Some fields are not valid.", "Not found.", "This action isn't allowed.", "Something went wrong."]


def _name(f: ast.expr) -> str | None:
    return f.id if isinstance(f, ast.Name) else f.attr if isinstance(f, ast.Attribute) else None


def _texts(node: ast.expr) -> list[str] | None:
    """The fixed sentences a message can be: a string, strings joined with +, or `a if x else b`.
    None when it is built at run time (an f-string): those go in English, so use params instead."""
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        return [node.value]
    if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Add):
        a, b = _texts(node.left), _texts(node.right)
        return [x + y for x in a for y in b] if a is not None and b is not None else None
    if isinstance(node, ast.IfExp):
        a, b = _texts(node.body), _texts(node.orelse)
        return a + b if a is not None and b is not None else None
    return None


def messages() -> tuple[list[str], list[str]]:
    found: set[str] = set(EXTRA)
    dynamic: list[str] = []
    for path in sorted(APP.rglob("*.py")):
        tree = ast.parse(path.read_text(encoding="utf-8"))
        for node in ast.walk(tree):
            if not isinstance(node, ast.Call) or _name(node.func) not in ERRORS:
                continue
            arg = (
                node.args[1]
                if len(node.args) > 1
                else next((k.value for k in node.keywords if k.arg == "message"), None)
            )
            if arg is None:
                continue
            texts = _texts(arg)
            if texts is None:
                dynamic.append(f"{path.relative_to(ROOT)}:{node.lineno}")
            else:
                found.update(texts)
    return sorted(found), dynamic


def main() -> int:
    found, dynamic = messages()
    check = "--check" in sys.argv
    problems = 0
    for lang in LANGS:
        path = OUT / f"{lang}.json"
        have = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
        missing = [m for m in found if not have.get(m)]
        stale = [m for m in have if m not in found]
        if missing or stale:
            problems += len(missing) + len(stale)
            print(f"{lang}: {len(missing)} missing, {len(stale)} no longer used")
            for m in missing[:20]:
                print("   missing:", m)
            for m in stale[:20]:
                print("   unused:", m)
    if "--list" in sys.argv:
        print(json.dumps(found, ensure_ascii=False, indent=2))
    print(f"{len(found)} messages; {len(dynamic)} built at run time (sent in English): {', '.join(dynamic)}")
    return 1 if check and problems else 0


if __name__ == "__main__":
    sys.exit(main())
