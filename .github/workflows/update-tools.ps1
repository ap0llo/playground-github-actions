
function Get-InstalledTools {
    $json = Get-Content -Raw -Path "./dotnet-tools.json" | ConvertFrom-Json
    $toolNames = $json.tools | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
    return $toolNames
}

function Get-ToolVersion($toolName) {
    $json = Get-Content -Raw -Path "./dotnet-tools.json" | ConvertFrom-Json
    $toolVersion = $json.tools.$toolName.version
    if(-not $toolVersion) {
        throw "Failed to determine version of tool $toolName"
    }
    return $toolVersion
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
    exec "git reset --hard" | Out-Null
    exec "git diff --quiet" | Out-Null # ensure working copy is clean

    log "Updating $tool" 
    exec "dotnet tool update `"$toolName`" " | Out-Null
  
    exec "git diff --quiet" -skipExitCodeCheck | Out-Null
    if($LASTEXITCODE -ne 0) {
        $version = Get-ToolVersion $toolName
        log "Tool $toolName was updated to version $version"
        $updatedTools += $tool
    }
}