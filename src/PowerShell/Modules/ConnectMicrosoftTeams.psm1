function Connect-MicrosoftTeamsUsingRequest {
    param (
        [object] $body
    )

    $authentication = $body.Authentication
    if ($authentication -eq "Application") {
        $vaultName = $body.VaultName
        $certificateName = $body.CertificateName
        $applicationId = $body.ApplicationId
        $tenantId = $body.TenantId

        if (!$vaultName -or !$certificateName -or !$applicationId -or !$tenantId) {
            $msg = "Request body does not contain 'VaultName', 'CertificateName', 'ApplicationId' and 'TenantId'"
            Write-Host $msg
            throw $msg
        }

        Write-Host "Start connection to Microsoft Teams as application $applicationId"

        Connect-AzAccount -Identity
        
        Write-Host "Start reading certificate $certificateName from vault $vaultName"
        $certificate = (Get-AzKeyVaultSecret -VaultName $vaultName -Name $certificateName -AsPlainText)
        Write-Host "Certificate string has length $($certificate.Length). Converting to certificate object."
        $pfxByteArray = [Convert]::FromBase64String($certificate)
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList $pfxByteArray,$null

        Write-Host "Start connection to Microsoft Teams with key vault certificate $($cert.Subject) using application $applicationId and tenant $tenantId"
        Connect-MicrosoftTeams -Certificate $cert -ApplicationId $applicationId -TenantId $tenantId
    } else {
        $userName = $body.UserName
        $password = $body.Password

        if (!$userName -or !$password) {
            $msg = "Request body does not contain 'UserName' and 'Password'"
            Write-Host $msg
            throw $msg
        }

        Write-Host "Start connection to Microsoft Teams as user $userName"
        [securestring]$secStringPassword = ConvertTo-SecureString $password -AsPlainText -Force
        [pscredential]$credential = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)
        
        Connect-MicrosoftTeams -Credential $credential
    }
    Write-Host "Successfully connected to Microsoft Teams"
}

Export-ModuleMember -Function Connect-MicrosoftTeamsUsingRequest