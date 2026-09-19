#!/usr/bin/env python3
"""Validate the local App Store text package; does not contact or submit to Apple."""

import argparse
import json
from pathlib import Path
import sys
from urllib.parse import urlparse


def validate(path: Path) -> int:
    data = json.loads(path.read_text(encoding="utf-8"))
    errors = []
    character_limits = {
        "name": 30,
        "subtitle": 30,
        "promotionalText": 170,
        "description": 4000,
        "whatsNew": 4000,
    }
    locales = data.get("locales", {})
    if set(locales) != {"en-US", "zh-Hans"}:
        errors.append("Expected exactly the en-US and zh-Hans localizations.")

    markdown = path.with_suffix(".md")
    markdown_text = markdown.read_text(encoding="utf-8") if markdown.exists() else None
    if markdown_text is None:
        errors.append(f"Missing matching copy document: {markdown.name}")

    print("Field                         Characters    UTF-8 bytes    Limit")
    for locale, fields in locales.items():
        for field, limit in character_limits.items():
            value = fields.get(field)
            if not isinstance(value, str) or not value.strip():
                errors.append(f"{locale}.{field}: required nonempty text is missing.")
                continue
            chars, size = len(value), len(value.encode("utf-8"))
            print(f"{locale + '.' + field:<30} {chars:>8} {size:>14}    {limit} chars")
            if chars > limit or (field == "name" and chars < 2):
                errors.append(f"{locale}.{field}: invalid character count {chars}.")
            if markdown_text is not None and f"```text\n{value}\n```" not in markdown_text:
                errors.append(f"{locale}.{field}: JSON and Markdown copy differ.")

        keywords = fields.get("keywords", "")
        if not isinstance(keywords, str) or not keywords:
            errors.append(f"{locale}.keywords: required text is missing.")
        else:
            size = len(keywords.encode("utf-8"))
            print(f"{locale + '.keywords':<30} {len(keywords):>8} {size:>14}    100 bytes")
            if size > 100:
                errors.append(f"{locale}.keywords: {size} UTF-8 bytes exceeds 100.")
            tokens = keywords.split(",")
            if any(not token or token != token.strip() for token in tokens):
                errors.append(f"{locale}.keywords: empty keyword or surrounding spaces.")
            if any(len(token) <= 2 for token in tokens):
                errors.append(f"{locale}.keywords: Apple requires keywords longer than two characters.")
            if len(tokens) != len(set(token.casefold() for token in tokens)):
                errors.append(f"{locale}.keywords: duplicate keyword.")
            if markdown_text is not None and f"```text\n{keywords}\n```" not in markdown_text:
                errors.append(f"{locale}.keywords: JSON and Markdown copy differ.")

        for field in ("supportURL", "marketingURL", "privacyPolicyURL", "privacyChoicesURL"):
            value = fields.get(field)
            if value is None and field in ("marketingURL", "privacyChoicesURL"):
                continue
            if not isinstance(value, str):
                errors.append(f"{locale}.{field}: URL missing or invalid.")
                continue
            url = urlparse(value)
            if url.scheme not in ("http", "https") or not url.netloc:
                errors.append(f"{locale}.{field}: expected a complete HTTP(S) URL.")

    shared = data.get("shared", {})
    notes = shared.get("reviewNotes")
    if not isinstance(notes, str) or not notes.strip():
        errors.append("shared.reviewNotes: required text is missing.")
    else:
        size = len(notes.encode("utf-8"))
        print(f"{'shared.reviewNotes':<30} {len(notes):>8} {size:>14}    4000 bytes")
        if size > 4000:
            errors.append(f"shared.reviewNotes: {size} UTF-8 bytes exceeds 4000.")
        if markdown_text is not None and f"```text\n{notes}\n```" not in markdown_text:
            errors.append("shared.reviewNotes: JSON and Markdown copy differ.")

    if shared.get("primaryLocale") not in locales:
        errors.append("shared.primaryLocale is not a provided localization.")
    if not isinstance(data.get("accountPending"), dict):
        errors.append("Missing accountPending object.")
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("PASS: text limits, copy consistency, and URL syntax.")
    print("Account decisions, public page contents, app behavior, screenshots, signing,")
    print("and App Store Connect acceptance require their separate checks.")
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("metadata", nargs="?", type=Path, default=Path(__file__).with_name("metadata.json"))
    args = parser.parse_args()
    try:
        sys.exit(validate(args.metadata))
    except (OSError, ValueError, TypeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
