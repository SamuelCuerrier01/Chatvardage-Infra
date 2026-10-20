const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

test('chaque service ne reçoit que ses secrets, sans rotation du fichier source', () => {
  const racine = fs.mkdtempSync(path.join(os.tmpdir(), 'chatvardage-isolation-'));
  try {
    fs.mkdirSync(path.join(racine, 'scripts'));
    const script = path.join(racine, 'scripts/preparer-env-services.sh');
    fs.copyFileSync(path.resolve(__dirname, '../preparer-env-services.sh'), script);
    const source = 'NODE_ENV=production\nJWT_SECRET=jwt-secret\nAUTH_DB_PASSWORD=auth-secret\nMESSAGES_DB_PASSWORD=message-secret\nPOSTGRES_SUPERPASS=super-secret\nREDIS_PASSWORD=redis-secret\nDASHBOARD_SESSION_SECRET=admin-secret\nINTERNAL_SERVICE_TOKEN=internal-secret\nNON_AUTORISE=secret-inattendu\n';
    fs.writeFileSync(path.join(racine, '.env'), source);
    const uid = process.getuid() || 1000;
    const gid = process.getgid() || 1000;
    const env = { ...process.env, LOCAL_UID: String(uid), LOCAL_GID: String(gid) };
    const resultat = spawnSync('sh', [script], { encoding: 'utf8', env });
    assert.equal(resultat.status, 0, resultat.stderr);
    const lire = (service) => fs.readFileSync(path.join(racine, '.runtime-env', service, '.env'), 'utf8');
    assert.match(lire('auth'), /JWT_SECRET=jwt-secret/);
    assert.match(lire('auth'), /AUTH_DB_PASSWORD=auth-secret/);
    assert.doesNotMatch(lire('auth'), /super-secret|message-secret|admin-secret/);
    assert.equal(lire('redis'), 'REDIS_PASSWORD=redis-secret\n');
    assert.match(lire('message'), /REDIS_PASSWORD=redis-secret/);
    assert.doesNotMatch(lire('serveur-api'), /jwt-secret|auth-secret|super-secret|admin-secret/);
    assert.doesNotMatch(lire('dashboard'), /internal-secret|jwt-secret|auth-secret/);
    for (const service of ['postgres', 'redis', 'auth', 'room', 'message', 'user-config', 'dashboard', 'serveur-api']) {
      assert.doesNotMatch(lire(service), /NON_AUTORISE/);
    }
    assert.equal(fs.readFileSync(path.join(racine, '.env'), 'utf8'), source);
    assert.equal(fs.statSync(path.join(racine, '.env')).mode & 0o777, 0o600);
    if (process.getuid() === 0) fs.chownSync(racine, uid, gid);
    const deuxieme = spawnSync('sh', [script], { encoding: 'utf8', env, uid, gid });
    assert.equal(deuxieme.status, 0, deuxieme.stderr);
    assert.equal(lire('auth').includes('JWT_SECRET=jwt-secret'), true);
    assert.equal(fs.readFileSync(path.join(racine, '.env'), 'utf8'), source);
    assert.equal(fs.statSync(path.join(racine, '.env')).mode & 0o777, 0o600);
    for (const service of ['postgres', 'redis', 'auth', 'room', 'message', 'user-config', 'dashboard', 'serveur-api']) {
      const dossier = path.join(racine, '.runtime-env', service);
      for (const fichier of [dossier, path.join(dossier, '.env')]) {
        assert.equal(fs.statSync(fichier).uid, uid);
        assert.equal(fs.statSync(fichier).gid, gid);
      }
    }
  } finally {
    fs.rmSync(racine, { recursive: true, force: true });
  }
});
