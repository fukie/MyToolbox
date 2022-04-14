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
Create a config file with the following parameters
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

# Load config file which shoud 
. "$PSScriptRoot\VMware-Config.ps1"

Function Test-AndInstallPSModule( $moduleName ){
   Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] Checking for module $moduleName..."

   If ( Get-Module -ListAvailable -Name $moduleName ) {
      Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] Module $moduleName exists"
   } 
   Else {
      # Requires connection to PowerShell Gallery repository.
      # Defaults to installation of module for current user and skipping warning of untrusted repository.
      Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] Module $moduleName does not exist. Attempting to install..."
      Install-Module -Name VMware.PowerCLI -Scope CurrentUser -Force
   }
   Write-Host ""
}

Function Test-AndConfigureVMwareInvalidCertificates( [ Boolean ]$ignoreInvalidCertificates ){
   Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] Checking this session's action to be taken for invalid certificates..."
   $powerCLIConfigs = Get-PowerCLIConfiguration

   If( $powerCLIConfigs.Where( { $_.Scope -eq "Session" } ).InvalidCertificateAction -eq "Ignore" -And $ignoreInvalidCertificates ){
      Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] Action for invalid certificates is configured to 'Ignore'."
   } ElseIf( $powerCLIConfigs.Where( { $_.Scope -eq "Session" } ).InvalidCertificateAction -ne "Ignore" -And $ignoreInvalidCertificates ){
      Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] Action for invalid certificates is configured to '$( $powerCLIConfigs.Where( { $_.Scope -eq "Session" } ).InvalidCertificateAction )'."
      Try{
         Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] Flag 'ignoreInvalidCertificates' is set to true, changing configuration..."
         Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Scope Session -Confirm:$false | Out-Null
         Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] Action for invalid certificates is changed to 'Ignore'."
      } Catch{
         Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] Error occured. Please peform checks. Script terminating."
         Exit
      }
   } ElseIf( $ignoreInvalidCertificates -eq $false ){
      Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] Action for invalid certificates is configured to '$( $powerCLIConfigs.Where( { $_.Scope -eq "Session" } ).InvalidCertificateAction )'."
      Try{
         Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] Flag 'ignoreInvalidCertificates' is set to false, changing configuration to 'Unset'..."
         Set-PowerCLIConfiguration -InvalidCertificateAction Unset -Scope Session -Confirm:$false | Out-Null
         Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] Action for invalid certificates is changed to 'Unset'."
      } Catch{
         Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] Error occured. Please peform checks. Script terminating."
         Exit
      }
   }
   Write-Host ""
}

Function Connect-VMwareServer( $serverURL, $credentials ){
   Try{ 
      Connect-VIServer -Server $serverURL -User $credentials.username -Password $credentials.password -ErrorAction Stop | Out-Null
      Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] Successful connection and authentication to $serverURL."
   } Catch [ VMware.VimAutomation.ViCore.Types.V1.ErrorHandling.InvalidLogin ]{
      Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] Authentication failed to $serverURL."
      Exit
   } Catch [VMware.VimAutomation.Sdk.Types.V1.ErrorHandling.VimException.ViServerConnectionException]{
      Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] Connect failed to $serverURL."
      Exit
   } Catch{
      Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] Unexpected error while connecting/authentication to $serverURL."
      Exit
   }
}

Test-AndInstallPSModule -moduleName "VMware.PowerCLI"
Test-AndConfigureVMwareInvalidCertificates -ignoreInvalidCertificates:$true
Connect-VMwareServer -serverURL $serverURL -credentials $credentials

[ System.Collections.ArrayList ]$monitoringResults =  @()
Do{
   $dateTime = Get-Date -Format "yyyy-MM-dd HH:mm"
   $vSANResyncingStatus = Get-VsanResyncingOverview -Cluster $clusterName
   $vSANResyncingStatusETA = [ String ][ Math ]::Round( $vSANResyncingStatus[ 0 ].TotalResyncingObjectRecoveryETAMinutes / 60, 2 )

   If( $vSANResyncingStatus[ 0 ].TotalDataToSyncGB -eq 0 ){
      Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] No vSAN resyncing in progress."
      Exit
   }
   
   If( $monitoringResults.Count -gt 0 ){
      $dataTransferSpeed = [ Math ]::Floor( 
         ( $monitoringResults[ $monitoringResults.Count - 1 ].dataLeftGB - $vSANResyncingStatus[ 0 ].TotalDataToSyncGB ) / 
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

Write-Host ""
Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] vSAN resyncing Completed"