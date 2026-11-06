<#
.SYNOPSIS
    Logical backup of the Jivo Quick Commerce PostgreSQL + PostGIS database (Windows twin of
    backup_db.sh; docs/deployment.md section 7).

.DESCRIPTION
    Dumps one database with pg_dump -Fc (read-only on the source), writes <file>.sha256 and a
    manifest, and optionally uploads to BACKUP_UPLOAD_URI (s3:// only; placeholder until D-05).
    Every run writes new timestamped files and never overwrites. -SchemaOnly also writes
    <base>.migrations.dump with the django_migrations rows, so verify_restore.py can check the
    migration state. Output must be outside the git repo. Credentials are never printed.

    Exit codes: 0 ok, 1 error, 2 usage, 3 upload not configured.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File infra\backup\backup_db.ps1 -EnvFile backend\.env -SchemaOnly -OutDir $env:TEMP\jqc-bk
#>
[CmdletBinding()]
param(
    [string]$EnvFile,
    [string]$Database,
    [string]$OutDir,
    [switch]$SchemaOnly,
    [switch]$Upload,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
. (Join-Path $PSScriptRoot 'common.ps1')

if (-not $OutDir) {
    $OutDir = if ($env:BACKUP_DIR) { $env:BACKUP_DIR } else { Join-Path $env:USERPROFILE '.local\share\jivoqc-backups' }
}
if ($EnvFile) { Import-JqcEnvFile $EnvFile }
Set-JqcPgEnv
if (-not $Database) { $Database = $env:PGDATABASE }
if (-not $Database) { Stop-Jqc 'no database: pass -Database or set PGDATABASE/POSTGRES_DB' 2 }
if ($Database -cnotmatch $script:JqcDbNameRe) { Stop-Jqc "refusing unusual database name: $Database" 2 }
Assert-JqcConn
Assert-JqcTool @('pg_dump', 'psql')

# Never write dumps inside the git work tree (the repo is public).
$outFull = [System.IO.Path]::GetFullPath($OutDir).TrimEnd('\') + '\'
$top = $null
try { $top = (& git -C $PSScriptRoot rev-parse --show-toplevel 2>$null) } catch { $top = $null }
if ($top) {
    $topFull = [System.IO.Path]::GetFullPath($top).TrimEnd('\') + '\'
    if ($outFull.StartsWith($topFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        Stop-Jqc "-OutDir is inside the git repo ($outFull); choose a directory outside it" 2
    }
}

$stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMdd'T'HHmmss'Z'")
$suffix = if ($SchemaOnly) { '_schema' } else { '' }
$base = "${Database}_${stamp}${suffix}"
$dump = Join-Path $OutDir "$base.dump"
$mig = Join-Path $OutDir "$base.migrations.dump"
$manifest = Join-Path $OutDir "$base.manifest.json"

$dumpArgs = @('--format=custom', '--compress=6', '--no-password')
if ($SchemaOnly) { $dumpArgs += '--schema-only' }
$dumpArgs += @("--dbname=$Database", "--file=$dump")
$migArgs = @('--format=custom', '--no-password', '--data-only', '--table=public.django_migrations', "--dbname=$Database", "--file=$mig")

if ($DryRun) {
    Write-JqcLog "dry run; target $(Get-JqcConnLabel)/$Database"
    Write-Output ('pg_dump ' + ($dumpArgs -join ' '))
    if ($SchemaOnly) { Write-Output ('pg_dump ' + ($migArgs -join ' ')) }
    exit 0
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
if (Test-Path -LiteralPath $dump) { Stop-Jqc "refusing to overwrite $dump" }

Write-JqcLog ("dumping $Database from $(Get-JqcConnLabel) (" + $(if ($SchemaOnly) { 'schema only' } else { 'full' }) + ')')
$t0 = Get-Date
$r = Invoke-JqcNative 'pg_dump' $dumpArgs
if ($r.Code -ne 0) { [Console]::Error.Write($r.StdErr); Stop-Jqc 'pg_dump failed' }
$files = @($dump)
if ($SchemaOnly) {
    $r = Invoke-JqcNative 'pg_dump' $migArgs
    if ($r.Code -ne 0) { [Console]::Error.Write($r.StdErr); Stop-Jqc 'pg_dump of django_migrations failed' }
    $files += $mig
}
$seconds = [int]((Get-Date) - $t0).TotalSeconds

# Restrict the files to the current user (a full dump holds PII).
foreach ($f in $files) {
    & icacls $f /inheritance:r /grant:r "$($env:USERNAME):(F)" | Out-Null
}

$entries = @()
foreach ($f in $files) {
    $sum = Get-JqcSha256 $f
    $name = Split-Path -Leaf $f
    # sha256sum format, LF, no BOM: readable by restore_db.sh and sha256sum -c
    [System.IO.File]::WriteAllText("$f.sha256", "$sum  $name`n", (New-Object System.Text.UTF8Encoding $false))
    $entries += [ordered]@{ file = $name; bytes = (Get-Item -LiteralPath $f).Length; sha256 = $sum }
}
$serverVersion = Invoke-JqcPsql $Database 'show server_version'
$postgis = Invoke-JqcPsql $Database "select extversion from pg_extension where extname='postgis'"
$pgDumpVersion = ((& pg_dump --version) -split ' ')[-1]
$commit = 'unknown'
try { $commit = (& git -C $PSScriptRoot rev-parse --short HEAD 2>$null) } catch { $commit = 'unknown' }
$m = [ordered]@{
    database         = $Database
    mode             = $(if ($SchemaOnly) { 'schema-only' } else { 'full' })
    created_at_utc   = $stamp
    duration_seconds = $seconds
    server_version   = $serverVersion
    postgis_version  = $(if ($postgis) { $postgis } else { 'none' })
    pg_dump_version  = $pgDumpVersion
    repo_commit      = $commit
    files            = $entries
}
[System.IO.File]::WriteAllText($manifest, ($m | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding $false))
Write-JqcLog ("wrote $dump ($((Get-Item -LiteralPath $dump).Length) bytes) in ${seconds}s; manifest $manifest")

if ($Upload) {
    $uri = $env:BACKUP_UPLOAD_URI
    if (-not $uri) { Write-JqcLog 'upload requested but BACKUP_UPLOAD_URI is not set (no backup bucket until D-05)'; exit 3 }
    if (-not $uri.StartsWith('s3://')) { Stop-Jqc 'unsupported BACKUP_UPLOAD_URI scheme (only s3:// is implemented)' 3 }
    Assert-JqcTool @('aws')
    foreach ($f in ($files + ($files | ForEach-Object { "$_.sha256" }) + $manifest)) {
        $r = Invoke-JqcNative 'aws' @('s3', 'cp', '--only-show-errors', '--sse', 'aws:kms', $f, ($uri.TrimEnd('/') + '/' + (Split-Path -Leaf $f)))
        if ($r.Code -ne 0) { [Console]::Error.Write($r.StdErr); Stop-Jqc "upload failed for $(Split-Path -Leaf $f)" }
    }
    Write-JqcLog "uploaded $($files.Count) dump file(s) + checksums + manifest to $($uri.TrimEnd('/'))/"
}
exit 0
