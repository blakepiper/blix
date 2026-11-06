"""Exercise dock naming, mirror rates, scaling and undocked defaults."""
import importlib.util
import sys
sys.dont_write_bytecode = True

spec = importlib.util.spec_from_file_location('outputs', sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

def output(name, rates, size=(1920, 1080)):
    return {'name': name, 'modes': [dict(width=size[0], height=size[1], refresh=r) for r in rates]}

settings = dict(primary='eDP-1', external=['HDMI-2', 'DP-*'], layout='mirror',
                mode='1920x1080', rate=None, scales={'eDP-1': 1.25})
panel = output('eDP-1', [60.008])
external = output('DP-7', [60, 120])
args = module.plan([external, panel], settings)
assert args == ['--output', 'eDP-1', '--on', '--mode', '1920x1080@60.008000Hz',
                '--pos', '0,0', '--scale', '1.25', '--output', 'DP-7', '--on',
                '--mode', '1920x1080@120.000000Hz', '--pos', '0,0', '--scale', '1.25']
assert module.plan([panel], settings) == ['--output', 'eDP-1', '--on', '--preferred',
                                         '--pos', '0,0', '--scale', '1.25']
assert module.plan([external], settings) == []
# Do not apply laptop defaults to unrelated connectors.
assert '--mode' not in module.plan([panel, output('HDMI-9', [60])], settings)
settings['scales']['eDP-1'] = 1.75
assert module.plan([panel, external], settings).count('1.75') == 2
settings['mode'] = '3840x2160'
assert '1920x1080@120.000000Hz' in module.plan([panel, external], settings)
try:
    module.plan([panel, output('DP-2', [60], (1280, 720))], settings)
except ValueError:
    pass
else:
    raise AssertionError('Must reject incompatible mirrors before applying anything')
# Apply mode/scale first, then positions: labwc auto-places resized outputs.
from unittest.mock import patch
import json
with patch.object(module.subprocess, 'check_output', return_value=json.dumps([panel, external])), \
     patch.object(module.subprocess, 'run') as run:
    module.apply(settings)
    assert run.call_count == 2
    assert run.call_args_list[1].args[0] == ['wlr-randr', '--output', 'eDP-1', '--pos', '0,0',
                                            '--output', 'DP-7', '--pos', '0,0']
