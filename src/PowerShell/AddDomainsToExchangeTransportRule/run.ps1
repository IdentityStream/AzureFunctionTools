using namespace System.Net

param($Request, $TriggerMetadata)

$ErrorActionPreference = "Stop"

function Enter-TransportRuleSenderDomains($ruleName, $domainList, $spamConfidenceLevel) {
    if ($domainList.Count -lt 1) {
        return
    }
    if (Get-TransportRule $ruleName -EA SilentlyContinue) {
        Write-Host "Updating existing rule: $ruleName"
        $existingDomainList = Get-TransportRule $ruleName | Select-Object -ExpandProperty SenderDomainIs
        $completeList = $existingDomainList + $domainList
        $completeList = $completeList | Select-Object -uniq | Sort-Object
        set-TransportRule $ruleName -SenderDomainIs $completeList
    } else {
        Write-Host "Creating new rule: $ruleName"
        $domainList = $domainList | Sort-Object
        New-TransportRule $ruleName -SenderDomainIs $domainList -SetSCL $spamConfidenceLevel
    }
}

function Get-DomainList($domains) {
    $domainList = @()
    if (!$domains) {
        return
    }
    $domainList += foreach ($domain in $domains) {
        $tmpdomain = $domain -replace “.*@”
        $tmpdomain.trim()
    }
    return $domainList
}

$statusCode = [HttpStatusCode]::OK
$msg = ""
$invocationId = $TriggerMetadata.InvocationId

try {
    $domains = Get-DomainList $Request.Body.Domains
    $spamConfidenceLevel = $Request.Body.SpamConfidenceLevel
    $transportRuleName = $Request.Body.TransportRuleName

    if ($domains.Count -lt 1 -or !$spamConfidenceLevel -or !$transportRuleName) {
        $statusCode = [HttpStatusCode]::BadRequest
        $msg = "Domain list, transport rule name or spam confidence level is missing"
    } else {
        $svcName = $ENV:ExoSvcAccountName
        $svcPwd = $ENV:ExoSvcPwd
        if (!$svcName -or !$svcPwd) {
            $statusCode = [HttpStatusCode]::InternalServerError
            $msg = "Function is not configured correctly"
        } else {
            $securePwd = ConvertTo-SecureString -String $svcPwd -AsPlainText -Force
            
            Write-Host "Connecting to EXO as: $svcName"
            $userCredential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $svcName, $securePwd
            
            $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "https://outlook.office365.com/powershell-liveid/" -Credential $userCredential -Authentication Basic -AllowRedirection
            Import-PSSession $Session
            
            Enter-TransportRuleSenderDomains $transportRuleName $domains $spamConfidenceLevel
            
            $Session.Runspace.Dispose()
        }
    }
    if ($msg) {
        Write-Host $msg
    }
} catch {
    $msg = $_
    $statusCode = [HttpStatusCode]::InternalServerError
}
$json = @"
{
    "invocationId": "$invocationId",
    "message": "$msg"
}
"@

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $statusCode
    Body = $json
})