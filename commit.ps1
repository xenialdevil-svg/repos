# Script to change all commits from one year to another year
# Author: Assistant
# Description: Takes user input for source year and target year, then changes all commit dates

Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Change All Commits From One Year to Another" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

# Function to validate year input
function Test-YearInput {
    param($year)
    return ($year -and $year -match '^[0-9]{4}$' -and [int]$year -ge 1990 -and [int]$year -le 2030)
}

# Get the source year (year to find in commits)
do {
    $sourceYear = Read-Host "Enter the year to find in commits (e.g., 2021)"
    if (-not (Test-YearInput $sourceYear)) {
        Write-Host "Invalid year. Please enter a valid 4-digit year between 1990-2030." -ForegroundColor Red
    }
} while (-not (Test-YearInput $sourceYear))

# Get the target year (year to replace with)
do {
    $targetYear = Read-Host "Enter the year to replace with (e.g., 2022)"
    if (-not (Test-YearInput $targetYear)) {
        Write-Host "Invalid year. Please enter a valid 4-digit year between 1990-2030." -ForegroundColor Red
    }
} while (-not (Test-YearInput $targetYear))

# Check if years are the same
if ($sourceYear -eq $targetYear) {
    Write-Host "Source year and target year are the same. Nothing to change." -ForegroundColor Yellow
    exit
}

Write-Host ""
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "- Source Year: $sourceYear" -ForegroundColor White
Write-Host "- Target Year: $targetYear" -ForegroundColor White
Write-Host ""

# Check if we're in a git repository
try {
    $gitStatus = git status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Not in a git repository." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Error: Git is not installed or not in PATH." -ForegroundColor Red
    exit 1
}

# Check for uncommitted changes
$uncommittedChanges = git status --porcelain
if ($uncommittedChanges) {
    Write-Host "Warning: You have uncommitted changes." -ForegroundColor Red
    Write-Host "Please commit or stash your changes before proceeding." -ForegroundColor Red
    exit 1
}

# Search for commits from the source year
Write-Host "Searching for commits from year $sourceYear..." -ForegroundColor Yellow
try {
    $commitsFromYear = git log --since="$sourceYear-01-01" --until="$sourceYear-12-31" --oneline
    $commitsCount = ($commitsFromYear | Measure-Object -Line).Lines
} catch {
    Write-Host "Error searching for commits: $_" -ForegroundColor Red
    exit 1
}

if ($commitsCount -eq 0) {
    Write-Host "No commits found from year $sourceYear. Nothing to change." -ForegroundColor Green
    Write-Host "Operation completed successfully!" -ForegroundColor Green
    exit 0
}

Write-Host "Found $commitsCount commits from year $sourceYear" -ForegroundColor Green
Write-Host ""

# Show preview of commits that will be changed
Write-Host "Preview of commits that will be changed:" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Gray
try {
    $previewCommits = git log --since="$sourceYear-01-01" --until="$sourceYear-12-31" --date=short --pretty=format:"%h %ad %s" | Select-Object -First 10
    $previewCommits | ForEach-Object { Write-Host $_ -ForegroundColor White }
    
    if ($commitsCount -gt 10) {
        Write-Host "... and $($commitsCount - 10) more commits" -ForegroundColor Gray
    }
} catch {
    Write-Host "Error displaying commit preview: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "This operation will:" -ForegroundColor Yellow
Write-Host "✓ Change ALL $commitsCount commits from year $sourceYear to year $targetYear" -ForegroundColor White
Write-Host "✓ Modify both author date and committer date" -ForegroundColor White
Write-Host "✓ Create new commit hashes for all affected commits" -ForegroundColor White
Write-Host "✓ Rewrite Git history (this cannot be easily undone)" -ForegroundColor White
Write-Host "✓ Require force push to update GitHub" -ForegroundColor White
Write-Host ""
Write-Host "⚠️  WARNING: This will change Git history permanently!" -ForegroundColor Red
Write-Host ""

$confirm = Read-Host "Do you want to proceed? Type 'YES' to continue"
if ($confirm -ne "YES") {
    Write-Host "Operation cancelled by user." -ForegroundColor Yellow
    exit 0
}

# Get current branch
try {
    $currentBranch = git branch --show-current
    if (-not $currentBranch) {
        Write-Host "Error: Could not determine current branch." -ForegroundColor Red
        exit 1
    }
    Write-Host "Working on branch: $currentBranch" -ForegroundColor Green
} catch {
    Write-Host "Error getting current branch: $_" -ForegroundColor Red
    exit 1
}

# Create backup branch
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupBranch = "${currentBranch}_backup_${sourceYear}to${targetYear}_$timestamp"
try {
    git branch $backupBranch
    Write-Host "Backup branch created: $backupBranch" -ForegroundColor Yellow
} catch {
    Write-Host "Error creating backup branch: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Starting Git history rewrite..." -ForegroundColor Yellow
Write-Host "This may take several minutes for repositories with many commits..." -ForegroundColor Gray

try {
    # Set environment variable to suppress filter-branch warning
    $env:FILTER_BRANCH_SQUELCH_WARNING = "1"
    
    # Create the filter command to change dates
    $filterCommand = @"
if echo "`$GIT_AUTHOR_DATE" | grep -q "$sourceYear"; then
    export GIT_AUTHOR_DATE=`$(echo "`$GIT_AUTHOR_DATE" | sed "s/$sourceYear/$targetYear/g")
fi
if echo "`$GIT_COMMITTER_DATE" | grep -q "$sourceYear"; then
    export GIT_COMMITTER_DATE=`$(echo "`$GIT_COMMITTER_DATE" | sed "s/$sourceYear/$targetYear/g")
fi
"@
    
    # Execute git filter-branch
    Write-Host "Executing: git filter-branch --env-filter..." -ForegroundColor Gray
    git filter-branch -f --env-filter $filterCommand HEAD
    
    if ($LASTEXITCODE -ne 0) {
        throw "Git filter-branch failed with exit code $LASTEXITCODE"
    }
    
    Write-Host ""
    Write-Host "✅ Git history rewrite completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host ""
    Write-Host "❌ Error during Git history rewrite: $_" -ForegroundColor Red
    Write-Host "Your repository has been restored to original state." -ForegroundColor Yellow
    Write-Host "Backup branch available: $backupBranch" -ForegroundColor Yellow
    Write-Host "To restore manually: git reset --hard $backupBranch" -ForegroundColor Yellow
    exit 1
}

# Verify the changes
Write-Host ""
Write-Host "Verifying changes..." -ForegroundColor Yellow
try {
    $newCommitsCount = (git log --since="$targetYear-01-01" --until="$targetYear-12-31" --oneline | Measure-Object -Line).Lines
    Write-Host "Verification: Found $newCommitsCount commits in year $targetYear" -ForegroundColor Green
    
    if ($newCommitsCount -gt 0) {
        Write-Host ""
        Write-Host "Sample of changed commits:" -ForegroundColor Cyan
        git log --since="$targetYear-01-01" --until="$targetYear-12-31" --date=short --pretty=format:"%h %ad %s" | Select-Object -First 5 | ForEach-Object { Write-Host $_ -ForegroundColor White }
    }
} catch {
    Write-Host "Warning: Could not verify changes: $_" -ForegroundColor Yellow
}

# Ask about pushing to GitHub
Write-Host ""
Write-Host "Git history has been changed locally." -ForegroundColor Green
Write-Host ""
$pushConfirm = Read-Host "Push changes to GitHub? Type 'PUSH' to confirm"

if ($pushConfirm -eq "PUSH") {
    Write-Host ""
    Write-Host "Pushing to GitHub..." -ForegroundColor Yellow
    Write-Host "Using: git push --force-with-lease origin $currentBranch" -ForegroundColor Gray
    
    try {
        git push --force-with-lease origin $currentBranch
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "🎉 Successfully pushed to GitHub!" -ForegroundColor Green
            Write-Host ""
            Write-Host "📊 Operation Summary:" -ForegroundColor Cyan
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
            Write-Host "✓ Changed: $commitsCount commits" -ForegroundColor White
            Write-Host "✓ From year: $sourceYear" -ForegroundColor White
            Write-Host "✓ To year: $targetYear" -ForegroundColor White
            Write-Host "✓ Branch: $currentBranch" -ForegroundColor White
            Write-Host "✓ Backup: $backupBranch" -ForegroundColor White
            Write-Host "✓ Status: Successfully pushed to GitHub" -ForegroundColor Green
            Write-Host ""
            Write-Host "🗂️  Cleanup (optional):" -ForegroundColor Yellow
            Write-Host "To delete backup branch: git branch -D $backupBranch" -ForegroundColor Gray
            
        } else {
            throw "Git push failed with exit code $LASTEXITCODE"
        }
        
    } catch {
        Write-Host ""
        Write-Host "❌ Push to GitHub failed: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Possible reasons:" -ForegroundColor Yellow
        Write-Host "• Someone else pushed changes (try: git fetch then retry)" -ForegroundColor White
        Write-Host "• Branch is protected (check GitHub branch protection rules)" -ForegroundColor White
        Write-Host "• Network connectivity issues" -ForegroundColor White
        Write-Host "• Insufficient permissions" -ForegroundColor White
        Write-Host ""
        Write-Host "Your local changes are complete. To push manually:" -ForegroundColor Cyan
        Write-Host "git push --force-with-lease origin $currentBranch" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Backup branch: $backupBranch" -ForegroundColor Yellow
    }
    
} else {
    Write-Host ""
    Write-Host "Push cancelled. Changes are local only." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📊 Operation Summary:" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "✓ Changed: $commitsCount commits" -ForegroundColor White
    Write-Host "✓ From year: $sourceYear" -ForegroundColor White
    Write-Host "✓ To year: $targetYear" -ForegroundColor White
    Write-Host "✓ Branch: $currentBranch" -ForegroundColor White
    Write-Host "✓ Backup: $backupBranch" -ForegroundColor White
    Write-Host "✓ Status: Local changes complete" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To push later:" -ForegroundColor Cyan
    Write-Host "git push --force-with-lease origin $currentBranch" -ForegroundColor Gray
}

Write-Host ""
Write-Host "🎉 Operation completed successfully!" -ForegroundColor Green