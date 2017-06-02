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
        $ServerModificationTime = $null
        $RepoModificationTime = $null

        $RepoXML = $Fixlet

        try {
            $RepoModificationTime = [datetime] (Get-BESMIMEField -XML $RepoXML -Name "x-fixlet-modification-time")
        } catch {}
        
        $GUID = Get-BESMIMEField -XML $Fixlet -Name "BES Sync GUID"
        
        $ServerItem = ($ServerContent | Where-Object {(Get-BESMIMEField -XML $_.xml -Name "BES Sync GUID") -eq $GUID})
        $ServerResource = $ServerItem.Resource
        
        try {
            $ServerModificationTime = [datetime] (Get-BESMIMEField -XML $ServerItem.xml -Name "x-fixlet-modification-time")
        } catch {}

        if ($RepoModificationTime -and $ServerModificationTime -and $RepoModificationTime -le $ServerModificationTime)  {
            write-verbose "Update for $ServerResource not required."
        } elseif ($ServerResource) {
            write-verbose "Updating $ServerResource with new Fixlet Information"
            Set-BESAPIResource -Credential $Credential -Resource $ServerResource -XML $RepoXML
        } else {
            write-verbose "Adding new Fixlet: $(Get-BESTitle $RepoXML)"
            Add-BESAPIResource -Credential $Credential -Server $Server -Site $Site -XML $RepoXML
        }
    }
}