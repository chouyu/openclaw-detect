# OpenClaw Detection Script for MDM deployment (Windows)
# Exit codes: 0=not-installed (clean), 1=found (non-compliant), 2=error

$ErrorActionPreference = "Stop"

# 强制旧版 PowerShell 使用 UTF-8 编码
if ($PSVersionTable.PSVersion.Major -le 5) {
    try {
        & chcp 65001 | Out-Null
        $utf8 = New-Object System.Text.UTF8Encoding $false
        $OutputEncoding = $utf8
        [Console]::OutputEncoding = $utf8
        [Console]::InputEncoding = $utf8
    } catch {}
}

# 使用 Unicode 转义序列定义中文词典，确保脚本源码为纯 ASCII，防止 iex 乱码报错
$CN = @{
    'EnvInfo'    = "$([char]0x73af)$([char]0x5883)$([char]0x57fa)$([char]0x672c)$([char]0x4fe1)$([char]0x606f)" # 环境基本信息
    'OSVer'      = "$([char]0x64cd)$([char]0x4f5c)$([char]0x7cfb)$([char]0x7edf)$([char]0x7248)$([char]0x672c)" # 操作系统版本
    'User'       = "$([char]0x5f53)$([char]0x524d)$([char]0x7528)$([char]0x6237)" # 当前用户
    'IP'         = "IP$([char]0x5730)$([char]0x5740)" # IP地址
    'Summary'    = "$([char]0x68c0)$([char]0x6d4b)$([char]0x6c47)$([char]0x603b)" # 检测汇总
    'NotInst'    = "$([char]0x672a)$([char]0x5b89)$([char]0x88c5)" # 未安装
    'InstRun'    = "$([char]0x5df2)$([char]0x5b89)$([char]0x88c5)$([char]0x4e14)$([char]0x8fd0)$([char]0x884c)$([char]0x4e2d)" # 已安装且运行中
    'InstNotRun' = "$([char]0x5df2)$([char]0x5b89)$([char]0x88c5)$([char]0x4e46)$([char]0x672a)$([char]0x8fd0)$([char]0x884c)" # 已安装但未运行
    'Platform'   = "$([char]0x5e73)$([char]0x53f0)" # 平台
    'CLI'        = "$([char]0x547d)$([char]0x4ee4)$([char]0x884c)$([char]0x5de5)$([char]0x5177)" # 命令行工具
    'CLIVer'     = "$([char]0x5de5)$([char]0x5177)$([char]0x7248)$([char]0x672c)" # 工具版本
    'App'        = "$([char]0x5e94)$([char]0x7528)$([char]0x7a0b)$([char]0x5e8f)" # 应用程序
    'StateDir'   = "$([char]0x72b6)$([char]0x6001)$([char]0x76ee)$([char]0x5f53)$([char]0x5f55)" # 状态目录
    'Config'     = "$([char]0x914d)$([char]0x7f6e)$([char]0x6587)$([char]0x4ef6)" # 配置文件
    'Port'       = "$([char]0x914d)$([char]0x7f6e)$([char]0x7aef)$([char]0x53e3)" # 配置端口
    'Service'    = "$([char]0x7f51)$([char]0x5173)$([char]0x670d)$([char]0x52a1)" # 网关服务
    'Process'    = "$([char]0x8fdb)$([char]0x7a0b)" # 进程
    'GwPort'     = "$([char]0x7f51)$([char]0x5173)$([char]0x7aef)$([char]0x53e3)" # 网关端口
    'DockerCon'  = "Docker$([char]0x5bb9)$([char]0x5668)" # Docker容器
    'DockerImg'  = "Docker$([char]0x955c)$([char]0x50cf)" # Docker镜像
    'ExitMsg'    = "$([char]0x68c0)$([char]0x6d4b)$([char]0x5b8c)$([char]0x6210)$([char]0xff0c)$([char]0x6309)$([char]0x56de)$([char]0x8f66)$([char]0x952e)$([char]0x9000)$([char]0x51fa)" # 检测完成，按回车键退出
}

$script:Profile = $env:OPENCLAW_PROFILE
$Port = if ($env:OPENCLAW_GATEWAY_PORT) { $env:OPENCLAW_GATEWAY_PORT } else { 18789 }
$script:Output = New-Object System.Collections.ArrayList

function Show-Banner {
    Write-Output "OpenClaw Detection Script (v1.1)`n"
}

Show-Banner

function Show-EnvInfo {
    Write-Host "--- Environment Information ($($CN.EnvInfo)) ---"
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        Write-Host "OS Version ($($CN.OSVer)): $($os.Caption) ($($os.Version))"
    } catch {
        try {
            $os = Get-WmiObject Win32_OperatingSystem -ErrorAction Stop
            Write-Host "OS Version ($($CN.OSVer)): $($os.Caption) ($($os.Version))"
        } catch {
            Write-Host "OS Version ($($CN.OSVer)): $([System.Environment]::OSVersion)"
        }
    }
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $isAdmin = if ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544') { "Admin" } else { "User" }
    Write-Host "Current User ($($CN.User)): $currentUser ($isAdmin)"
    
    try {
        if (Get-Command Get-NetIPAddress -ErrorAction SilentlyContinue) {
            $ips = Get-NetIPAddress | Where-Object { 
                $_.InterfaceAlias -notmatch 'Loopback' -and 
                $_.IPAddress -notmatch '^169\.254' -and 
                $_.IPAddress -notmatch '^fe80' 
            }
            $ipv4List = ($ips | Where-Object { $_.AddressFamily -eq 'IPv4' }).IPAddress -join ", "
            $ipv6List = ($ips | Where-Object { $_.AddressFamily -eq 'IPv6' }).IPAddress -join ", "
        } else {
            $configs = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
            $ipv4s = New-Object System.Collections.ArrayList
            $ipv6s = New-Object System.Collections.ArrayList
            foreach ($conf in $configs) {
                foreach ($addr in $conf.IPAddress) {
                    if ($addr -match '^([0-9]{1,3}\.){3}[0-9]{1,3}$') {
                        if ($addr -notmatch '^127\.' -and $addr -notmatch '^169\.254') { [void]$ipv4s.Add($addr) }
                    } else {
                        if ($addr -notmatch '^::1' -and $addr -notmatch '^fe80') { [void]$ipv6s.Add($addr) }
                    }
                }
            }
            $ipv4List = $ipv4s -join ", "
            $ipv6List = $ipv6s -join ", "
        }
        
        Write-Host "IP Address ($($CN.IP)):"
        Write-Host "  IPv4: $(if ($ipv4List) { $ipv4List } else { 'N/A' })"
        Write-Host "  IPv6: $(if ($ipv6List) { $ipv6List } else { 'N/A' })"
    } catch {
        Write-Host "IP Address ($($CN.IP)): Unknown"
    }
    Write-Host "-------------------------------`n"
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
        $excluded = @('Public', 'Default', 'Default User', 'All Users')
        Get-ChildItem "C:\Users" -Directory | Where-Object { $excluded -notcontains $_.Name } | ForEach-Object { $_.Name }
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
        if ($cmd) { return $cmd.Source }
    } catch {}
    return $null
}

function Test-CliGlobal {
    $locations = @(
        "C:\Program Files\openclaw\openclaw.exe",
        "C:\Program Files (x86)\openclaw\openclaw.exe"
    )
    foreach ($loc in $locations) {
        if (Test-Path $loc) { return $loc }
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
        if (Test-Path $loc) { return $loc }
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
            if ($content -match '"port"\s*:\s*(\d+)') { return $matches[1] }
        } catch {}
    }
    return $null
}

function Test-ScheduledTask {
    $taskName = if ($script:Profile) { "OpenClaw Gateway $($script:Profile)" } else { "OpenClaw Gateway" }
    try {
        $null = schtasks /Query /TN $taskName 2>$null
        if ($LASTEXITCODE -eq 0) { return $taskName }
    } catch {}
    return $null
}

function Test-Process {
    try {
        $proc = Get-Process -Name "openclaw" -ErrorAction SilentlyContinue
        if ($proc) { return "running" }
    } catch {}
    return "not-running"
}

function Test-GatewayPort {
    param([int]$PortNum)
    try {
        $result = Test-NetConnection -ComputerName localhost -Port $PortNum -WarningAction SilentlyContinue
        return $result.TcpTestSucceeded
    } catch { return $false }
}

function Get-DockerContainers {
    try {
        $cmd = Get-Command docker -ErrorAction SilentlyContinue
        if (-not $cmd) { return $null }
        $containers = docker ps --format '{{.Names}} ({{.Image}})' 2>$null | Select-String -Pattern "openclaw" -SimpleMatch
        if ($containers) { return ($containers -join ", ") }
    } catch {}
    return $null
}

function Get-DockerImages {
    try {
        $cmd = Get-Command docker -ErrorAction SilentlyContinue
        if (-not $cmd) { return $null }
        $images = docker images --format '{{.Repository}}:{{.Tag}}' 2>$null | Select-String -Pattern "openclaw" -SimpleMatch
        if ($images) { return ($images -join ", ") }
    } catch {}
    return $null
}

function Main {
    $cliFound = $false; $stateFound = $false; $serviceRunning = $false; $portListening = $false; $processRunning = $false
    Out "platform ($($CN.Platform)): windows"

    $cliPath = Test-CliInPath
    if (-not $cliPath) { $cliPath = Test-CliGlobal }
    if ($cliPath) {
        $cliFound = $true
        Out "cli ($($CN.CLI)): $cliPath"
        Out "cli-version ($($CN.CLIVer)): $(Get-CliVersion $cliPath)"
    }

    $users = @(Get-UsersToCheck)
    $multiUser = $users.Count -gt 1
    $portsToCheck = @($Port)

    foreach ($user in $users) {
        $homeDir = Get-HomeDir $user
        $stateDir = Get-StateDir $homeDir
        $configFile = Join-Path $stateDir "openclaw.json"

        if ($multiUser) {
            Out "user ($([char]0x7528)$([char]0x6237)): $user"
            if (-not $cliFound) {
                $userCli = Test-CliForUser $homeDir
                if ($userCli) {
                    $cliFound = $true
                    Out "  cli ($($CN.CLI)): $userCli"
                    Out "  cli-version ($($CN.CLIVer)): $(Get-CliVersion $userCli)"
                }
            }
            if (Test-StateDir $stateDir) { Out "  state-dir ($($CN.StateDir)): $stateDir"; $stateFound = $true } else { Out "  state-dir ($($CN.StateDir)): not-found" }
            if (Test-Config $stateDir) { Out "  config ($($CN.Config)): $configFile" } else { Out "  config ($($CN.Config)): not-found" }
            $configPort = Get-ConfiguredPort $configFile
            if ($configPort) { Out "  config-port ($($CN.Port)): $configPort"; $portsToCheck += [int]$configPort }
        } else {
            if (-not $cliFound) {
                $userCli = Test-CliForUser $homeDir
                if ($userCli) {
                    $cliFound = $true
                    Out "cli ($($CN.CLI)): $userCli"
                    Out "cli-version ($($CN.CLIVer)): $(Get-CliVersion $userCli)"
                }
            }
            if (-not $cliFound) { Out "cli ($($CN.CLI)): not-found"; Out "cli-version ($($CN.CLIVer)): n/a" }
            if (Test-StateDir $stateDir) { Out "state-dir ($($CN.StateDir)): $stateDir"; $stateFound = $true } else { Out "state-dir ($($CN.StateDir)): not-found" }
            if (Test-Config $stateDir) { Out "config ($($CN.Config)): $configFile" } else { Out "config ($($CN.Config)): not-found" }
            $configPort = Get-ConfiguredPort $configFile
            if ($configPort) { Out "config-port ($($CN.Port)): $configPort"; $portsToCheck += [int]$configPort }
        }
    }

    if ($multiUser -and -not $cliFound) { Out "cli ($($CN.CLI)): not-found"; Out "cli-version ($($CN.CLIVer)): n/a" }

    $taskResult = Test-ScheduledTask
    if ($taskResult) { Out "gateway-service ($($CN.Service)): $taskResult"; $serviceRunning = $true } else { Out "gateway-service ($($CN.Service)): not-scheduled" }

    $processResult = Test-Process
    if ($processResult -eq "running") { Out "process ($($CN.Process)): running"; $processRunning = $true } else { Out "process ($($CN.Process)): not-running" }

    $uniquePorts = $portsToCheck | Sort-Object -Unique
    $listeningPort = $null
    foreach ($p in $uniquePorts) { if (Test-GatewayPort $p) { $portListening = $true; $listeningPort = $p; break } }
    if ($portListening) { Out "gateway-port ($($CN.GwPort)): $listeningPort" } else { Out "gateway-port ($($CN.GwPort)): not-listening" }

    $dockerContainers = Get-DockerContainers
    if ($dockerContainers) { Out "docker-container ($($CN.DockerCon)): $dockerContainers"; $dockerRunning = $true } else { Out "docker-container ($($CN.DockerCon)): not-found" }

    $dockerImages = Get-DockerImages
    if ($dockerImages) { Out "docker-image ($($CN.DockerImg)): $dockerImages"; $dockerInstalled = $true } else { Out "docker-image ($($CN.DockerImg)): not-found" }

    $installed = $cliFound -or $stateFound -or $dockerInstalled
    $running = $serviceRunning -or $portListening -or $dockerRunning -or $processRunning

    if (-not $installed) {
        Write-Host "summary ($($CN.Summary)): not-installed ($($CN.NotInst))"
        $script:Output | ForEach-Object { Write-Host $_ }
        $exitCode = 0
    } elseif ($running) {
        Write-Host "summary ($($CN.Summary)): installed-and-running ($($CN.InstRun))"
        $script:Output | ForEach-Object { Write-Host $_ }
        $exitCode = 1
    } else {
        Write-Host "summary ($($CN.Summary)): installed-not-running ($($CN.InstNotRun))"
        $script:Output | ForEach-Object { Write-Host $_ }
        $exitCode = 1
    }

    if ($Host.Name -eq "ConsoleHost") {
        Write-Host "`n[Detection Completed] Press Enter to exit ($($CN.ExitMsg))..." -ForegroundColor Cyan
        Read-Host
    }
    exit $exitCode
}

try { Main } catch {
    Write-Host "summary ($($CN.Summary)): error"
    Write-Host "error: $_"
    exit 2
}
