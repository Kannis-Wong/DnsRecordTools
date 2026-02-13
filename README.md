# DnsRecordTools

DnsRecordTools is a PowerShell module that converts
`Get-DnsServerResourceRecord` output into a consistent, normalized object
model for filtering, exporting, and automation.

## Why DnsRecordTools?

The built-in `Get-DnsServerResourceRecord` cmdlet returns rich DNS record objects,
but the data structure is **not friendly for export or automation**.

### Problem: RecordData cannot be exported directly

Each DNS record type stores its actual data in the `RecordData` property which is type of CimInstance and is a **different object type for each record type** (A, AAAA, CNAME, MX, etc.).

As a result, exporting records directly produces unusable output:


```powershell
Get-DnsServerResourceRecord -ZoneName kannis.com -Name www | ConvertTo-Csv
```
will output:
```
"DistinguishedName","HostName","RecordClass","RecordData","RecordType","Timestamp","TimeToLive","Type","PSComputerName"
"DC=www,DC=kannis.com,cn=MicrosoftDNS,DC=DomainDnsZones,DC=kannis,DC=com","www","IN","DnsServerResourceRecordA","A",,"01:00:00","1",
```
The RecordData column only shows the object type, not the actual value
(e.g. IP address, target hostname, mail exchanger).
This makes direct CSV or JSON export impractical

### What DnsRecordTools solves

DnsRecordTools converts DNS records into a **normalized, consistent object model**
that is easy to:

- Export to CSV or JSON
- Filter and sort
- Detect the "@" symbol (zone apex) that represents the root domain
- Compare records across zones or servers
- Use in automation and reporting scripts

Each record type is flattened into explicit properties
(e.g. `IPv4`, `IPv6`, `HostNameAlias`, `MailExchange`, `Port`, `Priority`, etc.),
so you no longer need to manually inspect `RecordData` for each type.

## Available Commands

- ConvertFrom-DnsRecord

## Installation

```powershell
Install-Module DnsRecordTools -Scope CurrentUser
```

## Usage
```powershell
Get-DnsServerResourceRecord -ZoneName contoso.com |
ConvertFrom-DnsRecord -ZoneName contoso.com
```

## Exporting

- CSV

```powershell
Get-DnsServerResourceRecord -ZoneName contoso.com -RRType Ns |
ConvertFrom-DnsRecord -ZoneName contoso.com |
ConvertTo-Csv -NoTypeInformation

<# example output
"DistinguishedName","HostName","Fqdn","RecordClass","RecordType","Timestamp","TimeToLive","Type","DnsServer","NameServer"
"DC=@,DC=contoso.com,cn=MicrosoftDNS,DC=DomainDnsZones,DC=contoso,DC=com","@","contoso.com","IN","NS",,"01:00:00","2","DC01","dc01.contoso.com."
"DC=_msdcs,DC=contoso.com,cn=MicrosoftDNS,DC=DomainDnsZones,DC=contoso,DC=com","_msdcs","_msdcs.contoso.com","IN","NS",,"01:00:00","2","DC01","dc01.contoso.com."
#>
```

- JSON
```powershell
Get-DnsServerResourceRecord -ZoneName contoso.com -RRType A |
ConvertFrom-DnsRecord -ZoneName contoso.com |
ConvertTo-Json -Depth 3

<# example output
[
    {
        "DistinguishedName":  "DC=@,DC=contoso.com,cn=MicrosoftDNS,DC=DomainDnsZones,DC=contoso,DC=com",
        "HostName":  "@",
        "Fqdn":  "contoso.com",
        "RecordClass":  "IN",
        "RecordType":  "NS",
        "Timestamp":  null,
        "TimeToLive":  "01:00:00",
        "Type":  2,
        "DnsServer":  "DC01",
        "NameServer":  "dc01.contoso.com."
    },
    {
        "DistinguishedName":  "DC=_msdcs,DC=contoso.com,cn=MicrosoftDNS,DC=DomainDnsZones,DC=contoso,DC=com",
        "HostName":  "_msdcs",
        "Fqdn":  "_msdcs.contoso.com",
        "RecordClass":  "IN",
        "RecordType":  "NS",
        "Timestamp":  null,
        "TimeToLive":  "01:00:00",
        "Type":  2,
        "DnsServer":  "DC01",
        "NameServer":  "dc01.contoso.com."
    }
]
#>
```

## Supported Record Types
- A
- AAAA
- CNAME
- TXT
- MX
- SRV
- SOA
- PTR
- NS
