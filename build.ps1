<#
.SYNOPSIS
Configure and build Revision SDK for Windows x86 with CMake and Ninja.
.DESCRIPTION
Finds the latest Visual Studio installation (including previews) with x86/x64
C++ tools using vswhere, then initializes its official developer shell with an
x64 host and x86 target. Uses only that installation's bundled CMake and Ninja.
Process environment changes are restored on exit; system settings are unchanged.
Relative build directories are resolved against this script's directory, not
the caller's working directory. No cmd.exe or batch scripts are used.
.PARAMETER Game
One or more games: EZ2 (default), EZ1, HL2, EPISODIC, or All. All expands to
EZ2, EZ1, HL2, EPISODIC. Duplicates are removed while preserving order.
.PARAMETER Configuration
Debug or Release (default).
.PARAMETER Group
Build group: game (default), shaders, maptools, tools, or everything.
.PARAMETER Target
Optional Ninja targets. If omitted, builds the configured group's default target.
.PARAMETER Jobs
Maximum parallel build jobs. Defaults to the logical processor count.
.PARAMETER Clean
Pass --clean-first to the build step. Has no effect with ConfigureOnly.
.PARAMETER ConfigureOnly
Configure without building or cleaning.
.PARAMETER BuildDirectory
Build tree, defaulting to build/<games-joined-by-hyphens>/<Configuration> under
the repository root, for example build/EZ2/Release or build/EZ2-EZ1/Debug.
.PARAMETER CMakeArguments
Additional arguments appended to the CMake configure command. Pass each argument
as a separate array element; quote arguments containing spaces or semicolons.
.EXAMPLE
./build.ps1
Configure and build EZ2 Release, group game.
.EXAMPLE
./build.ps1 -Game EZ2,EZ1 -Configuration Debug -Target client_ez2,server_ez1 -Jobs 8
Build the EZ2 client and EZ1 server targets in Debug.
.EXAMPLE
./build.ps1 -Game All -Group everything -ConfigureOnly -CMakeArguments '-DFOO=ON'
Configure all games without starting a build.
#>

#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('EZ2', 'EZ1', 'HL2', 'EPISODIC', 'All')]
    [string[]] $Game = @('EZ2'),

    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release',

    [ValidateSet('game', 'shaders', 'maptools', 'tools', 'everything')]
    [string] $Group = 'game',

    [ValidateNotNullOrEmpty()]
    [string[]] $Target,

    [ValidateRange(1, 2147483647)]
    [int] $Jobs = [Environment]::ProcessorCount,

    [switch] $Clean,
    [switch] $ConfigureOnly,
    [string] $BuildDirectory,
    [string[]] $CMakeArguments = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Inspect native exit codes explicitly, regardless of the caller's preference.
$PSNativeCommandUseErrorActionPreference = $false

$exitCode = 0
$savedEnvironment = $null

function Invoke-CMake {
    param([string[]] $Arguments)

    & $script:cmakePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        $script:exitCode = $LASTEXITCODE
        throw "CMake failed with exit code $LASTEXITCODE."
    }
}

try {
    if (-not $IsWindows) {
        throw 'This script supports Windows x86 builds only. Run it with PowerShell 7 on Windows.'
    }

    $games = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in $Game) {
        $expanded = if ($entry -ieq 'All') {
            @('EZ2', 'EZ1', 'HL2', 'EPISODIC')
        } else {
            @($entry.ToUpperInvariant())
        }
        foreach ($name in $expanded) {
            if (-not $games.Contains($name)) {
                $games.Add($name)
            }
        }
    }
    if ($games.Count -eq 0) {
        throw 'Specify at least one game with -Game.'
    }

    # ValidateSet is case-insensitive; canonicalize paths and CMake values.
    $Configuration = if ($Configuration -ieq 'Debug') { 'Debug' } else { 'Release' }
    $Group = $Group.ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($BuildDirectory)) {
        $BuildDirectory = Join-Path 'build' (Join-Path ($games -join '-') $Configuration)
    }
    if (-not [IO.Path]::IsPathFullyQualified($BuildDirectory)) {
        $BuildDirectory = Join-Path $PSScriptRoot $BuildDirectory
    }
    $BuildDirectory = [IO.Path]::GetFullPath($BuildDirectory)

    $vswherePath = $null
    foreach ($programFiles in @(${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
        if ($programFiles) {
            $candidate = Join-Path $programFiles 'Microsoft Visual Studio/Installer/vswhere.exe'
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                $vswherePath = $candidate
                break
            }
        }
    }
    if (-not $vswherePath) {
        $vswhereCommand = Get-Command vswhere.exe -CommandType Application -ErrorAction SilentlyContinue
        if ($vswhereCommand) {
            $vswherePath = $vswhereCommand.Source
        }
    }
    if (-not $vswherePath) {
        throw 'vswhere.exe was not found. Install Visual Studio Installer and the Desktop development with C++ workload (including x86/x64 tools).'
    }

    $installationPaths = @(& $vswherePath -latest -prerelease -products '*' `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath)
    if ($LASTEXITCODE -ne 0) {
        $exitCode = $LASTEXITCODE
        throw "vswhere failed with exit code $LASTEXITCODE."
    }
    $vsPath = $installationPaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
    if (-not $vsPath) {
        throw 'No Visual Studio installation with x86/x64 C++ tools was found. Install the Desktop development with C++ workload in Visual Studio Build Tools.'
    }
    $vsPath = $vsPath.Trim()

    $devShellPath = Join-Path $vsPath 'Common7/Tools/Microsoft.VisualStudio.DevShell.dll'
    $cmakePath = Join-Path $vsPath 'Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe'
    $ninjaPath = Join-Path $vsPath 'Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja/ninja.exe'
    foreach ($tool in @(
        @{ Name = 'Microsoft.VisualStudio.DevShell.dll'; Path = $devShellPath; Remedy = 'Repair the Visual Studio installation.' },
        @{ Name = 'CMake'; Path = $cmakePath; Remedy = 'Install the C++ CMake tools for Windows component in Visual Studio Installer.' },
        @{ Name = 'Ninja'; Path = $ninjaPath; Remedy = 'Install the C++ CMake tools for Windows component in Visual Studio Installer.' }
    )) {
        if (-not (Test-Path -LiteralPath $tool.Path -PathType Leaf)) {
            throw "$($tool.Name) was not found at '$($tool.Path)'. $($tool.Remedy)"
        }
    }

    $savedEnvironment = [Environment]::GetEnvironmentVariables('Process')
    Import-Module $devShellPath -Scope Local -ErrorAction Stop
    Enter-VsDevShell -VsInstallPath $vsPath -SkipAutomaticLocation `
        -DevCmdArguments '-arch=x86 -host_arch=x64' -ErrorAction Stop
    if ($env:VSCMD_ARG_HOST_ARCH -ine 'x64' -or $env:VSCMD_ARG_TGT_ARCH -ine 'x86') {
        throw 'Visual Studio developer shell did not initialize the required x64 host / x86 target environment.'
    }

    Write-Host "Visual Studio: $vsPath"
    Write-Host "Games: $($games -join ', '); configuration: $Configuration; group: $Group"
    Write-Host "Build directory: $BuildDirectory"

    $configureArguments = @(
        '-S', $PSScriptRoot,
        '-B', $BuildDirectory,
        '-G', 'Ninja',
        "-DCMAKE_BUILD_TYPE=$Configuration",
        "-DCMAKE_MAKE_PROGRAM=$ninjaPath",
        "-DREVISION_GAMES=$($games -join ';')",
        "-DREVISION_BUILD_GROUP=$Group"
    ) + $CMakeArguments
    Invoke-CMake -Arguments $configureArguments

    if (-not $ConfigureOnly) {
        $buildArguments = @('--build', $BuildDirectory, '--parallel', "$Jobs")
        if ($Clean) {
            $buildArguments += '--clean-first'
        }
        if ($Target) {
            $buildArguments += '--target'
            $buildArguments += $Target
        }
        Invoke-CMake -Arguments $buildArguments
    }
} catch {
    if ($exitCode -eq 0) {
        $exitCode = 1
    }
    Write-Error -Message $_.Exception.Message -ErrorAction Continue
} finally {
    if ($null -ne $savedEnvironment) {
        # Restore only this process, including variables introduced by DevShell.
        $currentEnvironment = [Environment]::GetEnvironmentVariables('Process')
        foreach ($name in $currentEnvironment.Keys) {
            if (-not $savedEnvironment.Contains($name)) {
                [Environment]::SetEnvironmentVariable($name, $null, 'Process')
            }
        }
        foreach ($name in $savedEnvironment.Keys) {
            [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process')
        }
    }
}

exit $exitCode
