<#  
.SYNOPSIS  
    Script used to update a certificate on server local store and sites using the certificate

.DESCRIPTION
    The UpdateCertificate.ps1 uses IIS.CertObj (COM+ Object), System.Security (.NET) classes and
    "certutil" to retrieve infomation about certificates and uptade then, if it's needed.
    
    Usage: UpdateCertificate.ps1 [options]:
        -pfxPath      - path of pfx certificate file (mandatory)
        -pfxPass      - password of pfx certificate (mandatory)
        -domain       - domain of pfx certificate (mandatory)
        -forceInstall - by default, certificate will only be installed if some
                        old certificate for the same domain is already installed;
                        use this option to install certificate if no certificate was installed before

.NOTES  
    File Name      : UpdateCertificate.ps1
    Author         : Danilo Silva - daniloalsilva@gmail.com
    Prerequisite   : PowerShell V2 or greater
                   : X509Certificates Objects (from System.Security - .NET)
                   : IIS.CertObj COM+ Object
                   : certutil.exe Windows tool
    Copyright 2013 - Danilo Silva

    
.EXAMPLES
    UpdateCertificate.ps1 -pfxPath domain_com_br.pfx -pfxPass XXXXXX -domain *.domain.com.br -forceInstall
    UpdateCertificate.ps1 -pfxPath \\share\certs$\domain_com_br.pfx -pfxPass XXXXXX -domain *.domain.com.br
    
#>

Param(
    [Parameter(Mandatory=$true)]
    $pfxPath,
    [Parameter(Mandatory=$true)]
    $pfxPass,
    [Parameter(Mandatory=$true)]
    $domain,
    [switch]$forceInstall
)

function Get-CertificateInfo {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$certPath,
        [Parameter(Mandatory=$true)]
        [string]$certPass
    )
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2   
    $cert.Import($certPath, $certPass, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
    @{
        "NotAfter" = $cert.NotAfter;
        "NotBefore" = $cert.NotBefore;
        "Subject" = $cert.Subject;
        "Thumbprint" = $cert.Thumbprint;
    }
}

function Get-WebSiteCertificates {

    Param(
        [Parameter(Mandatory=$true)]
        [string]$domain
    )
    
    $sites_with_certs = @()

    $encode = New-Object System.Text.ASCIIEncoding
    
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
                    Certficate = $subject
                    Server = $env:COMPUTERNAME
                    ExpirationDate = [DateTime]::Parse($expiration.Replace(" ","").Replace("",""))
                })            
            }
        }
    }

    return $sites_with_certs
}

Function ImportSSLCertificateToWebsite{
    param(
        [string]$pfxPath, 
        [string]$pfxPassword, 
        [string]$siteName
    )

    $iisWebSite = Get-WmiObject -Namespace 'root\MicrosoftIISv2' -Class IISWebServerSetting -Filter "ServerComment = '$siteName'";
    $certMgr = New-Object -ComObject IIS.CertObj -ErrorAction SilentlyContinue;
    $certMgr.InstanceName = [string]$iisWebSite.Name;
    $certMgr.Import($pfxPath,$pfxPassword,$true,$true);
}

#initial variables
$path = 'Cert:\LocalMachine\My'
$pfxPath = (ls $pfxPath).FullName

#getting info from pfx file
$pfxObj = Get-CertificateInfo -certPath $pfxPath -certPass $pfxPass -ErrorAction SilentlyContinue

#getting info from current certificates of specified domain
$cert = ls $path | ? {$_.Subject.Contains($domain)}

#getting last installed cetificate expiration date
if ($cert -ne $null -or $forceInstall){
    $expirationDate = @()
    $cert | % { $expirationDate += $_.NotAfter.ToOADate() }
    $newerCertDate = [Datetime]::FromOADate(($expirationDate | measure -Maximum).Maximum)
    
    #update cert on store, if needed
    if ($pfxObj.NotAfter -ne $newerCertDate -or $forceInstall){
        & certutil –f –p $pfxPass –importpfx $pfxPath | Out-Null
        "CERTIFICATE OF $domain UPDATED"
    }
    
    #update certificate for all websites using it
    Get-WebSiteCertificates $domain | % {
        if($_.ExpirationDate.Date -ne $pfxObj.NotAfter.Date){
            ImportSSLCertificateToWebsite $pfxPath $pfxPass $_.Site | Out-Null
            "CERTIFICATE UPDATED ON {0} WITH CERT $domain" -f $_.Site
        }
    }
}