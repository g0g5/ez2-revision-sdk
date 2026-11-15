function Get-CheckFiles {
    param([string[]] $Files, [string] $RepositoryRoot)

    $sources = @{}
    $headers = @{}
    foreach ($file in $Files) {
        $path = [IO.Path]::GetFullPath($file, $RepositoryRoot)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "File not found: $file"
        }
        switch -Regex ([IO.Path]::GetExtension($path)) {
            '^\.(c|cc|cpp|cxx)$' { $sources[$path] = $file }
            '^\.(h|hh|hpp|hxx|inl|inc|ipp)$' { $headers[$path] = $file }
            default { throw "Expected a C/C++ source or header: $file" }
        }
    }
    return @{ Sources = $sources; Headers = $headers }
}

function Get-HeaderTargets {
    param(
        [string[]] $Headers,
        [string] $BuildDirectory,
        [string] $NinjaPath,
        [hashtable] $Owners,
        [hashtable] $PchConsumers,
        [hashtable] $SelectedTargets
    )

    $byHeader = @{}
    foreach ($header in $Headers) {
        $byHeader[$header] = @{}
    }

    $dependencies = & $NinjaPath -C $BuildDirectory -t deps
    if ($LASTEXITCODE -ne 0) {
        throw "Ninja could not read the recorded dependencies (exit code $LASTEXITCODE)."
    }

    $object = $null
    foreach ($line in $dependencies) {
        if ($line -match '^(\S.*): #deps ') {
            $object = $Matches[1].Replace('\', '/')
            continue
        }
        if (-not $object -or -not $Owners.ContainsKey($object) -or -not $line.StartsWith('    ')) {
            continue
        }

        $header = [IO.Path]::GetFullPath($line.TrimStart(), $BuildDirectory)
        if (-not $byHeader.ContainsKey($header)) {
            continue
        }

        $owner = $Owners[$object]
        # MSVC records headers from a PCH on its producer, which supplies multiple objects.
        $candidate = if ($object -like '*/cmake_pch.*.obj' -and $PchConsumers.ContainsKey($owner)) {
            $PchConsumers[$owner]
        } else {
            $object
        }
        $choices = $byHeader[$header]
        if (-not $choices.ContainsKey($owner) -or $SelectedTargets.ContainsKey($candidate)) {
            $choices[$owner] = $candidate
        }
    }
    return $byHeader
}

function Invoke-ObjectCheck {
    param(
        [hashtable] $CheckFiles,
        [string] $BuildDirectory,
        [int] $Jobs,
        [string] $NinjaPath
    )

    $sources = $CheckFiles.Sources
    $headers = $CheckFiles.Headers
    $database = Get-Content -Raw -LiteralPath (Join-Path $BuildDirectory 'compile_commands.json') |
        ConvertFrom-Json -AsHashtable
    $owners = @{}
    $pchConsumers = @{}
    $targets = @{}
    $mappedSources = @{}
    foreach ($entry in $database) {
        $output = $entry['output']
        if (-not $output -and $entry.command -match '(?:^|\s)/Fo(?:"([^"]+)"|(\S+))') {
            # Older CMake releases expose the object only in the MSVC command.
            $output = $Matches[1] + $Matches[2]
        }
        if (-not $output) {
            continue
        }
        $objectPath = [IO.Path]::GetFullPath($output, $entry.directory)
        $object = [IO.Path]::GetRelativePath($BuildDirectory, $objectPath).Replace('\', '/')
        if ($object -notmatch '^CMakeFiles/([^/]+)\.dir/.+\.obj$') {
            continue
        }
        $owner = $Matches[1]
        $owners[$object] = $owner

        $source = [IO.Path]::GetFullPath($entry.file, $entry.directory)
        $requested = $sources.ContainsKey($source)
        if ($requested) {
            $targets[$object] = $true
            $mappedSources[$source] = $true
        }
        if ($headers.Count -and $entry.command -match '(?:^|\s)/Yu' -and
            ($requested -or -not $pchConsumers.ContainsKey($owner))) {
            $pchConsumers[$owner] = $object
        }
    }

    $unmappedSources = @($sources.Keys | Where-Object { -not $mappedSources.ContainsKey($_) })
    if ($unmappedSources.Count) {
        $names = $unmappedSources | ForEach-Object { $sources[$_] }
        throw "No compile command for $($names -join ', '). Check -Game and the source lists under cmake/targets/."
    }

    $unmappedHeaders = @()
    if ($headers.Count) {
        $dependencyArgs = @{
            BuildDirectory = $BuildDirectory
            NinjaPath = $NinjaPath
            Owners = $owners
            PchConsumers = $pchConsumers
            SelectedTargets = $targets
        }
        $headerTargets = Get-HeaderTargets @dependencyArgs -Headers @($headers.Keys)
        foreach ($header in $headers.Keys) {
            foreach ($object in $headerTargets[$header].Values) {
                $targets[$object] = $true
            }
        }
        $unmappedHeaders = @($headers.Keys | Where-Object { -not $headerTargets[$_].Count })
    }

    if ($targets.Count) {
        $objectTargets = @($targets.Keys | Sort-Object)
        Write-Host "Checking $($objectTargets.Count) object target(s):"
        $objectTargets | ForEach-Object { Write-Host "  $_" }
        Invoke-CMakeBuild -BuildDirectory $BuildDirectory -Jobs $Jobs -Target $objectTargets

        # The first compilation in a clean tree populates Ninja's header dependencies.
        if ($unmappedHeaders.Count) {
            $headerTargets = Get-HeaderTargets @dependencyArgs -Headers $unmappedHeaders
            $unmappedHeaders = @($unmappedHeaders | Where-Object { -not $headerTargets[$_].Count })
        }
    }

    if ($unmappedHeaders.Count) {
        $names = $unmappedHeaders | ForEach-Object { $headers[$_] }
        throw "No recorded include dependency for $($names -join ', '). Pass a source that includes each header in -Files, or build the relevant target to populate Ninja's dependency log."
    }
}
