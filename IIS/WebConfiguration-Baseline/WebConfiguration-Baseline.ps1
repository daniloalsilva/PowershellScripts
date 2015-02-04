<#
.SYNOPSIS
    Sets a IIS Baseline Configuration, needed for a specific server type

.DESCRIPTION
    The WebConfiguration-Baseline contains several configuration values, 
    defined as "needed" for a specific server type.
    The Script was designed to serve as an configuration file
    and can easily be changed or receive adictions according with need.

    By default, script will try to find a directory called "ConfigFiles" 
    on the same level as the Script, and the specified config file on this directory.

    The config file contains a series of hash tables, that uses IIS Path as 
    the key for it's dictonary. After load config file, the object will be inputed 
    on IIS, changing all described configurations or creating news

.NOTES  
    File Name      : WebConfiguration-Baseline.ps1
    Author         : Danilo Silva - daniloalsilva@gmail.com
    Prerequisite   : PowerShell V2 or greater.
                   : PSModule WebAdministration
    Copyright 2015 - Danilo Silva

#>

Param (
    [string]$configFile,
    [string]$location
)

# changes Powershell to x64, if it was started on x86
if ($pshome -like "*syswow64*") {
	write-warning "Restarting script under 64 bit powershell"
	& (join-path ($pshome -replace "syswow64", "sysnative") powershell.exe) -file `
		(join-path $psscriptroot $myinvocation.mycommand) @args
	exit
}

# start logging script execution
Start-Transcript -Path "$($env:SystemRoot)\Logs\$($PSCommandPath.Split('\')[-1]).log" -Append

<# Variable Definition #>
$ErrorActionPreference = "Stop";
$IISRootPath = "IIS:\"
$installationRoot = "$((ls $PSCommandPath).Directory.FullName)"
$configurationFilePath = "$installationRoot\ConfigFiles\$configFile"

<# Import WebAdministration Module #>
Import-Module WebAdministration

<# Stops script execution if config file not exists #>
if (($configFile -eq $null) -or !(Test-Path $configurationFilePath)){
    throw "Configuration file does not exists"
}

<# DefineConfiguration functions, change it as needed #>
<#
# this function works like function below, but sets each property individually
Function DefineConfiguration ($iisPath, $iisConfig){
    foreach ($config in $iisConfig.Keys){
        Set-WebConfigurationProperty $iisPath -Name $config -Value $iisConfig[$config]
    }
}
# this function works better to input objects with many properties
Function DefineConfiguration ($iisPath, $iisConfig){
    $iisSettings = Get-WebConfiguration $IISRootPath -Filter $iisPath
    foreach ($config in $iisConfig.Keys){
        $iisSettings.$config = $iisConfig[$config]
    }
    $iisSettings | Set-WebConfiguration -PSPath $IISRootPath -Filter $iisPath
}
#>

<# Loading function DefineConfiguration #>
# this function works like functions on top, but only this creates new "WebConfigurations"
Function DefineConfiguration ($iisPath, $iisConfig){
    Set-WebConfiguration $iisPath -Value $iisConfig -PSPath $IISRootPath -Location $location
}

<# Loading Configuration File #>
$webConfig = Invoke-Expression $configurationFilePath

# foreach IIS "path", calls function 'DefineConfiguration'
foreach ($attr in $webConfig.Keys){
    DefineConfiguration $attr $webConfig[$attr] 
}

# stop logging script execution
Stop-Transcript