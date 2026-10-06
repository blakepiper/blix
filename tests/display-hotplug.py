"""Exercise display changes without an X server or physical monitors."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


source = Path(sys.argv[1]).read_text()
functions = source.split("\nconfigure_external_monitor\n", 1)[0]

with tempfile.TemporaryDirectory(prefix="blix-hotplug-check-") as temp:
    root = Path(temp)
    (root / "functions.sh").write_text(functions)
    for command, content in {
        "xrandr": '''if [[ $1 == --query ]]; then
    cat "$TEST_QUERY"
else
    printf "%s\\n" "$*" >> "$TEST_LOG"
    if [[ -n ${TEST_REJECT_RATE:-} && " $* " == *" --rate $TEST_REJECT_RATE "* ]]; then exit 1; fi
fi
''',
        "xset": 'printf "xset %s\\n" "$*" >> "$TEST_LOG"\n',
    }.items():
        path = root / command
        path.write_text(f"#!{shutil.which('bash')}\n{content}")
        path.chmod(0o755)

    def run(name, layout, primary, query, expected, *, scale="", rotation="normal",
            dpi="", duplicates=False, unplug=None, reconnect=None, mirror_rate="", reject_rate=""):
        log = root / "commands.log"
        log.write_text("")
        (root / "query").write_text(query)
        env = dict(os.environ, PATH=f"{root}:" + os.environ["PATH"], DISPLAY=":99",
                   XDG_DATA_HOME=str(root), XDG_RUNTIME_DIR=str(root),
                   TEST_LOG=str(log), TEST_QUERY=str(root / "query"),
                   BLIX_PRIMARY_OUTPUT=primary, BLIX_DISPLAY_LAYOUT=layout,
                   BLIX_PRIMARY_ROTATION=rotation, BLIX_DISPLAY_DPI=dpi,
                   BLIX_EXTERNAL_OUTPUT="HDMI-1", BLIX_ADDITIONAL_EXTERNAL_OUTPUTS="DP-*",
                   BLIX_PRIMARY_SCALE_FROM=scale, BLIX_WALLPAPER="",
                   BLIX_MIRROR_RATE=mirror_rate, TEST_REJECT_RATE=reject_rate)
        commands = 'source "$1" --once; configure_external_monitor'
        if duplicates:
            commands += "; configure_external_monitor"
        if unplug:
            (root / "unplug").write_text(unplug)
            commands += '; cp "$2" "$TEST_QUERY"; configure_external_monitor'
        if reconnect:
            (root / "reconnect").write_text(reconnect)
            commands += '; cp "$3" "$TEST_QUERY"; configure_external_monitor'
        subprocess.run(["bash", "-eu", "-c", commands, "_", str(root / "functions.sh"),
                        str(root / "unplug"), str(root / "reconnect")],
                       env=env, check=True, capture_output=True, text=True)
        actual = log.read_text().splitlines()
        assert actual == expected, f"{name}:\nexpected {expected}\nactual {actual}"
        print(f"PASS {name}")

    run("undocked laptop scaling", "mirror", "eDP-1", "eDP-1 connected\nHDMI-1 disconnected\n", [
        "--output HDMI-1 --off",
        "--output eDP-1 --auto --rotate normal --scale-from 1646x1029 --pos 0x0 --primary",
    ], scale="1646x1029")

    docked = [
        "--output DP-2-2 --off",
        "--output eDP-1 --mode 1920x1080 --rotate normal --scale 1x1 --pos 0x0 --primary",
        "--output HDMI-1 --off", "--output HDMI-1 --set max bpc 8",
        "--output HDMI-1 --mode 1920x1080 --scale 1x1 --same-as eDP-1",
        "--output DP-2-1 --off", "--output DP-2-1 --set max bpc 8",
        "--output DP-2-1 --mode 1920x1080 --scale 1x1 --same-as eDP-1",
        "xset dpms force on",
    ]
    query = "eDP-1 connected\nHDMI-1 connected\nDP-2-1 connected\nDP-2-2 disconnected\n"
    run("laptop dock mirrors and ignores duplicate events", "mirror", "eDP-1", query,
        docked, duplicates=True)
    run("laptop restores scaled panel after unplug", "mirror", "eDP-1", query, docked + [
        "--output HDMI-1 --off", "--output DP-2-1 --off", "--output DP-2-2 --off",
        "--output eDP-1 --auto --rotate normal --scale-from 1646x1029 --pos 0x0 --primary",
    ], scale="1646x1029",
        unplug="eDP-1 connected\nHDMI-1 disconnected\nDP-2-1 disconnected\nDP-2-2 disconnected\n")

    run("desktop extends three monitors", "extend", "DP-1",
        "DP-1 connected\nHDMI-1 connected\nDP-2 connected\n", [
            "--output DP-1 --auto --rotate normal --scale 1x1 --pos 0x0 --primary",
            "--output HDMI-1 --auto --scale 1x1 --right-of DP-1",
            "--output DP-2 --auto --scale 1x1 --right-of HDMI-1",
        ], duplicates=True)
    run("desktop single monitor", "extend", "DP-1", "DP-1 connected\n", [
        "--output DP-1 --auto --rotate normal --scale 1x1 --pos 0x0 --primary",
    ])
    run("missing primary leaves displays untouched", "extend", "DP-1",
        "HDMI-1 connected\n", [], rotation="left", dpi="192")

    for rotation in ("left", "right", "inverted"):
        run(f"phone {rotation} rotation with font DPI", "extend", "DSI-1",
            "DSI-1 connected 1080x2340+0+0\n", [
                f"--output DSI-1 --auto --rotate {rotation} --scale 1x1 --pos 0x0 --primary",
                "--dpi 192",
            ], rotation=rotation, dpi="192", duplicates=True)
    run("rotated panel scaling survives a disconnect and reconnect", "extend", "DSI-1",
        "DSI-1 connected\n", [
            "--output DSI-1 --auto --rotate left --scale-from 1560x720 --pos 0x0 --primary",
            "--dpi 192",
            "--output DSI-1 --auto --rotate left --scale-from 1560x720 --pos 0x0 --primary",
            "--dpi 192",
        ], rotation="left", dpi="192", scale="1560x720",
        unplug="DSI-1 disconnected\n", reconnect="DSI-1 connected\n")

    fast_panel = """eDP-1 connected primary 2880x1800+0+0
   1920x1080     60.00   120.00
   2880x1800    119.98   60.00*+  120.00
   1280x720     240.00
HDMI-1 disconnected
"""
    run("panel uses native resolution and numeric maximum, keeping scaling", "mirror", "eDP-1",
        fast_panel, [
            "--output HDMI-1 --off",
            "--output eDP-1 --mode 2880x1800 --rate 120.00 --rotate normal --scale-from 1646x1029 --pos 0x0 --primary",
        ], scale="1646x1029", duplicates=True)

    mixed = """DP-1 connected primary 3840x2160+0+0
   3840x2160   60.00*+  143.98  120.00
   1920x1080  240.00
HDMI-1 connected 2560x1440+3840+0
   2560x1440  59.95*+  99.95  165.00
   1920x1080  240.00
DP-2 connected 1920x1080+6400+0
   1920x1080  59.94*+  60.00
"""
    run("extended monitors keep preferred resolutions with independent maximum rates", "extend", "DP-1",
        mixed, [
            "--output DP-1 --mode 3840x2160 --rate 143.98 --rotate normal --scale 1x1 --pos 0x0 --primary",
            "--output HDMI-1 --mode 2560x1440 --rate 165.00 --scale 1x1 --right-of DP-1",
            "--output DP-2 --mode 1920x1080 --rate 60.00 --scale 1x1 --right-of HDMI-1",
        ], duplicates=True)

    fast_mirror = """eDP-1 connected
   2880x1800  60.00*+  120.00
   1920x1080  120.00  60.00
HDMI-1 connected
   1920x1080  60.00*+  99.95  165.00
   1280x720   240.00
"""
    mirror_commands = [
        "--output eDP-1 --mode 1920x1080 --rate 120.00 --rotate normal --scale 1x1 --pos 0x0 --primary",
        "--output HDMI-1 --off", "--output HDMI-1 --set max bpc 8",
        "--output HDMI-1 --mode 1920x1080 --rate 165.00 --scale 1x1 --same-as eDP-1",
        "xset dpms force on",
    ]
    run("mirrors choose each output's fastest rate at the configured resolution", "mirror", "eDP-1",
        fast_mirror, mirror_commands, duplicates=True)
    markers_changed = fast_mirror.replace("120.00  60.00", "120.00*  60.00").replace(
        "60.00*+  99.95  165.00", "60.00+  99.95  165.00*")
    run("active rate markers do not trigger another dock reset", "mirror", "eDP-1",
        fast_mirror, mirror_commands, reconnect=markers_changed)
    rate_added = fast_mirror.replace("99.95  165.00", "99.95  165.00  240.00")
    faster_commands = [line.replace("--rate 165.00", "--rate 240.00") for line in mirror_commands]
    run("newly available rates are applied without a physical unplug", "mirror", "eDP-1",
        fast_mirror, mirror_commands + faster_commands, reconnect=rate_added)
    fixed = [line.replace("--rate 120.00", "--rate 75").replace("--rate 165.00", "--rate 75")
             for line in mirror_commands]
    run("explicit mirror-rate overrides remain supported", "mirror", "eDP-1",
        fast_mirror, fixed, mirror_rate="75")
    fallback = mirror_commands[:-1] + [
        "--output HDMI-1 --mode 1920x1080 --scale 1x1 --same-as eDP-1",
        "xset dpms force on",
    ]
    run("rejected dock timing falls back without leaving the monitor off", "mirror", "eDP-1",
        fast_mirror, fallback, reject_rate="165.00", duplicates=True)
