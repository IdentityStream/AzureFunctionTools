using namespace System.Net

param($Request, $TriggerMetadata)

$ErrorActionPreference = "Stop"

$statusCode = [HttpStatusCode]::OK
$message = ""
$invocationId = $TriggerMetadata.InvocationId

try {
    $domain = $Request.Body.ExternalOrganizationDomain
    $userName = $Request.Body.UserName
    $password = $Request.Body.Password
    if ([string]::IsNullOrEmpty($domain)) {
        $statusCode = [HttpStatusCode]::BadRequest
        $message = "Domain for external organization is missing"
    } else {
        Write-Host "Start connection to Microsoft Teams as user: $userName"
        Import-Module MicrosoftTeams
        [securestring]$secStringPassword = ConvertTo-SecureString $password -AsPlainText -Force
        [pscredential]$credential = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)
        Connect-MicrosoftTeams -Credential $credential
        $currentAllowedDomains = Get-CsTenantFederationConfiguration | Select-Object -ExpandProperty AllowedDomains
        Write-Host "Current Microsoft Teams federation allowed domains: $currentAllowedDomains"
        $domain = $domain -replace “.*@”
        if ($currentAllowedDomains.AllowedDomain.Domain -contains $domain) {
            $message = "The domain $domain is already present in the list of federation allowed domains in Microsoft Teams." # This makes function idempotent :)
        } else {
            Write-Host "Adding domain $domain to Microsoft Teams list of federation allowed domains"
            # this command was not available in Skype For Business Online at the time of writing so we have to send the full list
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