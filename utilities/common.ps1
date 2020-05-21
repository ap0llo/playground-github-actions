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


function Update-Tool {

    param(
        [Parameter(Mandatory = $true)][string]$ManifestPath,
        [Parameter(Mandatory = $true)][string]$ToolName
    )

    if(-not(Test-Path $ManifestPath)) {
        throw "Tool manifest at '$ManifestPath' does not exist"
    }

    $manifestDir = Split-Path -Path $ManifestPath -Parent

    Push-Location $manifestDir
    try {
        Write-Log "Updating $ToolName" 
        Start-Command "dotnet tool update `"$toolName`" "
    }
    finally {
        Pop-Location
    }
    
    Start-Command "git diff --quiet" -SkipExitCodeCheck
    if($LASTEXITCODE -ne 0) {
        $version = Get-ToolVersion -MainfestPath $ManifestPath -ToolName $toolName
        Write-Log "Tool '$toolName' was updated to version $version"

        $branchName = "toolupdates/$toolName"
        Write-Log "Creating branch '$branchName'"
        Start-Command "git checkout -b `"$branchName`""

        Start-Command "git commit -am `"build(deps): Update $toolName to version $version`"" 
        Start-Command "git checkout -"

        return $branchName
    } else {
        Write-Log "Tool '$toolName' is already up to date"
        return $null
    }
}