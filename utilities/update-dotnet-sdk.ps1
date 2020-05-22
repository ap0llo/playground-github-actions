
. (Join-Path $PSScriptRoot "common.ps1") 
. (Join-Path $PSScriptRoot "setup.ps1") 


#
# Variables
#
$repoRoot = (Join-Path $PSScriptRoot ".." | Resolve-Path).Path
$releasesIndexUrl = "https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/releases-index.json"
$releaseChannel = "3.1"
$globalJsonPath = Join-Path $repoRoot "global.json"


#
# Main script
#
Reset-WorkingCopy

Write-Log "Getting Release Info"
$releaseInfo = Get-DotnetReleaseInfo -ReleaseIndexUrl $releasesIndexUrl -ReleaseChannel $releaseChannel
$latestSdkVersion = $releaseInfo.'latest-sdk'

Write-Log "Latest .NET SDK version is $latestSdkVersion"

$currentSdkVersion = Get-DotNetSdkVersion -GlobalJsonPath $globalJsonPath
Write-Log "Currently used .NET SDK version is $currentSdkVersion"

$updateInfo = New-UpdateInfo
$updateInfo.ToolName = "dotnet-sdk"
$updateInfo.ToolDisplayName = ".NET SDK"
$updateInfo.PreviousVersion = $currentSdkVersion
$updateInfo.BaseBranch = Get-CurrentBranchName

if($currentSdkVersion -ne $latestSdkVersion) {
    
    Set-DotNetSdkVersion  -GlobalJsonPath $globalJsonPath -Version $latestSdkVersion

    $updateInfo.Updated = $true        
    $updateInfo.NewVersion = $latestSdkVersion    

    New-UpdateBranch $updateInfo | Out-Null
    Publish-Branch $updateInfo

} else {
    Write-Log ".NET SDK is already up to date"
}