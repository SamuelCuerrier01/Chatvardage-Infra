const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const infra = path.resolve(__dirname, '../..');
const compose = fs.readFileSync(path.join(infra, 'docker-compose.yml'), 'utf8');
const entrypoint = fs.readFileSync(path.join(infra, 'scripts/docker-entrypoint-env.sh'), 'utf8');

const runtimeServices = [
  'postgres', 'redis', 'auth-service', 'room-service', 'message-service',
  'user-config-service', 'dashboard', 'serveur-api',
];

test('Compose lance réellement generer-env.sh au bootstrap', () => {
  assert.match(compose, /^  generer-env:\s*$/m);
  assert.match(compose, /\/bin\/sh \/infra\/scripts\/generer-env\.sh/);
  assert.match(compose, /if \[ -f \/infra\/\.env \]/);
});

test('tous les services runtime attendent la génération du .env', () => {
  for (const service of runtimeServices) {
    const start = compose.indexOf(`  ${service}:\n`);
    assert.notEqual(start, -1, `${service} absent du Compose`);
    const rest = compose.slice(start + 3);
    const next = rest.search(/^  [A-Za-z0-9_-]+:\s*$/m);
    const section = next === -1 ? compose.slice(start) : compose.slice(start, start + 3 + next);
    assert.match(section, /generer-env:\s*\n\s+condition: service_completed_successfully/, `${service} doit attendre generer-env`);
    assert.match(section, /\.\/\.runtime-env\/[a-z-]+:\/run\/chatvardage:ro/, `${service} doit voir son seul .env`);
    assert.doesNotMatch(section, /\.\/:\/infra:ro/, `${service} ne doit pas voir tous les secrets`);
  }
});

test('le Gateway écoute localement par défaut et le bootstrap prépare les secrets séparés', () => {
  assert.match(compose, /API_BIND_ADDRESS:-127\.0\.0\.1/);
  assert.match(compose, /"\[::1\]:3000:3000"/);
  assert.match(compose, /preparer-env-services\.sh/);
  assert.doesNotMatch(compose, /chmod 644 \/infra\/\.env/);
});

test('entrypoint commun charge .env et construit les URLs sensibles au runtime', () => {
  assert.match(entrypoint, /\. "\$ENV_FILE"/);
  assert.match(entrypoint, /DATABASE_URL=.*AUTH_DB_PASSWORD/);
  assert.match(entrypoint, /DATABASE_URL=.*ROOMS_DB_PASSWORD/);
  assert.match(entrypoint, /DATABASE_URL=.*MESSAGES_DB_PASSWORD/);
  assert.match(entrypoint, /DATABASE_URL=.*CONFIG_DB_PASSWORD/);
  assert.match(entrypoint, /REDIS_URL=.*REDIS_PASSWORD/);
  assert.match(entrypoint, /COOKIE_SECRET=.*DASHBOARD_COOKIE_SECRET/);
  assert.match(entrypoint, /SESSION_SECRET=.*DASHBOARD_SESSION_SECRET/);
});
