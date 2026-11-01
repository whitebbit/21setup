#!/usr/bin/env bash
# SERVER AUTO SETUP v1.0
# Debian / Ubuntu
# Run as root: bash 21.sh

set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

readonly SCRIPT_VERSION="1.0"
readonly LOG_FILE="/var/log/21-server-setup.log"
readonly GEOIP_URL="https://github.com/Davoyan/ipregion/raw/main/ipregion.sh"

STEP=0
TOTAL_STEPS=10
FAILED_STEPS=0
PASSED_STEPS=0

# ─────────────────────────────────────────────────────────────
# Colors
# ─────────────────────────────────────────────────────────────

if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_CYAN=$'\033[36m'
    C_BOLD=$'\033[1m'
else
    C_RESET=""
    C_RED=""
    C_GREEN=""
    C_YELLOW=""
    C_CYAN=""
    C_BOLD=""
fi

# ─────────────────────────────────────────────────────────────
# Terminal helpers
# ─────────────────────────────────────────────────────────────

terminal_width() {
    local width=80

    if command -v tput >/dev/null 2>&1; then
        width="$(tput cols 2>/dev/null || echo 80)"
    fi

    [[ "$width" =~ ^[0-9]+$ ]] || width=80

    # Keep the banner readable on narrow terminals.
    (( width < 60 )) && width=60

    echo "$width"
}

repeat_char() {
    local char="$1"
    local count="$2"
    local output=""

    for ((i = 0; i < count; i++)); do
        output+="$char"
    done

    printf '%s' "$output"
}

center_text() {
    local text="$1"
    local width="$2"
    local length="${#text}"
    local left=0
    local right=0

    (( length < width )) || {
        printf '%s\n' "$text"
        return
    }

    left=$(( (width - length) / 2 ))
    right=$(( width - length - left ))

    printf '%*s%s%*s\n' "$left" "" "$text" "$right" ""
}

draw_banner() {
    local width
    local inner
    local line

    width="$(terminal_width)"
    inner=$(( width - 2 ))

    local -a logo=(
        "██████╗  ██╗"
        "╚════██╗███║"
        " █████╔╝╚██║"
        "██╔═══╝  ██║"
        "███████╗ ██║"
        "╚══════╝ ╚═╝"
    )

    printf '\n'
    printf '%s╔%s╗%s\n' "$C_CYAN" "$(repeat_char '═' "$inner")" "$C_RESET"

    # Top padding
    printf '%s║%s║%s\n' "$C_CYAN" "$(repeat_char ' ' "$inner")" "$C_RESET"

    for line in "${logo[@]}"; do
        printf '%s║%s║%s\n' \
            "$C_CYAN" \
            "$(printf '%-*s' "$inner" "$(center_text "$line" "$inner")")" \
            "$C_RESET"
    done

    printf '%s║%s║%s\n' "$C_CYAN" "$(repeat_char ' ' "$inner")" "$C_RESET"

    printf '%s║%s║%s\n' \
        "$C_CYAN" \
        "$(printf '%-*s' "$inner" "$(center_text 'SERVER AUTO SETUP' "$inner")")" \
        "$C_RESET"

    printf '%s║%s║%s\n' \
        "$C_CYAN" \
        "$(printf '%-*s' "$inner" "$(center_text "v${SCRIPT_VERSION}" "$inner")")" \
        "$C_RESET"

    printf '%s║%s║%s\n' "$C_CYAN" "$(repeat_char ' ' "$inner")" "$C_RESET"
    printf '%s╚%s╝%s\n\n' "$C_CYAN" "$(repeat_char '═' "$inner")" "$C_RESET"
}

print_info() {
    printf '%s[INFO]%s %s\n' "$C_CYAN" "$C_RESET" "$1"
}

print_warn() {
    printf '%s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$1"
}

print_error() {
    printf '%s[ERROR]%s %s\n' "$C_RED" "$C_RESET" "$1"
}

# ─────────────────────────────────────────────────────────────
# Step runner
# ─────────────────────────────────────────────────────────────

run_step() {
    local description="$1"
    shift

    local show_output=false

    if [[ "${1:-}" == "--show" ]]; then
        show_output=true
        shift
    fi

    STEP=$((STEP + 1))

    printf '%s[%02d/%02d]%s %-48s' \
        "$C_CYAN" "$STEP" "$TOTAL_STEPS" "$C_RESET" "$description"

    if [[ "$show_output" == true ]]; then
        if "$@" 2>>"$LOG_FILE" | tee -a "$LOG_FILE"; then
            PASSED_STEPS=$((PASSED_STEPS + 1))
            printf '%s✓ OK%s\n' "$C_GREEN" "$C_RESET"
        else
            FAILED_STEPS=$((FAILED_STEPS + 1))
            printf '%s✗ FAILED%s\n' "$C_RED" "$C_RESET"
            printf '       Подробности: %s\n' "$LOG_FILE"
        fi
    else
        if "$@" >>"$LOG_FILE" 2>&1; then
            PASSED_STEPS=$((PASSED_STEPS + 1))
            printf '%s✓ OK%s\n' "$C_GREEN" "$C_RESET"
        else
            FAILED_STEPS=$((FAILED_STEPS + 1))
            printf '%s✗ FAILED%s\n' "$C_RED" "$C_RESET"
            printf '       Подробности: %s\n' "$LOG_FILE"
        fi
    fi
}

# ─────────────────────────────────────────────────────────────
# Initial checks
# ─────────────────────────────────────────────────────────────

check_system() {
    if [[ "${EUID}" -ne 0 ]]; then
        print_error "Запусти скрипт от root."
        exit 1
    fi

    if [[ ! -r /etc/os-release ]]; then
        print_error "Не удалось определить операционную систему."
        exit 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release

    case "${ID:-}" in
        debian|ubuntu)
            ;;
        *)
            print_error "Поддерживаются только Debian и Ubuntu."
            print_error "Обнаружено: ${PRETTY_NAME:-unknown}"
            exit 1
            ;;
    esac

    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"

    {
        printf '\n'
        printf '%s\n' "===== SERVER AUTO SETUP v${SCRIPT_VERSION} ====="
        printf 'Started: %s\n' "$(date --iso-8601=seconds)"
        printf 'OS: %s\n' "${PRETTY_NAME:-unknown}"
        printf 'Kernel: %s\n' "$(uname -r)"
        printf '%s\n' "========================================="
    } >>"$LOG_FILE"
}

# ─────────────────────────────────────────────────────────────
# 1. System update and packages
# ─────────────────────────────────────────────────────────────

update_system() {
    apt-get update
    apt-get -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        upgrade

    apt-get install -y \
        curl \
        wget \
        ca-certificates \
        ufw \
        fail2ban \
        iproute2 \
        procps \
        dnsutils \
        systemd
}

# ─────────────────────────────────────────────────────────────
# SSH port detection
# ─────────────────────────────────────────────────────────────

detect_ssh_ports() {
    local ports=()
    local active_port=""
    local configured_ports=""

    # SSH_CONNECTION format:
    # client_ip client_port server_ip server_port
    if [[ -n "${SSH_CONNECTION:-}" ]]; then
        active_port="$(awk '{print $4}' <<<"$SSH_CONNECTION")"

        if [[ "$active_port" =~ ^[0-9]+$ ]]; then
            ports+=("$active_port")
        fi
    fi

    if command -v sshd >/dev/null 2>&1; then
        configured_ports="$(sshd -T 2>/dev/null | awk '$1 == "port" {print $2}' || true)"

        while read -r port; do
            [[ "$port" =~ ^[0-9]+$ ]] && ports+=("$port")
        done <<<"$configured_ports"
    fi

    # Always preserve the standard SSH port as a fallback.
    ports+=(22)

    # Remove duplicates and sort.
    printf '%s\n' "${ports[@]}" | awk 'NF && !seen[$0]++' | sort -n
}

# ─────────────────────────────────────────────────────────────
# 2. UFW firewall
# ─────────────────────────────────────────────────────────────

configure_ufw() {
    local port

    mapfile -t SSH_PORTS < <(detect_ssh_ports)

    ufw default deny incoming
    ufw default allow outgoing

    # SSH ports detected from the active session and sshd config.
    for port in "${SSH_PORTS[@]}"; do
        ufw allow "${port}/tcp"
    done

    # Required ports.
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 443/udp
    ufw allow 8443/tcp
    ufw allow 8443/udp
    ufw allow 10000:60000/tcp
    ufw allow 10000:60000/udp

    ufw --force enable
    ufw reload
}

# ─────────────────────────────────────────────────────────────
# 3. TCP tuning and BBR
# ─────────────────────────────────────────────────────────────

configure_tcp() {
    local bbr_available=""

    modprobe tcp_bbr 2>/dev/null || true

    bbr_available="$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || true)"

    cat >/etc/sysctl.d/99-21-network.conf <<'EOF'
# TCP queue tuning
net.core.somaxconn = 4096
net.core.netdev_max_backlog = 4096
net.ipv4.tcp_max_syn_backlog = 4096

# TCP keepalive
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5

# Memory behavior
vm.swappiness = 10
EOF

    if grep -qw "bbr" <<<"$bbr_available"; then
        cat >>/etc/sysctl.d/99-21-network.conf <<'EOF'

# TCP congestion control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
    else
        printf 'BBR is not available in this kernel; skipped.\n' >>"$LOG_FILE"
    fi

    sysctl --system

    if grep -qw "bbr" <<<"$bbr_available"; then
        local current_cc
        current_cc="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || true)"

        if [[ "$current_cc" != "bbr" ]]; then
            printf 'Warning: BBR was configured but is not active.\n' >>"$LOG_FILE"
        fi

        # Persist module loading.
        printf '%s\n' "tcp_bbr" >/etc/modules-load.d/21-bbr.conf
    fi
}

# ─────────────────────────────────────────────────────────────
# 4. IPv6 disable
# ─────────────────────────────────────────────────────────────

disable_ipv6() {
    cat >/etc/sysctl.d/99-21-ipv6.conf <<'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

    sysctl --system

    if [[ -f /etc/default/ufw ]]; then
        if grep -q '^IPV6=' /etc/default/ufw; then
            sed -i 's/^IPV6=.*/IPV6=no/' /etc/default/ufw
        else
            printf '\nIPV6=no\n' >>/etc/default/ufw
        fi
    fi

    ufw reload
}

# ─────────────────────────────────────────────────────────────
# 5. Block incoming ICMP echo requests
# ─────────────────────────────────────────────────────────────

block_icmp_echo() {
    local file
    local pattern

    for file in /etc/ufw/before.rules /etc/ufw/before6.rules; do
        [[ -f "$file" ]] || continue

        # Keep the original file only once.
        if [[ ! -f "${file}.backup-21" ]]; then
            cp -a "$file" "${file}.backup-21"
        fi

        if [[ "$file" == *before6.rules ]]; then
            pattern='s/(--icmpv6-type[[:space:]]+echo-request[[:space:]]+-j[[:space:]]+)ACCEPT/\1DROP/'
        else
            pattern='s/(--icmp-type[[:space:]]+echo-request[[:space:]]+-j[[:space:]]+)ACCEPT/\1DROP/'
        fi

        sed -E -i "$pattern" "$file"
    done

    ufw reload
}

# ─────────────────────────────────────────────────────────────
# 6. Fail2ban
# ─────────────────────────────────────────────────────────────

configure_fail2ban() {
    local ports
    local action="iptables-multiport"

    mapfile -t SSH_PORTS < <(detect_ssh_ports)
    ports="$(IFS=,; echo "${SSH_PORTS[*]}")"

    if [[ -f /etc/fail2ban/action.d/ufw.conf ]]; then
        action="ufw"
    fi

    cat >/etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 7d
findtime = 3m
maxretry = 3
backend = systemd
banaction = ${action}
allowipv6 = auto
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
mode = aggressive
port = ${ports}
EOF

    systemctl enable --now fail2ban
    fail2ban-client reload
}

# ─────────────────────────────────────────────────────────────
# 7. DNS diagnostics — no resolver config changes
# ─────────────────────────────────────────────────────────────

check_dns() {
    printf '%s\n' "DNS resolver configuration:" >>"$LOG_FILE"

    if [[ -f /etc/resolv.conf ]]; then
        cat /etc/resolv.conf >>"$LOG_FILE"
    fi

    printf '\n%s\n' "DNS lookup test:" >>"$LOG_FILE"

    if getent hosts github.com >>"$LOG_FILE" 2>&1; then
        printf 'DNS lookup succeeded.\n' >>"$LOG_FILE"
    else
        printf 'DNS lookup failed.\n' >>"$LOG_FILE"
    fi
}

# ─────────────────────────────────────────────────────────────
# 8. Time synchronization
# ─────────────────────────────────────────────────────────────

configure_time_sync() {
    if command -v timedatectl >/dev/null 2>&1; then
        timedatectl set-ntp true || true
    fi

    if systemctl list-unit-files systemd-timesyncd.service 2>/dev/null \
        | grep -q 'systemd-timesyncd.service'; then

        systemctl unmask systemd-timesyncd.service || true
        systemctl enable --now systemd-timesyncd.service || true

    elif command -v chronyd >/dev/null 2>&1; then
        systemctl enable --now chrony || systemctl enable --now chronyd || true

    else
        apt-get install -y chrony
        systemctl enable --now chrony
    fi

    timedatectl status 2>/dev/null || true
}

# ─────────────────────────────────────────────────────────────
# 9. GeoIP report
# ─────────────────────────────────────────────────────────────

show_geoip_report() {
    local tmp_file
    local output
    local legend

    tmp_file="$(mktemp)"

    if ! curl -fsSL --connect-timeout 8 --max-time 30 \
        -o "$tmp_file" "$GEOIP_URL"; then

        rm -f "$tmp_file"
        printf 'GeoIP script could not be downloaded.\n' >>"$LOG_FILE"
        print_warn "GeoIP-отчет не получен: скрипт недоступен."
        return 0
    fi

    if ! output="$(timeout 45 bash "$tmp_file" 2>>"$LOG_FILE")"; then
        rm -f "$tmp_file"
        printf 'GeoIP script execution failed.\n' >>"$LOG_FILE"
        print_warn "GeoIP-скрипт завершился с ошибкой."
        return 0
    fi

    rm -f "$tmp_file"

    legend="$(
        printf '%s\n' "$output" |
            awk '
                /Legend/ { found = 1; next }
                found && /[0-9]+%/ { print }
            '
    )"

    printf '\n'
    printf '%s━━ GeoIP ━━%s\n' "$C_CYAN" "$C_RESET"

    if [[ -n "$legend" ]]; then
        printf '%s\n' "$legend"
    else
        print_warn "В выводе GeoIP не найдена секция Legend с процентами."
    fi
}

# ─────────────────────────────────────────────────────────────
# 10. Final report
# ─────────────────────────────────────────────────────────────

show_summary() {
    local bbr_status
    local ipv6_status
    local ufw_status
    local fail2ban_status

    bbr_status="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)"
    ipv6_status="$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null || echo unknown)"
    ufw_status="$(ufw status 2>/dev/null | head -n 1 || echo unknown)"
    fail2ban_status="$(systemctl is-active fail2ban 2>/dev/null || echo unknown)"

    printf '\n'
    printf '%s━━━━━━━━━━ SETUP SUMMARY ━━━━━━━━━━%s\n' "$C_CYAN" "$C_RESET"
    printf 'Completed steps: %s/%s\n' "$PASSED_STEPS" "$TOTAL_STEPS"
    printf 'Failed steps:    %s\n' "$FAILED_STEPS"
    printf 'TCP congestion:  %s\n' "$bbr_status"
    printf 'IPv6 disabled:   %s\n' "$ipv6_status"
    printf 'UFW:             %s\n' "$ufw_status"
    printf 'Fail2ban:        %s\n' "$fail2ban_status"
    printf 'Log file:        %s\n' "$LOG_FILE"
    printf '\n'

    if (( FAILED_STEPS > 0 )); then
        print_warn "Есть этапы с ошибками. Проверь лог: $LOG_FILE"
    else
        printf '%s✓ Настройка завершена.%s\n' "$C_GREEN" "$C_RESET"
    fi

    print_info "Перезагрузка автоматически не выполнялась."
}

# ─────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────

draw_banner
check_system

print_info "Система: ${PRETTY_NAME:-unknown}"
print_info "Лог: $LOG_FILE"
printf '\n'

run_step "Обновление системы и пакетов" update_system
run_step "Настройка UFW и SSH-портов" configure_ufw
run_step "TCP tuning и BBR" configure_tcp
run_step "Отключение IPv6" disable_ipv6
run_step "Блокировка ICMP echo-request" block_icmp_echo
run_step "Настройка Fail2ban" configure_fail2ban
run_step "Проверка DNS" check_dns
run_step "Синхронизация времени" configure_time_sync
run_step "GeoIP-отчет" --show show_geoip_report
run_step "Итоговая диагностика" --show show_summary

printf 'Finished: %s\n' "$(date --iso-8601=seconds)" >>"$LOG_FILE"
