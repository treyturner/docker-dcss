# docker-dcss

Packages the open source turn-based CRPG [Dungeon Crawl Stone Soup](https://crawl.develz.org/) as a standalone server with webtiles support, allowing you to play in a browser from anywhere.

Images are published to GitHub Container Registry, Forgejo, and Docker Hub:

- `ghcr.io/treyturner/dcss`
- `forgejo.treyturner.info/treyturner/dcss`
- `docker.io/treyturner/dcss`

## Quick Start

```sh
docker run -d -p 8080:8080 -v dcss-data:/data treyturner/dcss
```

Then open `http://localhost:8080` in a browser.

## Image Tags

Every push to `main` builds and publishes a **dev** image. When ready, a dev image is promoted to a **release** tag.

| Tag | Description |
| --- | --- |
| `<version>-dev` | Development build from `main` (e.g. `0.34.1-dev`) |
| `<version>` | Stable release promoted from the corresponding dev tag (e.g. `0.34.1`) |
| `latest` | Points to the most recent stable release |

## Configuration

Runtime configuration is handled through environment variables. At container startup, the entrypoint generates the server's `config.yml` and `games.d/base.yaml` from these values.

### Volumes

| Path | Purpose |
| --- | --- |
| `/data` | All persistent game data, user databases, and logs |

### Server

| Variable | Default | Description |
| --- | --- | --- |
| `DCSS_BIND_ADDRESS` | _(all interfaces)_ | Address to bind to |
| `DCSS_BIND_PORT` | `8080` | HTTP listen port |
| `DCSS_SERVER_ID` | _(empty)_ | Server name used in ttyrec metadata |
| `DCSS_HTTP_XHEADERS` | _(unset)_ | Set to trust `X-Real-IP` header from a reverse proxy |

### Data and Persistence

All persistent data defaults to paths under `/data`. Mount a volume there to preserve state across restarts.

| Variable | Default | Description |
| --- | --- | --- |
| `DCSS_DATA` | `/data` | Base directory for all persistent data |
| `DCSS_PASSWORD_DB` | `$DCSS_DATA/passwd.db3` | User and password database |
| `DCSS_DIR_PATH` | `$DCSS_DATA/crawl` | Crawl `-dir` base path for saves, prefs, and shared data (milestones, logfile, bones) |
| `DCSS_RCFILE_PATH` | `$DCSS_DATA/rcs` | Player RC files |
| `DCSS_MACRO_PATH` | `$DCSS_DATA/rcs` | Player macro files |
| `DCSS_MORGUE_PATH` | `$DCSS_DATA/rcs/%n` | Morgue dump directory (`%n` = player name) |
| `DCSS_TTYREC_PATH` | `$DCSS_DATA/rcs/ttyrecs/%n` | TTYrec recording directory |
| `DCSS_INPROGRESS_PATH` | `$DCSS_DATA/rcs/running` | In-progress game tracking |
| `DCSS_SOCKET_PATH` | `$DCSS_DATA/rcs` | Unix socket directory for crawl IPC |

### Logging

| Variable | Default | Description |
| --- | --- | --- |
| `DCSS_LOG_LEVEL` | `INFO` | `DEBUG`, `INFO`, `WARNING`, `ERROR`, or `CRITICAL` |
| `DCSS_LOG_FILE` | _(unset)_ | Log file path; logs to stderr only if unset |
| `DCSS_LOG_FORMAT` | `%(asctime)s %(levelname)s: %(message)s` | Python logging format string |

### Security

| Variable | Default | Description |
| --- | --- | --- |
| `DCSS_CRYPT_ALGORITHM` | `6` | crypt() algorithm (`6` = SHA-512, `1` = MD5) |
| `DCSS_MAX_PASSWD_LENGTH` | _(upstream: 20)_ | Maximum password length |

### Connections

| Variable | Default | Description |
| --- | --- | --- |
| `DCSS_MAX_CONNECTIONS` | _(upstream: 100)_ | Maximum concurrent connections |
| `DCSS_CONNECTION_TIMEOUT` | _(upstream: 600)_ | Seconds between connection liveness checks |
| `DCSS_MAX_IDLE_TIME` | _(upstream: 18000)_ | Maximum idle time while playing (seconds) |
| `DCSS_MAX_LOBBY_IDLE_TIME` | _(upstream: 10800)_ | Maximum idle time in lobby (seconds) |
| `DCSS_MAX_CHAT_LENGTH` | _(upstream: 1000)_ | Max chat message length; `0` disables chat |

### URLs

| Variable | Default | Description |
| --- | --- | --- |
| `DCSS_LOBBY_URL` | _(unset)_ | Public URL of the lobby (required for password reset emails) |
| `DCSS_PLAYER_URL` | _(unset)_ | Player page URL template with `%s` for the player name |
| `DCSS_MORGUE_URL` | _(unset)_ | Public-facing URL for morgue files |

### SSL

Provide both `DCSS_SSL_CERT` and `DCSS_SSL_KEY` to enable HTTPS.

| Variable | Default | Description |
| --- | --- | --- |
| `DCSS_SSL_CERT` | _(unset)_ | Path to SSL certificate file (inside the container) |
| `DCSS_SSL_KEY` | _(unset)_ | Path to SSL private key file (inside the container) |
| `DCSS_SSL_PORT` | `8443` | HTTPS listen port |

### SMTP

Set `DCSS_SMTP_HOST` to enable email support (required for password resets).

| Variable | Default | Description |
| --- | --- | --- |
| `DCSS_SMTP_HOST` | _(unset)_ | SMTP server hostname |
| `DCSS_SMTP_PORT` | `25` | SMTP server port |
| `DCSS_SMTP_USE_SSL` | `false` | Use SSL for SMTP connections |
| `DCSS_SMTP_USER` | _(empty)_ | SMTP authentication username |
| `DCSS_SMTP_PASSWORD` | _(empty)_ | SMTP authentication password |
| `DCSS_SMTP_FROM_ADDR` | `noreply@crawl.example.org` | Sender address for automated emails |
| `DCSS_ALLOW_PASSWORD_RESET` | _(unset)_ | Allow users to request password reset emails |
| `DCSS_ADMIN_PASSWORD_RESET` | _(unset)_ | Allow admins to generate password reset tokens |

### Moderation

| Variable | Default | Description |
| --- | --- | --- |
| `DCSS_NEW_ACCOUNTS_DISABLED` | _(unset)_ | Disable new account registration |
| `DCSS_NEW_ACCOUNTS_HOLD` | _(unset)_ | Hold new accounts for admin approval |

### Process

| Variable | Default | Description |
| --- | --- | --- |
| `DCSS_UID` | _(unset)_ | Numeric user ID to drop privileges to after binding |
| `DCSS_GID` | _(unset)_ | Numeric group ID to drop privileges to after binding |

### Development

| Variable | Default | Description |
| --- | --- | --- |
| `DCSS_AUTOLOGIN` | _(unset)_ | Auto-login username (insecure; development only) |

### Examples

Behind a reverse proxy with custom port:

```sh
docker run -d \
    -e DCSS_HTTP_XHEADERS=true \
    -e DCSS_LOBBY_URL=https://crawl.example.com/ \
    -p 1337:8080 \
    -v dcss-data:/data \
    treyturner/dcss
```

With standard HTTP on port 80 and SSL on port 443:

```sh
docker run -d \
    -e DCSS_BIND_PORT=80 \
    -e DCSS_SSL_CERT=/certs/fullchain.pem \
    -e DCSS_SSL_KEY=/certs/privkey.pem \
    -e DCSS_SSL_PORT=443 \
    -p 80:80 -p 443:443 \
    -v dcss-data:/data \
    -v /etc/letsencrypt/live/crawl.example.com:/certs:ro \
    treyturner/dcss
```

## Building from Source

To build an image of the latest upstream release:

```sh
docker build -t dcss .
```

or specify a version via the `CRAWL_TAG` build arg, though the build will surely break at some prior version:

```sh
docker build --build-arg CRAWL_TAG=0.34.0 -t dcss .
```

| Build Argument | Default | Description |
| --- | --- | --- |
| `CRAWL_REPO` | `https://github.com/crawl/crawl` | Git repository to clone |
| `CRAWL_TAG` | _(latest upstream)_ | Version tag to build; appears in the lobby UI |
