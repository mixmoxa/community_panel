#!/bin/bash

red='\033[1;31m'
green='\033[1;32m'
blue='\033[1;34m'
yellow='\033[1;33m'
cyan='\033[1;36m'
gray='\033[0;90m'
orange='\033[1;38;5;208m'
bold='\033[1m'
plain='\033[0m'

cur_dir=$(pwd)

# ── Localization (shared with the x-ui CLI via /etc/x-ui/lang; en|ru) ─────────
# choose_language() (below) sets XUI_LANG and persists it before any localized
# output. t <key> looks up the active language with an English fallback.
XUI_LANG="en"
[[ -f /etc/x-ui/lang ]] && XUI_LANG="$(tr -d '[:space:]' < /etc/x-ui/lang 2>/dev/null)"
[[ "$XUI_LANG" == "ru" ]] || XUI_LANG="en"
declare -A T_EN T_RU
t() { local k="$1" v=""; [[ "$XUI_LANG" == "ru" ]] && v="${T_RU[$k]}"; printf '%s' "${v:-${T_EN[$k]}}"; }
# orange-bold prompt label (eGames style)
askp() { echo -e "${bold}${orange}$*${plain}"; }

# ── Batch 3: turnkey install flow ────────────────────────────────────────────
T_EN[i_deps]="Installing dependencies";                  T_RU[i_deps]="Установка пакетных зависимостей"
T_EN[i_bbr]="BBR enabled";                               T_RU[i_bbr]="BBR включен"
T_EN[i_base]="Community Panel configured on port %s; reverse-proxy will run after start"; T_RU[i_base]="Community Panel настроена с портом %s, реверс-прокси заработает после запуска"
T_EN[i_acme]="Installing acme.sh";                       T_RU[i_acme]="Установка acme.sh"
T_EN[i_cert]="Issuing certificate for %s";               T_RU[i_cert]="Выпуск сертификата для %s"
T_EN[i_cert_fail]="Certificate issue failed for %s (check if the domain's DNS A-record is correct and port 80 on your server is not occupied), aborting installation"; T_RU[i_cert_fail]="Ошибка выпуска сертификата для %s (убедитесь что DNS A-запись домена указывает на этот сервер и проверьте что порт 80 не занят на сервере), отмена установки"
T_EN[i_nginx]="Installing Nginx + JQ";                   T_RU[i_nginx]="Установка Nginx + JQ"
T_EN[i_startnginx]="Starting Nginx";                     T_RU[i_startnginx]="Запуск Nginx"
T_EN[i_nginxtest]="Nginx config test failed:";           T_RU[i_nginxtest]="Ошибка при проверке конфигурации Nginx:"
T_EN[i_hy2]="Hysteria2 preconfigured inbound added";     T_RU[i_hy2]="Добавлен преднастроенный инбаунд Hysteria2"
T_EN[i_preconfigured]="Community Panel successfully installed"; T_RU[i_preconfigured]="Community Panel успешно установлена"
T_EN[p_dom_panel]="Community Panel domain:";             T_RU[p_dom_panel]="Домен для доступа в Community Panel:"
T_EN[p_dom_sub]="Subscription page domain:";             T_RU[p_dom_sub]="Домен для страницы подписок:"
T_EN[p_dom_self]="Selfsteal/Reality domain:";            T_RU[p_dom_self]="Домен для сайта-заглушки:"
T_EN[p_resolve]="%s resolves to %s, not server %s.";     T_RU[p_resolve]="A-запись %s привязана к айпи %s, а не к айпи сервера %s."
T_EN[p_continue]="Continue anyway? [y/N]:";              T_RU[p_continue]="Продолжить в любом случае? [y/N]:"
T_EN[p_uniq]="Community Panel, Subscription page and Selfsteal/Reality domains must be unique. Aborting installation"; T_RU[p_uniq]="Домены для Community Panel, страницы подписок и сайта-заглушки не должны быть одинаковыми, установка будет прервана"
T_EN[p_email]="Enter your email for Let's Encrypt ACME.sh:"; T_RU[p_email]="Введите email-адрес для Let's Encrypt ACME.sh:"
T_EN[p_access]="Select Community Panel access method:";   T_RU[p_access]="Выберите способ доступа к Community Panel:"
T_EN[p_access1]="Secret webBasePath (as in 3x-ui, not recommended)"; T_RU[p_access1]="Secret webBasePath (как в 3x-ui, не рекомендуется)"
T_EN[p_access2]="Cookie-gate secret cookie-auth link (Recommended)"; T_RU[p_access2]="Cookie-gate авторизация через Cookie в браузере (рекомендуется)"
T_EN[p_choose]="Choose method:";                         T_RU[p_choose]="Выберите метод:"
T_EN[s_ready]="Community Panel is ready!";               T_RU[s_ready]="Community Panel готова!"
T_EN[s_panel]="Panel access link:";                      T_RU[s_panel]="Панель доступна по:"
T_EN[s_sub]="Subscription Page access link:";            T_RU[s_sub]="Страница подписок доступна по:"
T_EN[s_decoy]="Selfsteal/Reality access link:";          T_RU[s_decoy]="Сайт-заглушка доступен по:"
T_EN[s_login]="Your login/password:";                    T_RU[s_login]="Ваш логин/пароль:"
T_EN[s_entry]="secret cookie-gate link — save it!";      T_RU[s_entry]="секретная Cookie-gate ссылка - сохраните её!"
T_EN[s_failed]="Reverse-proxy setup is not completed, but the panel is installed; please fix the errors above and re-run the installation script"; T_RU[s_failed]="Ошибка установки реверс-прокси, но Community Panel установлена; пожалуйста, проверьте ошибки по сообщениям выше и перезапустите установку скриптом"
T_EN[s_running]="Community Panel %s installed and running"; T_RU[s_running]="Community Panel %s установлена и работает"
T_EN[s_cli]="CLI manager commands are:";                 T_RU[s_cli]="Команды для работы с CLI:"

# ── quiet-step UI: hide noisy command output behind one spinner line + a log ──
XUI_INSTALL_LOG="/var/log/x-ui-install.log"
spinner() {
    local pid=$1 text=$2 frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' i=0
    [[ -t 1 ]] || { wait "$pid" 2>/dev/null; return; }
    while kill -0 "$pid" 2>/dev/null; do
        i=$(((i + 1) % ${#frames}))
        printf "\r  ${cyan}%s${plain} %s" "${frames:$i:1}" "$text" > /dev/tty
        sleep 0.1
    done
    printf "\r\033[K" > /dev/tty
}
# run_step "Message" cmd args... → quiet run; ✔ on success, ✗ + log tail on fail
run_step() {
    local text=$1; shift
    mkdir -p "$(dirname "$XUI_INSTALL_LOG")" 2>/dev/null
    echo "=== $(date '+%F %T') :: ${text} :: $*" >> "$XUI_INSTALL_LOG"
    ("$@") >> "$XUI_INSTALL_LOG" 2>&1 &
    local pid=$!
    spinner "$pid" "$text"
    if wait "$pid"; then
        echo -e "  ${green}✔${plain} $text"
        return 0
    fi
    echo -e "  ${red}✗${plain} $text"
    echo -e "  ${gray}--- last log lines (${XUI_INSTALL_LOG}) ---${plain}"
    tail -n 8 "$XUI_INSTALL_LOG" | sed 's/^/    /'
    return 1
}

xui_folder="${XUI_MAIN_FOLDER:=/usr/local/x-ui}"
xui_service="${XUI_SERVICE:=/etc/systemd/system}"

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Fatal error: ${plain} Please run this script with root privilege \n " && exit 1

# Check OS and set release variable
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "Failed to check the system OS, please contact the author!" >&2
    exit 1
fi
echo -e "  ${gray}OS: $release${plain}"

arch() {
    case "$(uname -m)" in
        x86_64 | x64 | amd64) echo 'amd64' ;;
        i*86 | x86) echo '386' ;;
        armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
        armv7* | armv7 | arm) echo 'armv7' ;;
        armv6* | armv6) echo 'armv6' ;;
        armv5* | armv5) echo 'armv5' ;;
        s390x) echo 's390x' ;;
        *) echo -e "${green}Unsupported CPU architecture! ${plain}" && exit 1 ;;
    esac
}

echo -e "  ${gray}Arch: $(arch)${plain}"
if [[ $(arch) != "amd64" ]]; then
    echo -e "${red}Error: Only x86_64/amd64 architecture is supported for this edition!${plain}"
    exit 1
fi


# Simple helpers
is_ipv4() {
    [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && return 0 || return 1
}
is_ipv6() {
    [[ "$1" =~ : ]] && return 0 || return 1
}
is_ip() {
    is_ipv4 "$1" || is_ipv6 "$1"
}
is_domain() {
    [[ "$1" =~ ^([A-Za-z0-9](-*[A-Za-z0-9])*\.)+(xn--[a-z0-9]{2,}|[A-Za-z]{2,})$ ]] && return 0 || return 1
}

# Port helpers
is_port_in_use() {
    local port="$1"
    if command -v ss > /dev/null 2>&1; then
        ss -ltn 2> /dev/null | awk -v p=":${port}$" '$4 ~ p {exit 0} END {exit 1}'
        return
    fi
    if command -v netstat > /dev/null 2>&1; then
        netstat -lnt 2> /dev/null | awk -v p=":${port} " '$4 ~ p {exit 0} END {exit 1}'
        return
    fi
    if command -v lsof > /dev/null 2>&1; then
        lsof -nP -iTCP:${port} -sTCP:LISTEN > /dev/null 2>&1 && return 0
    fi
    return 1
}

install_base() {
    # Build the dependency-install command per distro, then run it quietly
    # behind one spinner line (no streaming package-manager output).
    local cmd
    case "${release}" in
        ubuntu | debian | armbian)
            cmd='apt-get update && apt-get install -y -q cron curl tar tzdata socat ca-certificates openssl'
            ;;
        fedora | amzn | virtuozzo | rhel | almalinux | rocky | ol)
            # install dependencies only — never run a full system upgrade
            cmd='dnf install -y -q cronie curl tar tzdata socat ca-certificates openssl'
            ;;
        centos)
            if [[ "${VERSION_ID}" =~ ^7 ]]; then
                cmd='yum install -y cronie curl tar tzdata socat ca-certificates openssl'
            else
                cmd='dnf install -y -q cronie curl tar tzdata socat ca-certificates openssl'
            fi
            ;;
        arch | manjaro | parch)
            # -Sy = refresh package metadata only (no -Syu full upgrade)
            cmd='pacman -Sy --noconfirm cronie curl tar tzdata socat ca-certificates openssl'
            ;;
        opensuse-tumbleweed | opensuse-leap)
            cmd='zypper refresh && zypper -q install -y cron curl tar timezone socat ca-certificates openssl'
            ;;
        alpine)
            cmd='apk update && apk add dcron curl tar tzdata socat ca-certificates openssl'
            ;;
        *)
            cmd='apt-get update && apt-get install -y -q cron curl tar tzdata socat ca-certificates openssl'
            ;;
    esac
    DEBIAN_FRONTEND=noninteractive run_step "$(t i_deps)" bash -c "$cmd"
}

gen_random_string() {
    local length="$1"
    openssl rand -base64 $((length * 2)) \
        | tr -dc 'a-zA-Z0-9' \
        | head -c "$length"
}

install_postgres_local() {
    local pg_user pg_pass
    pg_pass=$(gen_random_string 24)
    local pg_db="xui"
    local pg_host="127.0.0.1"
    local pg_port="5432"

    case "${release}" in
        ubuntu | debian | armbian)
            apt-get update >&2 && apt-get install -y -q postgresql >&2 || return 1
            ;;
        fedora | amzn | virtuozzo | rhel | almalinux | rocky | ol)
            dnf install -y -q postgresql-server postgresql-contrib >&2 || return 1
            [[ -d /var/lib/pgsql/data && -f /var/lib/pgsql/data/PG_VERSION ]] || postgresql-setup --initdb >&2 || return 1
            ;;
        centos)
            if [[ "${VERSION_ID}" =~ ^7 ]]; then
                yum install -y postgresql-server postgresql-contrib >&2 || return 1
            else
                dnf install -y -q postgresql-server postgresql-contrib >&2 || return 1
            fi
            [[ -d /var/lib/pgsql/data && -f /var/lib/pgsql/data/PG_VERSION ]] || postgresql-setup --initdb >&2 || return 1
            ;;
        arch | manjaro | parch)
            pacman -Syu --noconfirm postgresql >&2 || return 1
            if [[ ! -f /var/lib/postgres/data/PG_VERSION ]]; then
                sudo -u postgres initdb -D /var/lib/postgres/data >&2 || return 1
            fi
            ;;
        opensuse-tumbleweed | opensuse-leap)
            zypper -q install -y postgresql-server postgresql-contrib >&2 || return 1
            if [[ ! -f /var/lib/pgsql/data/PG_VERSION ]]; then
                install -d -o postgres -g postgres -m 700 /var/lib/pgsql/data >&2 || return 1
                su - postgres -c "initdb -D /var/lib/pgsql/data" >&2 || return 1
            fi
            ;;
        alpine)
            apk add --no-cache postgresql postgresql-contrib >&2 || return 1
            if [[ ! -f /var/lib/postgresql/data/PG_VERSION ]]; then
                /etc/init.d/postgresql setup >&2 || return 1
            fi
            rc-update add postgresql default >&2 2> /dev/null || true
            rc-service postgresql start >&2 || return 1
            ;;
        *)
            echo -e "${red}Unsupported distro for automatic PostgreSQL install: ${release}${plain}" >&2
            return 1
            ;;
    esac

    if [[ "${release}" != "alpine" ]]; then
        systemctl enable --now postgresql >&2 || return 1
    fi

    # Wait briefly for the server to accept connections.
    local i
    for i in 1 2 3 4 5; do
        sudo -u postgres psql -tAc 'SELECT 1' > /dev/null 2>&1 && break
        sleep 1
    done

    local existing_owner=""
    existing_owner=$(sudo -u postgres psql -tAc \
        "SELECT pg_catalog.pg_get_userbyid(datdba) FROM pg_database WHERE datname='${pg_db}'" 2> /dev/null \
        | tr -d '[:space:]')
    if [[ -n "${existing_owner}" && "${existing_owner}" != "postgres" ]]; then
        pg_user="${existing_owner}"
    else
        pg_user=$(gen_random_string 8)
    fi

    # Idempotent role/db creation. Identifiers are double-quoted because a
    # random username may start with a digit, which Postgres rejects unquoted.
    sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${pg_user}'" 2> /dev/null \
        | grep -q 1 \
        || sudo -u postgres psql -c "CREATE USER \"${pg_user}\" WITH PASSWORD '${pg_pass}';" >&2 || return 1

    sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${pg_db}'" 2> /dev/null \
        | grep -q 1 \
        || sudo -u postgres psql -c "CREATE DATABASE \"${pg_db}\" OWNER \"${pg_user}\";" >&2 || return 1

    sudo -u postgres psql -c "ALTER USER \"${pg_user}\" WITH PASSWORD '${pg_pass}';" >&2 || return 1

    local pg_pass_enc
    pg_pass_enc=$(printf '%s' "${pg_pass}" | sed -e 's/%/%25/g' -e 's/:/%3A/g' -e 's/@/%40/g' -e 's|/|%2F|g' -e 's/?/%3F/g' -e 's/#/%23/g')

    if [[ -n "${PG_CRED_FILE:-}" ]]; then
        local prev_umask
        prev_umask=$(umask)
        umask 077
        if ! cat > "${PG_CRED_FILE}" << EOF; then
PG_USER=${pg_user}
PG_PASS=${pg_pass}
PG_HOST=${pg_host}
PG_PORT=${pg_port}
PG_DB=${pg_db}
EOF
            umask "${prev_umask}"
            echo -e "${red}Failed to write PostgreSQL credentials to ${PG_CRED_FILE}${plain}" >&2
            return 1
        fi
        umask "${prev_umask}"
    fi

    echo "postgres://${pg_user}:${pg_pass_enc}@${pg_host}:${pg_port}/${pg_db}?sslmode=disable"
    return 0
}

ensure_pg_client() {
    if command -v pg_dump > /dev/null 2>&1 && command -v pg_restore > /dev/null 2>&1; then
        return 0
    fi
    echo -e "${yellow}Installing PostgreSQL client tools (pg_dump/pg_restore) for in-panel backup...${plain}" >&2
    case "${release}" in
        ubuntu | debian | armbian)
            apt-get update >&2 && apt-get install -y -q postgresql-client >&2 || return 1
            ;;
        fedora | amzn | virtuozzo | rhel | almalinux | rocky | ol)
            dnf install -y -q postgresql >&2 || return 1
            ;;
        centos)
            if [[ "${VERSION_ID}" =~ ^7 ]]; then
                yum install -y postgresql >&2 || return 1
            else
                dnf install -y -q postgresql >&2 || return 1
            fi
            ;;
        arch | manjaro | parch)
            pacman -Sy --noconfirm postgresql >&2 || return 1
            ;;
        opensuse-tumbleweed | opensuse-leap)
            zypper -q install -y postgresql >&2 || return 1
            ;;
        alpine)
            apk add --no-cache postgresql-client >&2 || return 1
            ;;
        *)
            return 1
            ;;
    esac
    command -v pg_dump > /dev/null 2>&1 && command -v pg_restore > /dev/null 2>&1
}

install_acme() {
    echo -e "${green}Installing acme.sh for SSL certificate management...${plain}"
    cd ~ || return 1
    # stdout is noisy → silence it, but KEEP stderr so failures are diagnosable
    curl -s https://get.acme.sh | sh > /dev/null
    if [ $? -ne 0 ]; then
        echo -e "${red}Failed to install acme.sh${plain}"
        return 1
    else
        echo -e "${green}acme.sh installed successfully${plain}"
    fi
    return 0
}

setup_ssl_certificate() {
    local domain="$1"
    local server_ip="$2"
    local existing_port="$3"
    local existing_webBasePath="$4"

    echo -e "${green}Setting up SSL certificate...${plain}"

    # Check if acme.sh is installed
    if ! command -v ~/.acme.sh/acme.sh &> /dev/null; then
        install_acme
        if [ $? -ne 0 ]; then
            echo -e "${yellow}Failed to install acme.sh, skipping SSL setup${plain}"
            return 1
        fi
    fi

    # Create certificate directory
    local certPath="/root/cert/${domain}"
    mkdir -p "$certPath"

    # Issue certificate
    echo -e "${green}Issuing SSL certificate for ${domain}...${plain}"
    echo -e "${yellow}Note: Port 80 must be open and accessible from the internet${plain}"

    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt --force > /dev/null 2>&1
    ~/.acme.sh/acme.sh --issue -d ${domain} --listen-v6 --standalone --httpport 80 --force

    if [ $? -ne 0 ]; then
        echo -e "${yellow}Failed to issue certificate for ${domain}${plain}"
        echo -e "${yellow}Please ensure port 80 is open and try again later with: x-ui${plain}"
        rm -rf ~/.acme.sh/${domain} ~/.acme.sh/${domain}_ecc 2> /dev/null
        rm -rf "$certPath" 2> /dev/null
        return 1
    fi

    # Install certificate
    ~/.acme.sh/acme.sh --installcert -d ${domain} \
        --key-file /root/cert/${domain}/privkey.pem \
        --fullchain-file /root/cert/${domain}/fullchain.pem \
        --reloadcmd "systemctl restart x-ui" > /dev/null 2>&1

    if [ $? -ne 0 ]; then
        echo -e "${yellow}Failed to install certificate${plain}"
        return 1
    fi

    # Enable auto-renew
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade > /dev/null 2>&1
    # Secure permissions: private key readable only by owner
    chmod 600 $certPath/privkey.pem 2> /dev/null
    chmod 644 $certPath/fullchain.pem 2> /dev/null

    # Set certificate for panel
    local webCertFile="/root/cert/${domain}/fullchain.pem"
    local webKeyFile="/root/cert/${domain}/privkey.pem"

    if [[ -f "$webCertFile" && -f "$webKeyFile" ]]; then
        ${xui_folder}/x-ui cert -webCert "$webCertFile" -webCertKey "$webKeyFile" > /dev/null 2>&1
        echo -e "${green}SSL certificate installed and configured successfully!${plain}"
        return 0
    else
        echo -e "${yellow}Certificate files not found${plain}"
        return 1
    fi
}

# Issue Let's Encrypt IP certificate with shortlived profile (~6 days validity)
# Requires acme.sh and port 80 open for HTTP-01 challenge
setup_ip_certificate() {
    local ipv4="$1"
    local ipv6="$2" # optional

    echo -e "${green}Setting up Let's Encrypt IP certificate (shortlived profile)...${plain}"
    echo -e "${yellow}Note: IP certificates are valid for ~6 days and will auto-renew.${plain}"
    echo -e "${yellow}Default listener is port 80. If you choose another port, ensure external port 80 forwards to it.${plain}"

    # Check for acme.sh
    if ! command -v ~/.acme.sh/acme.sh &> /dev/null; then
        install_acme
        if [ $? -ne 0 ]; then
            echo -e "${red}Failed to install acme.sh${plain}"
            return 1
        fi
    fi

    # Validate IP address
    if [[ -z "$ipv4" ]]; then
        echo -e "${red}IPv4 address is required${plain}"
        return 1
    fi

    if ! is_ipv4 "$ipv4"; then
        echo -e "${red}Invalid IPv4 address: $ipv4${plain}"
        return 1
    fi

    # Create certificate directory
    local certDir="/root/cert/ip"
    mkdir -p "$certDir"

    # Build domain arguments
    local domain_args="-d ${ipv4}"
    if [[ -n "$ipv6" ]] && is_ipv6 "$ipv6"; then
        domain_args="${domain_args} -d ${ipv6}"
        echo -e "${green}Including IPv6 address: ${ipv6}${plain}"
    fi

    # Set reload command for auto-renewal (add || true so it doesn't fail during first install)
    local reloadCmd="systemctl restart x-ui 2>/dev/null || rc-service x-ui restart 2>/dev/null || true"

    # Choose port for HTTP-01 listener (default 80, prompt override)
    local WebPort=""
    read -rp "Port to use for ACME HTTP-01 listener (default 80): " WebPort
    WebPort="${WebPort:-80}"
    if ! [[ "${WebPort}" =~ ^[0-9]+$ ]] || ((WebPort < 1 || WebPort > 65535)); then
        echo -e "${red}Invalid port provided. Falling back to 80.${plain}"
        WebPort=80
    fi
    echo -e "${green}Using port ${WebPort} for standalone validation.${plain}"
    if [[ "${WebPort}" -ne 80 ]]; then
        echo -e "${yellow}Reminder: Let's Encrypt still connects on port 80; forward external port 80 to ${WebPort}.${plain}"
    fi

    # Ensure chosen port is available
    while true; do
        if is_port_in_use "${WebPort}"; then
            echo -e "${yellow}Port ${WebPort} is in use.${plain}"

            local alt_port=""
            read -rp "Enter another port for acme.sh standalone listener (leave empty to abort): " alt_port
            alt_port="${alt_port// /}"
            if [[ -z "${alt_port}" ]]; then
                echo -e "${red}Port ${WebPort} is busy; cannot proceed.${plain}"
                return 1
            fi
            if ! [[ "${alt_port}" =~ ^[0-9]+$ ]] || ((alt_port < 1 || alt_port > 65535)); then
                echo -e "${red}Invalid port provided.${plain}"
                return 1
            fi
            WebPort="${alt_port}"
            continue
        else
            echo -e "${green}Port ${WebPort} is free and ready for standalone validation.${plain}"
            break
        fi
    done

    # Issue certificate with shortlived profile
    echo -e "${green}Issuing IP certificate for ${ipv4}...${plain}"
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt --force > /dev/null 2>&1

    ~/.acme.sh/acme.sh --issue \
        ${domain_args} \
        --standalone \
        --server letsencrypt \
        --certificate-profile shortlived \
        --days 6 \
        --httpport ${WebPort} \
        --force

    if [ $? -ne 0 ]; then
        echo -e "${red}Failed to issue IP certificate${plain}"
        echo -e "${yellow}Please ensure port ${WebPort} is reachable (or forwarded from external port 80)${plain}"
        # Cleanup acme.sh data for both IPv4 and IPv6 if specified
        rm -rf ~/.acme.sh/${ipv4} ~/.acme.sh/${ipv4}_ecc 2> /dev/null
        [[ -n "$ipv6" ]] && rm -rf ~/.acme.sh/${ipv6} ~/.acme.sh/${ipv6}_ecc 2> /dev/null
        rm -rf ${certDir} 2> /dev/null
        return 1
    fi

    echo -e "${green}Certificate issued successfully, installing...${plain}"

    # Install certificate
    # Note: acme.sh may report "Reload error" and exit non-zero if reloadcmd fails,
    # but the cert files are still installed. We check for files instead of exit code.
    ~/.acme.sh/acme.sh --installcert -d ${ipv4} \
        --key-file "${certDir}/privkey.pem" \
        --fullchain-file "${certDir}/fullchain.pem" \
        --reloadcmd "${reloadCmd}" 2>&1 || true

    # Verify certificate files exist (don't rely on exit code - reloadcmd failure causes non-zero)
    if [[ ! -f "${certDir}/fullchain.pem" || ! -f "${certDir}/privkey.pem" ]]; then
        echo -e "${red}Certificate files not found after installation${plain}"
        # Cleanup acme.sh data for both IPv4 and IPv6 if specified
        rm -rf ~/.acme.sh/${ipv4} ~/.acme.sh/${ipv4}_ecc 2> /dev/null
        [[ -n "$ipv6" ]] && rm -rf ~/.acme.sh/${ipv6} ~/.acme.sh/${ipv6}_ecc 2> /dev/null
        rm -rf ${certDir} 2> /dev/null
        return 1
    fi

    echo -e "${green}Certificate files installed successfully${plain}"

    # Enable auto-upgrade for acme.sh (ensures cron job runs)
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade > /dev/null 2>&1

    # Secure permissions: private key readable only by owner
    chmod 600 ${certDir}/privkey.pem 2> /dev/null
    chmod 644 ${certDir}/fullchain.pem 2> /dev/null

    # Configure panel to use the certificate
    echo -e "${green}Setting certificate paths for the panel...${plain}"
    ${xui_folder}/x-ui cert -webCert "${certDir}/fullchain.pem" -webCertKey "${certDir}/privkey.pem"

    if [ $? -ne 0 ]; then
        echo -e "${yellow}Warning: Could not set certificate paths automatically${plain}"
        echo -e "${yellow}Certificate files are at:${plain}"
        echo -e "  Cert: ${certDir}/fullchain.pem"
        echo -e "  Key:  ${certDir}/privkey.pem"
    else
        echo -e "${green}Certificate paths configured successfully${plain}"
    fi

    echo -e "${green}IP certificate installed and configured successfully!${plain}"
    echo -e "${green}Certificate valid for ~6 days, auto-renews via acme.sh cron job.${plain}"
    echo -e "${yellow}acme.sh will automatically renew and reload x-ui before expiry.${plain}"
    return 0
}

# Comprehensive manual SSL certificate issuance via acme.sh
ssl_cert_issue() {
    local existing_webBasePath=$(${xui_folder}/x-ui setting -show true | grep 'webBasePath:' | awk -F': ' '{print $2}' | tr -d '[:space:]' | sed 's#^/##')
    local existing_port=$(${xui_folder}/x-ui setting -show true | grep 'port:' | awk -F': ' '{print $2}' | tr -d '[:space:]')

    # check for acme.sh first
    if ! command -v ~/.acme.sh/acme.sh &> /dev/null; then
        echo "acme.sh could not be found. Installing now..."
        cd ~ || return 1
        curl -s https://get.acme.sh | sh
        if [ $? -ne 0 ]; then
            echo -e "${red}Failed to install acme.sh${plain}"
            return 1
        else
            echo -e "${green}acme.sh installed successfully${plain}"
        fi
    fi

    # get the domain here, and we need to verify it
    local domain=""
    while true; do
        read -rp "Please enter your domain name: " domain
        domain="${domain// /}" # Trim whitespace

        if [[ -z "$domain" ]]; then
            echo -e "${red}Domain name cannot be empty. Please try again.${plain}"
            continue
        fi

        if ! is_domain "$domain"; then
            echo -e "${red}Invalid domain format: ${domain}. Please enter a valid domain name.${plain}"
            continue
        fi

        break
    done
    echo -e "${green}Your domain is: ${domain}, checking it...${plain}"
    SSL_ISSUED_DOMAIN="${domain}"

    # detect existing certificate and reuse it only if its files are actually
    # present and non-empty. acme.sh stores ECC certs under ${domain}_ecc and RSA
    # certs under ${domain}; a failed issuance can leave a domain entry in --list
    # with no usable cert files, which must not be reused (it produces a 0-byte
    # fullchain.pem). Broken partial state is cleaned up so issuance can proceed.
    local cert_exists=0
    if ~/.acme.sh/acme.sh --list 2> /dev/null | awk '{print $1}' | grep -Fxq "${domain}"; then
        local acmeCertDir=""
        if [[ -s ~/.acme.sh/${domain}_ecc/fullchain.cer && -s ~/.acme.sh/${domain}_ecc/${domain}.key ]]; then
            acmeCertDir=~/.acme.sh/${domain}_ecc
        elif [[ -s ~/.acme.sh/${domain}/fullchain.cer && -s ~/.acme.sh/${domain}/${domain}.key ]]; then
            acmeCertDir=~/.acme.sh/${domain}
        fi
        if [[ -n "${acmeCertDir}" ]]; then
            cert_exists=1
            local certInfo=$(~/.acme.sh/acme.sh --list 2> /dev/null | grep -F "${domain}")
            echo -e "${yellow}Existing certificate found for ${domain}, will reuse it.${plain}"
            [[ -n "${certInfo}" ]] && echo "$certInfo"
        else
            echo -e "${yellow}Found incomplete acme.sh state for ${domain} (no valid certificate files); cleaning it up and re-issuing.${plain}"
            rm -rf ~/.acme.sh/${domain} ~/.acme.sh/${domain}_ecc
        fi
    fi
    if [[ ${cert_exists} -eq 0 ]]; then
        echo -e "${green}Your domain is ready for issuing certificates now...${plain}"
    fi

    # create a directory for the certificate
    certPath="/root/cert/${domain}"
    if [ ! -d "$certPath" ]; then
        mkdir -p "$certPath"
    else
        rm -rf "$certPath"
        mkdir -p "$certPath"
    fi

    # get the port number for the standalone server
    local WebPort=80
    read -rp "Please choose which port to use (default is 80): " WebPort
    if [[ ${WebPort} -gt 65535 || ${WebPort} -lt 1 ]]; then
        echo -e "${yellow}Your input ${WebPort} is invalid, will use default port 80.${plain}"
        WebPort=80
    fi
    echo -e "${green}Will use port: ${WebPort} to issue certificates. Please make sure this port is open.${plain}"

    # Stop panel temporarily
    echo -e "${yellow}Stopping panel temporarily...${plain}"
    systemctl stop x-ui 2> /dev/null || rc-service x-ui stop 2> /dev/null

    if [[ ${cert_exists} -eq 0 ]]; then
        # issue the certificate
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt --force
        ~/.acme.sh/acme.sh --issue -d ${domain} --listen-v6 --standalone --httpport ${WebPort} --force
        if [ $? -ne 0 ]; then
            echo -e "${red}Issuing certificate failed, please check logs.${plain}"
            rm -rf ~/.acme.sh/${domain} ~/.acme.sh/${domain}_ecc
            systemctl start x-ui 2> /dev/null || rc-service x-ui start 2> /dev/null
            return 1
        else
            echo -e "${green}Issuing certificate succeeded, installing certificates...${plain}"
        fi
    else
        echo -e "${green}Using existing certificate, installing certificates...${plain}"
    fi

    # Setup reload command
    reloadCmd="systemctl restart x-ui || rc-service x-ui restart"
    echo -e "${green}Default --reloadcmd for ACME is: ${yellow}systemctl restart x-ui || rc-service x-ui restart${plain}"
    echo -e "${green}This command will run on every certificate issue and renew.${plain}"
    read -rp "Would you like to modify --reloadcmd for ACME? (y/n): " setReloadcmd
    if [[ "$setReloadcmd" == "y" || "$setReloadcmd" == "Y" ]]; then
        echo -e "\n${green}\t1.${plain} Preset: systemctl reload nginx ; systemctl restart x-ui"
        echo -e "${green}\t2.${plain} Input your own command"
        echo -e "${green}\t0.${plain} Keep default reloadcmd"
        read -rp "Choose an option: " choice
        case "$choice" in
            1)
                echo -e "${green}Reloadcmd is: systemctl reload nginx ; systemctl restart x-ui${plain}"
                reloadCmd="systemctl reload nginx ; systemctl restart x-ui"
                ;;
            2)
                echo -e "${yellow}It's recommended to put x-ui restart at the end${plain}"
                read -rp "Please enter your custom reloadcmd: " reloadCmd
                echo -e "${green}Reloadcmd is: ${reloadCmd}${plain}"
                ;;
            *)
                echo -e "${green}Keeping default reloadcmd${plain}"
                ;;
        esac
    fi

    # install the certificate
    local installOutput=""
    installOutput=$(~/.acme.sh/acme.sh --installcert -d ${domain} \
        --key-file /root/cert/${domain}/privkey.pem \
        --fullchain-file /root/cert/${domain}/fullchain.pem --reloadcmd "${reloadCmd}" 2>&1)
    local installRc=$?
    echo "${installOutput}"

    local installWroteFiles=0
    if echo "${installOutput}" | grep -q "Installing key to:" && echo "${installOutput}" | grep -q "Installing full chain to:"; then
        installWroteFiles=1
    fi

    if [[ -f "/root/cert/${domain}/privkey.pem" && -f "/root/cert/${domain}/fullchain.pem" && (${installRc} -eq 0 || ${installWroteFiles} -eq 1) ]]; then
        echo -e "${green}Installing certificate succeeded, enabling auto renew...${plain}"
    else
        echo -e "${red}Installing certificate failed, exiting.${plain}"
        if [[ ${cert_exists} -eq 0 ]]; then
            rm -rf ~/.acme.sh/${domain} ~/.acme.sh/${domain}_ecc
        fi
        systemctl start x-ui 2> /dev/null || rc-service x-ui start 2> /dev/null
        return 1
    fi

    # enable auto-renew
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    if [ $? -ne 0 ]; then
        echo -e "${yellow}Auto renew setup had issues, certificate details:${plain}"
        ls -lah /root/cert/${domain}/
        # Secure permissions: private key readable only by owner
        chmod 600 $certPath/privkey.pem 2> /dev/null
        chmod 644 $certPath/fullchain.pem 2> /dev/null
    else
        echo -e "${green}Auto renew succeeded, certificate details:${plain}"
        ls -lah /root/cert/${domain}/
        # Secure permissions: private key readable only by owner
        chmod 600 $certPath/privkey.pem 2> /dev/null
        chmod 644 $certPath/fullchain.pem 2> /dev/null
    fi

    # start panel
    systemctl start x-ui 2> /dev/null || rc-service x-ui start 2> /dev/null

    # Prompt user to set panel paths after successful certificate installation
    read -rp "Would you like to set this certificate for the panel? (y/n): " setPanel
    if [[ "$setPanel" == "y" || "$setPanel" == "Y" ]]; then
        local webCertFile="/root/cert/${domain}/fullchain.pem"
        local webKeyFile="/root/cert/${domain}/privkey.pem"

        if [[ -f "$webCertFile" && -f "$webKeyFile" ]]; then
            ${xui_folder}/x-ui cert -webCert "$webCertFile" -webCertKey "$webKeyFile"
            echo -e "${green}Certificate paths set for the panel${plain}"
            echo -e "${green}Certificate File: $webCertFile${plain}"
            echo -e "${green}Private Key File: $webKeyFile${plain}"
            echo ""
            echo -e "${green}Access URL: https://${domain}:${existing_port}/${existing_webBasePath}${plain}"
            echo -e "${yellow}Panel will restart to apply SSL certificate...${plain}"
            systemctl restart x-ui 2> /dev/null || rc-service x-ui restart 2> /dev/null
        else
            echo -e "${red}Error: Certificate or private key file not found for domain: $domain.${plain}"
        fi
    else
        echo -e "${yellow}Skipping panel path setting.${plain}"
    fi

    return 0
}

# Reusable interactive SSL setup (domain or IP)
# Sets global `SSL_HOST` to the chosen domain/IP for Access URL usage
prompt_and_setup_ssl() {
    local panel_port="$1"
    local web_base_path="$2"
    local server_ip="$3"

    local ssl_choice=""
    SSL_SCHEME="https"

    echo -e "${yellow}Choose SSL certificate setup method:${plain}"
    echo -e "${green}1.${plain} Let's Encrypt for Domain (90-day validity, auto-renews)"
    echo -e "${green}2.${plain} Let's Encrypt for IP Address (6-day validity, auto-renews)"
    echo -e "${green}3.${plain} Custom SSL Certificate (Path to existing files)"
    echo -e "${green}4.${plain} Skip SSL (advanced — behind reverse proxy / SSH tunnel only)"
    echo -e "${blue}Note:${plain} Options 1 & 2 require port 80 open. Option 3 requires manual paths."
    echo -e "${blue}Note:${plain} Option 4 serves the panel over plain HTTP — only safe behind nginx/Caddy or an SSH tunnel."
    read -rp "Choose an option (default 2 for IP): " ssl_choice
    ssl_choice="${ssl_choice// /}" # Trim whitespace

    # Default to 2 (IP cert) if input is empty or invalid (not 1, 3 or 4)
    if [[ "$ssl_choice" != "1" && "$ssl_choice" != "3" && "$ssl_choice" != "4" ]]; then
        ssl_choice="2"
    fi

    case "$ssl_choice" in
        1)
            # User chose Let's Encrypt domain option
            echo -e "${green}Using Let's Encrypt for domain certificate...${plain}"
            if ssl_cert_issue; then
                local cert_domain="${SSL_ISSUED_DOMAIN}"
                if [[ -z "${cert_domain}" ]]; then
                    cert_domain=$(~/.acme.sh/acme.sh --list 2> /dev/null | tail -1 | awk '{print $1}')
                fi

                if [[ -n "${cert_domain}" ]]; then
                    SSL_HOST="${cert_domain}"
                    echo -e "${green}✓ SSL certificate configured successfully with domain: ${cert_domain}${plain}"
                else
                    echo -e "${yellow}SSL setup may have completed, but domain extraction failed${plain}"
                    SSL_HOST="${server_ip}"
                fi
            else
                echo -e "${red}SSL certificate setup failed for domain mode.${plain}"
                SSL_HOST="${server_ip}"
            fi
            ;;
        2)
            # User chose Let's Encrypt IP certificate option
            echo -e "${green}Using Let's Encrypt for IP certificate (shortlived profile)...${plain}"

            # Ask for optional IPv6
            local ipv6_addr=""
            read -rp "Do you have an IPv6 address to include? (leave empty to skip): " ipv6_addr
            ipv6_addr="${ipv6_addr// /}" # Trim whitespace

            # Stop panel if running (port 80 needed)
            if [[ $release == "alpine" ]]; then
                rc-service x-ui stop > /dev/null 2>&1
            else
                systemctl stop x-ui > /dev/null 2>&1
            fi

            setup_ip_certificate "${server_ip}" "${ipv6_addr}"
            if [ $? -eq 0 ]; then
                SSL_HOST="${server_ip}"
                echo -e "${green}✓ Let's Encrypt IP certificate configured successfully${plain}"
            else
                echo -e "${red}✗ IP certificate setup failed. Please check port 80 is open.${plain}"
                SSL_HOST="${server_ip}"
            fi
            ;;
        3)
            # User chose Custom Paths (User Provided) option
            echo -e "${green}Using custom existing certificate...${plain}"
            local custom_cert=""
            local custom_key=""
            local custom_domain=""

            # 3.1 Request Domain to compose Panel URL later
            read -rp "Please enter domain name certificate issued for: " custom_domain
            custom_domain="${custom_domain// /}" # Remove spaces

            # 3.2 Loop for Certificate Path
            while true; do
                read -rp "Input certificate path (keywords: .crt / fullchain): " custom_cert
                # Strip quotes if present
                custom_cert=$(echo "$custom_cert" | tr -d '"' | tr -d "'")

                if [[ -f "$custom_cert" && -r "$custom_cert" && -s "$custom_cert" ]]; then
                    break
                elif [[ ! -f "$custom_cert" ]]; then
                    echo -e "${red}Error: File does not exist! Try again.${plain}"
                elif [[ ! -r "$custom_cert" ]]; then
                    echo -e "${red}Error: File exists but is not readable (check permissions)!${plain}"
                else
                    echo -e "${red}Error: File is empty!${plain}"
                fi
            done

            # 3.3 Loop for Private Key Path
            while true; do
                read -rp "Input private key path (keywords: .key / privatekey): " custom_key
                # Strip quotes if present
                custom_key=$(echo "$custom_key" | tr -d '"' | tr -d "'")

                if [[ -f "$custom_key" && -r "$custom_key" && -s "$custom_key" ]]; then
                    break
                elif [[ ! -f "$custom_key" ]]; then
                    echo -e "${red}Error: File does not exist! Try again.${plain}"
                elif [[ ! -r "$custom_key" ]]; then
                    echo -e "${red}Error: File exists but is not readable (check permissions)!${plain}"
                else
                    echo -e "${red}Error: File is empty!${plain}"
                fi
            done

            # 3.4 Apply Settings via x-ui binary
            ${xui_folder}/x-ui cert -webCert "$custom_cert" -webCertKey "$custom_key" > /dev/null 2>&1

            # Set SSL_HOST for composing Panel URL
            if [[ -n "$custom_domain" ]]; then
                SSL_HOST="$custom_domain"
            else
                SSL_HOST="${server_ip}"
            fi

            echo -e "${green}✓ Custom certificate paths applied.${plain}"
            echo -e "${yellow}Note: You are responsible for renewing these files externally.${plain}"

            systemctl restart x-ui > /dev/null 2>&1 || rc-service x-ui restart > /dev/null 2>&1
            ;;
        4)
            echo ""
            echo -e "${red}⚠ Panel will be installed WITHOUT SSL/TLS.${plain}"
            echo -e "${yellow}Login credentials and cookies will travel as plain HTTP.${plain}"
            echo -e "${yellow}Only safe when:${plain}"
            echo -e "${yellow}  • A reverse proxy (nginx, Caddy, Traefik) terminates TLS for you, or${plain}"
            echo -e "${yellow}  • You access the panel exclusively via SSH tunnel${plain}"
            echo ""

            SSL_SCHEME="http"
            SSL_HOST="${server_ip}"

            local bind_local=""
            read -rp "Bind the panel to 127.0.0.1 only? (recommended — forces SSH tunnel / reverse-proxy access) [y/N]: " bind_local
            if [[ "$bind_local" == "y" || "$bind_local" == "Y" ]]; then
                ${xui_folder}/x-ui setting -listenIP "127.0.0.1" > /dev/null 2>&1
                SSL_HOST="127.0.0.1"
                echo -e "${green}✓ Panel bound to 127.0.0.1 only. It is now unreachable from the public internet.${plain}"
                echo ""
                echo -e "${green}SSH Port Forwarding — open the panel from your local machine via:${plain}"
                echo -e "  Standard SSH command:"
                echo -e "  ${yellow}ssh -L 2222:127.0.0.1:${panel_port} root@${server_ip}${plain}"
                echo -e "  If using an SSH key:"
                echo -e "  ${yellow}ssh -i <sshkeypath> -L 2222:127.0.0.1:${panel_port} root@${server_ip}${plain}"
                echo -e "  Then open in your browser:"
                echo -e "  ${yellow}http://localhost:2222/${web_base_path}${plain}"
                echo ""
                echo -e "${yellow}Alternative: point a reverse proxy (nginx/Caddy) at 127.0.0.1:${panel_port} and let it terminate TLS.${plain}"
            else
                echo -e "${yellow}Panel will listen on all interfaces over plain HTTP. Make sure something else is terminating TLS in front of it.${plain}"
            fi

            systemctl restart x-ui > /dev/null 2>&1 || rc-service x-ui restart > /dev/null 2>&1
            echo -e "${green}✓ SSL setup skipped.${plain}"
            ;;
        *)
            echo -e "${red}Invalid option. Skipping SSL setup.${plain}"
            SSL_HOST="${server_ip}"
            ;;
    esac
}

# ============================================================================
#  TURNKEY REVERSE PROXY (install mode A) — validated end-to-end 2026-06-10.
#  Runs AFTER the panel is installed + started. Args: user pass port basePath.
#  Pipeline: prompt 3 domains -> LE certs (HTTP-01) -> nginx (3 SNI vhosts on a
#  unix socket) -> decoy -> panel API preconfig (domains + Reality inbound with
#  externalProxy=selfsteal) -> restart. Single port 443, no ports in URLs.
# ============================================================================
rp_resolve_ip() {
    getent hosts "$1" 2> /dev/null | awk '{print $1}' | head -1
}

setup_reverse_proxy() {
    local RP_USER="$1" RP_PASS="$2" RP_PORT="$3" RP_BP="$4"
    local SUB_PORT=2096 SOCK=/dev/shm/xui.sock SSLDIR=/etc/x-ui/ssl

    echo
    local server_ip
    server_ip=$(curl -s4 --max-time 5 https://api.ipify.org)

    # --- domains (asked explicitly, validated, must resolve here & be unique) ---
    local PANEL_DOMAIN SUB_DOMAIN SELFSTEAL_DOMAIN
    _ask_domain() {
        local prompt="$1" __var="$2" d ip
        while :; do
            read -rp " $(askp "$prompt") " d
            d="${d// /}"; d="${d#http://}"; d="${d#https://}"; d="${d%%/*}"
            if ! is_domain "$d"; then echo -e "  ${red}Invalid domain.${plain}"; continue; fi
            ip=$(rp_resolve_ip "$d")
            if [[ -n "$server_ip" && "$ip" != "$server_ip" ]]; then
                echo -e "  ${yellow}!${plain} $(printf "$(t p_resolve)" "$d" "${ip:-—}" "$server_ip")"
                read -rp "    $(askp "$(t p_continue)") " yn; [[ "$yn" =~ ^[Yy]$ ]] || continue
            fi
            printf -v "$__var" '%s' "$d"; break
        done
    }
    _ask_domain "$(t p_dom_panel)" PANEL_DOMAIN
    _ask_domain "$(t p_dom_sub)" SUB_DOMAIN
    _ask_domain "$(t p_dom_self)" SELFSTEAL_DOMAIN
    if [[ "$PANEL_DOMAIN" == "$SUB_DOMAIN" || "$PANEL_DOMAIN" == "$SELFSTEAL_DOMAIN" || "$SUB_DOMAIN" == "$SELFSTEAL_DOMAIN" ]]; then
        echo -e "  ${red}$(t p_uniq)${plain}"; return 1
    fi
    local ACME_EMAIL
    read -rp " $(askp "$(t p_email)") " ACME_EMAIL
    ACME_EMAIL="${ACME_EMAIL:-admin@${PANEL_DOMAIN#*.}}"

    # --- access style: classic webBasePath vs clean-domain cookie-gate ---
    echo
    echo -e "  ${bold}$(t p_access)${plain}"
    echo -e "     ${orange} 1${plain}  $(t p_access1)"
    echo -e "     ${orange} 2${plain}  $(t p_access2)"
    local style; read -rp " $(askp "$(t p_choose)") " style; style="${style:-1}"
    local COOKIE_KEY="" COOKIE_VAL="" PANEL_PATH="/${RP_BP}/"
    if [[ "$style" == "2" ]]; then
        COOKIE_KEY=$(gen_random_string 12); COOKIE_VAL=$(gen_random_string 24); PANEL_PATH="/"
    fi

    # --- certificates (acme.sh, HTTP-01 standalone, ECDSA) ---
    if [[ ! -f ~/.acme.sh/acme.sh ]]; then
        run_step "$(t i_acme)" bash -c "curl -s https://get.acme.sh | sh -s email=${ACME_EMAIL}" || return 1
    fi
    local ACME=~/.acme.sh/acme.sh
    "$ACME" --set-default-ca --server letsencrypt > /dev/null 2>&1
    local d
    for d in "$PANEL_DOMAIN" "$SUB_DOMAIN" "$SELFSTEAL_DOMAIN"; do
        # acme --issue exit codes: 0 = issued, 2 = already valid (skipped) —
        # both fine; only a real failure (DNS/:80) should abort. Then always
        # (re)install the cert to our paths.
        run_step "$(printf "$(t i_cert)" "$d")" bash -c \
            "$ACME --issue -d '$d' --standalone --httpport 80 --keylength ec-256; rc=\$?; \
             [ \$rc -eq 0 ] || [ \$rc -eq 2 ] || exit 1; \
             mkdir -p '$SSLDIR/$d'; \
             $ACME --install-cert -d '$d' --ecc --key-file '$SSLDIR/$d/privkey.pem' \
                   --fullchain-file '$SSLDIR/$d/fullchain.pem' --reloadcmd 'systemctl reload nginx 2>/dev/null || true'" \
            || { echo -e "  ${red}$(printf "$(t i_cert_fail)" "$d")${plain}"; return 1; }
    done
    # acme.sh installs a renewal cron on setup; assert it explicitly so certs
    # keep auto-renewing unattended (nginx reload via each cert's reloadcmd,
    # hysteria re-reads its cert from disk — oneTimeLoading:false). x-ui's
    # ensure_cert_cron re-verifies this policy on every interactive launch.
    "$ACME" --install-cronjob > /dev/null 2>&1 || true

    # --- nginx + decoy + branded error pages ---
    run_step "$(t i_nginx)" bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y -q nginx jq" || return 1
    mkdir -p /etc/x-ui/errorpages "/var/www/$SELFSTEAL_DOMAIN"
    cat > /etc/x-ui/errorpages/__xui_4xx.html <<'H'
<!doctype html><meta charset=utf-8><title>Not found</title><style>body{font:16px system-ui;background:#0b0c10;color:#cfd3dc;display:grid;place-items:center;height:100vh;margin:0}</style><div style=opacity:.6>404</div>
H
    cp /etc/x-ui/errorpages/__xui_4xx.html /etc/x-ui/errorpages/__xui_5xx.html
    [[ -f "/var/www/$SELFSTEAL_DOMAIN/index.html" ]] || cat > "/var/www/$SELFSTEAL_DOMAIN/index.html" <<'H'
<!doctype html><meta charset=utf-8><title>Welcome</title><style>body{font:16px system-ui;background:#f6f7f9;color:#222;display:grid;place-items:center;height:100vh;margin:0}</style><h1>It works.</h1>
H
    _render_nginx "$PANEL_DOMAIN" "$SUB_DOMAIN" "$SELFSTEAL_DOMAIN" "$RP_PORT" "$SUB_PORT" "$SOCK" "$SSLDIR" "$PANEL_PATH" "$COOKIE_KEY" "$COOKIE_VAL"
    rm -f /etc/nginx/sites-enabled/default
    if ! nginx -t > /tmp/nginxt.log 2>&1; then echo -e "  ${red}$(t i_nginxtest)${plain}"; tail -3 /tmp/nginxt.log; return 1; fi
    run_step "$(t i_startnginx)" systemctl restart nginx || return 1

    # --- panel API preconfig (validated sequence) ---
    _rp_preconfig "$RP_USER" "$RP_PASS" "$RP_PORT" "$RP_BP" "$PANEL_DOMAIN" "$SUB_DOMAIN" "$SELFSTEAL_DOMAIN" "$SUB_PORT" "$SOCK" "$PANEL_PATH" || return 1

    # Marker for x-ui's cert-cron self-check (ensure_cert_cron). Records the
    # turnkey domains + ssl dir so the CLI can detect an absent/altered renewal
    # policy and repair it (reinstall the acme cron + re-assert the per-domain
    # nginx reloadcmd). Plain KEY=VALUE, safe to `source`.
    cat > /etc/x-ui/reverse-proxy.conf <<MARK
PANEL_DOMAIN=$PANEL_DOMAIN
SUB_DOMAIN=$SUB_DOMAIN
SELFSTEAL_DOMAIN=$SELFSTEAL_DOMAIN
SSLDIR=$SSLDIR
MARK

    # --- summary (accented so the key outputs don't get lost) ---
    local rule="────────────────────────────────────────────────────────"
    echo
    echo -e "  ${green}${rule}${plain}"
    echo -e "  ${bold}${green}✔  $(t s_ready)${plain}"
    echo -e "  ${green}${rule}${plain}"
    echo
    if [[ "$style" == "2" ]]; then
        echo -e "  ${bold}${yellow}▶${plain} ${gray}$(t s_panel)${plain} ${bold}${green}https://${PANEL_DOMAIN}/?${COOKIE_KEY}=${COOKIE_VAL}${plain}"
        echo -e "    ${bold}${yellow}↳ $(t s_entry)${plain}"
    else
        echo -e "  ${bold}${yellow}▶${plain} ${gray}$(t s_panel)${plain} ${bold}${green}https://${PANEL_DOMAIN}/${RP_BP}/${plain}"
    fi
    echo -e "  ${gray}$(t s_sub)${plain} ${green}https://${SUB_DOMAIN}/<subId>${plain}"
    echo -e "  ${gray}$(t s_decoy)${plain} ${green}https://${SELFSTEAL_DOMAIN}/${plain}"
    echo
    echo -e "  ${bold}${yellow}▶ $(t s_login)${plain}  ${bold}${green}${RP_USER}${plain} ${gray}/${plain} ${bold}${green}${RP_PASS}${plain}"
    echo
    echo -e "  ${green}${rule}${plain}"
    echo
}

# render /etc/nginx/conf.d/xui.conf
_render_nginx() {
    local P="$1" S="$2" D="$3" WP="$4" SP="$5" SOCK="$6" SSL="$7" BP="$8" CK="$9" CV="${10}"
    local gate_map="" gate_block=""
    if [[ -n "$CK" ]]; then
        gate_map="
map \$http_cookie \$xui_ok { default 0; \"~*${CK}=${CV}\" 1; }
map \$arg_${CK} \$xui_q { default 0; \"${CV}\" 1; }
map \"\$xui_ok\$xui_q\" \$xui_auth { \"00\" 0; default 1; }
map \$arg_${CK} \$xui_setck { \"${CV}\" \"${CK}=${CV}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=31536000\"; default \"\"; }
"
        gate_block="    add_header Set-Cookie \$xui_setck;
    if (\$xui_auth = 0) { return 404; }"
    fi
    cat > /etc/nginx/conf.d/xui.conf <<EOF
set_real_ip_from 127.0.0.1;
set_real_ip_from unix:;
real_ip_header proxy_protocol;
${gate_map}
upstream xui_panel { server 127.0.0.1:${WP}; keepalive 16; }
upstream xui_sub   { server 127.0.0.1:${SP}; keepalive 16; }

server {
    listen unix:${SOCK} ssl proxy_protocol;
    server_name ${P};
    ssl_certificate ${SSL}/${P}/fullchain.pem;
    ssl_certificate_key ${SSL}/${P}/privkey.pem;
    error_page 400 401 403 404 405 429 /__xui_4xx.html;
    error_page 500 502 503 504 /__xui_5xx.html;
    location = /__xui_4xx.html { root /etc/x-ui/errorpages; internal; }
    location = /__xui_5xx.html { root /etc/x-ui/errorpages; internal; }
${gate_block}
    location ${BP}ws {
        proxy_pass http://xui_panel; proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host; proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Real-IP \$remote_addr; proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout 3600s;
    }
    location / {
        proxy_pass http://xui_panel;
        proxy_set_header Host \$host; proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
server {
    listen unix:${SOCK} ssl proxy_protocol;
    server_name ${S};
    ssl_certificate ${SSL}/${S}/fullchain.pem;
    ssl_certificate_key ${SSL}/${S}/privkey.pem;
    location / {
        proxy_pass http://xui_sub;
        proxy_set_header Host \$host; proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-Proto https;
    }
}
server {
    listen unix:${SOCK} ssl proxy_protocol;
    server_name ${D};
    ssl_certificate ${SSL}/${D}/fullchain.pem;
    ssl_certificate_key ${SSL}/${D}/privkey.pem;
    root /var/www/${D}; index index.html;
}
server {
    listen unix:${SOCK} ssl proxy_protocol default_server;
    server_name _;
    ssl_certificate ${SSL}/${D}/fullchain.pem;
    ssl_certificate_key ${SSL}/${D}/privkey.pem;
    return 444;
}
EOF
}

# panel API preconfig: domains + Reality inbound (externalProxy=selfsteal)
_rp_preconfig() {
    local U="$1" P="$2" PORT="$3" BP="$4" PD="$5" SD="$6" SS="$7" SP="$8" SOCK="$9" PANELPATH="${10}"
    local BASE="http://127.0.0.1:${PORT}/${BP}" JAR; JAR=$(mktemp)
    # Log in — retry to ride out a slow-starting panel (csrf/login race).
    local CSRF ok i
    for i in $(seq 1 20); do
        CSRF=$(curl -s -c "$JAR" "$BASE/csrf-token" | jq -r '.obj // empty')
        if [[ -n "$CSRF" ]]; then
            ok=$(curl -s -c "$JAR" -b "$JAR" -H "X-CSRF-Token: $CSRF" -H 'Content-Type: application/json' \
                -d "{\"username\":\"$U\",\"password\":\"$P\"}" "$BASE/login" | jq -r '.success // empty')
            [[ "$ok" == "true" ]] && break
        fi
        sleep 0.5
    done
    [[ "$ok" == "true" ]] || { echo -e "  ${red}Panel API login failed (panel not ready at ${BASE}).${plain}"; rm -f "$JAR"; return 1; }
    api() { curl -s -c "$JAR" -b "$JAR" -H "X-CSRF-Token: $CSRF" -H 'Content-Type: application/json' "$@"; }

    local X PRIV PUB UUID SID
    X=$(api "$BASE/panel/api/server/getNewX25519Cert"); PRIV=$(echo "$X"|jq -r '.obj.privateKey'); PUB=$(echo "$X"|jq -r '.obj.publicKey')
    UUID=$(api "$BASE/panel/api/server/getNewUUID"|jq -r '.obj.uuid'); SID=$(openssl rand -hex 8)
    [[ -n "$PRIV" && "$PRIV" != null && -n "$UUID" && "$UUID" != null ]] || { echo -e "  ${red}Key/UUID generation failed.${plain}"; rm -f "$JAR"; return 1; }

    local WBP="$BP"; [[ "$PANELPATH" == "/" ]] && WBP=""
    local ALL NEW
    ALL=$(api "$BASE/panel/setting/all" -X POST)
    # subPath="/" → the normal sub is served at the clean domain root
    # (https://SUB_DOMAIN/<subId>), no /sub/ segment. Each client still has a
    # unique subId, so a bare-domain request (no subId) returns 404 — still
    # probe-safe. Keeps clean-domain URLs symmetric with the panel/decoy.
    #
    # JSON sub: the sub server registers subPath and subJsonPath as TWO distinct
    # Gin route groups — they CANNOT both live at "/" (duplicate-route panic →
    # panel won't start). So subJsonPath stays "/json/". buildSingleURL uses a
    # non-empty subJsonURI VERBATIM + subId (ignoring subJsonPath), so the URI
    # must itself carry the /json/ segment, else the json link collapses onto
    # the normal one. Empty subJsonURI would fall back to base+path and leak the
    # internal :2096 port — so we pin it to the clean host. nginx needs no /json/
    # block: "location /" already proxies /json/<id> to the sub upstream.
    NEW=$(echo "$ALL"|jq -c --arg pd "$PD" --arg sd "$SD" --arg su "https://$SD/" \
        --arg sju "https://$SD/json/" --argjson sp "$SP" --arg wbp "$WBP" \
        '.obj | .webDomain=$pd | .webListen="127.0.0.1" | .webCertFile="" | .webKeyFile=""
              | (if $wbp=="" then .webBasePath="/" else . end)
              | .subEnable=true | .subDomain=$sd | .subListen="127.0.0.1" | .subPort=$sp
              | .subPath="/" | .subURI=$su | .subJsonPath="/json/" | .subJsonURI=$sju
              | .subCertFile="" | .subKeyFile=""')
    [[ "$(api "$BASE/panel/setting/update" -d "$NEW"|jq -r '.success')" == "true" ]] || { echo -e "  ${red}setting/update failed.${plain}"; rm -f "$JAR"; return 1; }

    local IB
    IB=$(jq -n --arg u "$UUID" --arg pv "$PRIV" --arg pb "$PUB" --arg sid "$SID" --arg sni "$SS" --arg sock "$SOCK" '{
      enable:true,remark:"Community Panel VLESS",listen:"",port:443,protocol:"vless",expiryTime:0,total:0,
      settings:{clients:[{id:$u,email:"Community_User",flow:"xtls-rprx-vision",limitIp:0,totalGB:0,expiryTime:0,enable:true,tgId:0,subId:"community_panel_user",comment:"",reset:0}],decryption:"none",encryption:"none",fallbacks:[]},
      streamSettings:{network:"tcp",tcpSettings:{header:{type:"none"}},security:"reality",
        externalProxy:[{forceTls:"same",dest:$sni,port:443,remark:""}],
        realitySettings:{show:false,xver:1,target:$sock,serverNames:[$sni],privateKey:$pv,minClientVer:"",maxClientVer:"",maxTimediff:0,shortIds:[$sid],mldsa65Seed:"",settings:{publicKey:$pb,fingerprint:"firefox",serverName:"",spiderX:"/",mldsa65Verify:""}}},
      sniffing:{enabled:true,destOverride:["http","tls","quic"],metadataOnly:false,routeOnly:false,ipsExcluded:[],domainsExcluded:[]}}')
    [[ "$(api "$BASE/panel/api/inbounds/add" -d "$IB"|jq -r '.success')" == "true" ]] || { echo -e "  ${red}inbound add failed.${plain}"; rm -f "$JAR"; return 1; }

    # Hysteria2 (UDP/27015) — terminates its own TLS with the selfsteal cert (no
    # nginx). SAME email ("Community_User") + subId ("community_panel_user") as the
    # Reality client, so the panel treats it as ONE client spanning both inbounds
    # (two clients with the same subId is rejected by the panel UI; matching the
    # email makes it a single identity). It becomes the 2nd key in that
    # subscription. (Identifiers have no spaces — the panel forbids them.)
    # Port 27015, not 443: UDP/443 gets throttled by DPI (ja4) — 27015 is clean.
    # externalProxy pins the link host:port to the selfsteal domain:27015.
    # Modelled on a known-working Theta inbound (force-brutal QUIC, h3, no obfs).
    local HYAUTH HYPASS; HYAUTH=$(gen_random_string 16); HYPASS=$(gen_random_string 16)
    local HY
    HY=$(jq -n --arg auth "$HYAUTH" --arg pass "$HYPASS" --arg sni "$SS" \
        --arg cert "/etc/x-ui/ssl/$SS/fullchain.pem" --arg key "/etc/x-ui/ssl/$SS/privkey.pem" '{
      enable:true,remark:"Community Panel Hysteria2",listen:"",port:27015,protocol:"hysteria",expiryTime:0,total:0,
      settings:{clients:[{auth:$auth,password:$pass,email:"Community_User",limitIp:0,totalGB:0,expiryTime:0,enable:true,tgId:0,subId:"community_panel_user",comment:"",reset:0}],version:2},
      streamSettings:{network:"hysteria",hysteriaSettings:{version:2,udpIdleTimeout:60},security:"tls",
        externalProxy:[{forceTls:"same",dest:$sni,port:27015,remark:""}],
        tlsSettings:{serverName:$sni,minVersion:"1.3",maxVersion:"1.3",cipherSuites:"",rejectUnknownSni:false,disableSystemRoot:false,enableSessionResumption:false,
          certificates:[{certificateFile:$cert,keyFile:$key,oneTimeLoading:false,usage:"encipherment",buildChain:false,useFile:true}],
          alpn:["h3"],echServerKeys:"",settings:{fingerprint:"chrome",echConfigList:"",pinnedPeerCertSha256:[]}},
        finalmask:{quicParams:{congestion:"force-brutal",brutalUp:"650000000",brutalDown:"850000000",initStreamReceiveWindow:8388608,maxStreamReceiveWindow:8388608,initConnectionReceiveWindow:20971520,maxConnectionReceiveWindow:20971520,keepAlivePeriod:5,maxIncomingStreams:1024}}},
      sniffing:{enabled:true,destOverride:["http","tls","quic"]}}')
    if [[ "$(api "$BASE/panel/api/inbounds/add" -d "$HY"|jq -r '.success')" == "true" ]]; then
        echo -e "  ${green}✔${plain} $(t i_hy2)"
    else
        echo -e "  ${yellow}! Hysteria2 inbound add failed (Reality still works); add it manually if needed.${plain}"
    fi

    api "$BASE/panel/api/server/restartXrayService" -X POST > /dev/null
    api "$BASE/panel/setting/restartPanel" -X POST > /dev/null
    rm -f "$JAR"
    echo -e "  ${green}✔${plain} $(t i_preconfigured)"
    return 0
}

config_after_install() {
    # Turnkey reverse-proxy + cookie-gate is the ONLY install path here. The
    # legacy / IP-access install was removed — it's served by a separate,
    # untouched script. No method prompt; we always run the turnkey path.
    RP_INSTALL_MODE="A"
    if [[ "$RP_INSTALL_MODE" == "A" ]]; then
        # Self-contained, deterministic base config for the turnkey path:
        # fresh creds + FIXED internal port + random basePath. setup_reverse_proxy
        # (after service start) does certs/nginx/decoy/domain-preconfig.
        # Port is FIXED (not random): in mode A the panel binds 127.0.0.1 behind
        # nginx (unix socket) and is never exposed, so randomising it buys no
        # security — but a fixed port makes the nginx upstream deterministic, so
        # a DB backup restored onto a clean reinstall stays reachable without
        # touching the nginx config (clean-domain restore = the whole point).
        RP_U=$(gen_random_string 10); RP_P=$(gen_random_string 10)
        RP_BP=$(gen_random_string 18); RP_PORT=2053
        ${xui_folder}/x-ui setting -username "${RP_U}" -password "${RP_P}" -port "${RP_PORT}" -webBasePath "${RP_BP}" > /dev/null 2>&1
        ${xui_folder}/x-ui migrate
        echo -e "  ${green}✔${plain} $(printf "$(t i_base)" "${RP_PORT}")"
        return 0
    fi

}

install_x-ui() {
    cd ${xui_folder%/x-ui}/

    # Download resources
    if [ $# == 0 ]; then
        # Resolve the latest release tag WITHOUT the GitHub REST API (60 req/h
        # unauthenticated rate limit per IP — easy to hit on shared hosts).
        # github.com/<repo>/releases/latest redirects to .../releases/tag/<tag>;
        # follow it with a HEAD request and read the final URL. No rate limit.
        resolve_latest_tag() {
            curl ${1:-} -fsSLI -o /dev/null -w '%{url_effective}' \
                "https://github.com/jaywehosl/community_panel/releases/latest" 2> /dev/null \
                | grep -oE '/tag/[^/]+$' | sed 's|^/tag/||'
        }
        tag_version=$(resolve_latest_tag)
        if [[ ! -n "$tag_version" ]]; then
            echo -e "${yellow}Trying to fetch version with IPv4...${plain}"
            tag_version=$(resolve_latest_tag -4)
            if [[ ! -n "$tag_version" ]]; then
                echo -e "${red}Failed to resolve the latest x-ui release (no published release yet, or GitHub is unreachable), please try it later${plain}"
                exit 1
            fi
        fi
        echo -e "  ${gray}Community Panel ${tag_version} — installing…${plain}"
        curl -4fsSLRo ${xui_folder}-linux-$(arch).tar.gz https://github.com/jaywehosl/community_panel/releases/download/${tag_version}/x-ui-linux-$(arch).tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Downloading x-ui failed, please be sure that your server can access GitHub ${plain}"
            exit 1
        fi
    else
        tag_version=$1
        tag_version_numeric=${tag_version#v}
        min_version="2.3.5"

        if [[ "$(printf '%s\n' "$min_version" "$tag_version_numeric" | sort -V | head -n1)" != "$min_version" ]]; then
            echo -e "${red}Please use a newer version (at least v2.3.5). Exiting installation.${plain}"
            exit 1
        fi

        url="https://github.com/jaywehosl/community_panel/releases/download/${tag_version}/x-ui-linux-$(arch).tar.gz"
        echo -e "Beginning to install x-ui $1"
        curl -4fsSLRo ${xui_folder}-linux-$(arch).tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Download x-ui $1 failed, please check if the version exists ${plain}"
            exit 1
        fi
    fi
    # Stop x-ui service and remove old resources
    if [[ -e ${xui_folder}/ ]]; then
        if [[ $release == "alpine" ]]; then
            rc-service x-ui stop
        else
            systemctl stop x-ui
        fi
        rm ${xui_folder}/ -rf
    fi

    # Extract resources and set permissions
    tar zxf x-ui-linux-$(arch).tar.gz
    rm x-ui-linux-$(arch).tar.gz -f

    cd x-ui
    chmod +x x-ui
    chmod +x x-ui.sh

    # Check the system's architecture and rename the file accordingly
    if [[ $(arch) == "armv5" || $(arch) == "armv6" || $(arch) == "armv7" ]]; then
        mv bin/xray-linux-$(arch) bin/xray-linux-arm
        chmod +x bin/xray-linux-arm
    fi
    chmod +x x-ui bin/xray-linux-$(arch)

    # Install the x-ui CLI menu. Prefer the copy shipped INSIDE the release
    # tarball so the CLI always matches the installed binary (no skew with the
    # repo's main branch); fall back to the raw file pinned to the SAME tag.
    if [ -f "x-ui.sh" ]; then
        cp -f x-ui.sh /usr/bin/x-ui
    else
        echo -e "${yellow}x-ui.sh not found in the tarball, downloading the ${tag_version} copy...${plain}"
        curl -4fLRo /usr/bin/x-ui "https://raw.githubusercontent.com/jaywehosl/community_panel/refs/tags/${tag_version}/x-ui.sh"
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Failed to download x-ui.sh${plain}"
            exit 1
        fi
    fi
    chmod +x /usr/bin/x-ui
    mkdir -p /var/log/x-ui
    config_after_install

    # Etckeeper compatibility
    if [ -d "/etc/.git" ]; then
        if [ -f "/etc/.gitignore" ]; then
            if ! grep -q "x-ui/x-ui.db" "/etc/.gitignore"; then
                echo "" >> "/etc/.gitignore"
                echo "x-ui/x-ui.db" >> "/etc/.gitignore"
                echo -e "${green}Added x-ui.db to /etc/.gitignore for etckeeper${plain}"
            fi
        else
            echo "x-ui/x-ui.db" > "/etc/.gitignore"
            echo -e "${green}Created /etc/.gitignore and added x-ui.db for etckeeper${plain}"
        fi
    fi

    if [[ $release == "alpine" ]]; then
        curl -4fLRo /etc/init.d/x-ui https://raw.githubusercontent.com/jaywehosl/community_panel/refs/tags/${tag_version}/x-ui.rc
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Failed to download x-ui.rc${plain}"
            exit 1
        fi
        chmod +x /etc/init.d/x-ui
        rc-update add x-ui
        rc-service x-ui start
    else
        # Install systemd service file
        service_installed=false

        if [ -f "x-ui.service" ]; then
            echo -e "${green}Found x-ui.service in extracted files, installing...${plain}"
            cp -f x-ui.service ${xui_service}/ > /dev/null 2>&1
            if [[ $? -eq 0 ]]; then
                service_installed=true
            fi
        fi

        if [ "$service_installed" = false ]; then
            case "${release}" in
                ubuntu | debian | armbian)
                    if [ -f "x-ui.service.debian" ]; then
                        echo -e "${green}Found x-ui.service.debian in extracted files, installing...${plain}"
                        cp -f x-ui.service.debian ${xui_service}/x-ui.service > /dev/null 2>&1
                        if [[ $? -eq 0 ]]; then
                            service_installed=true
                        fi
                    fi
                    ;;
                arch | manjaro | parch)
                    if [ -f "x-ui.service.arch" ]; then
                        echo -e "${green}Found x-ui.service.arch in extracted files, installing...${plain}"
                        cp -f x-ui.service.arch ${xui_service}/x-ui.service > /dev/null 2>&1
                        if [[ $? -eq 0 ]]; then
                            service_installed=true
                        fi
                    fi
                    ;;
                *)
                    if [ -f "x-ui.service.rhel" ]; then
                        echo -e "${green}Found x-ui.service.rhel in extracted files, installing...${plain}"
                        cp -f x-ui.service.rhel ${xui_service}/x-ui.service > /dev/null 2>&1
                        if [[ $? -eq 0 ]]; then
                            service_installed=true
                        fi
                    fi
                    ;;
            esac
        fi

        # If service file not found in tar.gz, download from GitHub
        if [ "$service_installed" = false ]; then
            echo -e "${yellow}Service files not found in tar.gz, downloading from GitHub...${plain}"
            case "${release}" in
                ubuntu | debian | armbian)
                    curl -4fLRo ${xui_service}/x-ui.service https://raw.githubusercontent.com/jaywehosl/community_panel/refs/tags/${tag_version}/x-ui.service.debian > /dev/null 2>&1
                    ;;
                arch | manjaro | parch)
                    curl -4fLRo ${xui_service}/x-ui.service https://raw.githubusercontent.com/jaywehosl/community_panel/refs/tags/${tag_version}/x-ui.service.arch > /dev/null 2>&1
                    ;;
                *)
                    curl -4fLRo ${xui_service}/x-ui.service https://raw.githubusercontent.com/jaywehosl/community_panel/refs/tags/${tag_version}/x-ui.service.rhel > /dev/null 2>&1
                    ;;
            esac

            if [[ $? -ne 0 ]]; then
                echo -e "${red}Failed to install x-ui.service from GitHub${plain}"
                exit 1
            fi
            service_installed=true
        fi

        if [ "$service_installed" = true ]; then
            chown root:root ${xui_service}/x-ui.service > /dev/null 2>&1
            chmod 644 ${xui_service}/x-ui.service > /dev/null 2>&1
            systemctl daemon-reload > /dev/null 2>&1
            systemctl enable x-ui > /dev/null 2>&1
            systemctl start x-ui > /dev/null 2>&1
            echo -e "  ${green}✔${plain} Setting up service"
        else
            echo -e "  ${red}✗${plain} Failed to install x-ui.service file"
            exit 1
        fi
    fi

    # Mode A: the panel is up now — run the turnkey reverse-proxy pipeline.
    if [[ "$RP_INSTALL_MODE" == "A" ]]; then
        local i
        for i in $(seq 1 30); do
            curl -fsS -o /dev/null "http://127.0.0.1:${RP_PORT}/${RP_BP}/csrf-token" 2> /dev/null && break
            sleep 0.5
        done
        setup_reverse_proxy "$RP_U" "$RP_P" "$RP_PORT" "$RP_BP" \
            || echo -e "${red}$(t s_failed)${plain}"
    fi

    echo -e "${green}✔ $(printf "$(t s_running)" "${tag_version}")${plain}"
    echo
    echo -e "  ${gray}$(t s_cli)${plain}"
    echo -e "    ${blue}x-ui${plain}                    admin management menu"
    echo -e "    ${blue}x-ui start|stop|restart${plain} service control"
    echo -e "    ${blue}x-ui status|settings${plain}    status / current settings"
    echo -e "    ${blue}x-ui log${plain}                panel logs"
    echo -e "    ${blue}x-ui update|uninstall${plain}   update / remove"
    echo
}

# Enable TCP BBR + fq qdisc by default (both install modes). The x-ui menu no
# longer exposes a BBR toggle — it's on out of the box. Idempotent: writes a
# sysctl drop-in and applies it; harmless if the kernel already runs bbr/fq.
enable_bbr_default() {
    local f=/etc/sysctl.d/99-xui-bbr.conf
    grep -q '^net.ipv4.tcp_congestion_control=bbr' "$f" 2>/dev/null && return 0
    printf 'net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\n' > "$f"
    sysctl --system > /dev/null 2>&1 || true
    if [[ "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)" == "bbr" ]]; then
        echo -e "  ${green}✔${plain} $(t i_bbr)"
    fi
}

# Ask the interface language ONCE and persist it to /etc/x-ui/lang (en|ru). Both
# this installer and the x-ui CLI read that flag, so the chosen language sticks.
# Reuses an existing choice on reinstall; defaults to English when non-interactive.
choose_language() {
    local existing=""
    [[ -f /etc/x-ui/lang ]] && existing="$(tr -d '[:space:]' < /etc/x-ui/lang 2>/dev/null)"
    if [[ "$existing" == "en" || "$existing" == "ru" ]]; then
        XUI_LANG="$existing"; return
    fi
    local c=""
    echo
    echo -e "  ${green}Select CLI locale / Выберите язык CLI:${plain}"
    echo -e "    ${green}1${plain}. English"
    echo -e "    ${green}2${plain}. Русский"
    [[ -t 0 ]] && read -rp "  [1-2] (default 1): " c
    case "$c" in 2) XUI_LANG="ru" ;; *) XUI_LANG="en" ;; esac
    mkdir -p /etc/x-ui
    echo "$XUI_LANG" > /etc/x-ui/lang
}

echo -e "  ${gray}Running…${plain}"
choose_language
install_base
enable_bbr_default
install_x-ui $1
