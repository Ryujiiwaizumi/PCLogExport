param(
    [string]$StartDate = "",
    [string]$EndDate = "",
    [int]$Days = 30,
    [string]$OutDir = ".\output"
)

$ErrorActionPreference = "Stop"

# ==================================================
# PCログオン・ログオフ日別集計ツール
# Version: 0.2
#
# 取得元:
#   Systemログ
#   Provider: Microsoft-Windows-Winlogon / Winlogon
#   Event ID 7001 = ログオン
#   Event ID 7002 = ログオフ
#
# 出力:
#   PCName, Date, LoginTime, LogoffTime
#
# 仕様:
#   LoginTime  = その日の最初のログオン時刻をそのまま出力
#   LogoffTime = その日の最後のログオフ時刻を10分単位で切り上げて出力
# ==================================================

function Resolve-ToolPath {
    param([string]$PathText)

    if ([System.IO.Path]::IsPathRooted($PathText)) {
        return $PathText
    }

    return Join-Path $BaseDir $PathText
}

function RoundUp-To10Minutes {
    param([datetime]$DateTimeValue)

    # 秒・ミリ秒を切り捨てて分単位にする
    $baseTime = Get-Date -Year $DateTimeValue.Year `
                         -Month $DateTimeValue.Month `
                         -Day $DateTimeValue.Day `
                         -Hour $DateTimeValue.Hour `
                         -Minute $DateTimeValue.Minute `
                         -Second 0

    $minuteRemainder = $baseTime.Minute % 10

    # すでに10分単位かつ秒が0ならそのまま
    if ($minuteRemainder -eq 0 -and $DateTimeValue.Second -eq 0 -and $DateTimeValue.Millisecond -eq 0) {
        return $baseTime
    }

    # 10分単位へ切り上げ
    $addMinutes = 10 - $minuteRemainder

    # ちょうど10分単位だが秒がある場合は次の10分へ
    if ($minuteRemainder -eq 0 -and ($DateTimeValue.Second -gt 0 -or $DateTimeValue.Millisecond -gt 0)) {
        $addMinutes = 10
    }

    return $baseTime.AddMinutes($addMinutes)
}

try {
    # スクリプト配置フォルダを基準にする
    if ($PSScriptRoot) {
        $BaseDir = $PSScriptRoot
    }
    else {
        $BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    }

    Set-Location $BaseDir

    $LogDir = Join-Path $BaseDir "logs"
    if (!(Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir | Out-Null
    }

    $OutDirResolved = Resolve-ToolPath $OutDir
    if (!(Test-Path $OutDirResolved)) {
        New-Item -ItemType Directory -Path $OutDirResolved | Out-Null
    }

    $PCName = $env:COMPUTERNAME

    # 日付範囲の決定
    if ($StartDate -ne "" -and $EndDate -ne "") {
        try {
            $StartTime = [datetime]::ParseExact($StartDate, "yyyy-MM-dd", $null)
            $EndDay = [datetime]::ParseExact($EndDate, "yyyy-MM-dd", $null)
        }
        catch {
            throw "日付形式が正しくありません。yyyy-MM-dd 形式で入力してください。例: 2026-06-01"
        }

        if ($EndDay -lt $StartTime.Date) {
            throw "終了日は開始日以降にしてください。"
        }

        $EndTime = $EndDay.Date.AddDays(1).AddSeconds(-1)
    }
    else {
        $EndDay = (Get-Date).Date
        $StartTime = $EndDay.AddDays(-$Days + 1)
        $EndTime = $EndDay.AddDays(1).AddSeconds(-1)
    }

    # Winlogon 7001 / 7002 を取得
    # ProviderName はPC環境により表記が異なる可能性があるため、ID取得後に絞り込む
    $events = Get-WinEvent -FilterHashtable @{
        LogName   = 'System'
        Id        = 7001, 7002
        StartTime = $StartTime
        EndTime   = $EndTime
    } |
    Where-Object {
        $_.ProviderName -eq "Microsoft-Windows-Winlogon" -or
        $_.ProviderName -eq "Winlogon"
    } |
    Sort-Object TimeCreated

    # 日付ごとに集計
    $result = @()
    $currentDate = $StartTime.Date

    while ($currentDate -le $EndTime.Date) {

        $dateText = $currentDate.ToString("yyyy-MM-dd")

        $dayEvents = $events | Where-Object {
            $_.TimeCreated.Date -eq $currentDate.Date
        } | Sort-Object TimeCreated

        $loginEvents  = $dayEvents | Where-Object { $_.Id -eq 7001 }
        $logoffEvents = $dayEvents | Where-Object { $_.Id -eq 7002 }

        # その日の最初のログオン
        $firstLogin = $loginEvents | Select-Object -First 1

        # その日の最後のログオフ
        $lastLogoff = $logoffEvents | Select-Object -Last 1

        $roundedLogoff = $null
        if ($lastLogoff) {
            $roundedLogoff = RoundUp-To10Minutes -DateTimeValue $lastLogoff.TimeCreated
        }

        $result += [PSCustomObject]@{
            PCName     = $PCName
            Date       = $dateText
            LoginTime  = if ($firstLogin)  { $firstLogin.TimeCreated.ToString("HH:mm:ss") } else { "" }
            LogoffTime = if ($roundedLogoff) { $roundedLogoff.ToString("HH:mm:ss") } else { "" }
        }

        $currentDate = $currentDate.AddDays(1)
    }

    # 出力ファイル名
    $fromText = $StartTime.ToString("yyyyMMdd")
    $toText   = $EndTime.ToString("yyyyMMdd")
    $stamp    = Get-Date -Format "HHmmss"

    $csvPath  = Join-Path $OutDirResolved "pc_log_summary_${PCName}_${fromText}_${toText}_${stamp}.csv"
    $jsonPath = Join-Path $OutDirResolved "pc_log_summary_${PCName}_${fromText}_${toText}_${stamp}.json"

    # CSV / JSON 出力
    $result | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

    @($result) |
    ConvertTo-Json -Depth 5 |
    Out-File -FilePath $jsonPath -Encoding UTF8

    Write-Host ""
    Write-Host "======================================"
    Write-Host "PCログ出力 完了"
    Write-Host "======================================"
    Write-Host "PC名    : $PCName"
    Write-Host "開始日  : $($StartTime.ToString("yyyy-MM-dd"))"
    Write-Host "終了日  : $($EndTime.ToString("yyyy-MM-dd"))"
    Write-Host "CSV     : $csvPath"
    Write-Host "JSON    : $jsonPath"
    Write-Host "日数    : $($result.Count)"
    Write-Host "仕様    : LogoffTimeのみ10分単位で切り上げ"
    Write-Host "======================================"
    Write-Host ""
}
catch {
    $BaseDirForError = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $LogDirForError = Join-Path $BaseDirForError "logs"
    if (!(Test-Path $LogDirForError)) {
        New-Item -ItemType Directory -Path $LogDirForError | Out-Null
    }

    $errorPath = Join-Path $LogDirForError ("error_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".txt")
    $_ | Out-File -FilePath $errorPath -Encoding UTF8

    Write-Host ""
    Write-Host "======================================"
    Write-Host "エラーが発生しました"
    Write-Host "======================================"
    Write-Host $_.Exception.Message
    Write-Host "ログ: $errorPath"
    Write-Host "======================================"
    Write-Host ""

    exit 1
}
