"""checklists answers manager questions voice notes

Revision ID: 49e1fcb03834
Revises: de79a0c356e5
Create Date: 2026-11-16 05:00:58.003438
"""

import json
import uuid
from pathlib import Path

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql
from sqlalchemy.dialects.postgresql import JSONB

revision = "49e1fcb03834"
down_revision = "de79a0c356e5"
branch_labels = None
depends_on = None


SEED_FILE = Path(__file__).resolve().parents[1] / "data" / "hvac_checklists_v1.json"
NS = uuid.UUID("6f1d2c3e-0b7a-4c55-9a51-7e1f3d1c0001")  # fixed, so ids never change
LANGS = ("en", "hi", "gu", "es", "fr")


def _seed_templates() -> None:
    data = json.loads(SEED_FILE.read_text(encoding="utf-8"))
    templates = sa.table(
        "checklist_templates",
        sa.column("id", sa.Uuid), sa.column("key", sa.String), sa.column("trade", sa.String),
        sa.column("name", JSONB), sa.column("source_language", sa.String), sa.column("minutes", sa.Integer),
        sa.column("version", sa.Integer), sa.column("status", sa.String), sa.column("usage_count", sa.Integer),
    )  # fmt: skip
    questions = sa.table(
        "checklist_questions",
        sa.column("id", sa.Uuid), sa.column("template_id", sa.Uuid), sa.column("position", sa.Integer),
        sa.column("type", sa.String), sa.column("text", JSONB), sa.column("help", JSONB),
        sa.column("text_status", JSONB), sa.column("options", JSONB), sa.column("unit", sa.String),
        sa.column("min_value", sa.Float), sa.column("max_value", sa.Float), sa.column("photo_rule", sa.String),
        sa.column("required", sa.Boolean), sa.column("condition", JSONB),
    )  # fmt: skip
    shots = sa.table(
        "shot_slots",
        sa.column("id", sa.Uuid), sa.column("template_id", sa.Uuid), sa.column("stage", sa.String),
        sa.column("key", sa.String), sa.column("prompt", JSONB), sa.column("position", sa.Integer),
    )  # fmt: skip
    status = {lang: ("ready" if lang == "en" else "needs_review") for lang in LANGS}
    for t in data["templates"]:
        tid = uuid.uuid5(NS, t["key"])
        op.bulk_insert(templates, [{
            "id": tid, "key": t["key"], "trade": "hvac", "name": t["name"], "source_language": "en",
            "minutes": t["minutes"], "version": 1, "status": "published", "usage_count": 0,
        }])  # fmt: skip
        qid = {q["key"]: uuid.uuid5(NS, f"{t['key']}/{q['key']}") for q in t["questions"]}
        rows = []
        for i, q in enumerate(t["questions"], start=1):
            cond = q.get("condition")
            rows.append({
                "id": qid[q["key"]], "template_id": tid, "position": i, "type": q["type"], "text": q["text"],
                "help": {}, "text_status": status, "options": q.get("options", []), "unit": q.get("unit"),
                "min_value": q.get("min"), "max_value": q.get("max"), "photo_rule": q.get("photo_rule", "none"),
                "required": q.get("required", True),
                "condition": {"question_id": str(qid[cond["question"]]), "equals": cond["equals"]} if cond else None,
            })  # fmt: skip
        op.bulk_insert(questions, rows)
        if t["shots"]:
            op.bulk_insert(shots, [
                {"id": uuid.uuid5(NS, f"{t['key']}/shot/{sh['key']}"), "template_id": tid, "stage": sh["stage"],
                 "key": sh["key"], "prompt": sh["prompt"], "position": i}
                for i, sh in enumerate(t["shots"], start=1)
            ])  # fmt: skip


LOCK_GUARDS = (
    """
CREATE FUNCTION checklist_answer_lock_guard() RETURNS trigger AS $$
BEGIN
    IF OLD.locked_at IS NOT NULL THEN
        RAISE EXCEPTION 'evidence_locked' USING ERRCODE = 'check_violation';
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;
""",
    """
CREATE TRIGGER checklist_answer_lock_guard BEFORE UPDATE OR DELETE ON checklist_answers
    FOR EACH ROW EXECUTE FUNCTION checklist_answer_lock_guard();
""",
    """
-- Transcription may still finish after lock; the recording, who, when and the edited text may not change.
CREATE FUNCTION voice_note_lock_guard() RETURNS trigger AS $$
BEGIN
    IF OLD.locked_at IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'evidence_locked' USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.locked_at IS DISTINCT FROM OLD.locked_at
       OR NEW.job_id IS DISTINCT FROM OLD.job_id
       OR NEW.kind IS DISTINCT FROM OLD.kind
       OR NEW.audio_key IS DISTINCT FROM OLD.audio_key
       OR NEW.recorded_at IS DISTINCT FROM OLD.recorded_at
       OR NEW.recorded_by IS DISTINCT FROM OLD.recorded_by
       OR NEW.duration_s IS DISTINCT FROM OLD.duration_s
       OR NEW.transcript_edited IS DISTINCT FROM OLD.transcript_edited
       OR NEW.deleted_at IS DISTINCT FROM OLD.deleted_at
       OR (OLD.kind = 'typed' AND NEW.transcript_original IS DISTINCT FROM OLD.transcript_original) THEN
        RAISE EXCEPTION 'evidence_locked' USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
""",
    """
CREATE TRIGGER voice_note_lock_guard BEFORE UPDATE OR DELETE ON voice_notes
    FOR EACH ROW EXECUTE FUNCTION voice_note_lock_guard();
""",
)


def upgrade() -> None:
    # ### commands auto generated by Alembic - please adjust! ###
    op.create_table(
        "checklist_templates",
        sa.Column("company_id", sa.Uuid(), nullable=True),
        sa.Column("trade", sa.String(length=48), nullable=True),
        sa.Column("key", sa.String(length=64), nullable=True),
        sa.Column("name", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("source_language", sa.String(length=5), server_default="en", nullable=False),
        sa.Column("minutes", sa.Integer(), nullable=True),
        sa.Column("version", sa.Integer(), server_default=sa.text("1"), nullable=False),
        sa.Column(
            "status",
            sa.Enum(
                "draft",
                "published",
                "archived",
                name="template_status",
                native_enum=False,
                create_constraint=True,
                length=32,
            ),
            nullable=False,
        ),
        sa.Column("usage_count", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("copied_from", sa.Uuid(), nullable=True),
        sa.Column("created_by", sa.Uuid(), nullable=True),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["company_id"],
            ["companies.id"],
            name=op.f("fk_checklist_templates_company_id_companies"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["copied_from"],
            ["checklist_templates.id"],
            name=op.f("fk_checklist_templates_copied_from_checklist_templates"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["created_by"],
            ["users.id"],
            name=op.f("fk_checklist_templates_created_by_users"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["trade"], ["industries.slug"], name=op.f("fk_checklist_templates_trade_industries")
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_checklist_templates")),
        sa.UniqueConstraint("key", name=op.f("uq_checklist_templates_key")),
    )
    op.create_index(
        op.f("ix_checklist_templates_company_id"), "checklist_templates", ["company_id"], unique=False
    )
    op.create_table(
        "checklist_questions",
        sa.Column("template_id", sa.Uuid(), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column(
            "type",
            sa.Enum(
                "yes_no",
                "pass_fail",
                "number",
                "text",
                "choice",
                "photo",
                "signature",
                name="question_type",
                native_enum=False,
                create_constraint=True,
                length=32,
            ),
            nullable=False,
        ),
        sa.Column("text", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column(
            "help",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'{}'::jsonb"),
            nullable=False,
        ),
        sa.Column(
            "text_status",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'{}'::jsonb"),
            nullable=False,
        ),
        sa.Column(
            "options",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'[]'::jsonb"),
            nullable=False,
        ),
        sa.Column("unit", sa.String(length=16), nullable=True),
        sa.Column("min_value", sa.Float(), nullable=True),
        sa.Column("max_value", sa.Float(), nullable=True),
        sa.Column(
            "photo_rule",
            sa.Enum(
                "none",
                "always",
                "if_no",
                "if_fail",
                name="photo_rule",
                native_enum=False,
                create_constraint=True,
                length=32,
            ),
            nullable=False,
        ),
        sa.Column("reference_image_key", sa.String(length=255), nullable=True),
        sa.Column("required", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("condition", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["template_id"],
            ["checklist_templates.id"],
            name=op.f("fk_checklist_questions_template_id_checklist_templates"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_checklist_questions")),
    )
    op.create_index(
        op.f("ix_checklist_questions_template_id"), "checklist_questions", ["template_id"], unique=False
    )
    op.create_table(
        "shot_slots",
        sa.Column("template_id", sa.Uuid(), nullable=False),
        sa.Column("stage", sa.String(length=16), nullable=False),
        sa.Column("key", sa.String(length=64), nullable=False),
        sa.Column("prompt", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.ForeignKeyConstraint(
            ["template_id"],
            ["checklist_templates.id"],
            name=op.f("fk_shot_slots_template_id_checklist_templates"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_shot_slots")),
        sa.UniqueConstraint("template_id", "key", name="uq_shot_slots_template_key"),
    )
    op.create_table(
        "job_checklists",
        sa.Column("company_id", sa.Uuid(), nullable=False),
        sa.Column("job_id", sa.Uuid(), nullable=False),
        sa.Column("template_id", sa.Uuid(), nullable=False),
        sa.Column("template_version", sa.Integer(), nullable=False),
        sa.Column("name", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("minutes", sa.Integer(), nullable=True),
        sa.Column("questions", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("answered_count", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("total", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("added_by", sa.Uuid(), nullable=True),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["added_by"], ["users.id"], name=op.f("fk_job_checklists_added_by_users"), ondelete="SET NULL"
        ),
        sa.ForeignKeyConstraint(
            ["company_id"],
            ["companies.id"],
            name=op.f("fk_job_checklists_company_id_companies"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["job_id"], ["jobs.id"], name=op.f("fk_job_checklists_job_id_jobs"), ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["template_id"],
            ["checklist_templates.id"],
            name=op.f("fk_job_checklists_template_id_checklist_templates"),
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_job_checklists")),
        sa.UniqueConstraint("job_id", "template_id", name="uq_job_checklists_job_template"),
    )
    op.create_index(op.f("ix_job_checklists_company_id"), "job_checklists", ["company_id"], unique=False)
    op.create_index(op.f("ix_job_checklists_job_id"), "job_checklists", ["job_id"], unique=False)
    op.create_table(
        "voice_notes",
        sa.Column("company_id", sa.Uuid(), nullable=False),
        sa.Column("job_id", sa.Uuid(), nullable=False),
        sa.Column("client_uuid", sa.Uuid(), nullable=True),
        sa.Column(
            "kind",
            sa.Enum("audio", "typed", name="note_kind", native_enum=False, create_constraint=True, length=32),
            nullable=False,
        ),
        sa.Column("audio_key", sa.String(length=255), nullable=True),
        sa.Column("content_type", sa.String(length=80), nullable=True),
        sa.Column("size", sa.BigInteger(), nullable=True),
        sa.Column("sha256", sa.String(length=64), nullable=True),
        sa.Column("duration_s", sa.Float(), nullable=True),
        sa.Column("language_hint", sa.String(length=5), nullable=True),
        sa.Column("detected_language", sa.String(length=8), nullable=True),
        sa.Column(
            "status",
            sa.Enum(
                "uploaded",
                "transcribing",
                "transcribed",
                "unclear",
                "failed",
                name="voice_status",
                native_enum=False,
                create_constraint=True,
                length=32,
            ),
            nullable=False,
        ),
        sa.Column("transcript_original", sa.Text(), nullable=True),
        sa.Column("transcript_translated", sa.Text(), nullable=True),
        sa.Column("translated_to", sa.String(length=5), nullable=True),
        sa.Column("transcript_edited", sa.Text(), nullable=True),
        sa.Column("confidence", sa.Float(), nullable=True),
        sa.Column("error", sa.String(length=300), nullable=True),
        sa.Column("recorded_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("recorded_by", sa.Uuid(), nullable=False),
        sa.Column("locked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["company_id"],
            ["companies.id"],
            name=op.f("fk_voice_notes_company_id_companies"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["job_id"], ["jobs.id"], name=op.f("fk_voice_notes_job_id_jobs"), ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(["recorded_by"], ["users.id"], name=op.f("fk_voice_notes_recorded_by_users")),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_voice_notes")),
        sa.UniqueConstraint("company_id", "client_uuid", name="uq_voice_notes_company_client"),
    )
    op.create_index(op.f("ix_voice_notes_company_id"), "voice_notes", ["company_id"], unique=False)
    op.create_index(op.f("ix_voice_notes_job_id"), "voice_notes", ["job_id"], unique=False)
    op.create_table(
        "checklist_answers",
        sa.Column("company_id", sa.Uuid(), nullable=False),
        sa.Column("job_checklist_id", sa.Uuid(), nullable=False),
        sa.Column("question_id", sa.Uuid(), nullable=False),
        sa.Column("client_uuid", sa.Uuid(), nullable=True),
        sa.Column("value", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("photo_id", sa.Uuid(), nullable=True),
        sa.Column("signature_key", sa.String(length=255), nullable=True),
        sa.Column("answered_by", sa.Uuid(), nullable=False),
        sa.Column("answered_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("locked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["answered_by"], ["users.id"], name=op.f("fk_checklist_answers_answered_by_users")
        ),
        sa.ForeignKeyConstraint(
            ["company_id"],
            ["companies.id"],
            name=op.f("fk_checklist_answers_company_id_companies"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["job_checklist_id"],
            ["job_checklists.id"],
            name=op.f("fk_checklist_answers_job_checklist_id_job_checklists"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["photo_id"], ["evidence.id"], name=op.f("fk_checklist_answers_photo_id_evidence")
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_checklist_answers")),
        sa.UniqueConstraint("company_id", "client_uuid", name="uq_checklist_answers_client"),
        sa.UniqueConstraint("job_checklist_id", "question_id", name="uq_checklist_answers_question"),
    )
    op.create_index(
        op.f("ix_checklist_answers_job_checklist_id"), "checklist_answers", ["job_checklist_id"], unique=False
    )
    op.create_table(
        "manager_questions",
        sa.Column("company_id", sa.Uuid(), nullable=False),
        sa.Column("job_id", sa.Uuid(), nullable=False),
        sa.Column("job_checklist_id", sa.Uuid(), nullable=True),
        sa.Column("question_id", sa.Uuid(), nullable=True),
        sa.Column("photo_id", sa.Uuid(), nullable=True),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("asked_by", sa.Uuid(), nullable=False),
        sa.Column("answer", sa.Text(), nullable=True),
        sa.Column("answered_by", sa.Uuid(), nullable=True),
        sa.Column("answered_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["answered_by"], ["users.id"], name=op.f("fk_manager_questions_answered_by_users")
        ),
        sa.ForeignKeyConstraint(["asked_by"], ["users.id"], name=op.f("fk_manager_questions_asked_by_users")),
        sa.ForeignKeyConstraint(
            ["company_id"],
            ["companies.id"],
            name=op.f("fk_manager_questions_company_id_companies"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["job_checklist_id"],
            ["job_checklists.id"],
            name=op.f("fk_manager_questions_job_checklist_id_job_checklists"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["job_id"], ["jobs.id"], name=op.f("fk_manager_questions_job_id_jobs"), ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["photo_id"], ["evidence.id"], name=op.f("fk_manager_questions_photo_id_evidence")
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_manager_questions")),
    )
    op.create_index(
        op.f("ix_manager_questions_company_id"), "manager_questions", ["company_id"], unique=False
    )
    op.create_index(op.f("ix_manager_questions_job_id"), "manager_questions", ["job_id"], unique=False)
    # ### end Alembic commands ###
    _seed_templates()
    for statement in LOCK_GUARDS:  # the driver runs one statement per call
        op.execute(statement)


def downgrade() -> None:
    op.execute("DROP TRIGGER IF EXISTS voice_note_lock_guard ON voice_notes")
    op.execute("DROP FUNCTION IF EXISTS voice_note_lock_guard()")
    op.execute("DROP TRIGGER IF EXISTS checklist_answer_lock_guard ON checklist_answers")
    op.execute("DROP FUNCTION IF EXISTS checklist_answer_lock_guard()")
    # ### commands auto generated by Alembic - please adjust! ###
    op.drop_index(op.f("ix_manager_questions_job_id"), table_name="manager_questions")
    op.drop_index(op.f("ix_manager_questions_company_id"), table_name="manager_questions")
    op.drop_table("manager_questions")
    op.drop_index(op.f("ix_checklist_answers_job_checklist_id"), table_name="checklist_answers")
    op.drop_table("checklist_answers")
    op.drop_index(op.f("ix_voice_notes_job_id"), table_name="voice_notes")
    op.drop_index(op.f("ix_voice_notes_company_id"), table_name="voice_notes")
    op.drop_table("voice_notes")
    op.drop_index(op.f("ix_job_checklists_job_id"), table_name="job_checklists")
    op.drop_index(op.f("ix_job_checklists_company_id"), table_name="job_checklists")
    op.drop_table("job_checklists")
    op.drop_table("shot_slots")
    op.drop_index(op.f("ix_checklist_questions_template_id"), table_name="checklist_questions")
    op.drop_table("checklist_questions")
    op.drop_index(op.f("ix_checklist_templates_company_id"), table_name="checklist_templates")
    op.drop_table("checklist_templates")
    # ### end Alembic commands ###
