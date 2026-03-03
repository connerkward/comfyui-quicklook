import os
import shutil
import glob
import re

# Paths
BASE_DIR = "/Users/CONWARD/dev/central"
SOURCE_RULES = os.path.join(BASE_DIR, "rules")
SOURCE_SKILLS = os.path.join(BASE_DIR, "skills")

DEST_AGENT_RULES = os.path.join(BASE_DIR, ".agent/rules")
DEST_AGENT_SKILLS = os.path.join(BASE_DIR, ".agent/skills")

DEST_CLAUDE_RULES = os.path.join(BASE_DIR, ".claude/rules")
DEST_CLAUDE_SKILLS = os.path.join(BASE_DIR, ".claude/skills")

DEST_CURSOR_RULES = os.path.join(BASE_DIR, ".cursor/rules")
DEST_CURSOR_SKILLS = os.path.join(BASE_DIR, ".cursor/skills")

def ensure_dir(path):
    if not os.path.exists(path):
        os.makedirs(path)

def read_file(path):
    with open(path, 'r') as f:
        return f.read()

def write_file(path, content):
    with open(path, 'w') as f:
        f.write(content)

def parse_frontmatter(content):
    match = re.search(r'^---\n(.*?)\n---', content, re.DOTALL)
    if match:
        return match.group(1), content[match.end():]
    return "", content

def update_frontmatter_for_agent(frontmatter, content):
    # .agent rules mostly need 'trigger: always_on' if not present
    # and might not use 'applyTo' or 'priority' the same way.
    # For now, we'll append/ensure trigger exists.
    if "trigger:" not in frontmatter:
        frontmatter += "\ntrigger: always_on"
    return f"---\n{frontmatter}\n---{content}"

def export_skills():
    print("Exporting Skills...")
    skills = [d for d in os.listdir(SOURCE_SKILLS) if os.path.isdir(os.path.join(SOURCE_SKILLS, d))]
    
    for skill in skills:
        src_skill_dir = os.path.join(SOURCE_SKILLS, skill)
        
        # .agent
        dest_agent = os.path.join(DEST_AGENT_SKILLS, skill)
        if os.path.exists(dest_agent): shutil.rmtree(dest_agent)
        shutil.copytree(src_skill_dir, dest_agent)
        
        # .claude
        dest_claude = os.path.join(DEST_CLAUDE_SKILLS, skill)
        if os.path.exists(dest_claude): shutil.rmtree(dest_claude)
        shutil.copytree(src_skill_dir, dest_claude)

        # .cursor
        dest_cursor = os.path.join(DEST_CURSOR_SKILLS, skill)
        if os.path.exists(dest_cursor): shutil.rmtree(dest_cursor)
        shutil.copytree(src_skill_dir, dest_cursor)
        
        print(f"  Synced skill: {skill}")

def export_rules():
    print("Exporting Rules...")
    # Source rules are flat .md files
    rule_files = glob.glob(os.path.join(SOURCE_RULES, "*.md"))
    
    for rule_path in rule_files:
        filename = os.path.basename(rule_path)
        name_no_ext = os.path.splitext(filename)[0]
        
        # Basic normalize: if file is "software-engineering-rule.md", name is "software-engineering-rule"
        # .agent prefers folders: .agent/rules/software-engineering/RULE.md
        # We might need to clean up the name for the folder (remove "-rule" suffix if desired, or keep it)
        # For simplicity/matching existing, let's keep it mostly as is but check conventions.
        # Existing .agent rule: "software-engineering" (folder) -> "RULE.md"
        # Source file: "software-engineering-rule.md"
        
        # Heuristic: remove "-rule" suffix for folder name if present
        folder_name = name_no_ext.replace("-rule", "")
        
        content = read_file(rule_path)
        fm, body = parse_frontmatter(content)
        
        # 1. Export to .agent (Directory structure)
        agent_rule_dir = os.path.join(DEST_AGENT_RULES, folder_name)
        ensure_dir(agent_rule_dir)
        agent_content = update_frontmatter_for_agent(fm, body)
        write_file(os.path.join(agent_rule_dir, "RULE.md"), agent_content)
        
        # 2. Export to .claude (Flat .md)
        # .claude seems to use "-rule.md" convention based on finding.
        # Source is typically "-rule.md", so copy directly.
        destination_filename = filename
        if not filename.endswith("-rule.md") and "-rule" not in filename:
             destination_filename = f"{name_no_ext}-rule.md"
             
        ensure_dir(DEST_CLAUDE_RULES)
        write_file(os.path.join(DEST_CLAUDE_RULES, destination_filename), content)
        
        # 3. Export to .cursor (Flat .mdc)
        # .cursor uses .mdc extension
        mdc_filename = f"{folder_name}.mdc" # or name_no_ext.mdc
        # Existing was `software-engineering.mdc` from `software-engineering-rule` id?
        # Let's use the folder_name (cleaner) for the .mdc filename
        
        ensure_dir(DEST_CURSOR_RULES)
        write_file(os.path.join(DEST_CURSOR_RULES, mdc_filename), content)
        
        print(f"  Synced rule: {filename} -> Agent({folder_name}), Claude({destination_filename}), Cursor({mdc_filename})")

def clear_dir(path):
    """Remove all contents of path (dir stays); skip if path doesn't exist."""
    if not os.path.isdir(path):
        return
    for name in os.listdir(path):
        p = os.path.join(path, name)
        if os.path.isdir(p):
            shutil.rmtree(p)
        else:
            os.remove(p)

def main():
    for d in (DEST_AGENT_RULES, DEST_AGENT_SKILLS, DEST_CLAUDE_RULES, DEST_CLAUDE_SKILLS, DEST_CURSOR_RULES, DEST_CURSOR_SKILLS):
        ensure_dir(d)
        clear_dir(d)
    export_skills()
    export_rules()
    print("Export Complete.")

if __name__ == "__main__":
    main()
