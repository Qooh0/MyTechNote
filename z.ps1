[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("preview", "p", "new", "n", "list", "ls", "books", "help")]
    [string]$Command = "help",

    [Parameter(Position = 1)]
    [string]$Title,

    [string]$Slug,

    [ValidateSet("tech", "idea")]
    [string]$Type = "tech",

    [switch]$Idea,

    [string]$Emoji,

    [string[]]$Topics = @(),

    [switch]$Publish,

    [int]$Port = 8000,

    [switch]$Open,

    [switch]$NoWatch,

    [string]$HostName
)

$ErrorActionPreference = "Stop"

$RepoRoot = $PSScriptRoot
$ZennCmd = Join-Path $RepoRoot "node_modules\.bin\zenn.cmd"

function Show-Usage {
    @"
Usage:
  .\z.ps1 preview [-Open] [-Port 8000] [-NoWatch]
  .\z.ps1 new "Title" [-Slug your-slug-123] [-Topics zenn,powershell] [-Idea] [-Emoji "<emoji>"] [-Publish]
  .\z.ps1 list
  .\z.ps1 books

Aliases:
  p  = preview
  n  = new
  ls = list

Examples:
  .\z.ps1 p -Open
  .\z.ps1 n "Write Zenn articles with PowerShell" -Slug powershell-zenn-writing -Topics zenn,powershell
  .\z.ps1 n "Idea note" -Idea -Publish
"@
}

function Ensure-Zenn {
    if (Test-Path $ZennCmd) {
        return
    }

    Write-Host "node_modules is missing. Running npm install..."
    Push-Location $RepoRoot
    try {
        & npm install
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }
    finally {
        Pop-Location
    }

    if (-not (Test-Path $ZennCmd)) {
        throw "zenn-cli was not found after npm install."
    }
}

function Invoke-Zenn {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ZennArgs,

        [switch]$Capture
    )

    Ensure-Zenn

    Push-Location $RepoRoot
    try {
        if ($Capture) {
            & $ZennCmd @ZennArgs
            return
        }

        & $ZennCmd @ZennArgs
        exit $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
}

function Get-CleanTopics {
    param([string[]]$RawTopics)

    $RawTopics |
        ForEach-Object { $_ -split "," } |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ } |
        Select-Object -Unique
}

function ConvertTo-TopicLiteral {
    param([string[]]$CleanTopics)

    $quoted = $CleanTopics | ForEach-Object {
        '"' + ($_.Replace('\', '\\').Replace('"', '\"')) + '"'
    }

    "[" + ($quoted -join ", ") + "]"
}

function Update-ArticleTopics {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath,

        [Parameter(Mandatory = $true)]
        [string[]]$CleanTopics
    )

    if ($CleanTopics.Count -eq 0) {
        return
    }

    $articlePath = Join-Path $RepoRoot $RelativePath
    if (-not (Test-Path $articlePath)) {
        Write-Warning "Created article path was not found: $RelativePath"
        return
    }

    $content = [System.IO.File]::ReadAllText($articlePath, [System.Text.Encoding]::UTF8)
    $topicLiteral = ConvertTo-TopicLiteral $CleanTopics

    if ($content -match '(?m)^topics:\s*\[.*\]\s*$') {
        $content = $content -replace '(?m)^topics:\s*\[.*\]\s*$', "topics: $topicLiteral"
    }
    else {
        $content = $content -replace '(?m)^(type:\s*.+)$', "`$1`ntopics: $topicLiteral"
    }

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($articlePath, $content, $utf8NoBom)
}

$normalizedCommand = switch ($Command) {
    "p" { "preview" }
    "n" { "new" }
    "ls" { "list" }
    default { $Command }
}

switch ($normalizedCommand) {
    "preview" {
        $zennArgs = @("preview", "--port", "$Port")

        if ($Open) {
            $zennArgs += "--open"
        }

        if ($NoWatch) {
            $zennArgs += "--no-watch"
        }

        if ($HostName) {
            $zennArgs += @("--host", $HostName)
        }

        Invoke-Zenn $zennArgs
    }

    "new" {
        $zennArgs = @("new:article", "--machine-readable", "--type", $(if ($Idea) { "idea" } else { $Type }), "--published", $(if ($Publish) { "true" } else { "false" }))

        if ($Title) {
            $zennArgs += @("--title", $Title)
        }

        if ($Slug) {
            $zennArgs += @("--slug", $Slug)
        }

        if ($Emoji) {
            $zennArgs += @("--emoji", $Emoji)
        }

        $output = Invoke-Zenn $zennArgs -Capture
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {
            $output | Write-Output
            exit $exitCode
        }

        $articleFile = $output | Where-Object { $_ -match '\.md$' } | Select-Object -Last 1
        $cleanTopics = @(Get-CleanTopics $Topics)

        if ($articleFile) {
            Update-ArticleTopics $articleFile $cleanTopics
        }

        $output | Write-Output

        if ($articleFile -and $cleanTopics.Count -gt 0) {
            Write-Host "Updated topics: $($cleanTopics -join ', ')"
        }
    }

    "list" {
        Invoke-Zenn @("list:articles", "--format", "tsv")
    }

    "books" {
        Invoke-Zenn @("list:books")
    }

    "help" {
        Show-Usage
    }
}
