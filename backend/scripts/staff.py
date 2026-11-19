"""Admin panel staff from the command line (there is no email service yet, so links are printed).

    python scripts/staff.py invite  --email you@company.com --name "Your Name" [--role super_admin]
    python scripts/staff.py reset   --email you@company.com   # new password and authenticator
    python scripts/staff.py link    --email you@company.com   # the setup link again, nothing reset

Run it where KN_DATABASE_URL and KN_SECRET_KEY point at the server you mean (Render → Shell, or your
computer with Render's external database URL and the same secret key). The link works once, for
72 hours. "reset" also ends that person's sessions.
"""

import argparse
import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.db import SessionLocal  # noqa: E402
from app.models.staff import STAFF_ROLES  # noqa: E402
from app.services import staff  # noqa: E402


async def main(args: argparse.Namespace) -> None:
    async with SessionLocal() as db:
        if args.cmd == "invite":
            person, link = await staff.invite(db, email=args.email, name=args.name, role=args.role)
        else:
            person = await staff.get_by_email(db, args.email)
            if args.cmd == "reset":
                link = await staff.issue_setup_link(db, person)
            elif person.status != "invited":
                sys.exit(
                    f"{person.email} has already set up. Use reset for a new password and authenticator."
                )
            else:
                link = staff.setup_link(person)
        await db.commit()
    print(f"{person.name} <{person.email}> ({person.role})\nSetup link (72 hours, once):\n{link}")


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    inv = sub.add_parser("invite")
    inv.add_argument("--email", required=True)
    inv.add_argument("--name", required=True)
    inv.add_argument("--role", choices=STAFF_ROLES, default="admin")
    for name in ("reset", "link"):
        sub.add_parser(name).add_argument("--email", required=True)
    asyncio.run(main(p.parse_args()))
