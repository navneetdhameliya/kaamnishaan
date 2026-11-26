"""next service requests from the report page (D-149)

"Book next service" on W27 is stored with the customer's other messages about a report.

Revision ID: d149a0b1c2d3
Revises: 5134d216ebca
Create Date: 2026-11-26 16:00:00
"""

from alembic import op

revision = "d149a0b1c2d3"
down_revision = "5134d216ebca"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_constraint(op.f("ck_report_issues_report_issue_kind"), "report_issues", type_="check")
    op.create_check_constraint(
        "report_issue_kind", "report_issues", "kind IN ('problem', 'new_link', 'next_service')"
    )


def downgrade() -> None:
    op.execute("DELETE FROM report_issues WHERE kind = 'next_service'")
    op.drop_constraint(op.f("ck_report_issues_report_issue_kind"), "report_issues", type_="check")
    op.create_check_constraint("report_issue_kind", "report_issues", "kind IN ('problem', 'new_link')")
