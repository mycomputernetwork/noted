# Deployment Guide

## Target

- **Server:** dabba.tailca1b9f.ts.net (MacBook Air)
- **User:** prabhanshu
- **Deploy path:** ~/services/noted
- **Public URL:** https://noted.mycomputer.network (via Pangolin)

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

On the Pangolin admin side, add a resource for `noted.mycomputer.network`
pointing at dabba's newt client and port 3000. DNS for `mycomputer.network`
is managed wherever Pangolin's setup expects it (see Pangolin's own docs for
the exact provider integration) — there is no separate tunnel binary, no
per-app `cloudflared` config, and no `service install` step to repeat for
each new app in the fleet; one newt client on dabba serves every
`*.mycomputer.network` resource registered in Pangolin.

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

## Application structure on server

```
~/services/noted/
├── current/              # Symlink to latest release
├── releases/             # Previous releases (kept 5)
│   ├── 20260817120000/
│   └── ...
├── shared/               # Persistent data across deploys
│   ├── config/
│   │   └── master.key
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

## Troubleshooting

### App not starting

```bash
# Check launchd logs
ssh prabhanshu@dabba.local "tail -100 ~/services/noted/shared/log/launchd.err.log"

# Check if service is loaded
ssh prabhanshu@dabba.local "launchctl list | grep com.noted.app"

# Manually restart
cap production noted:restart
```

### Database issues

```bash
# SSH to server
ssh prabhanshu@dabba.local

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

Create a backup script on dabba.local:

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
