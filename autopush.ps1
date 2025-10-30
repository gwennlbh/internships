#!/usr/bin/env pwsh
# PowerShell version of the Fish script using `mutool` for PDF page count

# Checkout the PDF from Git
git checkout -- rapport/main.pdf

# Pull latest changes with rebase and autostash
git pull --rebase --autostash

while ($true) {
    # --- Get the page count using mutool ---
    try {
        $pages = mutool info rapport/main.pdf |
            Select-String "^Pages:" |
            ForEach-Object { ($_ -split "\s+")[1] }
    } catch {
        Write-Host "Error: Could not get page count from rapport/main.pdf"
        $pages = "0"
    }

    # Save page count to a file
    Set-Content -Path "pages_count" -Value $pages

    # --- Stage files ---
    git add rapport/*.typ bib.yaml *.ps1 rapport/*.dot pages_count rapport/*.png

    # --- Commit quietly ---
    git commit --quiet -m "Continue rapport" 2>$null

    # --- Push quietly and force ---
    git push --quiet --force

    # --- Print timestamp ---
    Write-Host "Pushed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

    # --- Sleep for 30 minutes ---
    Start-Sleep -Seconds 1800
}
