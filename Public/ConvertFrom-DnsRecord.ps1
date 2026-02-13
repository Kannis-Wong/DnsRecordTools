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
                $baseObj =  [pscustomobject]@{
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
                        $baseObj | Add-Member -MemberType NoteProperty -Name 'IPv4' -Value $rd.IPv4Address.IPAddressToString -Force
                    }
                    'AAAA' {
                        $baseObj | Add-Member -MemberType NoteProperty -Name 'IPv6' -Value $rd.IPv6Address.IPAddressToString -Force
                    }
                    'CNAME' {
                        $baseObj | Add-Member -MemberType NoteProperty -Name 'HostNameAlias' -Value $rd.HostNameAlias -Force
                    }
                    'TXT' {
                        $baseObj | Add-Member -MemberType NoteProperty -Name 'DescriptiveText' -Value $rd.DescriptiveText -Force
                    }
                    'NS' {
                        $baseObj | Add-Member -MemberType NoteProperty -Name 'NameServer' -Value $rd.NameServer -Force
                    }
                    'SRV' {
                        $baseObj | Add-Member -MemberType NoteProperty -Name 'DomainName' -Value $rd.DomainName -Force
                        $baseObj | Add-Member -MemberType NoteProperty -Name 'Port' -Value $rd.Port -Force
                        $baseObj | Add-Member -MemberType NoteProperty -Name 'Priority' -Value $rd.Priority -Force
                        $baseObj | Add-Member -MemberType NoteProperty -Name 'Weight' -Value $rd.Weight -Force
                    }
                    'SOA' {
                        $baseObj | Add-Member -MemberType NoteProperty -Name 'ExpireLimit' -Value $rd.ExpireLimit.ToString() -Force
                        $baseObj | Add-Member -MemberType NoteProperty -Name 'MinimumTimeToLive' -Value $rd.MinimumTimeToLive.ToString() -Force
                        $baseObj | Add-Member -MemberType NoteProperty -Name 'PrimaryServer' -Value $rd.PrimaryServer -Force
                        $baseObj | Add-Member -MemberType NoteProperty -Name 'RefreshInterval' -Value $rd.RefreshInterval.ToString() -Force
                        $baseObj | Add-Member -MemberType NoteProperty -Name 'ResponsiblePerson' -Value $rd.ResponsiblePerson -Force
                        $baseObj | Add-Member -MemberType NoteProperty -Name 'RetryDelay' -Value $rd.RetryDelay.ToString() -Force
                        $baseObj | Add-Member -MemberType NoteProperty -Name 'SerialNumber' -Value $rd.SerialNumber -Force
                    }
                    'MX' {
                        $baseObj | Add-Member -MemberType NoteProperty -Name 'MailExchange' -Value $rd.MailExchange -Force
                        $baseObj | Add-Member -MemberType NoteProperty -Name 'Preference' -Value $rd.Preference -Force
                    }
                    'PTR' {
                        $baseObj | Add-Member -MemberType NoteProperty -Name 'PtrDomainName' -Value $rd.PtrDomainName -Force
                    }
                    default {
                        $baseObj | Add-Member -MemberType NoteProperty -Name 'UnknownRecordType' -Value $rd.ToString() -Force
                    }
                }
                $baseObj
            }
            catch {
                throw
            }
        }
    }
}
