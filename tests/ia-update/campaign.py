"""Export an allowlisted campaign index; private native evidence stays in the lab."""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re


CELL_NAME = re.compile(r'^[a-f0-9]{12}-(damage|guided|support|radio-cleanup|ai-spawn|hq-delete|integration|config)$')
LABEL = re.compile(r'^[A-Za-z][A-Za-z0-9_.:-]{0,159}$')
HEADLESS_LOOP = re.compile(r'for\(\$hcIndex=1;\$hcIndex -le ([0-2]);\$hcIndex\+\+\)')


def integer(value: object) -> int | None:
    return value if type(value) is int and value >= 0 else None


def boolean(value: object) -> bool | None:
    return value if type(value) is bool else None


def count(value: object) -> int | None:
    return len(value) if isinstance(value, list) else None


def digest(path: Path) -> str | None:
    if not path.is_file():
        return None
    with path.open('rb') as handle:
        return hashlib.file_digest(handle, 'sha256').hexdigest()


def read_object(path: Path, invalid: list[str]) -> dict | None:
    if not path.is_file():
        return None
    try:
        value = json.loads(path.read_text(encoding='utf-8-sig'))
    except (UnicodeError, json.JSONDecodeError):
        invalid.append(path.name)
        return None
    if not isinstance(value, dict):
        invalid.append(path.name)
        return None
    return value


def failure_labels(failures: object) -> tuple[list[str], int]:
    labels, redacted = [], 0
    if not isinstance(failures, list):
        return labels, redacted
    for failure in failures:
        label = None
        if isinstance(failure, list) and len(failure) > 4:
            payload = failure[4]
            if isinstance(payload, list) and payload:
                label = payload[0]
        # Never carry arbitrary assertion payloads, names, paths or UID digits.
        if not isinstance(label, str) or not LABEL.fullmatch(label) or re.search(r'\d{17}', label):
            label = 'redacted_assertion_label'
            redacted += 1
        labels.append(label)
    return sorted(set(labels)), redacted


def started_utc(report: dict) -> str | None:
    value = report.get('started_utc')
    if not isinstance(value, str):
        return None
    try:
        parsed = datetime.fromisoformat(value.replace('Z', '+00:00'))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return None
    return parsed.astimezone(timezone.utc).isoformat()


def requested_headless(cell: Path, suite: str, spec: dict) -> tuple[int | None, str]:
    explicit = integer(spec.get('headless'))
    if explicit is not None:
        return explicit, 'spec'
    if suite != 'integration':
        return 0, 'suite_has_no_headless_clients'
    launcher = cell / 'Run-Cell.ps1'
    if launcher.is_file():
        values = HEADLESS_LOOP.findall(launcher.read_text(encoding='utf-8-sig'))
        if len(values) == 1:
            return int(values[0]), 'frozen_launcher_literal'
    return None, 'unknown'


def cycle_mode(cell: Path, suite: str, result: dict, spec: dict) -> bool | None:
    for source in (result, spec):
        explicit = boolean(source.get('cycle'))
        if explicit is not None:
            return explicit
    if suite != 'integration':
        return False
    init = cell / 'fixture/mission/init.sqf'
    if init.is_file():
        return 'integration-cycle.sqf' in init.read_text(encoding='utf-8-sig')
    return None


def summarize_cell(cell: Path, suite: str) -> dict:
    invalid: list[str] = []
    recorded_result = read_object(cell / 'result.json', invalid)
    result = recorded_result or {}
    spec = read_object(cell / 'spec.json', invalid) or {}
    report = read_object(cell / 'report.json', invalid) or {}
    source_manifest = read_object(cell / 'source-manifest.json', invalid)
    fixture_manifest = read_object(cell / 'fixture-manifest.json', invalid)
    labels, redacted = failure_labels(result.get('failures'))
    processes = report.get('processes')
    roles = {p.get('role') for p in processes if isinstance(p, dict) and isinstance(p.get('role'), str)} if isinstance(processes, list) else set()
    if recorded_result is not None:
        status = 'recorded_result'
    elif (cell / 'result.json').is_file():
        status = 'invalid_result'
    elif roles or report.get('rpts'):
        status = 'native_execution_without_result'
    elif report:
        status = 'launch_or_setup_without_result'
    elif (cell / 'owned-processes.jsonl').is_file():
        status = 'execution_started_without_result'
    else:
        status = 'staging_without_result'
    headless, headless_source = requested_headless(cell, suite, spec)
    return {
        'cell_id': cell.name,
        'suite': suite,
        'kind': 'configuration_only' if suite == 'config' else 'native',
        'status': status,
        'cycle': cycle_mode(cell, suite, result, spec),
        'mfd_control_mode': spec.get('mfd_control_mode') if spec.get('mfd_control_mode') in ('off', 'reviewed-scout-v1') else None,
        'started_utc': started_utc(report),
        'players_requested': integer(spec.get('players')),
        'headless_requested': headless,
        'headless_count_source': headless_source,
        'graphical_clients_started': sum(bool(re.fullmatch(r'client\d+', role)) for role in roles) if isinstance(processes, list) else None,
        'headless_clients_started': sum(bool(re.fullmatch(r'HC\d+', role)) for role in roles) if isinstance(processes, list) else None,
        'checks': integer(result.get('checks')),
        'failed_checks': count(result.get('failures')),
        'failure_labels': labels,
        'redacted_failure_labels': redacted,
        'script_errors': integer(result.get('script_errors')),
        'cleanup_errors': count(result.get('cleanup_errors')),
        'runner_error_present': bool(result.get('error')) if recorded_result is not None else None,
        'hash_integrity': {
            'source_changes': count(result.get('frozen_source_changed')),
            'fixture_changes': count(result.get('fixture_changed')),
            'runtime_changes': count(result.get('runtime_changed')),
        },
        'completed': boolean(result.get('completed')) if recorded_result is not None else boolean(report.get('completed')),
        'passed': boolean(result.get('passed')) if recorded_result is not None else None,
        'malformed_records': count(result.get('malformed_records')),
        'provenance': {
            'source_manifest_sha256': digest(cell / 'source-manifest.json'),
            'fixture_manifest_sha256': digest(cell / 'fixture-manifest.json'),
            'result_sha256': digest(cell / 'result.json'),
            'source_manifest_entries': len(source_manifest) if source_manifest is not None else None,
            'fixture_manifest_entries': len(fixture_manifest) if fixture_manifest is not None else None,
        },
        'invalid_metadata_files': sorted(set(invalid)),
    }


def export_campaign(artifact_root: Path, output: Path) -> dict:
    cells = []
    for cell in artifact_root.iterdir():
        match = CELL_NAME.fullmatch(cell.name)
        if cell.is_dir() and match:
            cells.append(summarize_cell(cell, match[1]))
    cells.sort(key=lambda row: (row['started_utc'] is None, row['started_utc'] or '', row['cell_id']))
    counts = Counter(row['status'] for row in cells)
    document = {
        'schema_version': 1,
        'scope': 'All native campaign attempts found under the supplied lab artifact root; historical failures are retained.',
        'interpretation': [
            'passed is the recorded cell result, not final campaign or live-server acceptance.',
            'null means unavailable or not recorded; missing results are never classified as passing.',
            'Older cells may lack newer integrity or malformed-record checks; absent values remain null.',
            'Failure labels exclude assertion payloads and private error strings.',
            'Historical headless intent is recovered from a unique literal in the frozen launcher when absent from spec.',
            'Configuration-only attempts are marked separately and do not count as passing native cells.',
        ],
        'summary': {
            'attempts': len(cells),
            'recorded_results': counts['recorded_result'],
            'passed_cells': sum(row['passed'] is True for row in cells),
            'passed_native_cells': sum(row['passed'] is True and row['kind'] == 'native' for row in cells),
            'configuration_only_attempts': sum(row['kind'] == 'configuration_only' for row in cells),
            'failed_cells': sum(row['passed'] is False for row in cells),
            'unrecorded_pass_status': sum(row['passed'] is None for row in cells),
            'statuses': dict(sorted(counts.items())),
        },
        'cells': cells,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(document, indent=2, ensure_ascii=True) + '\n', encoding='utf-8')
    return document


def main() -> None:
    repo = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lab', type=Path, default=repo.parent / '420th-Arma3-Server-Lab')
    parser.add_argument('--output', type=Path, default=repo / 'docs/community-updates/ia-performance-gameplay-20260910/native-campaign.json')
    args = parser.parse_args()
    artifact_root = args.lab / 'artifacts/ia-update'
    if not artifact_root.is_dir():
        parser.error('The selected lab has no native campaign artifact directory.')
    document = export_campaign(artifact_root, args.output)
    print(json.dumps(document['summary'], sort_keys=True))


if __name__ == '__main__':
    main()
