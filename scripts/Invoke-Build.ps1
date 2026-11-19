#requires -Version 7.0
[CmdletBinding()]
param(
    [string[]] $Game = @('EZ2'),
    [ValidateSet('Debug', 'Release', 'Publish')]
    [string] $Configuration = 'Release',
    [string] $Group = 'game',
    [string[]] $Target,
    [int] $Jobs = [Environment]::ProcessorCount,
    [switch] $Clean,
    [switch] $ConfigureOnly,
    [string] $BuildDirectory,
    [string[]] $CMakeArguments = @(),
    [string[]] $Files
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Inspect native exit codes explicitly, regardless of the caller's preference.
$PSNativeCommandUseErrorActionPreference = $false

$exitCode = 0
$savedEnvironment = $null

function Get-VisualStudioTools {
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
        $script:exitCode = $LASTEXITCODE
        throw "vswhere failed with exit code $LASTEXITCODE."
    }
    $vsPath = $installationPaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
    if (-not $vsPath) {
        throw 'No Visual Studio installation with x86/x64 C++ tools was found. Install the Desktop development with C++ workload in Visual Studio Build Tools.'
    }
    $vsPath = $vsPath.Trim()

    $tools = @{
        InstallPath = $vsPath
        DevShell = Join-Path $vsPath 'Common7/Tools/Microsoft.VisualStudio.DevShell.dll'
        CMake = Join-Path $vsPath 'Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe'
        Ninja = Join-Path $vsPath 'Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja/ninja.exe'
    }
    foreach ($name in 'DevShell', 'CMake', 'Ninja') {
        if (-not (Test-Path -LiteralPath $tools[$name] -PathType Leaf)) {
            $remedy = if ($name -eq 'DevShell') {
                'Repair the Visual Studio installation.'
            } else {
                'Install the C++ CMake tools for Windows component in Visual Studio Installer.'
            }
            throw "$name was not found at '$($tools[$name])'. $remedy"
        }
    }
    return $tools
}

function Invoke-CMake {
    param([string[]] $Arguments)

    & $script:tools.CMake @Arguments
    if ($LASTEXITCODE -ne 0) {
        $script:exitCode = $LASTEXITCODE
        throw "CMake failed with exit code $LASTEXITCODE."
    }
}

function Invoke-CMakeBuild {
    param(
        [string] $BuildDirectory,
        [int] $Jobs,
        [string[]] $Target,
        [switch] $Clean
    )

    $arguments = @('--build', $BuildDirectory, '--parallel', "$Jobs")
    if ($Clean) {
        $arguments += '--clean-first'
    }
    if ($Target) {
        $arguments += '--target'
        $arguments += $Target
    }
    Invoke-CMake -Arguments $arguments
}

try {
    if (-not $IsWindows) {
        throw 'This script supports Windows x86 builds only. Run it with PowerShell 7 on Windows.'
    }

    $repositoryRoot = Split-Path -Parent $PSScriptRoot
    $check = $PSBoundParameters.ContainsKey('Files')
    if ($check) {
        . (Join-Path $PSScriptRoot 'CheckTargets.ps1')
        $checkFiles = Get-CheckFiles -Files $Files -RepositoryRoot $repositoryRoot
    }

    $games = @(foreach ($entry in $Game) {
        if ($entry -ieq 'All') {
            'EZ2', 'EZ1', 'HL2', 'EPISODIC'
        } else {
            $entry.ToUpperInvariant()
        }
    })
    $games = @($games | Select-Object -Unique)
    if (-not $games.Count) {
        throw 'Specify at least one game with -Game.'
    }

    # ValidateSet is case-insensitive; canonicalize paths and CMake values.
    $Configuration = [Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($Configuration.ToLowerInvariant())
    if ([string]::IsNullOrWhiteSpace($BuildDirectory)) {
        $BuildDirectory = Join-Path 'build' (Join-Path ($games -join '-') $Configuration)
    }
    $BuildDirectory = [IO.Path]::GetFullPath($BuildDirectory, $repositoryRoot)

    if ($check) {
        # An object check also works in a tree configured for tools or shaders.
        $cachePath = Join-Path $BuildDirectory 'CMakeCache.txt'
        if (Test-Path -LiteralPath $cachePath) {
            $cachedGroup = Select-String -LiteralPath $cachePath -Pattern '^REVISION_BUILD_GROUP:STRING=(.+)$'
            if ($cachedGroup) {
                $Group = $cachedGroup.Matches[0].Groups[1].Value
            }
        }
    }
    $Group = $Group.ToLowerInvariant()

    $tools = Get-VisualStudioTools
    $savedEnvironment = [Environment]::GetEnvironmentVariables('Process')
    Import-Module $tools.DevShell -Scope Local -ErrorAction Stop
    Enter-VsDevShell -VsInstallPath $tools.InstallPath -SkipAutomaticLocation `
        -DevCmdArguments '-arch=x86 -host_arch=x64' -ErrorAction Stop
    if ($env:VSCMD_ARG_HOST_ARCH -ine 'x64' -or $env:VSCMD_ARG_TGT_ARCH -ine 'x86') {
        throw 'Visual Studio developer shell did not initialize the required x64 host / x86 target environment.'
    }

    Write-Host "Visual Studio: $($tools.InstallPath)"
    Write-Host "Games: $($games -join ', '); configuration: $Configuration; group: $Group"
    Write-Host "Build directory: $BuildDirectory"

    $configureArguments = @(
        '-S', $repositoryRoot,
        '-B', $BuildDirectory,
        '-G', 'Ninja',
        "-DCMAKE_BUILD_TYPE=$Configuration",
        "-DCMAKE_MAKE_PROGRAM=$($tools.Ninja)",
        "-DREVISION_GAMES=$($games -join ';')",
        "-DREVISION_BUILD_GROUP=$Group"
    ) + $CMakeArguments
    Invoke-CMake -Arguments $configureArguments

    if ($check) {
        # The freshly generated database includes any newly registered sources.
        Invoke-ObjectCheck -CheckFiles $checkFiles -BuildDirectory $BuildDirectory -Jobs $Jobs -NinjaPath $tools.Ninja
    } elseif (-not $ConfigureOnly) {
        Invoke-CMakeBuild -BuildDirectory $BuildDirectory -Jobs $Jobs -Target $Target -Clean:$Clean
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
                [Environment]::SetEnvironmentVariable($name, [NullString]::Value, 'Process')
            }
        }
        foreach ($name in $savedEnvironment.Keys) {
            [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process')
        }
    }
}

exit $exitCode
