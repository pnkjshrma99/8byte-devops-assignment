"""Build the challenges document as PDF and DOCX from CHALLENGES.md."""

from __future__ import annotations

import re
from pathlib import Path
from xml.sax.saxutils import escape

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.shared import Inches, Pt, RGBColor
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas
from reportlab.platypus import (
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    XPreformatted,
)

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "CHALLENGES.md"
OUT_DIR = ROOT / "challenges"


def inline_markup(text: str) -> str:
    text = escape(text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text)
    text = re.sub(r"`(.+?)`", r'<font name="Courier" size="8">\1</font>', text)
    return text


def parse_markdown(path: Path):
    blocks = []
    paragraph = []
    code_lines = []
    in_code = False

    def flush_paragraph():
        if paragraph:
            blocks.append(("p", " ".join(paragraph).strip()))
            paragraph.clear()

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.rstrip()

        if line.startswith("```"):
            if in_code:
                blocks.append(("code", "\n".join(code_lines)))
                code_lines.clear()
                in_code = False
            else:
                flush_paragraph()
                in_code = True
            continue

        if in_code:
            code_lines.append(line)
            continue

        if not line.strip():
            flush_paragraph()
            continue

        if line.startswith("# "):
            flush_paragraph()
            blocks.append(("h1", line[2:].strip()))
        elif line.startswith("## "):
            flush_paragraph()
            blocks.append(("h2", line[3:].strip()))
        elif line.startswith("### "):
            flush_paragraph()
            blocks.append(("h3", line[4:].strip()))
        elif line.startswith("- "):
            flush_paragraph()
            blocks.append(("bullet", line[2:].strip()))
        elif line.strip() == "---":
            flush_paragraph()
            blocks.append(("spacer", ""))
        else:
            paragraph.append(line.strip())

    flush_paragraph()
    if in_code and code_lines:
        blocks.append(("code", "\n".join(code_lines)))
    return blocks


def build_pdf(blocks, output: Path) -> None:
    styles = getSampleStyleSheet()
    title = ParagraphStyle(
        "DocTitle",
        parent=styles["Title"],
        fontName="Helvetica-Bold",
        fontSize=22,
        leading=26,
        spaceAfter=6,
        textColor=colors.HexColor("#0f172a"),
    )
    subtitle = ParagraphStyle(
        "Subtitle",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=10,
        leading=14,
        textColor=colors.HexColor("#475569"),
        spaceAfter=16,
    )
    h1 = ParagraphStyle(
        "H1",
        parent=styles["Heading1"],
        fontName="Helvetica-Bold",
        fontSize=15,
        leading=19,
        spaceBefore=14,
        spaceAfter=6,
        textColor=colors.HexColor("#0f172a"),
    )
    h2 = ParagraphStyle(
        "H2",
        parent=styles["Heading2"],
        fontName="Helvetica-Bold",
        fontSize=12,
        leading=16,
        spaceBefore=12,
        spaceAfter=4,
        textColor=colors.HexColor("#1e3a8a"),
    )
    h3 = ParagraphStyle(
        "H3",
        parent=styles["Heading3"],
        fontName="Helvetica-Bold",
        fontSize=10.5,
        leading=14,
        spaceBefore=8,
        spaceAfter=3,
        textColor=colors.HexColor("#334155"),
    )
    body = ParagraphStyle(
        "Body",
        parent=styles["BodyText"],
        fontName="Helvetica",
        fontSize=10,
        leading=14.5,
        spaceAfter=5,
        textColor=colors.HexColor("#111827"),
    )
    bullet = ParagraphStyle(
        "Bullet",
        parent=body,
        leftIndent=14,
        bulletIndent=4,
        spaceAfter=3,
    )
    code = ParagraphStyle(
        "Code",
        parent=styles["Code"],
        fontName="Courier",
        fontSize=8,
        leading=10,
        leftIndent=8,
        rightIndent=8,
        backColor=colors.HexColor("#f1f5f9"),
        borderPadding=5,
        spaceBefore=4,
        spaceAfter=8,
    )

    class NumberedCanvas(canvas.Canvas):
        def __init__(self, *args, **kwargs):
            canvas.Canvas.__init__(self, *args, **kwargs)
            self._saved_page_states = []

        def showPage(self):
            self._saved_page_states.append(dict(self.__dict__))
            self._startPage()

        def save(self):
            page_count = len(self._saved_page_states)
            for state in self._saved_page_states:
                self.__dict__.update(state)
                self._footer(page_count)
                canvas.Canvas.showPage(self)
            canvas.Canvas.save(self)

        def _footer(self, page_count):
            self.setFont("Helvetica", 7.5)
            self.setFillColor(colors.HexColor("#64748b"))
            self.drawString(
                20 * mm, 10 * mm, "8Byte.ai DevOps Assignment - Challenges and Resolutions"
            )
            self.drawRightString(
                A4[0] - 20 * mm, 10 * mm, f"Page {self._pageNumber} of {page_count}"
            )

    doc = SimpleDocTemplate(
        str(output),
        pagesize=A4,
        leftMargin=20 * mm,
        rightMargin=20 * mm,
        topMargin=18 * mm,
        bottomMargin=18 * mm,
        title="Challenges and Resolutions - 8Byte.ai DevOps Assignment",
        author="Pankaj Sharma",
    )

    story = [
        Paragraph("Challenges and Resolutions", title),
        Paragraph(
            "8Byte.ai DevOps Engineer technical assignment. "
            "A record of the non-obvious problems, the reasoning, and the verification.",
            subtitle,
        ),
    ]

    for kind, text in blocks:
        if kind == "h1":
            if text.lower() not in {"challenges and resolutions"}:
                story.append(Paragraph(inline_markup(text), h1))
        elif kind == "h2":
            story.append(Paragraph(inline_markup(text), h2))
        elif kind == "h3":
            story.append(Paragraph(inline_markup(text), h3))
        elif kind == "p":
            story.append(Paragraph(inline_markup(text), body))
        elif kind == "bullet":
            story.append(Paragraph(inline_markup(text), bullet, bulletText="•"))
        elif kind == "code":
            story.append(XPreformatted(escape(text), code))
        elif kind == "spacer":
            story.append(Spacer(1, 6))

    doc.build(story, canvasmaker=NumberedCanvas)


def build_docx(blocks, output: Path) -> None:
    document = Document()
    document.core_properties.title = "Challenges and Resolutions - 8Byte.ai DevOps Assignment"
    document.core_properties.author = "Pankaj Sharma"

    section = document.sections[0]
    section.top_margin = Inches(0.8)
    section.bottom_margin = Inches(0.8)
    section.left_margin = Inches(0.85)
    section.right_margin = Inches(0.85)

    title = document.add_heading("Challenges and Resolutions", level=0)
    title.alignment = WD_ALIGN_PARAGRAPH.LEFT

    subtitle = document.add_paragraph(
        "8Byte.ai DevOps Engineer technical assignment. "
        "A record of the non-obvious problems, the reasoning, and the verification."
    )
    subtitle.runs[0].font.size = Pt(9.5)
    subtitle.runs[0].font.color.rgb = RGBColor(0x47, 0x55, 0x69)

    for kind, text in blocks:
        if kind == "h1":
            if text.lower() not in {"challenges and resolutions"}:
                document.add_heading(text, level=1)
        elif kind == "h2":
            document.add_heading(text, level=1)
        elif kind == "h3":
            document.add_heading(text, level=2)
        elif kind == "p":
            document.add_paragraph(text)
        elif kind == "bullet":
            document.add_paragraph(text, style="List Bullet")
        elif kind == "code":
            paragraph = document.add_paragraph()
            paragraph.paragraph_format.space_after = Pt(6)
            for index, line in enumerate(text.splitlines()):
                run = paragraph.add_run(line)
                run.font.name = "Courier New"
                run.font.size = Pt(8)
                if index < len(text.splitlines()) - 1:
                    run.add_break()
        elif kind == "spacer":
            document.add_paragraph()

    footer = section.footer.paragraphs[0]
    footer.text = "8Byte.ai DevOps Assignment - Challenges and Resolutions"
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    if footer.runs:
        footer.runs[0].font.size = Pt(8)
        footer.runs[0].font.color.rgb = RGBColor(0x64, 0x74, 0x8B)

    document.save(str(output))


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    blocks = parse_markdown(SOURCE)
    pdf_path = OUT_DIR / "Challenges.pdf"
    docx_path = OUT_DIR / "Challenges.docx"
    build_pdf(blocks, pdf_path)
    build_docx(blocks, docx_path)
    print(f"wrote {pdf_path}")
    print(f"wrote {docx_path}")


if __name__ == "__main__":
    main()
