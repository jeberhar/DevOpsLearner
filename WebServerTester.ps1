$computers = @()
$passwords = @()

# Server 1
$computers += "server1.com"
$passwords += "administratorP4assword!"

# Server 2
$computers += "server2.com"
$passwords += "administratorP4assword!"

Write-Output "==========Checking Servers=========="
for ($i=0; $i -lt $computers.length; $i++)
{
	$computer = $computers[$i]
	$password = $passwords[$i]

	$user = "$computer\administrator"

	$securepassword = convertto-securestring -asplaintext -force -string $password
	$credential = new-object -typename system.management.automation.pscredential -argumentlist $user, $securepassword  
	$session = new-pssession $computer -credential $credential 
	
	Write-Output "$computer"
	Invoke-Command -ComputerName $computer -Credential $credential -ScriptBlock {$regKeyPath = "registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\InetStp\"; $IIS = Test-Path $regKeyPath; Write-Output "IIS running: $IIS"}
	Invoke-Command -ComputerName $computer -Credential $credential -ScriptBlock {$tomcat = Get-Process "Tomcat8" -ErrorAction SilentlyContinue; if ($? -like "False") { $tomcat = $false } else { $tomcat = $true }; Write-Output "Tomcat8 running: $tomcat`n" }
}