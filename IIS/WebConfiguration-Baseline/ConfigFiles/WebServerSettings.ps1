<# Starting Configuration Definitions #>
@{ 

    <# ASP CLASSIC #>
    "system.webserver/asp" = @{
        enableParentPaths = $true
        runOnEndAnonymously = $false
        scriptErrorSentToBrowser = $true
        lcid = 1046
    } 
    'system.webserver/asp/comPlus' = @{
        executeInMta = $true
    }
    'system.webserver/asp/limits' = @{
        maxRequestEntityAllowed = 500000
    }

    <# LOGGING #>
    'system.applicationhost/sites/sitedefaults/logfile' = @{
        logExtFileFlags = 'Date,Time,ClientIP,UserName,SiteName,ComputerName,ServerIP,Method,UriStem,UriQuery,HttpStatus,Win32Status,BytesSent,BytesRecv,TimeTaken,ServerPort,UserAgent,Cookie,Referer,ProtocolVersion,Host,HttpSubStatus'
        logFormat = 'W3C'
        directory = 'L:\LogFiles'
        period = 'Daily'
    }
    'system.applicationHost/log' = @{
        logInUTF8 = $false
        centralLogFileMode = 'Site'
    }

    <# ERRORS #>
    "system.webServer/httpErrors" = @{
        errorMode = 'Detailed'
    }

    <# AUTHENTICATION #>
    # note: setting username to 'empty string' changes anonymousAuthentication 
    # to "Application Pool Identity"
    'system.webServer/security/authentication/anonymousAuthentication' = @{
        enabled = $true
        userName = ""
    }
    'system.webServer/security/authentication/windowsAuthentication' = @{
        enabled = $false
    }
    'system.webServer/security/authentication/basicAuthentication' = @{
        enabled = $true
        defaultLogonDomain = 'domain-net'
    }
    'system.webServer/security/authentication/digestAuthentication' = @{
        enabled = $false
    }
    'system.webServer/security/authentication/iisClientCertificateMappingAuthentication' = @{
        enabled = $false
    }
    'system.webServer/security/authentication/clientCertificateMappingAuthentication' = @{
        enabled = $false
    }
    
    <# APPLICATION POOLS #>
    'system.applicationHost/applicationPools/applicationPoolDefaults' = @{
        managedRuntimeVersion = 'v4.0'
        enable32BitAppOnWin64 = $true
        queueLength = 5000
        managedPipelineMode = 'Integrated'
        startMode = 'OnDemand'
    }
    'system.applicationHost/applicationPools/applicationPoolDefaults/processModel' = @{
        identityType = 'ApplicationPoolIdentity'
        loadUserProfile = $true
    }
    'system.applicationHost/applicationPools/applicationPoolDefaults/recycling' = @{
        disallowOverlappingRotation = $true
        disallowRotationOnConfigChange = $true
    }
}
<# End Configuration Definitions #>