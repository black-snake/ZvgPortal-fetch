# include constants
. $(Join-Path -Path $PSScriptRoot -ChildPath ZvgPortalConstants.ps1)

function Get-Zvgs {
    [CmdletBinding(DefaultParameterSetName = "Default")]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet(
            "Baden-Württemberg",
            "Bayern",
            "Berlin",
            "Brandenburg",
            "Bremen",
            "Hamburg",
            "Hessen",
            "Mecklenburg-Vorpommern",
            "Niedersachsen",
            "Nordrhein-Westfalen",
            "Rheinland-Pfalz",
            "Saarland",
            "Sachsen",
            "Sachsen-Anhalt",
            "Schleswig-Holstein",
            "Thüringen"
        )]
        [string] $State,

        [ValidateScript( { $StateCountyCourts[$States[$State]].ContainsKey($_) } )]
        [string] $StateCountyCourt = "-- Alle Amtsgerichte --",

        [ValidateScript( { Test-Path -Path $_ -PathType Leaf -IsValid } )]
        [string] $FilePath = "zvgs-fetched.json",

        [ValidateScript( { Test-Path -Path $_ -PathType Leaf } )]
        [string] $CustomNotificationScriptPath,

        [Parameter(Mandatory = $true, ParameterSetName = "Loop")]
        [switch] $Loop,

        [Parameter(ParameterSetName = "Loop")]
        [ValidateRange(30, 86400)]
        [uint32] $IntervalSeconds = 3600
    )
    
    begin {
        $StateAbbreviation = $States[$State]

        $BaseUri = "https://www.zvg-portal.de"
        $ItemUriGeneric = "$BaseUri/index.php?button=showZvg&land_abk=$StateAbbreviation&zvg_id="

        $ModificationDateRegEx = "\(letzte Aktualisierung (\d+-\d+-\d+ \d+:\d+)\)"
        $ItemPathRegEx = "index\.php\?button=showZvg&zvg_id=(\d+)&land_abk=$StateAbbreviation"
        $HtmlRegEx = "(?is)$ItemPathRegEx.*?$ModificationDateRegEx"

        $QueryUri = "$BaseUri/index.php?button=Suchen&all=1"
        $QueryObject = @{
            ger_name = $StateCountyCourt
            order_by = 2
            land_abk = $StateAbbreviation
            ger_id   = $StateCountyCourts[$StateAbbreviation][$StateCountyCourt]
            az1      = [string]::Empty
            az2      = [string]::Empty
            az3      = [string]::Empty
            az4      = [string]::Empty
            art      = [string]::Empty
            obj      = [string]::Empty
            str      = [string]::Empty
            hnr      = [string]::Empty
            plz      = [string]::Empty
            ort      = [string]::Empty
            ortsteil = [string]::Empty
            vtermin  = [string]::Empty
            btermin  = [string]::Empty
        }
    }
    
    process {
        do {
            Write-Host "QUERYING `"$QueryUri`" WITH THE FOLLOWING PARAMETERS:"
            Write-Host $(Out-String -InputObject $QueryObject)
            try {
                $ResultHtml = (Invoke-WebRequest -Uri $QueryUri -Method Post -Form $QueryObject).Content
            }
            catch {
                Write-Error "AN EXCEPTION OCCURRED DURING THE HTTP REQUEST; TERMINATING..."
                Write-Error $_.Exception
                break            
            }
            
            Write-Host "RETRIEVING ITEMS OF THE QUERY RESULTS..."
            $DetectedZvgs = @(
                (Select-String -InputObject $ResultHtml -Pattern $HtmlRegEx -AllMatches).Matches | ForEach-Object {
                    if ($null -ne $_) {
                        @{
                            Id               = $_.Groups[1].Value
                            ModificationDate = [datetime]::Parse($_.Groups[2].Value, [System.Globalization.CultureInfo]::new("de-DE"), [System.Globalization.DateTimeStyles]::AssumeLocal)
                            Uri              = ${ItemUriGeneric} + $_.Groups[1].Value
                        }
                    }
                }
            )

            $CurrentZvgs = Get-ZvgsObj -FilePath $FilePath
            Set-ZvgsObj -FilePath $FilePath -InputObject $DetectedZvgs
            $ZvgsDiff = Get-ZvgsDiff -CurrentZvgs $CurrentZvgs -DetectedZvgs $DetectedZvgs

            if ($null -ne $ZvgsDiff) {
                Write-Host "THERE ARE NEW/ MODIFIED ITEMS:"
                $ZvgsDiff | ForEach-Object { Write-Host $_.Uri }

                # invoke custom notification script
                if ($PSBoundParameters.ContainsKey("CustomNotificationScriptPath")) {
                    $CustomNotificationScriptArgs = @{InputObject = $ZvgsDiff}
                    & $CustomNotificationScriptPath @CustomNotificationScriptArgs
                }
            }

            if ($Loop) {
                Write-Host "LOOP MODE ACTIVE; SLEEPING $IntervalSeconds SECONDS"
                Start-Sleep -Seconds $IntervalSeconds
            }
        } while ($Loop)
    }
}


function Get-ZvgsObj {
    param (
        [Parameter(Mandatory = $true)]
        [string] $FilePath
    )

    if (Test-Path -Path $FilePath -PathType Leaf) {
        return Get-Content -Path $FilePath | ConvertFrom-Json
    }
    else {
        return $null
    }
}


function Set-ZvgsObj {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript( { Test-Path -Path $_ -PathType Leaf -IsValid } )]
        [string] $FilePath,

        [AllowNull()]
        [Parameter(Mandatory = $true)]
        [object] $InputObject
    )

    Set-Content -Path $FilePath -Value $(ConvertTo-Json -InputObject $InputObject)
}


function Get-ZvgsDiff {
    param (
        [AllowNull()]
        [Parameter(Mandatory = $true)]
        [object] $CurrentZvgs,
        
        [AllowNull()]
        [Parameter(Mandatory = $true)]
        [object] $DetectedZvgs
    )

    $StillAvailableZvgs = @($DetectedZvgs | Where-Object { $_.Id -in $CurrentZvgs.Id } )
    $ModifiedZvgs = @(
        $StillAvailableZvgs | Where-Object {
            $NewData = $_
            $OldData = $CurrentZvgs | Where-Object { $_.Id -eq $NewData.Id}

            return $NewData.ModificationDate -ne $OldData.ModificationDate
        }
    )

    $NewZvgs = @($DetectedZvgs | Where-Object { $_.Id -notin $CurrentZvgs.Id } )

    return $ModifiedZvgs + $NewZvgs
}