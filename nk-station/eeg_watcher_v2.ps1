# =============================================================================
# NK EEG Watcher v2
# =============================================================================
# Polls C:\nkt\Eeg2100\ for complete EEG study bundles and copies them to the
# DS916+ Synology share at \\100.86.203.16\EEGOfficeData\eeg-incoming\.
#
# Credentials are read from C:\nfx11\config\credentials.psd1 (NOT in source
# control). That file must contain:
#   @{ ShareUser = 'Nerve916'; SharePass = 'YOUR_PASSWORD_HERE' }
# =============================================================================

# ---- Config ----
$Source       = "C:\nkt\Eeg2100"
$Dest         = "\\100.86.203.16\EEGOfficeData\eeg-incoming"
$ShareUNC     = "\\100.86.203.16\EEGOfficeData"
$CredFile     = "C:\nfx11\config\credentials.psd1"
$StateDir     = "C:\nfx11\state"
$StateFile    = Join-Path $StateDir "copied.txt"
$LogDir       = "C:\nfx11\logs"
$StabilitySec = 60

$RequiredExts = @('.EEG', '.PNT', '.11D', '.21E', '.LOG', '.CN2', '.CMT', '.EVT', '.VF2', '.reg')
$RequiredDirs = @('.PTN', '.TRD', '.VOR')
$OptionalExts = @('.EGF', '.BFT')

# ---- Bootstrap ----
$ErrorActionPreference = 'Continue'
foreach ($d in @($StateDir, $LogDir, (Split-Path $CredFile))) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}
if (-not (Test-Path $StateFile)) { New-Item -ItemType File -Path $StateFile -Force | Out-Null }

$LogFile = Join-Path $LogDir ("watcher-{0}.log" -f (Get-Date -Format 'yyyy-MM-dd'))

function Write-Log {
    param([string]$Level, [string]$Message)
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$ts] [$Level] $Message"
    Add-Content -Path $LogFile -Value $line -Encoding utf8
}

function Get-ShareCredential {
    if (-not (Test-Path $CredFile)) {
        Write-Log 'ERROR' "Credential file not found: $CredFile"
        Write-Log 'ERROR' "Create it with: @{ ShareUser = 'Nerve916'; SharePass = 'PASSWORD' } | Export-PowerShellDataFile or write the hashtable literal directly."
        return $null
    }
    try {
        $cred = Import-PowerShellDataFile -Path $CredFile -ErrorAction Stop
        if (-not $cred.ShareUser -or -not $cred.SharePass) {
            Write-Log 'ERROR' "Credential file missing ShareUser or SharePass."
            return $null
        }
        return $cred
    } catch {
        Write-Log 'ERROR' "Failed to parse credential file: $($_.Exception.Message)"
        return $null
    }
}

function Ensure-Share {
    param($Credential)
    $reachable = $false
    try { $null = Get-Item $Dest -ErrorAction Stop; $reachable = $true } catch { $reachable = $false }
    if ($reachable) { Write-Log 'INFO' "Share already reachable: $Dest"; return $true }

    Write-Log 'WARN' "Share not reachable. Attempting net use..."
    $null = & net use $ShareUNC /delete /yes 2>&1
    $result = & net use $ShareUNC /user:$($Credential.ShareUser) $Credential.SharePass /persistent:yes 2>&1
    Write-Log 'INFO' ("net use result: " + ($result -join ' | '))

    try {
        $null = Get-Item $Dest -ErrorAction Stop
        Write-Log 'INFO' "Share now reachable after net use."
        return $true
    } catch {
        Write-Log 'ERROR' "Share still unreachable after net use. Aborting this run."
        return $false
    }
}

function Get-CandidateStems {
    $files = Get-ChildItem -Path $Source -File -Filter '*.EEG' -ErrorAction SilentlyContinue
    $stems = @()
    foreach ($f in $files) {
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
        if ($stem -match '^FA[0-9A-Z]{6}$') { $stems += $stem }
    }
    return ($stems | Sort-Object -Unique)
}

function Get-CopiedStems {
    if (-not (Test-Path $StateFile)) { return @() }
    return @(Get-Content $StateFile | Where-Object { $_ -and $_.Trim() })
}

function Mark-Copied {
    param([string]$Stem)
    Add-Content -Path $StateFile -Value $Stem -Encoding utf8
}

function Test-StemReady {
    param([string]$Stem)
    foreach ($ext in $RequiredExts) {
        $hit = Get-ChildItem -Path $Source -Filter ($Stem + $ext) -File -ErrorAction SilentlyContinue
        if (-not $hit) { Write-Log 'DEBUG' "Stem $Stem missing required $ext"; return $false }
    }
    foreach ($d in $RequiredDirs) {
        $hit = Get-ChildItem -Path $Source -Filter ($Stem + $d) -Directory -ErrorAction SilentlyContinue
        if (-not $hit) { Write-Log 'DEBUG' "Stem $Stem missing required subdir $d"; return $false }
    }
    $eeg = Get-ChildItem -Path $Source -Filter ($Stem + '.EEG') -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $eeg) { return $false }
    $age = (Get-Date) - $eeg.LastWriteTime
    if ($age.TotalSeconds -lt $StabilitySec) {
        Write-Log 'DEBUG' "Stem $Stem .EEG only $([int]$age.TotalSeconds)s old, waiting..."
        return $false
    }
    return $true
}

function Copy-Stem {
    param([string]$Stem)
    $allExts = $RequiredExts + $OptionalExts
    $errors = @()

    foreach ($ext in $allExts) {
        $matches = Get-ChildItem -Path $Source -Filter ($Stem + $ext) -File -ErrorAction SilentlyContinue
        foreach ($f in $matches) {
            try {
                Copy-Item -Path $f.FullName -Destination $Dest -Force -ErrorAction Stop
                Write-Log 'INFO' "Copied $($f.Name) ($($f.Length) bytes)"
            } catch {
                $msg = "Copy failed for $($f.Name): $($_.Exception.Message)"
                Write-Log 'ERROR' $msg
                $errors += $msg
            }
        }
    }

    foreach ($d in $RequiredDirs) {
        $matches = Get-ChildItem -Path $Source -Filter ($Stem + $d) -Directory -ErrorAction SilentlyContinue
        foreach ($subdir in $matches) {
            $destSub = Join-Path $Dest $subdir.Name
            try {
                if (Test-Path $destSub) { Remove-Item $destSub -Recurse -Force -ErrorAction SilentlyContinue }
                Copy-Item -Path $subdir.FullName -Destination $Dest -Recurse -Force -ErrorAction Stop
                Write-Log 'INFO' "Copied subdir $($subdir.Name)/"
            } catch {
                $msg = "Subdir copy failed for $($subdir.Name): $($_.Exception.Message)"
                Write-Log 'ERROR' $msg
                $errors += $msg
            }
        }
    }

    if ($errors.Count -gt 0) {
        Write-Log 'ERROR' "Stem $Stem had $($errors.Count) error(s), NOT marking complete."
        return $false
    }

    $sentinel = Join-Path $Dest ($Stem + '.done')
    try {
        $now = (Get-Date).ToString('o')
        Set-Content -Path $sentinel -Value $now -Encoding utf8 -ErrorAction Stop
        Write-Log 'INFO' "Wrote sentinel $($Stem).done"
    } catch {
        Write-Log 'ERROR' "Sentinel write failed for $Stem : $($_.Exception.Message)"
        return $false
    }
    return $true
}

function Update-LateFiles {
    param([string]$Stem)
    foreach ($ext in $OptionalExts) {
        $local = Get-ChildItem -Path $Source -Filter ($Stem + $ext) -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $local) { continue }
        $remote = Get-ChildItem -Path $Dest -Filter ($Stem + $ext) -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $remote -or $local.LastWriteTime -gt $remote.LastWriteTime) {
            try {
                Copy-Item -Path $local.FullName -Destination $Dest -Force -ErrorAction Stop
                Write-Log 'INFO' "Updated late file $($local.Name)"
            } catch {
                Write-Log 'ERROR' "Late file update failed for $($local.Name): $($_.Exception.Message)"
            }
        }
    }
}

# ---- Main ----
Write-Log 'INFO' "===== Watcher run starting (PID $PID) ====="

$cred = Get-ShareCredential
if (-not $cred) {
    Write-Log 'INFO' "===== Watcher run aborted (no credentials) ====="
    exit 1
}

if (-not (Ensure-Share -Credential $cred)) {
    Write-Log 'INFO' "===== Watcher run aborted (no share) ====="
    exit 1
}

$copied = Get-CopiedStems
Write-Log 'INFO' "$($copied.Count) stems already in state file"

$candidates = Get-CandidateStems
Write-Log 'INFO' "$($candidates.Count) candidate stems found in source"

$newCopies   = 0
$lateUpdates = 0

foreach ($stem in $candidates) {
    if ($copied -contains $stem) {
        Update-LateFiles -Stem $stem
        $lateUpdates += 1
        continue
    }
    if (Test-StemReady -Stem $stem) {
        Write-Log 'INFO' "Stem $stem is complete and stable, copying..."
        if (Copy-Stem -Stem $stem) {
            Mark-Copied -Stem $stem
            $newCopies += 1
            Write-Log 'INFO' "Stem $stem fully copied and marked done."
        }
    }
}

Write-Log 'INFO' "Run summary: $newCopies new copies, $lateUpdates late-file checks."
Write-Log 'INFO' "===== Watcher run complete ====="
