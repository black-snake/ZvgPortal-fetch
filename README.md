# ZvgPortal-fetch

## Description

This is a PowerShell module to fetch foreclosure auction information from zvg-portal.de which can run a subsequent custom notification script to handle any new/ updated entities. Optionally, the module's function can run in an endless loop to constantly check for changes.


## Usage

1. Please download the folder `ZvgPortal-fetch` containing the module (`.ps*` files).
2. After that, save the folder to one of your PowerShell module paths (see `$env:PSModulePath`) or import the module temporarily by executing:

        Import-Module ./ZvgPortal-fetch/ZvgPortal-fetch.psd1
3. Now you can use the function `Get-Zvgs` with your choice of parameters.


## Help
After you imported the module (or if the module is within your PowerShell module path), you can use the following command to get help for the function `Get-Zvgs`:

        help Get-Zvgs