param(
  [string]$SourceDir = ".",
  [string]$ClassDir  = ""
)

if (-not $ClassDir) { $ClassDir = $SourceDir }

$project = Split-Path $SourceDir -Leaf
$outDir = Split-Path (Split-Path $SourceDir -Parent) -Parent
$outputFile = Join-Path $outDir "$project`_Required_Libs.txt"

Write-Host "Maven dependencies for imports in $SourceDir`n" -ForegroundColor Cyan

$imports = Get-ChildItem -Path $SourceDir -Recurse -Filter '*.java' -ErrorAction SilentlyContinue |
  Select-String '^[ \t]*import[ \t]+([^;]+);' |
  ForEach-Object { $_.Matches[0].Groups[1].Value } |
  Where-Object { $_ -notmatch '^java\.' -and $_ -notmatch "^$project\." } |
  Sort-Object -Unique

$map = @{}
foreach ($pkg in $imports) {
  $query = [Uri]::EscapeDataString("fc:`"$pkg`"")
  try {
    $json = Invoke-RestMethod -Uri "https://search.maven.org/solrsearch/select?q=$query&rows=1&wt=json" -UseBasicParsing
    if ($json.response.numFound -gt 0) {
      $d = $json.response.docs[0]
      $key = "$($d.g):$($d.a):$($d.latestVersion)"
      if (-not $map.ContainsKey($key)) { $map[$key] = @() }
      $map[$key] += $pkg
    }
  } catch {
    Write-Host "!!! Failed to query Maven for $pkg !!!" -ForegroundColor Red
  }
}

$outLines = @()
if ($map.Count -eq 0) {
  Write-Host "  (no external dependencies found)`n" -ForegroundColor Yellow
  $outLines += "(no external dependencies found)"
} else {
  foreach ($key in $map.Keys) {
    Write-Host "Found $($key):" -ForegroundColor Green
    $outLines += "Found $($key):"
    foreach ($imp in $map[$key]) {
      Write-Host "  - $imp" -ForegroundColor Yellow
      $outLines += "- $imp"
    }
    $parts = $key.Split(':')
    $url = "https://search.maven.org/artifact/$($parts[0])/$($parts[1])/$($parts[2])/jar"
    Write-Host "  - $url" -ForegroundColor Blue
    $outLines += "- $url"
    Write-Host ""
    $outLines += ""
  }
}

Write-Host "Analyzing class file versions in $ClassDir`n" -ForegroundColor Cyan

$max = Get-ChildItem -Path $ClassDir -Recurse -Filter '*.class' -ErrorAction SilentlyContinue |
  ForEach-Object {
    $b = [IO.File]::ReadAllBytes($_.FullName)
    ($b[6] -shl 8) -bor $b[7]
  } |
  Measure-Object -Maximum |
  Select-Object -ExpandProperty Maximum

switch ($max) {
  45 { $ver = "Java 1.1" } 46 { $ver = "Java 1.2" }
  47 { $ver = "Java 1.3" } 48 { $ver = "Java 1.4" }
  49 { $ver = "Java 5"   } 50 { $ver = "Java 6"   }
  51 { $ver = "Java 7"   } 52 { $ver = "Java 8"   }
  53 { $ver = "Java 9"   } 54 { $ver = "Java 10"  }
  55 { $ver = "Java 11"  } 56 { $ver = "Java 12"  }
  57 { $ver = "Java 13"  } 58 { $ver = "Java 14"  }
  59 { $ver = "Java 15"  } 60 { $ver = "Java 16"  }
  61 { $ver = "Java 17"  } 62 { $ver = "Java 18"  }
  63 { $ver = "Java 19"  } 64 { $ver = "Java 20"  }
  Default { $ver = "Unknown (major version $max)" }
}

Write-Host "`nRecommended Java version: $ver`n" -ForegroundColor Magenta
$outLines += "Recommended Java version: $ver"

$outLines | Set-Content -Path $outputFile -Encoding UTF8
Write-Host "Output written to $outputFile`nDone." -ForegroundColor Gray
