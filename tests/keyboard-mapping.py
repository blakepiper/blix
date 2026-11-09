"""Compile workstation and phone maps and check their actual modifier symbols."""
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile


settings = json.loads(Path(sys.argv[1]).read_text())
assert not any("altwin:swap_alt_win" in rule for rule in settings["inputClassSections"]), \
    "Xorg must not apply the swap a second time"
assert "altwin:swap_alt_win" not in settings["options"], "Global layout would remap laptop Win"
with tempfile.TemporaryDirectory() as directory:
    hwdb_dir = Path(directory) / "etc/udev/hwdb.d"
    hwdb_dir.mkdir(parents=True)
    (hwdb_dir / "90-blix-keyboard.hwdb").write_text(settings["hwdb"])
    subprocess.run(["systemd-hwdb", "--root", directory, "--strict", "update"], check=True)

    def query(identity):
        result = subprocess.run(["systemd-hwdb", "--root", directory, "query", identity],
                                text=True, capture_output=True)
        return dict(line.split("=", 1) for line in result.stdout.splitlines())

    mapping = query("evdev:input:b0003v1FC9pE8C7e0100-e0,1,k")
    assert mapping == {
        "KEYBOARD_KEY_700e2": "leftmeta", "KEYBOARD_KEY_700e3": "leftalt",
        "KEYBOARD_KEY_700e6": "rightmeta", "KEYBOARD_KEY_700e7": "rightalt",
    }, mapping
    assert not query("evdev:input:b0003v046DpC08Be0111-e0,1,k"), "Other USB keyboards must not match"
    assert not query("evdev:input:b0011v0001p0001eAB41-e0,1,k"), "Built-in keyboard must not match"
    assert not query("evdev:input:b0005v1FC9pE8C7e0100-e0,1,k"), "Bluetooth must not match"


def compile_keymap(layout, options, configuration=settings, include=None):
    return subprocess.check_output([
        "xkbcli", "compile-keymap", "--rules", "evdev",
        *(["--include", str(include), "--include-defaults"] if include else []),
        "--model", configuration["model"], "--layout", layout,
        "--variant", configuration["variant"], "--options", options,
    ], text=True)


def check_key(keymap, name, symbol):
    key = re.search(r"key\s+<" + name + r">\s*\{(.*?)\};", keymap, re.S)
    assert key, f"Missing key {name}"
    symbols = re.search(r"symbols\[[^\]]+\]\s*=\s*\[\s*(\w+)", key.group(1))
    if not symbols:
        symbols = re.search(r"^\s*\[\s*(\w+)", key.group(1), re.M)
    assert symbols and symbols.group(1) == symbol, f"{name} did not resolve to {symbol}"


builtin = compile_keymap(settings["layout"], settings["options"])
# Resolve the remapped kernel modifier keycodes through the same XKB map used
# by Xorg and labwc, checking both sides of the physical Alt/Win positions.
keycode_names = {"leftmeta": "LWIN", "rightmeta": "RWIN", "leftalt": "LALT", "rightalt": "RALT"}
for suffix, alt_scan, win_scan in (("L", "700e2", "700e3"), ("R", "700e6", "700e7")):
    check_key(builtin, suffix + "WIN", "Super_" + suffix)
    check_key(builtin, suffix + "ALT", "Alt_" + suffix)
    check_key(builtin, keycode_names[mapping["KEYBOARD_KEY_" + alt_scan]], "Super_" + suffix)
    check_key(builtin, keycode_names[mapping["KEYBOARD_KEY_" + win_scan]], "Alt_" + suffix)
print("PASS built-in Win stays Super; mechanical Cmd maps to Super")

phone = json.loads(Path(sys.argv[2]).read_text())
phone_rules = [rule for rule in phone["inputClassSections"] if "altwin:swap_lalt_lwin" in rule]
assert len(phone_rules) == 1, "Phone swap must belong to one device rule"
phone_rule = phone_rules[0]
assert re.search(r'MatchProduct\s+"Bluetooth Keyboard"', phone_rule)
assert re.search(r'MatchIsKeyboard\s+"on"', phone_rule)
assert "altwin:swap_lalt_lwin" not in phone["options"]
phone_layout = re.search(r'Option\s+"XkbLayout"\s+"([^"]+)"', phone_rule).group(1)
phone_options = re.search(r'Option\s+"XkbOptions"\s+"([^"]+)"', phone_rule).group(1)
with tempfile.TemporaryDirectory() as directory:
    symbols = Path(directory) / "symbols"
    symbols.mkdir()
    for name, text in phone["symbols"].items():
        (symbols / name).write_text(text)
    phone_keys = compile_keymap(phone_layout, phone_options, phone, directory)
phone_default = compile_keymap(phone["layout"], phone["options"], phone)
for keymap in (builtin, phone_default):
    check_key(keymap, "TLDE", "grave")
check_key(phone_keys, "TLDE", "Escape")
check_key(phone_keys, "ESC", "Escape")
check_key(phone_keys, "AD01", "q")
check_key(phone_keys, "LALT", "Super_L")
check_key(phone_keys, "LWIN", "Alt_L")
check_key(phone_keys, "RALT", "Alt_R")
check_key(phone_keys, "RWIN", "Super_R")
print("PASS phone Bluetooth left Alt is Super; right modifiers stay unchanged")
print("PASS phone Bluetooth grave is Escape; other keyboards retain grave")
