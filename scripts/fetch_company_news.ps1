<#
.SYNOPSIS Multi-tier parallel company news fetcher.
.DESCRIPTION Reads config/news_sources.json, launches all fetches in parallel
  via Start-Job (PS 5.1+), 8s per-source timeout, 1 retry.
  Extracts headlines from RSS XML and HTML <a> tags.
  Outputs structured JSON.
#>
param(
    [string]$ConfigPath = "config/news_sources.json",
    [string]$OutputPath = $null,
    [int]$MaxTotalSeconds = 90,
    [int]$PerSourceTimeoutSeconds = 8
)

$ErrorActionPreference = "Continue"
$startTime = Get-Date

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not [System.IO.Path]::IsPathRooted($ConfigPath)) {
    $ConfigPath = Join-Path (Join-Path $scriptDir "..") $ConfigPath
    $ConfigPath = (Resolve-Path $ConfigPath).Path
}

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$g = $config.global
$ua = $g.user_agent
$retries = $g.retry_count

Write-Host "[fetch_news] timeout=${PerSourceTimeoutSeconds}s, budget=${MaxTotalSeconds}s, companies=$($config.companies.Count)"

$allTasks = [System.Collections.ArrayList]::new()
foreach ($co in $config.companies) {
    $kw = [System.Net.WebUtility]::UrlEncode($co.keywords[0])
    [void]$allTasks.Add(@{ Company=$co.name; Url="https://news.google.com/rss/search?q=${kw}&hl=en-US&gl=US&ceid=US:en"; Source="Google News RSS"; Tier=1 })
    foreach ($src in $co.sources) {
        $url = $src.url
        if ($src.url_template) {
            $q = [System.Net.WebUtility]::UrlEncode($co.keywords[0])
            $url = $src.url_template -replace '\{query\}', $q
        }
        if ($url) { [void]$allTasks.Add(@{ Company=$co.name; Url=$url; Source=$src.name; Tier=$src.tier }) }
    }
}

Write-Host "[fetch_news] $($allTasks.Count) tasks — launching parallel jobs"

$jobs = @()
foreach ($t in $allTasks) {
    $jobs += Start-Job -Name "fetch_$($t.Company)_$($t.Source)" -ArgumentList $t.Url, $t.Source, $PerSourceTimeoutSeconds, $retries, $ua -ScriptBlock {
        param($url, $src, $to, $rt, $ua)
        
Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
$sw = [System.Diagnostics.Stopwatch]::StartNew(); $a=0; $c=$null; $e=$null; $ok=$false
        do { $a++
            try { $r=Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec $to -UserAgent $ua -MaximumRedirection 3 -ErrorAction Stop; $c=$r.Content; $ok=$true; break }
            catch { $e = if($_.Exception.Response){"HTTP $($_.Exception.Response.StatusCode.value__)"}else{($_.Exception.Message -split "`n")[0]}; if($a -le $rt){Start-Sleep -Milliseconds 500} }
        } while ($a -le $rt)
        $sw.Stop()
        return @{Url=$url; Source=$src; Ok=$ok; Ms=$sw.ElapsedMilliseconds; Att=$a; Err=$e; Content=if($c){$c.Substring(0,[Math]::Min(50000,$c.Length))}else{$null}}
    }
}

$remain = [Math]::Max(3, $MaxTotalSeconds - [int]((Get-Date) - $startTime).TotalSeconds)
Write-Host "[fetch_news] waiting ${remain}s..."
$jobs | Wait-Job -Timeout $remain | Out-Null

$results = @(); $ok=0; $fail=0
$urlToCompany = @{}
foreach ($t in $allTasks) { $urlToCompany[$t.Url] = $t.Company }

foreach ($j in $jobs) {
    $r = Receive-Job $j -ErrorAction SilentlyContinue
    if ($r -and $r.Ok) { $ok++ } else { $fail++ }
    $results += $r
    Remove-Job $j -Force
}

$elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
Write-Host "[fetch_news] ${elapsed}s — ${ok}/$($jobs.Count) ok, $fail failed"

# Extract headlines
$comp = @{}; $seen = @{}
$navSkip = @('Entertainment','Amazon','Apple','Facebook','Google','Microsoft','Samsung','Home','About','Contact','Privacy','Terms','Login','Search','Menu','Skip to','Newsletters','Podcasts','Videos','Reviews','Gear','Science','Security','Policy','Tech','Business','Creators','Features','Events','Store','Forums','Sign','Jobs','RSS','Archives','Best Buy','Vox Media','Terms of Use','Ethics','Cookie','Accessibility','Platform','Status','RSS','Topics')

foreach ($r in $results) {
    if (-not $r -or -not $r.Ok -or -not $r.Content) { continue }
    $cn = $urlToCompany[$r.Url]
    if (-not $cn) { continue }
    if (-not $comp.ContainsKey($cn)) { $comp[$cn] = @() }

    $body = $r.Content
    # Extract RSS items or HTML links
    $blocks = [regex]::Matches($body, '<(item|entry)[^>]*?>(.*?)</\1>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($blocks.Count -eq 0) {
        $blocks = [regex]::Matches($body, '<a[^>]*href="(https?://[^"]+)"[^>]*>(.{20,200}?)</a>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    }

    foreach ($b in $blocks) {
        $txt = $b.Value
        $tm = [regex]::Match($txt, '<title[^>]*>(.*?)</title>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $lm = [regex]::Match($txt, 'href="(https?://[^"]+)"', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        if (-not $lm.Success) { $lm = [regex]::Match($txt, '<link[^>]*>(https?://[^<]+)</link>', [System.Text.RegularExpressions.RegexOptions]::Singleline) }
        $title = if ($tm.Success) { [System.Web.HttpUtility]::HtmlDecode($tm.Groups[1].Value.Trim()) } else { ([System.Web.HttpUtility]::HtmlDecode($txt -replace '<[^>]+>', '')).Trim() }
        $link = if ($lm.Success) { $lm.Groups[1].Value.Trim() } else { "" }
        $title = ($title -replace '\s+', ' ').Trim()
        if ($title.Length -lt 15 -or $link.Length -lt 15 -or $link -match '^(#|javascript:)') { continue }
        $skip = $false; foreach ($w in $navSkip) { if ($title -eq $w) { $skip=$true; break } }; if ($skip) { continue }
        $n = $link.TrimEnd('/').ToLowerInvariant()
        if ($seen.ContainsKey($n)) { continue }; $seen[$n]=$true
        if ($title.Length -le 200) { $comp[$cn] += @{Title=$title; Url=$link; Source=$r.Source} }
    }
}

$out = @{ FetchTime=Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"; Elapsed=$elapsed; Tasks=$jobs.Count; Ok=$ok; Failed=$fail; Companies=@() }
foreach ($cn in ($comp.Keys | Sort-Object)) {
    $items = @($comp[$cn] | Select-Object -First 15)
    $out.Companies += @{ Company=$cn; Count=$items.Count; Items=$items }
}

$json = $out | ConvertTo-Json -Depth 4 -Compress
if ($OutputPath) { $json | Out-File -Encoding utf8 $OutputPath; Write-Host "[fetch_news] wrote $OutputPath ($($json.Length) chars)" }
else { Write-Output $json }