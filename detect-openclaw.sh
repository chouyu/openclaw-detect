#!/usr/bin/env bash
# openclaw detection script for mdm deployment (v1.1)
# exit codes: 0=not-installed (clean), 1=found (non-compliant), 2=error

set -euo pipefail

PROFILE="${OPENCLAW_PROFILE:-}"
PORT="${OPENCLAW_GATEWAY_PORT:-18789}"

print_banner() {
  echo 'OpenClaw Detection Script (v1.1)'
  echo ''
}

print_banner

print_env_info() {
  local platform="$1"
  echo "--- Environment Information (环境基本信息) ---"
  echo -n "OS Version (操作系统版本): "
  case "$platform" in
    darwin) sw_vers | paste -sd ' ' - ;;
    linux) grep "PRETTY_NAME" /etc/os-release | cut -d= -f2 | tr -d '"' || uname -sr ;;
    *) uname -sr ;;
  esac
  echo "Current User (当前用户): $(whoami) (UID: $EUID)"
  
  # 获取所有非回环 IPv4
  local ipv4s
  if command -v ip >/dev/null; then
    ipv4s=$(ip -4 addr show up 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | tr '\n' ' ' || true)
  elif command -v hostname >/dev/null && hostname -I &>/dev/null; then
    ipv4s=$(hostname -I | tr ' ' '\n' | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' | tr '\n' ' ' || true)
  else
    ipv4s=$(ifconfig 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | tr '\n' ' ' || true)
  fi
  
  # 获取所有全局 IPv6
  local ipv6s
  if command -v ip >/dev/null; then
    ipv6s=$(ip -6 addr show scope global up 2>/dev/null | grep 'inet6' | awk '{print $2}' | cut -d/ -f1 | tr '\n' ' ' || true)
  else
    ipv6s=$(ifconfig 2>/dev/null | grep 'inet6 ' | grep -v '::1' | grep -v 'fe80' | awk '{print $2}' | cut -d% -f1 | tr '\n' ' ' || true)
  fi

  echo "IP Address (IP地址):"
  echo "  IPv4: ${ipv4s:-N/A}"
  echo "  IPv6: ${ipv6s:-N/A}"
  echo "-------------------------------"
  echo ""
}

detect_platform() {
  case "$(uname -s)" in
    Darwin) echo "darwin" ;;
    Linux) echo "linux" ;;
    *) echo "unknown" ;;
  esac
}

get_state_dir() {
  local home="$1"
  if [[ -n "$PROFILE" ]]; then
    echo "${home}/.openclaw-${PROFILE}"
  else
    echo "${home}/.openclaw"
  fi
}

get_users_to_check() {
  local platform="$1"
  if [[ "$EUID" -eq 0 ]]; then
    case "$platform" in
      darwin)
        for dir in /Users/*; do
          [[ -d "$dir" && "$(basename "$dir")" != "Shared" ]] && basename "$dir"
        done
        ;;
      linux)
        for dir in /home/*; do
          [[ -d "$dir" ]] && basename "$dir"
        done
        ;;
    esac
  else
    whoami
  fi
}

get_home_dir() {
  local user="$1"
  local platform="$2"
  case "$platform" in
    darwin) echo "/Users/$user" ;;
    linux) echo "/home/$user" ;;
  esac
}

check_cli_in_path() {
  local path
  path=$(command -v openclaw 2>/dev/null) || true
  if [[ -n "$path" ]]; then
    echo "$path"
    return 0
  fi
  return 1
}

check_cli_for_user() {
  local home="$1"
  local locations=(
    "${home}/.volta/bin/openclaw"
    "${home}/.local/bin/openclaw"
    "${home}/.nvm/current/bin/openclaw"
    "${home}/bin/openclaw"
  )
  for loc in "${locations[@]}"; do
    if [[ -x "$loc" ]]; then
      echo "$loc"
      return 0
    fi
  done
  return 1
}

check_cli_global() {
  local locations=(
    "/usr/local/bin/openclaw"
    "/opt/homebrew/bin/openclaw"
    "/usr/bin/openclaw"
  )
  for loc in "${locations[@]}"; do
    if [[ -x "$loc" ]]; then
      echo "$loc"
      return 0
    fi
  done
  return 1
}

check_mac_app() {
  local app_path="/Applications/OpenClaw.app"
  if [[ -d "$app_path" ]]; then
    echo "$app_path"
    return 0
  else
    echo "not-found (未找到)"
    return 1
  fi
}

check_state_dir() {
  local state_dir="$1"
  if [[ -d "$state_dir" ]]; then
    echo "$state_dir"
    return 0
  else
    echo "not-found (未找到)"
    return 1
  fi
}

check_config() {
  local config_file="${1}/openclaw.json"
  if [[ -f "$config_file" ]]; then
    echo "$config_file"
  else
    echo "not-found (未找到)"
  fi
}

check_launchd_service() {
  local label uid
  uid=$(id -u)
  if [[ -n "$PROFILE" ]]; then
    label="bot.molt.${PROFILE}"
  else
    label="bot.molt.gateway"
  fi
  if launchctl print "gui/${uid}/${label}" &>/dev/null; then
    echo "gui/${uid}/${label}"
  else
    echo "not-loaded (未加载)"
  fi
}

check_systemd_service() {
  local service
  if [[ -n "$PROFILE" ]]; then
    service="openclaw-gateway-${PROFILE}.service"
  else
    service="openclaw-gateway.service"
  fi
  if systemctl --user is-active "$service" &>/dev/null; then
    echo "$service"
  else
    echo "inactive (未激活)"
  fi
}

check_process() {
  if pgrep -x "openclaw" >/dev/null; then
    echo "running (运行中)"
    return 0
  else
    echo "not-running (未运行)"
    return 1
  fi
}

get_configured_port() {
  local config_file="$1"
  if [[ -f "$config_file" ]]; then
    grep -o '"port"[[:space:]]*:[[:space:]]*[0-9]*' "$config_file" 2>/dev/null | head -1 | grep -o '[0-9]*$' || true
  fi
}

check_gateway_port() {
  local port="$1"
  if nc -z localhost "$port" &>/dev/null; then
    echo "listening (正在监听)"
    return 0
  else
    echo "not-listening (未监听)"
    return 1
  fi
}

check_docker_containers() {
  if ! command -v docker &>/dev/null; then
    return 0
  fi
  docker ps --format '{{.Names}} ({{.Image}})' 2>/dev/null | grep -i openclaw || true
}

check_docker_images() {
  if ! command -v docker &>/dev/null; then
    return 0
  fi
  docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -i openclaw || true
}

main() {
  local platform cli_found=false app_found=false state_found=false service_running=false port_listening=false process_running=false
  local output=""

  out() { output+="$1"$'\n'; }

  platform=$(detect_platform)
  
  if [[ "$platform" == "unknown" ]]; then
    echo "summary (检测汇总): error (错误)"
    echo "Error: Unknown platform $(uname -s)"
    exit 2
  fi

  print_env_info "$platform"
  out "platform (平台): $platform"

  local cli_result=""
  cli_result=$(check_cli_in_path) || cli_result=$(check_cli_global) || true
  if [[ -n "$cli_result" ]]; then
    cli_found=true
    out "cli (命令行工具): $cli_result"
    out "cli-version (工具版本): $("$cli_result" --version 2>/dev/null | head -1 || echo "unknown")"
  fi

  if [[ "$platform" == "darwin" ]]; then
    local app_result
    app_result=$(check_mac_app) && app_found=true || app_found=false
    out "app (应用程序): $app_result"
  fi

  local users
  users=$(get_users_to_check "$platform")
  local multi_user=false
  local user_count
  user_count=$(echo "$users" | wc -l | tr -d ' ')
  [[ "$user_count" -gt 1 ]] && multi_user=true

  local ports_to_check="$PORT"

  for user in $users; do
    local home_dir state_dir
    home_dir=$(get_home_dir "$user" "$platform")
    state_dir=$(get_state_dir "$home_dir")

    if "$multi_user"; then
      out "user (用户): $user"
      if ! "$cli_found"; then
        local user_cli
        user_cli=$(check_cli_for_user "$home_dir") || true
        if [[ -n "$user_cli" ]]; then
          cli_found=true
          out "  cli (命令行工具): $user_cli"
          out "  cli-version (工具版本): $("$user_cli" --version 2>/dev/null | head -1 || echo "unknown")"
        fi
      fi
      local state_result
      state_result=$(check_state_dir "$state_dir") && state_found=true
      out "  state-dir (状态目录): $state_result"
      local config_result
      config_result=$(check_config "$state_dir")
      out "  config (配置文件): $config_result"
      local configured_port
      configured_port=$(get_configured_port "${state_dir}/openclaw.json")
      if [[ -n "$configured_port" ]]; then
        out "  config-port (配置端口): $configured_port"
        ports_to_check="$ports_to_check $configured_port"
      fi
    else
      if ! "$cli_found"; then
        local user_cli
        user_cli=$(check_cli_for_user "$home_dir") || true
        if [[ -n "$user_cli" ]]; then
          cli_found=true
          out "cli (命令行工具): $user_cli"
          out "cli-version (工具版本): $("$user_cli" --version 2>/dev/null | head -1 || echo "unknown")"
        fi
      fi
      if ! "$cli_found"; then
        out "cli (命令行工具): not-found (未找到)"
        out "cli-version (工具版本): n/a"
      fi
      local state_result
      state_result=$(check_state_dir "$state_dir") && state_found=true
      out "state-dir (状态目录): $state_result"
      out "config (配置文件): $(check_config "$state_dir")"
      local configured_port
      configured_port=$(get_configured_port "${state_dir}/openclaw.json")
      if [[ -n "$configured_port" ]]; then
        out "config-port (配置端口): $configured_port"
        ports_to_check="$ports_to_check $configured_port"
      fi
    fi
  done

  if "$multi_user" && ! "$cli_found"; then
    out "cli (命令行工具): not-found (未找到)"
    out "cli-version (工具版本): n/a"
  fi

  case "$platform" in
    darwin)
      local service_result
      service_result=$(check_launchd_service) && service_running=true || service_running=false
      out "gateway-service (网关服务): $service_result"
      ;;
    linux)
      local service_result
      service_result=$(check_systemd_service) && service_running=true || service_running=false
      out "gateway-service (网关服务): $service_result"
      ;;
  esac

  local process_result
  process_result=$(check_process) && process_running=true || process_running=false
  out "process (进程): $process_result"

  local unique_ports listening_port=""
  unique_ports=$(echo "$ports_to_check" | tr ' ' '\n' | sort -u | tr '\n' ' ')
  for port in $unique_ports; do
    if check_gateway_port "$port" >/dev/null; then
      port_listening=true
      listening_port="$port"
      break
    fi
  done
  if "$port_listening"; then
    out "gateway-port (网关端口): $listening_port (正在监听)"
  else
    out "gateway-port (网关端口): not-listening (未监听)"
  fi

  local docker_containers docker_images docker_running=false docker_installed=false
  docker_containers=$(check_docker_containers)
  if [[ -n "$docker_containers" ]]; then
    docker_running=true
    out "docker-container (Docker容器): $docker_containers"
  else
    out "docker-container (Docker容器): not-found (未找到)"
  fi

  docker_images=$(check_docker_images)
  if [[ -n "$docker_images" ]]; then
    docker_installed=true
    out "docker-image (Docker镜像): $docker_images"
  else
    out "docker-image (Docker镜像): not-found (未找到)"
  fi

  local installed=false running=false
  if "$cli_found" || "$app_found" || "$state_found" || "$docker_installed"; then
    installed=true
  fi
  if "$service_running" || "$port_listening" || "$docker_running" || "$process_running"; then
    running=true
  fi

  if ! "$installed"; then
    echo "summary (检测汇总): not-installed (未安装)"
    printf "%s" "$output"
    exit 0
  elif "$running"; then
    echo "summary (检测汇总): installed-and-running (已安装且运行中)"
    printf "%s" "$output"
    exit 1
  else
    echo "summary (检测汇总): installed-not-running (已安装但未运行)"
    printf "%s" "$output"
    exit 1
  fi
}

main
