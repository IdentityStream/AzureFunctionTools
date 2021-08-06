using namespace System.Net

param($Request, $TriggerMetadata)

$ErrorActionPreference = "Stop"

Write-Host "Getting PowerShell Modules"

$modules = Get-Module -ListAvailable |
Select-Object Name, Version, ModuleBase |
Sort-Object -Property Name |
Format-Table -wrap |
Out-String

$invocationId = $TriggerMetadata.InvocationId

$json = @"
{
    "invocationId": "$invocationId",
    "modules": "$modules"
}
"@

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $json
})