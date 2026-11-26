############################
# Windows preferences. Dot-sourced by install.ps1 (elevated).
# Each setting checks before changing anything.
############################

# Screenshots: location selection is pending because OneDrive versus Dropbox has not been decided.
# $screenshotDir = Join-Path $HOME 'Desktop\Screenshots'
# $shellFolders = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
# $screenshotsGuid = '{B7BEDE81-DF94-4682-A7D8-57A52620B86F}'
# New-Item -ItemType Directory -Force -Path $screenshotDir | Out-Null
# $current = (Get-ItemProperty -Path $shellFolders -Name $screenshotsGuid -ErrorAction SilentlyContinue).$screenshotsGuid
# if ([Environment]::ExpandEnvironmentVariables("$current") -ne $screenshotDir) {
#     New-ItemProperty -Path $shellFolders -Name $screenshotsGuid -Value '%USERPROFILE%\Desktop\Screenshots' -PropertyType ExpandString -Force | Out-Null
#     Write-Info "Screenshots will now be saved to $screenshotDir."
# }

# Explorer: show hidden files and file extensions, and disable Snap Assist.
$explorerAdvanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$explorerChanged = $false
foreach ($pair in @(
    @{ Name = 'Hidden'; Value = 1 },
    @{ Name = 'HideFileExt'; Value = 0 },
    @{ Name = 'SnapAssist'; Value = 0 }
)) {
    $existing = (Get-ItemProperty -Path $explorerAdvanced -Name $pair.Name -ErrorAction SilentlyContinue).($pair.Name)
    if ($existing -ne $pair.Value) {
        Set-ItemProperty -Path $explorerAdvanced -Name $pair.Name -Value $pair.Value -Type DWord
        $explorerChanged = $true
    }
}
if ($explorerChanged) {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Write-Info 'Explorer now shows hidden files and file extensions; Snap Assist is off.'
} else {
    Write-Info 'Explorer already shows hidden files and file extensions, Snap Assist off. Skipping.'
}

# PowerToys remapping is skipped.

# Edge: disable the floating search bar, startup boost, and background mode.
$edgePolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$edgeChanged = $false
if (-not (Test-Path $edgePolicy)) {
    New-Item -Path $edgePolicy | Out-Null
}
foreach ($name in 'WebWidgetAllowed', 'WebWidgetIsEnabledOnStartup', 'StartupBoostEnabled', 'BackgroundModeEnabled') {
    if ((Get-ItemProperty -Path $edgePolicy -Name $name -ErrorAction SilentlyContinue).$name -ne 0) {
        Set-ItemProperty -Path $edgePolicy -Name $name -Value 0 -Type DWord
        $edgeChanged = $true
    }
}
if ($edgeChanged) {
    Write-Info 'Edge: search bar, startup boost, and background mode turned off.'
} else {
    Write-Info 'Edge already quiet. Skipping.'
}

# Game Bar: disable background recording and capture.
$gameDvrChanged = $false
if (-not (Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR')) {
    New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' | Out-Null
}
foreach ($pair in @(
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'AppCaptureEnabled' },
    @{ Path = 'HKCU:\System\GameConfigStore'; Name = 'GameDVR_Enabled' }
)) {
    if ((Get-ItemProperty -Path $pair.Path -Name $pair.Name -ErrorAction SilentlyContinue).($pair.Name) -ne 0) {
        Set-ItemProperty -Path $pair.Path -Name $pair.Name -Value 0 -Type DWord
        $gameDvrChanged = $true
    }
}
if ($gameDvrChanged) {
    Write-Info 'Game Bar background recording turned off.'
} else {
    Write-Info 'Game Bar background recording already off. Skipping.'
}

# Remove unwanted preinstalled apps, while retaining Phone Link and Widgets.
$unwantedApps = @(
    'Microsoft.BingWeather',
    'Microsoft.BingSearch',
    'Microsoft.WindowsFeedbackHub',
    'Microsoft.GetHelp',
    'Microsoft.GamingApp',
    'Microsoft.XboxGamingOverlay',
    'Microsoft.XboxGameOverlay',
    'Microsoft.XboxSpeechToTextOverlay'
)
$removed = 0
foreach ($app in $unwantedApps) {
    $pkg = Get-AppxPackage -Name $app -ErrorAction SilentlyContinue
    if ($pkg) {
        $pkg | Remove-AppxPackage -ErrorAction SilentlyContinue
        $removed++
    }
}
if ($removed -gt 0) {
    Write-Info "Removed $removed unwanted preinstalled app(s)."
} else {
    Write-Info 'Unwanted preinstalled apps already removed. Skipping.'
}

# OneDrive is retained.

# Enable Windows and Git long-path support.
$fileSystem = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
if ((Get-ItemProperty -Path $fileSystem -Name LongPathsEnabled -ErrorAction SilentlyContinue).LongPathsEnabled -eq 1) {
    Write-Info 'Long paths are already enabled. Skipping.'
} else {
    Set-ItemProperty -Path $fileSystem -Name LongPathsEnabled -Value 1 -Type DWord
    Write-Info 'Long paths enabled.'
}
if (Get-Command git -ErrorAction SilentlyContinue) {
    git config --global core.longpaths true
}

# Windows sudo is skipped.

# Keep the desktop background black.
$desktopColors = 'HKCU:\Control Panel\Colors'
$desktop = 'HKCU:\Control Panel\Desktop'
$backgroundChanged = $false
if ((Get-ItemProperty -Path $desktopColors -Name Background -ErrorAction SilentlyContinue).Background -ne '0 0 0') {
    Set-ItemProperty -Path $desktopColors -Name Background -Value '0 0 0' -Type String
    $backgroundChanged = $true
}
if ((Get-ItemProperty -Path $desktop -Name Wallpaper -ErrorAction SilentlyContinue).Wallpaper) {
    Set-ItemProperty -Path $desktop -Name Wallpaper -Value '' -Type String
    $backgroundChanged = $true
}
if ($backgroundChanged) {
    Add-Type -Namespace Dotfiles -Name Wallpaper -MemberDefinition '[DllImport("user32.dll", SetLastError = true)] public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);'
    [Dotfiles.Wallpaper]::SystemParametersInfo(0x0014, 0, '', 0x03) | Out-Null
    Write-Info 'Desktop background set to black.'
} else {
    Write-Info 'Desktop background is already black. Skipping.'
}

# Optional wallpaper update functionality. Disabled while no custom wallpaper is selected.
# $wallpaper = Join-Path $PSScriptRoot 'settings\Desktop.png'
# if (-not (Test-Path $wallpaper)) {
#     Write-Warn "Desktop image not found at $wallpaper. Skipping desktop background."
# } elseif ((Get-ItemProperty 'HKCU:\Control Panel\Desktop').Wallpaper -eq $wallpaper) {
#     Write-Info 'Desktop background is already set. Skipping.'
# } else {
#     $spotlight = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\DesktopSpotlight\Settings'
#     if (Test-Path $spotlight) {
#         Set-ItemProperty $spotlight -Name EnabledState -Value 0 -Type DWord
#     }
#     Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value '10'
#     Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value '0'
#     Add-Type -Namespace Dotfiles -Name Wallpaper -MemberDefinition '[DllImport("user32.dll", SetLastError = true)] public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);'
#     [Dotfiles.Wallpaper]::SystemParametersInfo(0x0014, 0, $wallpaper, 0x03) | Out-Null
# }
