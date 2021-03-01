###############################################################################
# Email function
###############################################################################
Function Email-Alert {
	$Subject = "[HangfireFailure] Hangfire has exceeded failure threshold!"
	$Body = "Hello,<br><br>Hangfire in production has crossed the threshold for an increase of $failureTolerance in failed jobs in one hour, which may be causing issues. One hour ago there were $oldReading errors and the current reading is $currentReading .  Please investigate. <br><br>Thanks!"
	Send-MailMessage -From $From -to $RecipientOne, $RecipientTwo -Subject $Subject -Body $Body -SmtpServer $SMTPServer -port $SMTPPort -UseSsl -Credential $SMTPCreds -Priority High -BodyAsHtml
}

###############################################################################
# Analyze scraped data function
###############################################################################
Function Analyze-ScrapedData {
	foreach ($line in $output)
	{
		if ($line -like "*Failed*")
		{
			$value = $line.Split(" ")
			$failedCount = $value[2]
			if ($failedCount -ne $null ) {$failedCount = $failedCount.replace("`,", "")}
			Add-Content $historicalValues $failedCount
		}
	}
}

###############################################################################
# Email values
###############################################################################
$From = "hangfirefailure@company.com"
$RecipientOne = "jay.eberhard@company.com"
$RecipientTwo = "DevOps@company.com"
$SMTPServer = "email-smtp.us-east-1.amazonaws.com"
$SMTPPort = "587"

$SecurePassword = ConvertTo-SecureString "yourOwnSESPassword" -AsPlainText -Force
$SMTPCreds = New-Object System.Management.Automation.PSCredential("yourOwnSESUser", $SecurePassword)

###############################################################################
# Scraping and data values
###############################################################################
try {
	$page = (wget http://localhost:8080/hangfire/jobs/failed)
} catch {
	Write-Output "ERROR: Scrape of $page failed on localhost, please check the server name in the Wrapper and try again."
}
$output = $page.Links.InnerText
$historicalValues = "C:\HangfireMon\FailedJobsCount.txt"
[int]$failureTolerance = 20

# Create the HangfireMon directory if it doesn't exist
if (!(Test-Path "C:\HangfireMon\"))
{
	New-Item -ItemType "directory" -Path "C:\HangfireMon\"
}

# Create the output file if it doesn't exist
if (!(Test-Path $historicalValues))
{
	New-Item -ItemType "file" -Path $historicalValues
}

$outputLines = Get-Content $historicalValues | Measure-Object -Line

if ($outputLines.Lines -ge "12")
{
	# Trim off the oldest entry in the data to make room for the new one 
	(Get-Content $historicalValues | Select-Object -Skip 1) | Set-Content $historicalValues

	# Glean off the current number of failed jobs and add it to the data file
	Analyze-ScrapedData

	# Capture the last 12 (one hour's worth) of data from the data file 
	$currentData = (Get-Content $historicalValues | Select-Object -Last 12)

	# Work with the oldest and newest values from the data file and calculate the delta
	[int]$oldReading = $currentData[0]
	[int]$currentReading = $currentData[11]
	$readingDelta = $currentReading - $oldReading

	# If the delta is greater than 20 fire the alert, otherwise make note there is no alert at this time
	if ($readingDelta -gt 20)
	{
		Write-Output "ERROR: Hangfire failure readings are problematic! One Hour Ago: $oldReading Current: $currentReading Delta: $readingDelta"
		Write-Output "ERROR: Attention is required on produciton Hangfire, please investigate!"
		Email-Alert
		throw "Hangfire failure!"
	} else {
		Write-Output "INFO: Hangfire failure readings are within range. One Hour Ago: $oldReading Current: $currentReading Delta: $readingDelta"
	}
} else {
	# Glean off the current number of failed jobs and add it to the data file
	Analyze-ScrapedData
	[int]$currentReading = (Get-Content $historicalValues | Select-Object -Last 1)
	[int]$oldestReading = (Get-Content $historicalValues | Select-Object -First 1)
	Write-Output "INFO: Insufficient Hangfire failure readings, please check back in one hour. Oldest reading: $oldestReading Most current reading: $currentReading"
}