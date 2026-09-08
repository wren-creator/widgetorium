#!/usr/bin/env python3
"""Generate the seeded PDF that lives in the dev sandbox's fake export bucket.

Bug 24: the document metadata (Author / Creator / Producer / custom keys) and
the visible body text both leak internal detail -- staff identity, hostnames,
a ticket reference. Run once; the output is committed.

    python3 webapp/tools/make-recon-pdf.py \
        webapp/vhosts/dev/s3/widgetorium-migration-plan.pdf
"""
import sys
import zlib  # noqa: F401  (kept for future stream compression; not used now)

OUT = sys.argv[1] if len(sys.argv) > 1 else "widgetorium-migration-plan.pdf"

body_lines = [
    "Widgetorium storefront -- migration plan (INTERNAL / DRAFT)",
    "",
    "Owner: Frank Mills, Platform Lead (f.mills@corp.widgetorium.lab)",
    "Ticket: PLAT-421   Reviewed: A. Okafor, R. Singh",
    "",
    "1. Cut the storefront over from the single box to split web/db/ftp.",
    "2. Retire admin.corp.widgetorium.lab local accounts once SSO is live.",
    "3. Rotate WIDGETORIUM_API_KEY -- still literal on staging and in the",
    "   old admin/.git checkout.",
    "4. CI stays on jenkins.corp.widgetorium.lab (10.10.20.14) for now.",
    "5. Nightly export keeps landing in the dev s3/ mirror until replaced.",
]

content = "BT /F1 11 Tf 54 738 Td 14 TL\n"
for ln in body_lines:
    esc = ln.replace("\\", r"\\").replace("(", r"\(").replace(")", r"\)")
    content += f"({esc}) Tj T*\n"
content += "ET\n"
content_bytes = content.encode("latin-1")

objs = []
objs.append(b"<< /Type /Catalog /Pages 2 0 R >>")
objs.append(b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>")
objs.append(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
    b"/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>"
)
objs.append(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")
objs.append(
    b"<< /Length " + str(len(content_bytes)).encode() + b" >>\nstream\n"
    + content_bytes + b"\nendstream"
)
info = (
    b"<< /Title (Widgetorium Storefront Migration Plan) "
    b"/Author (Frank Mills <f.mills@corp.widgetorium.lab>) "
    b"/Subject (PLAT-421 storefront split + secret rotation) "
    b"/Keywords (internal; corp.widgetorium.lab; jenkins.corp.widgetorium.lab; PLAT-421) "
    b"/Creator (Widgetorium Docs Toolkit 3.1 on wsl-fmills) "
    b"/Producer (LibreOffice 7.4 / corp template v2) "
    b"/CreationDate (D:20241104020311Z) /ModDate (D:20241104021900Z) >>"
)
objs.append(info)

out = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
offsets = []
for i, obj in enumerate(objs, start=1):
    offsets.append(len(out))
    out += f"{i} 0 obj\n".encode() + obj + b"\nendobj\n"

xref_pos = len(out)
n = len(objs) + 1
out += f"xref\n0 {n}\n".encode()
out += b"0000000000 65535 f \n"
for off in offsets:
    out += f"{off:010d} 00000 n \n".encode()
out += (
    b"trailer\n<< /Size " + str(n).encode()
    + b" /Root 1 0 R /Info 6 0 R >>\nstartxref\n"
    + str(xref_pos).encode() + b"\n%%EOF\n"
)

with open(OUT, "wb") as fh:
    fh.write(out)
print(f"wrote {OUT} ({len(out)} bytes)")
