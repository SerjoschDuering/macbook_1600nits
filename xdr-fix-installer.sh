#!/bin/bash
# ================================================================
#  XDR Brightness Installer  –  macOS
# ================================================================
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/SerjoschDuering/macbook_1600nits/main"
APP_DIR="$HOME/Applications/XDR Brightness"
PY_FILE="$APP_DIR/XDR_Brightness.py"
LAUNCH_CMD="$APP_DIR/Launch XDR Brightness.command"

echo "────────────────────────────────────────────────────────"
echo "🌞  XDR Brightness Installer"
echo "────────────────────────────────────────────────────────"
echo
# ─────────────────────────────────────────────────────────
#  Dependencies
# ─────────────────────────────────────────────────────────
read -p "Install Python ‘rumps’ library (required)? [y/N] " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
    pip3 install --user rumps
fi

if ! command -v ddcctl >/dev/null 2>&1; then
    read -p "'ddcctl' (controls brightness) not found. Install with Homebrew now? [y/N] " brew_ans
    if [[ "$brew_ans" =~ ^[Yy]$ ]]; then
        brew install ddcctl
    else
        echo "⚠️  Continue without ddcctl – the app will not work."
    fi
fi

# ─────────────────────────────────────────────────────────
#  Install files
# ─────────────────────────────────────────────────────────
mkdir -p "$APP_DIR"

echo "⬇️  Downloading latest XDR_Brightness.py …"
curl -fsSL "$REPO_RAW/XDR_Brightness.py" -o "$PY_FILE"

echo "⚙️  Creating launchable command file …"
cat > "$LAUNCH_CMD" <<EOF
#!/bin/bash
/usr/bin/python3 "$PY_FILE" &
EOF
chmod +x "$LAUNCH_CMD"

echo "✅ Installation finished!  App located in:"
echo "   $APP_DIR"
echo

# ─────────────────────────────────────────────────────────
#  Optional auto-launch
# ─────────────────────────────────────────────────────────
read -p "Run XDR Brightness automatically at login? [y/N] " auto_ans
if [[ "$auto_ans" =~ ^[Yy]$ ]]; then
    /usr/bin/python3 "$PY_FILE" --install-launch-agent
fi

# ─────────────────────────────────────────────────────────
#  Start the app immediately
# ─────────────────────────────────────────────────────────
open "$LAUNCH_CMD"
echo "🚀  XDR Brightness launched. Look for the ☀️ icon in your menu-bar!"
