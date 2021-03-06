<#  
.SYNOPSIS  
    Script utilizado para iniciar uma execução assincrona BareMetal do Windows Backup e manutenção da rotina de Backup

.DESCRIPTION
    Script utilizado para iniciar uma execução assincrona BareMetal do Windows Backup e manutenção da rotina de Backup
    Parâmetros mandatórios: 
        WBKeptCount - Quantidade de Backups mantidos, antes da execução 
        WBTargetDrive - Drive utilizado como output do Backup

    Fontes de consulta:
    http://technet.microsoft.com/pt-br/library/ee849849(v=ws.10).aspx
    http://technet.microsoft.com/en-us/library/ee706683.aspx
    http://technet.microsoft.com/en-us/library/jj902428.aspx
    http://blogs.technet.com/b/filecab/archive/2009/06/22/backup-version-and-space-management-in-windows-server-backup.aspx
    http://blogs.technet.com/b/filecab/archive/2008/05/21/what-is-the-difference-between-vss-full-backup-and-vss-copy-backup-in-windows-server-2008.aspx

    Commandline utilizada para executar um Baremetal Backup sem utilizar Powershell:
    %windir%\System32\wbadmin.exe start backup -backupTarget:F: -allCritical -systemState -vssCopy -quiet

.NOTES  
    File Name      : WindowsBackupBareMetal.ps1
    Author         : Danilo Silva - daniloalsilva@gmail.com
    Prerequisite   : PowerShell V2 ou superiores.
                   : Ferramenta do Windows diskshadow.exe
                   : PSSnapin Windows.ServerBackup
    Copyright 2013 - Danilo Silva

.EXAMPLE
    WindowsBackupBareMetal.ps1 -WBKeptCount 3 -WBTargetDrive 'F:'
#>

Param (
   [Parameter(Mandatory=$True)]
   [int]$WBKeptCount,
   
   [Parameter(Mandatory=$True)]
   [string]$WBTargetDrive,

   [int]$retryInterval
)

function InitiateWBackup (){
    $WBPolicy = New-WBPolicy
    $WBVolume = Get-WBVolume $WBTargetDrive
    $WBTarget = New-WBBackupTarget -Volume $WBVolume
    Add-WBBareMetalRecovery -Policy $WBPolicy
    Add-WBBackupTarget -Policy $WBPolicy -Target $WBTarget | Out-Null
    Add-WBSystemState -Policy $WBPolicy 
    Set-WBVssBackupOptions -Policy $WBPolicy -VssCopyBackup
    Start-WBBackup -Policy $WBPolicy -Async
    "Bare Metal Backup started."

    $WBBackupSet = Get-WBBackupSet

    if($WBBackupSet.Count -gt $WBKeptCount){
        $WBBackupNotKept = $WBBackupSet | select -First ($WBBackupSet.Count - $WBKeptCount) | % { $_.SnapshotId.Guid }
        $DiskShadowScript = (Get-Location).Path + '\DiskShadowScript.dsh'
        if(Test-Path $DiskShadowScript){ Remove-Item $DiskShadowScript }
        New-Item -Path $DiskShadowScript -ItemType file | Out-Null
        $WBBackupNotKept | % { Add-Content -Path $DiskShadowScript -Value "DELETE SHADOWS ID {$_}" }
        & diskshadow.exe /s $DiskShadowScript
    }
}

try {
    
    Add-PSSnapin Windows.ServerBackup
    
    # Validate if some operation is in progress before start a new operation
    $summary = Get-WBSummary
    "CurrentOperationStatus : $($summary.CurrentOperationStatus)" 

    switch($summary.CurrentOperationStatus){
        'BackupInProgress' { $continueBackup = $false }
        'NoOperationInProgress' { $continueBackup = $true }
        default { $continueBackup = $false }
    }

    if ($retryInterval -ne $null -and $retryInterval -ne 0 -and $continueBackup){
        
        $lastSuccessfulBackupTime = (Get-WBSummary).LastSuccessfulBackupTime
        $backupInterval = New-TimeSpan -Start $lastSuccessfulBackupTime -End (Get-Date)

        if ($backupInterval.TotalHours -gt $retryInterval -and (Get-Date).Date -ne $lastSuccessfulBackupTime.Date){
            #InitiateWBackup
        }
        else {
            Write-Warning "The last Successful Backup was executed $([int]$backupInterval.TotalHours) hours ago."
            Write-Warning "If you still want to execute Windows Backup, omit -retryInterval option."
        }
    }
    elseif($continueBackup) {
        #InitiateWBackup
    }
    else {
        "Backup will not start because of CurrentOperationStatus"
    }
}

catch {
    #Write-EventLog -LogName Application -Source "CT-Windows Plugins" -EntryType Error -EventId 1 -Message "An error occurred on WindowsBackupBareMetal : $($Error[0].Message)"
    $Error[0]
}

