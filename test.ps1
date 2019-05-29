Param(
  # Folder containing server logs
  [string]$Container,
  # Folder containing our processed log summaries
  [string]$SummarizedLogsContainer,
  # Number of logs to process at once
  [int]$BatchSize = 1000
)

while ($true) {
  $summarizedLogName = Get-Date -Format yyyyMMddhhmmss
  $summarizedLogPath = "$SummarizedLogsContainer\$summarizedLogName.csv"

  $logs = Get-ChildItem $Container `
  | Sort-Object LastWriteTime `
  | Select -First $BatchSize

  $logs `
  | Import-Csv -Delimeter "`t" `
  | Where-Object StatusCode -ge 400 `
  | Export-Csv $summarizedLogPath

  $logs | Remove-Item

  if (-not (Test-Path "$Container\*")) {
    Start-Sleep -Seconds 10
  }
}













