# Deployment Guide

## Target

- **Server:** dabba.tailca1b9f.ts.net (MacBook Air)
- **User:** prabhanshu
- **Deploy path:** ~/services/noted
- **Public URL:** https://noted.prabhanshugupta.com (via Pangolin)

## Prerequisites on dabba

1. **SSH access configured**
   ```bash
   ssh prabhanshu@dabba.tailca1b9f.ts.net
   ```

2. **Tailscale installed and authenticated**
   ```bash
   tailscale status
   ```

3. **Git installed**
   ```bash
   git --version
   ```

## First-time setup

### 1. Prepare the server directory

```bash
ssh prabhanshu@dabba.tailca1b9f.ts.net "mkdir -p ~/services/noted"
```

**Note:** First deployment will install mise and build Ruby from source, which takes 15-20 minutes on the MacBook Air. This is normal and only happens once.

### 2. Initial deployment

From your local machine:

```bash
# Check SSH connectivity
cap production deploy:check

# First deploy (will install mise, Ruby, gems, and set up databases)
cap production deploy

# Check status
cap production noted:status
```

**Important:** The initial deployment includes building Ruby from source via mise. This will take 15-20 minutes on the MacBook Air. The command may appear hung during compilation - this is normal, just let it run.

### 3. Expose the app through Pangolin

Public-facing services (`noted`, `auth`, `chat`) reach the internet through
**Pangolin**, not a Cloudflare Tunnel. `newt`, Pangolin's local client, runs
on dabba and proxies inbound traffic to `127.0.0.1:PORT` over loopback —
which is why Puma binds only to `127.0.0.1`/`::1` in production
(`config/puma.rb`): nothing on the tailnet or LAN can reach the app
directly, only Pangolin's proxy, so Pangolin's auth gate can't be bypassed.

On the Pangolin admin side, add a resource for `noted.prabhanshugupta.com`
pointing at dabba's newt client and port 3000. DNS for `prabhanshugupta.com`
is managed wherever Pangolin's setup expects it (see Pangolin's own docs for
the exact provider integration) — there is no separate tunnel binary, no
per-app `cloudflared` config, and no `service install` step to repeat for
each new app in the fleet; one newt client on dabba serves every
`*.prabhanshugupta.com` resource registered in Pangolin.

**Bandwidth-heavy services stay on Tailscale, not Pangolin.** `photos`
(Immich) and `watch` (Jellyfin) serve large media payloads — video streams,
full-resolution photo libraries — and are reached over the tailnet directly
(`dabba.tailca1b9f.ts.net`) rather than proxied through Pangolin. Pangolin is
for small request/response traffic across services with public hostnames;
Tailscale is for the two services where routing every byte through an
additional proxy hop is wasteful and the client set (your own devices) is
already on the tailnet.

## Subsequent deployments

```bash
# Deploy latest changes
cap production deploy

# Restart app only
cap production noted:restart

# Check logs
ssh prabhanshu@dabba.tailca1b9f.ts.net "tail -f ~/services/noted/shared/log/launchd.out.log"

# Stop app
cap production noted:stop
```

## Verifying a deploy

A green `cap production deploy` only means the code is on the box. The wiring to
auth is not exercised by booting, so check it directly — each of these has been
broken in production while the app served pages normally:

```bash
ssh prabhanshu@dabba.tailca1b9f.ts.net 'cd ~/services/noted/current &&
  RAILS_ENV=production NOTED_DB_PATH=~/services/noted/shared/db_data \
  ~/.local/bin/mise exec -- bundle exec rails runner "
    puts AuthService.issuer
    puts AuthService.client_id
    puts AuthService.end_session_endpoint.inspect"'
```

Wants the public issuer, the production client's uid, and a non-nil
`end_session_endpoint`. A `nil` endpoint means discovery failed — either TLS
verification or the cache database, both above — and sign-out will silently
leave auth's session alive.

Then the part no check can replace: sign in with a real Google identity, sign
out through the account menu, and confirm in auth that the fan-out landed.

```bash
ssh prabhanshu@dabba.tailca1b9f.ts.net 'cd ~/services/auth/current &&
  RAILS_ENV=production AUTH_DB_PATH=~/services/auth/shared/db_data \
  ~/.local/bin/mise exec -- bundle exec rails runner "pp LogoutDelivery.last"'
```

`delivered` is the pass. `failed` means the POST never arrived at noted;
`rejected` means noted refused the logout token.

## Application structure on server

```
~/services/noted/
├── current/              # Symlink to latest release
├── releases/             # Previous releases (kept 5)
│   ├── 20260817120000/
│   └── ...
├── shared/               # Persistent data across deploys
│   ├── config/
│   │   └── credentials/
│   │       └── production.key
│   ├── db_data/          # SQLite databases
│   │   ├── production.sqlite3
│   │   ├── production_cache.sqlite3
│   │   ├── production_queue.sqlite3
│   │   └── production_cable.sqlite3
│   ├── log/
│   ├── storage/          # Active Storage blobs
│   ├── tmp/
│   └── vendor/bundle/    # Gems
└── repo/                 # Git cache
```

## Environment variables

Set in launchd plist (managed by Capistrano):

- `RAILS_ENV=production`
- `NOTED_DB_PATH` → shared/db_data
- `RAILS_LOG_TO_STDOUT=true`
- `RAILS_SERVE_STATIC_FILES=true`
- `PORT=3000`
- `NOTED_URL=https://noted.prabhanshugupta.com` — set from `:noted_url` in
  `deploy.rb`. OmniAuth builds the OIDC `redirect_uri` from it, and auth
  rejects a handshake whose `redirect_uri` is not the registered one exactly.
- `NOTED_HOST` — derived from `NOTED_URL`, for mailer URLs.
- `SSL_CERT_FILE=/etc/ssl/cert.pem` — see below. Without it the app has no CA
  store and every outbound HTTPS call fails.

## Secrets

Production uses per-environment credentials: `config/credentials/production.yml.enc`,
holding `secret_key_base` and the `auth` issuer, client id and client secret for
the **production** client registered in auth. Both `.enc` files are committed;
only the key is not.

`config/credentials/production.key` is the sole linked file. `noted:setup_credentials_key`
uploads it on first deploy from your local checkout and aborts the deploy if it
is missing there — production cannot decrypt without it, and there is no second
copy. Keep it in a password manager.

Editing them:

```bash
bin/rails credentials:edit --environment production
```

Changing `secret_key_base` signs out every existing session.

## Traps that have actually bitten

These three all present as something else, and cost an afternoon between them.

### No CA store: outbound HTTPS fails to verify

mise's Ruby is linked against a Homebrew OpenSSL whose `cert.pem` does not
exist on dabba, so it has **no trusted roots at all**:

```
certificate verify failed (unable to get local issuer certificate)
```

This breaks OIDC discovery, the JWKS fetch, and in auth, Google's token
exchange — so sign-in dies just after the Google redirect while the app looks
perfectly healthy. `SSL_CERT_FILE=/etc/ssl/cert.pem` in the plist fixes it.
Confirm with:

```bash
ruby -ropenssl -e 'p OpenSSL::X509::DEFAULT_CERT_FILE, File.exist?(OpenSSL::X509::DEFAULT_CERT_FILE)'
```

### Empty Solid Cache / Solid Queue schemas

`db:migrate` once wrote `db/cache_schema.rb` and `db/queue_schema.rb` as
`define(version: 0) do end` — files that exist and declare nothing, so
`db:prepare` reported success while the cache and queue databases held only
`schema_migrations`. Every `Rails.cache` read raised, and
`AuthService.end_session_endpoint` rescued it and returned `nil`, which made
sign-out skip auth **silently**. Verify after any deploy that touches them:

```bash
sqlite3 ~/services/noted/shared/db_data/production_cache.sqlite3 ".tables"   # wants solid_cache_entries
sqlite3 ~/services/noted/shared/db_data/production_queue.sqlite3 ".tables"   # wants solid_queue_jobs, …
```

If a database is missing its tables, `db:prepare` will not repair it — it
records a schema sha in `ar_internal_metadata` and skips. Load it explicitly:

```bash
DISABLE_DATABASE_ENVIRONMENT_CHECK=1 rails db:schema:load:cache db:schema:load:queue
```

### 503 from the public hostname while the app is fine

Pangolin's own error page, not Rails'. The resource has no reachable target.
Check the app answers on the box first, and only then go to the Pangolin admin:

```bash
ssh prabhanshu@dabba.tailca1b9f.ts.net \
  'curl -s -o /dev/null -w "%{http_code}\n" -H "Host: noted.prabhanshugupta.com" http://127.0.0.1:3000/up'
```

The `Host` header matters: Puma binds to loopback only, and Rails checks the
host, so a bare `curl 127.0.0.1:3000` returns 403 and tells you nothing.

## Troubleshooting

### App not starting

```bash
# Check launchd logs
ssh prabhanshu@dabba.tailca1b9f.ts.net "tail -100 ~/services/noted/shared/log/launchd.err.log"

# Check if service is loaded
ssh prabhanshu@dabba.tailca1b9f.ts.net "launchctl list | grep com.noted.app"

# Manually restart
cap production noted:restart
```

### Database issues

```bash
# SSH to server
ssh prabhanshu@dabba.tailca1b9f.ts.net

# Navigate to current release
cd ~/services/noted/current

# Run migrations manually
~/.local/bin/mise exec -- bundle exec rails db:migrate RAILS_ENV=production
```

### Pangolin / newt not working

```bash
ssh prabhanshu@dabba.tailca1b9f.ts.net

# Check newt is running
sudo launchctl list | grep newt

# View logs
tail -f ~/.newt/*.log

# Restart the client
sudo launchctl stop com.pangolin.newt
sudo launchctl start com.pangolin.newt
```

If a service is reachable on the tailnet (`curl dabba.tailca1b9f.ts.net:PORT`)
but not on its public hostname, the fault is in newt's connection to Pangolin
or the resource mapping in the Pangolin admin — not in the Rails app itself.

## Rollback

```bash
# Roll back to previous release
cap production deploy:rollback
```

## Backup

Create a backup script on dabba.tailca1b9f.ts.net:

```bash
#!/bin/bash
# ~/backup-noted.sh

BACKUP_DIR=~/backups/noted
DATE=$(date +%Y%m%d-%H%M%S)
DATA_DIR=~/services/noted/shared/db_data
STORAGE_DIR=~/services/noted/shared/storage

mkdir -p $BACKUP_DIR

# Backup databases
sqlite3 $DATA_DIR/production.sqlite3 ".backup $BACKUP_DIR/production-$DATE.sqlite3"
tar czf $BACKUP_DIR/storage-$DATE.tar.gz -C $STORAGE_DIR .

# Keep last 30 days
find $BACKUP_DIR -name "*.sqlite3" -mtime +30 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete

echo "Backup completed: $DATE"
```

Schedule with cron:
```bash
crontab -e
# Add: 0 2 * * * ~/backup-noted.sh
```
