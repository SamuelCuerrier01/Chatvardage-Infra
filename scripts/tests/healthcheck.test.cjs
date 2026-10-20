'use strict';

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const scenario = JSON.parse(process.env.HEALTHCHECK_SCENARIO || '{}');
const services = ['postgres', 'redis', 'auth-service', 'room-service', 'message-service', 'user-config-service', 'dashboard', 'serveur-api'];
const databases = ['local_auth', 'local_rooms', 'local_messages', 'local_config'];
const log = (entry) => fs.appendFileSync(process.env.HEALTHCHECK_LOG, JSON.stringify(entry) + '\n');

if (process.env.HEALTHCHECK_FETCH_FIXTURE) {
  global.fetch = async (url, options) => {
    log({ probe: process.env.HEALTHCHECK_FETCH_FIXTURE, url, timeout: options?.signal instanceof AbortSignal });
    const dashboard = process.env.HEALTHCHECK_FETCH_FIXTURE === 'dashboard';
    if (scenario[dashboard ? 'dashboardReject' : 'gatewayReject']) throw new Error('network unavailable');
    const status = scenario[dashboard ? 'dashboardStatus' : 'gatewayStatus'] || 200;
    return {
      status, ok: status >= 200 && status < 300,
      json: async () => {
        if (scenario.invalidJson) throw new SyntaxError('invalid JSON');
        return scenario.report ?? { status: 'ok', service: 'serveur-api', upstreams: { auth: 'ok', room: 'ok', message: 'ok', userConfig: 'ok' } };
      },
    };
  };
} else if (process.argv[2] === '--fake-psql') {
  log({ psql: process.argv.slice(3) });
  if (scenario.psqlError) process.exit(1);
  console.log((scenario.databases || databases).join('\n'));
} else if (process.argv[2] === '--fake-pg-isready') {
  log({ pg_isready: process.argv.slice(3) });
  process.exit(scenario.pgNotReady ? 1 : 0);
} else if (process.argv[2] === '--fake-docker') {
  const args = process.argv.slice(3);
  log({ docker: args });
  if (args[0] === 'compose' && args[1] === 'ps') {
    const service = args[3];
    if (scenario.psError === service) process.exit(1);
    if (scenario.missing !== service) console.log(service);
  } else if (args[0] === 'inspect') {
    const service = args.at(-1);
    if (scenario.inspectError === service) process.exit(1);
    console.log(scenario.states?.[service] || 'running healthy');
  } else if (args[0] === 'compose' && args[1] === 'exec' && args[2] === '-T') {
    const service = args[3];
    if (scenario.execError === service) process.exit(1);
    if (service === 'redis') {
      console.log(scenario.redisReply ?? 'PONG');
    } else if (service === 'postgres') {
      const result = spawnSync(process.env.HEALTHCHECK_SHELL, args.slice(5), {
        env: { ...process.env, POSTGRES_USER: 'postgres', AUTH_DB: databases[0], ROOMS_DB: databases[1], MESSAGES_DB: databases[2], CONFIG_DB: databases[3] }, encoding: 'utf8',
      });
      process.stdout.write(result.stdout || ''); process.stderr.write(result.stderr || '');
      process.exit(result.status ?? 1);
    } else {
      const result = spawnSync(process.execPath, ['-r', __filename, ...args.slice(5)], {
        env: { ...process.env, HEALTHCHECK_FETCH_FIXTURE: service }, encoding: 'utf8',
      });
      process.stdout.write(result.stdout || ''); process.stderr.write(result.stderr || '');
      process.exit(result.status ?? 1);
    }
  } else {
    console.error('Unexpected Docker command', args); process.exit(2);
  }
} else {
  const assert = require('node:assert/strict');
  const { test, after } = require('node:test');
  const shell = process.env.HEALTHCHECK_TEST_SHELL || (process.platform === 'win32' ? 'C:\\Program Files\\Git\\bin\\bash.exe' : '/bin/sh');
  const repo = path.resolve(__dirname, '../..');
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'chatvardage-health-'));
  const posix = (value) => process.platform === 'win32' ? value.replace(/\\/g, '/').replace(/^([A-Z]):/i, (_, drive) => '/' + drive.toLowerCase()) : value;
  const bin = path.join(temporary, 'bin');
  fs.mkdirSync(bin);
  for (const [name, mode] of [['docker', '--fake-docker'], ['psql', '--fake-psql'], ['pg_isready', '--fake-pg-isready']]) {
    fs.writeFileSync(path.join(bin, name), `#!/bin/sh\nexec node "$HEALTHCHECK_DRIVER" ${mode} "$@"\n`, { mode: 0o755 });
  }
  after(() => fs.rmSync(temporary, { recursive: true, force: true }));

  function run(input = {}, args = []) {
    const logfile = path.join(temporary, `calls-${process.pid}-${Date.now()}-${Math.random().toString(16).slice(2)}.jsonl`);
    fs.writeFileSync(logfile, '');
    const result = spawnSync(shell, ['-c', 'PATH="$1:$PATH"; export PATH; shift; exec sh "$@"', '_', posix(bin), posix(path.join(repo, 'scripts/healthcheck.sh')), ...args], {
      cwd: repo, encoding: 'utf8', timeout: 20000,
      env: { ...process.env, HEALTHCHECK_DRIVER: __filename, HEALTHCHECK_SCENARIO: JSON.stringify(input), HEALTHCHECK_LOG: logfile, HEALTHCHECK_SHELL: shell },
    });
    assert.ifError(result.error);
    return { ...result, output: result.stdout + result.stderr, calls: fs.readFileSync(logfile, 'utf8').trim().split('\n').filter(Boolean).map(JSON.parse) };
  }
  function fails(input, args) {
    const result = run(input, args);
    assert.notEqual(result.status, 0, result.output);
    assert.doesNotMatch(result.output, /Stack OK|Infrastructure OK/);
    return result;
  }

  test('full healthy stack: eight required services, custom databases, actual probe routes and bounded HTTP', () => {
    const result = run();
    assert.equal(result.status, 0, result.output);
    assert.match(result.output, /Stack OK/);
    assert.deepEqual(result.calls.filter(x => x.docker?.[1] === 'ps').map(x => x.docker[3]), services);
    assert.deepEqual(result.calls.filter(x => x.probe), [
      { probe: 'dashboard', url: 'http://localhost:3000/administration', timeout: true },
      { probe: 'serveur-api', url: 'http://localhost:3000/api/health/upstreams', timeout: true },
    ]);
    for (const name of databases) assert.ok(result.output.includes(name + ' : présente'));
    assert.ok(result.calls.find(x => x.psql)?.psql.includes('ON_ERROR_STOP=1'));
  });
  for (const service of services) {
    test(`${service} absent never reports success`, () => fails({ missing: service }));
    test(`${service}: compose ps error never reports success`, () => fails({ psError: service }));
    test(`${service}: inspect error never reports success`, () => fails({ inspectError: service }));
  }
  for (const state of ['running starting', 'running unhealthy', 'running sans-healthcheck', 'exited healthy', 'paused healthy']) {
    test(`Dashboard state ${state} is rejected`, () => fails({ states: { dashboard: state } }));
  }
  for (const service of ['postgres', 'redis', 'dashboard', 'serveur-api']) {
    test(`${service}: exec failure never reports success`, () => fails({ execError: service }));
  }
  test('PostgreSQL not ready is rejected', () => fails({ pgNotReady: true }));
  test('psql error is rejected', () => fails({ psqlError: true }));
  for (const database of databases) {
    test(`missing configured database ${database} is rejected`, () => fails({ databases: databases.filter(x => x !== database) }));
  }
  for (const reply of ['NOAUTH Authentication required', 'ERR PONG', 'PONG extra', '']) {
    test(`Redis reply ${JSON.stringify(reply)} is rejected`, () => fails({ redisReply: reply }));
  }
  test('Dashboard HTTP failure is rejected', () => fails({ dashboardStatus: 503 }));
  test('Dashboard network failure is rejected', () => fails({ dashboardReject: true }));
  test('Gateway HTTP failure even with healthy body is rejected', () => fails({ gatewayStatus: 503 }));
  test('Gateway network failure is rejected', () => fails({ gatewayReject: true }));
  test('Gateway non-JSON response is rejected', () => fails({ invalidJson: true }));
  test('Gateway degraded body with HTTP 200 is rejected', () => fails({ report: { status: 'degraded', service: 'serveur-api', upstreams: { auth: 'ok', room: 'ok', message: 'ok', userConfig: 'ok' } } }));
  test('Gateway missing upstreams with HTTP 200 is rejected', () => fails({ report: { status: 'ok', service: 'serveur-api' } }));
  test('Gateway wrong service with HTTP 200 is rejected', () => fails({ report: { status: 'ok', service: 'other', upstreams: { auth: 'ok', room: 'ok', message: 'ok', userConfig: 'ok' } } }));
  for (const upstream of ['auth', 'room', 'message', 'userConfig']) {
    test(`Gateway upstream ${upstream} unavailable with HTTP 200 is rejected`, () => fails({ report: { status: 'ok', service: 'serveur-api', upstreams: { auth: 'ok', room: 'ok', message: 'ok', userConfig: 'ok', [upstream]: 'unavailable' } } }));
  }
  test('--infra succeeds for infrastructure only and never probes Dashboard/Gateway or says Stack OK', () => {
    const result = run({ missing: 'dashboard' }, ['--infra']);
    assert.equal(result.status, 0, result.output);
    assert.match(result.output, /Infrastructure OK/); assert.doesNotMatch(result.output, /Stack OK/);
    assert.deepEqual(result.calls.filter(x => x.docker?.[1] === 'ps').map(x => x.docker[3]), ['postgres', 'redis']);
    assert.equal(result.calls.filter(x => x.probe).length, 0);
  });
  test('--infra still fails for unhealthy infrastructure', () => fails({ states: { postgres: 'running unhealthy' } }, ['--infra']));
  test('--infra still fails for missing configured database', () => fails({ databases: databases.slice(1) }, ['--infra']));
  test('unknown option exits 2 without Docker calls', () => {
    const result = fails({}, ['--wrong']); assert.equal(result.status, 2); assert.equal(result.calls.length, 0);
  });
  test('--help exits 0 without a success verdict or Docker calls', () => {
    const result = run({}, ['--help']); assert.equal(result.status, 0); assert.equal(result.calls.length, 0); assert.doesNotMatch(result.output, /Stack OK|Infrastructure OK/);
  });
}
