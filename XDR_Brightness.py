#!/usr/bin/env python3
"""
XDR Brightness (menu-bar) App
———————————————
• Toggles true 1600-nit XDR brightness on compatible MacBook Pro displays
  via the `ddcctl` CLI tool.
• Sits in the macOS menu bar (built with rumps).
• Lets you enable / disable the fix and auto-launch at login.
"""

import os
import sys
import subprocess
from pathlib import Path
import rumps


# ──────────────────────────────────────────────────────────────────────────────
# Configuration – tweak if you like
# ──────────────────────────────────────────────────────────────────────────────
DDCCTL_PATH      = "/usr/local/bin/ddcctl"   # Home-brew default
BRIGHTNESS_XDR   = "100"                     # 0–100  (approx. 1600 nits)
BRIGHTNESS_NORMAL = "50"                     # back to comfort mode


class XDRBrightnessApp(rumps.App):
    def __init__(self) -> None:
        super().__init__("☀️", quit_button=None)

        # Menu items -----------------------------------------------------------
        self.enable_item   = rumps.MenuItem("⚡ Enable XDR Brightness",
                                            callback=self.toggle_xdr)
        self.startup_item  = rumps.MenuItem("🚀 Launch at Startup",
                                            callback=self.toggle_startup)
        self.quit_item     = rumps.MenuItem("Quit", callback=self.quit_app)

        # Build the menu
        self.menu = [self.enable_item, self.startup_item, None, self.quit_item]

        # Runtime state
        self.enabled = False
        self.update_menu_state()

    # ─────────────────────────────────────────────
    # Helpers
    # ─────────────────────────────────────────────
    def _run_ddcctl(self, enable: bool) -> None:
        """Call ddcctl with sudo; warns on failure."""
        brightness = BRIGHTNESS_XDR if enable else BRIGHTNESS_NORMAL
        cmd = ["sudo", DDCCTL_PATH, "-d", "1", "-b", brightness]

        try:
            subprocess.run(cmd, check=True)
        except subprocess.CalledProcessError as exc:
            rumps.alert(f"ddcctl failed:\n{exc}")

    def _plist_path(self) -> Path:
        return Path.home() / "Library/LaunchAgents/com.xdr.brightness.plist"

    def _launch_agent_installed(self) -> bool:
        return self._plist_path().exists()

    # ─────────────────────────────────────────────
    # Menu callbacks
    # ─────────────────────────────────────────────
    def toggle_xdr(self, _sender) -> None:
        self.enabled = not self.enabled
        self._run_ddcctl(self.enabled)
        self.update_menu_state()

    def toggle_startup(self, _sender) -> None:
        if self._launch_agent_installed():
            self._remove_launch_agent()
        else:
            self._install_launch_agent()
        self.update_menu_state()

    def quit_app(self, _sender) -> None:
        rumps.quit_application()

    # ─────────────────────────────────────────────
    # LaunchAgent management
    # ─────────────────────────────────────────────
    def _install_launch_agent(self) -> None:
        plist = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.xdr.brightness</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>{Path(__file__).as_posix()}</string>
    </array>
    <key>RunAtLoad</key><true/>
</dict>
</plist>"""
        path = self._plist_path()
        path.write_text(plist)
        subprocess.run(["launchctl", "load", str(path)], check=False)

    def _remove_launch_agent(self) -> None:
        path = self._plist_path()
        if path.exists():
            subprocess.run(["launchctl", "unload", str(path)], check=False)
            path.unlink()

    # ─────────────────────────────────────────────
    # UI refresh
    # ─────────────────────────────────────────────
    def update_menu_state(self) -> None:
        """Refresh checkmarks to reflect current state."""
        self.enable_item.state  = self.enabled
        self.startup_item.state = self._launch_agent_installed()

# ──────────────────────────────────────────────────────────────────────────────
# CLI helper – called by installer script
# ──────────────────────────────────────────────────────────────────────────────
def cli_install_launch_agent():
    XDRBrightnessApp()._install_launch_agent()
    print("LaunchAgent installed. It will run at next login.")

# ──────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--install-launch-agent":
        cli_install_launch_agent()
        sys.exit(0)

    app = XDRBrightnessApp()
    app.run()
