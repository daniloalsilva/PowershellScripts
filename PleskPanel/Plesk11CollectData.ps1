function ExecuteQuery ($query){ 
    
    $pleskAdminTool = $env:plesk_cli + "\admin.exe"
    $user = '-uadmin'
    $pass = '-p' + (& $pleskAdminTool --show-password) 
    $mysql = $env:plesk_dir + "MySQL\bin\mysql.exe"
    & $mysql --skip-column-names $user -P8306 psa -e $query $pass

}

function CollectSpaceUsed ($path){
    if (Test-Path $path){ 
        $path = Get-Item $path -ErrorAction silentlycontinue
        $size=(dir $path -rec -force -ea silentlycontinue | measure-object length -sum -ErrorAction silentlycontinue).sum
        return [int]($size/1024/1024)
    }
    else { 0 }
}

function CollectComponents ($path){
    if (Test-Path $path){ 
        $path = Get-Item $path
        $files = ls $path -Recurse -Include "*.asp", "*.lib", "*.htaccess" -Force -ea silentlycontinue
        $files | % { 
            $_ = $_.FullName
            if ($_ -ne $null -and (Test-Path $_)){ 
                if($_ -match '.htaccess'){
                    @{$_ = "ISAPI REWRITE 3"}
                }
                else {
                    ValidateObjectCreation $_
                }
            }
        }
    }
    else { }
}

function ValidateObjectCreation ($file){
    try{
        $reader = [System.IO.File]::OpenText($file)
        $newline = $reader.ReadLine()
    }
    catch{
        Write-Warning "$file"
    }
    
    while ($newline){
        if($newline.ToLower().Contains('server.createobject')){
           @{$file = $newline.Trim()}
        }
        $newline = $reader.ReadLine()
    }
}

$login = Read-Host "Preencha o login que deseja consultar:"

# Collect DatabaseInfo

$databases = ExecuteQuery "select db.name as db_name, d.name as domain, db.type
from data_bases as db, domains as d, clients c
where db.dom_id = d.id 
and c.id = d.vendor_id
and c.login = '$login';"

$databases = $databases | % {
    $dbinfo = $_.Split()
    New-Object psobject -Property @{
        Database = $dbinfo[0];
        DomainOwner = $dbinfo[1];
        DatabaseType = $dbinfo[2];
    }
}

# Collect DomainInfo

$domains = ExecuteQuery "select d.name as domain
from domains as d, clients c
where c.id = d.vendor_id
and c.login = '$login';"

<#
$spaceUsed = $domains | % {
    $webSpaceUsed = 0
    $webSpaceUsed = CollectSpaceUsed "E:\vhosts\$_"

    $mailSpaceUsed = 0
    $mailSpaceUsed = CollectSpaceUsed "E:\Program Files (x86)\Parallels\Plesk\Mail Servers\Mail Enable\POSTOFFICES\$_"
    
    New-Object psobject -Property @{
        Domain = $_;
        "Web(MB)" = $webSpaceUsed;
        "Mail(MB)" = $mailSpaceUsed;
    }

    # Write-Host ("{0} | Web: {1}MB | Mail: {2}MB" -f $_, $webSpaceUsed, $mailSpaceUsed)
} #>

$spaceUsed = ExecuteQuery "select d.name as domain, du.mysql_dbases, du.mailboxes, du.httpdocs, SUM(dt.http_in), SUM(dt.http_out)
from domains as d, clients c, disk_usage du, domainstraffic dt
where c.id = d.vendor_id
and d.id = du.dom_id
and d.id = dt.dom_id
and dt.date > (DATE_ADD(CURDATE(), INTERVAL -30 DAY))
and c.login = '$login'
group by d.name;"

$spaceUsed = $spaceUsed | % {
    $duinfo = $_.Split()
    New-Object psobject -Property @{
        Domain = $duinfo[0];
        "MySQL (MB)" = "{0:N2}" -f ($duinfo[1] / 1MB);
        "MailBoxes (MB)" = "{0:N2}" -f ($duinfo[2] / 1MB);
        "Httpdocs (MB)" = "{0:N2}" -f ($duinfo[3] / 1MB);
        "HttpTraffic IN (MB)" = "{0:N2}" -f ($duinfo[4] / 1MB);
        "HttpTraffic OUT (MB)" = "{0:N2}" -f ($duinfo[5] / 1MB);
    }
}


# Collect ComponentsInfo 

$components = $domains | % {
    CollectComponents "E:\vhosts\$_"
}

$components | Out-GridView
$spaceUsed | Out-GridView
$databases | Out-GridView

read-host 

