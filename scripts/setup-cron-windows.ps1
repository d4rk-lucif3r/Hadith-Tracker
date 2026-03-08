# Setup 10 daily hadith reminder cron jobs using Windows Task Scheduler
# Reads config from .env file in the project root
# Usage: Run in PowerShell as Administrator:
#   powershell -ExecutionPolicy Bypass -File scripts\setup-cron-windows.ps1

$ErrorActionPreference = "Stop"

# Find project root (parent of scripts/)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$EnvFile = Join-Path $ProjectRoot ".env"

if (-not (Test-Path $EnvFile)) {
    Write-Host "❌ .env file not found at $EnvFile"
    Write-Host "   Copy .env.example to .env and fill in your values."
    exit 1
}

# Parse .env file
$envVars = @{}
Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#")) {
        $eqIdx = $line.IndexOf("=")
        if ($eqIdx -gt 0) {
            $key = $line.Substring(0, $eqIdx).Trim()
            $val = $line.Substring($eqIdx + 1).Trim()
            $envVars[$key] = $val
        }
    }
}

$BotToken = $envVars["TELEGRAM_BOT_TOKEN"]
$ChatId   = $envVars["TELEGRAM_CHAT_ID"]
$TZ       = $envVars["TZ"]
$DbDir    = if ($envVars["DB_DIR"]) { $envVars["DB_DIR"] } else { Join-Path $ProjectRoot "data" }

if (-not $BotToken -or $BotToken -eq "your_bot_token_here") {
    Write-Host "❌ TELEGRAM_BOT_TOKEN is not set in .env"
    exit 1
}
if (-not $ChatId -or $ChatId -eq "your_chat_id_here") {
    Write-Host "❌ TELEGRAM_CHAT_ID is not set in .env"
    exit 1
}
if (-not $TZ) {
    Write-Host "❌ TZ (timezone) is not set in .env"
    Write-Host "   Example: TZ=America/New_York"
    exit 1
}

$ReminderScript = Join-Path $ScriptDir "hadith-reminder.js"

# 10 daily slots: slot, hour, minute, label
$Slots = @(
    @{ Slot=1;  Hour=6;  Min=0;  Label="6:00 AM"  },
    @{ Slot=2;  Hour=8;  Min=0;  Label="8:00 AM"  },
    @{ Slot=3;  Hour=10; Min=0;  Label="10:00 AM" },
    @{ Slot=4;  Hour=12; Min=0;  Label="12:00 PM" },
    @{ Slot=5;  Hour=14; Min=0;  Label="2:00 PM"  },
    @{ Slot=6;  Hour=16; Min=0;  Label="4:00 PM"  },
    @{ Slot=7;  Hour=18; Min=0;  Label="6:00 PM"  },
    @{ Slot=8;  Hour=20; Min=0;  Label="8:00 PM"  },
    @{ Slot=9;  Hour=21; Min=30; Label="9:30 PM"  },
    @{ Slot=10; Hour=23; Min=0;  Label="11:00 PM" }
)

Write-Host "📅 Setting up 10 daily hadith reminder tasks in Windows Task Scheduler..."
Write-Host "   Telegram Chat ID: $ChatId"
Write-Host "   Timezone: $TZ (make sure your Windows timezone matches)"
Write-Host "   Data directory: $DbDir"
Write-Host ""

# Remove existing hadith tasks
Get-ScheduledTask -TaskName "HadithReminder*" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false

foreach ($s in $Slots) {
    $TaskName = "HadithReminder-Slot$($s.Slot)"
    $TimeStr  = "{0:D2}:{1:D2}" -f $s.Hour, $s.Min

    # The action: run node with the reminder script
    $Action  = New-ScheduledTaskAction `
        -Execute "node" `
        -Argument "`"$ReminderScript`" $($s.Slot)" `
        -WorkingDirectory $ProjectRoot

    $Trigger = New-ScheduledTaskTrigger -Daily -At $TimeStr

    $Settings = New-ScheduledTaskSettingsSet `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
        -StartWhenAvailable

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $Action `
        -Trigger $Trigger `
        -Settings $Settings `
        -RunLevel Highest `
        -Force | Out-Null

    Write-Host "  ✅ Slot $($s.Slot) — $($s.Label)"
}

Write-Host ""
Write-Host "✅ All 10 tasks registered in Task Scheduler!"
Write-Host "   Open 'Task Scheduler' and look for tasks named 'HadithReminder-Slot*' to verify."
Write-Host ""
Write-Host "⚠️  Make sure your Windows timezone is set to match: $TZ"
Write-Host "   Settings → Time & Language → Date & Time → Time zone"
