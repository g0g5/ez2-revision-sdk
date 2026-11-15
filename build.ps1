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
    [string[]] $Game,

    [ValidateSet('Debug', 'Release')]
    [string] $Configuration,

    [ValidateSet('game', 'shaders', 'maptools', 'tools', 'everything')]
    [string] $Group,

    [ValidateNotNullOrEmpty()]
    [string[]] $Target,

    [ValidateRange(1, 2147483647)]
    [int] $Jobs,

    [switch] $Clean,
    [switch] $ConfigureOnly,
    [string] $BuildDirectory,
    [string[]] $CMakeArguments
)

& (Join-Path $PSScriptRoot 'scripts/Invoke-Build.ps1') @PSBoundParameters
exit $LASTEXITCODE
