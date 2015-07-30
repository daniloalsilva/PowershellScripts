function pstelnet ([Parameter(Mandatory=$true)][string] $remoteHost, [Parameter(Mandatory=$true)][int] $port, [string[]] $commands){
    try { ## Open the socket, and connect to the computer on the specified port
        # write-host "Connecting to $remoteHost on port $port"
        $socket = new-object System.Net.Sockets.TcpClient($remoteHost, $port)

        if($socket -eq $null) {
            throw ("Could Not Connect")
        }

        $stream = $socket.GetStream() 
        $writer = new-object System.IO.StreamWriter($stream)

        $buffer = new-object System.Byte[] 1024
        $encoding = new-object System.Text.AsciiEncoding

        #Loop through $commands and execute one at a time.

        for($i=0; $i -lt $commands.Count; $i++) { ## Allow data to buffer for a bit start-sleep -m 500

            ## Read all the data available from the stream, writing it to the ## screen when done.
            while($stream.DataAvailable) {
                $read = $stream.Read($buffer, 0, 1024)
                write-host -n ($encoding.GetString($buffer, 0, $read))
            }

            write-host $commands[$i]
            ## Write the command to the remote host
            $writer.WriteLine($commands[$i]) 
            $writer.Flush()
        }

        if($LASTEXITCODE -eq 0) {
            # If string wasnt found then an error is thrown and caught
            throw ("Text Not found")
        }
        new-object psobject -prop @{
            Host = $remoteHost
            Port = $port
            ConnectionResult = "OK"
        }
    }

    catch {

        #When an exception is thrown catch it and output the error.
        #this is also where you would send an email or perform the code you want when its classed as down.
        <#
        write-host $error[0]
        $dateTime = get-date
        $errorOccurence = "Error occurred connecting to $remoteHost on $port at $dateTime"
        write-host $errorOccurence
        #>
        new-object psobject -prop @{
            Host = $remoteHost
            Port = $port
            ConnectionResult = "Error"
        }
    }

    finally {
        ## Close the streams
        ## Cleans everything up.
        $writer.Close()
        $stream.Close()
    }
}