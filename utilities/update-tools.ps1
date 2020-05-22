
. (Join-Path $PSScriptRoot "common.ps1") 
. (Join-Path $PSScriptRoot "setup.ps1") 

#
# Variables
#
$repoRoot = (Join-Path $PSScriptRoot ".." | Resolve-Path).Path
$toolManifestPath = Join-Path $repoRoot "dotnet-tools.json"
$targetBranch = "master"

#
# Main script
#
$toolNames = Get-ToolName -ManifestPath $toolManifestPath

foreach($toolName in $toolNames) {
    
    Reset-WorkingCopy
    $updateInfo = Update-Tool -ManifestPath $toolManifestPath -ToolName $toolName

    if($updateInfo.Updated) {

        Publish-Branch $updateInfo
    }
}

