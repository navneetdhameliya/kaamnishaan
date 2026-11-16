"""user trade (M11 "Your work")

Revision ID: b7c1d2e3f4a5
Revises: aee0eba682ff
Create Date: 2026-11-16 09:00:00
"""

import sqlalchemy as sa
from alembic import op

revision = "b7c1d2e3f4a5"
down_revision = "aee0eba682ff"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("trade", sa.String(length=48), nullable=True))
    op.create_foreign_key(op.f("fk_users_trade_industries"), "users", "industries", ["trade"], ["slug"])


def downgrade() -> None:
    op.drop_constraint(op.f("fk_users_trade_industries"), "users", type_="foreignkey")
    op.drop_column("users", "trade")
