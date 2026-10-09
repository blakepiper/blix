import argparse
import json
import os
import sys

from core import SettingsError, apply_saved_display, apply_session_preferences, prepare_picom_configuration, preview_display, watch_input


def main(gui=True):
    parser = argparse.ArgumentParser(description="Blix desktop settings")
    parser.add_argument("action", nargs="?", choices=["display-hotplug", "apply-session", "watch-input", "display-preview", "prepare-picom"])
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
        elif args.action == "prepare-picom":
            prepare_picom_configuration()
        else:
            parser.error("a runtime action is required")
    except (SettingsError, ValueError, OSError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main(gui="--runtime" not in sys.argv)
