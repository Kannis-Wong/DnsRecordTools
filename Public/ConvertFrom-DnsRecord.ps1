function ConvertFrom-DnsRecord {
<#
.SYNOPSIS
Converts DNS ciminstance into a normalized PowerShell object.

.DESCRIPTION
ConvertFrom-DnsRecord takes DNS record objects, typically returned by
Get-DnsServerResourceRecord, and converts them into a consistent,
structured PSCustomObject.

This normalized output is designed for:
- Filtering and comparison
- Exporting to CSV/JSON
- Automation and reporting

Each DNS record type (A, AAAA, CNAME, TXT, MX, SRV, SOA, PTR, NS) is mapped
to appropriate properties when available.

.PARAMETER InputObject
DNS record object(s) to convert. Accepts pipeline input.

.PARAMETER ZoneName
DNS zone name used to construct a fully qualified domain name (FQDN).

.PARAMETER ServerName
DNS server name to include in the output. Defaults to the local computer name.

.INPUTS
System.Object[]

.OUTPUTS
System.Management.Automation.PSCustomObject

.EXAMPLE
Get-DnsServerResourceRecord -ZoneName 'contoso.com' |
ConvertFrom-DnsRecord -ZoneName 'contoso.com'

.EXAMPLE
Get-DnsServerResourceRecord -ZoneName 'contoso.com' -RRType A |
ConvertFrom-DnsRecord -ZoneName 'contoso.com' |
Export-Csv dns-a-record.csv -NoTypeInformation

.NOTES
Author  : Kannis Wong
Module  : DnsRecordTools
Requires: Windows PowerShell 5.1 or PowerShell Core 7.4+, DnsServer module (RSAT-DNS-Server)
#>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [object[]]$InputObject,
        [Parameter(Position = 1)]
        [string]$ZoneName,
        [Parameter(Position = 2)]
        [string]$ServerName = $env:COMPUTERNAME
    )
    process {
        foreach ($rr in $InputObject) {
            $hasRecordType = $rr.PSObject.Properties.Match('RecordType').Count -gt 0
            $hasRecordData = $rr.PSObject.Properties.Match('RecordData').Count -gt 0
            if ((-not $hasRecordType) -or (-not $hasRecordData) -or (-not $rr.RecordData)) {
                [pscustomobject]@{
                    DistinguishedName   = $null
                    HostName            = $null
                    RecordClass         = $null
                    RecordType          = $null
                    Timestamp           = $null
                    TimeToLive          = $null
                    Type                = $null
                    DnsServer           = $ServerName
                }
                continue
            }
            try {
                $rDN        = $rr.DistinguishedName
                $rName      = $rr.HostName
                $fqdn       = if (($rName -eq '@') -and $ZoneName) { "$ZoneName" } elseif ($rName -and $ZoneName) { "$rName.$ZoneName" } else { "Unknown" }
                $rClass     = $rr.RecordClass
                $rd         = $rr.RecordData
                $rtype      = $rr.RecordType
                $type       = $rr.Type
                $ts         = if (-not ($rr.Timestamp)) { $null } else { $rr.Timestamp.ToString("o") }
                $ttl        = if (-not ($rr.TimeToLive)) { $null } else { $rr.TimeToLive.ToString() }
                $baseObj =  [ordered]@{
                    DistinguishedName   = $rDN
                    HostName            = $rName
                    Fqdn                = $fqdn
                    RecordClass         = $rClass
                    RecordType          = $rtype
                    Timestamp           = $ts
                    TimeToLive          = $ttl
                    Type                = $type
                    DnsServer           = $ServerName
                }
                switch ($rtype) {
                    'A' {
                        $baseObj['IPv4']                = $rd.IPv4Address.IPAddressToString
                    }
                    'AAAA' {
                        $baseObj['IPv6']                = $rd.IPv6Address.IPAddressToString
                    }
                    'CNAME' {
                        $baseObj['HostNameAlias']       = $rd.HostNameAlias
                    }
                    'TXT' {
                        $baseObj['DescriptiveText']     = $rd.DescriptiveText
                    }
                    'NS' {
                        $baseObj['NameServer']          = $rd.NameServer
                    }
                    'SRV' {
                        $baseObj['DomainName']          = $rd.DomainName
                        $baseObj['Port']                = $rd.Port
                        $baseObj['Priority']            = $rd.Priority
                        $baseObj['Weight']              = $rd.Weight
                    }
                    'SOA' {
                        $baseObj['ExpireLimit']         = $rd.ExpireLimit.ToString()
                        $baseObj['MinimumTimeToLive']   = $rd.MinimumTimeToLive.ToString()
                        $baseObj['PrimaryServer']       = $rd.PrimaryServer
                        $baseObj['RefreshInterval']     = $rd.RefreshInterval.ToString()
                        $baseObj['ResponsiblePerson']   = $rd.ResponsiblePerson
                        $baseObj['RetryDelay']          = $rd.RetryDelay.ToString()
                        $baseObj['SerialNumber']        = $rd.SerialNumber
                    }
                    'MX' {
                        $baseObj['MailExchange']        = $rd.MailExchange
                        $baseObj['Preference']          = $rd.Preference
                    }
                    'PTR' {
                        $baseObj['PtrDomainName']       = $rd.PtrDomainName
                    }
                    default {
                        $baseObj['UnknownRecordType']   = $rd.ToString()
                    }
                }
                [pscustomobject]$baseObj
            }
            catch {
                throw
            }
        }
    }
}
