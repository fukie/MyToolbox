Function Connect-AzAccountAndCheck( $tenantID, $subscriptionID ){
   Try{
      $authentication = Connect-AzAccount -Tenant $tenantID -Subscription $subscriptionID -ErrorAction Stop
      Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] Authentication and authorization successful."
   } Catch{
      # If authentication failed or no access, $null will be returned by Connect-AzAccount
      Write-Host "[$( Get-Date -Format "yyyy-MM-dd HH:mm" )] Authentication/authorization error, please check. Ending script..."
      Exit
   }
   Return $authentication

   <#
   $tenantID         = "1a2b3c4d-5e6f-7g8h-9i0j-1a2b3c4d5e6f"
   $subscriptionID   = "1a2b3c4d-5e6f-7g8h-9i0j-1a2b3c4d5e6f"

   $authentication = $null
   $authentication = Connect-AzAccountAndCheck -tenantId $tenantID -subscriptionID $subscriptionID
   $authentication
   #>
}

