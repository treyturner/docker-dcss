#!/bin/sh
set -e

############
# DEFAULTS #
############

DCSS_DATA_DIR="${DCSS_DATA_DIR:-/data}"

## Server
DCSS_BIND_PORT="${DCSS_BIND_PORT:-80}"
DCSS_BIND_ADDRESS="${DCSS_BIND_ADDRESS:-}"
DCSS_SERVER_ID="${DCSS_SERVER_ID:-}"

## Data paths
DCSS_PASSWORD_DB="${DCSS_PASSWORD_DB:-${DCSS_DATA_DIR}/passwd.db3}"
DCSS_DIR_PATH="${DCSS_DIR_PATH:-${DCSS_DATA_DIR}}"
DCSS_RCFILE_PATH="${DCSS_RCFILE_PATH:-${DCSS_DATA_DIR}/rcs}"
DCSS_MACRO_PATH="${DCSS_MACRO_PATH:-${DCSS_DATA_DIR}/rcs}"
DCSS_MORGUE_PATH="${DCSS_MORGUE_PATH:-${DCSS_DATA_DIR}/rcs/%n}"
DCSS_TTYREC_PATH="${DCSS_TTYREC_PATH:-${DCSS_DATA_DIR}/rcs/ttyrecs/%n}"
DCSS_INPROGRESS_PATH="${DCSS_INPROGRESS_PATH:-${DCSS_DATA_DIR}/rcs/running}"
DCSS_SOCKET_PATH="${DCSS_SOCKET_PATH:-${DCSS_DATA_DIR}/rcs}"

## Logging
DCSS_LOG_LEVEL="${DCSS_LOG_LEVEL:-INFO}"
DCSS_LOG_FORMAT="${DCSS_LOG_FORMAT:-%(asctime)s %(levelname)s: %(message)s}"
DCSS_LOG_FILE="${DCSS_LOG_FILE:-}"

## Security
DCSS_CRYPT_ALGORITHM="${DCSS_CRYPT_ALGORITHM:-6}"

# Helpers

log_level_int() {
    case "$(echo "$1" | tr '[:lower:]' '[:upper:]')" in
        DEBUG)    echo 10 ;;
        INFO)     echo 20 ;;
        WARNING)  echo 30 ;;
        ERROR)    echo 40 ;;
        CRITICAL) echo 50 ;;
        *)        echo 20 ;;
    esac
}

#####################
# CONFIG GENERATION #
#####################

cfg=/app/source/webserver/config.yml

cat > "$cfg" <<EOF
bind_address: "${DCSS_BIND_ADDRESS}"
bind_port: ${DCSS_BIND_PORT}
password_db: "${DCSS_PASSWORD_DB}"
server_id: "${DCSS_SERVER_ID}"
crypt_algorithm: "${DCSS_CRYPT_ALGORITHM}"
dgl_status_file: "${DCSS_DATA_DIR}/rcs/status"
EOF

if [ -n "$DCSS_LOG_FILE" ]; then
    cat >> "$cfg" <<EOF
logging_config:
  level: $(log_level_int "$DCSS_LOG_LEVEL")
  format: "${DCSS_LOG_FORMAT}"
  filename: "${DCSS_LOG_FILE}"
EOF
else
    cat >> "$cfg" <<EOF
logging_config:
  level: $(log_level_int "$DCSS_LOG_LEVEL")
  format: "${DCSS_LOG_FORMAT}"
EOF
fi

## Connections and limits
[ -n "$DCSS_MAX_CONNECTIONS" ]     && echo "max_connections: ${DCSS_MAX_CONNECTIONS}" >> "$cfg"
[ -n "$DCSS_CONNECTION_TIMEOUT" ]  && echo "connection_timeout: ${DCSS_CONNECTION_TIMEOUT}" >> "$cfg"
[ -n "$DCSS_MAX_IDLE_TIME" ]       && echo "max_idle_time: ${DCSS_MAX_IDLE_TIME}" >> "$cfg"
[ -n "$DCSS_MAX_LOBBY_IDLE_TIME" ] && echo "max_lobby_idle_time: ${DCSS_MAX_LOBBY_IDLE_TIME}" >> "$cfg"
[ -n "$DCSS_MAX_CHAT_LENGTH" ]     && echo "max_chat_length: ${DCSS_MAX_CHAT_LENGTH}" >> "$cfg"
[ -n "$DCSS_MAX_PASSWD_LENGTH" ]   && echo "max_passwd_length: ${DCSS_MAX_PASSWD_LENGTH}" >> "$cfg"

## URLs
[ -n "$DCSS_LOBBY_URL" ]  && echo "lobby_url: \"${DCSS_LOBBY_URL}\"" >> "$cfg"
[ -n "$DCSS_PLAYER_URL" ] && echo "player_url: \"${DCSS_PLAYER_URL}\"" >> "$cfg"

## Reverse proxy
[ -n "$DCSS_HTTP_XHEADERS" ] && echo "http_xheaders: true" >> "$cfg"

## Moderation
[ -n "$DCSS_NEW_ACCOUNTS_DISABLED" ] && echo "new_accounts_disabled: true" >> "$cfg"
[ -n "$DCSS_NEW_ACCOUNTS_HOLD" ]     && echo "new_accounts_hold: true" >> "$cfg"

## Password reset
[ -n "$DCSS_ALLOW_PASSWORD_RESET" ] && echo "allow_password_reset: true" >> "$cfg"
[ -n "$DCSS_ADMIN_PASSWORD_RESET" ] && echo "admin_password_reset: true" >> "$cfg"

## Process IDs
[ -n "$DCSS_UID" ] && echo "uid: ${DCSS_UID}" >> "$cfg"
[ -n "$DCSS_GID" ] && echo "gid: ${DCSS_GID}" >> "$cfg"

## Dev XP
[ -n "$DCSS_AUTOLOGIN" ] && echo "autologin: \"${DCSS_AUTOLOGIN}\"" >> "$cfg"

## SMTP - if DCSS_SMTP_HOST is set
if [ -n "$DCSS_SMTP_HOST" ]; then
    cat >> "$cfg" <<EOF
smtp_host: "${DCSS_SMTP_HOST}"
smtp_port: ${DCSS_SMTP_PORT:-25}
smtp_use_ssl: ${DCSS_SMTP_USE_SSL:-false}
smtp_user: "${DCSS_SMTP_USER:-}"
smtp_password: "${DCSS_SMTP_PASSWORD:-}"
smtp_from_addr: "${DCSS_SMTP_FROM_ADDR:-noreply@crawl.example.org}"
EOF
fi

## SSL - when both cert and key are set
if [ -n "$DCSS_SSL_CERT" ] && [ -n "$DCSS_SSL_KEY" ]; then
    cat >> "$cfg" <<EOF
ssl_options:
  certfile: "${DCSS_SSL_CERT}"
  keyfile: "${DCSS_SSL_KEY}"
ssl_port: ${DCSS_SSL_PORT:-8443}
EOF
fi

###############################
# GENERATE BASE GAME TEMPLATE #
###############################

games=/app/source/webserver/games.d/base.yaml

if [ -n "$DCSS_MORGUE_URL" ]; then
    MORGUE_URL_YAML="\"${DCSS_MORGUE_URL}\""
else
    MORGUE_URL_YAML="null"
fi

cat > "$games" <<EOF
templates:
  - id: default
    crawl_binary: ./crawl
    rcfile_path: "${DCSS_RCFILE_PATH}"
    macro_path: "${DCSS_MACRO_PATH}"
    morgue_path: "${DCSS_MORGUE_PATH}"
    socket_path: "${DCSS_SOCKET_PATH}"
    dir_path: "${DCSS_DIR_PATH}"
    inprogress_path: "${DCSS_INPROGRESS_PATH}"
    ttyrec_path: "${DCSS_TTYREC_PATH}"
    client_path: ./webserver/game_data/
    morgue_url: ${MORGUE_URL_YAML}
    show_save_info: true
    allowed_with_hold: true
  - id: ${CRAWL_TAG}
    version: "${CRAWL_TAG}"

games:
  - id: dcss-web-${CRAWL_TAG}
    template: ${CRAWL_TAG}
    name: "Play %v"
  - id: seeded-web-${CRAWL_TAG}
    template: ${CRAWL_TAG}
    name: Seeded
    options:
      - -seed
  - id: descent-web-${CRAWL_TAG}
    template: ${CRAWL_TAG}
    name: Descent
    options:
      - -descent
  - id: tut-web-${CRAWL_TAG}
    template: ${CRAWL_TAG}
    name: Tutorial
    options:
      - -tutorial
  - id: sprint-web-${CRAWL_TAG}
    template: ${CRAWL_TAG}
    name: "Sprint %v"
    options:
      - -sprint
EOF

# Ensure data dirs exist with runtime user/group ownership

mkdir -p "${DCSS_DATA_DIR}" \
         "${DCSS_RCFILE_PATH}" \
         "${DCSS_INPROGRESS_PATH}"

[ -n "$DCSS_UID" ] && chown -R "$DCSS_UID" "${DCSS_DATA_DIR}" "${DCSS_RCFILE_PATH}" "${DCSS_INPROGRESS_PATH}"
[ -n "$DCSS_GID" ] && chgrp -R "$DCSS_GID" "${DCSS_DATA_DIR}" "${DCSS_RCFILE_PATH}" "${DCSS_INPROGRESS_PATH}"

# Launch

exec python webserver/server.py "$@"
