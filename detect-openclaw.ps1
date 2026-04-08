# OpenClaw Detection Script for MDM deployment (Windows)
# Exit codes: 0=not-installed (clean), 1=found (non-compliant), 2=error

$ErrorActionPreference = "Stop"

$script:Profile = $env:OPENCLAW_PROFILE
$Port = if ($env:OPENCLAW_GATEWAY_PORT) { $env:OPENCLAW_GATEWAY_PORT } else { 18789 }
$script:Output = [System.Collections.ArrayList]::new()

function Show-Banner {
    Write-Output "OpenClaw Detection Script (v1.1)`n"
}

Show-Banner

function Show-EnvInfo {
    Write-Output "--- Environment Information (环境基本信息) ---"
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        Write-Output "OS Version (操作系统版本): $($os.Caption) ($($os.Version))"
    } catch {
        Write-Output "OS Version (操作系统版本): $($PSVersionTable.OS)"
    }
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $isAdmin = if ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544') { "Admin" } else { "User" }
    Write-Output "Current User (当前用户): $currentUser ($isAdmin)"
    
    try {
        # 获取非回环、非 APIPA、非链路本地的所有 IP 地址
        $ips = Get-NetIPAddress | Where-Object { 
            $_.InterfaceAlias -notmatch 'Loopback' -and 
            $_.IPAddress -notmatch '^169\.254' -and 
            $_.IPAddress -notmatch '^fe80' 
        }
        $ipv4List = ($ips | Where-Object { $_.AddressFamily -eq 'IPv4' }).IPAddress -join ", "
        $ipv6List = ($ips | Where-Object { $_.AddressFamily -eq 'IPv6' }).IPAddress -join ", "
        
        Write-Output "IP Address (IP地址):"
        Write-Output "  IPv4: $(if ($ipv4List) { $ipv4List } else { 'N/A' })"
        Write-Output "  IPv6: $(if ($ipv6List) { $ipv6List } else { 'N/A' })"
    } catch {
        Write-Output "IP Address (IP地址): Unknown"
    }
    Write-Output "-------------------------------"
    Write-Output ""
}

Show-EnvInfo

function Out {
    param([string]$Line)
    [void]$script:Output.Add($Line)
}

function Get-StateDir {
    param([string]$HomeDir)
    if ($script:Profile) {
        return Join-Path $HomeDir ".openclaw-$($script:Profile)"
    }
    return Join-Path $HomeDir ".openclaw"
}

function Get-UsersToCheck {
    if ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544') {
        Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') } | ForEach-Object { $_.Name }
    } else {
        $env:USERNAME
    }
}

function Get-HomeDir {
    param([string]$User)
    return "C:\Users\$User"
}

function Test-CliInPath {
    try {
        $cmd = Get-Command openclaw -ErrorAction SilentlyContinue
        if ($cmd) {
            return $cmd.Source
        }
    } catch {}
    return $null
}

function Test-CliGlobal {
    $locations = @(
        "C:\Program Files\openclaw\openclaw.exe",
        "C:\Program Files (x86)\openclaw\openclaw.exe"
    )
    foreach ($loc in $locations) {
        if (Test-Path $loc) {
            return $loc
        }
    }
    return $null
}

function Test-CliForUser {
    param([string]$HomeDir)
    $locations = @(
        (Join-Path $HomeDir "AppData\Local\Programs\openclaw\openclaw.exe"),
        (Join-Path $HomeDir "AppData\Roaming\npm\openclaw.cmd"),
        (Join-Path $HomeDir "AppData\Local\pnpm\openclaw.cmd"),
        (Join-Path $HomeDir ".volta\bin\openclaw.exe"),
        (Join-Path $HomeDir "scoop\shims\openclaw.exe")
    )
    foreach ($loc in $locations) {
        if (Test-Path $loc) {
            return $loc
        }
    }
    return $null
}

function Get-CliVersion {
    param([string]$CliPath)
    try {
        $version = & $CliPath --version 2>$null | Select-Object -First 1
        if ($version) { return $version }
    } catch {}
    return "unknown"
}

function Test-StateDir {
    param([string]$Path)
    return Test-Path $Path -PathType Container
}

function Test-Config {
    param([string]$StateDir)
    return Test-Path (Join-Path $StateDir "openclaw.json") -PathType Leaf
}

function Get-ConfiguredPort {
    param([string]$ConfigFile)
    if (Test-Path $ConfigFile) {
        try {
            $content = Get-Content $ConfigFile -Raw
            if ($content -match '"port"\s*:\s*(\d+)') {
                return $matches[1]
            }
        } catch {}
    }
    return $null
}

function Test-ScheduledTask {
    $taskName = if ($script:Profile) { "OpenClaw Gateway $($script:Profile)" } else { "OpenClaw Gateway" }
    try {
        $null = schtasks /Query /TN $taskName 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $taskName
        }
    } catch {}
    return $null
}

function Test-Process {
    try {
        $proc = Get-Process -Name "openclaw" -ErrorAction SilentlyContinue
        if ($proc) {
            return "running"
        }
    } catch {}
    return "not-running"
}

function Test-GatewayPort {
    param([int]$PortNum)
    try {
        $result = Test-NetConnection -ComputerName localhost -Port $PortNum -WarningAction SilentlyContinue
        return $result.TcpTestSucceeded
    } catch {
        return $false
    }
}

function Get-DockerContainers {
    try {
        $cmd = Get-Command docker -ErrorAction SilentlyContinue
        if (-not $cmd) { return $null }
        $containers = docker ps --format '{{.Names}} ({{.Image}})' 2>$null | Select-String -Pattern "openclaw" -SimpleMatch
        if ($containers) {
            return ($containers -join ", ")
        }
    } catch {}
    return $null
}

function Get-DockerImages {
    try {
        $cmd = Get-Command docker -ErrorAction SilentlyContinue
        if (-not $cmd) { return $null }
        $images = docker images --format '{{.Repository}}:{{.Tag}}' 2>$null | Select-String -Pattern "openclaw" -SimpleMatch
        if ($images) {
            return ($images -join ", ")
        }
    } catch {}
    return $null
}

function Main {
    $cliFound = $false
    $stateFound = $false
    $serviceRunning = $false
    $portListening = $false
    $processRunning = $false

    Out "platform (平台): windows"

    # check global CLI locations first
    $cliPath = Test-CliInPath
    if (-not $cliPath) { $cliPath = Test-CliGlobal }
    if ($cliPath) {
        $cliFound = $true
        Out "cli (命令行工具): $cliPath"
        Out "cli-version (工具版本): $(Get-CliVersion $cliPath)"
    }

    $users = @(Get-UsersToCheck)
    $multiUser = $users.Count -gt 1
    $portsToCheck = @($Port)

    foreach ($user in $users) {
        $homeDir = Get-HomeDir $user
        $stateDir = Get-StateDir $homeDir
        $configFile = Join-Path $stateDir "openclaw.json"

        if ($multiUser) {
            Out "user (用户): $user"
            # check user-specific CLI if not already found
            if (-not $cliFound) {
                $userCli = Test-CliForUser $homeDir
                if ($userCli) {
                    $cliFound = $true
                    Out "  cli (命令行工具): $userCli"
                    Out "  cli-version (工具版本): $(Get-CliVersion $userCli)"
                }
            }
            if (Test-StateDir $stateDir) {
                Out "  state-dir (状态目录): $stateDir"
                $stateFound = $true
            } else {
                Out "  state-dir (状态目录): not-found"
            }
            if (Test-Config $stateDir) {
                Out "  config (配置文件): $configFile"
            } else {
                Out "  config (配置文件): not-found"
            }
            $configPort = Get-ConfiguredPort $configFile
            if ($configPort) {
                Out "  config-port (配置端口): $configPort"
                $portsToCheck += [int]$configPort
            }
        } else {
            # single user mode - check user CLI
            if (-not $cliFound) {
                $userCli = Test-CliForUser $homeDir
                if ($userCli) {
                    $cliFound = $true
                    Out "cli (命令行工具): $userCli"
                    Out "cli-version (工具版本): $(Get-CliVersion $userCli)"
                }
            }
            if (-not $cliFound) {
                Out "cli (命令行工具): not-found"
                Out "cli-version (工具版本): n/a"
            }
            if (Test-StateDir $stateDir) {
                Out "state-dir (状态目录): $stateDir"
                $stateFound = $true
            } else {
                Out "state-dir (状态目录): not-found"
            }
            if (Test-Config $stateDir) {
                Out "config (配置文件): $configFile"
            } else {
                Out "config (配置文件): not-found"
            }
            $configPort = Get-ConfiguredPort $configFile
            if ($configPort) {
                Out "config-port (配置端口): $configPort"
                $portsToCheck += [int]$configPort
            }
        }
    }

    # print cli not-found for multi-user if none found
    if ($multiUser -and -not $cliFound) {
        Out "cli (命令行工具): not-found"
        Out "cli-version (工具版本): n/a"
    }

    $taskResult = Test-ScheduledTask
    if ($taskResult) {
        Out "gateway-service (网关服务): $taskResult"
        $serviceRunning = $true
    } else {
        Out "gateway-service (网关服务): not-scheduled"
    }

    $processResult = Test-Process
    if ($processResult -eq "running") {
        Out "process (进程): running"
        $processRunning = $true
    } else {
        Out "process (进程): not-running"
    }

    $uniquePorts = $portsToCheck | Sort-Object -Unique
    $listeningPort = $null
    foreach ($p in $uniquePorts) {
        if (Test-GatewayPort $p) {
            $portListening = $true
            $listeningPort = $p
            break
        }
    }
    if ($portListening) {
        Out "gateway-port (网关端口): $listeningPort"
    } else {
        Out "gateway-port (网关端口): not-listening"
    }

    $dockerContainers = Get-DockerContainers
    $dockerRunning = $false
    if ($dockerContainers) {
        $dockerRunning = $true
        Out "docker-container (Docker容器): $dockerContainers"
    } else {
        Out "docker-container (Docker容器): not-found"
    }

    $dockerImages = Get-DockerImages
    $dockerInstalled = $false
    if ($dockerImages) {
        $dockerInstalled = $true
        Out "docker-image (Docker镜像): $dockerImages"
    } else {
        Out "docker-image (Docker镜像): not-found"
    }

    $installed = $cliFound -or $stateFound -or $dockerInstalled
    $running = $serviceRunning -or $portListening -or $dockerRunning -or $processRunning

    # exit codes: 0=not-installed (clean), 1=found (non-compliant), 2=error
    if (-not $installed) {
        Write-Output "summary (检测汇总): not-installed (未安装)"
        $script:Output | ForEach-Object { Write-Output $_ }
        $exitCode = 0
    } elseif ($running) {
        Write-Output "summary (检测汇总): installed-and-running (已安装且运行中)"
        $script:Output | ForEach-Object { Write-Output $_ }
        $exitCode = 1
    } else {
        Write-Output "summary (检测汇总): installed-not-running (已安装但未运行)"
        $script:Output | ForEach-Object { Write-Output $_ }
        $exitCode = 1
    }

    if ($Host.Name -eq "ConsoleHost") {
        Write-Host "`n[Detection Completed] Press Enter to exit (检测完成，按回车键退出)..." -ForegroundColor Cyan
        Read-Host
    }
    exit $exitCode
}


try {
    Main
} catch {
    Write-Output "summary: error"
    Write-Output "error: $_"
    exit 2
}
