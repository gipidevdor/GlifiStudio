#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Build the Italian gold corpus from a public-domain source text.

The annotation follows the `it-token-v1` contract of GS-LNG-001 and is written **independently of
the Swift tokenizer**: it is a second implementation of the same contract, so a disagreement is a
question to adjudicate, not a result to copy. Running this script regenerates the annotation from
the source text; the adjudicated corrections live in `adjudications.json` and are applied here.
"""

from __future__ import annotations

import json
import re
import sys
import unicodedata
from pathlib import Path

PROJECT_DIRECTORY = Path(__file__).resolve().parent.parent
CORPUS_DIRECTORY = PROJECT_DIRECTORY / "Fixtures/Linguistics/it-gold-v1"
APOSTROPHES = "'’"
# Forme elise che conservano l'apostrofo finale: inventario versionato, non euristica.
TRAILING_ELISIONS = {"po", "mo", "be", "to", "va", "da", "fa", "di", "te"}
HYPHENS = "-‐‑"


def is_word_character(character: str) -> bool:
    """Letters and digits, accents included; the contract keeps the surface intact."""
    return character.isalnum()


def tokenize(text: str) -> list[dict[str, object]]:
    """Tokens as UTF-8 intervals, with elision components when the token contains an apostrophe."""
    tokens: list[dict[str, object]] = []
    prefix_bytes = [0]
    for character in text:
        prefix_bytes.append(prefix_bytes[-1] + len(character.encode("utf-8")))
    index = 0
    while index < len(text):
        if not is_word_character(text[index]):
            index += 1
            continue
        start = index
        while index < len(text):
            character = text[index]
            if is_word_character(character):
                index += 1
                continue
            following = text[index + 1] if index + 1 < len(text) else ""
            # Apostrofo interno fra lettere (elisione) o apostrofo finale di forma elisa.
            if character in APOSTROPHES:
                if is_word_character(following):
                    index += 1
                    continue
                if text[start:index].lower() in TRAILING_ELISIONS:
                    index += 1
                break
            # Trattino interno fra lettere o cifre: un solo token.
            if character in HYPHENS and is_word_character(following):
                index += 1
                continue
            break
        surface = text[start:index]
        token: dict[str, object] = {
            "start": prefix_bytes[start],
            "end": prefix_bytes[index],
            "surface": surface,
        }
        apostrophe = next(
            (position for position, char in enumerate(surface) if char in APOSTROPHES), None
        )
        if apostrophe is not None and apostrophe + 1 < len(surface):
            cut = start + apostrophe + 1
            token["components"] = [
                {"start": prefix_bytes[start], "end": prefix_bytes[cut], "surface": text[start:cut]},
                {"start": prefix_bytes[cut], "end": prefix_bytes[index], "surface": text[cut:index]},
            ]
        tokens.append(token)
    return tokens


def split_sentences(text: str) -> list[dict[str, object]]:
    """Sentence intervals: a run of terminators closes a sentence unless it is an abbreviation."""
    prefix_bytes = [0]
    for character in text:
        prefix_bytes.append(prefix_bytes[-1] + len(character.encode("utf-8")))
    sentences: list[dict[str, object]] = []
    start = 0
    index = 0
    while index < len(text):
        if text[index] in ".!?":
            end = index + 1
            while end < len(text) and text[end] in ".!?":
                end += 1
            rest = text[end:]
            closes = not rest.strip() or re.match(r"\s+[«\"A-ZÀ-ÖØ-Þ]", rest) is not None
            if closes:
                surface = text[start:end].strip()
                if surface:
                    offset = text.index(surface, start, end)
                    sentences.append(
                        {
                            "start": prefix_bytes[offset],
                            "end": prefix_bytes[offset + len(surface)],
                            "surface": surface,
                        }
                    )
                start = end
            index = end
            continue
        index += 1
    remainder = text[start:].strip()
    if remainder:
        offset = text.index(remainder, start)
        sentences.append(
            {
                "start": prefix_bytes[offset],
                "end": prefix_bytes[offset + len(remainder)],
                "surface": remainder,
            }
        )
    return sentences


def main() -> int:
    """Regenerate `token-boundaries.json` from the source text and the adjudications."""
    source = (CORPUS_DIRECTORY / "source/pinocchio-capitolo-1.txt").read_text(encoding="utf-8")
    adjudications = json.loads((CORPUS_DIRECTORY / "adjudications.json").read_text(encoding="utf-8"))
    overrides = {item["caseID"]: item for item in adjudications["decisions"]}

    cases = []
    for index, paragraph in enumerate(p for p in source.split("\n") if p.strip()):
        text = paragraph.strip()
        if unicodedata.normalize("NFC", text) != text:
            print(f"paragrafo {index}: il testo deve essere in NFC", file=sys.stderr)
            return 1
        case_id = f"pinocchio-{index:02d}"
        case = {
            "id": case_id,
            "class": "prosa-narrativa-ottocentesca",
            "text": text,
            "utf8Length": len(text.encode("utf-8")),
            "tokens": tokenize(text),
            "sentences": split_sentences(text),
        }
        decision = overrides.get(case_id)
        if decision:
            case["tokens"] = decision.get("tokens", case["tokens"])
            case["sentences"] = decision.get("sentences", case["sentences"])
        cases.append(case)

    document = {
        "schema": "studio.glifi.linguistic-fixture",
        "schemaVersion": 1,
        "coordinateSpace": "sourceUTF8",
        "intervalConvention": "half-open",
        "cases": cases,
    }
    (CORPUS_DIRECTORY / "token-boundaries.json").write_text(
        json.dumps(document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    tokens = sum(len(case["tokens"]) for case in cases)
    sentences = sum(len(case["sentences"]) for case in cases)
    print(f"Gold italiano: {len(cases)} casi, {tokens} token, {sentences} frasi")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
