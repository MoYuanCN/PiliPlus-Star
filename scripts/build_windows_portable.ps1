[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 2147483647)]
    [int]$BuildNumber,

    [ValidateRange(1, 16)]
    [int]$Jobs = 2
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$workspaceRoot = Split-Path $repoRoot -Parent
$flutterRoot = Join-Path $workspaceRoot 'tools\flutter\sdk\flutter-3.47.6-build\flutter'
$flutterBat = Join-Path $flutterRoot 'bin\flutter.bat'
$pubCache = Join-Path $workspaceRoot 'tools\flutter\pub-cache'
$isolatedAppData = Join-Path $workspaceRoot 'tools\flutter\isolated-appdata'
$outputRoot = Join-Path $workspaceRoot 'build\windows-x64-portable'
$releaseDir = Join-Path $repoRoot 'build\windows\x64\runner\Release'
$portableDir = Join-Path $outputRoot "PiliPlus-Star-$BuildNumber"
$zipPath = Join-Path $outputRoot "PiliPlus-Star-Windows-x64-Portable-$BuildNumber.zip"
$cmakeCache = Join-Path $repoRoot 'build\windows\x64\CMakeCache.txt'
$buildLogDir = Join-Path $workspaceRoot 'build\history'
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$buildLog = Join-Path $buildLogDir "windows-incremental-$BuildNumber-$timestamp.log"
$snapshot = Join-Path $buildLogDir "PiliPlus-Star-$BuildNumber-source.patch"
$toolBackupDir = Join-Path $buildLogDir "flutter-hook-backup-$BuildNumber-$timestamp"
$mappingCreated = $false
$buildDrive = [IO.Path]::GetPathRoot($repoRoot).TrimEnd('\').TrimEnd(':')
$mappedWorkspaceRoot = $workspaceRoot
$executionRepo = $repoRoot
$buildSucceeded = $false
$buildExitCode = 1
$buildSeconds = 0
$oldEnvironment = @{}
$toolFiles = @()
$toolBackups = @{}

function Get-WorkspaceUri([string]$Path) {
    return [Uri]::new($Path.TrimEnd('\') + '\').AbsoluteUri
}

if (-not (Test-Path $flutterBat)) { throw "Project-local Flutter is missing: $flutterBat" }
if (-not (Test-Path (Join-Path $repoRoot '.dart_tool\package_config.json'))) {
    throw 'Dart package configuration is missing; run flutter pub get once before using --no-pub.'
}
if (-not (Test-Path $cmakeCache)) { throw "Incremental CMake cache is missing: $cmakeCache" }
if (Test-Path $portableDir) { throw "Portable output already exists: $portableDir" }
if (Test-Path $zipPath) { throw "Portable archive already exists: $zipPath" }

$cacheLine = Select-String -Path $cmakeCache -Pattern '^CMAKE_HOME_DIRECTORY:INTERNAL=(.+)$' |
    Select-Object -First 1
if ($null -eq $cacheLine) { throw 'Could not read the source path from CMakeCache.txt.' }
$cmakeHome = $cacheLine.Matches[0].Groups[1].Value.Trim()
$cacheRepo = Split-Path -Parent $cmakeHome
$cacheDrive = [IO.Path]::GetPathRoot($cacheRepo).TrimEnd('\').TrimEnd(':')
$mappingNeeded = $false
if ($cacheDrive -ne $buildDrive) {
    $drive = $cacheDrive.ToUpperInvariant()
    $substPattern = '^' + [regex]::Escape($drive) + ':\\: => (.+)$'
    $substLine = (& subst.exe | Where-Object { $_ -match $substPattern } | Select-Object -First 1)
    if ($substLine) {
        $mappedRoot = [regex]::Match($substLine, $substPattern).Groups[1].Value.TrimEnd('\')
        if (-not $mappedRoot.Equals($workspaceRoot.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) {
            throw "Drive $drive`: is mapped to another path; refusing to change it."
        }
    } else {
        $mappingNeeded = $true
    }
    $buildDrive = $drive
    $mappedWorkspaceRoot = '{0}:\' -f $drive
    $executionRepo = '{0}:{1}\{2}' -f $drive, [IO.Path]::DirectorySeparatorChar, (Split-Path $repoRoot -Leaf)
} else {
    $executionRepo = $cacheRepo
}

New-Item -ItemType Directory -Force -Path $outputRoot, $buildLogDir, $isolatedAppData | Out-Null
New-Item -ItemType Directory -Path $toolBackupDir | Out-Null

$toolsRoot = '{0}:\tools\flutter' -f $buildDrive
$flutterToolsConfig = Join-Path $flutterRoot 'packages\flutter_tools\.dart_tool\package_config.json'
$hooksRoot = Join-Path $pubCache 'hosted\pub.dev\hooks_runner-1.5.0\lib\src'
$runnerSource = Join-Path $hooksRoot 'build_runner\build_runner.dart'
$processSource = Join-Path $hooksRoot 'utils\run_process.dart'
$toolFiles = @($flutterToolsConfig, $flutterBat, $runnerSource, $processSource)
foreach ($file in $toolFiles) {
    if (-not (Test-Path $file)) { throw "Required local Flutter build file is missing: $file" }
    $toolBackups[$file] = [IO.File]::ReadAllBytes($file)
    Copy-Item -LiteralPath $file -Destination (Join-Path $toolBackupDir ([IO.Path]::GetFileName($file))) -Force
}

$projectConfig = Join-Path $repoRoot '.dart_tool\package_config.json'
$environmentNames = @(
    'FLUTTER_ROOT', 'PUB_CACHE', 'APPDATA', 'CMAKE_BUILD_PARALLEL_LEVEL',
    'CI', 'FLUTTER_SUPPRESS_ANALYTICS'
)
foreach ($name in $environmentNames) {
    $oldEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
$stopwatch = [Diagnostics.Stopwatch]::new()
if ($mappingNeeded) {
    try {
        & subst.exe "$buildDrive`:" $workspaceRoot
        if ($LASTEXITCODE -ne 0) { throw "Could not create the temporary $buildDrive`: workspace mapping." }
        $mappingCreated = $true
    } catch {
        if ($mappingCreated) { & subst.exe "$buildDrive`:" /d }
        throw
    }
}

try {
    $toolConfig = [IO.File]::ReadAllText($flutterToolsConfig) | ConvertFrom-Json
    $hooksPackage = $toolConfig.packages | Where-Object name -eq 'hooks_runner' | Select-Object -First 1
    if ($null -eq $hooksPackage) { throw 'hooks_runner is missing from the local Flutter package configuration.' }
    $hooksUriPath = Join-Path $toolsRoot 'pub-cache\hosted\pub.dev\hooks_runner-1.5.0'
    $hooksPackage.rootUri = [Uri]::new($hooksUriPath.TrimEnd('\') + '\').AbsoluteUri.TrimEnd('/')
    $toolConfig | ConvertTo-Json -Depth 100 |
        Set-Content -LiteralPath $flutterToolsConfig -Encoding utf8

    $runnerText = [IO.File]::ReadAllText($runnerSource)
    $runnerPattern = '(final result = await runProcess\(\r?\n\s*filesystem: _fileSystem,\r?\n\s*workingDirectory: workingDirectory,\r?\n\s*executable: dartExecutable,\r?\n\s*)arguments: arguments,'
    $runnerText = [regex]::Replace(
        $runnerText,
        $runnerPattern,
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($match)
            $match.Groups[1].Value + "arguments: ['--disable-dart-dev', ...arguments],"
        },
        1
    )
    if ($runnerText -notmatch "arguments: \['--disable-dart-dev'") {
        throw 'Could not apply the local native-assets hook compatibility adjustment.'
    }
    [IO.File]::WriteAllText($runnerSource, $runnerText, [Text.UTF8Encoding]::new($false))

    $processText = [IO.File]::ReadAllText($processSource)
    $processPattern = 'runInShell:\s*Platform\.isWindows &&\s*\(!includeParentEnvironment \|\| workingDirectory != null\),'
    $processText = [regex]::Replace($processText, $processPattern, 'runInShell: false,', 1)
    if ($processText -notmatch 'runInShell: false,') {
        throw 'Could not apply the local Windows hook process adjustment.'
    }
    [IO.File]::WriteAllText($processSource, $processText, [Text.UTF8Encoding]::new($false))

    $batText = [IO.File]::ReadAllText($flutterBat)
    $oldInvocation = '"%dart%" --packages="%flutter_tools_dir%\.dart_tool\package_config.json" %FLUTTER_TOOL_ARGS% "%snapshot_path%" %* & "%exit_with_errorlevel%"'
    $newInvocation = '"%dart%" --packages="%flutter_tools_dir%\.dart_tool\package_config.json" %FLUTTER_TOOL_ARGS% "%flutter_tools_dir%\bin\flutter_tools.dart" %* & "%exit_with_errorlevel%"'
    if ($batText.Contains($oldInvocation)) {
        $batText = $batText.Replace($oldInvocation, $newInvocation)
    } elseif (-not $batText.Contains($newInvocation)) {
        throw 'Flutter launcher contents did not match the expected local SDK version.'
    }
    [IO.File]::WriteAllText($flutterBat, $batText, [Text.UTF8Encoding]::new($false))

    $flutterRootForBuild = Join-Path $mappedWorkspaceRoot 'tools\flutter\sdk\flutter-3.47.6-build\flutter'
    $flutterBatForBuild = Join-Path $flutterRootForBuild 'bin\flutter.bat'
    $pubCacheForBuild = Join-Path $mappedWorkspaceRoot 'tools\flutter\pub-cache'
    $appDataForBuild = Join-Path $mappedWorkspaceRoot 'tools\flutter\isolated-appdata'
    $env:FLUTTER_ROOT = $flutterRootForBuild
    $env:PUB_CACHE = $pubCacheForBuild
    $env:APPDATA = $appDataForBuild
    $env:CMAKE_BUILD_PARALLEL_LEVEL = [string]$Jobs
    $env:CI = 'true'
    $env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
    Push-Location $executionRepo
    try {
        $stopwatch.Start()
        $commandErrorActionPreference = $ErrorActionPreference
        try {
            # Windows PowerShell can surface native stderr (including benign
            # CMake developer warnings) as terminating PowerShell errors.
            # Keep the process output in the log and judge success by its code.
            $ErrorActionPreference = 'Continue'
            & $flutterBatForBuild build windows --release --no-pub --build-number $BuildNumber 2>&1 |
                Tee-Object -FilePath $buildLog
            $buildExitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $commandErrorActionPreference
        }
        $stopwatch.Stop()
        $buildSeconds = [int]$stopwatch.Elapsed.TotalSeconds
        if ($buildExitCode -ne 0) { throw "Flutter Windows build failed with exit code $buildExitCode. See $buildLog" }
        $buildSucceeded = $true
    } finally {
        Pop-Location
    }
} finally {
    foreach ($file in $toolFiles) {
        if ($toolBackups.ContainsKey($file)) {
            [IO.File]::WriteAllBytes($file, $toolBackups[$file])
        }
    }
    if (Test-Path $projectConfig) {
        $configText = [IO.File]::ReadAllText($projectConfig)
        $workspaceUri = Get-WorkspaceUri $workspaceRoot
        $configText = $configText.Replace("file:///$buildDrive`:/", $workspaceUri)
        [IO.File]::WriteAllText($projectConfig, $configText, [Text.UTF8Encoding]::new($false))
    }
    foreach ($name in $environmentNames) {
        [Environment]::SetEnvironmentVariable($name, $oldEnvironment[$name], 'Process')
    }
    if ($mappingCreated) { & subst.exe "$buildDrive`:" /d }
}

if (-not $buildSucceeded) { throw "Flutter Windows build failed with exit code $buildExitCode. See $buildLog" }
if (-not (Test-Path (Join-Path $releaseDir 'piliplus.exe'))) { throw 'Release executable was not produced.' }

New-Item -ItemType Directory -Path $portableDir | Out-Null
Copy-Item -Path (Join-Path $releaseDir '*') -Destination $portableDir -Recurse -Force
$exePath = Join-Path $portableDir 'piliplus.exe'
$stream = [IO.File]::OpenRead($exePath)
$reader = [IO.BinaryReader]::new($stream)
try {
    $stream.Position = 0x3c
    $peOffset = $reader.ReadInt32()
    $stream.Position = $peOffset + 4
    $machine = $reader.ReadUInt16()
} finally {
    $reader.Dispose()
    $stream.Dispose()
}
if ($machine -ne 0x8664) { throw ('Portable executable is not x64: 0x{0:X4}' -f $machine) }

$gitBranch = (git -C $repoRoot rev-parse --abbrev-ref HEAD).Trim()
$gitCommit = (git -C $repoRoot rev-parse HEAD).Trim()
git -C $repoRoot diff HEAD --binary "--output=$snapshot"
if ($LASTEXITCODE -ne 0) { throw 'Could not save the tracked source snapshot.' }
$sourceHash = (Get-FileHash -Algorithm SHA256 $snapshot).Hash
$pubspecVersion = (Select-String -Path (Join-Path $repoRoot 'pubspec.yaml') -Pattern '^version:\s*([^+\s]+)' |
    Select-Object -First 1).Matches[0].Groups[1].Value
$version = "$pubspecVersion+$BuildNumber"
$exeVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($exePath).FileVersion
if ($exeVersion -ne $version) { throw "Executable version mismatch: $exeVersion" }
$exeHash = (Get-FileHash -Algorithm SHA256 $exePath).Hash
$buildTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'
$buildInfo = @"
Project: PiliPlus-Star
Repository: $repoRoot
Branch: $gitBranch
Git Commit: $gitCommit
Working Tree: Modified; source snapshot: $snapshot
Source Diff SHA-256: $sourceHash
Build Time: $buildTime
Version: $version
Flutter: 3.47.6
Target: Windows x64 Portable
Build Mode: Incremental, --no-pub, $Jobs parallel CMake jobs
Flutter Build Seconds: $buildSeconds
Executable SHA-256: $exeHash
PE Machine: 0x$('{0:X4}' -f $machine)
Portable Directory: $portableDir
Portable ZIP: $zipPath
"@
Set-Content -LiteralPath (Join-Path $portableDir 'build-info.txt') -Value $buildInfo -Encoding utf8

Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory(
    $portableDir,
    $zipPath,
    [IO.Compression.CompressionLevel]::Fastest,
    $false
)

$archive = [IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $entries = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
    foreach ($required in @('piliplus.exe', 'data/app.so', 'flutter_windows.dll', 'build-info.txt')) {
        if ($required -notin $entries) { throw "ZIP is missing $required." }
    }
    foreach ($entry in $archive.Entries) {
        $entryStream = $entry.Open()
        try {
            $buffer = New-Object byte[] 65536
            while ($entryStream.Read($buffer, 0, $buffer.Length) -gt 0) { }
        } finally {
            $entryStream.Dispose()
        }
    }
    $entryCount = $archive.Entries.Count
} finally {
    $archive.Dispose()
}

$zipHash = (Get-FileHash -Algorithm SHA256 $zipPath).Hash
$extra = @"
ZIP SHA-256: $zipHash
ZIP Entries: $entryCount
ZIP Read Check: PASS
EXE Version Check: PASS
"@
Set-Content -LiteralPath (Join-Path $outputRoot 'build-info.txt') -Value ($buildInfo + "`r`n" + $extra) -Encoding utf8

Write-Output "Version=$version"
Write-Output "FlutterBuildSeconds=$buildSeconds"
Write-Output "Target=Windows x64 Portable"
Write-Output "ParallelJobs=$Jobs"
Write-Output "ZIP=$zipPath"
Write-Output "ZIP_SHA256=$zipHash"
Write-Output "EXE_SHA256=$exeHash"
Write-Output "ZIP_Entries=$entryCount"
