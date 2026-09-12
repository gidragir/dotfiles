#!/usr/bin/env bash
#
# obsidian-helper.sh — CLI helper for Noctalia Obsidian Companion Plugin
#

set -eo pipefail

COMMAND="${1:-status}"
shift || true

# Defaults
DEFAULT_VAULT="/data/obsidian"
DEFAULT_DAILY_FOLDER="DAILY"

get_vault() {
    local v="${1:-${OBSIDIAN_VAULT:-$DEFAULT_VAULT}}"
    echo "$v"
}

get_daily_folder() {
    local d="${1:-$DEFAULT_DAILY_FOLDER}"
    echo "$d"
}

find_daily_note() {
    local vault="$1"
    local daily_folder="$2"
    local today_iso today_ru
    today_iso=$(date '+%Y-%m-%d')
    today_ru=$(date '+%d.%m.%Y')

    local candidates=(
        "$vault/$daily_folder/$today_iso.md"
        "$vault/$daily_folder/$today_ru.md"
        "$vault/$today_iso.md"
        "$vault/$today_ru.md"
    )

    for c in "${candidates[@]}"; do
        if [[ -f "$c" ]]; then
            echo "$c"
            return 0
        fi
    done
    # Default target if not yet created
    echo "$vault/$daily_folder/$today_iso.md"
}

cmd_status() {
    local vault
    vault=$(get_vault "$1")
    local daily_folder
    daily_folder=$(get_daily_folder "$2")

    python3 - <<EOF
import os, json, re, datetime, subprocess

vault = os.path.expanduser("$vault")
daily_folder = "$daily_folder"

today_iso = datetime.date.today().strftime('%Y-%m-%d')
today_ru = datetime.date.today().strftime('%d.%m.%Y')
today_formatted = datetime.date.today().strftime('%d %b %Y')

candidates = [
    os.path.join(vault, daily_folder, f"{today_iso}.md"),
    os.path.join(vault, daily_folder, f"{today_ru}.md"),
    os.path.join(vault, f"{today_iso}.md"),
    os.path.join(vault, f"{today_ru}.md"),
]

daily_file = None
exists = False
for c in candidates:
    if os.path.isfile(c):
        daily_file = c
        exists = True
        break

if not daily_file:
    daily_file = candidates[0]

tasks = []
if exists:
    try:
        with open(daily_file, 'r', encoding='utf-8', errors='ignore') as f:
            for idx, line in enumerate(f, 1):
                m = re.match(r'^\s*-\s*\[([ xX])\]\s*(.+)$', line)
                if m:
                    done = m.group(1).lower() == 'x'
                    tasks.append({
                        "line": idx,
                        "done": done,
                        "text": m.group(2).strip()
                    })
    except Exception as e:
        pass

total = len(tasks)
completed = sum(1 for t in tasks if t["done"])
pending = total - completed

# Check rclone sync status
sync_status = "idle"
sync_msg = "Idle"
try:
    p = subprocess.run(
        ["systemctl", "--user", "is-active", "rclone-obsidian-sync.service"],
        capture_output=True, text=True
    )
    unit_active = p.stdout.strip()
    if unit_active == "active":
        sync_status = "syncing"
        sync_msg = "Syncing..."
    else:
        # Check failed state
        p_failed = subprocess.run(
            ["systemctl", "--user", "is-failed", "rclone-obsidian-sync.service"],
            capture_output=True, text=True
        )
        if p_failed.stdout.strip() == "failed":
            sync_status = "error"
            sync_msg = "Sync error"
        else:
            sync_status = "synced"
            sync_msg = "Synced"
except Exception:
    sync_status = "unknown"
    sync_msg = "No sync unit"

result = {
    "vault": vault,
    "vaultExists": os.path.isdir(vault),
    "dailyFile": daily_file,
    "dailyFilename": os.path.basename(daily_file),
    "exists": exists,
    "todayFormatted": today_formatted,
    "totalTasks": total,
    "completedTasks": completed,
    "pendingTasks": pending,
    "tasks": tasks,
    "syncStatus": sync_status,
    "syncMessage": sync_msg
}

print(json.dumps(result))
EOF
}

cmd_capture() {
    local text="$1"
    local item_type="${2:-task}" # task or note
    local vault
    vault=$(get_vault "$3")
    local daily_folder
    daily_folder=$(get_daily_folder "$4")

    if [[ -z "$text" ]]; then
        echo "Error: Capture text cannot be empty" >&2
        exit 1
    fi

    local daily_file
    daily_file=$(find_daily_note "$vault" "$daily_folder")
    local target_dir
    target_dir=$(dirname "$daily_file")
    mkdir -p "$target_dir"

    local time_str
    time_str=$(date '+%H:%M')

    if [[ ! -f "$daily_file" ]]; then
        local today_title
        today_title=$(date '+%Y-%m-%d')
        cat <<EOF > "$daily_file"
# $today_title

## Tasks

## Notes

EOF
    fi

    local entry
    if [[ "$item_type" == "task" ]]; then
        entry="- [ ] $time_str $text"
        if grep -q "^## Tasks" "$daily_file"; then
            python3 -c "
import sys
path = sys.argv[1]
entry = sys.argv[2]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

pos = content.find('## Tasks')
if pos != -1:
    line_end = content.find('\n', pos)
    new_content = content[:line_end+1] + entry + '\n' + content[line_end+1:]
else:
    new_content = content + '\n' + entry + '\n'

with open(path, 'w', encoding='utf-8') as f:
    f.write(new_content)
" "$daily_file" "$entry"
        else
            echo "$entry" >> "$daily_file"
        fi
    else
        entry="- $time_str $text"
        if grep -q "^## Notes" "$daily_file"; then
            python3 -c "
import sys
path = sys.argv[1]
entry = sys.argv[2]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

pos = content.find('## Notes')
if pos != -1:
    line_end = content.find('\n', pos)
    new_content = content[:line_end+1] + entry + '\n' + content[line_end+1:]
else:
    new_content = content + '\n' + entry + '\n'

with open(path, 'w', encoding='utf-8') as f:
    f.write(new_content)
" "$daily_file" "$entry"
        else
            echo "$entry" >> "$daily_file"
        fi
    fi

    echo "Captured to $daily_file"
}

cmd_toggle_task() {
    local file_path="$1"
    local line_num="$2"

    if [[ ! -f "$file_path" || -z "$line_num" ]]; then
        echo "Usage: toggle-task <file_path> <line_num>" >&2
        exit 1
    fi

    python3 -c "
import sys
path = sys.argv[1]
target_line = int(sys.argv[2])

with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

if 1 <= target_line <= len(lines):
    line = lines[target_line - 1]
    if '- [ ]' in line:
        lines[target_line - 1] = line.replace('- [ ]', '- [x]', 1)
    elif '- [x]' in line:
        lines[target_line - 1] = line.replace('- [x]', '- [ ]', 1)
    elif '- [X]' in line:
        lines[target_line - 1] = line.replace('- [X]', '- [ ]', 1)

with open(path, 'w', encoding='utf-8') as f:
    f.writelines(lines)
" "$file_path" "$line_num"

    echo "Toggled task on line $line_num"
}

cmd_open_daily() {
    local editor="${1:-neovim}"
    local vault
    vault=$(get_vault "$2")
    local daily_folder
    daily_folder=$(get_daily_folder "$3")

    local daily_file
    daily_file=$(find_daily_note "$vault" "$daily_folder")
    local target_dir
    target_dir=$(dirname "$daily_file")
    mkdir -p "$target_dir"

    if [[ ! -f "$daily_file" ]]; then
        local today_title
        today_title=$(date '+%Y-%m-%d')
        cat <<EOF > "$daily_file"
# $today_title

## Tasks

## Notes

EOF
    fi

    case "$editor" in
        neovim|nvim)
            ghostty --title="Obsidian: $(basename "$daily_file")" -e nvim "$daily_file" &
            ;;
        obsidian)
            xdg-open "obsidian://open?path=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$daily_file")" 2>/dev/null || obsidian "$daily_file" &
            ;;
        *)
            xdg-open "$daily_file" &
            ;;
    esac
}

cmd_sync() {
    if systemctl --user list-unit-files rclone-obsidian-sync.service &>/dev/null; then
        systemctl --user start rclone-obsidian-sync.service
        echo "Triggered rclone-obsidian-sync.service"
    else
        rclone bisync "$DEFAULT_VAULT" gdrive:Obsidian --fast-list &
        echo "Triggered rclone bisync in background"
    fi
}

cmd_list_tags_json() {
    local vault
    vault=$(get_vault "${1:-}")
    python3 - <<EOF
import os, re, json

vault = os.path.expanduser("$vault")
tags = {}
for root, dirs, files in os.walk(vault):
    if any(x in root for x in ['.obsidian', '.trash', '.git', 'SYSTEM/TEMPLATE', 'SYSTEM/SCRIPTS']):
        continue
    for f in files:
        if not f.endswith('.md'): continue
        p = os.path.join(root, f)
        try:
            with open(p, 'r', encoding='utf-8', errors='ignore') as fh:
                content = fh.read()
        except Exception: continue
        fm = re.match(r'^---\s*\n(.*?)\n---\s*\n', content, flags=re.DOTALL)
        file_tags = set()
        if fm:
            in_tags = False
            for line in fm.group(1).splitlines():
                if re.match(r'^(?:tags|tag):', line, re.IGNORECASE):
                    in_tags = True
                    arr = re.search(r'\[(.*?)\]', line)
                    if arr:
                        for t in arr.group(1).split(','):
                            c = t.strip(' \"\'')
                            if c: file_tags.add(c)
                        in_tags = False
                    continue
                if in_tags:
                    m = re.match(r'^\s*-\s*([a-zA-Z0-9_\-\/]+)', line)
                    if m: file_tags.add(m.group(1))
                    elif re.match(r'^\w+:', line): in_tags = False
        for m in re.finditer(r'(?:^|\s)#([a-zA-Zа-яА-Я0-9_\-\/]+)\b', content):
            t = m.group(1)
            if not re.match(r'^[0-9a-fA-F]{3,8}$', t) and not t.isdigit():
                file_tags.add(t)
        for t in file_tags:
            tags[t] = tags.get(t, 0) + 1

res = [{"tag": k, "count": v} for k, v in sorted(tags.items(), key=lambda x: (-x[1], x[0].lower()))]
print(json.dumps(res))
EOF
}

cmd_notes_by_tag_json() {
    local tag="$1"
    local vault
    vault=$(get_vault "${2:-}")
    python3 - <<EOF
import os, re, json

vault = os.path.expanduser("$vault")
tag = "${tag}".lstrip('#')
notes = []
for root, dirs, files in os.walk(vault):
    if any(x in root for x in ['.obsidian', '.trash', '.git', 'SYSTEM/TEMPLATE', 'SYSTEM/SCRIPTS']):
        continue
    for f in files:
        if not f.endswith('.md'): continue
        p = os.path.join(root, f)
        try:
            with open(p, 'r', encoding='utf-8', errors='ignore') as fh:
                content = fh.read()
        except Exception: continue
        fm = re.match(r'^---\s*\n(.*?)\n---\s*\n', content, flags=re.DOTALL)
        matched = False
        if fm:
            if re.search(r'(?:tags|tag):\s*(\[.*?\\b' + re.escape(tag) + r'\\b.*?\]|.*?\n\s*-\s*' + re.escape(tag) + r'\b)', fm.group(1), flags=re.IGNORECASE):
                matched = True
        if not matched and re.search(r'#' + re.escape(tag) + r'\b', content):
            matched = True
        if matched:
            rel = os.path.relpath(p, vault)
            title = os.path.splitext(f)[0]
            mtime = int(os.path.getmtime(p))
            notes.append({
                "title": title,
                "relPath": rel,
                "fullPath": p,
                "mtime": mtime
            })

notes.sort(key=lambda x: x["mtime"], reverse=True)
print(json.dumps(notes))
EOF
}

cmd_search_notes_json() {
    local query="${1:-}"
    local vault
    vault=$(get_vault "${2:-}")
    python3 - <<EOF
import os, sys, json, subprocess, urllib.request, urllib.parse

vault = os.path.expanduser("$vault")
query = """$query""".strip()

results = []
seen_files = set()

if not query:
    # If query is empty, return recently modified notes
    for root, dirs, files in os.walk(vault):
        if any(x in root for x in ['.obsidian', '.trash', '.git', 'SYSTEM/TEMPLATE', 'SYSTEM/SCRIPTS']):
            continue
        for f in files:
            if f.endswith('.md'):
                p = os.path.join(root, f)
                rel = os.path.relpath(p, vault)
                title = os.path.splitext(f)[0]
                results.append({
                    "title": title,
                    "relPath": rel,
                    "fullPath": p,
                    "snippet": "Recent note",
                    "source": "recent",
                    "mtime": os.path.getmtime(p)
                })
    results.sort(key=lambda x: x.get("mtime", 0), reverse=True)
    print(json.dumps(results[:30]))
    sys.exit(0)

# 1. Try Khoj search API
try:
    url = f"http://127.0.0.1:42110/api/search?q={urllib.parse.quote(query)}&n=15"
    req = urllib.request.Request(url, headers={"User-Agent": "Noctalia"})
    with urllib.request.urlopen(req, timeout=1.5) as resp:
        if resp.status == 200:
            data = json.loads(resp.read().decode("utf-8"))
            for item in data:
                add = item.get("additional") or {}
                f = add.get("file")
                if not f and item.get("entry"):
                    f = item.get("entry").splitlines()[0].lstrip("# ").strip()
                if f and os.path.isfile(f) and f.endswith(".md"):
                    rel = os.path.relpath(f, vault)
                    title = os.path.splitext(os.path.basename(f))[0]
                    snippet = item.get("entry", "")
                    clean_snip = " ".join([l.strip() for l in snippet.splitlines() if l.strip() and not l.startswith("#")][:3])
                    results.append({
                        "title": title,
                        "relPath": rel,
                        "fullPath": f,
                        "snippet": clean_snip[:160],
                        "source": "khoj",
                        "score": item.get("score", 0.0)
                    })
                    seen_files.add(f)
except Exception:
    pass

# 2. Filename & text match with ripgrep
try:
    for root, dirs, files in os.walk(vault):
        if any(x in root for x in ['.obsidian', '.trash', '.git', 'SYSTEM/TEMPLATE', 'SYSTEM/SCRIPTS']):
            continue
        for f in files:
            if not f.endswith('.md'): continue
            p = os.path.join(root, f)
            if p in seen_files: continue
            title = os.path.splitext(f)[0]
            if query.lower() in title.lower():
                rel = os.path.relpath(p, vault)
                results.append({
                    "title": title,
                    "relPath": rel,
                    "fullPath": p,
                    "snippet": "Match in title",
                    "source": "filename",
                    "score": 1.0
                })
                seen_files.add(p)
                if len(results) >= 25: break
        if len(results) >= 25: break

    if len(results) < 20:
        cmd = [
            "rg", "-i", "--max-count=1", "--line-number",
            "--glob=*.md", "--glob=!**/.obsidian/**", "--glob=!**/.trash/**",
            "--glob=!**/SYSTEM/TEMPLATE/**", query, vault
        ]
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=2.0)
        for line in p.stdout.splitlines()[:20]:
            parts = line.split(":", 2)
            if len(parts) >= 3:
                f_path = parts[0]
                if f_path not in seen_files and os.path.isfile(f_path):
                    rel = os.path.relpath(f_path, vault)
                    title = os.path.splitext(os.path.basename(f_path))[0]
                    snip = parts[2].strip()
                    results.append({
                        "title": title,
                        "relPath": rel,
                        "fullPath": f_path,
                        "snippet": snip[:160],
                        "source": "text",
                        "score": 0.5
                    })
                    seen_files.add(f_path)
except Exception:
    pass

print(json.dumps(results[:30]))
EOF
}

cmd_open_note() {
    local note_path="$1"
    local editor="${2:-neovim}"
    if [[ ! -f "$note_path" ]]; then
        echo "Error: Note not found: $note_path" >&2
        exit 1
    fi
    local title
    title=$(basename "$note_path" .md)
    case "$editor" in
        neovim|nvim)
            ghostty --title="Obsidian Note: $title" -e nvim "$note_path" &
            ;;
        obsidian)
            xdg-open "obsidian://open?path=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$note_path")" 2>/dev/null || obsidian "$note_path" &
            ;;
        *)
            xdg-open "$note_path" &
            ;;
    esac
}

cmd_explore_tags() {
    local vault
    vault=$(get_vault "${1:-}")
    
    local dmenu_bin=""
    if command -v noctalia-dmenu &>/dev/null; then
        dmenu_bin="noctalia-dmenu"
    elif [[ -x "$HOME/.config/noctalia/plugins/dmenu/noctalia-dmenu" ]]; then
        dmenu_bin="$HOME/.config/noctalia/plugins/dmenu/noctalia-dmenu"
    fi

    if [[ -n "$dmenu_bin" ]]; then
        local raw_json
        raw_json=$(cmd_list_tags_json "$vault")
        local tags_list
        tags_list=$(python3 -c "
import json, sys
data = json.loads('''$raw_json''')
for item in data:
    print(f\"{item['tag']} ({item['count']})\")
")
        if [[ -z "$tags_list" ]]; then
            return 0
        fi

        local selected_tag_line
        selected_tag_line=$(echo "$tags_list" | "$dmenu_bin" -p "🏷️ Выберите тег Obsidian:" || true)
        if [[ -z "$selected_tag_line" ]]; then
            return 0
        fi

        local selected_tag
        selected_tag=$(echo "$selected_tag_line" | awk '{print $1}')
        
        local notes_json
        notes_json=$(cmd_notes_by_tag_json "$selected_tag" "$vault")
        local notes_list
        notes_list=$(python3 -c "
import json, sys
notes = json.loads('''$notes_json''')
for n in notes:
    print(f\"{n['title']} | {n['relPath']}\")
")
        if [[ -z "$notes_list" ]]; then
            return 0
        fi

        sleep 0.25
        local selected_note_line
        selected_note_line=$(echo "$notes_list" | "$dmenu_bin" -p "🏷️ #${selected_tag} Заметки:" || true)
        if [[ -z "$selected_note_line" ]]; then
            return 0
        fi

        local rel_path
        rel_path=$(echo "$selected_note_line" | awk -F ' \\| ' '{print $2}')
        if [[ -n "$rel_path" && -f "$vault/$rel_path" ]]; then
            cmd_open_note "$vault/$rel_path" "neovim"
        fi
    elif [[ -x "$HOME/.zsh/scripts/khoj-tags" ]]; then
        ghostty --title="Obsidian Tag Explorer" -e "$HOME/.zsh/scripts/khoj-tags" &
    else
        ghostty --title="Obsidian Tags" -e bash -c "grep -rohnP '#[a-zA-Z0-9_\-\/]+' '$DEFAULT_VAULT' --exclude-dir='.obsidian' | sort -u | fzf" &
    fi
}

cmd_search_notes() {
    local vault
    vault=$(get_vault "${1:-}")
    
    local dmenu_bin=""
    if command -v noctalia-dmenu &>/dev/null; then
        dmenu_bin="noctalia-dmenu"
    elif [[ -x "$HOME/.config/noctalia/plugins/dmenu/noctalia-dmenu" ]]; then
        dmenu_bin="$HOME/.config/noctalia/plugins/dmenu/noctalia-dmenu"
    fi

    if [[ -n "$dmenu_bin" ]]; then
        local files_list
        files_list=$(python3 -c "
import os
vault = '$vault'
for root, dirs, files in os.walk(vault):
    if any(x in root for x in ['.obsidian', '.trash', '.git', 'SYSTEM/TEMPLATE', 'SYSTEM/SCRIPTS']):
        continue
    for f in sorted(files):
        if f.endswith('.md'):
            rel = os.path.relpath(os.path.join(root, f), vault)
            title = os.path.splitext(f)[0]
            print(f'{title} | {rel}')
")
        if [[ -z "$files_list" ]]; then
            return 0
        fi

        local selected_line
        selected_line=$(echo "$files_list" | "$dmenu_bin" -p "🔍 Поиск заметок Obsidian:" || true)
        if [[ -n "$selected_line" ]]; then
            local rel_path
            rel_path=$(echo "$selected_line" | awk -F ' \\| ' '{print $2}')
            if [[ -n "$rel_path" && -f "$vault/$rel_path" ]]; then
                cmd_open_note "$vault/$rel_path" "neovim"
            fi
        fi
    else
        ghostty --title="Obsidian Search" -e bash -c "cd '$vault' && fzf --preview 'glow -s dark -w \${FZF_PREVIEW_COLUMNS:-80} {}' --bind 'enter:become(nvim {})'" &
    fi
}

case "$COMMAND" in
    status)
        cmd_status "$@"
        ;;
    capture)
        cmd_capture "$@"
        ;;
    toggle-task)
        cmd_toggle_task "$@"
        ;;
    open-daily)
        cmd_open_daily "$@"
        ;;
    open-note)
        cmd_open_note "$@"
        ;;
    list-tags-json)
        cmd_list_tags_json "$@"
        ;;
    notes-by-tag-json)
        cmd_notes_by_tag_json "$@"
        ;;
    search-notes-json)
        cmd_search_notes_json "$@"
        ;;
    sync)
        cmd_sync "$@"
        ;;
    explore-tags)
        cmd_explore_tags "$@"
        ;;
    search-notes)
        cmd_search_notes "$@"
        ;;
    *)
        echo "Usage: obsidian-helper.sh {status|capture|toggle-task|open-daily|open-note|list-tags-json|notes-by-tag-json|search-notes-json|sync|explore-tags|search-notes} [args...]" >&2
        exit 1
        ;;
esac
