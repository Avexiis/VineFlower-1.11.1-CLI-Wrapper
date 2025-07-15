param(
  [string]$SourceDir,
  [string]$ClassDir,
  [string]$Project
)

$base    = Split-Path (Split-Path $SourceDir -Parent) -Parent
$reqFile = Join-Path $base "$Project`_Required_Libs.txt"
$verLine = Select-String -Path $reqFile -Pattern '^Recommended Java version:' -SimpleMatch | Select-Object -First 1
if ($verLine) {
  $verText = ($verLine.Line -split ':')[1].Trim()
} else {
  $verText = 'latest'
}

if ($verText -match 'Java\s+(\d+)') {
  $recVer = [int]$matches[1]
} else {
  $recVer = 0
}

$javaRoot = 'C:\Program Files\Java'
$installs = Get-ChildItem $javaRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'jdk|jre' } |
            ForEach-Object {
              $n = [int](([regex]::Match($_.Name, '\d+')).Value)
              [PSCustomObject]@{ Path = $_.FullName; Version = $n }
            } |
            Where-Object { $_.Version -ge $recVer } |
            Sort-Object Version

if ($installs.Count -gt 0) {
  $jdkPath = $installs[0].Path
  Write-Host "Using Java install at $jdkPath (v$($installs[0].Version))" -ForegroundColor Green
} else {
  $jdkPath = "C:\Program Files\Java\jdk-$verText"
  Write-Host "!!! No matching Java install found. Please install Java $verText or adjust JDK_PATH in your bat files. !!!" -ForegroundColor Yellow
}

$libsDir = Join-Path $SourceDir libs
if (-not (Test-Path $libsDir)) { New-Item -Path $libsDir -ItemType Directory | Out-Null }
Write-Host "Downloading JARs into $libsDir`n" -ForegroundColor Cyan

$urls = Get-Content $reqFile |
        Where-Object { $_ -match '^\s*-\s+https?://' } |
        ForEach-Object { $_ -replace '^\s*-\s+', '' }

$total = $urls.Count; $i = 0
foreach ($url in $urls) {
  $i++
  $pct = [int](($i / $total) * 100)
  Write-Progress -Activity "Downloading JARs" `
                 -Status    "($i/$total) $url" `
                 -PercentComplete $pct

  $parts     = $url.Split('/')
  if ($parts.Length -ge 6) {
    $artifact = $parts[-3]
    $version  = $parts[-2]
    $fileName = "$artifact-$version.jar"
  } else {
    $fileName = $parts[-1]
  }
  $dest = Join-Path $libsDir $fileName

  try {
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -Headers @{
      'User-Agent' = 'Mozilla/5.0'
    }
    Write-Host "Downloaded $fileName" -ForegroundColor DarkGreen
  } catch {
    Start-Sleep -Seconds 2
    try {
      Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -Headers @{
        'User-Agent' = 'Mozilla/5.0'
      }
      Write-Host "Downloaded $fileName (after retry)" -ForegroundColor DarkGreen
    } catch {
      Write-Host "!!! Failed to download $url !!!" -ForegroundColor Red
    }
  }
}
Write-Progress -Activity "Downloading JARs" -Completed
Write-Host "`nAll JARs downloaded.`n" -ForegroundColor Green

$mains = Get-ChildItem $SourceDir -Recurse -Filter '*.java' |
         Where-Object { Select-String -Path $_.FullName -Pattern 'public\s+static\s+void\s+main\s*\(' -Quiet }
if ($mains.Count -eq 0) {
  Write-Host "!!! No main() found; defaulting to MainClass !!!" -ForegroundColor Yellow
  $mainClass = "MainClass"
} else {
  $first     = $mains[0]
  Write-Host "Found main file: $($first.FullName)" -ForegroundColor Green
  $pkgLine   = Select-String -Path $first.FullName -Pattern '^[ \t]*package\s+([\w\.]+)\s*;' -SimpleMatch
  $pkg       = if ($pkgLine) { $pkgLine.Matches[0].Groups[1].Value } else { '' }
  $className = [IO.Path]::GetFileNameWithoutExtension($first.Name)
  $mainClass = if ($pkg) { "$pkg.$className" } else { $className }
  Write-Host "Using entry point: $mainClass`n" -ForegroundColor Green
}

$compile = @(
  '@echo off',
  'setlocal',
  "set ""JDK_DIR=$jdkPath""",
  'if not exist classes mkdir classes',
  'for /R %%f in (*.java) do "%JDK_DIR%\bin\javac.exe" -d classes "%%f"',
  'echo Compilation complete.',
  'pause'
)
$compilePath = Join-Path $SourceDir 'compile.bat'
$compile | Set-Content -Path $compilePath -Encoding ASCII
Write-Host "Generated compile.bat" -ForegroundColor Cyan

$run = @(
  '@echo off',
  'setlocal',
  "set ""JDK_DIR=$jdkPath""",
  'if not exist classes echo (You need to run compile.bat first)&pause&exit /b',
  "java -cp libs\*;classes $mainClass",
  'pause'
)
$runPath = Join-Path $SourceDir 'run.bat'
$run | Set-Content -Path $runPath -Encoding ASCII
Write-Host "Generated run.bat" -ForegroundColor Cyan

exit 0
