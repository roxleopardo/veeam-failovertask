# Start writing output to file
Start-Transcript -Path "C:\Scripts\Failover.log" -Append

# Load config from json
$fileconfig = "C:\Scripts\Failover.json"
$config = Get-Content -Path $fileconfig | ConvertFrom-Json

# Load Veeam B&R 9.5.4 Powershell Snap-in
Add-PSSnapin VeeamPSSnapIn

# Get PID from parent process
$parentpid = (Get-WmiObject Win32_Process -Filter "processid='$pid'").parentprocessid.ToString()

# Get command line parameters from parent process
$parentcmd = (Get-WmiObject Win32_Process -Filter "processid='$parentpid'").CommandLine
<# Just for testing purpose
if($args.Count -eq 0){
 # A1
 $parentcmd = '"C:\Program Files\Veeam\Backup and Replication\Backup\Veeam.Backup.Manager.exe" "startbackupjob" "owner=[vbsvc]" "Normal" "67504277-a776-4bc5-a6d6-a3a43e5ea0bb" "1aaa82f0-7051-46d0-9eb1-17ef79e4313f" '
 # B1
 #$parentcmd = '"C:\Program Files\Veeam\Backup and Replication\Backup\Veeam.Backup.Manager.exe" "startbackupjob" "owner=[vbsvc]" "Normal" "77cf6845-3a19-4350-bb30-3bfe19ba86eb" "085a8180-2b43-447a-8318-8d27a6205401" '
}
#>
Write-Output "Parent CMD: '$parentcmd'"

# Extract job.Id and session.Id from command line parameters
$job,$session = $parentcmd.Replace('" "','","').Replace('"','').Split(',')[4,5]

# Populate job object using job.Id
$job = Get-VBRJob | ?{$_.Id -eq $job}
Write-Output "Job: $($job.Name)"

# Populate session object using job.Name and session.Id
$session = Get-VBRBackupSession | ?{($_.OrigJobName -eq $job.Name) -and ($_.Id -eq $session)}
Write-Output "Session state: $($session.State)"

# Populate task object using session object
$task = Get-VBRTaskSession -Session $session
Write-Output "Task status: $($task.status)"

# Test if task was successfully executed
if ($task.Status -ne 'Success'){
 # Task wasn't sucessfully

 # Check if this task was called as a failover task
 if ($config.$($job.Name).failover -eq $config.$($job.Name).called) {
  # This is a failover task, so we don't need to run again a failover task
  # Reset failover task status for the next run
  $config.$($job.Name).called = ""
  Write-Output "Task error, but this is a failover job"
 } else {
  # This is not a failover task, so we need to run a failover task
  # Change failover task status
  $config.$($config.$($job.Name).failover).called = $job.Name

  # Populate failover job object
  $failover = Get-VBRJob -Name $config.$($job.Name).failover
  Write-Output "Task error, running failover: $($failover.Name)"

  # Run failover job
  Start-VBRJob -Job $failover -RunAsync | Out-Null
 }
 $config | ConvertTo-Json | Out-File -FilePath $fileconfig
}
Stop-Transcript
