#Requires -RunAsAdministrator
############################
# Sets up a Windows machine:
#   1. Installs winget packages and apps       (winget.txt)
#   2. Links config files into place           (PowerShell profile, Terminal, bat, ruff, ssh, VS Code)
#      and sets Windows preferences
#   3. Installs global npm/uv tools, AI agent skills, VS Code extensions, fonts
#
# Run from an elevated PowerShell:  Set-ExecutionPolicy Bypass -Scope Process; .\windows\install.ps1
# Safe to re-run: steps check before changing anything, and replaced files
# are backed up to ~\.dotfiles_backup\<timestamp>\
############################

# -NoInput: never wait for a person (test machines): skips the computer-name and git
# identity prompts, the GitHub login, and the sign-in pauses
param([switch]$NoInput)
$ErrorActionPreference = 'Stop'

# The prompts hardcode ~\dotfiles, so refuse to run from anywhere else
$dotfiledir = $PSScriptRoot
if ((Resolve-Path $dotfiledir).Path -ne (Join-Path $HOME 'dotfiles')) {
    Write-Host "This repo must live at $HOME\dotfiles (currently running from $dotfiledir)." -ForegroundColor Red
    Write-Host "Clone it there and re-run:  git clone -b myWindowsDotfile https://github.com/cbromano/dotfiles.git $HOME\dotfiles"
    exit 1
}
. "$PSScriptRoot\helpers.ps1"
Set-Location $dotfiledir

# Checks for existing OneDrive roots and look for Documents and Desktop.
# If either OneDrive folder isn’t present—for example, on the first run before OneDrive is installed—
# the script falls back to $HOME\Documents or $HOME\Desktop.
$oneDriveRoots = @($env:OneDrive, $env:OneDriveConsumer, $env:OneDriveCommercial, "$HOME\OneDrive") |
    Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } |
    Select-Object -Unique
$documentsDir = Join-Path $HOME 'Documents'
$desktopDir = Join-Path $HOME 'Desktop'
$oneDriveDocuments = $oneDriveRoots | ForEach-Object { Join-Path $_ 'Documents' } |
    Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -First 1
$oneDriveDesktop = $oneDriveRoots | ForEach-Object { Join-Path $_ 'Desktop' } |
    Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -First 1
if ($oneDriveDocuments) { $documentsDir = $oneDriveDocuments }
if ($oneDriveDesktop) { $desktopDir = $oneDriveDesktop }

# --- winget packages and apps
# Snapshot the Desktop shortcuts: installers add more, and only those are removed at the end

$desktopBefore = @(Get-ChildItem (Join-Path $desktopDir '*.lnk'), "$env:PUBLIC\Desktop\*.lnk" -ErrorAction SilentlyContinue).FullName
$packages = Read-Manifest "$PSScriptRoot\winget.txt"
$installed = Get-CommandOutput { winget list --accept-source-agreements }
foreach ($id in $packages) {
    if ($installed -match [regex]::Escape($id)) { Write-Info "$id is already installed. Skipping."; continue }
    # --no-upgrade: an app that's installed but newer upstream (or self-updated past winget's
    # record) must not get its upgrade installer run here - that's update_all's job, and
    # upgrade installers can hang on a running app
    $result = Get-CommandOutput { winget install --id $id --exact --silent --no-upgrade --accept-source-agreements --accept-package-agreements }
    # Store apps don't show in `winget list`, so some land here every run
    if ($result -match 'already installed') { Write-Info "$id is already installed. Skipping."; continue }
    if ($result -match 'Successfully installed') { Write-Info "Installed $id."; continue }
    # The exit code isn't reliable (portable packages, installers that return early), so check the package list
    if (-not ((Get-CommandOutput { winget list --id $id --exact }) -match [regex]::Escape($id))) {
        Write-Warn "$id is not registered with winget yet (its installer may still be running) - re-run the script later to check."
    }
}
Update-Path   # tools installed above become callable from here on

# --- Config files
# PowerShell 7 profile
Link-WithBackup "$PSScriptRoot\settings\Microsoft.PowerShell_profile.ps1" (Join-Path $documentsDir 'PowerShell\Microsoft.PowerShell_profile.ps1')
Link-WithBackup "$PSScriptRoot\settings\Microsoft.PowerShell_profile.ps1" (Join-Path $documentsDir 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1')   # 5.1: what SSH sessions land in
# fzf keybindings for PowerShell (PSFzf), installed by PowerShell 7 itself: its module
# installer needs no NuGet bootstrap (5.1's hangs), and the profile runs in 7 anyway
$pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwsh) { $pwsh = "$env:LOCALAPPDATA\Microsoft\WindowsApps\pwsh.exe" }
$psfzf = if (Test-Path $pwsh) { Get-CommandOutput { & $pwsh -NoProfile -Command 'Get-Module -ListAvailable PSFzf' } }
if (-not (Test-Path $pwsh)) {
    Write-Warn 'pwsh not found; skipping the PSFzf module (re-run after PowerShell 7 is installed).'
} elseif ($psfzf -match 'PSFzf') {
    Write-Info 'PSFzf module already installed. Skipping.'
} elseif ($psfzf -match 'Access is denied|failed to run') {
    # The Store build of PowerShell 7 can't be started from an SSH session
    Write-Warn 'Could not start pwsh from this session; skipping the PSFzf module (re-run from Terminal).'
} else {
    Write-Info 'Installing the PSFzf module...'
    Invoke-Native { & $pwsh -NoProfile -Command 'Install-PSResource PSFzf -Scope CurrentUser -TrustRepository -Quiet' }
}

# Windows Terminal rewrites its settings.json, so merge into it instead of linking:
# add/replace the CMS scheme, apply the defaults, make PowerShell 7 the default profile
$wtSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (Test-Path $wtSettings) {
    $wt = Get-Content $wtSettings -Raw | ConvertFrom-Json
    $wtBefore = $wt | ConvertTo-Json -Depth 32
    $scheme = Get-Content "$PSScriptRoot\settings\cms-scheme.json" -Raw | ConvertFrom-Json
    $wt.schemes = @($wt.schemes | Where-Object { $_.name -ne $scheme.name }) + $scheme
    $defaults = Get-Content "$PSScriptRoot\settings\terminal-defaults.json" -Raw | ConvertFrom-Json
    if (-not $wt.profiles.defaults) { $wt.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) }
    foreach ($p in $defaults.PSObject.Properties) { $wt.profiles.defaults | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force }
    # The PowerShell 7 profile entry may not exist yet, but its GUID is deterministic
    $pwsh = $wt.profiles.list | Where-Object { $_.source -eq 'Windows.Terminal.PowershellCore' } | Select-Object -First 1
    $wt.defaultProfile = if ($pwsh) { $pwsh.guid } else { '{574e775e-4f2a-5b96-ac1e-a2962a402336}' }
    $wtAfter = $wt | ConvertTo-Json -Depth 32
    if ($wtAfter -eq $wtBefore) { Write-Info 'Windows Terminal already configured. Skipping.' }
    else {
        $wtAfter | Set-Content $wtSettings -Encoding utf8
        Write-Info 'Windows Terminal: CMS scheme, defaults, and PowerShell 7 as the default profile.'
    }
} else { Write-Warn 'Windows Terminal settings.json not found (open Terminal once, then re-run).' }


# bat config + color scheme (theme cache built below)
# There was no changes other than the theme, which I'm not sure I care about
#Link-WithBackup "$dotfiledir\settings\bat-config" "$env:APPDATA\bat\config"
#Link-WithBackup "$dotfiledir\settings\bat-themes" "$env:APPDATA\bat\themes"

# Ruff global config
# Ruff is overkill, but it can be used to lint Python, TOML, and Markdown files, and it has a VS Code extension
Link-WithBackup "$dotfiledir\settings\ruff.toml" "$env:APPDATA\ruff\ruff.toml"

# Prettier global config (any file under $HOME with no closer .prettierrc uses it)

Link-WithBackup "$dotfiledir\settings\prettierrc.json" "$HOME\.prettierrc"

# VS Code settings and keybindings
#Link-WithBackup "$dotfiledir\settings\VSCode-Settings.json" "$env:APPDATA\Code\User\settings.json"
#Link-WithBackup "$dotfiledir\settings\VSCode-Keybindings.json" "$env:APPDATA\Code\User\keybindings.json"


if (-not $NoInput) {
    Pause-For 'Sign in to Google Chrome.'
    Pause-For 'Sign in to Google Drive.'
    Pause-For 'Sign in to Discord.'
    Pause-For 'Optional: to SSH into this PC, see "SSH into this PC" in windows\README.md.'
    Pause-For 'Open PowerToys and set up a FancyZones layout.'
    Pause-For 'Sign in to your accounts (GitHub Copilot, etc.) within VS Code.'
}

Write-Host ''
Write-Info 'Installation Complete!'
if (Test-Path $script:BackupDir) { Write-Info "Files replaced by this run were backed up to $script:BackupDir" }
