<#
.SYNOPSIS
  Run the local MinIO and Mailpit dev services natively on Windows (no Docker, no admin rights).

.DESCRIPTION
  Replaces the `minio` and `mailpit` services of infra/docker-compose.yml on the Windows dev
  machine (user approval 2026-11-04). Idempotent: every action can be repeated safely.

    start   download + verify the pinned binaries if missing, then start the services that are not
            already running (hidden background processes, logs in the data folder)
    stop    stop the services started from the tools folder (matched by executable path; nothing
            else is touched)
    status  show which services run and what listens on their ports
    init    create the MinIO buckets + public-read policy and verify them
            (runs infra/scripts/minio_buckets.py through the backend's uv environment)

  Layout (outside the repo):
    %USERPROFILE%\.local\share\jivoqc-tools\<tool>\<version>\*.exe   pinned binaries
    %USERPROFILE%\.local\share\jivoqc-tools\data\{minio,mailpit,logs}  data and logs

  Ports (127.0.0.1 only): MinIO API 9000, console 9001; Mailpit SMTP 1025, UI 8025.

  Downloads come only from the official sources and must match the sha256 pinned below, or the
  script stops. Upgrading = change Version + Url + Sha256 together, in a reviewed change.

  MinIO: dl.min.io answers "410 Gone" for every community build (checked 2026-11-04: upstream
  open-source MinIO is archived). The user approved (2026-11-04) the pgsty community build from
  its GitHub releases, the same build as the compose image, for LOCAL DEV ONLY (no upstream
  security fixes). No mc is published there; `init` uses boto3 instead.

.PARAMETER Action
  start | stop | status | init

.PARAMETER Service
  all (default) | minio | mailpit

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File infra\scripts\windows\dev-services.ps1 -Action start
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File infra\scripts\windows\dev-services.ps1 -Action status -Service mailpit
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('start', 'stop', 'status', 'init')][string]$Action,
    [ValidateSet('all', 'minio', 'mailpit')][string]$Service = 'all'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = Join-Path $env:USERPROFILE '.local\share\jivoqc-tools'
$Data = Join-Path $Root 'data'
$Logs = Join-Path $Data 'logs'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

# Pinned releases. Sha256 is of the downloaded file (archive or exe).
$Pins = @{
    mailpit = @{
        Version = 'v1.33.0'
        Url     = 'https://github.com/axllent/mailpit/releases/download/v1.33.0/mailpit-windows-amd64.zip'
        # GitHub release-asset digest published for this file (the release ships no checksum file).
        Sha256  = '47122dd828ff80dcaef62b2952c478b178afadadf066c990489608e537121bfd'
        Exe     = 'mailpit.exe'
    }
    minio   = @{
        # pgsty community build (github.com/pgsty/minio, renamed pgsty/silo; same repo id), the
        # same release as the compose image. Upstream MinIO is archived: LOCAL DEV ONLY.
        # Sha256 = GitHub release-asset digest, equal to the release's *_checksums.txt entry.
        Version = 'RELEASE.2026-08-04T00-00-00Z'
        Url     = 'https://github.com/pgsty/silo/releases/download/RELEASE.2026-08-04T00-00-00Z/minio_20260804000000.0.0_windows_amd64.tar.gz'
        Sha256  = 'c2160a4ccbb80ce1d45f69cc35137cb5ba68f638cc2f86ebfb3d0523ce3e0d74'
        Exe     = 'minio.exe'
    }
}

# Same defaults as infra/docker-compose.yml and backend/config/settings/local.py; real values
# from the environment win (MINIO_ROOT_USER / MINIO_ROOT_PASSWORD must equal S3_ACCESS_KEY_ID /
# S3_SECRET_ACCESS_KEY in backend/.env if those are set there).
function Get-MinioCredential {
    $user = if ($env:MINIO_ROOT_USER) { $env:MINIO_ROOT_USER } else { 'jivo-local' }
    $pass = if ($env:MINIO_ROOT_PASSWORD) { $env:MINIO_ROOT_PASSWORD } else { 'jivo-local-minio-secret' }
    return @($user, $pass)
}

$Services = [ordered]@{
    minio   = @{ Ports = @(9000, 9001); Health = 'http://127.0.0.1:9000/minio/health/live' }
    mailpit = @{ Ports = @(1025, 8025); Health = 'http://127.0.0.1:8025/readyz' }
}

function Get-ExePath([string]$name) {
    $p = $Pins[$name]
    if (-not $p.Version) { return $null }
    return Join-Path $Root "$name\$($p.Version)\$($p.Exe)"
}

function Install-Tool([string]$name) {
    $p = $Pins[$name]
    $exe = Get-ExePath $name
    if (-not $exe) {
        Write-Warning "${name}: no approved download source pinned (dl.min.io serves 410 Gone). Skipped."
        return $false
    }
    if (Test-Path -LiteralPath $exe) { return $true }

    $dest = Split-Path $exe -Parent
    $stage = Join-Path $Root ("_download-$name-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $stage | Out-Null
    try {
        $file = Join-Path $stage ([IO.Path]::GetFileName(([uri]$p.Url).AbsolutePath))
        Write-Host "${name}: downloading $($p.Url)"
        & curl.exe -fsSL --proto '=https' --tlsv1.2 -o $file $p.Url
        if ($LASTEXITCODE -ne 0) { throw "${name}: download failed (curl exit $LASTEXITCODE)" }
        $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash.ToLowerInvariant()
        if ($actual -ne $p.Sha256.ToLowerInvariant()) {
            throw "${name}: SHA256 MISMATCH (expected $($p.Sha256), got $actual). Nothing installed."
        }
        Write-Host "${name}: sha256 verified $actual"
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        if ($file.EndsWith('.zip') -or $file.EndsWith('.tar.gz')) {
            $unz = Join-Path $stage 'unzip'
            New-Item -ItemType Directory -Force -Path $unz | Out-Null
            if ($file.EndsWith('.zip')) {
                Expand-Archive -LiteralPath $file -DestinationPath $unz
            } else {
                & "$env:SystemRoot\System32\tar.exe" -xzf $file -C $unz
                if ($LASTEXITCODE -ne 0) { throw "${name}: tar extraction failed ($LASTEXITCODE)" }
            }
            $found = Get-ChildItem -LiteralPath $unz -Recurse -Filter $p.Exe | Select-Object -First 1
            if (-not $found) { throw "${name}: $($p.Exe) not found in archive" }
            Copy-Item -LiteralPath $found.FullName -Destination $exe
        } else {
            Copy-Item -LiteralPath $file -Destination $exe
        }
        Write-Host "${name}: installed $exe"
        return $true
    } finally {
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Our processes only: matched by the full executable path inside the tools folder.
function Get-ToolProcess([string]$name) {
    $exe = Get-ExePath $name
    if (-not $exe) { return @() }
    $all = Get-CimInstance Win32_Process -Filter ("Name = '{0}'" -f $Pins[$name].Exe)
    return @($all | Where-Object { $_.ExecutablePath -and ($_.ExecutablePath -ieq $exe) })
}

function Get-Listener([int[]]$ports) {
    return @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Where-Object { $ports -contains $_.LocalPort })
}

# Win32_Process.Create starts the process outside this shell's job, so it keeps running after the
# shell (or an agent's tool call) exits. cmd.exe only redirects output to the log, then waits.
function Start-Detached([string]$commandLine, [string]$workDir) {
    $startup = New-CimInstance -ClassName Win32_ProcessStartup -ClientOnly -Property @{ ShowWindow = [uint16]0 }
    $r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
        CommandLine = $commandLine; CurrentDirectory = $workDir; ProcessStartupInformation = $startup
    }
    if ($r.ReturnValue -ne 0) { throw "Win32_Process.Create failed ($($r.ReturnValue))" }
}

function Wait-Healthy([string]$name, [int]$seconds = 20) {
    $url = $Services[$name].Health
    for ($i = 0; $i -lt $seconds; $i++) {
        & curl.exe -fsS -o NUL -m 2 $url 2>$null
        if ($LASTEXITCODE -eq 0) { return $true }
        Start-Sleep -Seconds 1
    }
    return $false
}

function Start-Tool([string]$name) {
    if (-not (Install-Tool $name)) { return $false }
    if (@(Get-ToolProcess $name).Count -gt 0) { Write-Host "${name}: already running"; return $true }
    $busy = @(Get-Listener $Services[$name].Ports)
    if ($busy.Count -gt 0) {
        $owners = ($busy | ForEach-Object { "$($_.LocalAddress):$($_.LocalPort) pid $($_.OwningProcess)" }) -join ', '
        Write-Warning "${name}: port(s) already taken by another process ($owners). Not starting."
        return $false
    }
    New-Item -ItemType Directory -Force -Path $Logs | Out-Null
    $exe = Get-ExePath $name
    $log = Join-Path $Logs "$name.log"
    switch ($name) {
        'mailpit' {
            $dir = Join-Path $Data 'mailpit'
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            $db = Join-Path $dir 'mailpit.db'
            $cmd = "`"$exe`" --listen 127.0.0.1:8025 --smtp 127.0.0.1:1025 --database `"$db`""
            $prefix = ''
        }
        'minio' {
            $dir = Join-Path $Data 'minio'
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            $cred = Get-MinioCredential
            $cmd = "`"$exe`" server `"$dir`" --address 127.0.0.1:9000 --console-address 127.0.0.1:9001"
            $prefix = "set `"MINIO_ROOT_USER=$($cred[0])`" && set `"MINIO_ROOT_PASSWORD=$($cred[1])`" && "
        }
    }
    Start-Detached "cmd.exe /d /s /c `"$prefix$cmd >> `"$log`" 2>&1`"" $dir
    if (Wait-Healthy $name) { Write-Host "${name}: started and healthy (log: $log)"; return $true }
    Write-Warning "${name}: started but not healthy after 20 s; see $log"
    return $false
}

function Stop-Tool([string]$name) {
    $procs = @(Get-ToolProcess $name)
    if ($procs.Count -eq 0) { Write-Host "${name}: not running"; return $true }
    foreach ($p in $procs) {
        Stop-Process -Id $p.ProcessId -Force -Confirm:$false
        Write-Host "${name}: stopped pid $($p.ProcessId)"
    }
    return $true
}

function Show-Status([string]$name) {
    $procs = @(Get-ToolProcess $name)
    $exe = Get-ExePath $name
    $ver = if ($Pins[$name].Version) { $Pins[$name].Version } else { '(no approved source)' }
    $state = if ($procs.Count -gt 0) { "running pid $(($procs | ForEach-Object ProcessId) -join ',')" } `
        elseif ($exe -and (Test-Path -LiteralPath $exe)) { 'stopped' } else { 'not installed' }
    Write-Host ("{0,-8} {1,-20} {2}" -f $name, $ver, $state)
    foreach ($l in @(Get-Listener $Services[$name].Ports | Sort-Object LocalPort)) {
        $owner = (Get-Process -Id $l.OwningProcess -ErrorAction SilentlyContinue).ProcessName
        Write-Host ("         listening {0}:{1}  ({2} pid {3})" -f $l.LocalAddress, $l.LocalPort, $owner, $l.OwningProcess)
    }
    return ($procs.Count -gt 0)
}

$names = if ($Service -eq 'all') { @($Services.Keys) } else { @($Service) }
$ok = $true
switch ($Action) {
    'start'  { foreach ($n in $names) { if (-not (Start-Tool $n)) { $ok = $false } } }
    'stop'   { foreach ($n in $names) { [void](Stop-Tool $n) } }
    'status' { foreach ($n in $names) { if (-not (Show-Status $n)) { $ok = $false } } }
    'init'   {
        if (@(Get-ToolProcess 'minio').Count -eq 0) {
            Write-Warning 'minio: not running; start it first (-Action start -Service minio).'
            $ok = $false
        } else {
            Push-Location $RepoRoot
            try {
                & uv run --project backend python infra/scripts/minio_buckets.py
                if ($LASTEXITCODE -ne 0) { $ok = $false }
            } finally { Pop-Location }
        }
    }
}
if (-not $ok) { exit 2 }
