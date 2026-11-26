# Windows Development Environment Setup

This repository contains scripts and configuration files for my Windows 11 development environment.

## Warning

These configurations are highly personalized. The installer can install software, change system settings, and replace existing configuration files. Review the scripts before running them.

## Installation

1. Clone the repository to `$HOME\dotfiles`:
   ```powershell
   git clone https://github.com/CoreyMSchafer/dotfiles.git $HOME\dotfiles
   cd $HOME\dotfiles
   ```

2. Open an elevated PowerShell and run:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process
   & $HOME\dotfiles\install.ps1
   ```

Use `-NoInput` to skip interactive prompts:

```powershell
& $HOME\dotfiles\install.ps1 -NoInput
```

The installer is safe to rerun. Existing files are backed up before replacement.

## What It Installs and Configures

- Packages and applications from `winget.txt`
- PowerShell 7 and Windows PowerShell profiles
- Windows Terminal settings
- bat, Ruff, SSH, and Prettier configuration
- Windows preferences and selected system cleanup

## Configuration Files

- `install.ps1`: Main Windows installer
- `helpers.ps1`: Logging, backup, and symlink helpers
- `winget.txt`: winget package and application IDs
- `settings/Microsoft.PowerShell_profile.ps1`: PowerShell profile
- `settings/cms-scheme.json`: Windows Terminal color scheme
- `settings/terminal-defaults.json`: Windows Terminal defaults
- `settings/ruff.toml`: Global Ruff configuration
- `settings/prettierrc.json`: Prettier configuration copied to `$HOME\.prettierrc`

## Customizing

Review and edit `winget.txt`, `install.ps1`, and files under `settings/` before personalizing the setup.
