<#  
.SYNOPSIS  
    Gets the currently web requests of IIS to retrieve 

.DESCRIPTION
    The Monitor-WebRequest.ps1 uses PSModule WebAdministration to retrieve http requests 
    that are currently being executed.
    Data will be collected every 500msec and a summary will be displayed on console during data collection.
    After passed specified time collecting data, an GridView will pop-up
    with data collection result.
    
    Usage: Monitor-WebRequest [options]:
        -secondsToMonitor  - time in seconds to keep executing and collectng data

.NOTES  
    File Name      : Monitor-WebRequest.ps1
    Author         : Danilo Silva - daniloalsilva@gmail.com
    Prerequisite   : PowerShell V2 or greater.
                   : Windows Server 2008 or greater
                   : PSModule WebAdministration
    Copyright 2015 - Danilo Silva

.EXAMPLE
    Monitor-WebRequest.ps1 -secondsToMonitor 10
    
#>

Param(
    [Parameter(Mandatory=$true)]
    [int]$secondsToMonitor
)

Import-Module WebAdministration
$output = @()
$elapsed = [System.Diagnostics.Stopwatch]::StartNew()
$ErrorActionPreference = "Stop";

while ($elapsed.Elapsed.TotalSeconds -lt $secondsToMonitor) {
    
    $var = $null
    while ($var -eq $null){
        sleep -Milliseconds 100
        $var = Get-WebRequest -ErrorAction SilentlyContinue
    }
    
    # Removing duplicated request entries 
    foreach ($newline in $var){
        $notfound = $true
        foreach ($line in $output){
            if ($newline.requestId -eq $line.requestId){
                $line = $newline
                $notfound = $false
            }
        }
        if ($notfound){
            $output += $newline
        }
    }
    
    # Creating a real-time display for requests
    $table = @{}
    $output | % {
        $table[$_.hostName] += 1
    }
    
    # Older method, display on screen duplicated requests
    #$var | % {
    #    $table[$_.hostName] += 1
    #}
    
    $table['TOTALREQUEST'] = 0
    $table['TOTALREQUEST'] = ($table.Values | measure -Sum).sum
    
    clear
    $table.GetEnumerator() | sort Value -Descending | select -First 20 
    sleep -Milliseconds 500

}

$output | Out-GridView