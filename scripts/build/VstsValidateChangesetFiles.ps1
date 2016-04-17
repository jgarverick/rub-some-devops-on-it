#
# VstsValidateChangesetFiles.ps1
#
# Provides an example of how to vall VSTS APIs from within a custom build task
#
[CmdletBinding(DefaultParameterSetName = 'None')]
param(
)

Write-Host "Starting Validation Step"
try{
	$provider = $env:BUILD_REPOSITORY_PROVIDER
	$url = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
	$apiVersion = "1.0"
	$urlPart = ""
	$changeCount = 99999
	$changeId = $env:BUILD_SOURCEVERSION.Replace("CS","")
	Write-Host "Repo URI: $env:BUILD_REPOSITORY_URI, change $changeId"
	
	switch($provider){
		"TfsGit" { $url = $url + "_apis/git/repositories/$env:BUILD_REPOSITORY_ID/commits/$changeId/?api-version=$apiVersion&changeCount=$changeCount";break }
		"TFVC" { $url = $url +  "_apis/Changesets/$changeId/changes?api-version=$apiVersion";break }
		"Git" { $url = $env:BUILD_REPOSITORY_URI + "";break }
		default { throw [System.Exception] "No information found for provider $provider." }
	}
	
	#Write-Host "Args: $args" 
	#Write-Host "REST API URL: $url"
	$obj = Invoke-WebRequest -UseBasicParsing -Uri $url -Headers @{
    Authorization = "Bearer $env:SYSTEM_ACCESSTOKEN"
	} | ConvertFrom-Json
	
	$obj.changes | ForEach-Object -Process { 
		$line = $_.item.path
		$canPublish = $false
		$setName = $line.Split('/')[2]
		if($line.EndsWith(".json")){
			Write-Host "Change found for $line, variable set name $setName." 
			$canPublish = $true
		} elseif($line.EndsWith("Globals.json")){
			Write-Host "Change found for $line, global variable set." 
			$setName = "SolutionItems"
			$canPublish = true
		}
		
		
		if($canPublish){
			$args.Add("--setName=$setName")
			$job = Start-Job -ScriptBlock {
				<<path.to/executable>> $args
			}
			$result = Receive-Job $job
		}
	}

	Write-Host "Finishing Validation Step"
}catch{
	Write-Error $_
	Write-Host "Validation Step was not successful!"
}
