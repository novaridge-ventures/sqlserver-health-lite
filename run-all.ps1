<#
  Runs every read-only check and writes one text file per script into .\output.
  Example:  .\run-all.ps1 -Server "SQL01" -Database "SalesDB"            # Windows auth
            .\run-all.ps1 -Server "localhost" -Database "SalesDB" -User sa # prompts for password
  Requires sqlcmd (https://learn.microsoft.com/sql/tools/sqlcmd/sqlcmd-utility).
#>
param(
  [string]$Server = "localhost",
  [string]$Database = "master",
  [string]$User
)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
New-Item -ItemType Directory -Force -Path output | Out-Null
$auth = @("-E")
if ($User) {
  $sec = Read-Host "Password for $User" -AsSecureString
  $pw = [System.Net.NetworkCredential]::new("", $sec).Password
  $auth = @("-U", $User, "-P", $pw)
}
Get-ChildItem scripts\*.sql | Sort-Object Name | ForEach-Object {
  $out = Join-Path "output" ($_.BaseName + ".txt")
  Write-Host "Running $($_.Name) -> $out"
  & sqlcmd -S $Server @auth -C -d $Database -i $_.FullName -W -s "|" -o $out
}
Write-Host "Done. Look for CRITICAL / WARN in output\*.txt"
