# Venafi-TppEngineUtility
Venafi TPP processing engine utility - backup / restore / compare

### SYNTAX
    TppEngineUtility.ps1 -All [-outFile <String>]
    TppEngineUtility.ps1 -inEngine <String> [-outFile <String>]
    TppEngineUtility.ps1 -inEngine <String> -outEngine <String>
    TppEngineUtility.ps1 -inFile <String> [-outFile <String>]
    TppEngineUtility.ps1 -inFile <String> -outEngine <String>
    TppEngineUtility.ps1 -CompareOnly [-Engine1] <String> [-Engine2] <String>

### DESCRIPTION
View, backup, restore, or compare select configurations from TPP processing engines.

Engine configurations saved: Assigned Folders, Assigned Address Ranges, Assigned Start Time.

Using -All will read all server configurations from the Venafi API and output the results to the screen or to the file specified by -outFile. Files created with the -All option are not suitable for use as input via -inFile or with the -CompareOnly option.

When using -outEngine note that folders will be ADDED to the selected engine, but attributes are OVERWRITTEN. Assigned Address Ranges will NOT be merged.

### Input Options:
-inEngine should refer to the name of a TPP processing engine.

-inFile should refer to a JSON file created from the output of this utility.

### Output Options:

-outEngine should refer to the name of a TPP processing engine that you want to update.

-outFile should refer to a JSON file that will be created/overwritten by this utility.

### Compare Options:

     -CompareOnly <server1> <server2>

The utility will attempt to read a JSON file server1 and server2 and will fall back to downloading data from the Venafi API if the names are not files.


### PARAMETERS
    -All [<SwitchParameter>]
        Read configurations for all servers via the Venafi API. Optionally use -outFile to save results to a file.

    -inEngine <String>
        The name of a Venafi TPP engine to download configuration settings for.

    -inFile <String>
        The name of a JSON backup file containing engine configuration settings.

    -outEngine <String>
        The name of a Venafi TPP engine to push configuration settings to.

    -outFile <String>
        The name for a JSON file to create/overwrite configuration settings to. Optional - output defaults to stdout.

    -CompareOnly [<SwitchParameter>]
        Provide 'diff' like output showing the configuration differences between 2 servers (Engine1 and Engine2).

    -Engine1 <String>
        First file or engine name for comparison. The utility tries to open as a file first, then falls back to using the API.

    -Engine2 <String>
        Second file or engine name for comparison. The utility tries to open as a file first, then falls back to using the API.

### NOTES

Requires VenafiPS 5.0.0 (or newer)

### EXAMPLES

    TPPEngineUtility.ps1 -inEngine VENTPP01 -outFile VENTPP01.json

Download the configuration for TPP engine 'VENTPP01' and back the data up to the file 'VENTPP01.json'

    TPPEngineUtility.ps1 -inFile VENTPP01.json -outEngine VENTPP02

Load configuration from the file 'VENTPP01.json' and push those settings to the TPP engine 'VENTPP02'

    TppEngineUtility.ps1 -All -outFile ALL-Engines.json

Download configurations from all TPP engines and back the data up to the file 'ALL-Engines.json'

    TPPEngineUtility.ps1 -CompareOnly VENTPP01 VENTPP01.json

Compare the configuration of the TPP engine 'VENTPP01' to the settings saved in the file 'VENTPP01.json'

    TPPEngineUtility.ps1 -CompareOnly VENTPP01 VENTPP02

Compare the configurations of the TPP engines 'VENTPP01' and 'VENTPP02'
