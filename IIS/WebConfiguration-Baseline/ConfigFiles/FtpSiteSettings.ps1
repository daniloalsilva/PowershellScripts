<# Variable Definition #>

$IISRootPath = 'IIS:\'
$SiteName = '_ftp'
$PhysicalPath = 'C:\inetpub\ftproot'
$HostHeader = 'ftp.webfarmname.domain.tld'

$webConfig = @{
    
    <# FTP Authorization #>
    "system.ftpServer/security/authorization" = @{
        accessType = "Allow" 
        roles = ""
        permissions = "Read,Write"
        users="*"
    }
    
    <# FTP SSL Settings #>
    "system.applicationHost/sites/siteDefaults/ftpServer/security/ssl" = @{
        serverCertHash = (ls cert:\LocalMachine\My\* |? Subject -match "domain.tld").Thumbprint
        serverCertStoreName = 'My'
        controlChannelPolicy = 'SslRequireCredentialsOnly'
        dataChannelPolicy = 'SslAllow'
    }

    <# FTP Authentication #>
    "system.applicationHost/sites/siteDefaults/ftpServer/security/authentication/anonymousAuthentication" = @{
        enabled = $false
    }
    "system.applicationHost/sites/siteDefaults/ftpServer/security/authentication/basicAuthentication" = @{
        enabled = $true
        defaultLogonDomain = 'domain-net'
    }
}

<# Before exit, validate FTP site creation #>
if ((ls $IISRootPath\Sites | ? Name -eq $SiteName) -eq $null){
    New-WebFtpSite -Name $SiteName -Port "21" -HostHeader $HostHeader `
                   -PhysicalPath $PhysicalPath -IPAddress * -Force | Out-Null
}