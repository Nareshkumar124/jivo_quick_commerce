<#
.SYNOPSIS
    Restore a backup_db dump into a NAMED target database (Windows twin of restore_db.sh;
    docs/deployment.md section 7).

.DESCRIPTION
    Safety rules (the database server may be shared with other projects):
    - The target must match test_jivo_quick_commerce_restore* unless -Production is given with
      -Confirm "RESTORE INTO <target>" typed exactly.
    - A production restore always goes into a database that does not exist yet. Nothing but a
      test_jivo_quick_commerce_restore* database is ever dropped (-DropExisting, -DropOnly).
    - The dump's sha256 is checked before anything is created (skip with -SkipChecksum).

    Exit codes: 0 ok, 1 error, 2 usage or refused by a safety rule, 4 verification failed.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File infra\backup\restore_db.ps1 -EnvFile backend\.env -Dump C:\bk\x_schema.dump -TargetDb test_jivo_quick_commerce_restore_check -DropExisting -Verify -SourceDb jivo_quick_commerce
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File infra\backup\restore_db.ps1 -EnvFile backend\.env -TargetDb test_jivo_quick_commerce_restore_check -DropOnly
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$TargetDb,
    [string]$Dump,
    [string]$EnvFile,
    [string]$MaintenanceDb = 'postgres',
    [ValidateRange(1, 99)][int]$Jobs = 2,
    [switch]$DropExisting,
    [switch]$DropOnly,
    [switch]$Verify,
    [string]$SourceDb,
    [switch]$Production,
    [string]$Confirm,
    [switch]$SkipChecksum,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
. (Join-Path $PSScriptRoot 'common.ps1')

# ---------------------------------------------------------------- safety rules (before any I/O)
if ($TargetDb -cnotmatch $script:JqcDbNameRe) { Stop-Jqc "refusing unusual database name: $TargetDb" 2 }
if ($SourceDb -and $SourceDb -cnotmatch $script:JqcDbNameRe) { Stop-Jqc "refusing unusual database name: $SourceDb" 2 }
if ($SourceDb -and $SourceDb -ceq $TargetDb) { Stop-Jqc '-SourceDb and -TargetDb are the same' 2 }
$isTest = $TargetDb -cmatch $script:JqcTestRestoreRe
if (-not $isTest) {
    if (-not $Production) { Stop-Jqc "target '$TargetDb' is not a test_jivo_quick_commerce_restore* database; refusing (see -Production)" 2 }
    if ($Confirm -cne "RESTORE INTO $TargetDb") { Stop-Jqc "-Production needs -Confirm `"RESTORE INTO $TargetDb`" typed exactly" 2 }
    if ($DropExisting -or $DropOnly) { Stop-Jqc '-DropExisting/-DropOnly are only allowed for test_jivo_quick_commerce_restore* targets' 2 }
}
if (-not $DropOnly -and -not $Dump) { Stop-Jqc '-Dump is required' 2 }

if ($EnvFile) { Import-JqcEnvFile $EnvFile }
Remove-Item Env:PGDATABASE -ErrorAction SilentlyContinue  # never fall back to the app database
Set-JqcPgEnv
Remove-Item Env:PGDATABASE -ErrorAction SilentlyContinue
Assert-JqcConn
Assert-JqcTool @('psql', 'pg_restore')

function Remove-TargetDb {
    if ($TargetDb -cnotmatch $script:JqcTestRestoreRe) { Stop-Jqc "internal: refusing to drop $TargetDb" 2 }
    Write-JqcLog "dropping test database $TargetDb"
    Invoke-JqcPsql $MaintenanceDb 'drop database if exists :"dbname" with (force);' @{ dbname = $TargetDb } | Out-Null
}

if ($DryRun) {
    Write-JqcLog "dry run; server $(Get-JqcConnLabel), maintenance db $MaintenanceDb"
    if ($DropOnly) { Write-Output "drop database if exists `"$TargetDb`""; exit 0 }
    if ($DropExisting) { Write-Output "drop database if exists `"$TargetDb`"" }
    Write-Output "verify sha256 of $Dump"
    Write-Output "create database `"$TargetDb`""
    Write-Output "pg_restore --no-owner --no-privileges --jobs=$Jobs --dbname=$TargetDb $Dump"
    exit 0
}

if ($DropOnly) { Remove-TargetDb; exit 0 }

# ---------------------------------------------------------------- checksum
if (-not (Test-Path -LiteralPath $Dump -PathType Leaf)) { Stop-Jqc "dump not readable: $Dump" }
$Dump = (Resolve-Path -LiteralPath $Dump).ProviderPath
$mig = Join-Path (Split-Path -Parent $Dump) (([System.IO.Path]::GetFileNameWithoutExtension($Dump)) + '.migrations.dump')
function Test-Sum([string]$File) {
    $sumFile = "$File.sha256"
    if (-not (Test-Path -LiteralPath $sumFile)) { Stop-Jqc "missing checksum file $sumFile (or pass -SkipChecksum)" }
    $expected = ((Get-Content -LiteralPath $sumFile -TotalCount 1) -split '\s+')[0].ToLowerInvariant()
    if ($expected -ne (Get-JqcSha256 $File)) { Stop-Jqc "checksum mismatch for $(Split-Path -Leaf $File): the dump is corrupt or was changed" }
    Write-JqcLog "checksum ok: $(Split-Path -Leaf $File)"
}
if (-not $SkipChecksum) {
    Test-Sum $Dump
    if (Test-Path -LiteralPath $mig) { Test-Sum $mig }
}

# ---------------------------------------------------------------- create + restore
$exists = Invoke-JqcPsql $MaintenanceDb "select 1 from pg_database where datname = :'dbname';" @{ dbname = $TargetDb }
if ($exists -eq '1') {
    if ($DropExisting) { Remove-TargetDb }
    else { Stop-Jqc "target $TargetDb already exists (use -DropExisting for a test target; a production restore always goes into a new database)" 2 }
}
Write-JqcLog "creating $TargetDb on $(Get-JqcConnLabel)"
Invoke-JqcPsql $MaintenanceDb 'create database :"dbname";' @{ dbname = $TargetDb } | Out-Null

# pg_restore 17+ into PostgreSQL 16 issues SET transaction_timeout, which the server rejects;
# that is harmless and the only error tolerated.
function Test-RestoreErrors([string]$StdErr) {
    $real = @($StdErr -split "`r?`n" | Where-Object { $_ -match '^pg_restore: error:' -and $_ -notmatch 'unrecognized configuration parameter "transaction_timeout"' })
    return $real.Count -eq 0
}

Write-JqcLog "restoring $(Split-Path -Leaf $Dump) into $TargetDb (jobs=$Jobs)"
$t0 = Get-Date
$r = Invoke-JqcNative 'pg_restore' @('--no-password', '--no-owner', '--no-privileges', "--jobs=$Jobs", "--dbname=$TargetDb", $Dump)
if ($r.Code -ne 0) {
    if (-not (Test-RestoreErrors $r.StdErr)) { [Console]::Error.Write($r.StdErr); Stop-Jqc "pg_restore failed; $TargetDb is incomplete (drop it before retrying)" }
    Write-JqcLog 'pg_restore reported only tolerated errors (newer-client SET parameters)'
}
if (Test-Path -LiteralPath $mig) {
    Write-JqcLog "restoring the django_migrations rows ($(Split-Path -Leaf $mig))"
    $r = Invoke-JqcNative 'pg_restore' @('--no-password', '--no-owner', '--no-privileges', '--data-only', "--dbname=$TargetDb", $mig)
    if ($r.Code -ne 0 -and -not (Test-RestoreErrors $r.StdErr)) { [Console]::Error.Write($r.StdErr); Stop-Jqc 'restoring django_migrations failed' }
}
Write-JqcLog ("restore finished in {0}s" -f [int]((Get-Date) - $t0).TotalSeconds)

# ---------------------------------------------------------------- verify
if ($Verify) {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).ProviderPath
    $verifyArgs = @('run', '--project', (Join-Path $repoRoot 'backend'), 'python', (Join-Path $PSScriptRoot 'verify_restore.py'), '--target-db', $TargetDb)
    if ($SourceDb) { $verifyArgs += @('--source-db', $SourceDb) }
    Write-JqcLog 'running verify_restore.py'
    & uv @verifyArgs
    if ($LASTEXITCODE -ne 0) { Stop-Jqc "verification FAILED for $TargetDb" 4 }
}
exit 0
