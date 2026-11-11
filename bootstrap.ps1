[CmdletBinding()]
param(
    [switch]$Capture,
    [switch]$SkipInstall
)

$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$utf8 = [System.Text.UTF8Encoding]::new($false)

$files = @(
    @{ Source = (Join-Path $env:APPDATA 'nushell\config.nu'); Repo = 'nushell\config.nu'; Required = $true },
    @{ Source = (Join-Path $env:LOCALAPPDATA 'noctty\config.ghostty'); Repo = 'noctty\config.ghostty'; Required = $true },
    @{ Source = (Join-Path $env:APPDATA 'starship.toml'); Repo = 'starship\starship.toml'; Required = $true },
    @{ Source = (Join-Path $HOME '.config\mise\config.toml'); Repo = 'mise\config.toml'; Required = $false }
)

function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = @($machine, $user, $env:Path) -join ';'
}

function Find-Executable([string]$Name, [string[]]$Fallbacks = @()) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($candidate in $Fallbacks) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    throw "Executable missing: $Name (open a new PowerShell and retry)"
}

function Write-Utf8([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

if ($Capture) {
    foreach ($file in $files) {
        $dest = Join-Path $repo $file.Repo
        if (Test-Path -LiteralPath $dest) {
            Write-Host "Already tracked: $($file.Repo)"
            continue
        }
        if (-not (Test-Path -LiteralPath $file.Source -PathType Leaf)) {
            if ($file.Required) { throw "Current configuration missing: $($file.Source)" }
            continue
        }
        New-Item -ItemType Directory -Path (Split-Path $dest) -Force | Out-Null
        Copy-Item -LiteralPath $file.Source -Destination $dest
        if ($file.Repo -eq 'noctty\config.ghostty') {
            $contents = [System.IO.File]::ReadAllText($dest)
            $contents = [regex]::Replace($contents, '(?m)^command\s*=\s*.*?nu\.exe\s*$', 'command = nu.exe')
            Write-Utf8 $dest $contents
        }
        Write-Host "Captured: $($file.Repo)"
    }
}

if (-not $SkipInstall) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw 'WinGet not found' }
    $packages = @(
        'AmanThanvi.noctty',
        'Nushell.Nushell',
        'Starship.Starship',
        'ajeetdsouza.zoxide',
        'rsteube.Carapace',
        'junegunn.fzf',
        'eza-community.eza',
        'sharkdp.bat',
        'sharkdp.fd',
        'jdx.mise',
        'DEVCOM.JetBrainsMonoNerdFont',
        'Git.Git',
        'Microsoft.VisualStudioCode'
    )
    foreach ($id in $packages) {
        Write-Host "Checking $id..."
        $listed = (& winget list --id $id --exact --accept-source-agreements 2>&1 | Out-String)
        if ($LASTEXITCODE -eq 0 -and $listed -match [regex]::Escape($id)) { continue }
        & winget install --id $id --exact --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { throw "WinGet failed: $id ($LASTEXITCODE)" }
    }
    Refresh-Path
}

foreach ($file in $files) {
    $source = Join-Path $repo $file.Repo
    $target = $file.Source
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        if ($file.Required) { throw "Repository config missing: $source (run -Capture on the configured PC first)" }
        continue
    }
    $parent = Split-Path $target
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $existing = Get-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
    if ($existing -and $existing.LinkType -eq 'SymbolicLink') {
        $linkTarget = $existing.Target
        if ($linkTarget -is [array]) { $linkTarget = $linkTarget[0] }
        if ([string]::Equals([System.IO.Path]::GetFullPath([string]$linkTarget), [System.IO.Path]::GetFullPath($source), [StringComparison]::OrdinalIgnoreCase)) {
            Write-Host "Already linked: $target"
            continue
        }
    }
    $backup = $null
    if ($existing) {
        $backup = "$target.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss-fff')"
        Move-Item -LiteralPath $target -Destination $backup
        Write-Host "Backup: $backup"
    }
    try {
        New-Item -ItemType SymbolicLink -Path $target -Target $source -ErrorAction Stop | Out-Null
        Write-Host "Linked: $target -> $source"
    } catch {
        if ($backup -and -not (Test-Path -LiteralPath $target)) { Move-Item -LiteralPath $backup -Destination $target }
        throw "Cannot create symlink ($target). Enable Windows Developer Mode or run PowerShell as administrator. $($_.Exception.Message)"
    }
}

Refresh-Path
$nuExe = Find-Executable 'nu.exe' @((Join-Path $env:LOCALAPPDATA 'Programs\nu\bin\nu.exe'))
$starshipExe = Find-Executable 'starship.exe' @((Join-Path $HOME 'scoop\shims\starship.exe'))
$zoxideExe = Find-Executable 'zoxide.exe'

$autoload = Join-Path $env:APPDATA 'nushell\vendor\autoload'
New-Item -ItemType Directory -Path $autoload -Force | Out-Null
$starshipScript = & $starshipExe init nu | Out-String
if ($LASTEXITCODE -ne 0) { throw 'Starship initialization failed' }
# Avoid embedding a machine-specific installation path in generated autoload code.
$starshipScript = [regex]::Replace($starshipScript, "\^'[^']*starship\.exe'", '^starship', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$starshipScript = [regex]::Replace($starshipScript, '\^"[^"]*starship\.exe"', '^starship', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$starshipAutoload = Join-Path $autoload 'starship.nu'
if (Test-Path -LiteralPath $starshipAutoload) {
    Copy-Item -LiteralPath $starshipAutoload -Destination ($starshipAutoload + '.bak') -Force
}
Write-Utf8 $starshipAutoload $starshipScript
$zoxideScript = & $zoxideExe init nushell --cmd cd | Out-String
if ($LASTEXITCODE -ne 0) { throw 'Zoxide initialization failed' }
Write-Utf8 (Join-Path $autoload 'zoxide.nu') $zoxideScript

if (-not $SkipInstall) {
    $miseExe = Find-Executable 'mise.exe'
    & $miseExe install
    if ($LASTEXITCODE -ne 0) { throw 'mise install failed' }
}

& $nuExe --no-config-file -c 'print "Nushell installed"'
if ($LASTEXITCODE -ne 0) { throw 'Nushell executable check failed' }
Write-Host 'Bootstrap complete. Open a new Noctty window.'
