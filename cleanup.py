import os
import re

grill_dir = "DOCS/Handoff for agents and Todos/ANTIGRAVRITY_GRILL"
claude_path = os.path.join(grill_dir, "claude_sol.md")
issues_solved_path = "DOCS/Handoff for agents and Todos/issues_solved.md"

solved_sections = {}
current_file = None

# Pass 1: Parse what is solved
with open(claude_path, 'r') as f:
    for line in f:
        m_file = re.match(r"^## \d+\. `([^`]+)`:", line)
        if m_file:
            current_file = m_file.group(1)
            if current_file not in solved_sections:
                solved_sections[current_file] = []
        
        m_sec = re.match(r"^### (\d+\.\d+).*✅", line)
        if m_sec and current_file:
            solved_sections[current_file].append(m_sec.group(1))

def process_source_file(filename, solved_ids):
    filepath = os.path.join(grill_dir, filename)
    if not os.path.exists(filepath):
        return ""
        
    with open(filepath, 'r') as f:
        lines = f.readlines()
        
    remaining = []
    solved = []
    current_sec_id = None
    
    for line in lines:
        m_sec = re.match(r"^### (\d+\.\d+)", line)
        if m_sec:
            current_sec_id = m_sec.group(1)
        elif line.startswith("## ") or line.startswith("---") or line.startswith("# "):
            current_sec_id = None
            
        if current_sec_id and current_sec_id in solved_ids:
            solved.append(line)
        else:
            remaining.append(line)
            
    with open(filepath, 'w') as f:
        f.writelines(remaining)
        
    return "".join(solved)

def process_claude_sol():
    filepath = claude_path
    if not os.path.exists(filepath):
        return ""
        
    with open(filepath, 'r') as f:
        lines = f.readlines()
        
    remaining = []
    solved = []
    current_sec_id = None
    current_file_tracking = None
    
    for line in lines:
        m_file = re.match(r"^## \d+\. `([^`]+)`:", line)
        if m_file:
            current_file_tracking = m_file.group(1)
            current_sec_id = None
            remaining.append(line)
            continue
            
        m_sec = re.match(r"^### (\d+\.\d+)", line)
        if m_sec:
            current_sec_id = m_sec.group(1)
        elif line.startswith("## ") or line.startswith("---") or line.startswith("# "):
            current_sec_id = None
            
        # Check if solved
        is_solved = False
        if current_sec_id and current_file_tracking:
            if current_sec_id in solved_sections.get(current_file_tracking, []):
                is_solved = True
                
        if is_solved:
            solved.append(line)
        else:
            remaining.append(line)
            
    with open(filepath, 'w') as f:
        f.writelines(remaining)
        
    return "".join(solved)

all_solved_content = []

# Process the 4 source files
for fname, ids in solved_sections.items():
    if not ids: continue
    all_solved_content.append(f"## {fname}\n")
    solved_text = process_source_file(fname, ids)
    all_solved_content.append(solved_text)
    all_solved_content.append("\n")

# Process claude_sol.md
all_solved_content.append(f"## claude_sol.md\n")
solved_text = process_claude_sol()
all_solved_content.append(solved_text)
all_solved_content.append("\n")

with open(issues_solved_path, 'w') as f:
    f.write("# Issues Solved (from ANTIGRAVITY_GRILL)\n\n")
    f.write("".join(all_solved_content))

print(f"Cleanup complete. Found {sum(len(v) for v in solved_sections.values())} solved items.")
