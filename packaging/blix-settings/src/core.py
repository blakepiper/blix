"""Runtime controls; Nix supplies defaults, services own their device state."""
import fcntl
import fnmatch
import hashlib
import json
import math
import os
from pathlib import Path
import re
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import time


class SettingsError(Exception):
    pass


TOOLS = json.loads((Path(__file__).parent / "tools.json").read_text()) if (Path(__file__).parent / "tools.json").exists() else {}


def command(name, *args, timeout=12):
    try:
        result = subprocess.run([TOOLS[name], *map(str, args)], capture_output=True,
                                text=True, timeout=timeout, env={**os.environ, "LC_ALL": "C"})
    except (OSError, subprocess.TimeoutExpired) as error:
        raise SettingsError(f"Could not run {name}: {error}") from error
    if result.returncode:
        raise SettingsError(result.stderr.strip() or f"{name} could not complete the change.")
    return result.stdout


def config_root():
    return Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "blix"


def runtime_root():
    base = Path(os.environ.get("XDG_RUNTIME_DIR", tempfile.gettempdir()))
    root = base / f"blix-settings-{os.getuid()}"
    root.mkdir(mode=0o700, exist_ok=True)
    if root.stat().st_uid != os.getuid() or root.is_symlink():
        raise SettingsError("The settings runtime directory is not owned by this user.")
    root.chmod(0o700)
    return root


def read_json(path, default=None):
    try:
        return json.loads(Path(path).read_text())
    except FileNotFoundError:
        return {} if default is None else default
    except (OSError, ValueError) as error:
        raise SettingsError(f"Could not read {Path(path).name}: {error}") from error


def atomic_json(path, value):
    path = Path(path)
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream, indent=2, ensure_ascii=False)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


class Preferences:
    def __init__(self, path=None):
        self.path = Path(path) if path else config_root() / "settings.json"

    def read(self):
        value = read_json(self.path)
        if not isinstance(value, dict) or value.get("version", 1) != 1:
            raise SettingsError("The saved settings format is not supported.")
        return value

    def update(self, key, value):
        self.path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        with (self.path.parent / ".settings.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            state = self.read()
            if value is None:
                state.pop(key, None)
            else:
                state[key] = value
            state["version"] = 1
            atomic_json(self.path, state)


def defaults(path=None):
    return read_json(path or os.environ.get("BLIX_SETTINGS_DEFAULTS", config_root() / "defaults.json"))


def parse_outputs(query):
    """Parse XRandR's mode table and transform, excluding property/EDID text."""
    outputs, current = [], None
    lines = query.splitlines()
    for index, line in enumerate(lines):
        match = re.match(r"^(\S+) (connected|disconnected)\b(.*)", line)
        if match:
            name, status, tail = match.groups()
            geometry = re.search(r"(\d+)x(\d+)([+-]\d+)([+-]\d+)", tail)
            rotation = re.search(r"\b(normal|left|right|inverted)\s+\(", tail)
            current = {"name": name, "connected": status == "connected", "enabled": bool(geometry),
                       "primary": bool(re.search(r"\bprimary\b", tail)), "modes": {},
                       "mode": None, "rate": None, "rotation": rotation.group(1) if rotation else "normal",
                       "x": int(geometry[3]) if geometry else 0, "y": int(geometry[4]) if geometry else 0,
                       "scale": 1.0, "transform": "1,0,0,0,1,0,0,0,1", "preferred": None}
            outputs.append(current)
        elif current and re.match(r"^\s+Transform:", line):
            matrix = line.split(":", 1)[1].split() + lines[index + 1].split() + lines[index + 2].split()
            if len(matrix) == 9:
                try:
                    values = list(map(float, matrix))
                    current["transform"] = ",".join(matrix)
                    if values[0] > 0:
                        current["scale"] = round(1 / values[0], 3)
                except ValueError:
                    pass
        elif current:
            mode = re.match(r"^\s+(\d+x\d+)\s+([\d.+*\s]+)$", line)
            if mode:
                rates = []
                for token in mode[2].split():
                    numeric = token.rstrip("*+")
                    if re.fullmatch(r"\d+(?:\.\d+)?", numeric):
                        rates.append(numeric)
                        if "*" in token:
                            current["mode"], current["rate"] = mode[1], numeric
                        if "+" in token:
                            current["preferred"] = mode[1]
                if rates:
                    current["modes"][mode[1]] = rates
    return outputs


def outputs():
    # The regular table includes all refresh rates; verbose output has transforms.
    result = parse_outputs(command("xrandr", "--query"))
    transforms = {item["name"]: item for item in parse_outputs(command("xrandr", "--verbose"))}
    for item in result:
        other = transforms.get(item["name"], {})
        item["transform"] = other.get("transform", item["transform"])
        item["scale"] = other.get("scale", 1.0)
    return result


def mode_size(mode, rotation="normal", scale=1):
    width, height = map(int, mode.split("x"))
    if rotation in ("left", "right"):
        width, height = height, width
    return max(1, round(width / scale)), max(1, round(height / scale))


def preferred_mode(output, wanted=None):
    modes = output["modes"]
    if not modes:
        raise SettingsError(f"{output['name']} has no advertised display modes.")
    return wanted if wanted in modes else output.get("preferred") or next(iter(modes))


def choose_rate(output, mode, wanted=None):
    rates = output["modes"][mode]
    return wanted if wanted in rates else max(rates, key=float)


def default_display(available, display=None):
    display = display or {
        "layout": os.environ.get("BLIX_DISPLAY_LAYOUT", "extend"),
        "primaryOutput": os.environ.get("BLIX_PRIMARY_OUTPUT", ""),
        "primaryRotation": os.environ.get("BLIX_PRIMARY_ROTATION", "normal"),
        "externalOutput": os.environ.get("BLIX_EXTERNAL_OUTPUT", ""),
        "additionalExternalOutputs": os.environ.get("BLIX_ADDITIONAL_EXTERNAL_OUTPUTS", "").split(),
        "mirrorMode": os.environ.get("BLIX_MIRROR_MODE", "1920x1080"),
        "mirrorRate": os.environ.get("BLIX_MIRROR_RATE") or None,
        "primaryScaleFrom": os.environ.get("BLIX_PRIMARY_SCALE_FROM") or None,
    }
    connected = [item for item in available if item["connected"] and item["modes"]]
    if not connected:
        raise SettingsError("No connected displays were found.")
    primary = next((item for item in connected if item["name"] == display.get("primaryOutput")), connected[0])
    connected = [primary] + [item for item in connected if item is not primary]
    patterns = [display.get("externalOutput") or ""] + display.get("additionalExternalOutputs", [])
    mirrored = display.get("layout") == "mirror" and any(
        item != primary and any(fnmatch.fnmatchcase(item["name"], pattern) for pattern in patterns) for item in connected)
    selected = connected if not mirrored else [primary] + [item for item in connected if item != primary and
        any(fnmatch.fnmatchcase(item["name"], pattern) for pattern in patterns)]
    common = set.intersection(*(set(item["modes"]) for item in selected)) if mirrored else set()
    mirror_mode = display.get("mirrorMode")
    if mirrored and mirror_mode not in common:
        if not common:
            raise SettingsError("The displays have no common resolution for mirroring.")
        mirror_mode = max(common, key=lambda mode: math.prod(map(int, mode.split("x"))))
    plan, x = [], 0
    for item in connected:
        enabled = item in selected
        mode = preferred_mode(item, mirror_mode if mirrored else None)
        rotation = display.get("primaryRotation", "normal") if item == primary else "normal"
        scale = 1.0
        if item == primary and not mirrored and display.get("primaryScaleFrom"):
            logical_width = int(display["primaryScaleFrom"].split("x")[0])
            scale = mode_size(mode, rotation)[0] / logical_width
        plan.append({"name": item["name"], "enabled": enabled, "primary": item == primary,
                     "mode": mode, "rate": choose_rate(item, mode, display.get("mirrorRate") if mirrored else None),
                     "rotation": rotation, "scale": scale, "x": 0 if mirrored else x, "y": 0})
        if enabled and not mirrored:
            x += mode_size(mode, rotation, scale)[0]
    return {"layout": "mirror" if mirrored else "extend", "outputs": plan}


def validate_display(plan, available):
    if not isinstance(plan, dict) or plan.get("layout") not in ("mirror", "extend"):
        raise SettingsError("Choose a valid display layout.")
    actual = {item["name"]: item for item in available if item["connected"]}
    enabled, names = [], set()
    for item in plan.get("outputs", []):
        name = item.get("name")
        if name in names or name not in actual:
            raise SettingsError("The connected displays changed. Refresh and try again.")
        names.add(name)
        if not item.get("enabled"):
            continue
        if item.get("mode") not in actual[name]["modes"]:
            raise SettingsError(f"{name} does not advertise this resolution.")
        if str(item.get("rate")) not in actual[name]["modes"][item["mode"]]:
            raise SettingsError(f"{name} does not advertise this refresh rate at the selected resolution.")
        if item.get("rotation") not in ("normal", "left", "right", "inverted"):
            raise SettingsError("Choose a valid display rotation.")
        if not isinstance(item.get("scale"), (int, float)) or not 0.5 <= item["scale"] <= 4:
            raise SettingsError("Display scale must be between 50% and 400%.")
        if any(not isinstance(item.get(axis), int) or not 0 <= item[axis] <= 16384 for axis in ("x", "y")):
            raise SettingsError("Display positions must be between 0 and 16384 pixels.")
        enabled.append(item)
    if not enabled or sum(bool(item.get("primary")) for item in enabled) != 1:
        raise SettingsError("Enable at least one display and choose one enabled primary display.")
    if plan["layout"] == "mirror" and len({item["mode"] for item in enabled}) != 1:
        raise SettingsError("Mirrored displays must use the same resolution; refresh rates can differ.")
    return plan


def display_args(plan, snapshot=False):
    args = []
    for item in plan["outputs"]:
        args += ["--output", item["name"]]
        if not item["enabled"]:
            args += ["--off"]
            continue
        args += ["--mode", item["mode"], "--rate", str(item["rate"]), "--rotate", item["rotation"]]
        if snapshot:
            args += ["--transform", item.get("transform", "1,0,0,0,1,0,0,0,1")]
        else:
            width, height = mode_size(item["mode"], item["rotation"], item["scale"])
            args += ["--scale-from", f"{width}x{height}"]
        x, y = (0, 0) if plan.get("layout") == "mirror" else (item["x"], item["y"])
        args += ["--pos", f"{x}x{y}"]
        if item["primary"]:
            args += ["--primary"]
    return args


def snapshot_display(available):
    plan = {"layout": "extend", "outputs": [dict(item) for item in available if item["connected"]]}
    active = [item for item in plan["outputs"] if item["enabled"]]
    if active and not any(item["primary"] for item in active):
        active[0]["primary"] = True
    return plan


def restore_display(snapshot):
    available = outputs()
    names = {item["name"] for item in available if item["connected"]}
    restored = {"layout": "extend", "outputs": [item for item in snapshot["outputs"] if item["name"] in names]}
    active = [item for item in restored["outputs"] if item["enabled"] and item["mode"]]
    if not active:
        command("xrandr", *display_args(default_display(available)))
        return
    if not any(item["primary"] for item in active):
        active[0]["primary"] = True
    command("xrandr", *display_args(restored, snapshot=True))


def preview_display(request, input_stream=sys.stdin, output_stream=sys.stdout, seconds=15):
    """Separate watchdog: a dead GUI closes stdin and triggers immediate rollback."""
    root = runtime_root()
    marker = root / "display-preview.json"
    with (root / "display.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise SettingsError("Another display change is awaiting confirmation.") from error
        available = outputs()
        plan = validate_display(request["plan"], available)
        previous = snapshot_display(available)
        def interrupted(*_):
            raise SettingsError("The display preview was interrupted.")
        signal.signal(signal.SIGTERM, interrupted)
        signal.signal(signal.SIGINT, interrupted)
        atomic_json(marker, {"pid": os.getpid(), "expires": time.time() + seconds + 15})
        kept = False
        try:
            command("xrandr", *display_args(plan))
            deadline = time.monotonic() + seconds
            print(json.dumps({"ready": True, "seconds": seconds}), file=output_stream, flush=True)
            ready, _, _ = select.select([input_stream], [], [], max(0, deadline - time.monotonic()))
            answer = input_stream.readline().strip() if ready else "revert"
            if answer == "keep" and time.monotonic() <= deadline:
                Preferences().update("display", None if request.get("restore") else plan)
                kept = True
                (root / "display-cache.json").unlink(missing_ok=True)
        finally:
            try:
                if not kept:
                    restore_display(previous)
            finally:
                marker.unlink(missing_ok=True)
        print(json.dumps({"kept": kept}), file=output_stream, flush=True)


def saved_display(available, saved):
    """Keep per-connector choices; new dock connectors get advertised defaults."""
    base = default_display(available)
    by_name = {item["name"]: item for item in saved.get("outputs", [])}
    if saved.get("layout") not in ("mirror", "extend"):
        raise SettingsError("The saved display layout is invalid.")
    base["layout"] = saved["layout"]
    right = 0
    for item in base["outputs"]:
        actual = next(output for output in available if output["name"] == item["name"])
        remembered = by_name.get(item["name"])
        if remembered:
            item.update({key: remembered[key] for key in ("enabled", "primary", "rotation", "scale", "x", "y")})
            item["mode"] = preferred_mode(actual, remembered.get("mode"))
            item["rate"] = choose_rate(actual, item["mode"], remembered.get("rate"))
        else:
            item.update(enabled=True, primary=False, x=right, y=0)
        if item["enabled"]:
            right = max(right, item["x"] + mode_size(item["mode"], item["rotation"], item["scale"])[0])
    active = [item for item in base["outputs"] if item["enabled"]]
    if not active:
        base["outputs"][0]["enabled"] = True
        active = [base["outputs"][0]]
    primary = next((item for item in active if item["primary"]), active[0])
    for item in base["outputs"]:
        item["primary"] = item is primary
    if base["layout"] == "mirror":
        common = set.intersection(*(set(next(output for output in available if output["name"] == item["name"])["modes"]) for item in active))
        if not common:
            raise SettingsError("The connected displays have no common mirror resolution.")
        mode = primary["mode"] if primary["mode"] in common else max(common, key=lambda name: math.prod(map(int, name.split("x"))))
        for item in active:
            actual = next(output for output in available if output["name"] == item["name"])
            item.update(mode=mode, rate=choose_rate(actual, mode, item["rate"]), x=0, y=0, scale=1.0)
    return validate_display(base, available)


def apply_saved_display():
    root = runtime_root()
    marker = read_json(root / "display-preview.json")
    if marker and marker.get("expires", 0) > time.time():
        try:
            os.kill(int(marker["pid"]), 0)
            return 3
        except (ProcessLookupError, ValueError, KeyError):
            marker = {}
    saved = Preferences().read().get("display")
    if not saved:
        return 2
    available = outputs()
    fingerprint = hashlib.sha256(json.dumps([saved, [(item["name"], item["connected"], item["modes"])
        for item in available], os.environ.get("DISPLAY")], sort_keys=True).encode()).hexdigest()
    if read_json(root / "display-cache.json").get("fingerprint") == fingerprint:
        return 0
    plan = saved_display(available, saved)
    if plan["layout"] == "mirror":
        # Preserve the existing dock-link recovery policy on a new topology.
        # The fingerprint prevents resetting again for duplicate notifications.
        for item in plan["outputs"]:
            if item["enabled"] and not item["primary"]:
                command("xrandr", "--output", item["name"], "--off")
                try:
                    command("xrandr", "--output", item["name"], "--set", "max bpc", 8)
                except SettingsError:
                    pass  # Older connectors may not expose this link property.
    try:
        command("xrandr", *display_args(plan))
    except SettingsError:
        # Dock bandwidth can reject an advertised maximum. Let XRandR choose
        # timings independently at each output's requested resolution.
        args = display_args(plan)
        retry, index = [], 0
        while index < len(args):
            if args[index] == "--rate":
                index += 2
            else:
                retry.append(args[index])
                index += 1
        command("xrandr", *retry)
    atomic_json(root / "display-cache.json", {"fingerprint": fingerprint})
    return 0


def input_devices():
    devices = []
    for line in command("xinput", "--list", "--short").splitlines():
        match = re.search(r"(.+?)\s+id=(\d+).*slave\s+pointer", line)
        if not match:
            continue
        name = match[1].strip(" ⎜⎡⎣↳\t")
        properties = command("xinput", "list-props", match[2])
        props = {}
        for row in properties.splitlines():
            prop = re.match(r"\s+(.+?) \(\d+\):\s*(.*)", row)
            if prop:
                props[prop[1]] = prop[2]
        if "libinput Accel Speed" not in props:
            continue
        # A tablet or pointing stick is not an ordinary mouse. Do not offer
        # scrolling overrides that bypass Blix's device-specific Xorg rules.
        touchpad = "libinput Tapping Enabled" in props
        natural = "libinput Natural Scrolling Enabled" in props and (touchpad or
            not any(word in name.lower() for word in ("trackpoint", "pointing stick", "tablet", "stylus")))
        product = props.get("Device Product ID", name)
        devices.append({"id": match[2], "name": name, "key": f"{name}|{product}", "touchpad": touchpad,
                        "speed": float(props["libinput Accel Speed"].split(",")[0]),
                        "natural": props.get("libinput Natural Scrolling Enabled", "0") == "1" if natural else None,
                        "tapping": props.get("libinput Tapping Enabled") == "1" if touchpad else None})
    return devices


def set_input(device, values):
    allowed = {"speed": ("libinput Accel Speed", lambda value: isinstance(value, (float, int)) and -1 <= value <= 1),
               "natural": ("libinput Natural Scrolling Enabled", lambda value: isinstance(value, bool)),
               "tapping": ("libinput Tapping Enabled", lambda value: isinstance(value, bool))}
    for key, value in values.items():
        if key not in allowed or not allowed[key][1](value):
            raise SettingsError("The saved pointing-device setting is invalid.")
        if key != "speed" and device.get(key) is None:
            continue
        command("xinput", "set-prop", device["id"], allowed[key][0], int(value) if isinstance(value, bool) else value)


def apply_input_preferences():
    saved = Preferences().read().get("input_devices", {})
    if not saved:
        return
    for device in input_devices():
        if device["key"] in saved:
            set_input(device, saved[device["key"]])


def apply_session_preferences():
    saved = Preferences().read()
    keyboard = saved.get("keyboard")
    if keyboard:
        delay, rate = keyboard.get("delay"), keyboard.get("rate")
        if not isinstance(delay, int) or not 100 <= delay <= 2000 or not isinstance(rate, int) or not 1 <= rate <= 100:
            raise SettingsError("The saved keyboard repeat setting is invalid.")
        command("xset", "r", "rate", delay, rate)
    blank = saved.get("blank_seconds")
    if blank is not None:
        if not isinstance(blank, int) or not 0 <= blank <= 86400:
            raise SettingsError("The saved screen-off timer is invalid.")
        command("xset", "dpms", 0, 0, blank)
    apply_input_preferences()


def watch_input():
    apply_input_preferences()
    process = subprocess.Popen([TOOLS["udevadm"], "monitor", "--udev", "--property", "--subsystem-match=input"],
                               stdout=subprocess.PIPE, text=True)
    def stop(*_):
        process.terminate()
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    event = {}
    try:
        for line in process.stdout:
            line = line.strip()
            if not line:
                if event.get("ACTION") == "add" and event.get("DEVNAME", "").startswith("/dev/input/event"):
                    time.sleep(0.8)
                    try:
                        apply_input_preferences()
                    except SettingsError as error:
                        print(error, file=sys.stderr)
                event = {}
            elif "=" in line:
                key, value = line.split("=", 1)
                event[key] = value
    finally:
        process.terminate()
        process.wait(timeout=5)


def audio_state():
    def devices(kind):
        result = []
        for item in json.loads(command("pactl", "--format=json", "list", kind)):
            if kind == "sources" and (item.get("name", "").endswith(".monitor") or
                                     item.get("properties", {}).get("device.class") == "monitor"):
                continue
            volumes = [channel["value"] for channel in item.get("volume", {}).values()]
            result.append({"name": item["name"], "description": item.get("description", item["name"]),
                           "volume": round(sum(volumes) / len(volumes) / 65536 * 100) if volumes else 0,
                           "mute": item.get("mute", False)})
        return result
    return {"sinks": devices("sinks"), "sources": devices("sources"),
            "sink": command("pactl", "get-default-sink").strip(),
            "source": command("pactl", "get-default-source").strip()}


def brightness():
    result = command("brightnessctl", "--class=backlight", "--machine-readable").strip().split(",")
    return int(result[3].rstrip("%")) if len(result) >= 4 else None


def batteries():
    result = []
    for path in Path("/sys/class/power_supply").glob("*"):
        def read(name):
            try:
                return (path / name).read_text().strip()
            except OSError:
                return ""
        if read("type") != "Battery":
            continue
        result.append({"name": path.name, "capacity": read("capacity"), "status": read("status"),
                       "charge_limit": read("charge_control_end_threshold")})
    return result


def system_info():
    info = {}
    for line in Path("/etc/os-release").read_text().splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            info[key] = value.strip('"')
    memory = re.search(r"MemTotal:\s+(\d+)", Path("/proc/meminfo").read_text())
    cpu = re.search(r"(?:model name|Hardware)\s*:\s*(.+)", Path("/proc/cpuinfo").read_text())
    disk = shutil.disk_usage("/")
    return [("System", info.get("PRETTY_NAME", "NixOS")), ("Device", os.uname().nodename),
            ("Kernel", os.uname().release), ("Processor", cpu[1] if cpu else os.uname().machine),
            ("Memory", f"{int(memory[1]) / 1024 ** 2:.1f} GiB" if memory else "Unknown"),
            ("Storage available", f"{disk.free / 1024 ** 3:.1f} / {disk.total / 1024 ** 3:.1f} GiB"),
            ("Blix Settings", "0.1.0")]


def shortcut_reference(path=None):
    """Read the declarative Lua bindings without evaluating any Lua code."""
    candidate = Path(path) if path else Path(__file__).with_name("shortcuts.lua")
    try:
        source = candidate.read_text()
    except OSError:
        source = Path(__file__).with_name("shortcuts.lua").read_text()
    mod = re.search(r'local mod = "([^"]+)"', source)
    mod = mod[1] if mod else "Mod4"
    modifiers = {"Mod4": "Super", "Mod1": "Alt", "Control": "Ctrl", "Shift": "Shift"}
    actions = {
        "client.toggle_floating": "Toggle floating", "client.toggle_fullscreen": "Toggle fullscreen",
        "client.kill": "Close window", "tag.view_previous": "Previous workspace",
        "tag.view": "Switch workspace", "tag.move_to": "Move window to workspace",
        "layout.cycle": "Cycle layouts", "quit": "Log out", "spawn_terminal": "Terminal",
        "set_master_factor": "Adjust layout split", "inc_num_master": "Change master window count",
    }
    launchers = {"dmenu_run": "Application launcher", "firefox": "Firefox", "xfe": "File manager",
                 "blix-settings": "Blix Settings", "blix-lock": "Lock screen", "clipboard-history": "Clipboard history",
                 "control-menu": "Session controls", "blix-brightness": "Adjust brightness"}
    special = {"XF86AudioRaiseVolume": "Volume up", "XF86AudioLowerVolume": "Volume down",
               "XF86AudioMute": "Mute output", "XF86AudioMicMute": "Mute microphone",
               "XF86AudioPlay": "Play / pause", "XF86AudioNext": "Next track", "XF86AudioPrev": "Previous track",
               "XF86MonBrightnessUp": "Brightness up", "XF86MonBrightnessDown": "Brightness down"}
    result = []
    def append(mods, key, action):
        prefixes = []
        for item in mods.split(","):
            item = item.strip().strip('"')
            if item:
                prefixes.append(modifiers.get(mod if item == "mod" else item, item))
        binding = " + ".join([*prefixes, key])
        name = re.search(r"oxwm\.([\w.]+)\(", action)
        name = name[1] if name else ""
        title = special.get(key, actions.get(name, "Custom action"))
        launched = re.search(r'oxwm\.spawn\("([^"]+)"\)', action)
        if launched and key not in special:
            command_name = Path(launched[1].split()[0]).name.strip("@")
            title = launchers.get(command_name, command_name.replace("-", " ").title())
            if command_name == "screenshot-region":
                title = "Full screenshot" if "--full" in launched[1] else "Window screenshot" if "--window" in launched[1] else "Region screenshot"
        if name == "layout.set":
            layout = re.search(r'layout\.set\("([^"]+)"\)', action)
            title = f"{layout[1].capitalize()} layout" if layout else "Change layout"
        if name in ("client.focus_stack", "client.move_stack", "monitor.focus", "monitor.tag"):
            direction = "previous" if "-1" in action else "next"
            title = {"client.focus_stack": f"Focus {direction} window", "client.move_stack": f"Move window in stack ({direction})",
                     "monitor.focus": f"Focus {direction} monitor", "monitor.tag": f"Move to {direction} monitor"}[name]
        result.append((binding, title))
    for match in re.finditer(r'oxwm\.key\.bind\(\{([^}]*)\}, "([^"]+)", (.+)\)', source):
        append(*match.groups())
    numbers = re.search(r"for i = (\d+), (\d+) do\n(.*?)\nend", source, re.S)
    if numbers:
        for match in re.finditer(r"oxwm\.key\.bind\(\{([^}]*)\}, tostring\(i\), (.+)\)", numbers[3]):
            append(match[1], f"{numbers[1]}–{numbers[2]}", match[2])
    for loop in re.finditer(r"for _, key in ipairs\(\{([^}]*)\}\) do\n(.*?)\nend", source, re.S):
        keys = " / ".join(re.findall(r'"([^"]+)"', loop[1]))
        for match in re.finditer(r"oxwm\.key\.bind\(\{([^}]*)\}, key, (.+)\)", loop[2]):
            append(match[1], keys, match[2])
    return result
