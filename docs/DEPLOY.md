# Deploying noted

Deploys with Capistrano to `~/services/noted` on dabba, behind Pangolin at
`https://noted.prabhanshugupta.com`. The box itself — how traffic arrives, what else runs
there, how to tell whether it is up — is `~/work/services/docs/`.

```bash
cap production deploy
cap production deploy:rollback
cap production noted:restart
```

The first deploy on a fresh box builds Ruby from source through mise and takes 15–20
minutes.

## Secrets

Production uses `config/credentials/production.yml.enc`, holding `secret_key_base` and the
issuer, client id and client secret for the production client registered in auth. The
`.enc` files are committed; the key is not.

`config/credentials/production.key` is the only linked file, uploaded on first deploy by
`noted:setup_credentials_key` from your local checkout — which aborts the deploy if it is
missing there, because production cannot decrypt without it and there is no second copy.
Keep it in a password manager.

Changing `secret_key_base` signs out every existing session.

## Environment

Set in the launchd plist, managed by Capistrano: `RAILS_ENV`, `NOTED_DB_PATH`,
`RAILS_LOG_TO_STDOUT`, `RAILS_SERVE_STATIC_FILES`, `PORT=3000`, and:

- `NOTED_URL` — OmniAuth builds the OIDC `redirect_uri` from it, and auth rejects a
  handshake whose `redirect_uri` is not exactly the registered one.
- `NOTED_HOST` — derived from it, for mailer URLs.
- `SSL_CERT_FILE=/etc/ssl/cert.pem` — see below.

## Verifying a deploy

A green deploy only means the code is on the box. The wiring to auth is not exercised by
booting, and each of these has been broken in production while the app served pages
normally:

```bash
ssh dabba 'cd ~/services/noted/current &&
  RAILS_ENV=production NOTED_DB_PATH=~/services/noted/shared/db_data \
  ~/.local/bin/mise exec -- bundle exec rails runner "
    puts AuthService.issuer
    puts AuthService.client_id
    puts AuthService.end_session_endpoint.inspect"'
```

Wants the public issuer, the production client's uid, and a non-nil `end_session_endpoint`.
A `nil` endpoint means discovery failed — TLS verification or the cache database, both
below — and sign-out will silently leave auth's session alive.

Then sign in with a real Google identity, sign out through the account menu, and confirm
the fan-out landed:

```bash
ssh dabba 'cd ~/services/auth/current &&
  RAILS_ENV=production AUTH_DB_PATH=~/services/auth/shared/db_data \
  ~/.local/bin/mise exec -- bundle exec rails runner "pp LogoutDelivery.order(:created_at).last"'
```

`delivered` is the pass. `failed` means the POST never arrived at noted; `rejected` means
noted refused the logout token.

## Traps that have actually bitten

### No CA store: outbound HTTPS fails to verify

mise's Ruby is linked against a Homebrew OpenSSL whose `cert.pem` does not exist on dabba,
so it has **no trusted roots at all**:

```
certificate verify failed (unable to get local issuer certificate)
```

This breaks OIDC discovery, the JWKS fetch, and in auth, Google's token exchange — so
sign-in dies just after the Google redirect while the app looks perfectly healthy.
`SSL_CERT_FILE=/etc/ssl/cert.pem` in the plist fixes it.

```bash
ruby -ropenssl -e 'p OpenSSL::X509::DEFAULT_CERT_FILE, File.exist?(OpenSSL::X509::DEFAULT_CERT_FILE)'
```

### Empty Solid Cache / Solid Queue schemas

`db:migrate` once wrote `db/cache_schema.rb` and `db/queue_schema.rb` as
`define(version: 0) do end` — files that exist and declare nothing, so `db:prepare`
reported success while those databases held only `schema_migrations`. Every `Rails.cache`
read raised, `AuthService.end_session_endpoint` rescued it and returned `nil`, and sign-out
skipped auth **silently**. After any deploy that touches them:

```bash
sqlite3 ~/services/noted/shared/db_data/production_cache.sqlite3 ".tables"   # wants solid_cache_entries
sqlite3 ~/services/noted/shared/db_data/production_queue.sqlite3 ".tables"   # wants solid_queue_jobs, …
```

`db:prepare` will not repair a database missing its tables — it records a schema sha in
`ar_internal_metadata` and skips. Load it explicitly:

```bash
DISABLE_DATABASE_ENVIRONMENT_CHECK=1 rails db:schema:load:cache db:schema:load:queue
```

### 503 from the public hostname while the app is fine

Pangolin's error page, not Rails'. Check the app answers on the box before going to the
Pangolin admin:

```bash
ssh dabba 'curl -s -o /dev/null -w "%{http_code}\n" -H "Host: noted.prabhanshugupta.com" http://127.0.0.1:3000/up'
```

The `Host` header matters: Puma binds loopback only and Rails checks the host, so a bare
`curl 127.0.0.1:3000` returns 403 and tells you nothing.

## Backups

There is no backup job. `shared/db_data/` and `shared/storage/` are what would need one.
