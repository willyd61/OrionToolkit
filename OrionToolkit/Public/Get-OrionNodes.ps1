﻿Function Get-OrionNodes {
    <#
    .SYNOPSIS
        Retrieve node info from SolarWinds Orion Network Performance Monitor (NPM).

    .DESCRIPTION
        Retrieve node info from SolarWinds Orion Network Performance Monitor (NPM) using
        the SolarWinds Information Service (SWIS) API.

        Depends upon the SwisPowerShell module.
        https://github.com/solarwinds/OrionSDK/wiki/PowerShell

        Returns results as objects, suitable for formatting, filtering, or passing to pipeline
        for further processing.

        Results include the following fields. Refer to SWIS schema for details.
        http://solarwinds.github.io/OrionSDK/schema/index.html

        Orion.Nodes
            - AvgResponseTime 
            - NodeName 
            - Contact 
            - DetailsUrl 
            - IOSImage 
            - IOSVersion 
            - IPAddress 
            - Location 
            - MachineType 
            - NodeDescription 
            - PercentLoss 
            - PercentMemoryAvailable 
            - PercentMemoryUsed 
            - Status 
            - SysName 
            - Uri 
            - Vendor 
        
        NCM.EntityPhysical
            - EntityDescription
            - EntityName
            - Manufacturer
            - Model
            - Serial

    .PARAMETER Swis
        SolarWinds Information Service connection object, as returned from Connect-Swis.

        If not provided, Connect-Swis will prompt for username and password.

        Once supplied, $Swis remains in global scope, so future invocations of Get-OrionNodes
        will not prompt for credentials.
    
    .PARAMETER OrionServer
        IP address or FQDN of SolarWinds Orion NPM server.

        Once supplied, $OrionServer remains in global scope for future session use.

    .PARAMETER CustomProperties
        Administratively-defined custom properties to filter by or include in results.
        Pass a hashtable of property-value pairs to filter the query with, or
        pass a list of property names to include in all results.

    .PARAMETER ExtraFields
        List of extra built-in schema fields to add to the SWQL query.
        Must prefix fields with table aliases below:
            - Orion.Nodes = N
            - NCM.EntityPhysical = E

        Refer to SWIS schema documentation for details.
        http://solarwinds.github.io/OrionSDK/schema/index.html

    .PARAMETER IncludeMfgDate
        Parses serial number into an approximate date of manufacture.
        Supported only for modern Cisco devices.

    .PARAMETER IncludeIOSDate
        Parses $NodeDescription for the compilation date of the IOS image.
        Supported only if a date string exists in $NodeDescription.

    .PARAMETER IPAddress
        List of node IP addresses to include in results.

    .PARAMETER IOSVersion
        List of IOS version strings to include in results.

    .PARAMETER IOSImage
        List of IOS image strings to include in results.

    .PARAMETER Location
        List of SNMP sysLocation strings to include in results.

    .PARAMETER Manufacturer
        List of manufacturer strings to include in results.

    .PARAMETER Model
        List of model strings to include in results.

    .PARAMETER NodeName
        List of node names (usually hostnames) to include in results.

    .PARAMETER NodeDescription
        List of node description strings to include in results.

    .PARAMETER OrderBy
        Field name to sort results by. Defaults to NodeName. See available fields above.

    .PARAMETER QueryOnly
        Returns the SWQL query string, without executing it against $OrionServer.
    
    .PARAMETER ResultLimit
        Integer limit of results to provide. Defaults to 0 (unlimited).

    .PARAMETER Serial
        List of serial number strings to include in results.

    .PARAMETER Status
        List of status codes to include in results.
            - 1  = Up
            - 2  = Down
            - 3  = Warning
            - 4  = Shutdown
            - 9  = Unmanaged
            - 12 = Unreachable
            - 14 = Critical
            - 17 = Undefined

    .PARAMETER Vendor
        List of vendor strings to include in results.

    .EXAMPLE
        Get-OrionNodes

        Simple report on all managed nodes

    .EXAMPLE
        Get-OrionNodes -Vendor Cisco -IOSVersion "12.*"

        Get all Cisco nodes on IOS 12.x

    .EXAMPLE
        Get-OrionNodes -Status 9 | ft nodename

        Report on all unmanaged nodes

    .EXAMPLE
        Get-OrionNodes | ? { $_.PercentLoss -gt 1}

        Report on all nodes with polling packet loss greater than 1%

    .EXAMPLE
        Get-OrionNodes -CustomProperties devicetype,deviceclass

        Returns custom properties "DeviceType" and "DeviceClass" in results.
        Useful for reporting or filtering via PowerShell.

    .EXAMPLE
        Get-OrionNodes -CustomProperties @{'devicetype' = 'AccessSwitch'}

        Filters results for "devicetype" = "AccessSwitch"

    .NOTES
        All string parameters support wildcards (*) for partial matching.

        Numeric comparisons are not natively implemented. Use PowerShell filtering instead.

    .LINK
        https://github.com/austind/oriontoolkit

    .FUNCTIONALITY
        PowerShell Language

    #>

    [CmdletBinding()]
    Param (
        [Parameter(HelpMessage="Solar Winds Information Service connection object")]
        [object]$Swis = $Global:Swis,
        [Parameter(HelpMessage="IP or FQDN of SolarWinds Orion NPM server")]
        [string]$OrionServer = $Global:OrionServer,
        $CustomProperties,
        [string[]]$ExtraFields,
        [switch]$IncludeMfgDate = $true,
        [switch]$IncludeIOSDate = $true,
        [string[]]$IPAddress,
        [string[]]$IOSVersion,
        [string[]]$IOSImage,
        [string[]]$Location,
        [string[]]$Manufacturer,
        [string[]]$Model,
        [string[]]$NodeName,
        [string[]]$NodeDescription,
        [string]$OrderBy = 'NodeName',
        [switch]$QueryOnly = $false,
        [int]$ResultLimit = 0,
        [string[]]$Serial,
        [string[]]$Status,
        [string[]]$Vendor
    )
    Begin {
        Import-Module SwisPowerShell
        If (!$Swis -and !$OrionServer) {
            $OrionServer = $Global:OrionServer = Read-Host 'Orion IP or FQDN'
        }
        If (!$Swis) {
            $Swis = $Global:Swis = Connect-Swis -Hostname $OrionServer
        }

        # Maps fields to parameters
        $FieldParamMap = @{
            'E.Manufacturer'     = 'Manufacturer'
            'E.Model'            = 'Model'
            'E.Serial'           = 'Serial'
            'N.Contact'          = 'Contact'
            'N.CustomProperties' = 'CustomProperties'
            'N.IOSImage'         = 'IOSImage'
            'N.IOSVersion'       = 'IOSVersion'
            'N.IPAddress'        = 'IPAddress'
            'N.Location'         = 'Location'
            'N.MachineType'      = 'MachineType'
            'N.NodeDescription'  = 'NodeDescription'
            'N.NodeName'         = 'NodeName'
            'N.Status'           = 'Status'
            'N.SysName'          = 'SysName'
            'N.Vendor'           = 'Vendor'
        }
    }

    Process {

        # http://solarwinds.github.io/OrionSDK/schema/
        # Default Fields
        $DefaultFields = @(
            'E.EntityDescription'
            'E.EntityName'
            'E.Manufacturer'
            'E.Model'
            'E.Serial'
            'N.AvgResponseTime'
            'N.NodeName'
            'N.Contact'
            'N.DetailsUrl'
            'N.IOSImage'
            'N.IOSVersion'
            'N.IPAddress'
            'N.Location'
            'N.MachineType'
            'N.NodeDescription'
            'N.PercentLoss'
            'N.PercentMemoryAvailable'
            'N.PercentMemoryUsed'
            'N.Status'
            'N.SysName'
            'N.Uri'
            'N.Vendor'
        )

        # Extra fields
        If ($ExtraFields) {
            $AllFields = $DefaultFields + $ExtraFields
        } Else {
            $AllFields = $DefaultFields
        }

        # Custom Properties
        If ($CustomProperties) {
            If ($CustomProperties.GetType() -eq [hashtable]){
                ForEach ($Property in $CustomProperties.GetEnumerator()) {
                    $AllFields += "N.CustomProperties.$($Property.Name)"
                }
            } Else {
                ForEach ($Property in $CustomProperties) {
                    $AllFields += "N.CustomProperties.$Property"
                }
            }
        }

        # Result limit
        $LimitString = ''
        If ($ResultLimit) {
            $LimitString = " TOP $ResultLimit"
        }
        
        # Build query
        $Query  = "SELECT${LimitString} $($AllFields -join ', ') "
        $Query += "FROM NCM.NodeProperties P "
        $Query += "INNER JOIN Orion.Nodes N ON P.CoreNodeID = N.NodeID "
        $Query += "LEFT JOIN NCM.EntityPhysical E ON E.NodeID = P.NodeID AND E.EntityClass = 3 "
        $Query += "WHERE "
        $WhereClause = @()

        # Where clause
        ForEach ($Item in $FieldParamMap.GetEnumerator()) {
            $Param = Get-Variable -Name $Item.Value -ErrorAction SilentlyContinue
            # Custom properties
            If ($Item.Value -eq 'CustomProperties') {
                If ($Param.Value -and ($Param.Value.GetType() -eq [hashtable])) {
                    ForEach ($Part in $Param.Value.GetEnumerator()) {
                        $WhereClause += Get-WhereClauseStatement "$($Item.Name).$($Part.Name)" $Part.Value
                    }
                }
            } Else {
                $WhereClause += Get-WhereClauseStatement $Item.Name $Param.Value
            }
        }
    }

    End {

        # Finalize query
        $Query = "$Query $($WhereClause -join ' AND ') ORDER BY $OrderBy"

        If ($QueryOnly) {
            Return $Query
        } Else {
            # Obtain results
            $Results = Get-SwisData $Swis $Query
            ForEach ($Result in $Results) {
                [void]$Result.PSObject.TypeNames.Insert(0, 'OrionToolkit.Node')

                # Include manufacture date
                If ($IncludeMfgDate) {
                    If ($Result.Serial -and $Result.Vendor -like "*Cisco*") {
                        $MfgDate = (Get-CiscoManufactureDate $Result.Serial -ErrorAction SilentlyContinue)
                        $Result | Add-Member -MemberType NoteProperty -Name 'MfgDate' -Value $MfgDate
                    }
                }

                # Include IOS date
                If ($IncludeIOSDate) {
                    $Result.NodeDescription -match '(\d{2}-\w{3}-\d{2})' | Out-Null
                    If ($Matches) {
                        $IOSDate = (Get-Date $Matches[0])
                        $Result | Add-Member -MemberType NoteProperty -Name IOSDate -Value $IOSDate
                    }
                }
            }
            Return $Results
        }
    }
}