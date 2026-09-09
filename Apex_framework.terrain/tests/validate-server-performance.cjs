// Static checks only. Run with Node; no dependencies or Arma process required.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const names = ['perfBegin', 'perfEnd', 'perfInit', 'deleteOutOfBoundsLoop', 'spawnGroup',
  'unitSetup', 'serverObjectsMapper', 'core', 'eventEntityKilled', 'aoDefend', 'aoEnemy',
  'customInventory', 'aoGetTerrainData', 'findRandomPos', 'curatorSync',
  'corruptTransformDiagnostics'];

function structurallyBalanced(source, name) {
  const stack = [];
  let i = 0;
  while (i < source.length) {
    if (source.startsWith('//', i)) {
      const end = source.indexOf('\n', i);
      i = end < 0 ? source.length : end + 1;
    } else if (source.startsWith('/*', i)) {
      const end = source.indexOf('*/', i + 2);
      assert(end >= 0, `${name}: unterminated comment`);
      i = end + 2;
    } else if ('"\''.includes(source[i])) {
      const quote = source[i++];
      let closed = false;
      while (i < source.length) {
        if (source[i++] === quote) {
          if (source[i] === quote) { i++; } else { closed = true; break; }
        }
      }
      assert(closed, `${name}: unterminated string`);
    } else {
      const c = source[i++];
      if ('([{'.includes(c)) stack.push(c);
      if (')]}'.includes(c)) assert.equal(stack.pop(), '([{'[')]}'.indexOf(c)], `${name}: mismatched delimiter`);
    }
  }
  assert.equal(stack.length, 0, `${name}: unclosed delimiter`);
}

for (const name of names) structurallyBalanced(read(`code/functions/fn_${name}.sqf`), name);
structurallyBalanced(read('TGC/Functions/Database/fn_dbQuery.sqf'), 'dbQuery');
structurallyBalanced(read('code/config/serverPerformance.sqf'), 'settings');
const description = read('description.ext');
for (const name of ['perfBegin', 'perfEnd', 'perfInit']) {
  assert(description.includes(`class ${name} {file = "code\\functions\\fn_${name}.sqf";`), `${name}: missing registration`);
}
assert(/class perfInit \{[^}]*preInit = 1;/.test(description));
assert(description.includes('class corruptTransformDiagnostics {file = "code\\functions\\fn_corruptTransformDiagnostics.sqf"; postInit = 1;}'), 'Transform diagnostics missing postInit registration');
const helpers = ['perfBegin', 'perfEnd', 'perfInit'].map(n => read(`code/functions/fn_${n}.sqf`)).join('\n');
assert(!/\b(remoteExec(?:Call)?|publicVariable|allMissionObjects|allSimpleObjects)\b/i.test(helpers), 'Profiler must not broadcast or add world censuses');
assert(!/class QS_fnc_perf/.test(read('code/config/security.hpp')), 'Profiler must not be remotely allowlisted');
assert(helpers.includes('(count _perfActive) < 256'), 'Active registry must be bounded');
assert(helpers.includes('(count _perfRecent) > 16'), 'Recent history must be bounded');
assert(helpers.includes('_perfMs >= 5000'), 'Severe spans need reserved detail capacity');
assert(helpers.includes('_perfEndFrame - _perfStartFrame'), 'Frame deltas must be recorded');
assert(helpers.includes('_perfSnapshot = serverNamespace getVariable'), 'Summary must use a swapped snapshot');
const transformDiagnostics = read('code/functions/fn_corruptTransformDiagnostics.sqf');
assert(transformDiagnostics.includes('if (!isServer) exitWith {}'), 'Transform diagnostics must be server-only');
assert(!/\b(remoteExec(?:Call)?|publicVariable)\b/i.test(transformDiagnostics), 'Transform diagnostics must not broadcast');
assert(transformDiagnostics.includes("allMissionObjects ''"), 'Transform diagnostics must periodically reconcile all mission objects');
assert(transformDiagnostics.includes('finite _x'), 'Transform diagnostics must use the engine finite check');
assert(transformDiagnostics.includes("'EntityCreated'"), 'Transform diagnostics must inspect newly created entities');
assert(transformDiagnostics.includes("'EntityKilled'"), 'Transform diagnostics must inspect killed entities');
for (const field of ['class=', 'netId=', 'owner=', 'positionWorld=', 'velocity=', 'vectorDir=', 'vectorUp=']) {
  assert(transformDiagnostics.includes(field), `Transform diagnostic output missing ${field}`);
}
assert(transformDiagnostics.includes('QS_transformDiag_queueLimit'), 'Created-entity queue must be bounded');
assert(transformDiagnostics.includes('QS_transformDiag_cacheLimit'), 'Transform deduplication cache must be bounded');
assert(transformDiagnostics.includes("_related resize 16"), 'Killed-related immediate checks must be bounded');
assert.equal((read('TGC/Functions/Database/fn_dbQuery.sqf').match(/call QS_fnc_perfEnd/g) || []).length, 3, 'All 3 extension boundaries must be timed');
assert.equal((read('code/functions/fn_unitSetup.sqf').match(/call QS_fnc_perfEnd/g) || []).length, 3, 'All unitSetup returns must close the span');
assert.equal((read('code/functions/fn_aoGetTerrainData.sqf').match(/\[_perfTerrain,/g) || []).length, 5, 'All terrain type exits must close the span');
assert.equal((read('code/functions/fn_findRandomPos.sqf').match(/_perfAttempts = _perfAttempts \+ 1/g) || []).length, 2, 'Both search loops must count attempts');
for (const name of ['aoEnemy', 'aoDefend', 'spawnGroup', 'serverObjectsMapper']) {
  const lines = read(`code/functions/fn_${name}.sqf`).split(/\r?\n/);
  lines.forEach((line, i) => {
    if (/^\s*(?:private )?_\w+ = (?:_\w+ )?(?:createVehicle|createUnit|createSimpleObject)\b/.test(line)) {
      assert(lines[i - 1].includes('call QS_fnc_perfBegin'), `${name}:${i + 1}: missing creation start`);
      assert(lines[i + 1].includes('call QS_fnc_perfEnd'), `${name}:${i + 1}: missing creation end`);
    }
  });
}
console.log(`PASS: ${names.length + 2} SQF/config files structurally balanced; registration, locality, bounds, return paths, and creation/extension coverage checked. Arma runtime testing still required.`);
