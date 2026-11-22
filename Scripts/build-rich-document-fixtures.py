#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause
"""Rebuild original synthetic PDF/EPUB import fixtures using only the standard library."""
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parent.parent / "Fixtures/DocumentImport/v1"
root.mkdir(parents=True, exist_ok=True)
# A minimal two-page PDF with an embedded text layer and a deterministic cross-reference table.
objects = [
    b"<< /Type /Catalog /Pages 2 0 R >>",
    b"<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>",
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 6 0 R >>",
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 7 0 R >>",
    b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
]
for text in [b"La casa e il mare.", b"Il giardino e la casa."]:
    stream = b"BT /F1 16 Tf 72 720 Td (" + text + b") Tj ET\n"
    objects.append(b"<< /Length " + str(len(stream)).encode() + b" >>\nstream\n" + stream + b"endstream")
pdf = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
offsets = [0]
for index, value in enumerate(objects, 1):
    offsets.append(len(pdf))
    pdf += str(index).encode() + b" 0 obj\n" + value + b"\nendobj\n"
xref = len(pdf)
pdf += f"xref\n0 {len(offsets)}\n0000000000 65535 f \n".encode()
for offset in offsets[1:]:
    pdf += f"{offset:010} 00000 n \n".encode()
pdf += f"trailer\n<< /Size {len(offsets)} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode()
(root / "digital.pdf").write_bytes(pdf)
entries = [
    ("mimetype", b"application/epub+zip", zipfile.ZIP_STORED),
    ("META-INF/container.xml", b'''<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="Book/package.opf" media-type="application/oebps-package+xml"/></rootfiles></container>''', zipfile.ZIP_DEFLATED),
    ("Book/package.opf", b'''<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">synthetic-glifi-book</dc:identifier><dc:title>Libro sintetico</dc:title><dc:language>it</dc:language></metadata><manifest><item id="a" href="a.xhtml" media-type="application/xhtml+xml"/><item id="b" href="b.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="b"/><itemref idref="a"/></spine></package>''', zipfile.ZIP_DEFLATED),
    ("Book/a.xhtml", '''<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml"><head><title>A</title></head><body><p>La città e il giardino.</p></body></html>'''.encode(), zipfile.ZIP_DEFLATED),
    ("Book/b.xhtml", '''<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml"><head><title>B</title></head><body><p>La casa e il mare.</p><p>Una città.</p></body></html>'''.encode(), zipfile.ZIP_DEFLATED),
]
with zipfile.ZipFile(root / "book.epub", "w") as archive:
    for name, value, compression in entries:
        info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
        info.compress_type = compression
        info.create_system = 3
        info.external_attr = (0o100644 << 16)
        archive.writestr(info, value)
print("Built two original synthetic document-import fixtures")
