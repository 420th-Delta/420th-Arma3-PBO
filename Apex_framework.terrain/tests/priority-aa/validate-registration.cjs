// Static registration guard; run with Node and no Arma process.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const missionRoot = path.resolve(__dirname, '..', '..');
const read = relative => fs.readFileSync(path.join(missionRoot, relative), 'utf8');

function aaBlock(relative) {
  const source = read(relative);
  const start = [
    source.indexOf('/*/---------- VEHICLE AA/*/'),
    source.indexOf('/*/---------- AA VEHICLE/*/')
  ].find(index => index >= 0);
  const end = source.indexOf('/*/---------- GARRISON', start);
  assert(start >= 0 && end > start, `${relative}: missing bounded mobile-AA block`);
  return source.slice(start, end);
}

for (const relative of [
  'code/functions/fn_smEnemyGuer.sqf',
  'code/functions/fn_smEnemyInd.sqf'
]) {
  const source = aaBlock(relative);
  assert.match(source, /_SMaa\s*=\s*createVehicle\b/, `${relative}: mobile Tigris must be created here`);
  assert.match(
    source,
    /_grp\s*=\s*createVehicleCrew\s+_SMaa;\s*\r?\n\s*\[_SMaa\]\s+call\s+QS_fnc_airDefenseRegister;/,
    `${relative}: each mobile Tigris must register after its crew exists`
  );
}

const register = read('code/functions/fn_airDefenseRegister.sqf');
assert(register.includes("'O_APC_Tracked_02_AA_F'"), 'Tigris class must remain eligible for air-defense control');
const description = read('description.ext');
assert(
  description.includes('class airDefenseRegister {file = "code\\functions\\fn_airDefenseRegister.sqf";'),
  'airDefenseRegister must remain compiled by the mission'
);

console.log('PASS: FIA and Independent side-mission mobile Tigrises register with the Priority AA controller.');
