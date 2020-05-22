Write-Host "::group::Install Dependencies"

$ProgressPreference = "SilentlyContinue"

#
# Install dependencies
#
Write-Log "Installing module 'PowerShellForGitHub'"
Install-Module -Name PowerShellForGitHub -Force

Write-Host "::endgroup"
Write-Host "::group::Configure PowerShellForGitHub"

#
# Configure PowerShellForGitHub
#

# Disable Telemetry
Set-GitHubConfiguration -DisableTelemetry

# Set up default repository and owner
if($env:GITHUB_REPOSITORY) {
    Write-Log "Setting default owner and repository to '$env:GITHUB_REPOSITORY' "
    $ownerAndRepo = $env:GITHUB_REPOSITORY.Split('/')
    Set-GitHubConfiguration -DefaultOwnerName $ownerAndRepo[0] -DefaultRepositoryName $ownerAndRepo[1]
} else {
    throw "Failed to determine default owner and repository. Expected environment variable 'GITHUB_REPOSITORY' to be set"
}

# Set up credentials
if($env:GITHUB_TOKEN) {
    $user = "GitHub Actions"
    $accessToken = ConvertTo-SecureString -String $env:GITHUB_TOKEN -AsPlainText -Force
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user,$accessToken
    Set-GitHubAuthentication -Credential $credential
} else {
    throw "Failed to set authentication token Expected environment variable 'GITHUB_TOKEN' to be set"
}

Write-Host "::endgroup"