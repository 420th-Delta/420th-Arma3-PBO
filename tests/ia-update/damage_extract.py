"""Stage exact production profiles, ammunition resolution and release statements."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from ai_spawn_extract import balanced


def extract(source_root: Path, output: Path) -> dict:
    relative = Path('code/functions/fn_artillerySupport.sqf')
    source_bytes = (source_root / relative).read_bytes()
    source = source_bytes.decode('utf-8-sig')
    output.mkdir(parents=True, exist_ok=True)
    manifest = {'source': relative.as_posix(), 'source_sha256': hashlib.sha256(source_bytes).hexdigest(), 'blocks': []}

    def unique(anchor: str) -> int:
        if source.count(anchor) != 1:
            raise ValueError(f'Expected unique production anchor: {anchor}')
        return source.index(anchor)

    def write(name: str, begin: int, end: int) -> None:
        body = source[begin:end].encode('utf-8')
        (output / name).write_bytes(body)
        manifest['blocks'].append({'file': name, 'start_character': begin, 'end_character': end,
                                   'source_line': source.count('\n', 0, begin) + 1,
                                   'sha256': hashlib.sha256(body).hexdigest()})

    begin, end = balanced(source, unique('private _profiles = ['), '[', ']')
    write('profiles.sqf', begin, end)
    begin, end = balanced(source, unique('private _fn_resolveAmmo = {'))
    write('resolve-ammo.sqf', begin + 1, end - 1)
    begin = unique('private _projectile = createVehicle [')
    guard = unique('if (!isNull _projectile) then {')
    if guard <= begin:
        raise ValueError('Production release guard moved before projectile creation')
    _, end = balanced(source, guard)
    end = source.index(';', end) + 1
    write('release.sqf', begin, end)
    (output / 'extraction-manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--source-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    manifest = extract(args.source_root, args.output)
    print(json.dumps({'output': str(args.output), 'blocks': len(manifest['blocks'])}))


if __name__ == '__main__':
    main()
