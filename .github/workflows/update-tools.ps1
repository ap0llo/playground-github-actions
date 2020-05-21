
function Get-InstalledTools {
    $json = Get-Content -Raw -Path "./dotnet-tools.json" | ConvertFrom-Json
    $toolNames = $json.tools | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
    return $toolNames
}

function log($message) {
    Write-Host -ForegroundColor Green -Object $message
}

function exec($command, [switch]$skipExitCodeCheck) {
    Invoke-Expression $command

    if(-not $skipExitCodeCheck) {
        if ($LASTEXITCODE -ne 0) {
            throw "Command '$command' completed with exit code $LASTEXITCODE"
        }
    }

}

$updatedTools = @()     
$toolNames = Get-InstalledTools
foreach($toolName in $toolNames) {

    log "Resetting working copy"
    exec "git reset --hard"

    log "Updating $tool" 
    exec "dotnet tool update `"$toolName`" "
  
    exec "git diff --quiet" -skipExitCodeCheck
    if($LASTEXITCODE -eq 0) {
        log "Tool $toolName was updated"
        $updatedTools += $tool
    }
}