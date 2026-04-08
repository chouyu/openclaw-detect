# OpenClaw Detection Scripts

> **Find OpenClaw on managed devices.** Lightweight detection scripts for macOS, Linux, and Windows that check for CLI binaries, app bundles, config files, gateway services, and Docker artifacts. Designed for MDM deployment via Jamf, Intune, JumpCloud, and more.

## 🚀 Version v1.1 - Enhanced Edition

This version is an enhanced fork of the original detection scripts with the following improvements:

- **Bilingual Output**: All detection results and summaries are now provided in `English (Chinese)` format.
- **Environment Diagnostics**: Automatically displays OS version, current user (with privilege check), and all active IPv4/IPv6 addresses.
- **Process Detection**: Added real-time scanning for active `openclaw` processes to identify manual executions.
- **Clean UI**: Removed all promotional ASCII art and branding; output starts directly with the detection header.
- **Robust IP Handling**: Improved logic to correctly separate and display multiple IPv4 and global IPv6 addresses (excluding loopback and link-local).
- **Interactive PowerShell**: Windows script now remains open after manual execution for easy screenshotting.

---

# OpenClaw Detection Scripts - TL;DR

Detection scripts for MDM deployment to identify OpenClaw installations on managed devices.

## What It Detects

| Check | macOS | Linux | Windows |
|-------|-------|-------|---------|
| CLI binary (`openclaw`) | Yes | Yes | Yes |
| CLI version | Yes | Yes | Yes |
| macOS app (`/Applications/OpenClaw.app`) | Yes | - | - |
| State directory (`~/.openclaw`) | Yes | Yes | Yes |
| Config file (`~/.openclaw/openclaw.json`) | Yes | Yes | Yes |
| Gateway service (launchd/systemd/schtasks) | Yes | Yes | Yes |
| Gateway port (default 18789) | Yes | Yes | Yes |
| Active Process | Yes | Yes | Yes |
| Docker containers | Yes | Yes | Yes |
| Docker images | Yes | Yes | Yes |

## Exit Codes

| Exit Code | Meaning | MDM Status |
|-----------|---------|------------|
| 0 | NOT installed | Success (clean) |
| 1 | Installed (running or not) | Error (found) |
| 2 | Script error | Error (investigate) |

## Usage

### macOS/Linux

```bash
curl -sL https://raw.githubusercontent.com/chouyu/openclaw-detect/refs/heads/main/detect-openclaw.sh | bash
```

### Windows (PowerShell)

```powershell
iwr -useb https://raw.githubusercontent.com/chouyu/openclaw-detect/refs/heads/main/detect-openclaw.ps1 | iex
```

### Without curl

Copy [`detect-openclaw.sh`](detect-openclaw.sh) (macOS/Linux) or [`detect-openclaw.ps1`](detect-openclaw.ps1) (Windows) and run directly.

### Run as root/admin

Running with elevated privileges scans all user directories:

```bash
curl -sL https://raw.githubusercontent.com/chouyu/openclaw-detect/refs/heads/main/detect-openclaw.sh | sudo bash
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENCLAW_PROFILE` | (none) | Profile name for multi-instance setups |
| `OPENCLAW_GATEWAY_PORT` | 18789 | Gateway port to check |

## Example Output

```
OpenClaw Detection Script (v1.1)

--- Environment Information (环境基本信息) ---
OS Version (操作系统版本): Ubuntu 22.04.3 LTS
Current User (当前用户): user (UID: 1000)
IP Address (IP地址):
  IPv4: 192.168.1.100
  IPv6: 240e:xxx:xxx:xxx
-------------------------------

summary (检测汇总): installed-and-running (已安装且运行中)
platform (平台): linux
cli (命令行工具): /usr/local/bin/openclaw
cli-version (工具版本): 2026.1.15
state-dir (状态目录): /home/user/.openclaw
config (配置文件): /home/user/.openclaw/openclaw.json
gateway-service (网关服务): openclaw-gateway.service
process (进程): running
gateway-port (网关端口): 18789
docker-container (Docker容器): not-found
docker-image (Docker镜像): not-found
```

---

## MDM Integration

| Platform | Guide |
|----------|-------|
| Addigy | [docs/addigy.md](docs/addigy.md) |
| CrowdStrike Falcon | [docs/crowdstrike.md](docs/crowdstrike.md) |
| JumpCloud | [docs/jumpcloud.md](docs/jumpcloud.md) |
| Microsoft Intune | [docs/intune.md](docs/intune.md) |
| Jamf Pro | [docs/jamf.md](docs/jamf.md) |
| VMware Workspace ONE | [docs/workspace-one.md](docs/workspace-one.md) |
| Kandji | [docs/kandji.md](docs/kandji.md) |

---

## License

Apache 2.0 — see LICENSE for details.

---

# OpenClaw 检测脚本 - 中文说明

> **在受管设备上查找 OpenClaw。** 适用于 macOS、Linux 和 Windows 的轻量级检测脚本，可检查 CLI 二进制文件、应用程序包、配置文件、网关服务和 Docker 伪像。专为通过 Jamf、Intune、JumpCloud 等进行 MDM 部署而设计。

## 🚀 v1.1 增强版 - 主要改进

此版本基于原版检测脚本进行了以下深度优化：

- **中英双语输出**：所有检测结果和汇总状态均采用 `English (中文)` 格式展示。
- **环境信息诊断**：自动显示操作系统详细版本、当前运行用户（及权限状态）以及所有活跃的 IPv4 和 IPv6 地址。
- **进程实时检测**：新增对 `openclaw` 运行进程的扫描，防止绕过服务直接手动运行。
- **清爽输出界面**：移除了所有原版的广告内容，脚本首行直接输出检测版本标题。
- **多 IP 逻辑优化**：改进了 IP 检测算法，能够准确分离并展示多个内网/公网 IPv4 及全局 IPv6 地址（排除回环及链路本地地址）。
- **PowerShell 结果保留**：Windows 脚本在手动运行时会在完成后暂停，方便截屏。

## 检测内容

| 检查项目 | macOS | Linux | Windows |
|-------|-------|-------|---------|
| CLI 二进制文件 (`openclaw`) | 是 | 是 | 是 |
| CLI 版本 | 是 | 是 | 是 |
| macOS 应用程序 (`/Applications/OpenClaw.app`) | 是 | - | - |
| 状态目录 (`~/.openclaw`) | 是 | 是 | 是 |
| 配置文件 (`~/.openclaw/openclaw.json`) | 是 | 是 | 是 |
| 网关服务 (launchd/systemd/schtasks) | 是 | 是 | 是 |
| 网关端口 (默认 18789) | 是 | 是 | 是 |
| 活跃进程检测 | 是 | 是 | 是 |
| Docker 容器 | 是 | 是 | 是 |
| Docker 镜像 | 是 | 是 | 是 |

## 退出代码

| 退出代码 | 含义 | MDM 状态 |
|-----------|---------|------------|
| 0 | 未安装 | 成功 (清洁) |
| 1 | 已安装 (运行中或未运行) | 错误 (发现) |
| 2 | 脚本错误 | 错误 (需调查) |

## 使用方法

### macOS/Linux

```bash
curl -sL https://raw.githubusercontent.com/chouyu/openclaw-detect/refs/heads/main/detect-openclaw.sh | bash
```

### Windows (PowerShell)

```powershell
iwr -useb https://raw.githubusercontent.com/chouyu/openclaw-detect/refs/heads/main/detect-openclaw.ps1 | iex
```

### 以 root/管理员身份运行

以提升的权限运行将扫描所有用户目录：

```bash
curl -sL https://raw.githubusercontent.com/chouyu/openclaw-detect/refs/heads/main/detect-openclaw.sh | sudo bash
```
