$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

Write-Host ""
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "    Change Blog Avatar" -ForegroundColor Yellow
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. Drop your avatar image into the [tou xiang] folder" -ForegroundColor Gray
Write-Host "  2. Supported: jpg, png, gif, webp" -ForegroundColor Gray
Write-Host "  3. Square images look best" -ForegroundColor Gray
Write-Host ""

$avatarDir = Join-Path $scriptDir "头像"
$targetDir = Join-Path $scriptDir "source\images"

if (-not (Test-Path $avatarDir)) {
    New-Item -ItemType Directory -Path $avatarDir | Out-Null
    Write-Host "  Created [tou xiang] folder. Put an image there and run again." -ForegroundColor Green
    Read-Host "`n  Press Enter to exit"
    exit
}

$extensions = @("*.jpg", "*.jpeg", "*.png", "*.gif", "*.webp", "*.bmp")
$images = Get-ChildItem -Path $avatarDir -Include $extensions | Sort-Object Name

if ($images.Count -eq 0) {
    Write-Host "  No images found in [tou xiang] folder!" -ForegroundColor Red
    Write-Host "  Folder: $avatarDir" -ForegroundColor Yellow
    Read-Host "`n  Press Enter to exit"
    exit
}

Write-Host "  Found $($images.Count) image(s):" -ForegroundColor Green
Write-Host ""
for ($i = 0; $i -lt $images.Count; $i++) {
    $num = $i + 1
    Write-Host "    [$num]  $($images[$i].Name)" -ForegroundColor White
}
Write-Host ""

$choice = 0
while ($choice -lt 1 -or $choice -gt $images.Count) {
    $input = Read-Host "  Pick a number (1-$($images.Count))"
    if ([int]::TryParse($input, [ref]$choice)) {
        if ($choice -lt 1 -or $choice -gt $images.Count) {
            Write-Host "  Invalid number, try again" -ForegroundColor Red
        }
    } else {
        Write-Host "  Please enter a number" -ForegroundColor Red
    }
}

$selected = $images[$choice - 1]
$ext = $selected.Extension
Write-Host ""
Write-Host "  Selected: $($selected.Name)" -ForegroundColor Green

if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir | Out-Null
}

Get-ChildItem -Path $targetDir -Filter "avatar.*" | Remove-Item -Force -ErrorAction SilentlyContinue

$targetFile = Join-Path $targetDir "avatar$ext"
Copy-Item -Path $selected.FullName -Destination $targetFile -Force
Write-Host "  Copied to: source\images\avatar$ext" -ForegroundColor Green

$configPath = Join-Path $scriptDir "_config.next.yml"
$config = Get-Content $configPath -Raw -Encoding UTF8
$config = $config -replace 'url: /images/avatar\.\w+', "url: /images/avatar$ext"
[System.IO.File]::WriteAllText($configPath, $config, [System.Text.UTF8Encoding]::new($false))
Write-Host "  Config updated" -ForegroundColor Green

Write-Host ""
Write-Host "  Generating blog..." -ForegroundColor Yellow
$hexo = Join-Path $scriptDir "node_modules\.bin\hexo.cmd"
& $hexo clean 2>&1 | Out-Null
& $hexo generate 2>&1 | Out-Null
Write-Host "  Generated successfully!" -ForegroundColor Green

Write-Host "  Deploying to GitHub Pages..." -ForegroundColor Yellow
& $hexo deploy

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "  ============================================" -ForegroundColor Cyan
    Write-Host "    Avatar changed successfully!" -ForegroundColor Green
    Write-Host "    Visit: https://tianshiyan521.github.io" -ForegroundColor White
    Write-Host "    Press Ctrl+Shift+R to refresh" -ForegroundColor Gray
    Write-Host "  ============================================" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "  Deploy may have failed. Make sure proxy is ON." -ForegroundColor Red
    Write-Host "  You can retry with yi-jian-bu-shu.bat" -ForegroundColor Yellow
}

Write-Host ""
Read-Host "  Press Enter to exit"
