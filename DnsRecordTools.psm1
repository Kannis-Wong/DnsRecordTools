# DnsRecordTools.psm1

$PublicPath = Join-Path $PSScriptRoot 'Public'
$Public = @(Get-ChildItem -Path (Join-Path $PublicPath '*.ps1') -File -ErrorAction SilentlyContinue)

foreach ($file in $Public) {
    try {
        . $file.FullName
    }
    catch {
        throw "Failed to import $($file.FullName): $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function ($Public | Select-Object -ExpandProperty BaseName)