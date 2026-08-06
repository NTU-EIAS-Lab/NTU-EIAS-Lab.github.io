<#
.SYNOPSIS
  Serve this folder over HTTP and open the lab page in a browser.

.DESCRIPTION
  The page loads its content with fetch('data/*.json') at runtime. Browsers
  block those requests on file:// URLs, so opening the .html by double-clicking
  shows an empty shell. Any static HTTP server fixes it; this script picks one
  that is already installed, finds a free port, and opens the page.

  Needs internet on first load: support.js pulls React, ReactDOM and Babel from
  unpkg, and the page pulls webfonts from Google Fonts. Everything else --
  markup, data, images, video -- is served locally.

  Binds to 127.0.0.1 only, so the site is not reachable from the network.

.PARAMETER Port
  Preferred port (default 8080). If busy, the next free port is used.

.PARAMETER NoBrowser
  Start the server without opening a browser.

.EXAMPLE
  .\serve.ps1

.EXAMPLE
  .\serve.ps1 -Port 3000 -NoBrowser
#>
[CmdletBinding()]
param(
    [ValidateRange(1024, 65535)]
    [int]$Port = 8080,
    [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'

$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$page = 'SLAM Research Group v2.dc.html'

if (-not (Test-Path -LiteralPath (Join-Path $root $page))) {
    throw "Cannot find '$page' in $root."
}

function Test-PortFree {
    param([int]$Candidate)
    $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Candidate)
    try {
        $listener.Start()
        $listener.Stop()
        return $true
    } catch {
        return $false
    }
}

$chosen = $null
foreach ($candidate in $Port..([Math]::Min($Port + 20, 65535))) {
    if (Test-PortFree -Candidate $candidate) { $chosen = $candidate; break }
}
if (-not $chosen) { throw "No free port between $Port and $($Port + 20)." }
if ($chosen -ne $Port) { Write-Host "Port $Port is busy - using $chosen instead." -ForegroundColor Yellow }

# Whichever of these is installed. Python's http.server is stdlib, so it is the
# most likely to be present; http-server is the Node equivalent.
if (Get-Command python -ErrorAction SilentlyContinue) {
    $exe = 'python'
    $arguments = @('-m', 'http.server', "$chosen", '--bind', '127.0.0.1')
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
    $exe = 'py'
    $arguments = @('-3', '-m', 'http.server', "$chosen", '--bind', '127.0.0.1')
} elseif (Get-Command npx -ErrorAction SilentlyContinue) {
    $exe = 'npx'
    $arguments = @('--yes', 'http-server', '-p', "$chosen", '-a', '127.0.0.1', '-c-1')
} else {
    throw 'Need Python or Node.js (npx) on PATH to serve the folder.'
}

$url = "http://localhost:$chosen/$([uri]::EscapeDataString($page))"

$browserJob = $null
if (-not $NoBrowser) {
    # The server blocks this shell, so hand the browser launch to a job that
    # waits for the port to answer first.
    $browserJob = Start-Job -ScriptBlock {
        param($target, $portNumber)
        for ($i = 0; $i -lt 40; $i++) {
            try {
                $probe = New-Object System.Net.Sockets.TcpClient
                $probe.Connect('127.0.0.1', $portNumber)
                $probe.Close()
                Start-Process $target
                return
            } catch {
                Start-Sleep -Milliseconds 250
            }
        }
    } -ArgumentList $url, $chosen
}

Write-Host ''
Write-Host "  Serving $root" -ForegroundColor Cyan
Write-Host "  $url" -ForegroundColor Cyan
Write-Host '  Edit data/*.json and refresh the browser to see changes.'
Write-Host '  Press Ctrl+C to stop.'
Write-Host ''

Push-Location $root
try {
    & $exe @arguments
} finally {
    Pop-Location
    if ($browserJob) { Remove-Job -Job $browserJob -Force -ErrorAction SilentlyContinue }
}
