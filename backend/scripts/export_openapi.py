"""Write the API contract generated from the backend code to shared/api/openapi.generated.json.

    python scripts/export_openapi.py          # update the file
    python scripts/export_openapi.py --check  # fail if the file is out of date (CI)

The apps generate their API clients from this file (Dart for Flutter, TypeScript for web and admin).
"""

import json
import sys
from pathlib import Path

from app.main import create_app

OUT = Path(__file__).resolve().parents[2] / "shared" / "api" / "openapi.generated.json"


def main() -> int:
    spec = create_app().openapi()
    # local-only helpers (test inbox, local file links) are not part of the contract
    local_only = ("/api/v1/dev/", "/api/v1/files/")
    spec["paths"] = {k: v for k, v in spec["paths"].items() if not k.startswith(local_only)}
    text = json.dumps(spec, indent=2, ensure_ascii=False, sort_keys=True) + "\n"
    if "--check" in sys.argv:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print(f"{OUT.name} is out of date: run `python scripts/export_openapi.py` in backend/")
            return 1
        print(f"{OUT.name} is up to date ({len(spec['paths'])} paths)")
        return 0
    OUT.write_text(text, encoding="utf-8")
    print(f"Wrote {OUT} ({len(spec['paths'])} paths)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
