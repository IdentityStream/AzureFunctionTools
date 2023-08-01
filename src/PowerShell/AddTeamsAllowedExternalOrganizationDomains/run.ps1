using namespace System.Net

param($Request, $TriggerMetadata)

$ErrorActionPreference = "Stop"

$statusCode = [HttpStatusCode]::OK
$message = ""
$invocationId = $TriggerMetadata.InvocationId

try {
    $domain = $Request.Body.ExternalOrganizationDomain

    if ([string]::IsNullOrEmpty($domain)) {
        $statusCode = [HttpStatusCode]::BadRequest
        $message = "Domain for external organization is missing"
    } else {
        Import-Module $psScriptRoot\..\Modules\ConnectMicrosoftTeams.psm1
        Connect-MicrosoftTeamsUsingRequest -body $Request.Body
        
        $currentAllowedDomains = Get-CsTenantFederationConfiguration | Select-Object -ExpandProperty AllowedDomains
        Write-Host "Current Microsoft Teams federation allowed domains: $currentAllowedDomains"
        
        $domain = $domain -replace “.*@”
        
        if ($currentAllowedDomains.AllowedDomain.Domain -contains $domain) { # Make function idempotent - duplicates will be added without this check
            $message = "The domain $domain is already present in the list of federation allowed domains in Microsoft Teams."
        } else {
            Write-Host "Adding domain $domain to Microsoft Teams list of federation allowed domains"
            
            # This command was not available in Skype For Business Online at the time of writing so we have to get the full list of domains, add the new one and then send this list - this is the preferred function to use if it does come available:
            # New-CsAllowedDomain -Identity $domain            
            
            $domainList = @(New-CsEdgeDomainPattern -Domain $domain)
            $domainList += $currentAllowedDomains.AllowedDomain
            
            $newAllowList = New-CsEdgeAllowList -AllowedDomain $domainList
            Set-CsTenantFederationConfiguration -AllowedDomains $newAllowList            
            $currentAllowedDomains = Get-CsTenantFederationConfiguration | Select-Object -ExpandProperty AllowedDomains

            $message = "The domain $domain was successfully added to the list of federation allowed domains in Microsoft Teams. The full allow list is now: $currentAllowedDomains"
        }
    }
    if (![string]::IsNullOrEmpty($message)) {
        Write-Host $message
    }
} catch {
    $message = $_
    Write-Error $message
    $statusCode = [HttpStatusCode]::InternalServerError
}

$output = @{
    "invocationId" = $invocationId
    "message" = $message
} | ConvertTo-Json

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $statusCode
    Body = $output
})