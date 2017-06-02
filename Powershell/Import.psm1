import-module "$PSScriptRoot\BFRESTAPI.psm1" -force
import-module "$PSScriptRoot\Extract.psm1" -force

Function Get-BESRepoContents {
    param (
        $Repository
    )

    $Files = get-childitem -Path $Repository -Include "*.bes" -file -Recurse

    $RawContent = @()

    foreach ($File in $Files) {
        [XML] $XML = New-Object System.XML.XMLDocument
    
        $XML.Load($File)

        $RawContent += $XML  
    }

    return $RawContent
}

Function Import-BESRepoContents {
    param (
        $Credential,
        $Server,
        $Site,
        $Repository
    )

    $RepoContent = Get-BESRepoContents -Repository $Repository
    $ServerContent = Get-BESSiteContents -Credential $Credential -Server $Server -Site $Site

    foreach ($Fixlet in $RepoContent) {
        $RepoXML = $Fixlet
        
        $GUID = Get-BESMIMEField -XML $Fixlet -Name "BES Sync GUID"

        $ServerResource = ($ServerContent | Where-Object {(Get-BESMIMEField -XML $_.xml -Name "BES Sync GUID") -eq $GUID}).Resource
        
        if ($ServerResource) {
            write-verbose "Updating $ServerResource with new Fixlet Information"
            Set-BESAPIResource -Credential $Credential -Resource $ServerResource -XML $RepoXML
        } else {
            write-verbose "Adding new Fixlet: $(Get-BESTitle $RepoXML)"
            Add-BESAPIResource -Credential $Credential -XML $RepoXML
        }
    }
}