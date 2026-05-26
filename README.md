# TNA Infrastructure

Operational scripts and configs for the Tallahassee Neurology Associates infrastructure.

## Layout

- `nk-station/` — Scripts that live on the NK EEG acquisition station
  - `eeg_watcher_v2.ps1` — PowerShell watcher: polls `C:\nkt\Eeg2100\`, validates complete bundles, copies to DS916+, writes `.done` sentinels
  - `watcher-task.xml` — Task Scheduler XML for installing the watcher as a recurring task

## Credentials policy

Credentials are NEVER committed to this repo. Scripts read credentials from local config files (e.g. `C:\nfx11\config\credentials.psd1` on the NK station) that are excluded by `.gitignore`. These files must be created out-of-band during install.

## NK station install (one-time)

From PowerShell on the NK box:

```powershell
# Enable TLS 1.2 (required on Win10 1511 for GitHub HTTPS)
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# Fetch the scripts
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SWhit88/tna-infrastructure/main/nk-station/eeg_watcher_v2.ps1" -OutFile C:\nfx11\eeg_watcher_v2.ps1 -UseBasicParsing
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SWhit88/tna-infrastructure/main/nk-station/watcher-task.xml" -OutFile C:\nfx11\watcher-task.xml -UseBasicParsing

# Create the local credentials file (NOT in source control)
New-Item -ItemType Directory -Path C:\nfx11\config -Force | Out-Null
@"
@{
    ShareUser = 'Nerve916'
    SharePass = 'YOUR_DS916_PASSWORD_HERE'
}
"@ | Set-Content -Path C:\nfx11\config\credentials.psd1 -Encoding utf8

# Lock down credentials file: only NK + SYSTEM can read
icacls C:\nfx11\config\credentials.psd1 /inheritance:r /grant:r "NK:R" "SYSTEM:R" "Administrators:F"
```

Then install the scheduled task — see `nk-station/INSTALL.md` (TBD).
