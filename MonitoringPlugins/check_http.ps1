<#  
.SYNOPSIS  
    Request an url passed in parameters and returns a nagios code, acording with result

.DESCRIPTION
    The check_http.ps1 uses System.Net class to retrieve a http content
    Usage: check_http [options]:
        -url          - url to check (mandatory)
        -string       - string to search on requested http page
        -regex        - same as string parameter, but validate as a regex
        -usessl       - use this option to request an https page (accept fake certs)
        -showerrors   - if some error was generated, shows real .NET error
        -omitresponse - dont show http content
        -timeout      - define request timeout (default:30sec)
        -validateresponseqtd
                      - validate response, url content as integer (use | separator, ex: "warn|crit")
        -explode      - explode any errors encountered as critical

.NOTES  
    File Name      : check_http.ps1
    Author         : Danilo Silva - daniloalsilva@gmail.com
    Prerequisite   : PowerShell V2 or greater.
    Copyright 2014 - Danilo Silva/Locaweb

    CHANGELOG
        17/07/2014 : added -omitresponse and -regex
        21/07/2014 : Mandatory parameters removed to fix wrong exit code when using CmdledBindings
                     http://support.microsoft.com/kb/2552055

.EXAMPLE
    check_http.ps1 -url http://xxxxxx.github.com/f5.asp -string OK
    check_http.ps1 -url https://xxxxxx.github.com/monitoring -usessl
    check_http.ps1 -url https://xxxxxx.github.com/provisioning -validateresponseqtd "5|10"
#>

Param(
    [string]$url,
    [string]$string,
    [string]$regex,
    [switch]$usessl,
    [switch]$showerrors,
    [switch]$omitresponse,
    [switch]$explode,
    [int]$timeout,
    [string]$validateresponseqtd
)

$nagiosCodes = @{
    "OK" = 0;
    "Warning" = 1;
    "Critical" = 2;
    "Unknown" = 3;
}

# Configure 'critical' returnCode as default exit 
if ($explode){
    $returnCode = $nagiosCodes["Critical"]    
}
else {
    $returnCode = $nagiosCodes["Unknown"]
}

$returnMsg = ""

if ($timeout -eq $null){ $timeout = 30 }
try {Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Net;
using System.Net.Cache;
using System.Text;

public class HttpRequestHelper
{
    private string contentType;
    private string method;
    private int timeout;
    private string url;
    private string data;
    
    public HttpRequestHelper(string url, string method, string contentType, int timeout)
    {
        this.url = url;
        this.method = method;
        this.contentType = contentType;
        this.timeout = (timeout < 0x3e8) ? (timeout * 0x3e8) : timeout;
    }
    public HttpRequestHelper(string url, string method, string contentType, int timeout, string data)
    {
        this.url = url;
        this.method = method;
        this.contentType = contentType;
        this.timeout = (timeout < 0x3e8) ? (timeout * 0x3e8) : timeout;
        this.data = data;
    }

    public static HttpRequestHelper Create(string url, string method, string contentType, int timeout)
    {
        return new HttpRequestHelper(url, method, contentType, timeout);
    }
    public static HttpRequestHelper Create(string url, string method, string contentType, int timeout, string data)
    {
        return new HttpRequestHelper(url, method, contentType, timeout, data);
    }

    public string GetHttpResponse()
    {
        HttpWebResponse response = null;
        string message = null;
        try
        {   
            HttpWebRequest request = (HttpWebRequest) WebRequest.Create(this.url);
            request.ContentType = this.contentType;
            request.Method = this.method;
            request.Proxy = null;
            request.CachePolicy = new HttpRequestCachePolicy(HttpRequestCacheLevel.NoCacheNoStore);

            if (data != null)
            {
                byte[] buffer = Encoding.UTF8.GetBytes(data);
                request.ContentLength = buffer.Length;
                Stream requestStream = request.GetRequestStream();
                requestStream.Write(buffer, 0, buffer.Length);
                requestStream.Flush();
                requestStream.Close();
            }

            response = (HttpWebResponse) request.GetResponse();
            StreamReader reader = new StreamReader(response.GetResponseStream(), Encoding.ASCII);
            //message = String.Format("HTTP {0} - ", response.StatusCode) + reader.ReadToEnd();
            message = reader.ReadToEnd();
            reader.Close();
            reader.Dispose();
            response.Close();
        }
        catch (WebException exception)
        {
            throw exception;
        }
        catch (Exception exception2)
        {
            throw exception2;
        }
        return message;
    }
}
"@ -ErrorAction SilentlyContinue } catch { 
    "ERROR - CANNOT CALL WEBREQUEST METHODS" 
    if ($showerrors){ $Error[0].Exception }
    exit $returnCode
}

$url = [String]::Format($url,$env:COMPUTERNAME.ToLower())

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $usessl }

try { $response = [HttpRequestHelper]::Create($url,'GET','text/html',$timeout).GetHttpResponse() }
catch {
    "ERROR - INVALID HTTP REQUEST - $url"
    if ($showerrors){ $Error[0].Exception }
    exit $returnCode
}

if ($string -ne [String]::Empty){
    if ($response.Contains($string)){
        $returnMsg = "OK"
        $returnCode = $nagiosCodes["OK"]
    }
    else {
        $returnMsg = "ERROR - STRING $string NOT FOUND IN HTTP RESPONSE"
        $returnCode = $nagiosCodes["Critical"]
    }
}
elseif ($regex -ne [String]::Empty){
    if ($response -match $regex){
        $returnMsg = "OK"
        $returnCode = $nagiosCodes["OK"]
    }
    else {
        $returnMsg = "ERROR - REGEX $string NOT FOUND IN HTTP RESPONSE"
        $returnCode = $nagiosCodes["Critical"]
    }
}
elseif($validateresponseqtd -ne [String]::Empty -and [int]::TryParse($response, [ref]$response)){
    try {
        
        # validateresponseqtd variable validation
        $codes = $validateresponseqtd.Split("|")
        if ($codes.Count -lt 2){ 
            "Not enough parameters on -validateresponseqtd (min:2, '|' separator)"
            $returnCode = $nagiosCodes["Unknown"]
        }

        if ($response -ge [int]$codes[1]){
            $returnMsg = "CRITICAL - VALUE ON RESPONSE IS GREATER THAN $([int]$codes[1])"
            $returnCode = $nagiosCodes["Critical"]
        }
        elseif($response -ge [int]$codes[0]){
            $returnMsg = "WARNING - VALUE ON RESPONSE IS GREATER THAN $([int]$codes[0])"
            $returnCode = $nagiosCodes["Warning"]
        }
        elseif($response -lt [int]$codes[0]){
            $returnMsg = "OK"
            $returnCode = $nagiosCodes["OK"]  
        }
    }
    catch {
        "ERROR - SOMETHING IS WRONG ON -validateresponseqtd"
        $returnCode = $nagiosCodes["Unknown"]
    }
}

else {
    $returnMsg = "OK"
    $returnCode = $nagiosCodes["OK"]
}

if($omitresponse){
    "$returnMsg - $url"
}
else {
    "$returnMsg - RESPONSE: $response - $url"
}

exit $returnCode 

