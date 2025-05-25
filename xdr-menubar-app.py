#!/usr/bin/env python3
"""
XDR Brightness Menu Bar App for macOS
Controls MacBook Pro display brightness up to 1600 nits
"""

import rumps
import subprocess
import os
import sys
from pathlib import Path

class XDRBrightnessApp(rumps.App):
    def __init__(self):
        super(XDRBrightnessApp, self).__init__("☀️", quit_button=None)
        self.current_brightness = 1.0  # Default to normal max
        self.enabled = True
        self.setup_menu()
        
    def setup_menu(self):
        """Setup the menu items"""
        # Create menu items
        self.menu = [
            rumps.MenuItem("☀️ Outdoor (1600 nits)", callback=self.set_outdoor),
            rumps.MenuItem("💡 Bright (1000 nits)", callback=self.set_bright),
            rumps.MenuItem("🖥️  Normal (500 nits)", callback=self.set_normal),
            rumps.MenuItem("🌙 Dim (250 nits)", callback=self.set_dim),
            rumps.separator,
            rumps.SliderMenuItem(value=50, min_value=0, max_value=100, callback=self.slider_changed),
            rumps.separator,
            rumps.MenuItem("✅ Enabled", callback=self.toggle_enabled),
            rumps.separator,
            rumps.MenuItem("🚀 Launch at Startup", callback=self.toggle_startup),
            rumps.separator,
            rumps.MenuItem("Quit", callback=self.quit_app)
        ]
        
        # Update checkmarks
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
        
        process = subprocess.Popen(['swift', '-'], stdin=subprocess.PIPE, text=True)
        process.communicate(input=swift_code)
        self.current_brightness = level
        
    def set_outdoor(self, _):
        """Set to outdoor brightness (1600 nits)"""
        self.set_brightness(3.2)
        self.show_notification("Outdoor Mode", "1600 nits - Maximum brightness")
        self.update_icon("☀️")
        self.menu["🔆 Brightness:"].set_value(100)
        
    def set_bright(self, _):
        """Set to bright mode (1000 nits)"""
        self.set_brightness(2.0)
        self.show_notification("Bright Mode", "1000 nits")
        self.update_icon("💡")
        self.menu["🔆 Brightness:"].set_value(62)
        
    def set_normal(self, _):
        """Set to normal max (500 nits)"""
        self.set_brightness(1.0)
        self.show_notification("Normal Mode", "500 nits")
        self.update_icon("🖥️")
        self.menu["🔆 Brightness:"].set_value(31)
        
    def set_dim(self, _):
        """Set to dim mode (250 nits)"""
        self.set_brightness(0.5)
        self.show_notification("Dim Mode", "250 nits")
        self.update_icon("🌙")
        self.menu["🔆 Brightness:"].set_value(15)
        
    def slider_changed(self, sender):
        """Handle slider value changes"""
        if not self.enabled:
            return
            
        # Convert slider value (0-100) to brightness (0-3.2)
        brightness = (sender.value / 100.0) * 3.2
        self.set_brightness(brightness)
        
        # Update icon based on brightness
        if brightness >= 2.5:
            self.update_icon("☀️")
        elif brightness >= 1.5:
            self.update_icon("💡")
        elif brightness >= 0.8:
            self.update_icon("🖥️")
        else:
            self.update_icon("🌙")
            
    def toggle_enabled(self, sender):
        """Toggle the app on/off"""
        self.enabled = not self.enabled
        sender.title = "✅ Enabled" if self.enabled else "❌ Disabled"
        
        if not self.enabled:
            self.set_brightness(1.0)  # Reset to normal when disabled
            self.update_icon("⭕")
        else:
            self.update_icon("☀️")
            
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
        # Create LaunchAgent plist
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
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>"""
        
        plist_path = Path.home() / "Library/LaunchAgents/com.xdr.brightness.plist"
        plist_path.parent.mkdir(exist_ok=True)
        plist_path.write_text(plist_content)
        
        # Load the LaunchAgent
        subprocess.run(['launchctl', 'load', str(plist_path)])
        
    def disable_startup(self):
        """Disable launch at startup"""
        plist_path = Path.home() / "Library/LaunchAgents/com.xdr.brightness.plist"
        
        if plist_path.exists():
            subprocess.run(['launchctl', 'unload', str(plist_path)])
            plist_path.unlink()
            
    def update_menu_state(self):
        """Update menu checkmarks"""
        startup_item = self.menu["🚀 Launch at Startup"]
        if self.is_startup_enabled():
            startup_item.title = "🚀 Launch at Startup ✓"
            
    def update_icon(self, icon):
        """Update the menu bar icon"""
        self.icon = icon
        
    def show_notification(self, title, message):
        """Show a macOS notification"""
        rumps.notification(
            title="XDR Brightness",
            subtitle=title,
            message=message,
            sound=False
        )
        
    def quit_app(self, _):
        """Quit the application"""
        rumps.quit_application()

# Installation helper
def install_app():
    """Install the app and its dependencies"""
    print("🌞 XDR Brightness Menu Bar App Installer")
    print("========================================\n")
    
    # Check if rumps is installed
    try:
        import rumps
    except ImportError:
        print("Installing required dependency: rumps")
        subprocess.run([sys.executable, '-m', 'pip', 'install', 'rumps'])
        print("✅ Dependencies installed\n")
    
    # Create Applications directory if needed
    app_dir = Path.home() / "Applications/XDR Brightness"
    app_dir.mkdir(exist_ok=True)
    
    # Copy this script to Applications
    script_path = app_dir / "XDR Brightness.py"
    current_script = Path(__file__).read_text()
    script_path.write_text(current_script)
    script_path.chmod(0o755)
    
    # Create a launcher script
    launcher_path = app_dir / "Launch XDR Brightness.command"
    launcher_content = f"""#!/bin/bash
cd "{app_dir}"
{sys.executable} "XDR Brightness.py"
"""
    launcher_path.write_text(launcher_content)
    launcher_path.chmod(0o755)
    
    print("✅ App installed to: ~/Applications/XDR Brightness/")
    print("\n📋 INSTRUCTIONS:")
    print("================")
    print("1. To start the app now:")
    print(f"   python3 '{script_path}'")
    print("\n2. Or double-click:")
    print("   ~/Applications/XDR Brightness/Launch XDR Brightness.command")
    print("\n3. Once running, click the ☀️ icon in your menu bar")
    print("4. Select '🚀 Launch at Startup' to auto-start")
    print("\n🌞 Enjoy working outdoors with 1600 nits!")

if __name__ == "__main__":
    # Check if this is an installation run
    if len(sys.argv) > 1 and sys.argv[1] == "install":
        install_app()
    else:
        # Run the app
        try:
            app = XDRBrightnessApp()
            app.run()
        except KeyboardInterrupt:
            pass