Function Extract-BESSiteContents {
    param (
        $Credential,
        $Server,
        $Site,
        $OutDir
    )

    $Contents = Get-BESSiteContents -Credential $Credential -Server $Server -Site $Site

    new-item $OutDir -ItemType directory -ErrorAction SilentlyContinue

    foreach ($Fixlet in $Contents) {
        $Title = Remove-InvalidFileNameChars ((Get-BESTitle -XML $Fixlet).innertext)

        set-content -Value (Format-XML $Fixlet) -Path "$OutDir\$Title.bes"
    }

}

function Format-XML {
    Param (
        [XML] $XML
    ) 

    $sw=New-Object system.io.stringwriter 
    $writer=New-Object system.xml.xmltextwriter($sw) 
    $writer.Formatting = [System.xml.formatting]::Indented 
    $XML.WriteContentTo($writer) 
    $sw.ToString() 
}

Function Get-BESSiteContents {
    param (
        $Credential,
        $Server,
        $Site
    )

    $RawContent = @()
    $RawContent += (Get-BESFixlets -Credential $Credential -Server $Server -Site $Site)
    $RawContent += (Get-BESAnalyses -Credential $Credential -Server $Server -Site $Site)

    $SanitizedContent = @()

    foreach ($Item in $RawContent) {
        $FixletContent = Get-BESAPIResource -Resource $Item.Resource -Credential $Credential
        $FixletContent = Sanitize-BESAPIResource $FixletContent

        if (!(Get-BESMIMEField -XML $FixletContent -Name "BES Sync GUID")) {
            $FixletContent = Add-BESMIMEField -XML $FixletContent -Name "BES Sync GUID" -Value (new-guid).guid
        }
        
        $SanitizedContent += $FixletContent
    }

    return $SanitizedContent
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

function Get-Config {
    param (
        $Path
    )

    [XML] $XML = New-Object System.XML.XMLDocument
    
    $XML.Load($Path)

    write-output $XML    
}