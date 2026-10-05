#!/usr/bin/env python3
"""Extract touched paths from Codex PreToolUse JSON; never execute patch text."""

import json
import sys

PATCH_START = "*** Begin Patch"
PATCH_END = "*** End Patch"
FILE_HEADER_PREFIXES = (
    "*** Add File: ",
    "*** Update File: ",
    "*** Delete File: ",
    "*** Move to: ",
)


def patch_paths(payload):
    """Return file paths from patch headers, including both ends of a rename."""
    if not isinstance(payload, dict) or payload.get("tool_name") != "apply_patch":
        return []
    tool_input = payload.get("tool_input")
    if not isinstance(tool_input, dict):
        return []
    patch = tool_input.get("command")
    if not isinstance(patch, str):
        return []
    lines = patch.strip().splitlines()
    if len(lines) < 2 or lines[0] != PATCH_START or lines[-1] != PATCH_END:
        return []
    paths = []
    for line in lines[1:-1]:
        # Hunk contents start with ' ', '+' or '-', so embedded examples do
        # not count as file headers. Include both endpoints of a rename.
        for prefix in FILE_HEADER_PREFIXES:
            if line.startswith(prefix):
                path = line[len(prefix) :].strip()
                if path:
                    paths.append(path)
                break
    return paths


def main():
    """Read one hook event and print its paths without blocking on bad input."""
    try:
        paths = patch_paths(json.load(sys.stdin))
        if paths:
            print("\n".join(paths))
    except (ValueError, OSError, RecursionError):
        # Advisory hook: malformed input must not block editing.
        pass


if __name__ == "__main__":
    main()
