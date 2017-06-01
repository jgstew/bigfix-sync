# Created by William Easton 
# Created on 1/20/2016
# Free to distribute, copy, modify, and sell.
# No copyright notice must be maintained.

Param (
    $BFServer,
    $BFUsername,
    $BFPassword,
    $Sites,
    $Types,
    $OutDir
)

cd $PSScriptRoot

if (!($BFServer)) { $BFServer = read-host -Prompt "Please identify the server you would like to export from (server.domain.tld)" }

if (!($Sites)) { $Sites = read-host -Prompt "Please identify the sites you would like to export (comma seperated)" }

if (!($OutDir)) { $OutDir = read-host -Prompt "Please identify the location you would like to export the sites to" }

if (!($BFUsername)) { $BFUsername = read-host -Prompt "BigFix Operator Username with Read Permissions" }

if (!($BFPassword)) { $BFPassword = read-host -Prompt "BigFix BigFix Operator Password" }

if (!($Types)) { $Types = read-host -Prompt "Which types would you like to export (Tasks, Fixlets, Files, Analyses)" }

# -- Start -- Bypass cert errors in Enhanced Security environments

add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

Add-Type -AssemblyName System.Security
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# -- End -- Bypass cert errors in Enhanced Security environments

# Get a connection header for use in later connections
Function Get-BFConnectHeaders {
    param (
        $Username,
        $Password
    )
    <#
    .SYNOPSIS
    Get HTTP connection headers for connecting to the BigFix Server
    
    .DESCRIPTION
    Get encoded authorization information necessary to connect to the BigFix Server
    #>

    $EncodedAuthorization = [System.Text.Encoding]::UTF8.GetBytes($username + ':' + $password)
    $EncodedPassword = [System.Convert]::ToBase64String($EncodedAuthorization)
    $headers = @{"Authorization"="Basic $($EncodedPassword)"}

    return $Headers
}

# Remove invalid characters for when we want to save the file
Function Remove-InvalidFileNameChars {
  param(
    [Parameter(Mandatory=$true,
      Position=0,
      ValueFromPipeline=$true,
      ValueFromPipelineByPropertyName=$true)]
    [String]$Name
  )

  $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''

  $re = "[{0}]" -f [RegEx]::Escape($invalidChars)
  $NewName = $Name -replace $re
  $NewName = $NewName.Replace("%","")
  $NewName = $NewName.Replace("^","")
  $NewName = $NewName.Replace("[","")
  $NewName = $NewName.Replace("]","")
  return $NewName
}

function get-plural {
    param (
        [string] $value
    )
    if ($value[-2] -eq "i" -and $value[-1] -eq "s") {
        $value = ($value[0..($value.length-3)] -join "") + "es"
    } else {
        $value += "s"
    }
    return $value
}

#Exports and manually added files from the site
function Export-Files {
    param (
        $Server,
        $Site,
        $ConnectHeaders,
        $OutDir
    )

    $Response = invoke-webrequest -uri "https://$($Server):52311/api/site/custom/$Site/files" -Headers ($ConnectHeaders) -method get

    $Items = (select-xml -content ($Response) -xpath "/BESAPI/SiteFile").Node

    foreach ($Item in $Items) {
        invoke-webrequest -uri $Item.Resource -Headers ($ConnectHeaders) -method get -OutFile "$OutDir\$Site\Files\$($Item.Name)"
    }

}

function Export-Content {
    param (
        $Server,
        $ConnectHeaders,
        $Site,
        $OutDir,
        $Types,
        [switch] $Clean
    )
    write-host "Processing site: $Site"
H
    foreach ($Type in $Types) {
        
        write-host "           processing type: $Type"

        if ($Clean) {
            #Delete Contents
            remove-item "$OutDir\$Site\$(get-plural $Type)" -Recurse -ErrorAction SilentlyContinue | out-null
    
            #Create Structure
            new-item "$OutDir\$Site\$(get-plural $Type)" -ItemType directory -ErrorAction SilentlyContinue | out-null
        }

        if ($Type -eq "File") { Export-Files -Server $Server -Site $Site -OutDir $OutDir -ConnectHeaders $ConnectHeaders; continue; }

        #Query server for items in site
        $Response = invoke-webrequest -uri "https://$($Server):52311/api/$((get-plural $Type).tolower())/custom/$Site" -Headers ($ConnectHeaders) -method get

        #Parse XML for items
        $Items = (select-xml -content ($Response) -xpath "/BESAPI/$Type").Node

        foreach ($Item in $Items) {
            #Get Item Name
            $Name = $Item.Name

            #Query for the actual item
            $ItemRaw = invoke-webrequest -uri $Item.Resource -Headers ($ConnectHeaders) -method get

            #Pull the XML
            $ItemXML = (select-xml -content $ItemRaw.Content -xpath "/BES/$Type").node

            #Strip the modified date/time from the item
            $xml = New-Object System.Xml.XmlDocument
            $xml.PreserveWhitespace = $true
            $xml.LoadXml($ItemRaw.Content)
            $xml.PreserveWhitespace = $false

			
			
            foreach ($Node in $xml.SelectNodes("//BES//$Type//MIMEField")) {
                if ($Node.Name -eq "x-fixlet-first-propagation" -or $Node.Name -eq "x-fixlet-modification-time" -or $Node.Name -like "*bigfixme*") {
                    $xml["BES"]["$Type"].RemoveChild($Node) | out-null
                }
            }

            #Save Item to Disk
            $Path = (resolve-path "$OutDir\$Site\$(get-plural $Type)").path
            $FileName = "$(Remove-InvalidFileNameChars -Name $Name).bes"
            
            write-host "$Path\$FileName"
            $xml.Save("$Path\$FileName")
            
            (gc "$Path\$FileName") | ? {$_ -ne "`t`t"} | set-content "$Path\$FileName"
        }
    }
}

$ConnectHeaders = Get-BFConnectHeaders -Username $BFUsername -Password $BFPassword

foreach ($Site in $Sites.split(",")){
    Export-Content -Server $BFServer -ConnectHeaders $ConnectHeaders -Site $Site -OutDir $Outdir -Types $Types.split(",") -Clean

}