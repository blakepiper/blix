"""Exercise Steam-style input hints and rendered game opacity on isolated X11."""
import ctypes as c
import os
from pathlib import Path
import select
import subprocess as sp
import sys
import tempfile
import time

wm, xvfb, picom, xdotool, xlib, config = sys.argv[1:]
x = c.CDLL(xlib)
def bind(name, args, result=c.c_int):
    f = getattr(x, name); f.argtypes = args; f.restype = result
    return f
P, W, I, U = c.c_void_p, c.c_ulong, c.c_int, c.c_uint
bind('XOpenDisplay', [c.c_char_p], P)
bind('XDefaultRootWindow', [P], W)
bind('XCreateSimpleWindow', [P,W,I,I,U,U,U,W,W], W)
bind('XSetWMHints', [P,W,P]); bind('XSetWMProtocols', [P,W,P,I])
bind('XSetClassHint', [P,W,P]); bind('XSelectInput', [P,W,c.c_long])
bind('XMapRaised', [P,W]); bind('XSync', [P,I]); bind('XPending', [P])
bind('XNextEvent', [P,P]); bind('XGetInputFocus', [P,P,P])
bind('XInternAtom', [P,c.c_char_p,I], W)
bind('XChangeProperty', [P,W,W,W,I,I,P,I])
bind('XDeleteProperty', [P,W,W]); bind('XSetInputFocus', [P,W,I,W])
bind('XGetImage', [P,W,I,I,U,U,W,I], P)
bind('XGetPixel', [P,I,I], W); bind('XDestroyImage', [P])
bind('XCloseDisplay', [P]); bind('XDestroyWindow', [P,W])
class Hints(c.Structure):
    _fields_ = [('flags',c.c_long),('input',I),('state',I),('pixmap',W),
                ('window',W),('x',I),('y',I),('mask',W),('group',W)]
class Class(c.Structure):
    _fields_ = [('instance',c.c_char_p),('class_',c.c_char_p)]
def wait_for(test, message):
    end = time.monotonic() + 8
    while time.monotonic() < end:
        if test(): return
        time.sleep(.03)
    raise AssertionError(message)
with tempfile.TemporaryDirectory(prefix='blix-steam-') as directory:
    root = Path(directory); env = os.environ.copy(); env.pop('XAUTHORITY', None)
    processes = []
    with (root/'log').open('w+') as log:
        try:
            server = sp.Popen([xvfb,'-displayfd','1','-screen','0','800x600x24','-nolisten','tcp'], stdout=sp.PIPE,stderr=log,env=env,text=True)
            processes.append(server)
            assert select.select([server.stdout],[],[],10)[0]
            env['DISPLAY'] = ':' + server.stdout.readline().strip()
            d = x.XOpenDisplay(env['DISPLAY'].encode()); assert d
            r = x.XDefaultRootWindow(d)
            lua = root/'config.lua'
            lua.write_text("oxwm.set_tags({'1'})\noxwm.bar.set_font('DejaVu Sans:size=10')\n")
            manager = sp.Popen([wm,'-c',str(lua)],env=env,stdout=log,stderr=log); processes.append(manager)
            time.sleep(.5)
            def focus():
                w=W(); revert=I(); x.XGetInputFocus(d,c.byref(w),c.byref(revert)); return w.value
            def window(class_, accepts_input):
                w=x.XCreateSimpleWindow(d,r,0,0,300,300,0,0,0xCC6432)
                x.XSetClassHint(d,w,c.byref(Class(class_,class_)))
                x.XSetWMHints(d,w,c.byref(Hints(flags=1,input=accepts_input)))
                protocols=(W*1)(x.XInternAtom(d,b'WM_TAKE_FOCUS',0))
                x.XSetWMProtocols(d,w,protocols,1)
                x.XSelectInput(d,w,1) # KeyPressMask
                x.XMapRaised(d,w); x.XSync(d,0); return w
            ordinary=window(b'ordinary',True)
            wait_for(lambda: focus()==ordinary,'Ordinary client did not focus')
            game=window(b'steam_app_12345',False)
            wait_for(lambda: focus()==game,'Steam-style InputHint=False window left focus on previous client')
            # A genuine key event must reach the game, not merely the root property.
            while x.XPending(d):
                event=(c.c_long*24)(); x.XNextEvent(d,c.byref(event))
            sp.run([xdotool,'key','w','a','s','d'],env=env,check=True)
            keys=[]
            def received():
                while x.XPending(d):
                    event=(c.c_long*24)(); x.XNextEvent(d,c.byref(event))
                    if event[0] & 0xffffffff == 2 and event[4] == game: keys.append(event)
                return len(keys)>=4
            wait_for(received,'WASD did not reach game window')
            print('PASS: Steam-style globally active game receives keyboard focus and WASD')
            non_game=window(b'steam',False)
            time.sleep(.3)
            assert focus()!=non_game, 'Non-game InputHint=False was overridden'
            manager.terminate(); manager.wait(timeout=4)
            for previous in (ordinary, game, non_game): x.XDestroyWindow(d,previous)
            x.XSync(d,0)
            # Without a WM, use a fixed fixture to sample Picom pixels.
            render=x.XCreateSimpleWindow(d,r,0,0,200,200,0,0,0xCC6432)
            x.XSetClassHint(d,render,c.byref(Class(b'fixture',b'fixture')))
            x.XMapRaised(d,render); x.XSetInputFocus(d,render,1,0); x.XSync(d,0)
            marker=x.XInternAtom(d,b'STEAM_GAME',0)
            compositor=sp.Popen([picom,'--config',config,'--no-vsync'],env=env,stdout=log,stderr=log); processes.append(compositor)
            def red():
                img=x.XGetImage(d,r,50,50,1,1,W(-1),2); assert img
                pixel=x.XGetPixel(img,0,0); x.XDestroyImage(img); return (pixel>>16)&255
            wait_for(lambda: 150<red()<195,'Ordinary window did not remain translucent')
            app=W(12345)
            x.XChangeProperty(d,render,marker,6,32,0,c.byref(app),1); x.XSync(d,0)
            wait_for(lambda: red()==204,'STEAM_GAME did not force opacity')
            x.XDeleteProperty(d,render,marker)
            x.XSetClassHint(d,render,c.byref(Class(b'steam_app_56789',b'other'))); x.XSync(d,0)
            wait_for(lambda: red()==204,'Steam game instance did not force opacity')
            x.XSetClassHint(d,render,c.byref(Class(b'other',b'steam_app_56789'))); x.XSync(d,0)
            wait_for(lambda: red()==204,'Steam game class did not force opacity')
            x.XSetInputFocus(d,r,1,0); x.XSync(d,0)
            wait_for(lambda: red()==204,'Unfocused game became translucent')
            x.XSetClassHint(d,render,c.byref(Class(b'fixture',b'fixture'))); x.XSync(d,0)
            wait_for(lambda: 150<red()<195,'Removing game markers did not restore transparency')
            print('PASS: Steam property/class/instance games stay opaque, focused or unfocused; ordinary apps remain translucent')
            x.XCloseDisplay(d)
        except Exception:
            log.flush(); log.seek(0); print(log.read()[-8000:],file=sys.stderr); raise
        finally:
            for process in reversed(processes):
                if process.poll() is None:
                    process.terminate(); process.wait(timeout=5)
