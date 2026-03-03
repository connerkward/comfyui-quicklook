#!/usr/bin/env python3
"""
Sync .cursor/rules and .cursor/skills from central (this repo) into another repo.
Usage: python3 sync_to_repo.py [target_dir]
  target_dir: repo to update (default: current directory).
Use after cloning a repo so the new repo gets the same Cursor rules and skills as central.
"""
import os
import sys
import shutil

def find_central():
    """Central repo = repo that has .cursor/rules and .cursor/skills (source of truth)."""
    script = os.path.abspath(__file__)
    skill_export_dir = os.path.dirname(script)
    skills_dir = os.path.dirname(skill_export_dir)
    # Script may live in central/skills/... or central/.cursor/skills/...
    parent = os.path.dirname(skills_dir)
    if os.path.basename(parent) == ".cursor":
        central = os.path.dirname(parent)
    else:
        central = parent
    return central

def sync_to_repo(target_dir: str) -> None:
    central = find_central()
    src_rules = os.path.join(central, ".cursor", "rules")
    src_skills = os.path.join(central, ".cursor", "skills")
    dest_cursor = os.path.join(target_dir, ".cursor")
    dest_rules = os.path.join(dest_cursor, "rules")
    dest_skills = os.path.join(dest_cursor, "skills")

    if not os.path.isdir(src_rules) or not os.path.isdir(src_skills):
        print(f"Error: central has no .cursor/rules or .cursor/skills at {central}", file=sys.stderr)
        sys.exit(1)

    os.makedirs(dest_cursor, exist_ok=True)

    # Replace rules
    if os.path.exists(dest_rules):
        shutil.rmtree(dest_rules)
    shutil.copytree(src_rules, dest_rules)
    print(f"  rules -> {dest_rules}")

    # Replace skills
    if os.path.exists(dest_skills):
        shutil.rmtree(dest_skills)
    shutil.copytree(src_skills, dest_skills)
    print(f"  skills -> {dest_skills}")

    print("Sync done.")

def main():
    target = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.getcwd())
    if not os.path.isdir(target):
        print(f"Error: not a directory: {target}", file=sys.stderr)
        sys.exit(1)
    print(f"Syncing from central into {target}")
    sync_to_repo(target)

if __name__ == "__main__":
    main()
