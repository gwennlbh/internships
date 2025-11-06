#!/usr/bin/env pwsh
# PowerShell equivalent of the provided Fish script

git checkout -- rapport/main.pdf
git pull --rebase --autostash

while ($true) {
    # Get page count using mutool instead of pdfinfo
    $pageCount = & mutool info rapport/main.pdf |
        Select-String '^Pages:' |
        ForEach-Object { ($_ -split '\s+')[-1] }

    $pageCount > pages_count

    # Check for changes in relevant files
    git diff --no-patch --exit-code slides/*.typ slides/*.dot slides/*.png rapport/*.typ rapport/*.dot rapport/*.png bib.yaml | Out-Null
    $pdfChanges = $LASTEXITCODE

    Write-Host "PDF updates with these changes: $pdfChanges"

    # Stage relevant files
    git add rapport/ slides/ bib.yaml *.fish *.ps1 pages_count
    git commit --quiet -m "Continue rapport"

    # Push if there were changes
    if ($pdfChanges -ne 0) {
        git push --quiet --force
        Write-Host "Pushed at $(Get-Date)"
    }

    Start-Sleep -Seconds (60 * 30)
}
