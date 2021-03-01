###############################################################################
# Email function
###############################################################################
Function Email-Results ($body, $subject, $from){
	Send-MailMessage -From $from -to $RecipientOne, $RecipientTwo -Subject $subject -Body $body -SmtpServer $SMTPServer -port $SMTPPort -UseSsl -Credential $SMTPCreds -Priority High
}

###############################################################################
# Counter, array and date values
###############################################################################
$count_Warnings = 0
$count_Errors = 0
$count_ProcessingErrors = 0
$count_Info = 0

$array_Warnings = New-Object System.Collections.ArrayList
$array_Errors = New-Object System.Collections.ArrayList
$array_ProcessingErrors = New-Object System.Collections.ArrayList

$CurrentDate = Get-Date -UFormat "%Y-%m-%d %H"

###############################################################################
# Email values
###############################################################################
$RecipientOne = "jay.eberhard@company.com"
$RecipientTwo = "DevOps@company.com"
$SMTPServer = "email-smtp.us-east-1.amazonaws.com"
$SMTPPort = "587"


$SecurePassword = ConvertTo-SecureString "yourOwnSESPassword" -AsPlainText -Force
$SMTPCreds = New-Object System.Management.Automation.PSCredential("yourOwnSESUser", $SecurePassword)

###############################################################################
# Open the Camel logfile
###############################################################################
$LogFileLocation = "D:\logs\Integration.log"
$LogContents = Get-Content -Path $LogFileLocation

###############################################################################
# Process the log file
###############################################################################
foreach ($line in $LogContents) {
	if ($line -clike "$CurrentDate* *INFO*") {
		if ($line -clike "*error*") {
			$messageIndex = $line.IndexOf("  ")
			$message = $line.Substring($messageIndex + 1)
			if ($array_ProcessingErrors -notcontains $message) {
				$array_ProcessingErrors += "$message`n"
			}
			$count_ProcessingErrors = $count_ProcessingErrors + 1
			continue
		} else {
			$count_Info = $count_Info + 1
			continue
		}
	}
	if ($line -clike "$CurrentDate* *WARN*") {
		$messageIndex = $line.IndexOf("  ")
		$message = $line.Substring($messageIndex + 1)
		if ($array_Warnings -notcontains $message) {
			$array_Warnings += $message	
		}
		$count_Warnings = $count_Warnings + 1
		continue
	}
	if ($line -clike "$CurrentDate* *ERROR*") {
		$messageIndex = $line.IndexOf("R ")
		$message = $line.Substring($messageIndex + 1)
		if ($array_Errors -notcontains $message) {
			$array_Errors += $message
		}
		$count_Errors = $count_Errors + 1
		continue
	}
}

###############################################################################
# Generate Output
###############################################################################
Write-Output "===================================================================================================="
Write-Output "Count of all INFO entries for the past hour: $count_Info"
Write-Output "Count of all WARN entries for the past hour: $count_Warnings"
Write-Output "Count of all ERROR entries for the past hour: $count_Errors"
Write-Output "Count of all Processing Error entries for the past hour: $count_ProcessingErrors"
Write-Output "===================================================================================================="
if ($array_Warnings.Count -gt 0) {
	$RealWarnings = $array_Warnings.Count
	$warningsPercentage = ($count_Warnings / $count_Info) * 100
	$warningsPercentage = [math]::Round($warningsPercentage)
	Write-Output "`n`n===================================================================================================="
	Write-Output "In the last hour there were $RealWarnings unique WARN entries occurring $count_Warnings times..."
	Write-Output "----------------------------------------------------------------------------------------------------"
	$array_Warnings
	$warningsSubject = "[log] Non-zero number of WARN entries last hour"
	$warningsBody = "Hello,`n`nThere were WARN entries in $LogFileLocation on sftp.ad.company.com for the past hour.`n`nTotal Entries: $count_Warnings`nUnique Entries: $RealWarnings`nWARN/INFO Percentage: $warningsPercentage`n`n`====================`nWARN output`n====================`n$array_Warnings`n`nFor the full logfile information, please see the console output at jenkins.ad.company.com`n`nThanks!"
	$warningsFrom = "log_warnings@company.com"
	Email-Results -body $warningsBody -subject $warningsSubject -from $warningsFrom
	Start-Sleep 2
}
if ($array_Errors.Count -gt 0) {
	$RealErrors = $array_Errors.Count
	$errorsPercentage = ($count_Errors / $count_Info) * 100
	$errorsPercentage = [math]::Round($errorsPercentage)
	Write-Output "`n`n===================================================================================================="
	Write-Output "In the last hour there were $RealErrors unique ERROR entries occurring $count_Errors times..."
	Write-Output "----------------------------------------------------------------------------------------------------"
	$array_Errors
	$errorsSubject = "[log] Non-zero number of ERROR entries last hour"
	$errorsBody = "Hello,`n`nThere were ERROR entries in $LogFileLocation on sftp.ad.company.com for the past hour.`n`nTotal Entries: $count_Errors`nUnique Entries: $RealErrors`nERROR/INFO Percentage: $errorsPercentage`n`n`====================`nERROR output`n====================`n$array_Errors`n`nFor the full logfile information, please see the console output at jenkins.ad.company.com`n`nThanks!"
	$errorsFrom = "log_errors@company.com"
	Email-Results -body $errorsBody -subject $errorsSubject -from $errorsFrom
	Start-Sleep 2
}
if ($array_ProcessingErrors.Count -gt 0) {
	$RealProcessingErrors = $array_ProcessingErrors.Count
	$processingErrorsPercentage = ($count_ProcessingErrors / $count_Info) * 100
	$processingErrorsPercentage = [math]::Round($processingErrorsPercentage)
	Write-Output "`n`n===================================================================================================="
	Write-Output "In the last hour there were $RealProcessingErrors unique processing error entries occurring $count_ProcessingErrors times..."
	Write-Output "----------------------------------------------------------------------------------------------------"
	$array_ProcessingErrors
	$processingErrorsSubject = "[log] Non-zero number of processing error entries last hour"
	$processingErrorsBody = "Hello,`n`nThere were processing error entries in $LogFileLocation on sftp.ad.company.com for the past hour.`n`nTotal Entries: $count_ProcessingErrors`nUnique Entries: $RealProcessingErrors`nProcessing Errors/INFO Percentage: $processingErrorsPercentage`n`n`====================`nprocessing errors output`n====================`n$array_ProcessingErrors`n`nFor the full logfile information, please see the console output at jenkins.ad.company.com`n`nThanks!"
	$processingErrorsFrom = "log_processingerrors@company.com"
	Email-Results -body $processingErrorsBody -subject $processingErrorsSubject -from $processingErrorsFrom
}
If (($array_Warnings.Count -gt 0) -Or ($array_Errors.Count -gt 0) -Or ($array_ProcessingErrors.Count -gt 0)) {
	exit 111
}