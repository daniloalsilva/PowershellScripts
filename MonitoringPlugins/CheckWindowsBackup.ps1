<#  
.SYNOPSIS  
    Script used to validate Windows Backup execution
    
.NOTES  
    File Name      : CheckWindowsBackup.ps1
    Author         : Danilo Silva - daniloalsilva@gmail.com
    Prerequisite   : PowerShell V2 or greater.
                   : PSSnapin Windows.ServerBackup
    Copyright 2013 - Danilo Silva

#>
# Monitoring return codes

$statusCodes = @{
"OK" = 0;
"Warning" = 1;
"Critical" = 2;
"Unknown" = 3;
}

# Initial Stats
$statusCode = $statusCodes['Unknown']
$statusMsg = "Unknown"

try{
    # Load Windows.ServerBackup
    Add-PSSnapin Windows.ServerBackup
    
    # Validate the last successful backup and store his time
    $lastSuccessfulBackupTime = (Get-WBSummary).LastSuccessfulBackupTime

    # If the last backup has run for more than two days, explode an critical
    if(((Get-Date) - $lastSuccessfulBackupTime).Days -ge 2){
        $statusCode = $statusCodes['Critical']
        $statusMsg = 'Critical'
    }

    # If the last backup has run for more than one day and one hour, explode an warning
    # this one more hour was considered for actual execution backup
    elseif(((Get-Date) - $lastSuccessfulBackupTime).Days -ge 1 -and ((Get-Date) - $lastSuccessfulBackupTime).Hours -ge 1){
        $statusCode = $statusCodes['Warning']
        $statusMsg = 'Warning'
    }
    <#
        NEED VALIDATE THE HOUR USED DURING BACKUP EXECUTION
    #>

    elseif(((Get-Date) - $lastSuccessfulBackupTime).Days -eq 0){
        $statusCode = $statusCodes['OK']
        $statusMsg = 'OK'
    }
    
    "$statusMsg - O ultimo Windows Backup foi executado em: " + $lastSuccessfulBackupTime.ToString("dd/MM/yyyy - hh:mm:ss")
    exit $statusCode
}
catch{
    "$statusMsg - Ops, algo esta errado, ErrorMsg: "+ $Error[0]
    exit $statusCode
}