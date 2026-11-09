# Builds a single-file ViVeTool.exe (Albacore.ViVe.dll + Newtonsoft.Json.dll merged in,
# FeatureDictionary.pfs embedded gzip-compressed) from the official source.
# Needs: git, .NET SDK (any recent), internet. No VS / .NET 4.8.1 targeting pack required.
param(
    [string]$Tag = "v0.3.4",
    [string]$Out = (Join-Path $PSScriptRoot "ViVeTool.exe")
)
$ErrorActionPreference = 'Stop'
$patch = [System.IO.Path]::Combine($PSScriptRoot, "Extra", "singlefile.patch")
$work  = Join-Path ([IO.Path]::GetTempPath()) ("vivetool-build-" + [guid]::NewGuid().ToString('N').Substring(0, 8))

function Run { param([scriptblock]$cmd) & $cmd; if ($LASTEXITCODE) { throw "Failed: $cmd" } }

try {
    Run { git clone --quiet --depth 1 --branch $Tag https://github.com/thebookisclosed/ViVe.git "$work\src" }
    Run { git -C "$work\src" apply $patch }
    Run { dotnet build "$work\src\ViVeTool\ViVeTool.sdk.csproj" -c Release -nologo -v:minimal }

    # ILRepack (pinned) straight from nuget.org
    New-Item -ItemType Directory -Force "$work\tools" | Out-Null
    Invoke-WebRequest "https://www.nuget.org/api/v2/package/ILRepack/2.0.48" -OutFile "$work\tools\ilrepack.zip"
    Expand-Archive "$work\tools\ilrepack.zip" "$work\tools\ilrepack"

    Push-Location "$work\src\ViVeTool\bin\Release\net481"
    try { Run { & "$work\tools\ilrepack\tools\ILRepack.exe" /out:"$work\merged\ViVeTool.exe" ViVeTool.exe Albacore.ViVe.dll Newtonsoft.Json.dll } }
    finally { Pop-Location }

    Copy-Item "$work\merged\ViVeTool.exe" $Out -Force
    Write-Host "Wrote $Out ($((Get-Item $Out).Length) bytes)"
}
finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
