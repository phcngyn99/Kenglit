from pathlib import Path
import struct
import sys
import zlib


def chunk(kind, payload):
    checksum = zlib.crc32(kind + payload) & 0xffffffff
    return struct.pack('>I', len(payload)) + kind + payload + struct.pack('>I', checksum)


def normalize(path, dpi):
    source = path.read_bytes()
    signature = b'\x89PNG\r\n\x1a\n'
    if not source.startswith(signature):
        print(f'skip (not PNG): {path.name}', file=sys.stderr)
        return
    parts = []
    offset = 8
    width = height = None
    while offset < len(source):
        length = struct.unpack('>I', source[offset:offset + 4])[0]
        kind = source[offset + 4:offset + 8]
        payload = source[offset + 8:offset + 8 + length]
        raw = source[offset:offset + 12 + length]
        if len(raw) != length + 12:
            raise ValueError(f'Truncated PNG: {path}')
        if struct.unpack('>I', raw[-4:])[0] != zlib.crc32(kind + payload) & 0xffffffff:
            raise ValueError(f'Invalid PNG checksum: {path}')
        if kind == b'IHDR':
            width, height = struct.unpack('>II', payload[:8])
        if kind == b'eXIf':
            raise ValueError(f'Unexpected EXIF metadata: normalize with an image metadata tool: {path}')
        parts.append((kind, payload, raw))
        offset += length + 12
    expected = (1520, 1200) if dpi == 144 else (760, 600)
    if (width, height) != expected:
        raise ValueError(f'Unexpected dimensions in {path}: {(width, height)}, expected {expected}')
    pixels_per_meter = round(dpi / 0.0254)
    physical = chunk(b'pHYs', struct.pack('>IIB', pixels_per_meter, pixels_per_meter, 1))
    output = bytearray(signature)
    added = False
    for kind, payload, raw in parts:
        if kind == b'pHYs':
            continue
        if kind == b'IDAT' and not added:
            output.extend(physical)
            added = True
        output.extend(raw)
    if not added:
        raise ValueError(f'PNG has no image data: {path}')
    path.write_bytes(output)
    print(f'{path.name}: {width} x {height} px, {dpi} DPI, approximately 760 x 600 pt')


root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent
pairs = [
    ('background-manual.png', 72),
    ('background-manual@2x.png', 144),
    ('background-release.png', 72),
    ('background-release@2x.png', 144),
    ('background.png', 72),
    ('background@2x.png', 144),
    ('dmg-background-manual.png', 72),
    ('dmg-background-manual@2x.png', 144),
    ('dmg-background-release.png', 72),
    ('dmg-background-release@2x.png', 144),
]
for name, dpi in pairs:
    path = root / name
    if not path.exists():
        continue
    try:
        normalize(path, dpi)
    except ValueError as exc:
        print(f'skip {path.name}: {exc}', file=sys.stderr)
