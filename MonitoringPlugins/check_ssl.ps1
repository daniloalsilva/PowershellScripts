<#  
.SYNOPSIS  
    Validates a certificate of domain passed as a param and returns a nagios code

.DESCRIPTION
    The check_ssl.ps1 uses Microsoft.PowerShell.Security class to retrieve certificate collection
    Threshould of Warning and Critical are optional
    If Critical value wasn't passed as parameter, critical state appears only to expirated certs
    Usage: check_ssl.ps1 [options]:
        -domain     - domain to check (mandatory)
        -warning    - threshould in days to explode a warning
        -critical   - threshould in days to explode a critical

.NOTES  
    File Name      : check_ssl.ps1
    Author         : Danilo Silva - daniloalsilva@gmail.com
    Prerequisite   : PowerShell V2 or greater.
    Copyright 2014 - Danilo Silva

.EXAMPLE
    check_ssl.ps1 -domain *.github.com
    check_ssl.ps1 -domain *.github.com -warning 30 -critical 5
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$domain,
    [int]$warning,
    [int]$critical
)

$nagiosCodes = @{
    "OK" = 0;
    "Warning" = 1;
    "Critical" = 2;
    "Unknown" = 3;
}

$nowdate = Get-Date

$path = 'Cert:\LocalMachine\My'
$cert = ls $path | ? {$_.Subject.Contains($domain)}

if ($cert -eq $null){
    "CRITICAL - there is no certificate installed to domain $domain"
    exit $nagiosCodes["CRITICAL"]
}

$expirationDate = @()

$cert | % { $expirationDate += $_.NotAfter.ToOADate() }

$newerCertDate = [Datetime]::FromOADate(($expirationDate | measure -Maximum).Maximum)

if ($newerCertDate -le $nowdate.AddDays(-$critical)){
    "CRITICAL - certificate from $domain is valid until " + $newerCertDate.ToString("dd/MM/yyyy")
    exit $nagiosCodes["Critical"]
}
elseif ($newerCertDate -le $nowdate.AddDays(-$warning)){
    "WARNING - certificate from $domain is valid until " + $newerCertDate.ToString("dd/MM/yyyy")
    exit $nagiosCodes["Warning"]
}
else {
    "OK - certificate from $domain is valid until " + $newerCertDate.ToString("dd/MM/yyyy")
    exit $nagiosCodes["OK"]
}