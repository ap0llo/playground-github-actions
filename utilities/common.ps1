function Start-Command {

    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory= $false)][switch]$SkipExitCodeCheck
    )

    Invoke-Expression $Command | Write-Host
    if(-not $SkipExitCodeCheck) {
        if ($LASTEXITCODE -ne 0) {
            throw "Command '$command' completed with exit code $LASTEXITCODE"
        }
    }
}

function Get-ToolName {

    param(
        [Parameter(Mandatory = $true)][string]$ManifestPath
    )

    $json = Get-Content -Raw -Path $ManifestPath | ConvertFrom-Json
    $toolNames = $json.tools | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
    return $toolNames
}


function Get-ToolVersion {

    param(
        [Parameter(Mandatory = $true)][string]$ManifestPath,
        [Parameter(Mandatory = $true)][string]$ToolName
    )

    $json = Get-Content -Raw -Path $ManifestPath | ConvertFrom-Json
    $toolVersion = $json.tools.$ToolName.version
    if(-not $toolVersion) {
        throw "Failed to determine version of tool $ToolName"
    }
    return $toolVersion
}


function Write-Log ($message) {
    Write-Host "[LOG] $message" -ForegroundColor Green     
}


function Reset-WorkingCopy {

    Write-Log "Resetting working copy"
    Start-Command "git reset --hard" 
    Start-Command "git diff --quiet" # ensure working copy is clean
}

function Get-CurrentBranchName {

    $command = "git rev-parse --abbrev-ref HEAD"
    $currentBranch = Invoke-Expression $command
    if ($LASTEXITCODE -ne 0) {
        throw "Command '$command' completed with exit code $LASTEXITCODE"
    }

    Write-Log "Current branch is $currentBranch"
    return $currentBranch
}

function Get-UpdateBranchName {

    param(
        [Parameter(Mandatory = $true)]$UpdateInfo      
    )

    $toolName = $UpdateInfo.ToolName
    $version = $UpdateInfo.NewVersion
    return "toolupdate/$toolName/$version"
}


function Get-TempFile {
    $dir = [System.IO.Path]::GetTempPath()
    $name = [System.IO.Path]::GetRandomFileName()
    return Join-Path $dir $name
}

function New-UpdateInfo {
    
    $result = New-Object -TypeName PSObject
    $result | Add-Member -MemberType NoteProperty -Name Updated -Value $false
    $result | Add-Member -MemberType NoteProperty -Name BaseBranch -Value ""
    $result | Add-Member -MemberType NoteProperty -Name ToolName -Value ""
    $result | Add-Member -MemberType NoteProperty -Name ToolDisplayName -Value ""
    $result | Add-Member -MemberType NoteProperty -Name PreviousVersion -Value ""
    $result | Add-Member -MemberType NoteProperty -Name NewVersion -Value ""
    return $result    
}


function Get-CommitMessageSummary {

    param(
        [Parameter(Mandatory=$true)]$UpdateInfo
    )

    return "build(deps): Bump $($UpdateInfo.ToolDisplayName) from $($UpdateInfo.PreviousVersion) to $($UpdateInfo.NewVersion) "
}

function Get-CommitMessageBody {
    param(
        [Parameter(Mandatory=$true)]$UpdateInfo
    )

    return "Bumps $($UpdateInfo.ToolDisplayName) from version $($UpdateInfo.PreviousVersion) to $($UpdateInfo.NewVersion)"
}


function New-UpdateBranch {

    param(
        [Parameter(Mandatory=$true)]$UpdateInfo
    )

    $branchName = Get-UpdateBranchName -UpdateInfo $UpdateInfo
    Write-Log "Creating branch '$branchName'"
    Start-Command "git checkout -b `"$branchName`""

    $commitMessageSummary = Get-CommitMessageSummary -UpdateInfo $UpdateInfo
    $commitMessageBody = Get-CommitMessageBody -UpdateInfo $UpdateInfo

    $commitMessageFile = Get-TempFile
    $commitMessageSummary > $commitMessageFile
    "" >> $commitMessageFile
    $commitMessageBody >> $commitMessageFile
    
    Start-Command "git commit -a --file `"$commitMessageFile`"" 
    Start-Command "git checkout -"    

    return $branchName
}


function Update-Tool {

    param(
        [Parameter(Mandatory = $true)][string]$ManifestPath,
        [Parameter(Mandatory = $true)][string]$ToolName
    )

    if(-not(Test-Path $ManifestPath)) {
        throw "Tool manifest at '$ManifestPath' does not exist"
    }
    
    # Save currently installed version of tool
    $currentVersion = Get-ToolVersion -ManifestPath $ManifestPath -ToolName $toolName

    $updateInfo = New-UpdateInfo
    $updateInfo.ToolName = $ToolName
    $updateInfo.ToolDisplayName = $ToolName
    $updateInfo.PreviousVersion = $currentVersion
    $updateInfo.BaseBranch = Get-CurrentBranchName

    $manifestDir = Split-Path -Path $ManifestPath -Parent

    Push-Location $manifestDir
    try {
        Write-Log "Updating $ToolName" 
        Start-Command "dotnet tool update `"$toolName`" "
    }
    finally {
        Pop-Location
    }
    
    $newVersion = Get-ToolVersion -ManifestPath $ManifestPath -ToolName $toolName
    if($currentVersion -ne $newVersion) {        
        
        Write-Log "Tool '$toolName' was updated to version $newVersion"
        
        $updateInfo.Updated = $true
        $updateInfo.NewVersion = $newVersion

        New-UpdateBranch $updateInfo | Out-Null
        
    } else {
        Write-Log "Tool '$toolName' is already up to date at version $currentVersion"
    }
    return $updateInfo
}


function Get-DotnetReleaseInfo {

    param(
        [Parameter(Mandatory = $true)][string]$ReleaseIndexUrl,
        [Parameter(Mandatory = $true)][string]$ReleaseChannel
    )

    Write-Log "Downloading .NET Release Index"
    $response = Invoke-WebRequest -Uri $ReleaseIndexUrl
    $releaseIndexJson = ConvertFrom-Json -InputObject $response.Content

    Write-Log "Getting Release information for channel $releaseChannel"
    $channelReleaseInfo = $releaseIndexJson.'releases-index' | Where-Object { $PSItem.'channel-version' -eq $releaseChannel}

    if(($channelReleaseInfo | Measure-Object).Count -gt 1) {
        throw "Found multiple entries for channel $releaseChannel in the Release Index"
    } 
    elseif($channelReleaseInfo -eq $null) {
        throw "Failed to find entry for channel $releaseChannel in the Release Index"
    } else {    
        
        $releaseInfoUrl = $channelReleaseInfo.'releases.json'
        Write-Log "Getting Release Information from '$releaseInfoUrl'"
        $response = Invoke-WebRequest -Uri $releaseInfoUrl
        $releaseJson = ConvertFrom-Json $response.Content
        return $releaseJson
    }
}

function Get-DotNetSdkVersion {

    param(
        [Parameter(Mandatory = $true)][string]$GlobalJsonPath
    )

    if(-not(Test-Path $GlobalJsonPath)) {
        throw "global.json at '$GlobalJsonPath' does not exist"
    }

    $json = Get-Content $GlobalJsonPath -Raw | ConvertFrom-Json

    $sdkVersion = $json.sdk.version
    if(-not $sdkVersion) {
        throw "Failed to read .NET SDK version from '$GlobalJsonPath'"
    }
    return $sdkVersion
}

function Set-DotNetSdkVersion {

    param(
        [Parameter(Mandatory = $true)][string]$GlobalJsonPath,
        [Parameter(Mandatory = $true)][string]$Version
    )

    if(-not(Test-Path $GlobalJsonPath)) {
        throw "global.json at '$GlobalJsonPath' does not exist"
    }

    $json = Get-Content $GlobalJsonPath -Raw | ConvertFrom-Json
    $json.sdk.version = $Version
    $json | ConvertTo-Json | Out-File $GlobalJsonPath
}


<#
.SYNOPSIS
Publishes the branch if it does not yet exist and creates a Pull Request
#>
function Publish-Branch {

    param(
        [Parameter(Mandatory = $true)]$UpdateInfo     
    )

    Write-Log "Getting branches from GitHub"
    $existingBranches = Get-GitHubBranch | Select-Object -ExpandProperty name

    $branchName = Get-UpdateBranchName -UpdateInfo $UpdateInfo

    if($existingBranches -contains $branchName) {
        Write-Log "Branch `"$branchName`" already exists, skipping tool update"
    } else {

        Write-Log "Pushing branch `"$branchName`""
        Start-Command "git push origin $branchName`:$branchName"
    
        Start-Sleep -Seconds 2
    
        # Create a Pull Request for the branch (if there isn't a PR already)
        Write-Log "Getting open Pull Requests"
        $pr = Get-GitHubPullRequest -State Open -NoStatus | Where-Object { $PsItem.Head.ref -eq $branchName  }
    
        if($pr) {
            Write-Log "Pull Request for branch '$branchName' already exists (#$($pr.number))"
        } else {
            Write-Log "Creating Pull Request"
    
            $title = Get-CommitMessageSummary -UpdateInfo $UpdateInfo
            $body = Get-CommitMessageBody -UpdateInfo $UpdateInfo
    
            $pr = New-GitHubPullRequest -Title $title -Body $body -Head $branchName -Base $UpdateInfo.BaseBranch -NoStatus
            Write-Log "Created Pull Request #$($pr.Number)"
        }
    }

}