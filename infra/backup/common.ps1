# Shared helpers for infra/backup/*.ps1 (Windows PowerShell 5.1 and PowerShell 7). Dot-sourced.
# Same rules as lib.sh: connection settings go into the libpq PG* variables of this process only,
# and are never printed.

$script:JqcTestRestoreRe = '^test_jivo_quick_commerce_restore[a-z0-9_]*$'
$script:JqcDbNameRe = '^[a-z_][a-z0-9_]{0,62}$'
$script:JqcEnvMap = @{
    'POSTGRES_HOST'     = 'PGHOST'
    'POSTGRES_PORT'     = 'PGPORT'
    'POSTGRES_DB'       = 'PGDATABASE'
    'POSTGRES_USER'     = 'PGUSER'
    'POSTGRES_PASSWORD' = 'PGPASSWORD'
    'POSTGRES_SSLMODE'  = 'PGSSLMODE'
}

function Write-JqcLog([string]$Message) {
    [Console]::Error.WriteLine(('[{0}] {1}' -f (Get-Date).ToUniversalTime().ToString('HH:mm:ssZ'), $Message))
}

function Stop-Jqc([string]$Message, [int]$Code = 1) {
    Write-JqcLog "ERROR: $Message"
    exit $Code
}

# Read only the six POSTGRES_* connection keys from a dotenv file into PG* variables.
function Import-JqcEnvFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { Stop-Jqc "env file not readable: $Path" }
    foreach ($raw in [System.IO.File]::ReadAllLines((Resolve-Path -LiteralPath $Path).ProviderPath)) {
        $line = $raw.Trim()
        if ($line.StartsWith('export ')) { $line = $line.Substring(7) }
        $eq = $line.IndexOf('=')
        if ($eq -lt 1) { continue }
        $key = $line.Substring(0, $eq)
        if (-not $script:JqcEnvMap.ContainsKey($key)) { continue }
        $val = $line.Substring($eq + 1)
        if ($val.Length -ge 2 -and $val[0] -eq $val[$val.Length - 1] -and ($val[0] -eq '"' -or $val[0] -eq "'")) {
            $val = $val.Substring(1, $val.Length - 2)
        }
        [Environment]::SetEnvironmentVariable($script:JqcEnvMap[$key], $val, 'Process')
    }
}

# Fill PG* from POSTGRES_* where PG* is unset.
function Set-JqcPgEnv {
    foreach ($k in $script:JqcEnvMap.Keys) {
        $pg = $script:JqcEnvMap[$k]
        $have = [Environment]::GetEnvironmentVariable($pg, 'Process')
        $src = [Environment]::GetEnvironmentVariable($k, 'Process')
        if (-not $have -and $src) { [Environment]::SetEnvironmentVariable($pg, $src, 'Process') }
    }
    if (-not $env:PGCONNECT_TIMEOUT) { $env:PGCONNECT_TIMEOUT = '10' }
    if (-not $env:PGAPPNAME) { $env:PGAPPNAME = 'jqc-backup' }
}

function Assert-JqcConn {
    if (-not $env:PGHOST) { Stop-Jqc 'no database host: set PGHOST/POSTGRES_HOST or pass -EnvFile' }
    if (-not $env:PGUSER) { Stop-Jqc 'no database user: set PGUSER/POSTGRES_USER or pass -EnvFile' }
}

function Assert-JqcTool([string[]]$Names) {
    foreach ($n in $Names) {
        if (-not (Get-Command $n -ErrorAction SilentlyContinue)) {
            Stop-Jqc "'$n' not found on PATH (PostgreSQL client tools, same major version as the server or newer)"
        }
    }
}

function Get-JqcConnLabel {
    $port = if ($env:PGPORT) { $env:PGPORT } else { '5432' }
    if ($env:JQC_SHOW_HOST -eq '1') { return ('{0}@{1}:{2}' -f $env:PGUSER, $env:PGHOST, $port) }
    return "the configured server (port $port)"
}

function Get-JqcSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

# Quote one argument for a Windows command line (CommandLineToArgvW rules).
function ConvertTo-JqcArg([string]$Arg) {
    if ($Arg -notmatch '[\s"]') { return $Arg }
    return '"' + ($Arg -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
}

# Run a native tool; returns @{ Code; StdErr }. Does not throw on stderr output (PS 5.1 safe).
function Invoke-JqcNative([string]$Exe, [string[]]$Arguments) {
    $errFile = [System.IO.Path]::GetTempFileName()
    $outFile = [System.IO.Path]::GetTempFileName()
    try {
        $cmd = (Get-Command $Exe -ErrorAction Stop).Source
        $argLine = ($Arguments | ForEach-Object { ConvertTo-JqcArg $_ }) -join ' '
        $p = Start-Process -FilePath $cmd -ArgumentList $argLine -NoNewWindow -Wait -PassThru `
            -RedirectStandardError $errFile -RedirectStandardOutput $outFile
        return @{
            Code   = $p.ExitCode
            StdErr = [System.IO.File]::ReadAllText($errFile)
            StdOut = [System.IO.File]::ReadAllText($outFile)
        }
    }
    finally {
        Remove-Item -LiteralPath $errFile, $outFile -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-JqcPsql([string]$Database, [string]$Sql) {
    $r = Invoke-JqcNative 'psql' @('--no-psqlrc', '--no-password', '-X', '-v', 'ON_ERROR_STOP=1', '-qAt', '-d', $Database, '-c', $Sql)
    if ($r.Code -ne 0) { Stop-Jqc ("psql failed: " + ($r.StdErr.Trim() -split "`n")[0]) }
    return $r.StdOut.Trim()
}
