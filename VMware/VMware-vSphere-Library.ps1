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
      $serverConnection = Connect-VIServer -Server $serverURL -User $credentials.username -Password $credentials.password -ErrorAction Stop
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
   Return $serverConnection
}