# OpenClaw Detection Script for MDM deployment (Windows)
# Version: v1.1 - Ultimate Compatibility Build (PS 2.0+)
# All source code is 100% ASCII to prevent parser compatibility.

$ErrorActionPreference = "Continue"

# Encoding Setup for Legacy PowerShell
if ($PSVersionTable.PSVersion.Major -le 5) {
    try {
        $utf8 = New-Object System.Text.UTF8Encoding $false
        $OutputEncoding = $utf8
        [Console]::OutputEncoding = $utf8
    } catch { }
}

# Unicode Dictionary (All characters escaped)
$CN = @{
    'EnvInfo'    = "$([char]0x73af)$([char]0x5883)$([char]0x57fa)$([char]0x672c)$([char]0x4fe1)$([char]0x606f)" # 环境基本信息
    'OSVer'      = "$([char]0x64cd)$([char]0x4f5c)$([char]0x7cfb)$([char]0x7edf)$([char]0x7248)$([char]0x672c)" # 操作系统版本
    'User'       = "$([char]0x5f53)$([char]0x524d)$([char]0x7528)$([char]0x6237)" # 当前用户
    'UserTag'    = "$([char]0x7528)$([char]0x6237)" # 用户
    'IP'         = "IP$([char]0x5730)$([char]0x5740)" # IP地址
    'Summary'    = "$([char]0x68c0)$([char]0x6d4b)$([char]0x6c47)$([char]0x603b)" # 检测汇总
    'NotInst'    = "$([char]0x672a)$([char]0x5b89)$([char]0x88c5)" # 未安装
    'InstRun'    = "$([char]0x5df2)$([char]0x5b89)$([char]0x88c5)$([char]0x4e14)$([char]0x8fd0)$([char]0x884c)$([char]0x4e2d)" # 已安装且运行中
    'InstNotRun' = "$([char]0x5df2)$([char]0x5b89)$([char]0x88c5)$([char]0x4f46)$([char]0x672a)$([char]0x8fd0)$([char]0x884c)" # 已安装但未运行
    'Platform'   = "$([char]0x5e73)$([char]0x53f0)" # 平台
    'CLI'        = "$([char]0x547d)$([char]0x4ee4)$([char]0x884c)$([char]0x5de5)$([char]0x5177)" # 命令行工具
    'CLIVer'     = "$([char]0x5de5)$([char]0x5177)$([char]0x7248)$([char]0x672c)" # 工具版本
    'App'        = "$([char]0x5e94)$([char]0x7528)$([char]0x7a0b)$([char]0x5e8f)" # 应用程序
    'StateDir'   = "$([char]0x72b6)$([char]0x6001)$([char]0x76ee)$([char]0x5f55)" # 状态目录
    'Config'     = "$([char]0x914d)$([char]0x7f6e)$([char]0x6587)$([char]0x4ef6)" # 配置文件
    'Port'       = "$([char]0x914d)$([char]0x7f6e)$([char]0x7aef)$([char]0x53e3)" # 配置端口
    'Service'    = "$([char]0x7f51)$([char]0x5173)$([char]0x670d)$([char]0x52a1)" # 网关服务
    'Process'    = "$([char]0x8fdb)$([char]0x7a0b)" # 进程
    'GwPort'     = "$([char]0x7f51)$([char]0x5173)$([char]0x7aef)$([char]0x53e3)" # 网关端口
    'DockerCon'  = "Docker$([char]0x5bb9)$([char]0x5668)" # Docker容器
    'DockerImg'  = "Docker$([char]0x955c)$([char]0x50cf)" # Docker镜像
    'ExitMsg'    = "$([char]0x68c0)$([char]0x6d4b)$([char]0x5b8c)$([char]0x6210)$([char]0xff0c)$([char]0x6309)$([char]0x56de)$([char]0x8f66)$([char]0x952e)$([char]0x9000)$([char]0x51fa)" # 检测完成，按回车键退出
    'NotFound'   = "not-found ($([char]0x672a)$([char]0x627e)$([char]0x5230))" # not-found (未找到)
    'NotListen'  = "not-listening ($([char]0x672a)$([char]0x76d1)$([char]0x542c))" # not-listening (未监听)
    'NotSched'   = "not-scheduled ($([char]0x672a)$([char]0x8ba1)$([char]0x5212))" # not-scheduled (未计划)
    'Running'    = "running ($([char]0x8fd0)$([char]0x884c)$([char]0x4e2d))" # running (运行中)
    'NotRunning' = "not-running ($([char]0x672a)$([char]0x8fd0)$([char]0x884c))" # not-running (未运行)
}

function Write-Safe {
    param($Message, $Color)
    if ($Color) {
        try { Write-Host $Message -ForegroundColor $Color } catch { Write-Output $Message }
    } else {
        try { Write-Host $Message } catch { Write-Output $Message }
    }
}

$script:ProfileName = $env:OPENCLAW_PROFILE
$script:DefaultPort = 18789
if ($env:OPENCLAW_GATEWAY_PORT) {
    try { $script:DefaultPort = [int]$env:OPENCLAW_GATEWAY_PORT } catch { }
}
$script:OutputList = @()

function Add-ToOutput {
    param($Line)
    $script:OutputList += $Line
}

function Show-EnvInfo {
    Write-Safe "`n--- Environment Information ($($CN.EnvInfo)) ---"
    $osInfo = "Unknown"
    try {
        $osObj = Get-WmiObject Win32_OperatingSystem -ErrorAction SilentlyContinue
        $osInfo = $osObj.Caption + " (" + $osObj.Version + ")"
    } catch {
        $osInfo = [System.Environment]::OSVersion.ToString()
    }
    Write-Safe ("OS Version (" + $CN.OSVer + "): " + $osInfo)
    $currUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $isAdmin = "User"
    if ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544') { $isAdmin = "Admin" }
    Write-Safe ("Current User (" + $CN.User + "): " + $currUser + " (" + $isAdmin + ")")
    $v4List = ""; $v6List = ""
    try {
        $configs = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
        foreach ($c in $configs) {
            foreach ($addr in $c.IPAddress) {
                if ($addr -match '^([0-9]{1,3}\.){3}[0-9]{1,3}$') {
                    if ($addr -notmatch '^127\.' -and $addr -notmatch '^169\.254') {
                        if ($v4List) { $v4List += ", " }
                        $v4List += $addr
                    }
                } else {
                    if ($addr -notmatch '^::1' -and $addr -notmatch '^fe80') {
                        if ($v6List) { $v6List += ", " }
                        $v6List += $addr
                    }
                }
            }
        }
    } catch { }
    Write-Safe ("IP Address (" + $CN.IP + "):")
    Write-Safe ("  IPv4: " + $(if ($v4List) { $v4List } else { 'N/A' }))
    Write-Safe ("  IPv6: " + $(if ($v6List) { $v6List } else { 'N/A' }))
    Write-Safe "-------------------------------"
}

function Get-StateDir {
    param($HomeDir)
    if ($script:ProfileName) { return Join-Path $HomeDir (".openclaw-" + $script:ProfileName) }
    return Join-Path $HomeDir ".openclaw"
}

function Get-UsersToCheck {
    $foundUsers = @()
    try {
        if ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544') {
            $excluded = @('Public', 'Default', 'Default User', 'All Users')
            $userDirs = Get-ChildItem "C:\Users" | Where-Object { $_.PSIsContainer }
            foreach ($d in $userDirs) {
                if ($excluded -notcontains $d.Name) { $foundUsers += $d.Name }
            }
            if ($foundUsers.Length -gt 0) { return $foundUsers }
        }
    } catch { }
    return ,$env:USERNAME
}

function Get-CliVersion {
    param($CliPath)
    try {
        $ver = & $CliPath --version 2>$null | Select-Object -First 1
        if ($ver) { return $ver }
    } catch { }
    return "unknown"
}

function Test-GatewayPort {
    param($PortNum)
    $success = $false
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $asyncResult = $tcp.BeginConnect("127.0.0.1", $PortNum, $null, $null)
        $wait = $asyncResult.AsyncWaitHandle.WaitOne(100, $false)
        if ($wait) {
            $tcp.EndConnect($asyncResult)
            $success = $true
        }
        $tcp.Close()
    } catch { $success = $false }
    return $success
}

function Get-DockerContainers {
    try {
        $cmd = Get-Command docker -ErrorAction SilentlyContinue
        if (-not $cmd) { return $null }
        $res = docker ps --format '{{.Names}} ({{.Image}})' 2>$null | Select-String -Pattern "openclaw" -SimpleMatch
        if ($res) { return ($res -join ", ") }
    } catch { }
    return $null
}

function Get-DockerImages {
    try {
        $cmd = Get-Command docker -ErrorAction SilentlyContinue
        if (-not $cmd) { return $null }
        $res = docker images --format '{{.Repository}}:{{.Tag}}' 2>$null | Select-String -Pattern "openclaw" -SimpleMatch
        if ($res) { return ($res -join ", ") }
    } catch { }
    return $null
}

function Main {
    Write-Safe "OpenClaw Detection Script (v1.1)"
    Show-EnvInfo

    $cliFound = $false; $stateFound = $false; $serviceRunning = $false; $portListening = $false; $processRunning = $false
    $dockerRunning = $false; $dockerInstalled = $false
    Add-ToOutput ("platform (" + $CN.Platform + "): windows")

    $gCli = $null
    $cCheck = Get-Command openclaw -ErrorAction SilentlyContinue
    if ($cCheck) { $gCli = $cCheck.Definition }
    if (-not $gCli) {
        $locs = @("C:\Program Files\openclaw\openclaw.exe", "C:\Program Files (x86)\openclaw\openclaw.exe")
        foreach ($l in $locs) { if (Test-Path $l) { $gCli = $l; break } }
    }
    if ($gCli) {
        $cliFound = $true
        Add-ToOutput ("cli (" + $CN.CLI + "): " + $gCli)
        Add-ToOutput ("cli-version (" + $CN.CLIVer + "): " + (Get-CliVersion $gCli))
    }

    $allUsersList = Get-UsersToCheck
    $isMulti = $false
    if (@($allUsersList).Count -gt 1) { $isMulti = $true }
    $portsToCheck = @($script:DefaultPort)

    foreach ($u in $allUsersList) {
        $hDir = "C:\Users\$u"
        $sDir = Get-StateDir $hDir
        $cFile = Join-Path $sDir "openclaw.json"
        $uHeaderDone = $false

        # Check user-specific CLI paths regardless of global findings
        $uLocs = @(
            (Join-Path $hDir "AppData\Local\Programs\openclaw\openclaw.exe"),
            (Join-Path $hDir "AppData\Roaming\npm\openclaw.cmd"),
            (Join-Path $hDir "AppData\Local\pnpm\openclaw.cmd"),
            (Join-Path $hDir ".volta\bin\openclaw.exe"),
            (Join-Path $hDir "scoop\shims\openclaw.exe")
        )
        foreach ($ul in $uLocs) {
            if (Test-Path $ul) {
                $cliFound = $true
                if ($isMulti) { Add-ToOutput ("user (" + $CN.UserTag + "): " + $u); $uHeaderDone = $true }
                Add-ToOutput ("  cli (" + $CN.CLI + "): " + $ul)
                Add-ToOutput ("  cli-version (" + $CN.CLIVer + "): " + (Get-CliVersion $ul))
                break
            }
        }

        $sExist = Test-Path $sDir
        if ($sExist) { $stateFound = $true }

        if ($isMulti) {
            if ($sExist) {
                if (-not $uHeaderDone) { Add-ToOutput ("user (" + $CN.UserTag + "): " + $u); $uHeaderDone = $true }
                Add-ToOutput ("  state-dir (" + $CN.StateDir + "): " + $sDir)
                if (Test-Path $cFile) {
                    Add-ToOutput ("  config (" + $CN.Config + "): " + $cFile)
                    try {
                        $txt = Get-Content $cFile | Out-String
                        if ($txt -match '"port"\s*:\s*(\d+)') {
                            $pNum = [int]$matches[1]
                            Add-ToOutput ("  config-port (" + $CN.Port + "): " + $pNum)
                            $fIn = $false
                            foreach($pt in $portsToCheck) { if($pt -eq $pNum) { $fIn = $true } }
                            if(-not $fIn) { $portsToCheck += $pNum }
                        }
                    } catch { }
                } else { Add-ToOutput ("  config (" + $CN.Config + "): " + $CN.NotFound) }
            }
        } else {
            Add-ToOutput ("state-dir (" + $CN.StateDir + "): " + $(if ($sExist) { $sDir } else { $CN.NotFound }))
            if (Test-Path $cFile) {
                Add-ToOutput ("config (" + $CN.Config + "): " + $cFile)
                try {
                    $txt = Get-Content $cFile | Out-String
                    if ($txt -match '"port"\s*:\s*(\d+)') {
                        $pNum = [int]$matches[1]
                        Add-ToOutput ("config-port (" + $CN.Port + "): " + $pNum)
                        if ($portsToCheck -notcontains $pNum) { $portsToCheck += $pNum }
                    }
                } catch { }
            } else { Add-ToOutput ("config (" + $CN.Config + "): " + $CN.NotFound) }
        }
    }

    if (-not $cliFound) {
        Add-ToOutput ("cli (" + $CN.CLI + "): " + $CN.NotFound)
        if (-not $isMulti) { Add-ToOutput ("cli-version (" + $CN.CLIVer + "): n/a") }
    }

    $tName = "OpenClaw Gateway"
    if ($script:ProfileName) { $tName = "OpenClaw Gateway " + $script:ProfileName }
    $tCheck = schtasks /Query /TN $tName 2>$null
    if ($LASTEXITCODE -eq 0) { $serviceRunning = $true; Add-ToOutput ("gateway-service (" + $CN.Service + "): " + $tName) }
    else { Add-ToOutput ("gateway-service (" + $CN.Service + "): " + $CN.NotSched) }

    $pCheck = Get-Process -Name "openclaw" -ErrorAction SilentlyContinue
    if ($pCheck) { $processRunning = $true; Add-ToOutput ("process (" + $CN.Process + "): " + $CN.Running) }
    else { Add-ToOutput ("process (" + $CN.Process + "): " + $CN.NotRunning) }

    $fPortStr = $CN.NotListen
    foreach ($pt in $portsToCheck) {
        if (Test-GatewayPort $pt) {
            $portListening = $true
            $fPortStr = $pt.ToString() + " ($([char]0x6b63)$([char]0x5728)$([char]0x76d1)$([char]0x542c))" # (正在监听)
            break
        }
    }
    Add-ToOutput ("gateway-port (" + $CN.GwPort + "): " + $fPortStr)

    $dCons = Get-DockerContainers
    if ($dCons) { $dockerRunning = $true; Add-ToOutput ("docker-container (" + $CN.DockerCon + "): " + $dCons) }
    else { Add-ToOutput ("docker-container (" + $CN.DockerCon + "): " + $CN.NotFound) }

    $dImgs = Get-DockerImages
    if ($dImgs) { $dockerInstalled = $true; Add-ToOutput ("docker-image (" + $CN.DockerImg + "): " + $dImgs) }
    else { Add-ToOutput ("docker-image (" + $CN.DockerImg + "): " + $CN.NotFound) }

    $isInst = ($cliFound -or $stateFound -or $dockerInstalled)
    $isRun = ($serviceRunning -or $portListening -or $processRunning -or $dockerRunning)

    if (-not $isInst) {
        Write-Safe ("`nsummary (" + $CN.Summary + "): not-installed (" + $CN.NotInst + ")")
        $exitCode = 0
    } elseif ($isRun) {
        Write-Safe ("`nsummary (" + $CN.Summary + "): installed-and-running (" + $CN.InstRun + ")")
        $exitCode = 1
    } else {
        Write-Safe ("`nsummary (" + $CN.Summary + "): installed-not-running (" + $CN.InstNotRun + ")")
        $exitCode = 1
    }

    foreach ($line in $script:OutputList) { Write-Safe $line }

    if ($Host.Name -match "ConsoleHost|Default Host") {
        Write-Safe ("`n[Detection Completed] Press Enter to exit (" + $CN.ExitMsg + ")...") "Cyan"
        $null = Read-Host
    }
    exit $exitCode
}

try { Main } catch {
    Write-Output ("summary (" + $CN.Summary + "): error")
    Write-Output ("error: " + $_)
    exit 2
}
