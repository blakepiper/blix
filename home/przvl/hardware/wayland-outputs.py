"""Apply host display defaults at login and DRM hotplug, without idle polling."""
import fnmatch
import json
import subprocess
import sys
import time


def plan(outputs, settings):
    primary = next((o for o in outputs if o['name'] == settings['primary']), None)
    if primary is None:
        return []
    patterns = settings['external']
    external = [o for o in outputs if o is not primary and any(
        fnmatch.fnmatchcase(o['name'], pattern) for pattern in patterns)]
    mirrored = settings['layout'] == 'mirror' and bool(external)
    selected = [primary, *external] if mirrored else [primary]
    mode = settings['mode']
    if mirrored:
        common = set.intersection(*({(m['width'], m['height']) for m in o['modes']} for o in selected))
        requested = tuple(map(int, mode.split('x')))
        if requested not in common:
            if not common:
                raise ValueError('Connected displays have no common mirror resolution')
            requested = max(common, key=lambda size: size[0] * size[1])
        mode = f'{requested[0]}x{requested[1]}'
    scale = settings['scales'].get(primary['name'], 1)
    args = []
    for output in selected:
        args += ['--output', output['name'], '--on']
        if mirrored:
            modes = [m for m in output['modes'] if f"{m['width']}x{m['height']}" == mode]
            rate = settings['rate']
            chosen = min(modes, key=lambda m: abs(m['refresh'] - float(rate))) if rate else max(modes, key=lambda m: m['refresh'])
            mode_arg = f"{mode}@{chosen['refresh']:.6f}Hz" if chosen['refresh'] > 0 else mode
            args += ['--mode', mode_arg, '--pos', '0,0', '--scale', str(scale)]
        else:
            args += ['--preferred', '--pos', '0,0', '--scale', str(scale)]
    return args


def apply(settings):
    outputs = json.loads(subprocess.check_output(['wlr-randr', '--json'], text=True))
    args = plan(outputs, settings)
    if args:
        subprocess.run(['wlr-randr', *args], check=True)
        # Mode/scale changes can make labwc auto-place outputs during the first
        # transaction. Reapply positions after those changes have settled.
        if '--mode' in args:
            positions = []
            for index, arg in enumerate(args):
                if arg == '--output':
                    positions += ['--output', args[index + 1], '--pos', '0,0']
            subprocess.run(['wlr-randr', *positions], check=True)


def main():
    with open(sys.argv[1]) as source:
        settings = json.load(source)
    # Subscribe before reading topology so dock events cannot be lost at startup.
    with subprocess.Popen(['udevadm', 'monitor', '--udev', '--property', '--subsystem-match=drm'],
                          stdout=subprocess.PIPE, text=True, bufsize=1) as monitor:
        def update():
            for attempt in range(3):
                try:
                    apply(settings)
                    return
                except (subprocess.SubprocessError, ValueError) as error:
                    print(error, file=sys.stderr, flush=True)
                    if attempt < 2:
                        time.sleep(1)
        update()
        event = {}
        for line in monitor.stdout:
            line = line.strip()
            if not line:
                if event.get('ACTION') == 'change' and event.get('HOTPLUG') == '1':
                    time.sleep(1)
                    update()
                event = {}
            elif '=' in line:
                key, value = line.split('=', 1)
                event[key] = value
        raise RuntimeError('DRM monitor exited')


if __name__ == '__main__':
    main()
