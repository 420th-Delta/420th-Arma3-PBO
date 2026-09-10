"""Extract exact production SQF blocks for the engine fixture and callsite audit."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


def mask(source: str) -> str:
    """Preserve offsets, blank comments and strings (including doubled quotes)."""
    result = list(source)
    i = 0
    while i < len(source):
        if source.startswith('//', i):
            end = source.find('\n', i)
            end = len(source) if end < 0 else end
        elif source.startswith('/*', i):
            end = source.find('*/', i + 2)
            if end < 0:
                raise ValueError('Unterminated block comment')
            end += 2
        elif source[i] in "\"'":
            quote = source[i]
            end = i + 1
            while end < len(source):
                if source[end] == quote:
                    if end + 1 < len(source) and source[end + 1] == quote:
                        end += 2
                        continue
                    end += 1
                    break
                end += 1
        else:
            i += 1
            continue
        result[i:end] = ['\n' if c == '\n' else ' ' for c in source[i:end]]
        i = end
    return ''.join(result)


def balanced(source: str, start: int, opening: str = '{', closing: str = '}') -> tuple[int, int]:
    clean = mask(source)
    begin = clean.index(opening, start)
    depth = 1
    for end in range(begin + 1, len(source)):
        if clean[end] == opening:
            depth += 1
        elif clean[end] == closing:
            depth -= 1
            if depth == 0:
                return begin, end + 1
    raise ValueError('Unbalanced SQF')


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--source-root', type=Path, help='Frozen production directory from native harness')
    parser.add_argument('--revision', help='Read immutable baseline with git show; otherwise working files')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    manifest = {'revision': args.revision or 'working-tree', 'blocks': []}

    def read(name: str) -> tuple[str, str]:
        rel = f'Apex_framework.terrain/code/functions/fn_{name}.sqf'
        if args.revision:
            source = subprocess.check_output(['git', '-c', f'safe.directory={args.repo.resolve().as_posix()}',
                                              '-C', str(args.repo), 'show', f'{args.revision}:{rel}']).decode('utf-8-sig')
        else:
            path = (args.source_root / 'code/functions' / f'fn_{name}.sqf') if args.source_root else (args.repo / rel)
            source = path.read_text(encoding='utf-8-sig')
        return rel, source

    rel, source = read('AI')
    for name, key in [('ai-register', 'private _fn_register ='), ('ai-track', 'private _fn_track ='),
                      ('ai-rotary', "if (_delivery isEqualTo 'ROTARY') exitWith"),
                      ('ai-native-cleanup', 'if (_QS_module_classic_enemy_0 isNotEqualTo []) then'),
                      ('ai-cas-provider-prune', "if ((missionNamespace getVariable 'QS_AI_supportProviders_CASHELI') isNotEqualTo []) then"),
                      ('ai-intel-provider-prune', "if ((missionNamespace getVariable 'QS_AI_supportProviders_INTEL') isNotEqualTo []) then")]:
        begin, end = balanced(source, source.index(key))
        body = source[begin + 1:end - 1]
        (args.output / f'{name}.sqf').write_text(body, encoding='utf-8')
        manifest['blocks'].append({'file': f'{name}.sqf', 'source': rel, 'source_sha256': hashlib.sha256(source.encode()).hexdigest(),
                                   'start': begin + 1, 'end': end - 1, 'sha256': hashlib.sha256(body.encode()).hexdigest()})
    begin = source.index("missionNamespace setVariable ['QS_fnc_aoPressure',{")
    _, end = balanced(source, begin)
    end = source.index(';', end) + 1
    body = source[begin:end]
    (args.output / 'ai-pressure.sqf').write_text(body, encoding='utf-8')
    manifest['blocks'].append({'file': 'ai-pressure.sqf', 'source': rel, 'source_sha256': hashlib.sha256(source.encode()).hexdigest(),
                               'start': begin, 'end': end, 'sha256': hashlib.sha256(body.encode()).hexdigest()})

    rel, source = read('aoForestCamp')
    begin = source.index('[', source.index('private _patrolGroup ='))
    end = source.index(';', begin)
    body = source[begin:end]
    (args.output / 'ai-forest-guard-call.sqf').write_text(body, encoding='utf-8')
    manifest['blocks'].append({'file': 'ai-forest-guard-call.sqf', 'source': rel, 'source_sha256': hashlib.sha256(source.encode()).hexdigest(),
                               'start': begin, 'end': end, 'sha256': hashlib.sha256(body.encode()).hexdigest()})

    for name in ['spawnGroup', 'scSpawnHeli']:
        rel, source = read(name)
        (args.output / f'{name}.sqf').write_text(source, encoding='utf-8')
        manifest['blocks'].append({'file': f'{name}.sqf', 'source': rel, 'source_sha256': hashlib.sha256(source.encode()).hexdigest(),
                                   'start': 0, 'end': len(source), 'sha256': hashlib.sha256(source.encode()).hexdigest()})

    sites = []
    base = (args.source_root or (args.repo / 'Apex_framework.terrain')) / 'code/functions'
    for path in sorted(base.glob('*.sqf')):
        text = path.read_text(encoding='utf-8-sig')
        if 'QS_fnc_spawnGroup' not in text and '_fn_spawnGroup' not in text:
            continue
        if args.revision:
            _, text = read(path.stem.removeprefix('fn_'))
        clean = mask(text)
        for match in re.finditer(r'\bcall\b', clean):
            after = text[match.end():text.find(';', match.end()) + 1]
            if not re.match(r"\s+(?:QS_fnc_spawnGroup\b|_fn_spawnGroup\b|\(missionNamespace getVariable 'QS_fnc_spawnGroup'\))", after):
                continue
            close = match.start() - 1
            while close >= 0 and clean[close].isspace():
                close -= 1
            if close < 0 or clean[close] != ']':
                continue
            depth = 1
            begin = close - 1
            while begin >= 0:
                if clean[begin] == ']':
                    depth += 1
                elif clean[begin] == '[':
                    depth -= 1
                    if depth == 0:
                        break
                begin -= 1
            expression = text[begin:close + 1]
            parts = mask(expression)
            levels = 0
            arguments = 1
            for char in parts[1:-1]:
                if char in '[{(':
                    levels += 1
                elif char in ']})':
                    levels -= 1
                elif char == ',' and levels == 0:
                    arguments += 1
            mode = 'expanded-slots' if re.match(r"\[\s*'(?:SLOTS|VEHICLE_SLOTS)'", expression) else ('expanded-group' if arguments > 8 else 'legacy-compact')
            sites.append({'file': path.name, 'line': text.count('\n', 0, begin) + 1, 'kind': mode, 'arguments': arguments, 'call': expression})
    (args.output / 'callsite-audit.json').write_text(json.dumps(sites, indent=2), encoding='utf-8')
    (args.output / 'extraction-manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print(json.dumps({'output': str(args.output), 'blocks': len(manifest['blocks']), 'calls': len(sites),
                      'classification': {key: sum(site['kind'] == key for site in sites) for key in ['expanded-slots', 'expanded-group', 'legacy-compact']}}))


if __name__ == '__main__':
    main()
