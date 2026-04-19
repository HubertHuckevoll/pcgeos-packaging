param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Arguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Parent -LiteralPath $scriptPath
$ensembleDir = (Resolve-Path -LiteralPath $scriptDir).ProviderPath
$launchDirName = Split-Path -Leaf -LiteralPath $ensembleDir
$baseboxVersion = $env:BASEBOX_VERSION

if ([string]::IsNullOrWhiteSpace($baseboxVersion))
{
    $baseboxVersion = '{{BASEBOX_VERSION}}'
}

$baseboxBinDir = 'binnt'
if ([Environment]::Is64BitOperatingSystem)
{
    $baseboxBinDir = 'binnt64'
}

$baseboxExec = Join-Path -Path $ensembleDir -ChildPath ("basebox\{0}\{1}\basebox.exe" -f $baseboxVersion, $baseboxBinDir)
$baseConfigFile = Join-Path -Path $ensembleDir -ChildPath 'basebox.conf'
$launchTemplateConfigFile = Join-Path -Path $ensembleDir -ChildPath 'basebox.launch.templ.conf'
$launchConfigFile = Join-Path -Path $ensembleDir -ChildPath 'basebox.launch.conf'
$logFile = Join-Path -Path $ensembleDir -ChildPath 'ensemble.log'

function Write-Log
{
    param (
        [Parameter(Mandatory = $true)]
        [string] $Message
    )

    Add-Content -LiteralPath $logFile -Encoding ASCII -Value $Message
}

$timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
$argSuffix = ''
if ($Arguments.Count -gt 0)
{
    $argSuffix = ' ' + ($Arguments -join ' ')
}
Set-Content -LiteralPath $logFile -Encoding ASCII -Value ("[{0}] start: {1}{2}" -f $timestamp, $MyInvocation.MyCommand.Name, $argSuffix)
Write-Log ("basebox: {0}" -f $baseboxExec)

try
{
    if ([string]::IsNullOrWhiteSpace($launchDirName))
    {
        Write-Log ("error: could not resolve launcher directory name from {0}" -f $ensembleDir)
        exit 1
    }

    if (-not (Test-Path -LiteralPath $baseConfigFile -PathType Leaf))
    {
        Write-Log ("error: missing static config {0}" -f $baseConfigFile)
        exit 1
    }

    if (-not (Test-Path -LiteralPath $launchTemplateConfigFile -PathType Leaf))
    {
        Write-Log ("error: missing launch template config {0}" -f $launchTemplateConfigFile)
        exit 1
    }

    $templateContent = Get-Content -LiteralPath $launchTemplateConfigFile -Raw -Encoding ASCII
    if ($templateContent.IndexOf('{{LAUNCH_DIR_NAME}}', [System.StringComparison]::Ordinal) -lt 0)
    {
        Write-Log ("error: placeholder {{LAUNCH_DIR_NAME}} not found in launch template {0}" -f $launchTemplateConfigFile)
        exit 1
    }

    $generatedConfig = $templateContent.Replace('{{LAUNCH_DIR_NAME}}', $launchDirName)
    if ($generatedConfig.IndexOf('{{LAUNCH_DIR_NAME}}', [System.StringComparison]::Ordinal) -ge 0)
    {
        Write-Log ("error: unresolved placeholder remained in generated config {0}" -f $launchConfigFile)
        exit 1
    }

    Set-Content -LiteralPath $launchConfigFile -Encoding ASCII -Value $generatedConfig
    Write-Log ("config: generated {0} from template {1} (launch dir: {2})" -f $launchConfigFile, $launchTemplateConfigFile, $launchDirName)

    if (-not (Test-Path -LiteralPath $baseboxExec -PathType Leaf))
    {
        Write-Log ("error: missing executable {0}" -f $baseboxExec)
        exit 1
    }

    $baseboxArgs = @(
        '-noconsole'
        '-noprimaryconf'
        '-nolocalconf'
        '-conf'
        $baseConfigFile
        '-conf'
        $launchConfigFile
    )
    if ($Arguments.Count -gt 0)
    {
        $baseboxArgs += $Arguments
    }

    Write-Log 'launch: request submitted'
    $process = Start-Process -FilePath $baseboxExec -ArgumentList $baseboxArgs -WindowStyle Hidden -WorkingDirectory $ensembleDir -PassThru
    Write-Log ("launch: pid={0}" -f $process.Id)
    Write-Log 'launcher: exiting'
    exit 0
}
catch
{
    Write-Log ("error: exception {0}" -f $_.Exception.Message)
    exit 1
}
