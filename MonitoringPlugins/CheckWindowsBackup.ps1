<#  
.SYNOPSIS  
    Script utilizado para validar a execução do Windows Backup.
    
.NOTES  
    File Name      : CheckWindowsBackup.ps1
    Author         : Danilo Silva - daniloalsilva@gmail.com
    Prerequisite   : PowerShell V2 ou superiores.
                   : PSSnapin Windows.ServerBackup
    Copyright 2013 - Danilo Silva

#>
# Codigos de retorno para a monitoracao

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
    Add-PSSnapin Windows.ServerBackup
    $summary = Get-WBSummary

    $lastBackup = $summary.LastSuccessfulBackupTime
    if(((Get-Date) - $lastBackup).Days -ge 2){
        $statusCode = $statusCodes['Critical']
        $statusMsg = 'Critical'
    }
    elseif(((Get-Date) - $lastBackup).Days -ge 1 -and ((Get-Date) - $lastBackup).Hours -ge 1){
        $statusCode = $statusCodes['Warning']
        $statusMsg = 'Warning'
    }
    elseif(((Get-Date) - $lastBackup).Days -eq 0){
        $statusCode = $statusCodes['OK']
        $statusMsg = 'OK'
    }
    
    "$statusMsg - Last Backup: $($lastBackup.ToString("dd/MM/yyyy - HH:mm:ss")) - Backup Status: $($summary.CurrentOperationStatus) - Last Backup Drive: $($summary.LastBackupTarget) - TotalBackups: $($summary.NumberOfVersions)"
    exit $statusCode
}
catch{
    "$statusMsg - Ops, algo esta errado, ErrorMsg: "+ $Error[0]
    exit $statusCode
}