"""Portable telemetry fixtures: no host devices, privileges or persistent writes."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('system_info', sys.argv.pop(1))
info = importlib.util.module_from_spec(spec)
spec.loader.exec_module(info)


class TelemetryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.proc, self.sysfs = self.base / 'proc', self.base / 'sys'
        self.now = 10.0
        self.monitor = info.Monitor(self.proc, self.sysfs, clock=lambda: self.now)
        self.put(self.proc / 'stat', 'cpu 100 0 100 800 0 0 0 0 0 0\n')
        self.put(self.proc / 'meminfo', 'MemTotal: 8388608 kB\nMemAvailable: 6291456 kB\nSwapTotal: 2097152 kB\nSwapFree: 1048576 kB\n')
        self.put(self.proc / 'loadavg', '0.25 0.50 0.75 1/42 99')
        self.put(self.proc / 'uptime', '90060.0 0')

    def put(self, path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def rows(self):
        return {r['label']: r['value'] for r in self.monitor.sample()['rows']}

    def test_cpu_interval_memory_swap_and_uptime(self):
        first = self.rows()
        self.assertEqual(first['CPU'], 'Sampling…')
        self.assertEqual(first['RAM'], '2.0 / 8.0 GiB')
        self.assertEqual(first['Swap'], '1.0 / 2.0 GiB')
        self.assertEqual(first['Uptime'], '1d 1h 1m')
        self.put(self.proc / 'stat', 'cpu 120 0 110 870 0 0 0 0\n')
        self.now += 2
        self.assertEqual(self.rows()['CPU'], '30%')

    def test_missing_hardware_and_malformed_values_are_not_zero_usage(self):
        self.put(self.proc / 'stat', '')
        self.put(self.proc / 'meminfo', 'MemTotal: invalid')
        rows = self.rows()
        self.assertEqual(rows['RAM'], 'Unavailable')
        self.assertEqual(rows['GPU apps'], 'Unavailable')
        self.assertEqual(rows['Temperature'], 'Unavailable')
        json.dumps(self.monitor.sample(), allow_nan=False)

    def test_amd_busy_and_labeled_temperature(self):
        self.put(self.sysfs / 'class/drm/card1/device/gpu_busy_percent', '42')
        hwmon = self.sysfs / 'class/hwmon/hwmon0'
        self.put(hwmon / 'name', 'k10temp')
        self.put(hwmon / 'temp1_label', 'Tctl')
        self.put(hwmon / 'temp1_input', '61500')
        self.put(hwmon / 'temp2_input', '-999999')
        rows = self.rows()
        self.assertEqual(rows['GPU 1'], '42%')
        self.assertEqual(rows['k10temp Tctl'], '62°C')
        self.assertNotIn('k10temp temp2', rows)

    def test_xe_gt_idle_and_arm_thermal_fallback(self):
        idle = self.sysfs / 'class/drm/card0/device/tile0/gt0/gtidle/idle_residency_ms'
        self.put(idle, '1000')
        self.put(self.sysfs / 'class/thermal/thermal_zone0/type', 'cpu-thermal')
        self.put(self.sysfs / 'class/thermal/thermal_zone0/temp', '43000')
        self.rows()
        self.put(idle, '2500')
        self.now += 2
        rows = self.rows()
        self.assertEqual(rows['Intel GPU 0'], '25%')
        self.assertEqual(rows['cpu-thermal'], '43°C')

    def test_drm_fdinfo_deduplicates_clients_and_normalizes_capacity(self):
        client = self.proc / '123'
        (client / 'fd').mkdir(parents=True)
        for fd in ['4', '5']:
            (client / 'fd' / fd).symlink_to('/dev/dri/renderD128')
        def update(ns):
            for fd in ['4', '5']:
                self.put(client / 'fdinfo' / fd, f'drm-driver: i915\ndrm-pdev: 0000:00:02.0\ndrm-client-id: 7\ndrm-engine-render: {ns} ns\ndrm-engine-capacity-render: 2\n')
        update(1000000000)
        self.rows()
        update(2000000000)
        self.now += 2
        self.assertEqual(self.rows()['GPU apps'], '25%')
        update(1900000000)
        self.now += 2
        self.assertEqual(self.rows()['GPU apps'], '0%')

    def test_nvidia_uses_explicit_tool_with_timeout_and_survives_failure(self):
        self.monitor.nvidia = '/test/nvidia-smi'
        result = subprocess.CompletedProcess([], 0, stdout='73, 62\n')
        with patch.object(info.subprocess, 'run', return_value=result) as run:
            self.assertEqual(self.rows()['NVIDIA 0'], '73% · 62°C')
            self.assertEqual(run.call_args.args[0][0], '/test/nvidia-smi')
            self.assertEqual(run.call_args.kwargs['timeout'], 1)
        with patch.object(info.subprocess, 'run', side_effect=subprocess.TimeoutExpired([], 1)):
            self.assertEqual(self.rows()['GPU apps'], 'Unavailable')


unittest.main()
