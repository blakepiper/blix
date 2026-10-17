import argparse
import json
import os
import sys

from core import SettingsError, command, power_profiles, set_power_profile, run_nightlight, apply_saved_display, apply_session_preferences, prepare_picom_configuration, preview_display, watch_input


def main(gui=True):
    parser = argparse.ArgumentParser(description="Blix desktop settings")
    parser.add_argument("action", nargs="?", choices=["display-hotplug", "apply-session", "watch-input", "display-preview", "prepare-picom", "nightlight", "power-mode"])
    parser.add_argument("profile", nargs="?", choices=["performance", "balanced", "power-saver"])
    parser.add_argument("--demo", action="store_true", help="Preview the interface with simulated devices; changes stay in memory")
    args = parser.parse_args()
    try:
        if gui:
            from ui import Application
            sys.exit(Application(demo=args.demo).run([sys.argv[0]]))
        if args.action == "display-hotplug":
            sys.exit(apply_saved_display())
        elif args.action == "apply-session":
            if os.environ.get("DISPLAY"):
                apply_session_preferences()
        elif args.action == "watch-input":
            if os.environ.get("DISPLAY"):
                watch_input()
        elif args.action == "display-preview":
            preview_display(json.loads(sys.stdin.readline()))
        elif args.action == "nightlight":
            run_nightlight()
        elif args.action == "prepare-picom":
            prepare_picom_configuration()
        elif args.action == "power-mode":
            if args.profile:
                set_power_profile(args.profile)
            else:
                print(power_profiles()["active"])
        else:
            parser.error("a runtime action is required")
    except (SettingsError, ValueError, OSError) as error:
        print(str(error), file=sys.stderr)
        if args.action == "power-mode" and args.profile:
            try:
                command("notify-send", "--urgency=critical", "Power mode could not be changed", str(error))
            except SettingsError:
                pass
        sys.exit(1)


if __name__ == "__main__":
    main(gui="--runtime" not in sys.argv)
