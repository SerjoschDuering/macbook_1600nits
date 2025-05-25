#!/bin/bash

# Fixed XDR Brightness Menu Bar App Installer

echo "🌞 Fixing XDR Brightness Menu Bar App..."
echo "========================================"

# Create fixed Python app
cat > "$HOME/Applications/XDR Brightness/XDR_Brightness.py" << 'FIXED_APP'
#!/usr/bin/env python3
"""
XDR Brightness Menu Bar App for macOS
Controls MacBook Pro display brightness up to 1600 nits
"""

import subprocess
import os
import sys
from pathlib import Path

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
            None,  # Separator
            rumps.MenuItem("✅ Enabled", callback=self.toggle_enabled),
            None,  # Separator
            rumps.MenuItem("🚀 Launch at Startup", callback=self.toggle_startup),
            rumps.MenuItem("ℹ️  About", callback=self.show_about),
            None,  # Separator
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
            process = subprocess.Popen(['swift', '-'], stdin=subprocess.PIPE, text=True, stderr=subprocess.PIPE)
            stdout, stderr = process.communicate(input=swift_code)
            if process.returncode != 0:
                print(f"Swift error: {stderr}")
            else:
                self.current_brightness = level
        except Exception as e:
            print(f"Error setting brightness: {e}")
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
        # Get the actual script path
        script_path = os.path.abspath(__file__)
        
        plist_content = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.xdr.brightness</string>
    <key>ProgramArguments</key>
    <array>
        <string>{sys.executable}</string>
        <string>{script_path}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/tmp/xdr-brightness.err</string>
    <key>StandardOutPath</key>
    <string>/tmp/xdr-brightness.out</string>
</dict>
</plist>"""
        
        plist_path = Path.home() / "Library/LaunchAgents/com.xdr.brightness.plist"
        plist_path.parent.mkdir(exist_ok=True)
        plist_path.write_text(plist_content)
        
        # Unload first if it exists, then load
        subprocess.run(['launchctl', 'unload', str(plist_path)], stderr=subprocess.DEVNULL)
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
            # Skip None items (separators)
            if item is None:
                continue
            # Check if this is a MenuItem with a title
            if hasattr(item, 'title') and isinstance(item.title, str):
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
            "⚠️ High brightness uses more battery and generates heat.\n\n"
            "Version 1.0"
        )
        
    def show_notification(self, title, message):
        """Show a macOS notification"""
        try:
            rumps.notification(
                title="XDR Brightness",
                subtitle=title,
                message=message,
                sound=False
            )
        except Exception as e:
            print(f"Notification error: {e}")

if __name__ == "__main__":
    try:
        app = XDRBrightnessApp()
        app.run()
    except KeyboardInterrupt:
        print("\nXDR Brightness stopped.")
    except Exception as e:
        print(f"Error: {e}")
        rumps.alert("Error", f"XDR Brightness encountered an error:\n{e}")
FIXED_APP

# Make executable
chmod +x "$HOME/Applications/XDR Brightness/XDR_Brightness.py"

echo "✅ Fixed! Starting XDR Brightness..."
echo ""
echo "If you see ☀️ in your menu bar, it's working!"
echo "Click it to access brightness controls."
echo ""

# Kill any existing instances
pkill -f "XDR_Brightness.py" 2>/dev/null

# Start the app
cd "$HOME/Applications/XDR Brightness"
python3 XDR_Brightness.py &

echo "🎉 XDR Brightness is now running!"
echo ""
echo "To stop it: Click ☀️ in menu bar → Quit"
echo "To auto-start: Click ☀️ → 🚀 Launch at Startup"
