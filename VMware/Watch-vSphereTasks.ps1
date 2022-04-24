<#
.SYNOPSIS
Script to check and watch a vSphere server/cluster's tasks that are in the running state.
The tasks will be checked at regular intervals until there are no more tasks left in the running state.
This helps to circumvent the timeout issue on the vSphere client while giving the ability to continously monitor and see the progress.

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

--- Credit ---
https://www.virtjunkie.com/2019/03/04/get-details-from-get-task/
- Saw this script and noticed that it checks for cluster name.
- Realised that it can be useful in larger environments with multiple clusters and included a check to look up the cluster that the VM belongs to.

.EXAMPLE
PS C:\> .\Watch-vSphereTasks.ps1
[2022-04-22 15:53] Checking for module VMware.PowerCLI...
[2022-04-22 15:53] Module VMware.PowerCLI exists

[2022-04-22 15:53] Checking this session's action to be taken for invalid certificates...
[2022-04-22 15:53] Action for invalid certificates is configured to 'Ignore'.

[2022-04-22 15:53] Successful connection and authentication to x.x.x.x.

-------- Tasks As Of 22 April 2022 15:53 hrs --------

Cluster         VM Name          Description              Progress Start Time            Duration
-------         -------          -----------              -------- ----------            --------
vSAN Cluster    VM 01            Relocate virtual machine       12 22/4/2022 2:21:29 pm  1 Hours 31 Minutes
vSAN Cluster    VM 02            Relocate virtual machine       52 22/4/2022 1:58:47 pm  1 Hours 54 Minutes
vSAN Cluster    VM 03            Relocate virtual machine       61 22/4/2022 1:58:47 pm  1 Hours 54 Minutes
vSAN Cluster    VM 04            Remove all snapshots           96 22/4/2022 10:07:51 am 5 Hours 45 Minutes

-------- Tasks As Of 22 April 2022 15:58 hrs --------

Cluster         VM Name        Description              Progress Start Time            Duration
-------         -------        -----------              -------- ----------            --------
vSAN Cluster    VM 01          Relocate virtual machine       40 22/4/2022 2:21:29 pm  1 Hours 36 Minutes
vSAN Cluster    VM 02          Remove all snapshots           98 22/4/2022 10:07:51 am 5 Hours 50 Minutes

-------- Tasks As Of 22 April 2022 16:03 hrs --------

Cluster         VM Name        Description              Progress Start Time           Duration
-------         -------        -----------              -------- ----------           --------
vSAN Cluster    VM 01          Relocate virtual machine       43 22/4/2022 2:21:29 pm 1 Hours 41 Minutes

-------- Tasks As Of 22 April 2022 16:08 hrs --------

Cluster         VM Name        Description              Progress Start Time           Duration
-------         -------        -----------              -------- ----------           --------
vSAN Cluster    VM 01          Relocate virtual machine       47 22/4/2022 2:21:29 pm 1 Hours 46 Minutes

[2022-04-22 16:13] No tasks running currently.
[2022-04-22 16:13] Disconnecting from x.x.x.x.

.INPUTS
See .NOTES for paramters to configure.

.OUTPUTS
System.String. Writes status of vSphere tasks that are running, to console.

#>

# Load library and config file.
. "$PSScriptRoot\VMware-vSphere-Library.ps1"
. "$PSScriptRoot\VMware-Config.ps1"

Test-AndInstallPSModule -moduleName "VMware.PowerCLI"
Test-AndConfigureVMwareInvalidCertificates -ignoreInvalidCertificates:$true
$serverConnection = Connect-VMwareServer -serverURL $serverURL -credentials $credentials

$tasks = $null
Do{
   $dateTime = Get-Date
   [ System.Collections.ArrayList ]$tasksFormatted =  @()
   $tasks = Get-Task -Server $serverConnection -Status Running
   If( $tasks.Count -eq 0 ){
      Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] No tasks running currently."
      Break
   }

   ForEach( $task In $tasks ){
      <# ### Entity Types
         Cluster           - ClusterComputeResource
         vSphere Hosts     - HostSystem-host
         Virtual Machine   - VirtualMachine-vm
      #> 

      # Get cluster name if entity type is of VMs.
      If( $task.ExtensionData.Info.Entity -Like "VirtualMachine-vm*" ){
         $vm = Get-VM $task.ExtensionData.Info.EntityName -Server $serverConnection
         $cluster = $vm | Get-Cluster -Server $serverConnection
      } Else{
         $cluster = "-"
      }
      

      $duration = New-TimeSpan -Start $task.ExtensionData.Info.StartTime.ToLocalTime() -End $dateTime
      If( $duration.Days -gt 0 ){
         $durationFormatted = "$( $duration.Days ) Days $( $duration.Hours ) Hours $( $duration.Minutes ) Minutes"
      } ElseIf( $duration.Days -eq 0 -And $duration.Hours -gt 0 ){
         $durationFormatted = "$( $duration.Hours ) Hours $( $duration.Minutes ) Minutes"
      } ElseIf( $duration.Days -eq 0 -And $duration.Hours -eq 0 -And $duration.Minutes -gt 0 ){
         $durationFormatted = "$( $duration.Minutes ) Minutes"
      } ElseIf( $duration.Days -eq 0 -And $duration.Hours -eq 0 -And $duration.Minutes -eq 0 -And $duration.Seconds -gt 0 ){
         $durationFormatted = "$( $duration.Seconds ) Seconds"
      }
      $tasksFormatted.Add( [ PSCustomObject ]@{
         "Cluster" = $cluster.Name
         "Resource" = $task.ExtensionData.Info.EntityName
         "Description" = $task.Description
         "Progress" = $task.PercentComplete.ToString() + " %"
         "Start Time" = $task.StartTime
         "Duration" = $durationFormatted
      } ) | Out-Null
   }
   
   Write-Host "`n-------- Tasks As Of $( $dateTime.ToString( "dd MMMM yyyy HH:mm" ) ) hrs --------"
   ( $tasksFormatted | Sort-Object "Start Time" | Format-Table | Out-String ).TrimEnd()
   Start-Sleep -Seconds $intervalSeconds
} While( $tasks.Count -gt 0 )

Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] Disconnecting from $serverURL."
Disconnect-VIServer -Server $serverConnection -Confirm:$false