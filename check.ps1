<#
.SYNOPSIS
Incrementally compile the MSVC objects needed for a quick check of changed C/C++ files.
.DESCRIPTION
Compile each requested source in every configured target that uses it. For each
header, use Ninja's recorded dependencies to check a representative translation
unit per target. In a fresh build tree, pass a source that includes the header
so Ninja can record the dependency. Paths are relative to the repository root.
.EXAMPLE
./check.ps1 -Game EZ2 -Files sp/src/game/server/ai_basenpc_movement.cpp,sp/src/game/server/ai_basenpc.h
#>

#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]] $Files,

    [ValidateSet('EZ2', 'EZ1', 'HL2', 'EPISODIC', 'All')]
    [string[]] $Game,

    [ValidateSet('Debug', 'Release')]
    [string] $Configuration,

    [ValidateRange(1, 2147483647)]
    [int] $Jobs,

    [string] $BuildDirectory
)

& (Join-Path $PSScriptRoot 'scripts/Invoke-Build.ps1') @PSBoundParameters
exit $LASTEXITCODE
