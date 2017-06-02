Function Extract-BESSiteContents {
    param (
        $Credential,
        $Server,
        $Site,
        $OutDir
    )

    $Contents = (Get-BESSiteContents -Credential $Credential -Server $Server -Site $Site -UpdateGUID).XML

    foreach ($Fixlet in $Contents) {
        $Title = Remove-InvalidFileNameChars (Get-BESTitle -XML $Fixlet)

        if (test-path "$OutDir\$Title.bes") {
            $StoreTime = $Null
            $ServerTime = $Null

            try {
                $StoreTime  = [datetime] (Get-BESMIMEField -XML $Fixlet -Name "x-fixlet-modification-time")
                $ServerTime = [datetime]  (Get-BESMIMEField -XML ([xml](get-content "$OutDir\$Title.bes")) -Name "x-fixlet-modification-time")
            } catch {}

            if ($ServerTime -and $StoreTime -and $StoreTime -ge $ServerTime) {
                continue;
            }
        }

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
        $Site,
        [switch]$UpdateGUID
    )

    $RawContent = @()
    $RawContent += (Get-BESFixlets -Credential $Credential -Server $Server -Site $Site)
    $RawContent += (Get-BESAnalyses -Credential $Credential -Server $Server -Site $Site)

    $SanitizedContent = @()

    foreach ($Item in $RawContent) {
        $FixletContent = Get-BESAPIResource -Resource $Item.Resource -Credential $Credential

        # Does the Fixlet have a Sync GUID?
        if ($UpdateGUID -and !(Get-BESMIMEField -XML $FixletContent -Name "BES Sync GUID")) {
            $FixletContent = Add-BESMIMEField -XML $FixletContent -Name "BES Sync GUID" -Value (new-guid).guid
            
            #Update the Fixlet
            Set-BESAPIResource -Resource $Item.Resource -Credential $Credential -XML $FixletContent
        }

        $FixletContent = Sanitize-BESAPIResource $FixletContent

        $SanitizedContent += @{
            Resource = $Item.Resource
            XML = $FixletContent
        }
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