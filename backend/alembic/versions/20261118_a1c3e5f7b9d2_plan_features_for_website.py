"""plan features for the website comparison table (W02)

Revision ID: a1c3e5f7b9d2
Revises: f99138993dbc
Create Date: 2026-11-18 10:00:00
"""

import json

import sqlalchemy as sa
from alembic import op

revision = "a1c3e5f7b9d2"
down_revision = "f99138993dbc"
branch_labels = None
depends_on = None

BASE = {"ai_reports": True, "languages": 5, "capture": True, "offline": True, "report_links": True}
PLUS = {
    "free": {"support": "email"},
    "starter": {"branded_pdf": True, "support": "email"},
    "professional": {
        "branded_pdf": True,
        "manager_approvals": True,
        "ai_assistant": True,
        "support": "email_chat",
    },
    "business": {
        "branded_pdf": True,
        "manager_approvals": True,
        "ai_assistant": True,
        "custom_checklists": True,
        "support": "priority",
    },
    "enterprise": {
        "branded_pdf": True,
        "manager_approvals": True,
        "ai_assistant": True,
        "custom_checklists": True,
        "sso_audit": True,
        "custom_integrations": True,
        "support": "dedicated",
    },
}


def upgrade() -> None:
    for code, extra in PLUS.items():
        op.execute(
            sa.text("UPDATE plans SET features = CAST(:f AS jsonb) WHERE code = :c").bindparams(
                f=json.dumps({**BASE, **extra}), c=code
            )
        )


def downgrade() -> None:
    op.execute(sa.text("""UPDATE plans SET features = '{"ai_reports": true, "languages": 5}'::jsonb"""))
