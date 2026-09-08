// Run with: node test-settings.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { spawnSync } = require('node:child_process');

const source = fs.readFileSync(`${__dirname}/Service.qml`, 'utf8');
const id = 'miharekar.studio-display-auto-brightness';
let entry = { id, sensor: 'rear', profile: 'dim', paused: false };
const applied = [];
const context = vm.createContext({
  manifest: { id },
  sensorSide: 'front', profile: 'balanced', paused: false, settingsReady: false,
  settingsFile: { text: () => JSON.stringify({ bar: { layout: { right: [entry] } } }) },
  shell: {
    // Simulate Omarchy exposing the previous snapshot during a settings write.
    barConfig: { layout: { right: [{ id, sensor: 'front', profile: 'bright' }] } },
    updateEntryInline: (_, next) => { entry = next; },
  },
  restartController: () => applied.push([context.sensorSide, context.profile, context.paused]),
  startController: () => {},
});

for (const name of ['configEntry', 'syncSettings', 'persist', 'setSensorSide', 'setProfile', 'setPaused']) {
  const match = source.match(new RegExp(`  function ${name}\\([^]*?\\n  }`));
  assert.ok(match, `Missing ${name}`);
  vm.runInContext(match[0], context);
}

context.syncSettings();
assert.deepEqual(applied.at(-1), ['rear', 'dim', false]);
context.setProfile('bright');
context.syncSettings();
assert.deepEqual(applied.at(-1), ['rear', 'bright', false]);
context.setSensorSide('front');
context.syncSettings();
assert.deepEqual(applied.at(-1), ['front', 'bright', false]);
context.setProfile('balanced');
context.syncSettings();
assert.deepEqual(applied.at(-1), ['front', 'balanced', false]);
context.setPaused(true);
context.syncSettings();
assert.deepEqual(applied.at(-1), ['front', 'balanced', true]);
assert.equal(applied.length, 5);
console.log('Settings stay synchronized despite a stale scoped barConfig.');

const controller = fs.readFileSync(`${__dirname}/controller`, 'utf8');
const manualCheck = controller.match(/  if \(\( last_applied > 0[^]*?\n  fi/);
assert.ok(manualCheck);
const result = spawnSync('bash', ['-c', `
  last_applied=40; last_manual_check=0; manual_check_interval=2; SECONDS=3; monitor=test
  timeout() { printf '50\\n'; }
  omarchy() { return 0; }
  emit_status() { printf '%s\\n' "$3"; }
  sleep() { exit 99; }
  ${manualCheck[0]}
  exit 98
`], { encoding: 'utf8', timeout: 2000 });
assert.equal(result.status, 0, result.stderr);
assert.equal(result.stdout.trim(), 'true');
console.log('Manual adjustment reports pause and exits without sleeping.');
