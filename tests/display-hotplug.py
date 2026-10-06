"""Exercise display changes without an X server or physical monitors."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


source = Path(sys.argv[1]).read_text()
functions = source.split("\napply_gaming_keyboard\nconfigure_external_monitor\n", 1)[0]

with tempfile.TemporaryDirectory(prefix="blix-hotplug-check-") as temp:
    root = Path(temp)
    (root / "functions.sh").write_text(functions)
    for command, content in {
        "xrandr": 'if [[ $1 == --query ]]; then cat "$TEST_QUERY"; else printf "%s\\n" "$*" >> "$TEST_LOG"; fi\n',
        "xset": 'printf "xset %s\\n" "$*" >> "$TEST_LOG"\n',
    }.items():
        path = root / command
        path.write_text(f"#!{shutil.which('bash')}\n{content}")
        path.chmod(0o755)

    def run(name, layout, primary, query, expected, *, scale="", rotation="normal",
            dpi="", duplicates=False, unplug=None, reconnect=None):
        log = root / "commands.log"
        log.write_text("")
        (root / "query").write_text(query)
        env = dict(os.environ, PATH=f"{root}:" + os.environ["PATH"], DISPLAY=":99",
                   XDG_DATA_HOME=str(root), XDG_RUNTIME_DIR=str(root),
                   TEST_LOG=str(log), TEST_QUERY=str(root / "query"),
                   BLIX_PRIMARY_OUTPUT=primary, BLIX_DISPLAY_LAYOUT=layout,
                   BLIX_PRIMARY_ROTATION=rotation, BLIX_DISPLAY_DPI=dpi,
                   BLIX_EXTERNAL_OUTPUT="HDMI-1", BLIX_ADDITIONAL_EXTERNAL_OUTPUTS="DP-*",
                   BLIX_PRIMARY_SCALE_FROM=scale, BLIX_WALLPAPER="")
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
        "--output eDP-1 --mode 1920x1080 --rate 60 --rotate normal --scale 1x1 --pos 0x0 --primary",
        "--output HDMI-1 --off", "--output HDMI-1 --set max bpc 8",
        "--output HDMI-1 --mode 1920x1080 --rate 60 --scale 1x1 --same-as eDP-1",
        "--output DP-2-1 --off", "--output DP-2-1 --set max bpc 8",
        "--output DP-2-1 --mode 1920x1080 --rate 60 --scale 1x1 --same-as eDP-1",
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
