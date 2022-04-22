<#
.SYNOPSIS
Script to check and watch a vSAN cluster's status for objects that are being resynced.
The vSAN resyncing objects status will be checked at regular intervals until resyncing is completed. 

.NOTES
--- General ---
Licensed under GNU GPL v3.
License can be found at https://github.com/fukie/MyToolbox/blob/main/LICENSE

Author:        Nyan, Fu Keong
Version:       1.0
Repository:    https://github.com/fukie/MyToolbox

--- Parameters ---
Create a config file (VMware-Config.ps1) in the same folder as this script, with the following parameters
$serverURL        - vCenter's IP address or resolvable domain name (without HTTP/HTTPS)
$credentials      - Username and password. This will be stored in plaintext!
$clusterName      - Name of vSAN cluster in the VMware datacenter.
$intervalSeconds  - How frequent to check and report on the status. 
                  - Setting too low an interval on slower infrastructure will result in negative values in the 'throughput' column.
                  - Recommend to set at least 30 seconds or higher.

--- VMware PowerCLI ---
- Installation of VMware PowerCLI may take 10 - 15 mins.
- Installation of VMware PowerCLI with '-Scope AllUsers' wil require administrative privileges.

.EXAMPLE
PS C:\> .\Watch-vSANResyncingStatus.ps1
[2022-04-14 16:45] Checking for module VMware.PowerCLI...
[2022-04-14 16:45] Module VMware.PowerCLI exists

[2022-04-14 16:45] Checking this session's action to be taken for invalid certificates...
[2022-04-14 16:45] Action for invalid certificates is configured to 'Ignore'.

[2022-04-14 16:45] Successful connection and authentication to x.x.x.x.

dateTime (24h)   vSANCluster  dataLeftGB objectsLeft ETA (hours) ETA (minutes) throughput( MiBps )
--------------   -----------  ---------- ----------- ----------- ------------- -------------------
2022-04-14 16:45 vSAN Cluster        133           2 0.52                   31 N/A
2022-04-14 16:50 vSAN Cluster        112           2 0.43                   26                  70
2022-04-14 16:55 vSAN Cluster         89           2 0.35                   21                  75
2022-04-14 17:00 vSAN Cluster         67           2 0.25                   15                  74
2022-04-14 17:05 vSAN Cluster         45           2 0.17                   10                  72
2022-04-14 17:10 vSAN Cluster         24           2 0.08                    5                  69
2022-04-14 17:15 vSAN Cluster          3           1 0                       0                  70

[2022-04-14 17:21] vSAN Resyncing Completed

.INPUTS
See .NOTES for paramters to configure.

.OUTPUTS
System.String. Writes status of vSAN resyncing objects to console.

#>

# Load library and config file.
. "$PSScriptRoot\VMware-vSphere-Library.ps1"
. "$PSScriptRoot\VMware-Config.ps1"

Test-AndInstallPSModule -moduleName "VMware.PowerCLI"
Test-AndConfigureVMwareInvalidCertificates -ignoreInvalidCertificates:$true
$serverConnection = Connect-VMwareServer -serverURL $serverURL -credentials $credentials

[ System.Collections.ArrayList ]$monitoringResults =  @()
Do{
   $dateTime = Get-Date -Format "yyyy-MM-dd HH:mm"
   Try{
      $vSANResyncingStatus = Get-VsanResyncingOverview -Server $serverConnection -Cluster $clusterName -ErrorAction Stop
   } Catch{
      If( $Error[ 0 ].CategoryInfo.Category -eq "ObjectNotFound" ){
         Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] vSAN Cluster $clusterName not found. Please check. Script terminating."
      } Else{
         Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] An uncaught exception error has occured. Please check. Script terminating."
      }
      Exit
   }
   $vSANResyncingStatusETA = [ String ][ Math ]::Round( $vSANResyncingStatus[ 0 ].TotalResyncingObjectRecoveryETAMinutes / 60, 2 )

   If( $vSANResyncingStatus[ 0 ].TotalDataToSyncGB -eq 0 ){
      Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] No vSAN resyncing in progress."
      Break
   }
   
   If( $monitoringResults.Count -gt 0 ){
      $dataTransferSpeed = [ Math ]::Floor( 
         ( $monitoringResults[ $monitoringResults.Count - 1 ]."Data Left(GB)" - $vSANResyncingStatus[ 0 ].TotalDataToSyncGB ) / 
         $intervalSeconds * 1024 
      )
   } Else{
      $dataTransferSpeed = "N/A"
   }

   $monitoringResults.Add( [ PSCustomObject ]@{
      "Date Time (24h)" = $dateTime
      "vSAN Cluster" = $vSANResyncingStatus[ 0 ].Cluster
      "Data Left(GB)" = [ Math ]::Floor( $vSANResyncingStatus[ 0 ].TotalDataToSyncGB )
      "Objects Left" = $vSANResyncingStatus[ 0 ].TotalObjectsToSync
      "ETA (Hours)" = $vSANResyncingStatusETA
      "ETA (Minutes)" = $vSANResyncingStatus[ 0 ].TotalResyncingObjectRecoveryETAMinutes
      "Throughput (MiBps)" = $dataTransferSpeed
   } ) | Out-Null

   # Output vSAN resyncing status in a table format and in a continous way / "stream" rather than displaying a whole table after at each interval.
   If( $monitoringResults.Count -gt 1 ){
      ( $monitoringResults[ $monitoringResults.Count - 1 ] | Format-Table -HideTableHeaders | Out-String ).Trim()
   } Else{
      Write-Host ""
      ( $monitoringResults | Format-Table | Out-String ).Trim()
   }

   Start-Sleep -Seconds $intervalSeconds
} While( $vSANResyncingStatus[ 0 ].TotalResyncingObjectRecoveryETAMinutes -gt 0 )

If( $monitoringResults.Count -gt 0 ){
   Write-Host ""
   Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] vSAN resyncing Completed."
}

Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] Disconnecting from $serverURL."
Disconnect-VIServer -Server $serverConnection -Confirm:$false