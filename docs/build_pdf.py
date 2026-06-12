#!/usr/bin/env python3
# 把 QRISC-V996-操作指南.md 转成 PDF(markdown -> HTML -> weasyprint),
# 嵌入 Noto Sans CJK 字体以正确显示中文。改完 .md 重跑本脚本即可更新 PDF。
#   python3 docs/build_pdf.py
import sys, os, markdown
from weasyprint import HTML, CSS
from weasyprint.text.fonts import FontConfiguration

HERE = os.path.dirname(os.path.abspath(__file__))
MD   = os.path.join(HERE, "QRISC-V996-操作指南.md")
PDF  = os.path.join(HERE, "QRISC-V996-操作指南.pdf")

md_text = open(MD, encoding="utf-8").read()
body = markdown.markdown(md_text, extensions=["tables", "fenced_code", "toc"])

CSS_TEXT = """
@page { size: A4; margin: 2cm 1.8cm;
        @bottom-center { content: "QRISC-V996 操作指南  ·  第 " counter(page) " 页";
                         font-size: 9pt; color: #888; } }
body { font-family: "Noto Sans CJK SC","WenQuanYi Zen Hei",sans-serif;
       font-size: 10.5pt; line-height: 1.6; color: #222; }
h1 { font-size: 20pt; color: #1a4d7a; border-bottom: 2px solid #1a4d7a;
     padding-bottom: 6px; }
h2 { font-size: 14pt; color: #1a4d7a; margin-top: 1.4em;
     border-left: 4px solid #1a4d7a; padding-left: 8px; }
h3 { font-size: 12pt; color: #2c6ca0; }
code, pre { font-family: "DejaVu Sans Mono","Noto Sans Mono CJK SC",monospace; }
pre { background: #f4f6f8; border: 1px solid #e1e4e8; border-radius: 4px;
      padding: 8px 10px; font-size: 9pt; line-height: 1.4; white-space: pre-wrap;
      word-wrap: break-word; }
code { background: #f0f2f4; padding: 1px 4px; border-radius: 3px; font-size: 9.2pt; }
pre code { background: none; padding: 0; }
table { border-collapse: collapse; width: 100%; font-size: 9.5pt; margin: 0.6em 0; }
th, td { border: 1px solid #ccd2d8; padding: 4px 8px; text-align: left;
         vertical-align: top; }
th { background: #eef3f7; }
blockquote { border-left: 4px solid #c8d4dd; margin: 0.6em 0; padding: 2px 12px;
             color: #555; background: #fafbfc; }
a { color: #1a6fc0; text-decoration: none; }
"""

html = f"<html><head><meta charset='utf-8'></head><body>{body}</body></html>"
fc = FontConfiguration()
HTML(string=html, base_url=HERE).write_pdf(
    PDF, stylesheets=[CSS(string=CSS_TEXT, font_config=fc)], font_config=fc)
print("✅ 生成", PDF, "(%d bytes)" % os.path.getsize(PDF))
