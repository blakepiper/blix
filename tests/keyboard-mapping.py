"""Verify the built-in Win and external Cmd keys compile to Super."""
import json
from pathlib import Path
import re
import subprocess
import sys


settings = json.loads(Path(sys.argv[1]).read_text())
rules = [rule for rule in settings["inputClassSections"] if "altwin:swap_alt_win" in rule]
assert len(rules) == 1, "Modifier swapping must be confined to one device rule"
rule = rules[0]
assert re.search(r'MatchUSBID\s+"1fc9:e8c7"', rule), "Mechanical keyboard USB match missing"
assert re.search(r'MatchIsKeyboard\s+"on"', rule), "Rule must target keyboard interfaces"
assert "altwin:swap_alt_win" not in settings["options"], "Global layout would remap laptop Win"


def compile_keymap(layout, options):
    return subprocess.check_output([
        "xkbcli", "compile-keymap", "--rules", "evdev",
        "--model", settings["model"], "--layout", layout,
        "--variant", settings["variant"], "--options", options,
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
