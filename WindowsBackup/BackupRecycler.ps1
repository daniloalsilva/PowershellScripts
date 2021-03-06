<#  
.NOTES  
    File Name      : BackupRecycler.ps1
    Author         : Danilo Silva - daniloalsilva@gmail.com
    Prerequisite   : PowerShell V2 or greater.
                   : diskshadow.exe Windows tool
                   : PSSnapin Windows.ServerBackup

.EXAMPLE
    BackupRecycler.ps1 -WBKeptCount 3
#>

Param (
   [Parameter(Mandatory=$True)]
   [int]$WBKeptCount
)


try {
    
    Add-PSSnapin Windows.ServerBackup

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

catch {
    Write-EventLog -LogName Application -Source "CT-Windows Plugins" -EntryType Error -EventId 1 -Message "An error occurred on BackupRecycler : $($Error[0].Message)"
    $Error[0]
}

