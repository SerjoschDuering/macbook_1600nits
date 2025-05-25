#!/bin/bash

# XDR Brightness Menu Bar App - One-Click Installer
# This script installs everything you need automatically

echo "🌞 XDR Brightness Menu Bar App Installer"
echo "========================================"
echo ""

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed."
    echo "Please install Python 3 from: https://python.org"
    exit 1
fi

# Create app directory
APP_DIR="$HOME/Applications/XDR Brightness"
mkdir -p "$APP_DIR"

# Download the app script
echo "📥 Downloading XDR Brightness app..."
cat > "$APP_DIR/XDR_Brightness.py" << 'PYTHON_APP'
#!/usr/bin/env python3
"""
XDR Brightness Menu Bar App for macOS
Controls MacBook Pro display brightness up to 1600 nits
"""

import subprocess
import os
import sys
from pathlib import Path

# Try to import rumps, install if needed
try:
    import rumps
except ImportError:
    print("Installing required dependency: rumps...")
    subprocess.run([sys.executable, '-m', 'pip', 'install', 'rumps'])
    import rumps

class XDRBrightnessApp(rumps.App):
    def __init__(self):
        super(XDRBrightnessApp, self).__init__("☀️", quit_button=None)
        self.current_brightness = 1.0
        self.enabled = True
        self.setup_menu()
        
    def setup_menu(self):
        """Setup the menu items"""
        self.menu = [
            rumps.MenuItem("☀️ Outdoor (1600 nits)", callback=self.set_outdoor),
            rumps.MenuItem("💡 Bright (1000 nits)", callback=self.set_bright),
            rumps.MenuItem("🖥️  Normal (500 nits)", callback=self.set_normal),
            rumps.MenuItem("🌙 Dim (250 nits)", callback=self.set_dim),
            rumps.separator,
            rumps.MenuItem("✅ Enabled", callback=self.toggle_enabled),
            rumps.separator,
            rumps.MenuItem("🚀 Launch at Startup", callback=self.toggle_startup),
            rumps.MenuItem("ℹ️  About", callback=self.show_about),
            rumps.separator,
            rumps.MenuItem("Quit", callback=rumps.quit_application)
        ]
        self.update_menu_state()
        
    def set_brightness(self, level):
        """Set the actual brightness using CoreDisplay API"""
        if not self.enabled:
            return
            
        swift_code = f"""
        import Foundation
        import CoreGraphics
        
        let displayID = CGMainDisplayID()
        let path = "/System/Library/PrivateFrameworks/CoreDisplay.framework/CoreDisplay"
        
        if let handle = dlopen(path, RTLD_LAZY),
           let sym = dlsym(handle, "CoreDisplay_Display_SetUserBrightness") {{
            let setBrightness = unsafeBitCast(sym, to: (@convention(c) (CGDirectDisplayID, Double) -> Void).self)
            setBrightness(displayID, {level})
        }}
        """
        
        try:
            process = subprocess.Popen(['swift', '-'], stdin=subprocess.PIPE, text=True)
            process.communicate(input=swift_code)
            self.current_brightness = level
        except Exception as e:
            rumps.alert("Error", f"Failed to set brightness: {e}")
        
    def set_outdoor(self, _):
        """Set to outdoor brightness (1600 nits)"""
        self.set_brightness(3.2)
        self.show_notification("Outdoor Mode", "1600 nits - Maximum brightness")
        self.icon = "☀️"
        
    def set_bright(self, _):
        """Set to bright mode (1000 nits)"""
        self.set_brightness(2.0)
        self.show_notification("Bright Mode", "1000 nits")
        self.icon = "💡"
        
    def set_normal(self, _):
        """Set to normal max (500 nits)"""
        self.set_brightness(1.0)
        self.show_notification("Normal Mode", "500 nits")
        self.icon = "🖥️"
        
    def set_dim(self, _):
        """Set to dim mode (250 nits)"""
        self.set_brightness(0.5)
        self.show_notification("Dim Mode", "250 nits")
        self.icon = "🌙"
        
    def toggle_enabled(self, sender):
        """Toggle the app on/off"""
        self.enabled = not self.enabled
        sender.title = "✅ Enabled" if self.enabled else "❌ Disabled"
        
        if not self.enabled:
            self.set_brightness(1.0)
            self.icon = "⭕"
        else:
            self.icon = "☀️"
            
    def toggle_startup(self, sender):
        """Toggle launch at startup"""
        is_enabled = self.is_startup_enabled()
        
        if is_enabled:
            self.disable_startup()
            sender.title = "🚀 Launch at Startup"
            self.show_notification("Startup Disabled", "XDR Brightness won't launch at startup")
        else:
            self.enable_startup()
            sender.title = "🚀 Launch at Startup ✓"
            self.show_notification("Startup Enabled", "XDR Brightness will launch at startup")
            
    def is_startup_enabled(self):
        """Check if app is set to launch at startup"""
        plist_path = Path.home() / "Library/LaunchAgents/com.xdr.brightness.plist"
        return plist_path.exists()
        
    def enable_startup(self):
        """Enable launch at startup"""
        plist_content = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.xdr.brightness</string>
    <key>ProgramArguments</key>
    <array>
        <string>{sys.executable}</string>
        <string>{os.path.abspath(__file__)}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>"""
        
        plist_path = Path.home() / "Library/LaunchAgents/com.xdr.brightness.plist"
        plist_path.parent.mkdir(exist_ok=True)
        plist_path.write_text(plist_content)
        subprocess.run(['launchctl', 'load', str(plist_path)])
        
    def disable_startup(self):
        """Disable launch at startup"""
        plist_path = Path.home() / "Library/LaunchAgents/com.xdr.brightness.plist"
        if plist_path.exists():
            subprocess.run(['launchctl', 'unload', str(plist_path)])
            plist_path.unlink()
            
    def update_menu_state(self):
        """Update menu checkmarks"""
        for item in self.menu:
            if item.title.startswith("🚀 Launch at Startup"):
                if self.is_startup_enabled():
                    item.title = "🚀 Launch at Startup ✓"
                break
                
    def show_about(self, _):
        """Show about dialog"""
        rumps.alert(
            "XDR Brightness",
            "Unlock the full 1600 nits brightness on your MacBook Pro!\n\n"
            "Created for outdoor work and bright environments.\n\n"
            "⚠️ High brightness uses more battery and generates heat."
        )
        
    def show_notification(self, title, message):
        """Show a macOS notification"""
        rumps.notification(
            title="XDR Brightness",
            subtitle=title,
            message=message,
            sound=False
        )

if __name__ == "__main__":
    app = XDRBrightnessApp()
    app.run()
PYTHON_APP

# Make the script executable
chmod +x "$APP_DIR/XDR_Brightness.py"

# Create launcher script
echo "📝 Creating launcher..."
cat > "$APP_DIR/Launch XDR Brightness.command" << 'LAUNCHER'
#!/bin/bash
cd "$(dirname "$0")"
python3 XDR_Brightness.py
LAUNCHER

chmod +x "$APP_DIR/Launch XDR Brightness.command"

# Create uninstaller
echo "🗑️  Creating uninstaller..."
cat > "$APP_DIR/Uninstall.command" << 'UNINSTALLER'
#!/bin/bash
echo "Uninstalling XDR Brightness..."

# Remove from startup if enabled
launchctl unload ~/Library/LaunchAgents/com.xdr.brightness.plist 2>/dev/null
rm -f ~/Library/LaunchAgents/com.xdr.brightness.plist

# Remove app directory
rm -rf "$HOME/Applications/XDR Brightness"

echo "✅ XDR Brightness has been uninstalled"
UNINSTALLER

chmod +x "$APP_DIR/Uninstall.command"

# Install Python dependencies
echo "📦 Installing dependencies..."
python3 -m pip install --quiet rumps

# Create desktop shortcut
ln -sf "$APP_DIR/Launch XDR Brightness.command" "$HOME/Desktop/XDR Brightness"

echo ""
echo "✅ Installation Complete!"
echo ""
echo "🚀 TO START THE APP:"
echo "   • Double-click 'XDR Brightness' on your Desktop"
echo "   • Or run: open '$APP_DIR/Launch XDR Brightness.command'"
echo ""
echo "📱 USING THE APP:"
echo "   • Look for ☀️ in your menu bar"
echo "   • Click to access brightness presets"
echo "   • Select '🚀 Launch at Startup' to auto-start"
echo ""
echo "⚠️  IMPORTANT:"
echo "   • 1600 nits uses more battery"
echo "   • Your MacBook may get warmer"
echo "   • Perfect for outdoor work!"
echo ""
echo "🗑️  TO UNINSTALL:"
echo "   Run: '$APP_DIR/Uninstall.command'"
echo ""
echo "Starting XDR Brightness now..."
sleep 2
open "$APP_DIR/Launch XDR Brightness.command"