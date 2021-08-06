using namespace System.Net

param($Request, $TriggerMetadata)

$ErrorActionPreference = "Stop"

$invocationId = $TriggerMetadata.InvocationId
$statusCode = [HttpStatusCode]::OK
$msg = ""

try {
    $dnsRecordName = $Request.Body.DnsRecordName
    $dnsRecordValue = $Request.Body.DnsRecordValue
    $zoneName = $Request.Body.ZoneName
    $resourceGroupName = $Request.Body.ResourceGroupName
    $recordType = $Request.Body.RecordType
    if ([string]::IsNullOrEmpty($recordType)) {
        $recordType = "A"
    }

    $records = @()
    switch ($recordType) {
        "A" { $records += New-AzDnsRecordConfig -IPv4Address $dnsRecordValue }
        "CNAME" { $records += New-AzDnsRecordConfig -Cname $dnsRecordValue }
        "AAAA" { $records += New-AzDnsRecordConfig -Ipv6Address $dnsRecordValue }
        Default {}
    }

    if ([string]::IsNullOrEmpty($dnsRecordName) -or 
        [string]::IsNullOrEmpty($dnsRecordValue) -or 
        [string]::IsNullOrEmpty($zoneName) -or
        [string]::IsNullOrEmpty($resourceGroupName) -or
        $records.Count -lt 1) {
        $msg = "Body does not contain 'dnsRecordName', 'ip', 'zoneName', 'resourceGroupName' and valid 'recordType' (A, AAAA or CName)"
        Write-Host $msg
        $statusCode = [HttpStatusCode]::BadRequest
    } else {
        Write-Host "Starting create DNS record"
        $recordSet = New-AzDnsRecordSet -Name $dnsRecordName -RecordType $recordType -ZoneName $zoneName -ResourceGroupName $resourceGroupName -Ttl 3600 -DnsRecords $records
        if ($recordSet) {
            $msg = "DNS $recordType record $dnsRecordName was added to zone $zoneName in resource group $resourceGroupName and assigned value $dnsRecordValue"
        } else {
            $statusCode = [HttpStatusCode]::InternalServerError
            $msg = "DNS $recordType  record $subDomain was not added"
        }
    }
} catch {
    $msg = $_
    if ($msg -match "exists already") {
        $statusCode = [HttpStatusCode]::OK
    } else {
        $statusCode = [HttpStatusCode]::InternalServerError
    }
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