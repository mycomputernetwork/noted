# Deployment Guide

## Target

- **Server:** dabba.tailca1b9f.ts.net (MacBook Air)
- **User:** prabhanshu
- **Deploy path:** ~/services/noted
- **Public URL:** https://noted.mycomputer.network (via Cloudflare Tunnel)

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

### 3. Set up Cloudflare Tunnel

On dabba:

```bash
# Install cloudflared if not already installed
brew install cloudflared

# Authenticate with Cloudflare (opens browser, do this once)
cloudflared tunnel login

# Create a tunnel
cloudflared tunnel create noted

# This will output a tunnel ID - save it
# Creates ~/.cloudflared/<tunnel-id>.json

# Create tunnel config
cat > ~/.cloudflared/config.yml <<EOF
tunnel: <tunnel-id-from-above>
credentials-file: /Users/prabhanshu/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: noted.mycomputer.network
    service: http://localhost:3000
  - service: http_status:404
EOF

# Route DNS through the tunnel
cloudflared tunnel route dns noted noted.mycomputer.network

# Run the tunnel (test first)
cloudflared tunnel run noted

# If that works, install as a service
sudo cloudflared service install
sudo launchctl start com.cloudflare.cloudflared
```

### 4. DNS Configuration

The `cloudflared tunnel route dns` command automatically creates a CNAME in your Cloudflare DNS pointing to the tunnel.

If you're using DigitalOcean DNS instead, you'll need to:
1. Get the tunnel's CNAME target: `<tunnel-id>.cfargotunnel.com`
2. Add CNAME record in DigitalOcean:
   - **Name:** noted
   - **Value:** `<tunnel-id>.cfargotunnel.com`
   - **TTL:** 300

**Note:** The domain `mycomputer.network` needs to be managed in Cloudflare for `cloudflared tunnel route dns` to work. If it's in DigitalOcean, you'll need to manually add the CNAME.

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

### Cloudflare Tunnel not working

```bash
ssh prabhanshu@dabba.tailca1b9f.ts.net

# Check tunnel status
cloudflared tunnel info noted

# Check if service is running
sudo launchctl list | grep cloudflare

# View logs
tail -f ~/.cloudflared/*.log

# Restart the service
sudo launchctl stop com.cloudflare.cloudflared
sudo launchctl start com.cloudflare.cloudflared
```

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
