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

function Get-UpdateBranchName {

    param(
        [Parameter(Mandatory = $true)][string]$ToolName,
        [Parameter(Mandatory = $true)][string]$ToolVersion
    )

    return "toolupdate/$ToolName/$ToolVersion"
}


function Get-TempFile {
    $dir = [System.IO.Path]::GetTempPath()
    $name = [System.IO.Path]::GetRandomFileName()
    return Join-Path $dir $name
}

function New-UpdateResult {
    
    $result = New-Object -TypeName PSObject
    $result | Add-Member -MemberType NoteProperty -Name Updated -Value $false
    $result | Add-Member -MemberType NoteProperty -Name BranchName -Value ""
    $result | Add-Member -MemberType NoteProperty -Name Summary -Value ""
    $result | Add-Member -MemberType NoteProperty -Name Body -Value ""
    $result | Add-Member -MemberType NoteProperty -Name ToolName -Value ""
    $result | Add-Member -MemberType NoteProperty -Name PreviousVersion -Value ""
    $result | Add-Member -MemberType NoteProperty -Name NewVersion -Value ""
    return $result    
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

    $manifestDir = Split-Path -Path $ManifestPath -Parent

    Push-Location $manifestDir
    try {
        Write-Log "Updating $ToolName" 
        Start-Command "dotnet tool update `"$toolName`" "
    }
    finally {
        Pop-Location
    }
    
    $result = New-UpdateResult
    $result.ToolName = $ToolName
    $result.PreviousVersion = $currentVersion

    $newVersion = Get-ToolVersion -ManifestPath $ManifestPath -ToolName $toolName
    if($currentVersion -ne $newVersion) {        
        
        Write-Log "Tool '$toolName' was updated to version $newVersion"
        
        $branchName = Get-UpdateBranchName -ToolName $ToolName -ToolVersion $newVersion
        Write-Log "Creating branch '$branchName'"
        Start-Command "git checkout -b `"$branchName`""

        $commitMessageSummary = "build(deps): Bump $toolName from $currentVersion version $newVersion"
        $commitMessageBody = "Bumps .NET Local tool '$toolName' from version $currentVersion to $newVersion"

        $commitMessageFile = Get-TempFile
        $commitMessageSummary > $commitMessageFile
        "" >> $commitMessageFile
        $commitMessageBody >> $commitMessageFile

        Start-Command "git add `"$ManifestPath`""
        Start-Command "git commit --file `"$commitMessageFile`"" 
        Start-Command "git checkout -"
        
        $result.Updated = $true
        $result.NewVersion = $newVersion
        $result.BranchName = $branchName
        $result.Summary = $commitMessageSummary
        $result.Body = $commitMessageBody
        
    } else {
        Write-Log "Tool '$toolName' is already up to date at version $currentVersion"
    }
    return $result
}