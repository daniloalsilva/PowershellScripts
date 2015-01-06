<#
.EXAMPLES
    ArchiveFiles.ps1 -originpath F:\log -destpath F:\log -extension *.txt, *.log -removeAfterZip
    ArchiveFiles.ps1 -originpath F:\log -destpath E:\archive -extension *.log -removeAfterZip
#>

Param(
    [Parameter(Mandatory=$True,Position=1)]
    [string]$originpath,
	
    [Parameter(Mandatory=$True)]
    $extension,
    
    [Parameter(Mandatory=$True)]
    [string]$destpath,

    [switch]$removeAfterZip

)

function Zip-Files ($files, $output){
 
    $7zip = 'C:\Program Files\7-Zip\7z.exe'
    & $7zip a -t7z -y -bd $output $files
}

$nowDate = Get-Date

if ((Test-Path $originpath) -and (Test-Path $originpath)){ 
    $filelist = ls -Recurse $originpath -Include $extension | ? {$_.LastWriteTime.Month -lt $nowDate.Month }

    if ($filelist -ne $null){
        $output = "$destpath\archived_$($nowDate.AddMonths(-1).ToString('yyyyMMdd'))"
        Zip-Files ($filelist).FullName $output
        
        if ($removeAfterZip){
            $filelist | Remove-Item -Force
        }
    }
}