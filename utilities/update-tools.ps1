

# Import Helper functions
. (Join-Path $PSScriptRoot "common.ps1") 

# Install dependencies
Install-Module -Name PowerShellForGitHub -Force

Set-GitHubConfiguration -DisableTelemetry

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
    $updateInfo = Update-Tool -ManifestPath $toolManifestPath -ToolName $toolName

    if($updateInfo) {

        # Push the new branch
        $branchName = $updateInfo.BranchName

        Write-Log "Pushing branch `"$branchName`""
        Start-Command "git push origin $branchName`:$branchName --force"

        Start-Sleep -Seconds 2

        # Create a Pull Request for the branch (if there isn't a PR already)
        Write-Log "Getting open Pull Requests"
        $pr = Get-GitHubPullRequest -State Open | Where-Object { $PsItem.Head.ref -eq $branchName  }

        if($pr) {
            Write-Log "Pull Request for branch '$branchName' already exists (#$($pr.number))"
        } else {
            Write-Log "Creating Pull Request"
            $pr = New-GitHubPullRequest -Title $updateInfo.Summary -Head $newBranchName -Base $targetBranch
            Write-Log "Created Pull Request #$($pr.Number)"
        }

    }
}

