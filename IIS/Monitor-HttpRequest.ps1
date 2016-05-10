<#  
.SYNOPSIS  
    Gets the currently web requests of IIS from logs to retrieve http requests 

.DESCRIPTION
    The Monitor-WebRequest.ps1 uses PSModule WebAdministration to retrieve configurated log path.
    The Script will keep all logfiles with LastWrite equal actual day openned and "Tail" it.
    Data will be collected every 1000msec and a summary will be displayed on console during data collection.
    After passed specified time collecting data, an GridView will pop-up with data collection result.
    
    Usage: Monitor-WebRequest [options]:
        -secondsToMonitor  - time in seconds to keep executing and collectng data

.NOTES  
    File Name      : Monitor-HttpRequest.ps1
    Author         : Danilo Silva - daniloalsilva@gmail.com
    Prerequisite   : PowerShell V2 or greater.
                   : Windows Server 2008 or greater
                   : PSModule WebAdministration
    Copyright 2015 - Danilo Silva

.EXAMPLE
    Monitor-HttpRequest.ps1 -secondsToMonitor 60
    
#>

Param(
    [Parameter(Mandatory=$true)]
    [int]$secondsToMonitor
)

Import-Module WebAdministration

$counter = 0
$sites = ls IIS:\Sites
$logFiles = foreach ($site in $sites){
    Write-Progress -PercentComplete ($counter * 100 / $sites.Count) -Activity "Collecting websites log paths..." -Status "Opening $counter of $($sites.Count)"
    $dirlog = ls "$($site.logFile.directory)\W3SVC$($site.ID)" -ErrorAction SilentlyContinue
    if ($dirlog -ne $null){
        $dirlog | %{
            if($_.LastWriteTime.Date -eq (Get-Date).Date){
                $_.FullName
            }
        }
    }
    $counter++
}

$reader = @{}
$lastMaxOffset = @{}

$counter = 0
foreach($log in ($logFiles | select -Unique)){
    Write-Progress -PercentComplete ($counter * 100 / $logFiles.Count) -Activity "Opening log files..." -Status "Opening $counter of $($logFiles.Count)"
    $reader[$log] = new-object System.IO.StreamReader(New-Object IO.FileStream($log, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [IO.FileShare]::ReadWrite))
    $lastMaxOffset[$log] = $reader[$log].BaseStream.Length
    $counter++
}

$elapsed = [System.Diagnostics.Stopwatch]::StartNew()

$output = while ($elapsed.Elapsed.TotalSeconds -lt $secondsToMonitor){

    Write-Progress -PercentComplete ($elapsed.Elapsed.TotalSeconds * 100 / $secondsToMonitor) -Activity "Opening log files..." -Status "Collecting data, elapsed time: $($elapsed.Elapsed.TotalSeconds) of $secondsToMonitor"
    foreach($log in ($logFiles | select -Unique)){

        if ($reader[$log].BaseStream.Length -eq $lastMaxOffset[$log]) {
            continue;
        }

        $reader[$log].BaseStream.Seek($lastMaxOffset[$log], [System.IO.SeekOrigin]::Begin) | out-null

        $line = ""
        while (($line = $reader[$log].ReadLine()) -ne $null) {
            $lineSplitted = $line.Split()
            
            new-object psobject -Property @{
                "date" = $lineSplitted[0]
                "time" = $lineSplitted[1]
                "s-sitename" = $lineSplitted[2]
                "s-computername" = $lineSplitted[3]
                "s-ip" = $lineSplitted[4]
                "cs-method" = $lineSplitted[5]
                "cs-uri-stem" = $lineSplitted[6]
                "cs-uri-query" = $lineSplitted[7]
                "s-port" = $lineSplitted[8]
                "cs-username" = $lineSplitted[9]
                "c-ip" = $lineSplitted[10]
                "cs-version" = $lineSplitted[11]
                "cs(User-Agent)" = $lineSplitted[12]
                #"cs(Cookie)" = $lineSplitted[13]
                "cs(Referer)" = $lineSplitted[14]
                "cs-host" = $lineSplitted[15]
                "sc-status" = $lineSplitted[16]
                "sc-substatus" = $lineSplitted[17]
                "sc-win32-status" = $lineSplitted[18]
                "sc-bytes" = $lineSplitted[19]
                "cs-bytes" = $lineSplitted[20]
                "time-taken"= $lineSplitted[21]
            }
        }
        
        $lastMaxOffset[$log] = $reader[$log].BaseStream.Position
    }
    sleep -m 1000
}

$output |  Out-GridView
# $output | group 'cs-host' | sort Count