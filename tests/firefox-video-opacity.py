"""Exercise the packaged extension in a private browser and Picom on Xvfb."""

import ctypes as c
import functools
import http.server
import json
import os
from pathlib import Path
import select
import socket
import subprocess as sp
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request
import wave

firefox, geckodriver, ffmpeg, xvfb_path, picom, picom_conf, xlib_path = sys.argv[1:]
marker = "[blix-video] "


def wait_for(predicate, message, timeout=10):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.05)
    raise AssertionError(message)


class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


with tempfile.TemporaryDirectory(prefix="blix-video-opacity-") as directory:
    root = Path(directory)
    sp.run([ffmpeg, "-v", "error", "-f", "lavfi", "-i", "color=c=red:s=160x90:r=5",
            "-t", "1", "-an", "-c:v", "libvpx", str(root / "video.webm")], check=True)
    with wave.open(str(root / "audio.wav"), "wb") as audio:
        audio.setparams((1, 2, 8000, 0, "NONE", "not compressed"))
        audio.writeframes(bytes(16000))
    (root / "index.html").write_text('''<!doctype html><title>Video fixture</title>
        <video id="video" src="video.webm" muted loop></video>
        <video id="second" src="video.webm" muted loop></video>
        <audio id="audio" src="audio.wav" muted loop></audio>''')
    (root / "frame.html").write_text('''<!doctype html><title>Frame</title>
        <video id="video" src="video.webm" muted loop autoplay></video>''')
    (root / "blank.html").write_text("<!doctype html><title>Ordinary page</title>")
    handler = functools.partial(Handler, directory=directory)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    url = f"http://127.0.0.1:{server.server_port}"
    sock = socket.socket()
    sock.bind(("127.0.0.1", 0))
    port = sock.getsockname()[1]
    sock.close()
    env = os.environ | {
        "MOZ_ENABLE_WAYLAND": "0",
        "XDG_CACHE_HOME": str(root / "cache"),
        "XDG_CONFIG_HOME": str(root / "config"),
    }
    log = (root / "process.log").open("w+")
    xvfb = sp.Popen([xvfb_path, "-displayfd", "1", "-screen", "0", "1024x768x24",
                     "-nolisten", "tcp"], stdout=sp.PIPE, stderr=log, text=True, env=env)
    processes = [xvfb]
    session = None
    base = f"http://127.0.0.1:{port}"

    def api(method, path, data=None):
        request = urllib.request.Request(base + path, method=method,
            data=None if data is None else json.dumps(data).encode(),
            headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(request, timeout=40) as response:
                return json.load(response)["value"]
        except urllib.error.HTTPError as error:
            raise AssertionError(error.read().decode()) from error

    def command(method, path, data=None):
        if path.startswith("/window"):
            api("POST", "/session/" + session + "/moz/context", {"context": "content"})
        return api(method, "/session/" + session + path, data)

    def script(source, chrome=False, asynchronous=False):
        command("POST", "/moz/context", {"context": "chrome" if chrome else "content"})
        return command("POST", "/execute/" + ("async" if asynchronous else "sync"),
                       {"script": source, "args": []})

    def marked(expected):
        wait_for(lambda: script("return document.title;", chrome=True).startswith(marker)
                 == expected, f"Expected video marker {expected}")

    def navigate(path):
        command("POST", "/moz/context", {"context": "content"})
        command("POST", "/url", {"url": url + path})

    try:
        assert select.select([xvfb.stdout], [], [], 10)[0], "Xvfb failed to start"
        env["DISPLAY"] = ":" + xvfb.stdout.readline().strip()
        processes.append(sp.Popen([geckodriver, "--allow-system-access", "--host", "127.0.0.1",
                                    "--port", str(port), "--profile-root", directory],
                                   stdout=log, stderr=log, env=env))

        def ready():
            try:
                return api("GET", "/status")["ready"]
            except (OSError, AssertionError):
                return False

        wait_for(ready, "WebDriver did not start")
        (root / "profile").mkdir()
        capabilities = {"browserName": "firefox", "moz:firefoxOptions": {
            "binary": firefox, "args": ["-no-remote", "-profile", str(root / "profile")], "prefs": {
                "media.autoplay.default": 0,
                "browser.shell.checkDefaultBrowser": False,
                "browser.startup.homepage_override.mstone": "ignore",
            }}}
        session = api("POST", "/session", {
            "capabilities": {"alwaysMatch": capabilities}})["sessionId"]
        navigate("/index.html")
        installed = script('''const done = arguments[arguments.length - 1];
            const { AddonManager } = ChromeUtils.importESModule("resource://gre/modules/AddonManager.sys.mjs");
            AddonManager.getAddonByID("video-opacity@blix.local").then(addon => done({
                active: addon?.isActive, temporary: addon?.temporarilyInstalled,
                signatures: Services.prefs.getBoolPref("xpinstall.signatures.required"),
                sandbox: Services.prefs.getIntPref("security.sandbox.content.level")
            }));''', chrome=True, asynchronous=True)
        assert installed["active"] and not installed["temporary"], installed
        assert installed["signatures"] and installed["sandbox"] > 0, installed
        marked(False)
        script("document.getElementById('audio').play();")
        marked(False)
        script("document.getElementById('video').play();")
        marked(True)
        script("document.getElementById('video').pause();")
        marked(False)
        print("PASS: installed built-in, signing/sandbox preserved, audio ignored, play/pause", flush=True)

        script("document.getElementById('video').play(); document.getElementById('second').play();")
        marked(True)
        script("document.getElementById('video').pause();")
        marked(True)
        script("document.getElementById('second').remove();")
        marked(False)
        script("const v = document.getElementById('video'); v.currentTime=0; v.loop=false; v.play();")
        marked(True)
        wait_for(lambda: script("return document.getElementById('video').ended;"), "Video did not end")
        marked(False)
        print("PASS: multiple videos, removed video, natural completion", flush=True)

        script("const v = document.getElementById('video'); v.loop=true; v.play();")
        marked(True)
        first = command("GET", "/window")
        second = command("POST", "/window/new", {"type": "tab"})["handle"]
        command("POST", "/window", {"handle": second})
        navigate("/blank.html")
        marked(False)
        command("POST", "/window", {"handle": first})
        marked(True)
        # Force the event page to unload while a video plays, then prove that
        # a tab switch restores its state without persistent ports or polling.
        script('''const done = arguments[arguments.length - 1];
            WebExtensionPolicy.getByID("video-opacity@blix.local").extension
                .terminateBackground().then(() => done(true));''', chrome=True, asynchronous=True)
        time.sleep(0.5)
        assert script('''return WebExtensionPolicy.getByID("video-opacity@blix.local")
            .extension.backgroundState;''', chrome=True) == "stopped"
        command("POST", "/window", {"handle": second})
        marked(False)
        command("POST", "/window", {"handle": first})
        marked(True)
        navigate("/blank.html")
        marked(False)
        print("PASS: background tab excluded, tab restore, idle background restart, navigation", flush=True)

        script(f'''const frame = document.createElement('iframe'); frame.id='frame';
            frame.src='http://localhost:{server.server_port}/frame.html'; document.body.append(frame);''')
        marked(True)
        script("document.getElementById('frame').src='blank.html';")
        marked(False)
        script(f"document.getElementById('frame').src='http://localhost:{server.server_port}/frame.html';")
        marked(True)
        script("document.getElementById('frame').remove();")
        marked(False)
        print("PASS: cross-origin iframe playback, frame navigation/removal", flush=True)

        navigate("/index.html")
        script("document.getElementById('video').play();")
        marked(True)
        separate = command("POST", "/window/new", {"type": "window"})["handle"]
        command("POST", "/window", {"handle": separate})
        navigate("/blank.html")
        marked(False)
        command("POST", "/window", {"handle": first})
        marked(True)
        command("DELETE", "/window")
        command("POST", "/window", {"handle": separate})
        marked(False)
        print("PASS: independent windows and closing a playback window", flush=True)

        handles = set(command("GET", "/window/handles"))
        script("OpenBrowserWindow({private: true});", chrome=True)
        wait_for(lambda: len(command("GET", "/window/handles")) > len(handles),
                 "Private window did not open")
        private = (set(command("GET", "/window/handles")) - handles).pop()
        command("POST", "/window", {"handle": private})
        navigate("/index.html")
        script("document.getElementById('video').play();")
        marked(True)
        script("document.getElementById('video').pause();")
        marked(False)
        print("PASS: private browsing playback", flush=True)

        api("DELETE", "/session/" + session)
        session = None
        session = api("POST", "/session", {
            "capabilities": {"alwaysMatch": capabilities}})["sessionId"]
        navigate("/index.html")
        script("document.getElementById('video').play();")
        marked(True)
        script("document.getElementById('video').pause();")
        marked(False)
        api("DELETE", "/session/" + session)
        session = None
        print("PASS: persistent installation across Firefox restart with the same profile", flush=True)

        # The production Picom configuration must turn the marker into actual
        # rendered opacity. Sample the composited X11 framebuffer, not a rule mock.
        x = c.CDLL(xlib_path)
        x.XOpenDisplay.argtypes = [c.c_char_p]; x.XOpenDisplay.restype = c.c_void_p
        x.XDefaultRootWindow.argtypes = [c.c_void_p]; x.XDefaultRootWindow.restype = c.c_ulong
        x.XCreateSimpleWindow.argtypes = [c.c_void_p, c.c_ulong, c.c_int, c.c_int,
            c.c_uint, c.c_uint, c.c_uint, c.c_ulong, c.c_ulong]
        x.XCreateSimpleWindow.restype = c.c_ulong
        x.XInternAtom.argtypes = [c.c_void_p, c.c_char_p, c.c_int]; x.XInternAtom.restype = c.c_ulong
        x.XGetSelectionOwner.argtypes = [c.c_void_p, c.c_ulong]; x.XGetSelectionOwner.restype = c.c_ulong
        for name in ["XMapRaised", "XDestroyWindow", "XClearWindow"]:
            getattr(x, name).argtypes = [c.c_void_p, c.c_ulong]
        x.XStoreName.argtypes = [c.c_void_p, c.c_ulong, c.c_char_p]
        x.XSetInputFocus.argtypes = [c.c_void_p, c.c_ulong, c.c_int, c.c_ulong]
        x.XSync.argtypes = [c.c_void_p, c.c_int]
        x.XGetImage.argtypes = [c.c_void_p, c.c_ulong, c.c_int, c.c_int, c.c_uint,
                               c.c_uint, c.c_ulong, c.c_int]; x.XGetImage.restype = c.c_void_p
        x.XGetPixel.argtypes = [c.c_void_p, c.c_int, c.c_int]; x.XGetPixel.restype = c.c_ulong
        x.XDestroyImage.argtypes = [c.c_void_p]
        x.XCloseDisplay.argtypes = [c.c_void_p]
        display = x.XOpenDisplay(env["DISPLAY"].encode())
        assert display, "Cannot open isolated display"
        root_window = x.XDefaultRootWindow(display)
        processes.append(sp.Popen([picom, "--config", picom_conf, "--no-vsync"],
                                   stdout=log, stderr=log, env=env))
        compositor = x.XInternAtom(display, b"_NET_WM_CM_S0", False)
        wait_for(lambda: x.XGetSelectionOwner(display, compositor), "Picom failed to start")
        window = x.XCreateSimpleWindow(display, root_window, 0, 0, 200, 200, 0, 0, 0xCC6432)

        class ClassHint(c.Structure):
            _fields_ = [("res_name", c.c_char_p), ("res_class", c.c_char_p)]

        x.XSetClassHint.argtypes = [c.c_void_p, c.c_ulong, c.POINTER(ClassHint)]
        x.XSetClassHint(display, window, c.byref(ClassHint(b"Navigator", b"firefox")))
        x.XStoreName(display, window, b"Video fixture")
        x.XMapRaised(display, window)
        x.XSetInputFocus(display, window, 1, 0)
        x.XSync(display, False)

        def red():
            image = x.XGetImage(display, root_window, 50, 50, 1, 1, c.c_ulong(-1), 2)
            assert image
            pixel = x.XGetPixel(image, 0, 0)
            x.XDestroyImage(image)
            return (pixel >> 16) & 255

        wait_for(lambda: 150 < red() < 195, "Normal Firefox did not render translucent")
        x.XStoreName(display, window, b"[blix-video] Video fixture")
        x.XSync(display, False)
        wait_for(lambda: red() == 204, "Video marker did not render fully opaque")
        x.XStoreName(display, window, b"YouTube - paused")
        x.XSync(display, False)
        wait_for(lambda: 150 < red() < 195, "Old YouTube title still forces opacity")
        x.XDestroyWindow(display, window)
        x.XCloseDisplay(display)
        print("PASS: Picom rendered opacity follows video marker; YouTube title alone is translucent", flush=True)
    except Exception:
        log.flush()
        log.seek(0)
        print(log.read()[-12000:], file=sys.stderr)
        raise
    finally:
        if session:
            try:
                api("DELETE", "/session/" + session)
            except Exception:
                pass
        for process in reversed(processes):
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except sp.TimeoutExpired:
                    process.kill()
                    process.wait()
        server.shutdown()
        server.server_close()
        log.close()
