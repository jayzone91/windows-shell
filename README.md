# Windows Shell

Noctty + Nushell + Starship + Zoxide + Carapace + FZF + Eza + Bat + fd + mise.

## First PC (capture existing setup)

Clone the repository to `D:\GitHub\windows-shell`, place `bootstrap.ps1` at its root, then open PowerShell:

```powershell
cd D:\GitHub\windows-shell
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -Capture
```

The script imports your current config files into this repository (only if the repository copy does not yet exist), installs missing dependencies via WinGet, backs up existing config files, creates symbolic links, and generates the Nushell autoload scripts for Starship and Zoxide.

Review the captured files for secrets and hardcoded user paths before pushing. Commit `nushell/config.nu`, `noctty/config.ghostty`, `starship/starship.toml`, and optional `mise/config.toml` along with this script.

## Other PC

```powershell
cd D:\GitHub\windows-shell
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1
```

Symbolic links require Windows Developer Mode or an elevated PowerShell. Existing target files are renamed with a `.backup-TIMESTAMP` suffix before linking. Running the script again preserves correct links. It does not replace an existing repository configuration on `-Capture`.

For dependency-free re-linking and script generation use `-SkipInstall`. The project expects the Nushell configuration to include the mise shims path and any desired Nushell keybindings. Version-specific runtime installations are governed by the optional tracked mise `config.toml`.

## Validate

Open a fresh Noctty window and test `nu --version`, `starship --version`, `zoxide --version`, `mise doctor`, `node --version`, `go version`, and `bun --version` (provided your global mise configuration declares them).
