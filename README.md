# Windows Dotfiles

This repository is my Windows 11 configuration, based on
[CoreyMSchafer/dotfiles](https://github.com/CoreyMSchafer/dotfiles) and maintained
in my own fork at [cbromano/dotfiles](https://github.com/cbromano/dotfiles).

> [!WARNING]
> These configurations are highly personalized. The installer can install
> software, change system settings, and replace existing configuration files.
> Review [install.ps1](install.ps1) and [winget.txt](winget.txt) before running it.

## Installation

Clone the `myWindowsDotfile` branch because it is the branch containing this
Windows setup:

```powershell
winget install --id Git.Git --exact
git clone --branch myWindowsDotfile https://github.com/cbromano/dotfiles.git $HOME\dotfiles
cd $HOME\dotfiles
```

Open Windows Terminal as Administrator, then run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process
& $HOME\dotfiles\install.ps1
```

Use `-NoInput` to skip the sign-in and setup pauses:

```powershell
& $HOME\dotfiles\install.ps1 -NoInput
```

The repository must be located at `$HOME\dotfiles`. The script is safe to rerun:
it skips installed packages and backs up files before replacing them.

## What the Installer Does

- Installs winget packages listed in [winget.txt](winget.txt).
- Links the PowerShell profile for PowerShell 7 and Windows PowerShell 5.1.
- Installs PSFzf for PowerShell 7 when available.
- Configures the Windows Terminal color scheme and default profile.
- Links the global Ruff configuration and Prettier configuration.
- Prompts for optional account sign-ins and desktop setup.

The following items are included in the repository but are not currently linked
by `install.ps1`: bat configuration and bat themes.

## Configuration Files

- [install.ps1](install.ps1): Main Windows installer.
- [helpers.ps1](helpers.ps1): Logging, backup, and symlink helpers.
- [winget.txt](winget.txt): winget package and application IDs.
- [Microsoft.PowerShell_profile.ps1](settings/Microsoft.PowerShell_profile.ps1):
  PowerShell prompt and shell helpers.
- [cms-scheme.json](settings/cms-scheme.json): Windows Terminal color scheme.
- [terminal-defaults.json](settings/terminal-defaults.json): Windows Terminal defaults.
- [settings.ps1](settings.ps1): Selective Windows preferences for Explorer, Edge,
  Game Bar, unwanted apps, long paths, and a black desktop background.
- [ruff.toml](settings/ruff.toml): Global Ruff configuration copied to
  `$env:APPDATA\ruff\ruff.toml`.
- [prettierrc.json](settings/prettierrc.json): Prettier configuration copied to
  `$HOME\.prettierrc`.
- [VSCode-Settings.json](settings/VSCode-Settings.json): VS Code settings copied
  to `$env:APPDATA\Code\User\settings.json`.
- [VSCode-Keybindings.json](settings/VSCode-Keybindings.json): VS Code keybindings
  copied to `$env:APPDATA\Code\User\keybindings.json`.

## SSH into this PC

Windows ships the OpenSSH server as an optional feature. From an elevated
PowerShell:

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Set-Service sshd -StartupType Automatic
Set-NetConnectionProfile -NetworkCategory Private
Start-Service sshd
New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell `
  -Value 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' `
  -PropertyType String -Force
Restart-Service sshd
```

Administrator accounts must store their authorized keys in
`C:\ProgramData\ssh\administrators_authorized_keys`, not `~\.ssh\authorized_keys`:

```powershell
Set-Content C:\ProgramData\ssh\administrators_authorized_keys `
  'ssh-ed25519 AAAA... you@host' -Encoding ascii
icacls C:\ProgramData\ssh\administrators_authorized_keys /inheritance:r `
  /grant Administrators:F /grant SYSTEM:F
```

Connect with `ssh <user>@<computer-name>`.

## Customizing

Review and edit [winget.txt](winget.txt), [install.ps1](install.ps1), and files
under [settings](settings/) to suit your machine. Because [winget.txt](winget.txt)
contains exact package IDs, test package changes on a disposable setup before
running the installer on a primary machine.
