#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="cliproxyapi"
UPSTREAM_NAME="CLIProxyAPI"
REPO="router-for-me/CLIProxyAPI"
SERVICE_NAME="cliproxyapi"
DEFAULT_INSTALL_DIR="/opt/cliproxyapi"
DEFAULT_CONFIG_DIR="/etc/cliproxyapi"
DEFAULT_DATA_DIR="/var/lib/cliproxyapi"
DEFAULT_LOG_DIR="/var/log/cliproxyapi"
DEFAULT_SERVICE_USER="cliproxyapi"
DEFAULT_PORT="8317"
DEFAULT_LISTEN_HOST=""
GITHUB_BASE="https://github.com/${REPO}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { printf "${BLUE}[信息]${NC} %s\n" "$*"; }
success() { printf "${GREEN}[完成]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[注意]${NC} %s\n" "$*"; }
error() { printf "${RED}[错误]${NC} %s\n" "$*" >&2; }

pause() {
  local _ignored
  echo
  read_from_tty "按 Enter 返回主菜单..." _ignored
}

need_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    error "请使用 root 权限运行。推荐命令：curl -fsSL <install.sh 原始链接> | sudo bash"
    exit 1
  fi
}

read_from_tty() {
  local prompt="$1"
  local __resultvar="$2"
  local input_value=""
  if [[ "${CPA_FORCE_STDIN:-0}" != "1" ]] && [[ -e /dev/tty ]] && { : </dev/tty; } 2>/dev/null; then
    read -r -p "$prompt" input_value </dev/tty || true
  else
    read -r -p "$prompt" input_value || true
  fi
  printf -v "$__resultvar" '%s' "$input_value"
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

install_dependencies() {
  local missing=()
  for cmd in curl tar sed awk grep systemctl; do
    command_exists "$cmd" || missing+=("$cmd")
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    return 0
  fi

  info "检测到缺少依赖：${missing[*]}，尝试自动安装。"
  if command_exists apt-get; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y curl tar sed gawk grep systemd ca-certificates coreutils
  elif command_exists dnf; then
    dnf install -y curl tar sed gawk grep systemd ca-certificates coreutils
  elif command_exists yum; then
    yum install -y curl tar sed gawk grep systemd ca-certificates coreutils
  elif command_exists apk; then
    apk add --no-cache curl tar sed awk grep systemd ca-certificates coreutils
  else
    error "无法自动安装依赖，请先安装：${missing[*]}"
    exit 1
  fi

  for cmd in curl tar sed awk grep systemctl; do
    command_exists "$cmd" || { error "依赖 $cmd 仍不可用。"; exit 1; }
  done
}

read_default() {
  local prompt="$1"
  local default_value="$2"
  local value=""
  if [[ -n "$default_value" ]]; then
    read_from_tty "${prompt} [${default_value}]: " value
    printf '%s' "${value:-$default_value}"
  else
    read_from_tty "${prompt} [留空]: " value
    printf '%s' "$value"
  fi
}

read_yes_no() {
  local prompt="$1"
  local default_value="$2"
  local suffix value
  if [[ "$default_value" == "y" ]]; then
    suffix="Y/n"
  else
    suffix="y/N"
  fi
  while true; do
    read_from_tty "${prompt} [${suffix}]: " value
    value="${value:-$default_value}"
    case "${value,,}" in
      y|yes) return 0 ;;
      n|no) return 1 ;;
      *) echo "请输入 y 或 n。" ;;
    esac
  done
}

trim() {
  local s="$*"
  s="${s#${s%%[![:space:]]*}}"
  s="${s%${s##*[![:space:]]}}"
  printf '%s' "$s"
}

yaml_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

random_hex() {
  if command_exists openssl; then
    openssl rand -hex 24
  else
    od -An -N24 -tx1 /dev/urandom | tr -d ' \n'
  fi
}

normalize_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) printf 'amd64' ;;
    aarch64|arm64) printf 'aarch64' ;;
    *)
      error "当前 CPU 架构 ${arch} 暂未匹配到官方 Linux 发行包。支持 amd64 与 aarch64。"
      exit 1
      ;;
  esac
}

get_latest_version() {
  local url tag
  url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "${GITHUB_BASE}/releases/latest" || true)"
  tag="${url##*/}"
  tag="${tag#v}"
  if [[ -z "$tag" || "$tag" == "latest" ]]; then
    tag="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\{0,1\}\([^"]*\)".*/\1/p' | head -n1)"
  fi
  [[ -n "$tag" ]] || { error "无法获取最新版本号，请检查网络或手动输入版本。"; exit 1; }
  printf '%s' "$tag"
}

validate_port() {
  local port="$1"
  if ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
    error "端口必须是 1-65535 的整数。"
    exit 1
  fi
}

create_service_user() {
  local user="$1"
  local home_dir="$2"
  if id "$user" >/dev/null 2>&1; then
    info "系统用户 ${user} 已存在，继续使用。"
  else
    useradd --system --home-dir "$home_dir" --create-home --shell /usr/sbin/nologin "$user"
    success "已创建系统用户 ${user}。"
  fi
}

write_config() {
  local config_file="$1"
  local listen_host="$2"
  local port="$3"
  local auth_dir="$4"
  local proxy_url="$5"
  local debug="$6"
  local logging_to_file="$7"
  local allow_remote_mgmt="$8"
  local management_key="$9"
  shift 9
  local api_keys=("$@")

  local tmp_file
  tmp_file="$(mktemp)"
  {
    echo "# CLIProxyAPI 配置文件，由 install_cliproxyapi.sh 生成。"
    echo "# 如需完整高级配置，可参考官方 config.example.yaml。"
    echo "host: \"$(yaml_escape "$listen_host")\""
    echo "port: ${port}"
    echo
    echo "tls:"
    echo "  enable: false"
    echo "  cert: \"\""
    echo "  key: \"\""
    echo
    echo "remote-management:"
    echo "  allow-remote: ${allow_remote_mgmt}"
    echo "  secret-key: \"$(yaml_escape "$management_key")\""
    if [[ -n "$management_key" ]]; then
      echo "  disable-control-panel: false"
    else
      echo "  disable-control-panel: true"
    fi
    echo "  disable-auto-update-panel: false"
    echo "  panel-github-repository: \"router-for-me/Cli-Proxy-API-Management-Center\""
    echo
    echo "auth-dir: \"$(yaml_escape "$auth_dir")\""
    echo
    if [[ ${#api_keys[@]} -gt 0 ]]; then
      echo "api-keys:"
      for key in "${api_keys[@]}"; do
        echo "  - \"$(yaml_escape "$key")\""
      done
    else
      echo "api-keys: []"
    fi
    echo
    echo "debug: ${debug}"
    echo "logging-to-file: ${logging_to_file}"
    echo "logs-max-total-size-mb: 1024"
    echo "error-logs-max-files: 10"
    echo "usage-statistics-enabled: false"
    echo "redis-usage-queue-retention-seconds: 60"
    echo
    echo "proxy-url: \"$(yaml_escape "$proxy_url")\""
    echo "request-retry: 3"
    echo "max-retry-credentials: 0"
    echo "max-retry-interval: 30"
    echo "disable-cooling: false"
    echo "disable-image-generation: false"
    echo
    echo "quota-exceeded:"
    echo "  switch-project: true"
    echo "  switch-preview-model: true"
    echo "  antigravity-credits: true"
    echo
    echo "routing:"
    echo "  strategy: \"round-robin\""
    echo "  session-affinity: false"
    echo "  session-affinity-ttl: \"1h\""
    echo
    echo "ws-auth: false"
    echo "enable-gemini-cli-endpoint: false"
    echo "nonstream-keepalive-interval: 0"
  } > "$tmp_file"

  install -m 0640 "$tmp_file" "$config_file"
  rm -f "$tmp_file"
}

write_env_file() {
  local env_file="$1"
  local extra_args="$2"
  cat > "$env_file" <<EOF
# CLIProxyAPI systemd 环境文件。
# 可在此追加启动参数，例如：EXTRA_ARGS="-local-model"
EXTRA_ARGS="${extra_args}"
EOF
  chmod 0644 "$env_file"
}

write_systemd_service() {
  local service_file="/etc/systemd/system/${SERVICE_NAME}.service"
  local install_dir="$1"
  local config_file="$2"
  local service_user="$3"
  cat > "$service_file" <<EOF
[Unit]
Description=CLIProxyAPI Service
Documentation=${GITHUB_BASE}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${service_user}
Group=${service_user}
WorkingDirectory=${install_dir}
EnvironmentFile=-/etc/default/${SERVICE_NAME}
ExecStart=${install_dir}/cli-proxy-api -config ${config_file} \$EXTRA_ARGS
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
}

download_and_install_binary() {
  local version="$1"
  local arch="$2"
  local install_dir="$3"
  local tmp_dir asset url checksums_url checksum_line expected actual

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"; trap - RETURN' RETURN

  asset="CLIProxyAPI_${version}_linux_${arch}.tar.gz"
  url="${GITHUB_BASE}/releases/download/v${version}/${asset}"
  checksums_url="${GITHUB_BASE}/releases/download/v${version}/checksums.txt"

  info "下载 ${UPSTREAM_NAME} ${version} (${arch})。"
  curl -fL --retry 3 --connect-timeout 20 -o "${tmp_dir}/${asset}" "$url"

  if curl -fsSL --retry 2 -o "${tmp_dir}/checksums.txt" "$checksums_url"; then
    checksum_line="$(grep -E "(^|[[:space:]])${asset}$" "${tmp_dir}/checksums.txt" | head -n1 || true)"
    if [[ -n "$checksum_line" ]] && command_exists sha256sum; then
      expected="$(printf '%s\n' "$checksum_line" | awk '{print $1}')"
      actual="$(sha256sum "${tmp_dir}/${asset}" | awk '{print $1}')"
      if [[ "$expected" != "$actual" ]]; then
        error "校验失败：下载文件 sha256 与 checksums.txt 不一致。"
        exit 1
      fi
      success "发行包 SHA256 校验通过。"
    else
      warn "未能在 checksums.txt 中找到 ${asset}，跳过校验。"
    fi
  else
    warn "无法下载 checksums.txt，跳过校验。"
  fi

  mkdir -p "${tmp_dir}/extract"
  tar -xzf "${tmp_dir}/${asset}" -C "${tmp_dir}/extract"
  if [[ ! -f "${tmp_dir}/extract/cli-proxy-api" ]]; then
    error "发行包中未找到 cli-proxy-api 二进制文件。"
    exit 1
  fi

  install -d -m 0755 "$install_dir"
  install -m 0755 "${tmp_dir}/extract/cli-proxy-api" "${install_dir}/cli-proxy-api"
  if [[ -f "${tmp_dir}/extract/config.example.yaml" ]]; then
    install -m 0644 "${tmp_dir}/extract/config.example.yaml" "${install_dir}/config.example.yaml"
  fi
  if [[ -f "${tmp_dir}/extract/LICENSE" ]]; then
    install -m 0644 "${tmp_dir}/extract/LICENSE" "${install_dir}/LICENSE"
  fi
  success "二进制文件已安装到 ${install_dir}/cli-proxy-api。"
}

install_or_upgrade() {
  need_root
  install_dependencies

  local latest_version version arch install_dir config_dir data_dir auth_dir log_dir service_user
  local listen_host port proxy_url debug_bool logging_bool allow_remote_bool management_key
  local config_file env_file backup_ts extra_args
  local api_keys=()

  latest_version="$(get_latest_version)"
  version="${latest_version#v}"
  arch="$(normalize_arch)"

  install_dir="$DEFAULT_INSTALL_DIR"
  config_dir="$DEFAULT_CONFIG_DIR"
  data_dir="$DEFAULT_DATA_DIR"
  auth_dir="${data_dir}/auths"
  log_dir="$DEFAULT_LOG_DIR"
  service_user="$DEFAULT_SERVICE_USER"
  port="$DEFAULT_PORT"
  listen_host="$DEFAULT_LISTEN_HOST"
  proxy_url=""
  debug_bool="false"
  logging_bool="true"
  allow_remote_bool="true"
  management_key="mgmt-cpa-$(random_hex)"
  extra_args=""

  validate_port "$port"
  config_file="${config_dir}/config.yaml"
  env_file="/etc/default/${SERVICE_NAME}"

  echo
  info "开始全默认安装/升级 ${UPSTREAM_NAME}，无需填写参数。"
  echo "版本：${version}"
  echo "安装目录：${install_dir}"
  echo "配置目录：${config_dir}"
  echo "数据目录：${data_dir}"
  echo "日志目录：${log_dir}"
  echo "服务端口：${port}"
  echo "Web 管理面板：启用"
  echo "客户端 API Key：安装时不预置，可在 Web 管理面板中添加"

  info "创建目录与系统用户。"
  install -d -m 0755 "$install_dir" "$config_dir" "$data_dir" "$auth_dir" "$log_dir"
  create_service_user "$service_user" "$data_dir"

  if systemctl list-unit-files | grep -q "^${SERVICE_NAME}\.service"; then
    info "检测到已有服务，先停止。"
    systemctl stop "${SERVICE_NAME}" || true
  fi

  download_and_install_binary "$version" "$arch" "$install_dir"

  if [[ -e "$config_file" ]]; then
    backup_ts="$(date +%Y%m%d%H%M%S)"
    cp -a "$config_file" "${config_file}.bak.${backup_ts}"
    warn "已有配置已备份为 ${config_file}.bak.${backup_ts}。"
  fi

  write_config "$config_file" "$listen_host" "$port" "$auth_dir" "$proxy_url" "$debug_bool" "$logging_bool" "$allow_remote_bool" "$management_key" "${api_keys[@]}"
  write_env_file "$env_file" "$extra_args"

  chown -R "${service_user}:${service_user}" "$install_dir" "$config_dir" "$data_dir" "$log_dir"
  chmod 0750 "$config_dir" "$data_dir" "$auth_dir" "$log_dir"
  chmod 0640 "$config_file"

  rm -rf "${install_dir}/logs"
  ln -s "$log_dir" "${install_dir}/logs"
  chown -h "${service_user}:${service_user}" "${install_dir}/logs" || true

  write_systemd_service "$install_dir" "$config_file" "$service_user"
  systemctl daemon-reload
  systemctl enable --now "${SERVICE_NAME}"

  echo
  success "${UPSTREAM_NAME} 已按默认配置安装并启动。"
  echo "服务状态：systemctl status ${SERVICE_NAME} --no-pager"
  echo "查看日志：journalctl -u ${SERVICE_NAME} -f"
  echo "配置文件：${config_file}"
  echo "服务地址：http://<服务器IP>:${port}"
  echo "OpenAI 兼容 API Base URL：http://<服务器IP>:${port}/v1"
  echo "Web 管理面板：http://<服务器IP>:${port}/management.html"
  echo "管理 secret-key：${management_key}"
  echo "预置客户端 API Key：未设置，请登录 Web 管理面板后在 API Keys 中添加。"
  echo
  echo "如果你的服务器已反代到 80/443 端口，可直接访问：http://<服务器IP>/management.html 或 https://<域名>/management.html。"
  echo "浏览器打不开时，请确认服务器防火墙/安全组已放行 TCP ${port}。"
  echo
  echo "常用登录命令示例："
  echo "  sudo -u ${service_user} ${install_dir}/cli-proxy-api -config ${config_file} -codex-device-login"
  echo "  sudo -u ${service_user} ${install_dir}/cli-proxy-api -config ${config_file} -claude-login -no-browser"
  echo "  sudo -u ${service_user} ${install_dir}/cli-proxy-api -config ${config_file} -login -no-browser"
  echo
  systemctl --no-pager --full status "${SERVICE_NAME}" || true
}

uninstall_app() {
  need_root
  local install_dir config_dir data_dir log_dir service_user
  install_dir="$DEFAULT_INSTALL_DIR"
  config_dir="$DEFAULT_CONFIG_DIR"
  data_dir="$DEFAULT_DATA_DIR"
  log_dir="$DEFAULT_LOG_DIR"
  service_user="$DEFAULT_SERVICE_USER"

  warn "开始彻底卸载 ${UPSTREAM_NAME}，将删除服务、程序、配置、数据、认证文件、日志和默认系统用户。"

  if command_exists systemctl; then
    systemctl stop "${SERVICE_NAME}" 2>/dev/null || true
    systemctl disable "${SERVICE_NAME}" 2>/dev/null || true
  fi

  rm -f "/etc/systemd/system/${SERVICE_NAME}.service" "/etc/default/${SERVICE_NAME}"
  command_exists systemctl && systemctl daemon-reload || true
  command_exists systemctl && systemctl reset-failed "${SERVICE_NAME}" 2>/dev/null || true

  rm -rf "$install_dir" "$config_dir" "$data_dir" "$log_dir"
  rm -rf "/tmp/${SERVICE_NAME}" "/tmp/${UPSTREAM_NAME}" "/tmp/cpa-onekey-test"

  if id "$service_user" >/dev/null 2>&1; then
    userdel -r "$service_user" 2>/dev/null || userdel "$service_user" 2>/dev/null || warn "删除系统用户 ${service_user} 失败，可能仍有进程或文件占用。"
  fi

  success "已彻底删除默认路径下的 ${UPSTREAM_NAME} 相关文件。"
}

show_menu() {
  clear || true
  echo "========================================"
  echo " ${UPSTREAM_NAME} + Web Dashboard 极简一键脚本"
  echo " 仓库：${GITHUB_BASE}"
  echo "========================================"
  echo "1. 安装/升级"
  echo "2. 卸载"
  echo "3. 退出"
  echo "========================================"
}

main() {
  while true; do
    show_menu
    read_from_tty "请选择 [1-3]: " choice
    case "${choice:-}" in
      1) install_or_upgrade; pause ;;
      2) uninstall_app; pause ;;
      3) echo "已退出。"; exit 0 ;;
      *) echo "无效选择，请输入 1、2 或 3。"; sleep 1 ;;
    esac
  done
}

main "$@"
