param(
  [string]$SourceDir = ".",
  [string]$ClassDir  = ""
)

if (-not $ClassDir) { $ClassDir = $SourceDir }

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$commonHeaders = @{
  'User-Agent' = 'Mozilla/5.0'
  'Accept'     = 'application/json'
}

Write-Host "Scanning for Maven dependencies and Java class version..." -ForegroundColor Cyan

$imports = Get-ChildItem -Path $SourceDir -Recurse -Filter '*.java' -ErrorAction SilentlyContinue |
  Select-String '^[ \t]*import[ \t]+([^;]+);' |
  ForEach-Object { $_.Matches.Groups[1].Value } |
  Where-Object { $_ -notmatch '^java\.' -and $_ -notmatch '^javax\.' } |
  Sort-Object -Unique

$total = $imports.Count; $i = 0
$map   = @{}

foreach ($pkg in $imports) {
  $i++
  $percent = [int](($i / $total) * 100)
  Write-Progress `
    -Activity      "Querying Maven Central" `
    -Status        ("{0} of {1}: {2}" -f $i, $total, $pkg) `
    -PercentComplete $percent

  $classPart = [Uri]::EscapeDataString($pkg)
  $url       = "https://search.maven.org/solrsearch/select?q=fc%3A%22$classPart%22&rows=1&wt=json"

  try {
    $json = Invoke-RestMethod `
      -Uri     $url `
      -Headers $commonHeaders `
      -UseBasicParsing

    if ($json.response.numFound -gt 0) {
      $d   = $json.response.docs[0]
      $key = "{0}:{1}:{2}" -f $d.g, $d.a, $d.latestVersion
      if (-not $map.ContainsKey($key)) { $map[$key] = @() }
      $map[$key] += $pkg
    }
  }
  catch {
    Write-Host ("!!! Error querying Maven for {0}: {1} !!!" -f $pkg, $_.Exception.Message) -ForegroundColor Red
  }

  Start-Sleep -Milliseconds 750
}

Write-Progress -Activity "Querying Maven Central" -Completed

if ($map.Count -eq 0) {
  Write-Host "(no external dependencies found)" -ForegroundColor Yellow
}
else {
  foreach ($key in $map.Keys) {
    foreach ($imp in $map[$key]) {
      Write-Host ("  - {0}" -f $imp) -ForegroundColor Yellow
    }
    $parts = $key.Split(':')
    $jarUrl = "https://search.maven.org/artifact/{0}/{1}/{2}/jar" -f $parts[0], $parts[1], $parts[2]
    Write-Host ("  -> {0}" -f $jarUrl) -ForegroundColor Blue
    Write-Host ""
  }
}

Write-Host "Analyzing class file versions..." -ForegroundColor Cyan
$max = Get-ChildItem -Path $ClassDir -Recurse -Filter '*.class' -ErrorAction SilentlyContinue |
  ForEach-Object {
    $b = [IO.File]::ReadAllBytes($_.FullName)
    ($b[6] -shl 8) -bor $b[7]
  } | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum

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

$outputFile = Join-Path (Split-Path (Split-Path $SourceDir -Parent) -Parent) "$((Split-Path $SourceDir -Leaf))`_Required_Libs.txt"
$out = @()
foreach ($key in $map.Keys) {
  $out += ("Found {0}:" -f $key)
  foreach ($imp in $map[$key]) { $out += (" - {0}" -f $imp) }
  $parts = $key.Split(':')
  $out += (" - https://search.maven.org/artifact/{0}/{1}/{2}/jar" -f $parts[0], $parts[1], $parts[2])
  $out += ""
}
$out += ("Recommended Java version: {0}" -f $ver)
$out | Set-Content -Path $outputFile -Encoding UTF8

exit 0
