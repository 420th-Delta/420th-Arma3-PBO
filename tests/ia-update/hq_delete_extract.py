"""Prepare the exact mapper position contrast from the frozen production copy."""
import hashlib
import json
from pathlib import Path


def extract(source: Path, destination: Path) -> None:
    source_file = source / "code/functions/fn_serverObjectsMapper.sqf"
    raw = source_file.read_bytes()
    text = raw.decode("utf-8-sig").replace("\r\n", "\n")
    old = "[(random -1000),(random -1000),(1000 + (random 1000))]"
    replacement = "(if (((QS_core_vehicles_map getOrDefault [toLowerANSI _type,_type]) isKindOf 'House') && {!surfaceIsWater _newPos}) then {_newPos} else {" + old + "})"
    anchor = "\tif (_code isNotEqualTo {}) then {\n\t\t_newObj = [_newObj] call _code;\n\t};\n"
    publish = (
        "\tprivate _mappedHouse = _newObj;\n" + anchor +
        "\t// Preserve callback changes in the existing entity-bound client snapshot.\n"
        "\tif ((_mappedHouse isEqualType objNull) && {!isNull _mappedHouse} &&\n"
        "\t\t{!isSimpleObject _mappedHouse} && {_mappedHouse isKindOf 'House'} &&\n"
        "\t\t{!surfaceIsWater (getPosWorld _mappedHouse)}) then {\n"
        "\t\t_mappedHouse setVariable ['QS_client_houseVectors',[vectorDir _mappedHouse,vectorUp _mappedHouse],FALSE];\n"
        "\t\t[_mappedHouse] call QS_fnc_serverPublishEntityState;\n"
        "\t};\n"
    )
    if text.count(anchor) != 1:
        raise ValueError("Expected one mapper callback anchor")
    if text.count(replacement) == 2 and text.count(old) == 2 and text.count(publish) == 1:
        baseline_text = text.replace(replacement, old).replace(publish, anchor)
        changed = text
        mode = "fixed-source"
        matched = replacement
    elif replacement not in text and text.count(old) == 2 and publish not in text:
        baseline_text = text
        changed = text.replace(old, replacement).replace(anchor, publish)
        mode = "baseline-source"
        matched = old
    else:
        raise ValueError("Expected two consistent baseline or exact corrected mapper position expressions")
    destination.mkdir(parents=True, exist_ok=True)
    baseline = destination / "mapper-baseline.sqf"
    baseline.write_bytes(baseline_text.encode("utf-8"))
    variant = destination / "mapper-final-position.sqf"
    variant.write_bytes(changed.encode("utf-8"))
    metadata = {
        "source": "code/functions/fn_serverObjectsMapper.sqf",
        "source_sha256": hashlib.sha256(raw).hexdigest(),
        "baseline_sha256": hashlib.sha256(baseline.read_bytes()).hexdigest(),
        "variant_sha256": hashlib.sha256(variant.read_bytes()).hexdigest(),
        "mode": mode,
        "old_expression": old,
        "replacement": replacement,
        "replacement_count": 2,
        "entity_state_publication": publish,
        "entity_state_publication_anchor": anchor,
        "entity_state_publication_count": 1,
        "matched_expression": matched,
        "source_offsets": [i for i in range(len(text)) if text.startswith(matched, i)],
        "offset_basis": "UTF-8-sig decoded characters with CRLF normalized to LF",
        "production_modified": False,
    }
    (destination / "manifest.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
