#
# Venafi Tpp Engine utility script
#
# 2022-09-28 First version released on github by Christopher Camacho
#

<#
.SYNOPSIS
TPP processing engine utility - backup / restore / compare
.DESCRIPTION
View, backup, restore, or compare select configurations from TPP processing engines.

Engine configurations saved: Assigned Folders, Assigned Address Ranges, Assigned Start Time.

Using -All will read all server configurations from the Venafi API and output the results to the screen or to the file specified by -outFile. Files created with the -All option are not suitable for use as input via -inFile or with the -CompareOnly option.

When using -outEngine note that folders will be ADDED to the selected engine, but attributes are OVERWRITTEN. Assigned Address Ranges will NOT be merged.

Input Options:
-inEngine should refer to the name of a TPP processing engine.
-inFile should refer to a JSON file created from the output of this utility.

Output Options:
-outEngine should refer to the name of a TPP processing engine that you want to update.
-outFile should refer to a JSON file that will be created/overwritten by this utility.

Compare Options:
-CompareOnly <server1> <server2>
The utility will attempt to read a JSON file <server1> and <server2> and will fall back to downloading data from the Venafi API if the names are not files.
.PARAMETER All
Read configurations for all servers via the Venafi API. Optionally use -outFile to save results to a file.
.PARAMETER inEngine
The name of a Venafi TPP engine to download configuration settings for.
.PARAMETER inFile
The name of a JSON backup file containing engine configuration settings.
.PARAMETER outEngine
The name of a Venafi TPP engine to push configuration settings to.
.PARAMETER outFile
The name for a JSON file to create/overwrite configuration settings to. Optional - output defaults to stdout.
.PARAMETER CompareOnly
Provide 'diff' like output showing the configuration differences between 2 servers (Engine1 and Engine2).
.PARAMETER Engine1
First file or engine name for comparison. The utility tries to open as a file first, then falls back to using the API.
.PARAMETER Engine2
Second file or engine name for comparison. The utility tries to open as a file first, then falls back to using the API.
.PARAMETER VenafiSession
Authentication for the utility.
The value defaults to the script/global session object $VenafiSession created by New-VenafiSession.
A TPP token can also provided, but this requires an environment variable TPP_SERVER to be set.
.NOTES
Requires VenafiPS 5.0.0 (or newer)
.EXAMPLE
TPPEngineUtility.ps1 -inEngine VENTPP01 -outFile VENTPP01.json
Download the configuration for TPP engine 'VENTPP01' and back the data up to the file 'VENTPP01.json'
.EXAMPLE
TPPEngineUtility.ps1 -inFile VENTPP01.json -outEngine VENTPP02
Load configuration from the file 'VENTPP01.json' and push those settings to the TPP engine 'VENTPP02'
.EXAMPLE
TppEngineUtility.ps1 -All -outFile ALL-Engines.json
Download configurations from all TPP engines and back the data up to the file 'ALL-Engines.json'
.EXAMPLE
TPPEngineUtility.ps1 -CompareOnly VENTPP01 VENTPP01.json
Compare the configuration of the TPP engine 'VENTPP01' to the settings saved in the file 'VENTPP01.json'
.EXAMPLE
TPPEngineUtility.ps1 -CompareOnly VENTPP01 VENTPP02
Compare the configurations of the TPP engines 'VENTPP01' and 'VENTPP02'
#>

#Requires -Modules @{ ModuleName='VenafiPS'; ModuleVersion='5.0.0' }

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName='InE-OutF')]

Param(
    [Parameter(Mandatory, ParameterSetName='All-OutF')]
    [switch] $All,

    [Parameter(Mandatory, ParameterSetName='InE-OutE')]
    [Parameter(Mandatory, ParameterSetName='InE-OutF')]
    [Alias('inEngineDN', 'inEnginePath', 'EngineDN', 'EnginePath')]
    [ValidateNotNullOrEmpty()]
    [string] $inEngine,

    [Parameter(Mandatory, ParameterSetName='InF-OutE')]
    [Parameter(Mandatory, ParameterSetName='InF-OutF')]
    [ValidateNotNullOrEmpty()]
    [string] $inFile,

    [Parameter(Mandatory, ParameterSetName='InE-OutE')]
    [Parameter(Mandatory, ParameterSetName='InF-OutE')]
    [Alias('outEngineDN', 'outEnginePath', 'Target', 'TargetDN', 'TargetPath')]
    [ValidateNotNullOrEmpty()]
    [string] $outEngine,

    [Parameter(ParameterSetName='All-OutF')]
    [Parameter(ParameterSetName='InE-OutF')]
    [Parameter(ParameterSetName='InF-OutF')]
    [ValidateNotNullOrEmpty()]
    [string] $outFile,

    [Parameter(Mandatory, ParameterSetName='Compare', Position=1)]
    [Alias('Compare', 'diff')]
    [switch] $CompareOnly,

    [Parameter(Mandatory, ParameterSetName='Compare', Position=2)]
    [string] $Engine1,

    [Parameter(Mandatory, ParameterSetName='Compare', Position=3)]
    [string] $Engine2,

    [Parameter()]
    [ValidateScript( {
        if (Resolve-DnsName -Name $PSItem) { $true }
        else { throw "Could not resolve hostname '$($PSItem)'." }
    } ) ]
    [ValidateNotNullOrEmpty()]
    [Alias('ServerUrl', 'Url')]
    [string] $Server,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ClientID='ps-config-utility',

    $VenafiSession=$Global:VenafiSession
)

function Get-FolderPaths
{
    param (
        [Parameter(Mandatory, ValueFromPipeline, Position=0)]
        [string] $EnginePath
    )

    # Return a sorted list of folder paths
    ((Get-TppEngineFolder -EnginePath $EnginePath).FolderPath | Sort-Object)
}

function Get-EngineAttributes
{
    param (
        [Parameter(Mandatory, ValueFromPipeline, Position=0)]
        [string] $EnginePath
    )

    $EngineAttr = New-Object -TypeName psobject
    foreach ($attr in $('Address Range','Start Time')) {
        $EngineAttr | Add-Member -MemberType NoteProperty -Name $attr -Value ((Get-TppAttribute -Path $EnginePath -Attribute $attr).$attr | Sort-Object)
    }

    $EngineAttr
}

function Get-EngineFromTpp
{
    param (
        [Parameter(Mandatory)]
        [Alias('EngineDN', 'EnginePath')]
        [ValidateNotNullOrEmpty()]
        [string] $Engine,

        $VenafiSession=$Global:VenafiSession
    )

    try {
        $tppObj = (Get-TppObject -Path $Engine)
    }
    catch {
        $tppObj = (Find-TppEngine -Pattern $Engine)
        if (-not $tppObj) {
            throw "Could not find TPP engine '$($Engine)'"
        }
    }
    if ($tppObj.TypeName -ne 'Venafi Platform') {
        throw "$($Engine) is not a TPP engine"
    }

    Write-Verbose "Collected Engine Data for '$($tppObj.Name)'"
    [PSCustomObject] @{
        'Engine'     = ($tppObj.Path | Split-Path -Leaf)
        'Attributes' = ($tppObj.Path | Get-EngineAttributes)
        'Folders'    = ($tppObj.Path | Get-FolderPaths)
    }
}

Write-Verbose "Parameter Set Name: $($PSCmdlet.ParameterSetName)"

if ($CompareOnly.IsPresent) {
    [PSCustomObject[]] $EngineOne = @()
    if (Test-Path -Path $Engine1 -PathType Leaf) {
        $EngineOne += (Get-Content -Path $Engine1 | ConvertFrom-Json)
    }
    else {
        $EngineOne += Get-EngineFromTpp -Engine $Engine1 -VenafiSession $VenafiSession
    }

    if ($EngineOne.Count -gt 1) {
        throw "$($Engine1) matched more than one engine"
    }
    Write-Verbose "Loaded Engine 1: $($EngineOne.Engine)"

    [PSCustomObject[]] $EngineTwo = @()
    if (Test-Path -Path $Engine2 -PathType Leaf) {
        $EngineTwo += (Get-Content -Path $Engine2 | ConvertFrom-Json)
    }
    else {
        $EngineTwo += Get-EngineFromTpp -Engine $Engine2 -VenafiSession $VenafiSession
    }

    if ($EngineTwo.Count -gt 1) {
        throw "$($Engine2) matched more than one engine"
    }
    Write-Verbose "Loaded Engine 2: $($EngineTwo.Engine)"

    Compare-Object (($EngineOne|ConvertTo-Json -Depth 9) -split '\r?\n') (($EngineTwo|ConvertTo-Json -Depth 9) -split '\r?\n')

    return
}

if ($All.IsPresent -or $inEngine -or $outEngine) {
    if (-not $VenafiSession) {
        $venCred=Get-Credential -Message 'Enter Venafi API credentials'
        $VenafiSession = New-VenafiSession -Server $Server -Credential $venCred -ClientId $ClientID -Scope @{'configuration'='manage,delete';} -PassThru
    }
}

[PSCustomObject[]] $TppHierarchy = @()
    
if ($All.IsPresent) {
    foreach ($engine in ((Find-TppEngine -Pattern '*').Path | Sort-Object)) {
        Write-Verbose "Gathering Engine Data: $($engine)"
        $TppHierarchy += @{
            'Engine'     = ($engine | Split-Path -Leaf)
            'Attributes' = ($engine | Get-EngineAttributes)
            'Folders'    = ($engine | Get-FolderPaths)
        }
    }

    Write-Verbose "Gathered data for $($TppHierarchy.Count) processing engines"
}

if ($inEngine) {
    try {
        $tppObj = (Get-TppObject -Path $inEngine)
    }
    catch {
        $tppObj = (Find-TppEngine -Pattern $inEngine)
        if (-not $tppObj) {
            throw "Could not find TPP engine '$($inEngine)'"
        }
    }
    if ($tppObj.TypeName -ne 'Venafi Platform') {
        throw "$($inEngine) is not a TPP engine"
    }
    $engine = $tppObj.Path
    Write-Verbose "Gathering Engine Data: $($tppObj.Name)"
    [PSCustomObject] $TppHierarchy += @{
        'Engine'     = ($engine | Split-Path -Leaf)
        'Attributes' = ($engine | Get-EngineAttributes)
        'Folders'    = ($engine | Get-FolderPaths)
    }
}

if ($inFile) {
    $TppHierarchy += (Get-Content -Path $inFile | ConvertFrom-Json)
    foreach ($engine in $TppHierarchy) {
        Write-Verbose "Loaded Engine Data: $($engine.Engine)"
    }
    Write-Verbose "Loaded data for $($TppHierarchy.Count) processing engines"
}

if ($PSCmdlet.ParameterSetName -match '.*-OutF$') {
    if ($outFile) {
        Write-Verbose "Writing JSON output to file: $($outFile)"
        $TppHierarchy | ConvertTo-Json -Depth 9 | Set-Content -Path $outFile
    }
    else {
        Write-Verbose 'Generating JSON output'
        $TppHierarchy | ConvertTo-Json -Depth 9
    }
}

if ($outEngine) {
    if ($TppHierarchy.Count -ne 1) {
        # If copying config to a TPP engine then the source file can only contain 1 engine
        # If the source file is a dump of multiple engines, how we do know which to copy??
        throw "Ambiguous Source File: Loaded $($TppHierarchy.Count) engines from $($outFile)"
    }

    try {
        $tppObj = (Get-TppObject -Path $outEngine)
    }
    catch {
        $tppObj = (Find-TppEngine -Pattern $outEngine)
        if (-not $tppObj) {
            throw "Could not find TPP engine '$($outEngine)'"
        }
    }
    if ($tppObj.TypeName -ne 'Venafi Platform') {
        throw "$($outEngine) is not a TPP engine"
    }

    if ($PSCmdlet.ShouldProcess($tppObj.Name, 'Update settings and assigned folders')) {
        Write-Verbose "Update Engine: $($tppObj.Name)"
        foreach ($folder in ($TppHierarchy.Folders)) {
            Write-Verbose "Add Folder: $($folder)"
        }

        Add-TppEngineFolder -EnginePath ($tppObj.Path) -FolderPath ($TppHierarchy.Folders)

        $attribHash = @{}
        $TppHierarchy.Attributes | Get-Member -MemberType Properties | ForEach-Object {
            Write-Verbose "Update Setting: '$($_.Name)' = '$($TppHierarchy.Attributes.($_.Name))'"
            $attribHash."$($_.Name)" = ($TppHierarchy.Attributes.($_.Name))
        }

        Set-TppAttribute -Path ($tppObj.Path) -Attribute $attribHash -VenafiSession $VenafiSession

        Write-Verbose "$($tppObj.Name) has been updated!"
    }
} # if ($outEngine)
