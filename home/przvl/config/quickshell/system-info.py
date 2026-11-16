"""Read-only, unprivileged Linux telemetry; stream only while its menu is open."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time


def read(path):
    try:
        return path.read_text().strip()
    except (OSError, UnicodeError):
        return ""


def number(path):
    try:
        return int(read(path))
    except ValueError:
        return None


def percent(value):
    return max(0, min(100, round(value)))


class Monitor:
    def __init__(self, proc=Path('/proc'), sysfs=Path('/sys'), nvidia='', clock=time.monotonic):
        self.proc, self.sysfs, self.nvidia, self.clock = proc, sysfs, nvidia, clock
        self.previous = {}

    def delta(self, key, value):
        now = self.clock()
        previous = self.previous.get(key)
        self.previous[key] = (now, value)
        if previous is None or now <= previous[0]:
            return None
        return now - previous[0], value - previous[1]

    def cpu(self):
        try:
            values = list(map(int, read(self.proc / 'stat').splitlines()[0].split()[1:9]))
            total, idle = sum(values), values[3] + values[4]
            a, b = self.delta('cpu-total', total), self.delta('cpu-idle', idle)
            if a and b and a[1] > 0 and b[1] >= 0:
                return percent(100 * (a[1] - b[1]) / a[1])
        except (ValueError, IndexError):
            pass
        return None

    def drm_clients(self):
        """DRM fdinfo nanoseconds, deduplicated by device/client ID (user apps only)."""
        clients = {}
        for process in self.proc.glob('[0-9]*'):
            try:
                if process.stat().st_uid != os.getuid():
                    continue
                for fd in (process / 'fd').iterdir():
                    try:
                        if not os.readlink(fd).startswith('/dev/dri/'):
                            continue
                    except OSError:
                        continue
                    fields = dict(line.split(':', 1) for line in read(process / 'fdinfo' / fd.name).splitlines() if ':' in line)
                    fields = {k: v.strip() for k, v in fields.items()}
                    client = fields.get('drm-client-id')
                    device = fields.get('drm-pdev', fields.get('drm-driver', ''))
                    if client:
                        clients[(device, client)] = fields
            except OSError:
                continue
        engines = {}
        for (device, client), fields in clients.items():
            for key, raw in fields.items():
                if not key.startswith('drm-engine-') or not raw.endswith(' ns'):
                    continue
                try:
                    current = int(raw.split()[0])
                    state_key = ('engine', device, client, key)
                    # Kernel counters may temporarily regress: retain the high-water mark.
                    previous = self.previous.get(state_key)
                    if previous:
                        current = max(current, previous[1])
                    delta = self.delta(state_key, current)
                    capacity = max(1, int(fields.get(key.replace('drm-engine-', 'drm-engine-capacity-'), '1')))
                    if delta:
                        engine = (device, key)
                        engines[engine] = engines.get(engine, 0) + delta[1] / (delta[0] * 1e9 * capacity)
                except ValueError:
                    continue
        # Bound history when apps exit.
        active = {(d, c) for d, c in clients}
        for key in list(self.previous):
            if isinstance(key, tuple) and key[0] == 'engine' and (key[1], key[2]) not in active:
                del self.previous[key]
        return percent(max(engines.values()) * 100) if engines else None

    def gpu_rows(self):
        rows = []
        if self.nvidia:
            try:
                result = subprocess.run([self.nvidia, '--query-gpu=utilization.gpu,temperature.gpu',
                    '--format=csv,noheader,nounits'], capture_output=True, text=True, timeout=1, check=True)
                for i, line in enumerate(result.stdout.splitlines()):
                    usage, temperature = [int(x.strip()) for x in line.split(',')]
                    rows.append({'label': f'NVIDIA {i}', 'value': f'{percent(usage)}% · {temperature}°C'})
            except (OSError, ValueError, subprocess.SubprocessError):
                pass
        for card in sorted((self.sysfs / 'class/drm').glob('card[0-9]*')):
            if not re.fullmatch(r'card\d+', card.name):
                continue
            busy = number(card / 'device/gpu_busy_percent')
            if busy is not None:
                rows.append({'label': f'GPU {card.name[4:]}', 'value': f'{percent(busy)}%'})
                continue
            # Intel Xe exports per-GT idle residency, in milliseconds.
            activity = []
            for idle in (card / 'device').glob('tile*/gt*/gtidle/idle_residency_ms'):
                value = number(idle)
                delta = self.delta(str(idle), value) if value is not None else None
                if delta and delta[1] >= 0:
                    activity.append(percent(100 * (1 - delta[1] / (delta[0] * 1000))))
            if activity:
                rows.append({'label': f'Intel GPU {card.name[4:]}', 'value': f'{max(activity)}%'})
        if not rows:
            usage = self.drm_clients()
            rows.append({'label': 'GPU apps', 'value': 'Unavailable' if usage is None else f'{usage}%'})
        return rows

    def sample(self):
        usage = self.cpu()
        rows = [{'label': 'CPU', 'value': 'Sampling…' if usage is None else f'{usage}%'}]
        memory = {}
        for line in read(self.proc / 'meminfo').splitlines():
            try:
                key, value = line.split(':', 1)
                memory[key] = int(value.split()[0])
            except (ValueError, IndexError):
                continue
        total, available = memory.get('MemTotal', 0), memory.get('MemAvailable')
        rows.append({'label': 'RAM', 'value': 'Unavailable' if not total or available is None
            else f'{(total-available)/1048576:.1f} / {total/1048576:.1f} GiB'})
        swap = memory.get('SwapTotal', 0)
        rows.append({'label': 'Swap', 'value': f'{(swap-memory.get("SwapFree", 0))/1048576:.1f} / {swap/1048576:.1f} GiB' if swap else 'None'})
        rows.extend(self.gpu_rows())
        load = read(self.proc / 'loadavg').split()
        if len(load) >= 3:
            rows.append({'label': 'Load 1/5/15m', 'value': ' / '.join(load[:3])})
        try:
            seconds = int(float(read(self.proc / 'uptime').split()[0]))
            rows.append({'label': 'Uptime', 'value': f'{seconds//86400}d {seconds//3600%24}h {seconds//60%60}m'})
        except (ValueError, IndexError):
            pass
        try:
            disk = shutil.disk_usage('/')
            rows.append({'label': 'Disk /', 'value': f'{disk.used/2**30:.0f} / {disk.total/2**30:.0f} GiB'})
        except OSError:
            pass
        sensors = []
        for hwmon in sorted((self.sysfs / 'class/hwmon').glob('hwmon*')):
            name = read(hwmon / 'name')
            for path in sorted(hwmon.glob('temp*_input')):
                value = number(path)
                if value is not None and -20000 <= value <= 150000:
                    label = read(hwmon / path.name.replace('_input', '_label')) or path.name.replace('_input', '')
                    sensors.append({'label': f'{name} {label}', 'value': f'{value/1000:.0f}°C'})
        if not sensors:
            for zone in sorted((self.sysfs / 'class/thermal').glob('thermal_zone*')):
                value = number(zone / 'temp')
                if value is not None and -20000 <= value <= 150000:
                    sensors.append({'label': read(zone / 'type') or zone.name, 'value': f'{value/1000:.0f}°C'})
        # Keep package/CPU temperatures ahead of peripheral sensors in the menu.
        sensors.sort(key=lambda row: (not any(word in row['label'].lower()
            for word in ('package', 'tctl', 'cpu')), row['label']))
        rows.extend(sensors or [{'label': 'Temperature', 'value': 'Unavailable'}])
        return {'rows': rows}


def main():
    monitor = Monitor(nvidia=sys.argv[1] if len(sys.argv) > 1 else '')
    monitor.sample()
    time.sleep(0.25)
    try:
        while True:
            print(json.dumps(monitor.sample()), flush=True)
            time.sleep(2)
    except BrokenPipeError:
        pass


if __name__ == '__main__':
    main()
