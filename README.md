```
██╗  ██╗███╗   ██╗ ██████╗ ███████╗████████╗██╗ ██████╗
██║ ██╔╝████╗  ██║██╔═══██╗██╔════╝╚══██╔══╝██║██╔════╝
█████╔╝ ██╔██╗ ██║██║   ██║███████╗   ██║   ██║██║     
██╔═██╗ ██║╚██╗██║██║   ██║╚════██║   ██║   ██║██║     
██║  ██╗██║ ╚████║╚██████╔╝███████║   ██║   ██║╚██████╗
╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝   ╚═╝   ╚═╝ ╚═════╝
```

# OpenClaw Detection Scripts

**By [Knostic](https://knostic.ai/)**

> **Find OpenClaw on managed devices.** Lightweight detection scripts for macOS, Linux, and Windows that check for CLI binaries, app bundles, config files, gateway services, and Docker artifacts. Designed for MDM deployment via Jamf, Intune, JumpCloud, and more.

Also check out:
- **openclaw-telemetry:** https://github.com/knostic/openclaw-telemetry
- **Like what we do?** Knostic helps you with visibility and control of your coding agents and MCP/extensions, from Cursor and Claude Code, to Copilot.

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
summary: installed-and-running
platform: darwin
cli: /usr/local/bin/openclaw
cli-version: 2026.1.15
app: /Applications/OpenClaw.app
state-dir: /Users/alice/.openclaw
config: /Users/alice/.openclaw/openclaw.json
gateway-service: gui/501/bot.molt.gateway
gateway-port: 18789
docker-container: not-found
docker-image: not-found
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

- ## License

Apache 2.0 — see LICENSE for details.

---

# OpenClaw 检测脚本 - 中文说明

**由 [Knostic](https://knostic.ai/) 开发**

> **在受管设备上查找 OpenClaw。** 适用于 macOS、Linux 和 Windows 的轻量级检测脚本，可检查 CLI 二进制文件、应用程序包、配置文件、网关服务和 Docker 伪像。专为通过 Jamf、Intune、JumpCloud 等进行 MDM 部署而设计。

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

### 无 curl 环境

复制 [`detect-openclaw.sh`](detect-openclaw.sh) (macOS/Linux) 或 [`detect-openclaw.ps1`](detect-openclaw.ps1) (Windows) 并直接运行。

### 以 root/管理员身份运行

以提升的权限运行将扫描所有用户目录：

```bash
curl -sL https://raw.githubusercontent.com/chouyu/openclaw-detect/refs/heads/main/detect-openclaw.sh | sudo bash
```

## 环境变量

| 变量 | 默认值 | 描述 |
|----------|---------|-------------|
| `OPENCLAW_PROFILE` | (无) | 多实例设置的配置文件名称 |
| `OPENCLAW_GATEWAY_PORT` | 18789 | 要检查的网关端口 |

## 输出示例

```
summary: installed-and-running (已安装且运行中)
platform (平台): darwin
cli (命令行工具): /usr/local/bin/openclaw
cli-version (工具版本): 2026.1.15
app (应用程序): /Applications/OpenClaw.app
state-dir (状态目录): /Users/alice/.openclaw
config (配置文件): /Users/alice/.openclaw/openclaw.json
gateway-service (网关服务): gui/501/bot.molt.gateway
gateway-port (网关端口): 18789
docker-container (Docker容器): not-found
docker-image (Docker镜像): not-found
```

