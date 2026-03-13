#!/bin/bash
set -e

CONFIG_DIR="$HOME/.config/hauntr"
CONFIG_FILE="$CONFIG_DIR/projects.json"
SCRIPTS_DIR="$CONFIG_DIR/scripts"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "No projects found. Add projects via the Hauntr menu bar app." >&2
    exit 1
fi

get_project_path() {
    /usr/bin/python3 -c "
import json, sys
with open('$CONFIG_FILE') as f:
    items = json.load(f)
for item in items:
    if item.get('type') == 'project':
        p = item['project']
    elif 'name' in item:
        p = item
    else:
        continue
    if p['name'].lower() == sys.argv[1].lower():
        print(p['path'])
        sys.exit(0)
print('Project not found: ' + sys.argv[1], file=sys.stderr)
sys.exit(1)
" "$1"
}

list_projects() {
    echo "Available projects:"
    echo ""
    /usr/bin/python3 -c "
import json
with open('$CONFIG_FILE') as f:
    items = json.load(f)
for item in items:
    if item.get('type') == 'project':
        p = item['project']
        if p.get('isHidden', False):
            continue
        display = p.get('displayName') or p['name']
        name = p['name']
        if display != name:
            print(f'  {name}  ({display})')
        else:
            print(f'  {name}')
    elif item.get('type') == 'group':
        if item.get('isHidden', False):
            continue
        print(f'  --- {item[\"title\"]} ---')
    elif 'name' in item:
        if item.get('isHidden', False):
            continue
        print(f'  {item[\"name\"]}')
"
    echo ""
    echo "Usage:"
    echo "  hauntr <name>            launch in new window (default)"
    echo "  hauntr <name> --here     launch in current window"
    echo "  hauntr <name> --window   launch in new window"
    echo "  hauntr <name> --path     print project path"
    echo "  hauntr <name> --script   print paths to applescript files"
    echo "  hauntr <name> --edit     open project in Hauntr app"
    echo "  hauntr --add             add current directory as project"
    echo "  hauntr --uninstall-cli   uninstall the hauntr CLI"
}

if [ $# -eq 0 ]; then
    list_projects
    exit 0
fi

if [ "$1" = "--uninstall-cli" ]; then
    rm -f /usr/local/bin/hauntr
    echo "Hauntr CLI uninstalled."
    exit 0
fi

if [ "$1" = "--add" ]; then
    ENCODED_PATH=$(/usr/bin/python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$(pwd)")
    open "hauntr://add?path=$ENCODED_PATH"
    exit 0
fi

NAME="$1"
ACTION="${2:-}"

run_script() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "No script found for project '$NAME'." >&2
        echo "Open Hauntr and save the project to generate the script." >&2
        exit 1
    fi
    /usr/bin/osascript "$file"
}

case "$ACTION" in
    --path)
        get_project_path "$NAME"
        ;;
    --script)
        echo "$SCRIPTS_DIR/$NAME-here.applescript"
        echo "$SCRIPTS_DIR/$NAME-window.applescript"
        ;;
    --edit)
        open "hauntr://edit/$NAME"
        ;;
    --here)
        run_script "$SCRIPTS_DIR/$NAME-here.applescript"
        ;;
    --window|"")
        run_script "$SCRIPTS_DIR/$NAME-window.applescript"
        ;;
    *)
        echo "Unknown option: $ACTION" >&2
        echo "Usage: hauntr <name> [--here|--window|--path|--script|--edit]" >&2
        exit 1
        ;;
esac
