$ProgressPreference = "SilentlyContinue"

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

#
# Main script
#
$toolNames = Get-ToolName -ManifestPath $toolManifestPath
$branchNames = Get-GitHubBranch | Select-Object -ExpandProperty name

foreach($toolName in $toolNames) {
    
    Reset-WorkingCopy
    $updateResult = Update-Tool -ManifestPath $toolManifestPath -ToolName $toolName

    if($updateResult.Updated) {

        # Push the new branch
        $branchName = $updateResult.BranchName

        if($branchNames -contains $branchName) {
            Write-Log "Branch `"$branchName`" already exists, skipping tool update"
        }

        Write-Log "Pushing branch `"$branchName`""
        Start-Command "git push origin $branchName`:$branchName --force"

        Start-Sleep -Seconds 2

        # Create a Pull Request for the branch (if there isn't a PR already)
        Write-Log "Getting open Pull Requests"
        $pr = Get-GitHubPullRequest -State Open -NoStatus | Where-Object { $PsItem.Head.ref -eq $branchName  }

        if($pr) {
            Write-Log "Pull Request for branch '$branchName' already exists (#$($pr.number))"
        } else {
            Write-Log "Creating Pull Request"
            $pr = New-GitHubPullRequest -Title $updateResult.Summary -Body $updateResult.Body -Head $branchName -Base $targetBranch -NoStatus
            Write-Log "Created Pull Request #$($pr.Number)"
        }

    }
}

