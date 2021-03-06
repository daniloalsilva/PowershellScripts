Param(
    [Parameter(Mandatory=$true)]
    $domain,
    [Parameter(Mandatory=$true)]
    $warning,
    [Parameter(Mandatory=$true)]
    $critical,
    [switch]$ignoreMissingCertificate
)

function Get-WebSiteCertificates {

    Param(
        [Parameter(Mandatory=$true)]
        [string]$domain
    )
    
    $sites_with_certs = @()

    $encoding_type = "System.Text.ASCIIEncoding"
    $encode = New-Object $encoding_type
    $WebServerQuery = "Select * from IIsWebServerSetting"

    $sites = gwmi -namespace "root\MicrosoftIISv2" -query "select Name, ServerComment, SSLStoreName from IIsWebServerSetting"

    foreach( $site in $sites ) {
        if( $site.SSLStoreName -eq "My" ) {    
            $certmgr = New-Object -ComObject IIS.CertObj
            $certmgr.ServerName = $ENV:COMPUTERNAME
            $certmgr.InstanceName = $site.Name 

            $cert_info_bytes = $certmgr.GetCertInfo()
            $certs_info_stripped = $cert_info_bytes | where { $_ -ne 0 }
            $cert_info = ($encode.GetString($certs_info_stripped)).Split("`n")
            
            $subject = $cert_info | where { $_ -imatch "2.5.4.3" } | % { $_.Split("=")[1] }
            $expiration = $cert_info | where { $_ -like "6=*" } | % { $_.Split("=")[1] }
            if ($subject -eq $domain){
                $sites_with_certs += (New-Object PSObject -Property @{
                    Site = $site.ServerComment
                    Certificate = $subject
                    Server = $env:COMPUTERNAME
                    ExpirationDate = [DateTime]::Parse($expiration.Replace(" ","").Replace("",""))
                })            
            }
        }
    }

    return $sites_with_certs
}

$nagiosCodes = @{
    "OK" = 0;
    "Warning" = 1;
    "Critical" = 2;
    "Unknown" = 3;
}

$certObj = Get-WebSiteCertificates $domain

$nowdate = Get-Date

if ($certObj -eq $null){
    if($ignoreMissingCertificate){
        "OK - there is no websites using certificate of domain $domain"
        exit $nagiosCodes["OK"]        
    }
    else {
        "CRITICAL - there is no websites using certificate of domain $domain"
        exit $nagiosCodes["CRITICAL"]
    }
}

$expirationDate = @()
$returnText = ""

$certObj | % { $expirationDate += $_.ExpirationDate.ToOADate() }
$certObj | % {
    $tempdate = $_.ExpirationDate.ToString("dd/MM/yyyy")
    $tempsite = $_.Site
    $tempdomain = $_.Certificate
    $returnText += "WebSite $tempsite using CERT $tempdomain, valid until $tempdate; "
}

$olderCertDate = [Datetime]::FromOADate(($expirationDate | measure -Minimum).Minimum)

if ($olderCertDate -le $nowdate.AddDays(-$critical)){
    "CRITICAL - $returnText"
    exit $nagiosCodes["Critical"]
}
elseif ($olderCertDate -le $nowdate.AddDays(-$warning)){
    "WARNING - $returnText"
    exit $nagiosCodes["Warning"]
}
else {
    "OK - $returnText"
    exit $nagiosCodes["OK"]
}