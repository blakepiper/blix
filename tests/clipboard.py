"""Exercise the packaged history daemon against an isolated X11 clipboard."""
import os
import random
import struct
import subprocess
import sys
import time
import zlib
from pathlib import Path


def chunk(kind, data):
    return (struct.pack('!I', len(data)) + kind + data
            + struct.pack('!I', zlib.crc32(kind + data)))


# Incompressible PNG large enough to require X11 INCR transfers. No user data.
pixels = random.Random(0).randbytes(768 * 512 * 3)
rows = b''.join(b'\0' + pixels[i:i + 768 * 3]
                for i in range(0, len(pixels), 768 * 3))
png = (b'\x89PNG\r\n\x1a\n'
       + chunk(b'IHDR', struct.pack('!2I5B', 768, 512, 8, 2, 0, 0, 0))
       + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b''))
Path('test.png').write_bytes(png)
os.environ.update(DISPLAY=':193', CM_ONESHOT='1', CM_SELECTIONS='clipboard',
                  CM_OWN_CLIPBOARD='0', CM_DIR=os.getcwd(), USER='test')
server = subprocess.Popen(['Xvfb', ':193', '-screen', '0', '640x480x24',
                           '-nolisten', 'tcp', '-noreset'])
try:
    for _ in range(100):
        if Path('/tmp/.X11-unix/X193').exists():
            break
        if server.poll() is not None:
            raise RuntimeError('Xvfb failed')
        time.sleep(.05)

    def roundtrip(target, filename, expected):
        owner = subprocess.Popen(['xclip', '-quiet', '-selection', 'clipboard',
                                  '-target', target, '-in', filename],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            for _ in range(100):
                ready = subprocess.run(['xclip', '-selection', 'clipboard',
                                        '-out', '-target', 'TARGETS'],
                                       capture_output=True, timeout=2)
                if target.encode() in ready.stdout.splitlines():
                    break
                time.sleep(.02)
            else:
                raise AssertionError('Clipboard owner did not become ready')
            subprocess.run([sys.argv[1]], check=True, timeout=5)
            for _ in range(3):
                result = subprocess.run(['xclip', '-selection', 'clipboard',
                                         '-out', '-target', target],
                                        capture_output=True, check=True, timeout=3)
                assert result.stdout == expected, 'Clipboard contents changed'
        finally:
            owner.terminate()
            owner.wait(timeout=3)

    roundtrip('image/png', 'test.png', png)
    cache = Path('clipmenu.6.test/line_cache')
    assert not cache.exists(), 'Image was captured as text history'
    text = b'clipboard regression test'
    Path('text.txt').write_bytes(text)
    roundtrip('UTF8_STRING', 'text.txt', text)
    assert text in cache.read_bytes(), 'Text history was not recorded'
    roundtrip('image/png', 'test.png', png)
    assert len(cache.read_text().splitlines()) == 1
    print('Large PNG survives history probes and repeated pastes; text history works')
finally:
    server.terminate()
    server.wait(timeout=3)
