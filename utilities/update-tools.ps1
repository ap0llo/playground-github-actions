

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
$toolManifestPath = Join-Path $repoRoot "dotnet-tools.json"
$targetBranch = "master"

# Main script
$toolNames = Get-ToolName -ManifestPath $toolManifestPath


foreach($toolName in $toolNames) {
    
    Reset-WorkingCopy
    $newBranchName = Update-Tool -ManifestPath $toolManifestPath -ToolName $toolName

    if($newBranchName) {
        # Push the new branch
        Write-Log "Pushing branch `"$newBranchName`""
        Start-Command "git push origin $newBranchName`:$newBranchName"

        Start-Sleep -Seconds 2

        # Create a Pull Request for the branch
        Write-Log "Creating Pull Request"
        $pr = New-GitHubPullRequest -Title "Update tool $toolName" -Head $newBranchName -Base $targetBranch
        Write-Log "Created Pull Request $($pr.Number)"
    }
}

