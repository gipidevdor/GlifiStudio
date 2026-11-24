#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Check every literal GlifiFailure construction against GS-API-001 § 8 (RQ-058).

The admitted retry dispositions and retained states are read from
`GlifiFailureTaxonomy` in GlifiFailure.swift, so the script and the runtime
assertion share one table. A construction with a literal category must use either
literal values admitted for that category or the taxonomy defaults.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ROOT / "Packages/GlifiCore/Sources"
TAXONOMY = SOURCES / "GlifiCore/GlifiFailure.swift"
SITE = re.compile(
    r"category:\s*\.(\w+),\s*operation:\s*[^,]+,\s*retryDisposition:\s*([^,]+?),"
    r"\s*retainedState:\s*([^,]+?),\s*messageKey:",
    re.S,
)


def table(source: str, name: str) -> dict[str, set[str]]:
    """Parse one `[Category: Set<...>]` dictionary literal of the taxonomy."""
    start = source.index(f"public static let {name}:")
    body = source[source.index("[", source.index("=", start)) : source.index("]\n", start)]
    return {
        category: set(re.findall(r"\.(\w+)", values))
        for category, values in re.findall(r"\.(\w+):\s*\[([^\]]*)\]", body)
    }


def main() -> int:
    source = TAXONOMY.read_text(encoding="utf-8")
    retry, retained = table(source, "retry"), table(source, "retained")
    errors: list[str] = []
    sites = 0
    for path in sorted(SOURCES.rglob("*.swift")):
        text = path.read_text(encoding="utf-8")
        for match in SITE.finditer(text):
            category, retry_expr, retained_expr = (part.strip() for part in match.groups())
            if category not in retry:
                continue
            sites += 1
            line = text[: match.start()].count("\n") + 1
            where = f"{path.relative_to(ROOT)}:{line}"
            for expression, admitted, label in (
                (retry_expr, retry[category], "retryDisposition"),
                (retained_expr, retained[category], "retainedState"),
            ):
                literal = re.fullmatch(r"\.(\w+)", expression)
                if literal and literal.group(1) not in admitted:
                    errors.append(f"{where}: {label} .{literal.group(1)} non ammesso per .{category}")
                elif not literal and "GlifiFailureTaxonomy" not in expression:
                    values = set(re.findall(r"\.(\w+)", expression)) - {category}
                    outside = sorted(v for v in values if v not in admitted and v[0].islower())
                    known = retry.keys() | {v for s in retained.values() for v in s}
                    outside = [v for v in outside if v in known or v in {s for r in retry.values() for s in r}]
                    if outside:
                        errors.append(f"{where}: {label} può produrre {outside} per .{category}")
    if errors:
        print("Tassonomia delle failure violata:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(f"Failure taxonomy: {sites} siti con categoria letterale conformi a GS-API-001 § 8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
