Start-Transcript -Path "C:\Scripts\Failover.log" -Append

$config = Get-Content -Path "C:\Scripts\Failover.json" | ConvertFrom-Json

Add-PSSnapin VeeamPSSnapIn

$parentpid = (Get-WmiObject Win32_Process -Filter "processid='$pid'").parentprocessid.ToString()
$parentcmd = (Get-WmiObject Win32_Process -Filter "processid='$parentpid'").CommandLine
Write-Output "Parent CMD: '$parentcmd'"

$job,$session = $parentcmd.Replace('" "','","').Replace('"','').Split(',')[4,5]

$job = Get-VBRJob | ?{$_.Id -eq $job}
Write-Output "Job: $($job.Name)"

$session = Get-VBRBackupSession | ?{($_.OrigJobName -eq $job.Name) -and ($_.Id -eq $session)}
Write-Output "Session state: $($session.State)"

$task = Get-VBRTaskSession -Session $session
Write-Output "Task status: $($task.status)"

if ($task.Status -ne 'Success'){
 $reversejob = $config.$($job.Name).failover
 if ($config.$($reversejob).executed) {
  $config.$($reversejob).executed = $false
  Write-Output "Task error, but this is a failover job"
 } else {
  $config.$($job.Name).executed = $true
  $failover = Get-VBRJob -Name $config.$($job.Name).failover
  Write-Output "Task error, running failover: $($failover.Name)"
  Start-VBRJob -Job $failover -RunAsync
 }
 $config | ConvertTo-Json | Out-File -FilePath "C:\Scripts\Failover.json"
}
Stop-Transcript
