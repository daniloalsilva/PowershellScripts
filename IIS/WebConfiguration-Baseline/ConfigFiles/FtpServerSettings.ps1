<# Starting Configuration Definitions #>
@{

    <# FTP Authentication #>
    "system.applicationHost/sites/siteDefaults/ftpServer/security/authentication/anonymousAuthentication" = @{
        enabled = $false
    }
    "system.applicationHost/sites/siteDefaults/ftpServer/security/authentication/basicAuthentication" = @{
        enabled = $true
        defaultLogonDomain = 'domain-net'
    }

    <# FTP Authorization #>
    "system.ftpServer/security/authorization" = @{
        accessType = "Allow" 
        roles = ""
        permissions = "Read,Write"
        users="*"
    }

    <# FTP Directory Browsing #>
    "system.applicationHost/sites/siteDefaults/ftpServer/directoryBrowse" = @{
        showFlags = 'StyleUnix'
    }

    <# FTP Firewall Support #>
    "system.ftpServer/firewallSupport" = @{
        lowDataChannelPort = 60000
        highDataChannelPort = 61000
    }

    <# FTP Logging #>
    "system.ftpServer/log" = @{
        centralLogFileMode = 'Site'
        logInUTF8 = $false
    }
    "system.ftpServer/log/centralLogFile" = @{
        logExtFileFlags = 'Date,Time,ClientIP,UserName,ServerIP,Method,UriStem,FtpStatus,Win32Status,ServerPort,FtpSubStatus,Session,FullPath'
        period = 'Daily'
        directory = 'L:\FtpLogFiles'
    }

    <# FTP Logon Attempt Restrictions #>
    "system.ftpServer/security/authentication/denyByFailure" = @{
        enabled = $true
        maxFailure = 15
        entryExpiration = "00:05:00"
        loggingOnlyMode = $false
    }

    <# FTP SSL Settings #>
    "system.applicationHost/sites/siteDefaults/ftpServer/security/ssl" = @{
        serverCertHash = (ls cert:\LocalMachine\My\* |? Subject -match "domain.tld").Thumbprint
        serverCertStoreName = 'My'
        controlChannelPolicy = 'SslRequireCredentialsOnly'
        dataChannelPolicy = 'SslAllow'
    }

    <# FTP Messages #>
    "system.applicationHost/sites/siteDefaults/ftpServer/messages" = @{
        exitMessage = 'Thanks for use FTP!'
        greetingMessage = 'Hail! Welcome to FTP!'
        allowLocalDetailedErrors = $true
    }
}
<# End Configuration Definitions #>