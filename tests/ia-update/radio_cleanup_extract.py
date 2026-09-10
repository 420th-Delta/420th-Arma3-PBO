"""Stage exact housekeeping source slices for native SQF preprocessing."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def extract(source_root: Path, output: Path) -> dict:
    relative = Path('code/functions/fn_core.sqf')
    source_bytes = (source_root / relative).read_bytes()
    source = source_bytes.decode('utf-8-sig')
    output.mkdir(parents=True, exist_ok=True)
    manifest = {'source': relative.as_posix(), 'source_sha256': hashlib.sha256(source_bytes).hexdigest(), 'blocks': []}
    for name, marker in [('helpers', 'HOUSEKEEPING_HELPERS'), ('tick', 'HOUSEKEEPING_TICK')]:
        opening, closing = f'// {marker}_BEGIN', f'// {marker}_END'
        if source.count(opening) != 1 or source.count(closing) != 1:
            raise ValueError(f'Expected unique {marker} marker pair')
        begin, end = source.index(opening), source.index(closing)
        if end <= begin:
            raise ValueError(f'Reversed {marker} markers')
        body = source[begin:end].encode('utf-8')
        filename = f'{name}.sqf'
        (output / filename).write_bytes(body)
        manifest['blocks'].append({'file': filename, 'start_character': begin, 'end_character': end,
                                   'source_line': source.count('\n', 0, begin) + 1,
                                   'sha256': hashlib.sha256(body).hexdigest()})
    (output / 'extraction-manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--source-root', type=Path, required=True, help='Frozen production mission directory')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    manifest = extract(args.source_root, args.output)
    print(json.dumps({'output': str(args.output), 'blocks': len(manifest['blocks'])}))


if __name__ == '__main__':
    main()
