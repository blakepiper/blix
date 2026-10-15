"""Compile workstation and phone maps and check their actual modifier symbols."""
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile


settings = json.loads(Path(sys.argv[1]).read_text())
rules = [rule for rule in settings["inputClassSections"] if "altwin:swap_alt_win" in rule]
assert len(rules) == 1, "Modifier swapping must be confined to one device rule"
rule = rules[0]
assert re.search(r'MatchUSBID\s+"1fc9:e8c7"', rule), "Mechanical keyboard USB match missing"
assert re.search(r'MatchIsKeyboard\s+"on"', rule), "Rule must target keyboard interfaces"
assert "altwin:swap_alt_win" not in settings["options"], "Global layout would remap laptop Win"


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
external_layout = re.search(r'Option\s+"XkbLayout"\s+"([^"]+)"', rule).group(1)
external_options = re.search(r'Option\s+"XkbOptions"\s+"([^"]+)"', rule).group(1)
external = compile_keymap(external_layout, external_options)
for suffix in ("L", "R"):
    check_key(builtin, suffix + "WIN", "Super_" + suffix)
    check_key(builtin, suffix + "ALT", "Alt_" + suffix)
    check_key(external, suffix + "ALT", "Super_" + suffix)
    check_key(external, suffix + "WIN", "Alt_" + suffix)
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
for keymap in (builtin, external, phone_default):
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
