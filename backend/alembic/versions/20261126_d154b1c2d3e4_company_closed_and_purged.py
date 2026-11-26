"""company closed_at and purged_at (D-154)

A closed company's data is deleted 30 days after the owner closed it; the company row stays as the record.
Companies already closed count from their last change.

Revision ID: d154b1c2d3e4
Revises: d149a0b1c2d3
Create Date: 2026-11-26 17:00:00
"""

import sqlalchemy as sa
from alembic import op

revision = "d154b1c2d3e4"
down_revision = "d149a0b1c2d3"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("companies", sa.Column("closed_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("companies", sa.Column("purged_at", sa.DateTime(timezone=True), nullable=True))
    op.create_index(op.f("ix_companies_closed_at"), "companies", ["closed_at"])
    op.execute("UPDATE companies SET closed_at = updated_at WHERE status = 'cancelled'")


def downgrade() -> None:
    op.drop_index(op.f("ix_companies_closed_at"), table_name="companies")
    op.drop_column("companies", "purged_at")
    op.drop_column("companies", "closed_at")
