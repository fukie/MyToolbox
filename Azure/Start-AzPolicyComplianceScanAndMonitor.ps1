Function Start-AzPolicyComplianceScanAndMonitor(){
   <#
   .SYNOPSIS
   Starts an Azure Policy Compliance scan and monitors it.
   
   .DESCRIPTION
   Starts an Azure Policy Compliance scan as a background job and allows the monitoring of the job.
   Frequency of monitoring is customizable.
   Informs once the scan is compleeted.
   
   .PARAMETER waitSeconds
   Mandatory. Integer. Number of seconds to wait before checking the background job's status.
   
   .PARAMETER rgName
   String. Name of resource group to check. If omitted, the whole subscription is scanned.
   
   .EXAMPLE
   Start-AzPolicyComplianceScanAndMonitor -waitSeconds $waitSeconds -rgName $rgName
   Start-AzPolicyComplianceScanAndMonitor -waitSeconds $waitSeconds
   
   .NOTES
   --- Other Parameters ---
   Create a config file (Azure-Config.ps1) in the same folder as this script, with the following parameters
   $tenantID         - ID of Azure tenant, e.g., "1a2b3c4d-5e6f-7g8h-9i0j-1a2b-3c4d5e6f7g8h"
   $subscriptionID   - ID of Azure subscription, e.g., "1a2b3c4d-5e6f-7g8h-9i0j-1a2b-3c4d5e6f7g8h"
   $rgName           - Name of resource group.
   $intervalSeconds  - How frequent to check and report on the status. 
                     - Recommend to set at least 30 seconds or higher to keep network utilization low.
   #>
   Param(
      [ Parameter( Mandatory=$true ) ][ Int ]$waitSeconds,
      [ String ]$rgName
   )
   Try{
      # Check for valid session before continuing. Else, terminate script.
      $session = Get-AzContext
      If( $null -eq $session ){
         Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] No Azure session detected, ending script..."
         Exit
      }

      If( $rgName ){
         # If resource group name is incorrect, it does not throw an error. Scan will then run for the whole subscription.
         $job = Start-AzPolicyComplianceScan -ResourceGroupName $rgName -AsJob
      } Else{
         $job = Start-AzPolicyComplianceScan -AsJob
      }
      
      While( $job.State -eq "Running" ){
         Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] Azure compliance scan state: $( $job.State )"
         Start-Sleep -Seconds $waitSeconds
      }
      Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] Azure compliance scan state: $( $job.State )"
   } Catch{
      Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] Error occured, please check."
   }
}

# Load library file.
. "$PSScriptRoot\Azure-Config.ps1"
. "$PSScriptRoot\Azure-Library.ps1"

Connect-AzAccountAndCheck -tenantID $tenantID -subscriptionID $subscriptionID | Out-Null
Start-AzPolicyComplianceScanAndMonitor -waitSeconds $intervalSeconds -rgName $rgName