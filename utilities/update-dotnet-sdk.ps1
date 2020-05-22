
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
Write-Log "Getting Release Info"
$releaseInfo = Get-DotnetReleaseInfo -ReleaseIndexUrl $releasesIndexUrl -ReleaseChannel $releaseChannel
$latestSdkVersion = $releaseInfo.'latest-sdk'

Write-Log "Latest .NET SDK version is $latestSdkVersion"

$currentSdkVersion = Get-DotNetSdkVersion -GlobalJsonPath $globalJsonPath
Write-Log "Currently used .NET SDK version is $currentSdkVersion"

if($currentSdkVersion -ne $latestSdkVersion) {
    Write-Log "Updating .NET SDK to version $latestSdkVersion"
    Set-DotNetSdkVersion -GlobalJsonPath $globalJsonPath -Version $latestSdkVersion

    $branchName = Get-UpdateBranchName -ToolName "dotnet-sdk" -ToolVersion $latestSdkVersion
    Write-Log "Creating branch '$branchName'"
    Start-Command "git checkout -b `"$branchName`""

    $commitMessageSummary = "build(sdk): Bump .NET SDK version from $currentSdkVersion version $latestSdkVersion"
    $commitMessageBody = "Bumps .NET SDK from version $currentSdkVersion to $latestSdkVersion"

    $commitMessageFile = Get-TempFile
    $commitMessageSummary > $commitMessageFile
    "" >> $commitMessageFile
    $commitMessageBody >> $commitMessageFile

    Start-Command "git add `"$globalJsonPath`""
    Start-Command "git commit --file `"$commitMessageFile`"" 
    Start-Command "git checkout -"   

} else {
    Write-Log ".NET SDK is already up to date"
}