"""The customer PDF (M34). Built with fpdf2; Hindi and Gujarati are shaped with HarfBuzz.

Photos use the 480 px thumbnails (EXIF and GPS removed), which keeps a 12-photo report small.
The file's SHA-256 is stored, so a PDF a customer forwards can be checked against ours.
"""

import io
from pathlib import Path

from fpdf import FPDF

from app.services.report_labels import fmt_date, label
from app.services.report_view import CustomerView

FONTS = Path(__file__).resolve().parent.parent / "assets" / "fonts"
FAMILIES = {"NS": "NotoSans", "ND": "NotoSansDevanagari", "NG": "NotoSansGujarati"}
MAIN = {"hi": "ND", "gu": "NG"}  # other languages use Noto Sans

INK = (43, 36, 32)
MUTED = (110, 100, 94)
MOCHA = (164, 120, 100)  # brand/mocha
SAGE = (156, 175, 136)  # brand/sage
FAIL = (192, 72, 58)
LINE = (226, 220, 214)
MAX_PAIRS = 6
MAX_PHOTOS = 9


class _Pdf(FPDF):
    def __init__(self, view: CustomerView, lang: str, branded: bool = True):
        super().__init__(format="A4")
        self.view, self.lang, self.branded = view, lang, branded
        for key, fam in FAMILIES.items():
            self.add_font(key, "", str(FONTS / f"{fam}-Regular.ttf"))
            self.add_font(key, "B", str(FONTS / f"{fam}-Bold.ttf"))
        self.main = MAIN.get(lang, "NS")
        self.set_text_shaping(True)
        self.set_fallback_fonts([f for f in FAMILIES if f != self.main])
        self.set_auto_page_break(True, margin=22)
        self.set_margins(16, 16, 16)

    def font(self, size: float, bold: bool = False, color=INK) -> None:
        # always switch: after a fallback font was used, fpdf2 may skip "same font again"
        # and the next text would be written with no font (seen as missing Gujarati titles)
        self.font_family = ""
        self.set_font(self.main, "B" if bold else "", size)
        self.set_text_color(*color)

    def para(self, text: str, size: float = 10.5, bold: bool = False, color=INK, h: float = 5.6) -> None:
        self.font(size, bold, color)
        self.multi_cell(self.epw, h, text, new_x="LMARGIN", new_y="NEXT")

    def heading(self, text: str) -> None:
        if self.get_y() > self.h - 50:
            self.add_page()
        self.ln(4)
        self.font(12.5, True, MOCHA)
        self.cell(self.epw, 8, text, new_x="LMARGIN", new_y="NEXT")
        self.set_draw_color(*LINE)
        self.line(self.l_margin, self.get_y(), self.w - self.r_margin, self.get_y())
        self.ln(2.5)

    def footer(self) -> None:
        v = self.view
        self.set_y(-19 if not self.branded else -15)
        self.font(7.5, color=MUTED)
        if not self.branded:  # D-147: plans without a branded PDF carry KaamNishaan's line
            self.cell(self.epw, 4, label(self.lang, "made_with"), new_x="LMARGIN", new_y="NEXT")
        locked = label(self.lang, "locked", date=fmt_date(v.local(v.report.submitted_at), self.lang))
        self.cell(self.epw * 0.8, 4, locked)
        self.cell(self.epw * 0.2, 4, f"{v.number} · {label(self.lang, 'page', n=self.page_no())}", align="R")


def _image_box(pdf: _Pdf, data: bytes | None, x: float, y: float, w: float, h: float, caption: str) -> None:
    pdf.set_draw_color(*LINE)
    pdf.set_fill_color(246, 243, 240)
    pdf.rect(x, y, w, h, style="DF")
    if data:
        try:
            pdf.image(io.BytesIO(data), x=x, y=y, w=w, h=h, keep_aspect_ratio=True)
        except Exception:  # noqa: BLE001, S110 - a broken image leaves an empty frame, never a failed PDF
            pass
    pdf.set_xy(x, y + h + 0.8)
    pdf.font(8.5, True, MUTED)
    pdf.cell(w, 4.5, caption)


def build_pdf(
    view: CustomerView, lang: str, images: dict, logo: bytes | None = None, branded: bool = True
) -> tuple[bytes, int]:
    """[branded] False (D-147): no company logo, and "Made with KaamNishaan" in the footer."""
    if not branded:
        logo = None
    """images: evidence id -> thumbnail bytes. Returns (pdf bytes, page count)."""
    rep = view.report
    pdf = _Pdf(view, lang, branded)
    pdf.set_title(f"{label(lang, 'title')} {view.number}")
    pdf.set_author(view.company.name)
    pdf.set_creator("KaamNishaan")
    pdf.set_creation_date(rep.approved_at)
    pdf.add_page()

    # header: company, report number and date
    top = pdf.get_y()
    x_text = pdf.l_margin
    if logo:
        try:
            pdf.image(io.BytesIO(logo), x=pdf.l_margin, y=top, h=14)
            x_text += 18
        except Exception:  # noqa: BLE001, S110 - no logo is better than no PDF
            pass
    pdf.set_xy(x_text, top)
    pdf.font(15, True)
    pdf.cell(pdf.epw * 0.6, 7, view.company.name)
    pdf.set_xy(pdf.l_margin, top)
    pdf.font(15, True, MOCHA)
    pdf.cell(pdf.epw, 7, label(lang, "title"), align="R", new_x="LMARGIN", new_y="NEXT")
    pdf.font(9.5, color=MUTED)
    pdf.cell(
        pdf.epw,
        5,
        f"{view.number} · {fmt_date(view.local(rep.approved_at), lang)}",
        align="R",
        new_x="LMARGIN",
        new_y="NEXT",
    )
    pdf.set_y(max(pdf.get_y(), top + 16) + 3)

    # job details in two columns
    rows = [
        (label(lang, "customer"), view.customer),
        (label(lang, "job"), f"{view.job_number} · {view.title}"),
        (label(lang, "address"), view.address),
        (label(lang, "technician"), view.technician),
        (label(lang, "approved_by"), view.approved_by),
        (label(lang, "date"), fmt_date(view.local(view.job.completed_at or rep.approved_at), lang)),
    ]
    rows = [(k, v) for k, v in rows if v]
    pdf.set_fill_color(248, 245, 242)
    box_top = pdf.get_y()
    col = pdf.epw / 2
    for i, (k, v) in enumerate(rows):
        x = pdf.l_margin + 4 + (i % 2) * col
        y = box_top + 3 + (i // 2) * 11
        pdf.set_xy(x, y)
        pdf.font(8, color=MUTED)
        pdf.cell(col - 8, 4, k.upper() if lang in ("en", "es", "fr") else k)
        pdf.set_xy(x, y + 4.2)
        pdf.font(10, True)
        pdf.cell(col - 8, 5.5, v if len(v) < 60 else v[:57] + "…")
    box_h = 6 + ((len(rows) + 1) // 2) * 11
    pdf.set_draw_color(*LINE)
    pdf.rect(pdf.l_margin, box_top, pdf.epw, box_h)
    pdf.set_y(box_top + box_h + 2)

    if rep.summary:
        pdf.heading(label(lang, "summary"))
        pdf.para(rep.summary)

    if view.lines:
        pdf.heading(label(lang, "work_done"))
        for line in view.lines:
            pdf.para(f"•  {line}")

    # photos: before/after pairs, or the before and after photos side by side
    pairs = view.pairs[:MAX_PAIRS]
    if not pairs:
        befores = [e for e in view.photos if e.stage == "before"]
        afters = [e for e in view.photos if e.stage == "after"]
        pairs = [(None, b, a) for b, a in zip(befores, afters, strict=False)][:MAX_PAIRS]
    if pairs:
        w = (pdf.epw - 6) / 2
        h = w * 0.68
        if pdf.get_y() + h + 30 > pdf.h - 22:
            pdf.add_page()
        pdf.heading(label(lang, "before_after"))
        for subject, b, a in pairs:
            if pdf.get_y() + h + 14 > pdf.h - 22:
                pdf.add_page()
            if subject:
                pdf.para(subject, 9.5, True, MUTED, 5)
            y = pdf.get_y()
            _image_box(pdf, images.get(b.id), pdf.l_margin, y, w, h, label(lang, "before"))
            _image_box(pdf, images.get(a.id), pdf.l_margin + w + 6, y, w, h, label(lang, "after"))
            pdf.set_y(y + h + 8)
    used = {e.id for _, b, a in pairs for e in (b, a)}
    rest = [e for e in view.photos if e.id not in used][:MAX_PHOTOS]
    if rest:
        w = (pdf.epw - 8) / 3
        h = w * 0.75
        if pdf.get_y() + h + 30 > pdf.h - 22:  # keep the heading with its first row
            pdf.add_page()
        pdf.heading(label(lang, "photos"))
        for start in range(0, len(rest), 3):
            if pdf.get_y() + h + 14 > pdf.h - 22:
                pdf.add_page()
            y = pdf.get_y()
            for i, e in enumerate(rest[start : start + 3]):
                caption = label(lang, e.stage) if e.stage in ("before", "after") else ""
                _image_box(pdf, images.get(e.id), pdf.l_margin + i * (w + 4), y, w, h, caption)
            pdf.set_y(y + h + 8)

    if view.checklists:
        pdf.heading(label(lang, "checklist"))
        wq, wv = pdf.epw * 0.66, pdf.epw * 0.34
        for cl in view.checklists:
            if len(view.checklists) > 1:
                pdf.para(cl["name"], 10, True, MUTED, 6)
            for a in cl["items"]:
                if a["passed"] is True:
                    value, color = label(lang, "pass"), SAGE
                elif a["passed"] is False:
                    value, color = label(lang, "fail"), FAIL
                else:
                    value, color = a["answer"] or "—", INK
                pdf.font(9.5)
                hq = pdf.multi_cell(wq, 5.2, a["question"], dry_run=True, output="HEIGHT")
                pdf.font(9.5, True, color)
                hv = pdf.multi_cell(wv, 5.2, value, dry_run=True, output="HEIGHT", align="R")
                if pdf.get_y() + max(hq, hv) > pdf.h - 24:
                    pdf.add_page()
                y = pdf.get_y()
                pdf.font(9.5)
                pdf.multi_cell(wq, 5.2, a["question"], new_x="RIGHT", new_y="TOP")
                pdf.set_xy(pdf.l_margin + wq, y)
                pdf.font(9.5, True, color)
                pdf.multi_cell(wv, 5.2, value, align="R", new_x="LMARGIN", new_y="NEXT")
                bottom = y + max(hq, hv)
                pdf.set_draw_color(*LINE)
                pdf.line(pdf.l_margin, bottom + 0.8, pdf.w - pdf.r_margin, bottom + 0.8)
                pdf.set_y(bottom + 1.8)

    if view.advice_lines:
        pdf.heading(label(lang, "advice"))
        for line in view.advice_lines:
            pdf.para(f"•  {line}")

    data = bytes(pdf.output())
    return data, pdf.page_no()
