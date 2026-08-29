#!/bin/bash
# ============================================================================
#  MIH 3X-UI Installer
#  Оригинальный 3X-UI + Nginx + Cookie-Gate + Reverse Proxy
#  Версия: 3.0 (2026-08-29)
# ============================================================================

set -e

red='\033[1;31m'
green='\033[1;32m'
yellow='\033[1;33m'
blue='\033[1;34m'
cyan='\033[1;36m'
bold='\033[1m'
plain='\033[0m'

# ── Баннер ──
echo -e "${green}${bold}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║    MIH 3X-UI Installer                                      ║"
echo "║    Оригинальный 3X-UI + Nginx + Cookie-Gate + Reverse Proxy║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${plain}"

# ── Проверка прав ──
if [[ $EUID -ne 0 ]]; then
    echo -e "${red}Error: This script must be run as root!${plain}"
    exit 1
fi

# ── Генерация случайных строк ──
gen_random_string() {
    local length="$1"
    openssl rand -base64 $((length * 2)) 2>/dev/null | tr -dc 'a-zA-Z0-9' | head -c "$length"
}

# ── Запрос доменов ──
echo -e "\n${blue}${bold}Настройка доменов${plain}"
echo -e "${yellow}Убедитесь, что A-записи всех доменов указывают на IP этого сервера${plain}"

while true; do
    read -p "$(echo -e "${cyan}Домен для панели: ${plain}")" PANEL_DOMAIN
    read -p "$(echo -e "${cyan}Домен для подписок: ${plain}")" SUB_DOMAIN
    read -p "$(echo -e "${cyan}Домен для заглушки (selfsteal): ${plain}")" SELFSTEAL_DOMAIN

    if [[ "$PANEL_DOMAIN" == "$SUB_DOMAIN" || "$PANEL_DOMAIN" == "$SELFSTEAL_DOMAIN" || "$SUB_DOMAIN" == "$SELFSTEAL_DOMAIN" ]]; then
        echo -e "${red}Ошибка: Все три домена должны быть разными!${plain}"
        continue
    fi
    break
done

read -p "$(echo -e "${cyan}Email для Let's Encrypt: ${plain}")" ACME_EMAIL
ACME_EMAIL=${ACME_EMAIL:-"admin@${PANEL_DOMAIN#*.}"}

# ── УДАЛЕНИЕ СТАРОГО ──
echo -e "\n${blue}${bold}Очистка старых установок...${plain}"
systemctl stop x-ui nginx 2>/dev/null
systemctl disable x-ui nginx 2>/dev/null
rm -rf /usr/local/x-ui /etc/x-ui /etc/nginx/conf.d/xui.conf /root/.acme.sh /var/www/* /dev/shm/xui.sock /usr/bin/x-ui
echo -e "  ${green}✔${plain} Очистка выполнена"

# ── Установка зависимостей ──
echo -e "\n${blue}${bold}Шаг 1: Установка зависимостей${plain}"
apt-get update -qq
apt-get install -y -qq nginx jq curl socat sqlite3 openssl cron
echo -e "  ${green}✔${plain} Зависимости установлены"

# ── Установка оригинального 3X-UI ──
echo -e "\n${blue}${bold}Шаг 2: Установка оригинального 3X-UI${plain}"
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
sleep 5
echo -e "  ${green}✔${plain} 3X-UI установлен"

# ── Установка acme.sh ──
echo -e "\n${blue}${bold}Шаг 3: Установка acme.sh${plain}"
if ! command -v ~/.acme.sh/acme.sh &> /dev/null; then
    curl -s https://get.acme.sh | sh -s email=${ACME_EMAIL}
fi
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
echo -e "  ${green}✔${plain} acme.sh установлен"

# ── SSL-сертификаты ──
echo -e "\n${blue}${bold}Шаг 4: Выпуск SSL-сертификатов${plain}"
systemctl stop nginx 2>/dev/null || true
SSLDIR="/etc/x-ui/ssl"
mkdir -p "$SSLDIR"

for domain in "$PANEL_DOMAIN" "$SUB_DOMAIN" "$SELFSTEAL_DOMAIN"; do
    echo -e "  ${cyan}Выпуск сертификата для ${domain}...${plain}"
    ~/.acme.sh/acme.sh --issue -d "$domain" --standalone --httpport 80 --keylength ec-256 --force || {
        echo -e "  ${red}Ошибка для ${domain}${plain}"
        exit 1
    }
    mkdir -p "$SSLDIR/$domain"
    ~/.acme.sh/acme.sh --install-cert -d "$domain" --ecc \
        --key-file "$SSLDIR/$domain/privkey.pem" \
        --fullchain-file "$SSLDIR/$domain/fullchain.pem" \
        --reloadcmd "systemctl reload nginx 2>/dev/null || true"
    chmod 600 "$SSLDIR/$domain/privkey.pem"
    chmod 644 "$SSLDIR/$domain/fullchain.pem"
    echo -e "  ${green}✔${plain} Сертификат для ${domain}"
done

systemctl start nginx 2>/dev/null || true

# ── Генерация Cookie-Gate ключей ──
COOKIE_KEY=$(gen_random_string 12)
COOKIE_VAL=$(gen_random_string 24)

# ── Настройка Nginx ──
echo -e "\n${blue}${bold}Шаг 5: Настройка Nginx + Cookie-Gate${plain}"

mkdir -p /etc/x-ui/errorpages
cat > /etc/x-ui/errorpages/__xui_4xx.html <<'HTML'
<!doctype html><meta charset=utf-8><title>Not found</title>
<style>body{font:16px system-ui;background:#0b0c10;color:#cfd3dc;display:grid;place-items:center;height:100vh;margin:0}</style>
<div style=opacity:.6>404</div>
HTML
cp /etc/x-ui/errorpages/__xui_4xx.html /etc/x-ui/errorpages/__xui_5xx.html

mkdir -p "/var/www/$SELFSTEAL_DOMAIN"
cat > "/var/www/$SELFSTEAL_DOMAIN/index.html" <<'HTML'
<!doctype html>
<html>
<head><meta charset=utf-8><title>Welcome</title>
<style>body{font:16px system-ui;background:#f6f7f9;color:#222;display:grid;place-items:center;height:100vh;margin:0}</style>
</head>
<body><h1>It works!</h1></body>
</html>
HTML

cat > /etc/nginx/conf.d/xui.conf <<EOF
set_real_ip_from 127.0.0.1;
set_real_ip_from unix:;
real_ip_header proxy_protocol;

upstream xui_panel { server 127.0.0.1:2053; keepalive 16; }
upstream xui_sub   { server 127.0.0.1:2096; keepalive 16; }

map \$http_cookie \$has_auth_cookie {
    default 0;
    "~*${COOKIE_KEY}=${COOKIE_VAL}" 1;
}
map \$arg_${COOKIE_KEY} \$has_auth_query {
    default 0;
    "${COOKIE_VAL}" 1;
}
map "\$has_auth_cookie\$has_auth_query" \$authorized {
    "00" 0;
    default 1;
}
map \$arg_${COOKIE_KEY} \$set_auth_cookie {
    "${COOKIE_VAL}" "${COOKIE_KEY}=${COOKIE_VAL}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=31536000";
    default "";
}

server {
    listen 443 ssl http2;
    server_name ${PANEL_DOMAIN};
    ssl_certificate ${SSLDIR}/${PANEL_DOMAIN}/fullchain.pem;
    ssl_certificate_key ${SSLDIR}/${PANEL_DOMAIN}/privkey.pem;
    error_page 400 401 403 404 405 429 /__xui_4xx.html;
    error_page 500 502 503 504 /__xui_5xx.html;
    location = /__xui_4xx.html { root /etc/x-ui/errorpages; internal; }
    location = /__xui_5xx.html { root /etc/x-ui/errorpages; internal; }
    add_header Set-Cookie \$set_auth_cookie;
    if (\$authorized = 0) { return 404; }
    location /ws {
        proxy_pass http://xui_panel;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout 3600s;
    }
    location / {
        proxy_pass http://xui_panel;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}

server {
    listen 443 ssl http2;
    server_name ${SUB_DOMAIN};
    ssl_certificate ${SSLDIR}/${SUB_DOMAIN}/fullchain.pem;
    ssl_certificate_key ${SSLDIR}/${SUB_DOMAIN}/privkey.pem;
    location / {
        proxy_pass http://xui_sub;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}

server {
    listen 443 ssl http2;
    server_name ${SELFSTEAL_DOMAIN};
    ssl_certificate ${SSLDIR}/${SELFSTEAL_DOMAIN}/fullchain.pem;
    ssl_certificate_key ${SSLDIR}/${SELFSTEAL_DOMAIN}/privkey.pem;
    root /var/www/${SELFSTEAL_DOMAIN};
    index index.html;
    location / { try_files \$uri \$uri/ =404; }
}

server {
    listen 443 ssl http2 default_server;
    server_name _;
    ssl_certificate ${SSLDIR}/${SELFSTEAL_DOMAIN}/fullchain.pem;
    ssl_certificate_key ${SSLDIR}/${SELFSTEAL_DOMAIN}/privkey.pem;
    return 444;
}
EOF

nginx -t || { echo -e "${red}Ошибка Nginx!${plain}"; exit 1; }
systemctl restart nginx
systemctl enable nginx
echo -e "  ${green}✔${plain} Nginx настроен"

# ── Фаервол ──
echo -e "\n${blue}${bold}Шаг 6: Настройка фаервола${plain}"
if command -v ufw &> /dev/null; then
    ufw allow 443/tcp
    ufw allow 27015/udp
    ufw allow 80/tcp
    echo -e "  ${green}✔${plain} Фаервол настроен (UFW)"
else
    echo -e "  ${yellow}⚠${plain} Откройте порты вручную: 443/tcp, 27015/udp, 80/tcp"
fi

# ── Установка логина/пароля ──
echo -e "\n${blue}${bold}Шаг 7: Установка логина и пароля${plain}"
cd /usr/local/x-ui
./x-ui setting -username admin -password admin123
echo -e "  ${green}✔${plain} Логин/пароль установлены"

# ── СОЗДАНИЕ ИНБАУНДОВ ──
echo -e "\n${blue}${bold}Шаг 8: Создание инбаундов VLESS Reality + Hysteria2${plain}"

API_TOKEN=$(sqlite3 /usr/local/x-ui/x-ui.db "SELECT value FROM settings WHERE key='apiToken' LIMIT 1;" 2>/dev/null)

if [ -n "$API_TOKEN" ]; then
    echo -e "  ${green}✔${plain} API токен получен, создаём инбаунды..."

    keys=$(curl -s -H "Authorization: Bearer ${API_TOKEN}" -H "Content-Type: application/json" http://127.0.0.1:2053/panel/api/server/getNewX25519Cert)
    priv=$(echo "$keys" | jq -r '.obj.privateKey')
    pub=$(echo "$keys" | jq -r '.obj.publicKey')
    uuid=$(curl -s -H "Authorization: Bearer ${API_TOKEN}" -H "Content-Type: application/json" http://127.0.0.1:2053/panel/api/server/getNewUUID | jq -r '.obj.uuid')
    sid=$(openssl rand -hex 8)

    inbound_json=$(jq -n --arg uuid "$uuid" --arg priv "$priv" --arg pub "$pub" --arg sid "$sid" --arg sni "$SELFSTEAL_DOMAIN" '{
        enable:true,
        remark:"MIH VLESS",
        listen:"",
        port:443,
        protocol:"vless",
        settings: {
            clients: [{id:$uuid, email:"MIH_User", flow:"xtls-rprx-vision", enable:true}],
            decryption:"none"
        },
        streamSettings: {
            network:"tcp",
            security:"reality",
            externalProxy: [{forceTls:"same", dest:$sni, port:443, remark:"Public"}],
            realitySettings: {
                xver:1,
                target:"unix:/dev/shm/xui.sock",
                serverNames:[$sni],
                privateKey:$priv,
                shortIds:[$sid],
                settings: {publicKey:$pub, fingerprint:"firefox"}
            }
        }
    }')

    curl -s -X POST -H "Authorization: Bearer ${API_TOKEN}" -H "Content-Type: application/json" -d "$inbound_json" http://127.0.0.1:2053/panel/api/inbounds/add > /dev/null
    echo -e "  ${green}✔${plain} MIH VLESS создан"

    hysteria_pass=$(openssl rand -hex 16)
    hysteria_json=$(jq -n --arg pass "$hysteria_pass" --arg sni "$SELFSTEAL_DOMAIN" --arg cert "/etc/x-ui/ssl/$SELFSTEAL_DOMAIN/fullchain.pem" --arg key "/etc/x-ui/ssl/$SELFSTEAL_DOMAIN/privkey.pem" '{
        enable:true,
        remark:"MIH Hysteria2",
        listen:"",
        port:27015,
        protocol:"hysteria",
        settings: { clients: [{auth:$pass, password:$pass, email:"MIH_User", enable:true}], version:2 },
        streamSettings: {
            network:"hysteria",
            hysteriaSettings: { version:2, udpIdleTimeout:60 },
            security:"tls",
            externalProxy: [{forceTls:"same", dest:$sni, port:443, remark:"Public"}],
            tlsSettings: {
                serverName:$sni,
                certificates: [{certificateFile:$cert, keyFile:$key, oneTimeLoading:false}],
                alpn: ["h3"]
            }
        }
    }')

    curl -s -X POST -H "Authorization: Bearer ${API_TOKEN}" -H "Content-Type: application/json" -d "$hysteria_json" http://127.0.0.1:2053/panel/api/inbounds/add > /dev/null
    echo -e "  ${green}✔${plain} MIH Hysteria2 создан"

    systemctl restart x-ui
    echo -e "  ${green}✔${plain} Инбаунды успешно созданы!"
else
    echo -e "  ${yellow}⚠${plain} API токен не получен. Создайте инбаунды вручную."
fi

# ── CLI меню ──
cat > /usr/bin/x-ui <<'EOF'
#!/bin/bash
red='\033[1;31m'
green='\033[1;32m'
yellow='\033[1;33m'
plain='\033[0m'

show_menu() {
    clear
    echo "╔════════════════════════════════════════╗"
    echo "║   MIH 3X-UI CLI Manager              ║"
    echo "╠════════════════════════════════════════╣"
    echo "║  1) Запустить панель                  ║"
    echo "║  2) Остановить панель                 ║"
    echo "║  3) Перезапустить панель              ║"
    echo "║  4) Статус панели                     ║"
    echo "║  5) Показать ссылку входа             ║"
    echo "║  0) Выход                             ║"
    echo "╚════════════════════════════════════════╝"
    read -p "Выберите действие: " choice
    case $choice in
        1) systemctl start x-ui ;;
        2) systemctl stop x-ui ;;
        3) systemctl restart x-ui ;;
        4) systemctl status x-ui ;;
        5) 
            if [ -f /etc/x-ui/reverse-proxy.conf ]; then
                source /etc/x-ui/reverse-proxy.conf
                echo -e "${green}Ссылка: https://${PANEL_DOMAIN}/?${COOKIE_KEY}=${COOKIE_VAL}${plain}"
            fi
            ;;
        0) exit 0 ;;
        *) echo -e "${red}Неверный выбор${plain}" ;;
    esac
}
case "$1" in
    start|stop|restart|status) systemctl "$1" x-ui ;;
    link)
        if [ -f /etc/x-ui/reverse-proxy.conf ]; then
            source /etc/x-ui/reverse-proxy.conf
            echo -e "${green}https://${PANEL_DOMAIN}/?${COOKIE_KEY}=${COOKIE_VAL}${plain}"
        fi
        ;;
    *) show_menu ;;
esac
EOF
chmod +x /usr/bin/x-ui

# ── Финальный вывод ──
cat > /etc/x-ui/reverse-proxy.conf <<VARS
PANEL_DOMAIN="${PANEL_DOMAIN}"
SUB_DOMAIN="${SUB_DOMAIN}"
SELFSTEAL_DOMAIN="${SELFSTEAL_DOMAIN}"
COOKIE_KEY="${COOKIE_KEY}"
COOKIE_VAL="${COOKIE_VAL}"
VARS

echo -e "\n${green}${bold}════════════════════════════════════════════════════════════════${plain}"
echo -e "${green}${bold}  ✅ УСТАНОВКА ЗАВЕРШЕНА!${plain}"
echo -e "${green}${bold}════════════════════════════════════════════════════════════════${plain}"

echo -e "\n${bold}🔗 ССЫЛКА ДЛЯ ВХОДА (СОХРАНИТЕ!):${plain}"
echo -e "${green}https://${PANEL_DOMAIN}/?${COOKIE_KEY}=${COOKIE_VAL}${plain}"
echo -e "${yellow}⚠️ Без неё вход невозможен!${plain}"

echo -e "\n${bold}🔑 ЛОГИН / ПАРОЛЬ:${plain}"
echo -e "  ${green}admin${plain} / ${green}admin123${plain}"

echo -e "\n${bold}📋 ИНБАУНДЫ (уже созданы):${plain}"
echo -e "  ${green}MIH VLESS${plain}     — порт ${green}443${plain} (Reality)"
echo -e "  ${green}MIH Hysteria2${plain}  — порт ${green}27015${plain} (Hysteria2)"

echo -e "\n${green}${bold}════════════════════════════════════════════════════════════════${plain}"
