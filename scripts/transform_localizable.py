#!/usr/bin/env python3
"""
Transform Localizable.xcstrings to use English as source language.

Rules:
1. Change sourceLanguage from "ko" to "en"
2. For Korean-text keys that have an "en" translation:
   - New key = the English translation value
   - Add "ko" localization with the old Korean key as value
   - Remove the "en" localization (since the key IS the English text)
3. For keys already in English or are symbols/numbers/format strings: keep as-is
   but ensure "ko" translation exists if there was a Korean key
4. For keys with extractionState "stale", keep them as stale
5. Keys that are onboarding_*, share_app_message etc. (programmatic keys): keep as-is
"""

import json
import re
import sys
import os

def is_korean(text):
    """Check if text contains Korean characters."""
    for char in text:
        if '\uAC00' <= char <= '\uD7AF':  # Hangul Syllables
            return True
        if '\u3130' <= char <= '\u318F':  # Hangul Compatibility Jamo
            return True
    return False

def is_symbol_or_format_key(key):
    """Check if key is a symbol, number, or format string only (no real text)."""
    # Empty string, single symbols, just format specifiers
    if key in ("", ":", "•", ">>", "notice", "alarmID"):
        return True
    # Pure format strings like "%lld", "%lld / %lld", "%lld %@"
    if re.match(r'^[%\d\s\/@$lld]*$', key):
        return True
    return False

def is_programmatic_key(key):
    """Check if key is a programmatic identifier (not user-visible text)."""
    programmatic_prefixes = [
        "onboarding_", "share_app_message",
        "Configuration", "Favorite Emoji", "A an example",
        "This is an example", "Timer Name Configuration",
    ]
    for prefix in programmatic_prefixes:
        if key.startswith(prefix):
            return True
    return False

def transform_localizable(input_path, output_path):
    with open(input_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    new_strings = {}
    # Build a mapping from old Korean key -> new English key for Swift file updates
    key_mapping = {}

    for key, entry in data["strings"].items():
        localizations = entry.get("localizations", {})
        extraction_state = entry.get("extractionState")
        comment = entry.get("comment")

        # Case 1: Symbol/format-only keys - keep as-is
        if is_symbol_or_format_key(key):
            new_strings[key] = entry
            continue

        # Case 2: Programmatic keys (onboarding_*, share_app_message, etc.) - keep as-is
        if is_programmatic_key(key):
            new_strings[key] = entry
            continue

        # Case 3: English-text keys (no Korean in key) - keep as-is
        if not is_korean(key):
            new_strings[key] = entry
            continue

        # Case 4: Korean-text key WITH English translation
        en_loc = localizations.get("en", {})
        en_value = en_loc.get("stringUnit", {}).get("value", "")

        if en_value:
            # New key is the English translation
            new_key = en_value

            # Build new entry
            new_entry = {}

            # Preserve extractionState if it was stale
            if extraction_state:
                new_entry["extractionState"] = extraction_state

            # Preserve comment if present
            if comment:
                new_entry["comment"] = comment

            # Build new localizations with just "ko"
            ko_value = key  # The old Korean key becomes the ko value

            # Check if there was already a "ko" localization with a different value
            existing_ko = localizations.get("ko", {})
            existing_ko_value = existing_ko.get("stringUnit", {}).get("value", "")
            existing_ko_state = existing_ko.get("stringUnit", {}).get("state", "translated")

            if existing_ko_value and existing_ko_value != ko_value:
                # There's an explicit ko localization that differs from the key
                # Use the explicit one (it likely has positional specifiers)
                ko_final_value = existing_ko_value
                ko_state = existing_ko_state
            else:
                ko_final_value = ko_value
                ko_state = "translated"

            new_entry["localizations"] = {
                "ko": {
                    "stringUnit": {
                        "state": ko_state,
                        "value": ko_final_value
                    }
                }
            }

            new_strings[new_key] = new_entry
            key_mapping[key] = new_key
        else:
            # Korean key but NO English translation - needs manual handling
            # For now, keep as-is (these are likely only used in Korean context)
            # Examples: "App Store에서 리뷰 작성", "디버그 정보", "완료 횟수 초기화", "타이머 완료 횟수: %lld회"
            # These don't have en translations, so we need to provide one
            # We'll create a reasonable English key and add ko localization

            # Map of known untranslated Korean keys to English
            manual_translations = {
                "App Store에서 리뷰 작성": "Write a Review on App Store",
                "디버그 정보": "Debug Info",
                "완료 횟수 초기화": "Reset Completion Count",
                "타이머 완료 횟수: %lld회": "Timer completions: %lld",
            }

            if key in manual_translations:
                new_key = manual_translations[key]
                new_entry = {}
                if extraction_state:
                    new_entry["extractionState"] = extraction_state
                if comment:
                    new_entry["comment"] = comment
                new_entry["localizations"] = {
                    "ko": {
                        "stringUnit": {
                            "state": "translated",
                            "value": key
                        }
                    }
                }
                new_strings[new_key] = new_entry
                key_mapping[key] = new_key
            else:
                # Keep as-is (shouldn't happen with current data)
                print(f"WARNING: Korean key without English translation: {key}")
                new_strings[key] = entry

    # Build output
    output = {
        "sourceLanguage": "en",
        "strings": dict(sorted(new_strings.items(), key=lambda x: x[0])),
        "version": data["version"]
    }

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    # Save key mapping for Swift file updates
    mapping_path = os.path.join(os.path.dirname(output_path), 'key_mapping.json')
    with open(mapping_path, 'w', encoding='utf-8') as f:
        json.dump(key_mapping, f, ensure_ascii=False, indent=2)

    print(f"Transformed {len(data['strings'])} entries -> {len(new_strings)} entries")
    print(f"Key mapping saved to {mapping_path}")
    print(f"Mapped {len(key_mapping)} Korean keys to English keys")

    return key_mapping

if __name__ == "__main__":
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    input_path = os.path.join(base_dir, "Toki", "Localizable.xcstrings")
    output_path = input_path  # Overwrite in place

    key_mapping = transform_localizable(input_path, output_path)

    # Print the mapping for reference
    print("\n--- Key Mapping (Korean -> English) ---")
    for ko, en in sorted(key_mapping.items()):
        print(f"  {ko!r} -> {en!r}")
