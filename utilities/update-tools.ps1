

# Import Helper functions
. (Join-Path $PSScriptRoot "common.ps1") 

# Install dependencies
Install-Module -Name PowerShellForGitHub -Force

# TODO: configure credentials

# Set up default repository and owner
if($env:GITHUB_REPOSITORY) {
    Write-Log "Setting default owner and repository to '$env:GITHUB_REPOSITORY' "
    $ownerAndRepo = $env:GITHUB_REPOSITORY.Split('/')
    Set-GitHubConfiguration -DefaultOwnerName $ownerAndRepo[0] -DefaultRepositoryName $ownerAndRepo[1]
} else {
    throw "Failed to determine default owner and repository. Expected environment variable 'GITHUB_REPOSITORY' to be set"
}

if($env:GITHUB_TOKEN) {
    $user = "GitHub Actions"
    $accessToken = ConvertTo-SecureString -String $env:GITHUB_TOKEN -AsPlainText -Force
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user,$accessToken
    Set-GitHubAuthentication -Credential $credential
} else {
    throw "Failed to set authentication token Expected environment variable 'GITHUB_TOKEN' to be set"
}


# Variables
$repoRoot = (Join-Path $PSScriptRoot ".." | Resolve-Path).Path
$toolManifestPath = (Join-Path $repoRoot "dotnet-tools.json")
$targetBranch = "master"

# Main script
$toolNames = Get-ToolName -ManifestPath $toolManifestPath


foreach($toolName in $toolNames) {
    
    Reset-WorkingCopy
    $newBranchName = Update-Tool -ManifestPath $toolManifestPath -ToolName $toolName

    if($newBranchName) {
        # Push the new branch
        Start-Command "git push origin $newBranchName`:$newBranchName"

        # Create a Pull Request for the branch
        $pr = New-GitHubPullRequest -Title "Update tool $toolName" -Head $newBranchName -Base $targetBranch
        Write-Log "Created Pull Request $($pr.Number)"
    }
}

