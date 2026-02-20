#!/usr/bin/env python3
"""
Update Korean string literals in Swift files to English equivalents.
Uses the key_mapping.json from the Localizable.xcstrings transformation,
plus additional manual mappings for strings not in the xcstrings file.
"""

import json
import os
import re
import glob

def load_key_mapping(mapping_path):
    with open(mapping_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def build_replacement_map(key_mapping):
    """Build a comprehensive mapping including extra strings not in xcstrings."""
    # Start with the xcstrings key mapping
    replacements = dict(key_mapping)

    # Add extra strings found in Swift files that aren't xcstrings keys
    # These are hardcoded strings, toast messages, notification content, etc.
    extra = {
        # Toast messages (TimerScreenViewModel)
        "⌚️ Watch에서 타이머 시작": "⌚️ Timer started from Watch",
        "⌚️ Watch에서 일시정지": "⌚️ Paused from Watch",
        "⌚️ Watch에서 재개": "⌚️ Resumed from Watch",
        "⌚️ Watch에서 중지": "⌚️ Stopped from Watch",
        "⚠️ 알림 권한 없이 시작됨": "⚠️ Started without notification permission",
        "시작": "Start",
        "Watch에서 시작": "Started from Watch",

        # Timer.swift default messages
        # These use String(localized:) so they match xcstrings keys - handled by key_mapping

        # Notification content (AppStateManager)
        "Toki 테스트 알림": "Toki Test Notification",
        "알림이 정상적으로 작동합니다! 🎉": "Notifications are working correctly! 🎉",

        # Watch notification content
        "설정한 시간이 종료되었습니다.": "Your set time has ended.",
        "지정 알림": "Custom Alert",

        # TokiAlarmManager error messages
        "알림 권한이 필요합니다": "Notification permission is required",
        "알람 스케줄링에 실패했습니다": "Failed to schedule alarm",

        # Watch NotificationService
        "초 후": "sec later",

        # ring.swift enum raw values - these are stored/persisted, careful!
        # We should NOT change enum raw values as they may be persisted in UserDefaults
        # Instead, the display strings use String(localized:) which references xcstrings

        # PushNotice
        "타이머가 종료되었습니다!": "Timer has finished!",

        # Timer.swift - label presets dictionary keys
        "발표": "Presentation",
        "멘토링": "Mentoring",
        "회의": "Meeting",
        "휴식": "Break",
        "집중": "Focus",
        "운동": "Exercise",
        "공부": "Study",
        "독서": "Reading",

        # macOS fallback text
        "macOS에서는 기본 알림만 지원됩니다": "Only basic notifications are supported on macOS",

        # Live Activity fallback
        "타이머": "Timer",
    }

    replacements.update(extra)
    return replacements

def replace_korean_in_file(filepath, replacements):
    """Replace Korean strings in a Swift file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content

    # Sort replacements by length (longest first) to avoid partial replacements
    sorted_replacements = sorted(replacements.items(), key=lambda x: len(x[0]), reverse=True)

    for korean, english in sorted_replacements:
        # Replace within string literals (quoted strings)
        # Handle both "..." and multi-line strings
        # We need to be careful to only replace within string contexts

        # Escape special regex chars in the Korean text
        escaped_korean = re.escape(korean)

        # Replace in various string contexts:
        # 1. Inside double-quoted strings: "korean text"
        # 2. Inside String(localized: "korean text")
        # 3. Inside Text("korean text")
        # 4. Inside .alert("korean text", ...)
        # etc.

        # Simple approach: replace the Korean text wherever it appears in quoted context
        # We do a direct string replacement since the Korean text is unique enough
        content = content.replace(korean, english)

    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    return False

def find_remaining_korean(filepath):
    """Find any remaining Korean characters in string literals."""
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    remaining = []
    for i, line in enumerate(lines, 1):
        # Skip comment-only lines
        stripped = line.strip()
        if stripped.startswith('//') or stripped.startswith('///') or stripped.startswith('/*') or stripped.startswith('*'):
            continue
        # Skip print/debug statements
        if 'print(' in line:
            continue

        # Check for Korean in string literals
        # Find all quoted strings
        in_string = False
        for match in re.finditer(r'"([^"]*)"', line):
            text = match.group(1)
            if any('\uAC00' <= c <= '\uD7AF' for c in text):
                remaining.append((i, line.rstrip(), text))

    return remaining

def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    mapping_path = os.path.join(base_dir, "Toki", "key_mapping.json")

    key_mapping = load_key_mapping(mapping_path)
    replacements = build_replacement_map(key_mapping)

    # Find all Swift files
    search_dirs = [
        os.path.join(base_dir, "Toki"),
        os.path.join(base_dir, "WatchToki Watch App"),
        os.path.join(base_dir, "Shared"),
        os.path.join(base_dir, "TokiAlarm"),
    ]

    swift_files = []
    for d in search_dirs:
        swift_files.extend(glob.glob(os.path.join(d, "**", "*.swift"), recursive=True))

    print(f"Found {len(swift_files)} Swift files to process")
    print(f"Using {len(replacements)} replacement mappings")
    print()

    modified_files = []
    for filepath in sorted(swift_files):
        if replace_korean_in_file(filepath, replacements):
            rel = os.path.relpath(filepath, base_dir)
            modified_files.append(rel)
            print(f"  Modified: {rel}")

    print(f"\nModified {len(modified_files)} files")

    # Check for remaining Korean in string literals (excluding comments and prints)
    print("\n--- Remaining Korean in string literals (excluding comments/prints) ---")
    has_remaining = False
    for filepath in sorted(swift_files):
        remaining = find_remaining_korean(filepath)
        if remaining:
            rel = os.path.relpath(filepath, base_dir)
            for line_num, line, text in remaining:
                has_remaining = True
                print(f"  {rel}:{line_num}: {text}")

    if not has_remaining:
        print("  None found!")

if __name__ == "__main__":
    main()
