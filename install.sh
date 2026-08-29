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

# ── Localization ──────────────────────────────────────────────────────────────
XUI_LANG="en"
[[ -f /etc/x-ui/lang ]] && XUI_LANG="$(tr -d '[:space:]' < /etc/x-ui/lang 2>/dev/null)"
[[ "$XUI_LANG" == "ru" ]] || XUI_LANG="en"
declare -A T_EN T_RU
t() { local k="$1" v=""; [[ "$XUI_LANG" == "ru" ]] && v="${T_RU[$k]}"; printf '%s' "${v:-${T_EN[$k]}}"; }
askp() { echo -e "${bold}${orange}$*${plain}"; }

# ── Translations ─────────────────────────────────────────────────────────────
T_EN[i_deps]="Installing dependencies";                  T_RU[i_deps]="Установка зависимостей"
T_EN[i_bbr]="BBR enabled";                               T_RU[i_bbr]="BBR включен"
T_EN[i_base]="3x-ui v3.7.0 configured on port %s; reverse-proxy will run after start"; T_RU[i_base]="3x-ui v3.7.0 настроена с портом %s, реверс-прокси запустится после старта"
T_EN[i_acme]="Installing acme.sh";                       T_RU[i_acme]="Установка acme.sh"
T_EN[i_cert]="Issuing certificate for %s";               T_RU[i_cert]="Выпуск сертификата для %s"
T_EN[i_cert_fail]="Certificate issue failed for %s";     T_RU[i_cert_fail]="Ошибка выпуска сертификата для %s"
T_EN[i_nginx]="Installing Nginx + JQ";                   T_RU[i_nginx]="Установка Nginx + JQ"
T_EN[i_startnginx]="Starting Nginx";                     T_RU[i_startnginx]="Запуск Nginx"
T_EN[i_nginxtest]="Nginx config test failed:";           T_RU[i_nginxtest]="Ошибка проверки конфига Nginx:"
T_EN[i_hy2]="Hysteria2 preconfigured inbound added";     T_RU[i_hy2]="Добавлен преднастроенный инбаунд Hysteria2"
T_EN[i_preconfigured]="3x-ui v3.7.0 successfully installed"; T_RU[i_preconfigured]="3x-ui v3.7.0 успешно установлена"
T_EN[p_dom_panel]="3x-ui domain:";                       T_RU[p_dom_panel]="Домен для 3x-ui:"
T_EN[p_dom_sub]="Subscription page domain:";             T_RU[p_dom_sub]="Домен для подписок:"
T_EN[p_dom_self]="Selfsteal/Reality domain:";            T_RU[p_dom_self]="Домен для сайта-заглушки:"
T_EN[p_resolve]="%s resolves to %s, not server %s.";     T_RU[p_resolve]="A-запись %s ведет к %s, а не к IP сервера %s."
T_EN[p_continue]="Continue anyway? [y/N]:";              T_RU[p_continue]="Продолжить? [y/N]:"
T_EN[p_uniq]="3x-ui, Subscription and Selfsteal domains must be unique. Aborting."; T_RU[p_uniq]="Домены для 3x-ui, подписок и заглушки должны быть разными. Отмена."
T_EN[p_email]="Enter your email for Let's Encrypt:";     T_RU[p_email]="Введите email для Let's Encrypt:"
T_EN[p_access]="Select 3x-ui access method:";            T_RU[p_access]="Выберите способ доступа к 3x-ui:"
T_EN[p_access1]="Secret webBasePath";                    T_RU[p_access1]="Secret webBasePath"
T_EN[p_access2]="Cookie-gate auth (Recommended)";        T_RU[p_access2]="Cookie-gate авторизация (рекомендуется)"
T_EN[p_choose]="Choose method:";                         T_RU[p_choose]="Выберите метод:"
T_EN[s_ready]="3x-ui is ready!";                         T_RU[s_ready]="3x-ui готова!"
T_EN[s_panel]="Panel access link:";                      T_RU[s_panel]="Панель доступна по:"
T_EN[s_sub]="Subscription Page access link:";            T_RU[s_sub]="Страница подписок доступна по:"
T_EN[s_decoy]="Selfsteal/Reality access link:";          T_RU[s_decoy]="Сайт-заглушка доступен по:"
T_EN[s_login]="Your login/password:";                    T_RU[s_login]="Ваш логин/пароль:"
T_EN[s_entry]="secret cookie-gate link — save it!";      T_RU[s_entry]="секретная cookie-gate ссылка - сохраните!"
T_EN[s_failed]="Reverse-proxy setup failed";             T_RU[s_failed]="Ошибка настройки реверс-прокси"
T_EN[s_running]="3x-ui v3.7.0 installed and running";    T_RU[s_running]="3x-ui v3.7.0 установлена и работает"
T_EN[s_cli]="CLI manager commands are:";                 T_RU[s_cli]="Команды для управления:"

# ── quiet-step UI ────────────────────────────────────────────────────────────
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
    local cmd
    case "${release}" in
        ubuntu | debian | armbian)
            cmd='apt-get update && apt-get install -y -q cron curl tar tzdata socat ca-certificates openssl jq'
            ;;
        fedora | amzn | virtuozzo | rhel | almalinux | rocky | ol)
            cmd='dnf install -y -q cronie curl tar tzdata socat ca-certificates openssl jq'
            ;;
        centos)
            if [[ "${VERSION_ID}" =~ ^7 ]]; then
                cmd='yum install -y cronie curl tar tzdata socat ca-certificates openssl jq'
            else
                cmd='dnf install -y -q cronie curl tar tzdata socat ca-certificates openssl jq'
            fi
            ;;
        arch | manjaro | parch)
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

install_acme() {
    echo -e "${green}Installing acme.sh for SSL certificate management...${plain}"
    cd ~ || return 1
    curl -s https://get.acme.sh | sh > /dev/null
    if [ $? -ne 0 ]; then
        echo -e "${red}Failed to install acme.sh${plain}"
        return 1
    else
        echo -e "${green}acme.sh installed successfully${plain}"
    fi
    return 0
}

ssl_cert_issue() {
    local existing_webBasePath=$(${xui_folder}/x-ui setting -show true | grep 'webBasePath:' | awk -F': ' '{print $2}' | tr -d '[:space:]' | sed 's#^/##')
    local existing_port=$(${xui_folder}/x-ui setting -show true | grep 'port:' | awk -F': ' '{print $2}' | tr -d '[:space:]')

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

    local domain=""
    while true; do
        read -rp "Please enter your domain name: " domain
        domain="${domain// /}"

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

    certPath="/root/cert/${domain}"
    if [ ! -d "$certPath" ]; then
        mkdir -p "$certPath"
    else
        rm -rf "$certPath"
        mkdir -p "$certPath"
    fi

    local WebPort=80
    read -rp "Please choose which port to use (default is 80): " WebPort
    if [[ ${WebPort} -gt 65535 || ${WebPort} -lt 1 ]]; then
        echo -e "${yellow}Your input ${WebPort} is invalid, will use default port 80.${plain}"
        WebPort=80
    fi
    echo -e "${green}Will use port: ${WebPort} to issue certificates. Please make sure this port is open.${plain}"

    echo -e "${yellow}Stopping panel temporarily...${plain}"
    systemctl stop x-ui 2> /dev/null || rc-service x-ui stop 2> /dev/null

    if [[ ${cert_exists} -eq 0 ]]; then
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

    ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    if [ $? -ne 0 ]; then
        echo -e "${yellow}Auto renew setup had issues, certificate details:${plain}"
        ls -lah /root/cert/${domain}/
        chmod 600 $certPath/privkey.pem 2> /dev/null
        chmod 644 $certPath/fullchain.pem 2> /dev/null
    else
        echo -e "${green}Auto renew succeeded, certificate details:${plain}"
        ls -lah /root/cert/${domain}/
        chmod 600 $certPath/privkey.pem 2> /dev/null
        chmod 644 $certPath/fullchain.pem 2> /dev/null
    fi

    systemctl start x-ui 2> /dev/null || rc-service x-ui start 2> /dev/null

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

# ============================================================================
# УСТАНОВКА ПОСЛЕДНЕЙ СТАБИЛЬНОЙ ВЕРСИИ (v3.7.0)
# ============================================================================

install_xui_latest() {
    local TAG_VERSION="v3.7.0"
    
    echo -e "  ${gray}Установка 3x-ui ${TAG_VERSION}...${plain}"
    
    # Остановка старой версии
    systemctl stop x-ui 2>/dev/null
    rm -rf ${xui_folder}
    
    # Скачивание версии
    local URL="https://github.com/MHSanaei/3x-ui/releases/download/${TAG_VERSION}/x-ui-linux-$(arch).tar.gz"
    local FILE="/tmp/x-ui-linux-$(arch).tar.gz"
    
    curl -4fsSL -o "$FILE" "$URL"
    if [[ $? -ne 0 ]]; then
        echo -e "${red}Ошибка скачивания версии ${TAG_VERSION}${plain}"
        exit 1
    fi
    
    # Распаковка
    tar zxf "$FILE" -C /usr/local/
    rm -f "$FILE"
    
    cd ${xui_folder} || exit 1
    chmod +x x-ui x-ui.sh
    
    # Установка CLI
    cp -f x-ui.sh /usr/bin/x-ui
    chmod +x /usr/bin/x-ui
    
    # Установка службы
    if [[ -f "x-ui.service.debian" ]]; then
        cp -f x-ui.service.debian ${xui_service}/x-ui.service
    else
        curl -4fsSL -o ${xui_service}/x-ui.service \
            "https://raw.githubusercontent.com/MHSanaei/3x-ui/refs/tags/${TAG_VERSION}/x-ui.service.debian"
    fi
    
    systemctl daemon-reload
    systemctl enable x-ui
    
    echo -e "  ${green}✔ 3x-ui ${TAG_VERSION} установлена${plain}"
}

# ============================================================================
# ИСПРАВЛЕННАЯ ФУНКЦИЯ _rp_preconfig ДЛЯ v3.7.0
# ============================================================================

rp_resolve_ip() {
    getent hosts "$1" 2> /dev/null | awk '{print $1}' | head -1
}

_rp_preconfig() {
    local U="$1" P="$2" PORT="$3" BP="$4" PD="$5" SD="$6" SS="$7" SP="$8" SOCK="$9" PANELPATH="${10}"
    local BASE="http://127.0.0.1:${PORT}/${BP}"
    local API_BASE="${BASE}/panel/api"  # ← НОВЫЙ ПУТЬ ДЛЯ v3.7.0
    local JAR=$(mktemp)
    local CSRF ok i

    echo -e "  ${gray}API: ожидание запуска панели...${plain}"

    # Ожидание запуска панели
    for i in $(seq 1 30); do
        if curl -s -o /dev/null -w "%{http_code}" "${API_BASE}/csrf-token" | grep -q "200"; then
            echo -e "  ${gray}API: панель запущена${plain}"
            break
        fi
        sleep 1
    done

    # Получение CSRF токена через новый API путь
    for i in $(seq 1 10); do
        CSRF=$(curl -s -c "$JAR" "${API_BASE}/csrf-token" | jq -r '.obj // empty')
        if [[ -n "$CSRF" && "$CSRF" != "null" ]]; then
            echo -e "  ${gray}API: CSRF токен получен${plain}"
            break
        fi
        sleep 1
    done

    if [[ -z "$CSRF" || "$CSRF" == "null" ]]; then
        echo -e "  ${red}Не удалось получить CSRF токен${plain}"
        rm -f "$JAR"
        return 1
    fi

    # Логин через новый API путь
    for i in $(seq 1 10); do
        ok=$(curl -s -c "$JAR" -b "$JAR" \
            -H "X-CSRF-Token: $CSRF" \
            -H "Content-Type: application/json" \
            -d "{\"username\":\"$U\",\"password\":\"$P\"}" \
            "${API_BASE}/login" | jq -r '.success // empty')
        if [[ "$ok" == "true" ]]; then
            echo -e "  ${gray}API: авторизация успешна${plain}"
            break
        fi
        sleep 1
    done

    if [[ "$ok" != "true" ]]; then
        echo -e "  ${red}Panel API login failed${plain}"
        rm -f "$JAR"
        return 1
    fi

    api() { 
        curl -s -b "$JAR" -H "X-CSRF-Token: $CSRF" -H "Content-Type: application/json" "$@"
    }

    # Генерация ключей через новый API путь
    local X PRIV PUB UUID SID
    X=$(api "${API_BASE}/server/getNewX25519Cert")
    PRIV=$(echo "$X"|jq -r '.obj.privateKey')
    PUB=$(echo "$X"|jq -r '.obj.publicKey')
    UUID=$(api "${API_BASE}/server/getNewUUID"|jq -r '.obj.uuid')
    SID=$(openssl rand -hex 8)

    [[ -n "$PRIV" && "$PRIV" != null && -n "$UUID" && "$UUID" != null ]] || { 
        echo -e "  ${red}Key/UUID generation failed.${plain}"
        rm -f "$JAR"
        return 1
    }

    # Настройка панели через новый API путь
    local WBP="$BP"
    [[ "$PANELPATH" == "/" ]] && WBP=""

    local ALL NEW
    ALL=$(api "${API_BASE}/setting/all" -X POST)

    NEW=$(echo "$ALL" | jq -c \
        --arg pd "$PD" \
        --arg sd "$SD" \
        --arg su "https://$SD/" \
        --arg sju "https://$SD/json/" \
        --argjson sp "$SP" \
        --arg wbp "$WBP" \
        '.obj | 
         .webDomain = $pd | 
         .webListen = "127.0.0.1" | 
         .webCertFile = "" | 
         .webKeyFile = "" |
         (if $wbp == "" then .webBasePath = "/" else .webBasePath = "/" + $wbp + "/" end) |
         .subEnable = true | 
         .subDomain = $sd | 
         .subListen = "127.0.0.1" | 
         .subPort = $sp |
         .subPath = "/" | 
         .subURI = $su | 
         .subJsonPath = "/json/" | 
         .subJsonURI = $sju |
         .subCertFile = "" | 
         .subKeyFile = ""')

    local UPDATE_RESULT=$(api "${API_BASE}/setting/update" -d "$NEW" | jq -r '.success // empty')

    if [[ "$UPDATE_RESULT" != "true" ]]; then
        echo -e "  ${red}setting/update failed.${plain}"
        rm -f "$JAR"
        return 1
    fi

    # Добавление Reality инбаунда через новый API путь
    local IB
    IB=$(jq -n --arg u "$UUID" --arg pv "$PRIV" --arg pb "$PUB" --arg sid "$SID" --arg sni "$SS" --arg sock "$SOCK" '{
      enable:true,remark:"3x-ui VLESS",listen:"",port:443,protocol:"vless",expiryTime:0,total:0,
      settings:{clients:[{id:$u,email:"3xui_user",flow:"xtls-rprx-vision",limitIp:0,totalGB:0,expiryTime:0,enable:true,tgId:0,subId:"3xui_user",comment:"",reset:0}],decryption:"none",encryption:"none",fallbacks:[]},
      streamSettings:{network:"tcp",tcpSettings:{header:{type:"none"}},security:"reality",
        externalProxy:[{forceTls:"same",dest:$sni,port:443,remark:""}],
        realitySettings:{show:false,xver:1,target:$sock,serverNames:[$sni],privateKey:$pv,minClientVer:"",maxClientVer:"",maxTimediff:0,shortIds:[$sid],settings:{publicKey:$pb,fingerprint:"firefox",serverName:"",spiderX:"/",mldsa65Verify:""}}},
      sniffing:{enabled:true,destOverride:["http","tls","quic"],metadataOnly:false,routeOnly:false,ipsExcluded:[],domainsExcluded:[]}}')

    [[ "$(api "${API_BASE}/inbounds/add" -d "$IB"|jq -r '.success')" == "true" ]] || { 
        echo -e "  ${red}inbound add failed.${plain}"
        rm -f "$JAR"
        return 1
    }

    # Hysteria2 инбаунд через новый API путь
    local HYAUTH HYPASS
    HYAUTH=$(gen_random_string 16)
    HYPASS=$(gen_random_string 16)

    local HY
    HY=$(jq -n --arg auth "$HYAUTH" --arg pass "$HYPASS" --arg sni "$SS" \
        --arg cert "/etc/x-ui/ssl/$SS/fullchain.pem" --arg key "/etc/x-ui/ssl/$SS/privkey.pem" '{
      enable:true,remark:"3x-ui Hysteria2",listen:"",port:27015,protocol:"hysteria",expiryTime:0,total:0,
      settings:{clients:[{auth:$auth,password:$pass,email:"3xui_user",limitIp:0,totalGB:0,expiryTime:0,enable:true,tgId:0,subId:"3xui_user",comment:"",reset:0}],version:2},
      streamSettings:{network:"hysteria",hysteriaSettings:{version:2,udpIdleTimeout:60},security:"tls",
        externalProxy:[{forceTls:"same",dest:$sni,port:27015,remark:""}],
        tlsSettings:{serverName:$sni,minVersion:"1.3",maxVersion:"1.3",cipherSuites:"",rejectUnknownSni:false,disableSystemRoot:false,enableSessionResumption:false,
          certificates:[{certificateFile:$cert,keyFile:$key,oneTimeLoading:false,usage:"encipherment",buildChain:false,useFile:true}],
          alpn:["h3"],echServerKeys:"",settings:{fingerprint:"chrome",echConfigList:"",pinnedPeerCertSha256:[]}},
        finalmask:{quicParams:{congestion:"force-brutal",brutalUp:"650000000",brutalDown:"850000000",initStreamReceiveWindow:8388608,maxStreamReceiveWindow:8388608,initConnectionReceiveWindow:20971520,maxConnectionReceiveWindow:20971520,keepAlivePeriod:5,maxIncomingStreams:1024}}},
      sniffing:{enabled:true,destOverride:["http","tls","quic"]}}')

    if [[ "$(api "${API_BASE}/inbounds/add" -d "$HY"|jq -r '.success')" == "true" ]]; then
        echo -e "  ${green}✔${plain} $(t i_hy2)"
    else
        echo -e "  ${yellow}! Hysteria2 inbound add failed (Reality still works); add it manually if needed.${plain}"
    fi

    # Перезапуск через новый API путь
    api "${API_BASE}/server/restartXrayService" -X POST > /dev/null
    api "${API_BASE}/setting/restartPanel" -X POST > /dev/null

    rm -f "$JAR"
    echo -e "  ${green}✔${plain} $(t i_preconfigured)"
    return 0
}

# ============================================================================
# ОСТАЛЬНЫЕ ФУНКЦИИ (без изменений)
# ============================================================================

setup_reverse_proxy() {
    local RP_USER="$1" RP_PASS="$2" RP_PORT="$3" RP_BP="$4"
    local SUB_PORT=2096 SOCK=/dev/shm/xui.sock SSLDIR=/etc/x-ui/ssl

    echo
    local server_ip
    server_ip=$(curl -s4 --max-time 5 https://api.ipify.org)

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

    echo
    echo -e "  ${bold}$(t p_access)${plain}"
    echo -e "     ${orange} 1${plain}  $(t p_access1)"
    echo -e "     ${orange} 2${plain}  $(t p_access2)"
    local style; read -rp " $(askp "$(t p_choose)") " style; style="${style:-1}"
    local COOKIE_KEY="" COOKIE_VAL="" PANEL_PATH="/${RP_BP}/"
    if [[ "$style" == "2" ]]; then
        COOKIE_KEY=$(gen_random_string 12); COOKIE_VAL=$(gen_random_string 24); PANEL_PATH="/"
    fi

    if [[ ! -f ~/.acme.sh/acme.sh ]]; then
        run_step "$(t i_acme)" bash -c "curl -s https://get.acme.sh | sh -s email=${ACME_EMAIL}" || return 1
    fi
    local ACME=~/.acme.sh/acme.sh
    "$ACME" --set-default-ca --server letsencrypt > /dev/null 2>&1
    local d
    for d in "$PANEL_DOMAIN" "$SUB_DOMAIN" "$SELFSTEAL_DOMAIN"; do
        run_step "$(printf "$(t i_cert)" "$d")" bash -c \
            "$ACME --issue -d '$d' --standalone --httpport 80 --keylength ec-256; rc=\$?; \
             [ \$rc -eq 0 ] || [ \$rc -eq 2 ] || exit 1; \
             mkdir -p '$SSLDIR/$d'; \
             $ACME --install-cert -d '$d' --ecc --key-file '$SSLDIR/$d/privkey.pem' \
                   --fullchain-file '$SSLDIR/$d/fullchain.pem' --reloadcmd 'systemctl reload nginx 2>/dev/null || true'" \
            || { echo -e "  ${red}$(printf "$(t i_cert_fail)" "$d")${plain}"; return 1; }
    done
    "$ACME" --install-cronjob > /dev/null 2>&1 || true

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

    _rp_preconfig "$RP_USER" "$RP_PASS" "$RP_PORT" "$RP_BP" "$PANEL_DOMAIN" "$SUB_DOMAIN" "$SELFSTEAL_DOMAIN" "$SUB_PORT" "$SOCK" "$PANEL_PATH" || return 1

    cat > /etc/x-ui/reverse-proxy.conf <<MARK
PANEL_DOMAIN=$PANEL_DOMAIN
SUB_DOMAIN=$SUB_DOMAIN
SELFSTEAL_DOMAIN=$SELFSTEAL_DOMAIN
SSLDIR=$SSLDIR
MARK

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

config_after_install() {
    RP_INSTALL_MODE="A"
    if [[ "$RP_INSTALL_MODE" == "A" ]]; then
        RP_U=$(gen_random_string 10); RP_P=$(gen_random_string 10)
        RP_BP=$(gen_random_string 18); RP_PORT=2053
        ${xui_folder}/x-ui setting -username "${RP_U}" -password "${RP_P}" -port "${RP_PORT}" -webBasePath "${RP_BP}" > /dev/null 2>&1
        ${xui_folder}/x-ui migrate
        echo -e "  ${green}✔${plain} $(printf "$(t i_base)" "${RP_PORT}")"
        return 0
    fi
}

enable_bbr_default() {
    local f=/etc/sysctl.d/99-xui-bbr.conf
    grep -q '^net.ipv4.tcp_congestion_control=bbr' "$f" 2>/dev/null && return 0
    printf 'net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\n' > "$f"
    sysctl --system > /dev/null 2>&1 || true
    if [[ "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)" == "bbr" ]]; then
        echo -e "  ${green}✔${plain} $(t i_bbr)"
    fi
}

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
install_xui_latest

# Настройка
config_after_install

# Ожидание запуска
sleep 3

# Настройка reverse-proxy
setup_reverse_proxy "$RP_U" "$RP_P" "$RP_PORT" "$RP_BP" \
    || echo -e "${red}$(t s_failed)${plain}"

echo -e "${green}✔ $(printf "$(t s_running)" "v3.7.0")${plain}"
echo
echo -e "  ${gray}$(t s_cli)${plain}"
echo -e "    ${blue}x-ui${plain}                    admin management menu"
echo -e "    ${blue}x-ui start|stop|restart${plain} service control"
echo -e "    ${blue}x-ui status|settings${plain}    status / current settings"
echo -e "    ${blue}x-ui log${plain}                panel logs"
echo -e "    ${blue}x-ui update|uninstall${plain}   update / remove"
echo
