#!/usr/bin/env python3
"""Validate .agents/skills/* against the Agent Skills specification.

https://agentskills.io/specification
- SKILL.md with YAML frontmatter
- name: 1-64 chars, a-z 0-9 and single hyphens, equal to the folder name
- description: 1-1024 chars
- compatibility (optional): max 500 chars
Also checks that the local Claude Code copy (.claude/skills/) is not committed.

Usage: python3 tools/validate-agent-skills.py
"""

import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SKILLS = ROOT / ".agents" / "skills"
NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


def frontmatter(text: str) -> dict[str, str]:
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        raise ValueError("missing frontmatter (first line must be ---)")
    out: dict[str, str] = {}
    for line in lines[1:]:
        if line.strip() == "---":
            return out
        m = re.match(r"^([A-Za-z][\w-]*):\s*(.*)$", line)
        if m:
            out[m.group(1)] = m.group(2).strip().strip('"').strip("'")
    raise ValueError("frontmatter is not closed with ---")


def main() -> int:
    errors: list[str] = []
    if not SKILLS.is_dir():
        print("no .agents/skills/ folder, nothing to check")
        return 0
    for folder in sorted(p for p in SKILLS.iterdir() if p.is_dir()):
        skill = folder / "SKILL.md"
        where = skill.relative_to(ROOT)
        if not skill.is_file():
            errors.append(f"{folder.relative_to(ROOT)}: missing SKILL.md")
            continue
        try:
            fm = frontmatter(skill.read_text(encoding="utf-8"))
        except ValueError as e:
            errors.append(f"{where}: {e}")
            continue
        name = fm.get("name", "")
        desc = fm.get("description", "")
        if not (1 <= len(name) <= 64 and NAME_RE.match(name)):
            errors.append(f"{where}: invalid name {name!r}")
        if name != folder.name:
            errors.append(f"{where}: name {name!r} must equal folder {folder.name!r}")
        if not 1 <= len(desc) <= 1024:
            errors.append(f"{where}: description must be 1-1024 chars (has {len(desc)})")
        if len(fm.get("compatibility", "")) > 500:
            errors.append(f"{where}: compatibility must be at most 500 chars")
        print(f"ok  {name}  ({len(desc)} chars description)")

    tracked = subprocess.run(
        ["git", "ls-files", ".claude/skills"],
        cwd=ROOT, capture_output=True, text=True, check=False,
    ).stdout.strip()
    if tracked:
        errors.append(
            ".claude/skills/ is committed; it is a local copy made by "
            "tools/sync-agent-skills.sh. Edit .agents/skills/ instead:\n" + tracked
        )

    for e in errors:
        print(f"ERROR {e}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
