# PCLogExport v0.2

Windows のイベントログから、PC のログオン・ログオフ時刻を日別に集計し、CSV / JSON に出力する小型ツールです。

## v0.2 修正内容

`LogoffTime` だけを 10分単位で切り上げて出力します。

例:

| 元のログオフ時刻 | 出力されるLogoffTime |
|---|---|
| 18:20:00 | 18:20:00 |
| 18:20:01 | 18:30:00 |
| 18:21:03 | 18:30:00 |
| 18:29:59 | 18:30:00 |
| 18:30:00 | 18:30:00 |
| 18:59:10 | 19:00:00 |

`LoginTime` は切り上げせず、イベントログの時刻をそのまま出力します。

## 目的

勤怠入力の参考として、以下の4項目を出力します。

| 項目 | 内容 |
|---|---|
| PCName | PC名 |
| Date | 日付 |
| LoginTime | その日の最初のログオン時間 |
| LogoffTime | その日の最後のログオフ時間を10分単位で切り上げた時間 |

## フォルダ構成

```text
PCLogExport_v0_2/
├─ export_pc_log.ps1
├─ Run_PCLogExport.bat
├─ Run_Last30Days.bat
├─ Open_Output_Folder.bat
├─ output/
└─ logs/
```

## 使い方

### 日付を指定して出力

`Run_PCLogExport.bat` をダブルクリックします。

以下の形式で日付を入力します。

```text
Start date: 2026-06-01
End date  : 2026-06-15
```

### 過去30日分を出力

`Run_Last30Days.bat` をダブルクリックします。

### 出力フォルダを開く

`Open_Output_Folder.bat` をダブルクリックします。

## 出力先

`output` フォルダに CSV と JSON が出力されます。

例:

```text
output/
├─ pc_log_summary_EXAMPLE-PC_20260601_20260615_083000.csv
└─ pc_log_summary_EXAMPLE-PC_20260601_20260615_083000.json
```

## 出力CSV例

```csv
PCName,Date,LoginTime,LogoffTime
EXAMPLE-PC,2026-06-01,08:03:12,18:30:00
EXAMPLE-PC,2026-06-02,07:58:01,18:00:00
EXAMPLE-PC,2026-06-03,08:10:33,
EXAMPLE-PC,2026-06-04,,
```

ログが無い日も1行出力します。

## 取得元イベント

- ログ: System
- Provider: Microsoft-Windows-Winlogon / Winlogon
- Event ID:
  - 7001 = ログオン
  - 7002 = ログオフ

## 注意事項

このツールが取得するのは、PC のログオン・ログオフ時刻です。

以下のような場合、勤怠時刻とはズレる可能性があります。

- PCをログオフせずスリープした
- PCをつけっぱなしにした
- 電源長押しや強制終了をした
- Windows Update による再起動があった
- リモート接続を使用した

そのため、このツールの出力は「勤怠確定」ではなく、勤怠入力の参考データとして使用してください。


## 公開・共有時の注意

`output` と `logs` には、PC名・ログオン/ログオフ時刻・エラー内容など、環境固有の情報が含まれる可能性があります。

このリポジトリでは `.gitignore` により、`output/` と `logs/` の生成ファイルをGit管理対象外にしています。生成したCSV / JSON / エラーログは、そのまま公開リポジトリへコミットしないでください。

## エラー時

エラーが発生した場合は `logs` フォルダにエラーログが出ます。

```text
logs/
└─ error_20260616_083000.txt
```

## 配布方法

このフォルダを ZIP 化して、使用するPCにコピーしてください。

推奨配置例:

```text
C:\Tools\PCLogExport
```

会社PCで実行ポリシーやセキュリティ制限により起動できない場合は、右クリックから「管理者として実行」を試してください。
