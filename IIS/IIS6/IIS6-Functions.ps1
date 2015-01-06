Function Get-Websites ([string]$siteName){

    # Validate if namespace existsbefore starting
    if ((Get-WmiObject -Class 'IISWebServerSetting' -List -Namespace 'root\MicrosoftIISv2' -ErrorAction SilentlyContinue) -eq $null){
        Write-Warning -Message "Required Namespace/Class not found."
        break
    }

    # Validate if an specific website was requested
    if ([String]::IsNullOrEmpty($siteName)){
        $Websites  = gwmi -namespace "root\MicrosoftIISv2" -class "IISWebServerSetting"
    }
    else {
        $Websites  = gwmi -namespace "root\MicrosoftIISv2" -class "IISWebServerSetting" -filter "ServerComment = '$siteName'"
    }

    if ($Websites -eq $null){
        Write-Warning -Message "Website $siteName not found."
    }
    else {
        # Start Execution
        $Websites | % {
            
            $siteName = $_.ServerComment
            
            $bindings = $_.ServerBindings
            foreach ($binding in $bindings)
            {
                New-Object PSObject -Property @{
                    Type = "HTTP"
                    SiteName = $siteName
                    Hostname = $binding.Hostname
                    IP = $binding.IP
                    Port = $binding.Port
                }
            }

            $securebindings = $_.SecureBindings
            foreach ($sbinding in $securebindings)
            {
                if(![String]::IsNullOrEmpty($sbinding.Port)){
                    New-Object PSObject -Property @{
                        Type = "HTTPS"
                        SiteName = $siteName
                        Hostname = $sbinding.Hostname
                        IP = $sbinding.IP
                        Port = $sbinding.Port
                    }
                }
            }   
        }
    }
}
"Function Get-Websites loaded."