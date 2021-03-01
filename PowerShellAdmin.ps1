#don't forget to rename this file to .ps1 for powershell use!
$serviceName1 = "Service01.Name" #name your services here
$serviceName2 = "Service02.Name"
$computerNames = @("server01", "server02") #your list of server(s) 
$emailAll = "emailGroup1@company.com, emailGroup2@company.com"
$emailGroupOne = "emailGroup1@company.com"
$serviceSleepTime = 120 #in seconds
$rebootSleepTime = 60 #in seconds
$timeoutRetrySleepTIme = 60 #in seconds
$username = "adminLogin"
$password = "adminPassword"
$returnValue = 0
$failedServerCount = 0
$logFileExpiration = 120 #delete log files older than N days
$logFilePath = "C:\LogFilePath\logs"
$smtpServer = "your.smtp.server"

function New-Credentials{
    param(
        $username,
        $password
    )
    
    #Convert a non securestring to a securestring.
    if (-Not($password -is [System.Security.SecureString])){
        $password = ConvertTo-SecureString -AsPlainText -Force -String $password
    }    
    
    return New-Object System.Management.Automation.PSCredential($username,$password)
}

function Start-RemoteService{
    param(
        $serviceName, 
        $computerName, 
        $credentials
    )
    
    try{

        #WMI can generate non-terminating errors, but we want them to be terminating.
        $local:ErrorActionPreference = "Stop"
        
        #Splattable parameter table.
        $Wmi_Params = @{
            ComputerName = $computerName
            Query = "SELECT * FROM Win32_Service WHERE name='$serviceName'"
            Namespace = "root/CIMv2"
            Credential = $credentials
        }

		Write-Host "Starting $serviceName on $computerName`r`n"
        
        #Get the service.
        $RemoteService = Get-WmiObject @Wmi_Params
        
        if ($RemoteService){
            $CommandResult = $RemoteService.StartService()
			Write-Host "Remote Service`r`n"
			$RemoteService
			Write-Host "Command Result:`r`n"
			$CommandResult
			if ($CommandResult.ReturnValue -eq 7){
                Write-Host "Timeout was reached on $computerName, waiting 60 seconds and trying to start $serviceName again...`r`n"
				Start-Sleep -s $timeoutRetrySleepTIme
				Write-Host "Resuming start of $serviceName on $computerName after addditional wait...`r`n"
				
				$CommandResult = $RemoteService.StartService()
				Write-Host "Remote Service`r`n"
				$RemoteService
				Write-Host "Command Result:`r`n"				
				$CommandResult
				
				if ($CommandResult.ReturnValue -ne 0){
					Write-Host -foregroundcolor "Red" "ERROR: Sevice wouldn't start after timeout handling! ReturnValue is $($CommandResult.ReturnValue) http://msdn.microsoft.com/en-us/library/aa393660(v=vs.85).aspx`r`n"
					$returnValue = 1
					break
				}
            }
			if ($CommandResult.ReturnValue -ne 0){
				Write-Host -foregroundcolor "Red" "ERROR: Non timout related error starting sevice! ReturnValue is $($CommandResult.ReturnValue) http://msdn.microsoft.com/en-us/library/aa393660(v=vs.85).aspx`r`n"
				$returnValue = 1
				break
			}
        }
    }
    catch{
        throw $_
    }
    finally{
        $local:ErrorActionPreference = "Continue"
    }
}

function Stop-RemoteService{
    param(
        $serviceName, 
        $computerName, 
        $credentials
    )
    
    try{
        #WMI can generate non-terminating errors, but we want them to be terminating.
        $local:ErrorActionPreference = "Stop"
        
        #Splattable parameter table.
        $Wmi_Params = @{
            ComputerName = $computerName
            Query = "SELECT * FROM Win32_Service WHERE name='$serviceName'"
            Namespace = "root/CIMv2"
            Credential = $credentials
        }

	$WMIHostname = Get-WmiObject -Class Win32_ComputerSystem -computername $computerName
	Write-Host "Stopping $serviceName on $computerName`r`n"
        
        #Get the service.
        $RemoteService = Get-WmiObject @Wmi_Params
        
        if ($RemoteService){
			if ($RemoteService.State -eq "Running"){
				$CommandResult = $RemoteService.StopService()							
				if ($CommandResult.ReturnValue -ne 0){
					Write-Host -foregroundcolor "Red" "Error stopping sevice! ReturnValue is $($CommandResult.ReturnValue) http://msdn.microsoft.com/en-us/library/aa393673(v=vs.85).aspx`r`n"
					Write-Host "Remote Service`r`n"
					$RemoteService
					Write-Host "Command Result:`r`n"				
					$CommandResult
					break
				}
			} else {
				Write-Host "    $serviceName is" $RemoteService.State "rather than Running on $computerName and no action was taken`r`n"
			}
        }
    }
    catch{
        throw $_
    }
    finally{
        $local:ErrorActionPreference = "Continue"
    }
}

function Reboot-RemoteMachine{
    param(
        $computerName, 
        $credentials
    )
    
    try{
        #WMI can generate non-terminating errors, but we want them to be terminating.
        $local:ErrorActionPreference = "Stop"
        $Wmi_Params = @{
            ComputerName = $computerName
            Class = "Win32_OperatingSystem"
            Namespace = "root/CIMv2"
            Credential = $credentials
        }
        
		Write-Host "Rebooting $computerName`r`n"

        $OperatingSystem = Get-WmiObject @Wmi_Params
        if ($OperatingSystem){
            $OperatingSystem.Reboot()
        }
    }
    catch{
        throw $_
    }
    finally{
        $local:ErrorActionPreference = "Continue"
    }
}

function Check-RemoteMachine{
    param(
        $computerName,
        $credentials
    )

    $ping = New-Object System.Net.NetworkInformation.Ping
    $timeout = "300"

    Write-Host "Checking $computerName`r`n"

    #Wait for the system to stop replying to ping requests.
    try{
        $local:ErrorActionPreference = "Stop"
        for ($i = 0; $i -lt $timeout; $i++){
            if ($ping.Send($computerName).Status -eq "Success"){
                Start-Sleep 1
            }
            else{
                break
            }
        }
    }
    catch{
        #It's expected that when the server stops responding, it will throw an exception.
    }
    finally{
        $local:ErrorActionPreference = "Continue"
    }
    
    
    #Setup another loop to wait for the ping requests to start responding again. 
    #We're hiding non terminating errors because they are expected.
    for ($i = 0; $i -lt $timeout; $i++){
        $local:ErrorActionPreference = "SilentlyContinue"
        if ($ping.Send($computerName).Status -eq "Success"){
            break
        }
        else{
            Start-Sleep 2
        }
    }
    
    $local:ErrorActionPreference = "Continue"
    if ($i -ge ($timeout-1)){
        throw "Unable to ping machine after $timeout seconds!"
    }
    
    #This last loop waits until WMI starts responding again and then exists the function.
    for ($i = 0; $i -lt $timeout; $i++){
        $local:ErrorActionPreference = "SilentlyContinue"
        if ((Get-WmiObject -ComputerName $computerName -NameSpace "root/CIMv2" -Query "SELECT * FROM Win32_Service") -ne $Null){
            break
        }
        else{
            Start-Sleep 2
        }
    }
    
    $local:ErrorActionPreference = "Continue"
    if ($i -ge ($timeout-1)){
        throw "WMI didn't reply after $timeout seconds!"
    }
}

function Kill-RemoteService{
    param(
		$serviceName,
        $computerName, 
        $credentials
    )
    
    try{
	
		#WMI can generate non-terminating errors, but we want them to be terminating.
        $local:ErrorActionPreference = "Stop"
        
        #Splattable parameter table.
        $Wmi_Params = @{
            ComputerName = $computerName
            Query = "SELECT * FROM Win32_Service WHERE name='$serviceName'"
            Namespace = "root/CIMv2"
			
            Credential = $credentials
        }
        
        #Kill the service.
        $RemoteService = Get-WmiObject @Wmi_Params
		if ($RemoteService){
			Write-Host "$serviceName is" $RemoteService.State "on $computerName`r`n"
			if ($RemoteService.State -ne "Stopped"){
				Write-Host "    Killing $serviceName process on $computerName`r`n"
				$process = Get-WmiObject Win32_Process -ComputerName $computerName -Filter "name='$serviceName.exe'"
				if ($process -ne $null){
					$returnValue = $process.terminate()
				}
				else{
					Write-Host $serviceName "process not present on" $computerName "`r`n"
				}
			}
            if (($returnValue -eq $null) -and ($RemoteService.State -ne "Stopped")) {
                throw "Error killing sevice! ReturnValue is $($returnValue) for this instance"
            }
        }
    }
    catch{
        throw $_
    }
    finally{
        $local:ErrorActionPreference = "Continue"
    }
}

function Send-Mail{
	param(
		$messageBodyText,
		$messageSubjextText,
		$messageRecipients
	)
	
	Write-Host "Sending email notifications...`r`n"
     
	#Creating a Mail object
    $message = new-object Net.Mail.MailMessage
     
	#Creating SMTP server object
    $smtp = new-object Net.Mail.SmtpClient($smtpServer)
     
	#Email structure 
    $message.From = "DoNotReply@company.com"
    $message.ReplyTo = "DoNotReply@company.com"
    $message.To.Add($messageRecipients)
    $message.subject = $messageSubjextText
    $message.body = $messageBodyText
    
	#Sending email 
    $smtp.Send($message)
}

function Clean-Logs{
	$deleteDate = (Get-Date).AddDays(-$logFileExpiration)
	
	# Delete files older than the $logFileExpiration
	Get-ChildItem -Path $logFilePath -Recurse -Force | Where-Object {!$_.PSIsContainer -and $_.CreationTime -lt $deleteDate} | Remove-Item -Force
}

# Main
#####################
Clean-Logs
$tracefile="$logFilePath\logFile_$(get-date -format 'MM-dd-yyyy').txt"
Start-Transcript -path $tracefile

$emailMessage = "Server maintenance is beginning..."
$emailSubject = "[INFO] Starting maintenance on servers"
Send-Mail -messageBodyText $emailMessage -messageSubjextText $emailSubject -messageRecipients $emailAll

$credentials = New-Credentials -username $username -password $password
foreach ($computerName in $computerNames){
	if ($failedServerCount -gt 1) {
		Write-Host -foregroundcolor "Red" "[ERROR] More than one server failed to start the service and this script is aborting.`r`nPlease investigate then run this script again.`r`n"
		$emailMessage = "The PSAdmin script encountered more than one failed server and the script has aborted.`r`nPlease investigate all servers then run again.`r`n"
		$emailSubject = "[ERROR] $computerName encountered an error and must be investigated manually"
		Send-Mail -messageBodyText $emailMessage -messageSubjextText $emailSubject -messageRecipients $emailGroupOne
		Exit
	}
	$startTime = Get-Date
	Stop-RemoteService -serviceName $serviceName1 -computerName $computerName -credentials $credentials
	Stop-RemoteService -serviceName $serviceName2 -computerName $computerName -credentials $credentials
	Write-Host "Waiting $serviceSleepTime seconds for services to stop.`r`n"
	Start-Sleep -s $serviceSleepTime #configure this for timeout value on the service stop
	Kill-RemoteService -serviceName $serviceName1 -computerName $computerName -credentials $credentials
	Kill-RemoteService -serviceName $serviceName2 -computerName $computerName -credentials $credentials
	Reboot-RemoteMachine -computerName $computerName -credentials $credentials
	Check-RemoteMachine -ComputerName $computerName -Credentials $credentials
	Write-Host "Waiting $rebootSleepTime seconds for $computerName to fully start before trying to restart services.`r`n"
	Start-Sleep -s $rebootSleepTime #let the server fully boot before attempting to start the services
	Start-RemoteService -serviceName $serviceName1 -computerName $computerName -credentials $credentials
	if ($returnValue -ne 0) {
		Write-Host -foregroundcolor "Red" "[ERROR] There was a problem starting $serviceName1 on $computerName`r`nPlease manually investigate this server while this script continues to the next server.`r`n"
		$emailMessage = "There was a problem starting $serviceName1 on $computerName`r`nPlease manually investigate this server by checking the log file at $tracefile while this script continues to the next server.`r`n"
		$emailSubject = "[ERROR] $computerName encountered an error and must be investigated manually"
		Send-Mail -messageBodyText $emailMessage -messageSubjextText $emailSubject -messageRecipients $emailGroupOne
		$returnValue = 0;
		$failedServerCount += $failedServerCount
	}
	if ($computerName -eq "server02") {
		Start-RemoteService -serviceName $serviceName2 -computerName $computerName -credentials $credentials
		if ($returnValue -ne 0) {
			Write-Host -foregroundcolor "Red" "[ERROR] There was a problem starting $serviceName2 on $computerName`r`nPlease manually investigate this server while this script continues to the next server.`r`n"
			$emailMessage = "There was a problem starting $serviceName2 on $computerName`r`nPlease manually investigate this server by checking the log file at $tracefile while this script continues to the next server.`r`n"
			$emailSubject = "[ERROR] $computerName encountered an error and must be investigated manually"
			Send-Mail -messageBodyText $emailMessage -messageSubjextText $emailSubject -messageRecipients $emailGroupOne
			$returnValue = 0;
			$failedServerCount += $failedServerCount
		}
	}
	$finishTime = Get-Date
	$totalMinutes = ($finishTime - $startTime).minutes
	$totalSeconds = ($finishTime - $startTime).seconds
	Write-Host "$computerName was cycled in $totalMinutes minutes and $totalSeconds seconds.`r`n"
	Write-Host "----------------------------------------`r`n`r`n"
	if ($totalMinutes -gt 10) {
		$emailMessage = "$computerName took longer than ten minutes to be cycled and this could indicate a problem.`r`nPlease manually check this server by checking the log file at $tracefile and logging into $computerName to ensure everything is functional while this script continues to the next server.`r`n"
		$emailSubject = "[WARNING] $computerName took longer than ten minutes for maintenance and must be checked manually"
		Send-Mail -messageBodyText $emailMessage -messageSubjextText $emailSubject -messageRecipients $emailGroupOne
	}
}
$emailMessage = "Server maintenance is complete."
$emailSubject = "[INFO] Completed maintenance on all servers"
Send-Mail -messageBodyText $emailMessage -messageSubjextText $emailSubject -messageRecipients $emailAll
	
Stop-Transcript