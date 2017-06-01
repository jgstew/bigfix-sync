$PSScriptRoot = "."

import-module ".\Extract.psm1" -force
import-module ".\BFRESTAPI.psm1" -force
import-module ".\Import.psm1" -force

$ConfigXML = get-item "$PSScriptRoot\Config.xml"

$Config = (Get-Config $ConfigXML.FullName).config

$secpasswd = ConvertTo-SecureString ($Config.operator.password) -AsPlainText -Force

$Credential = New-Object System.Management.Automation.PSCredential ($Config.operator.username, $secpasswd)
$Server = $Config.server

foreach ($Site in $Config.Sites.Site) {
    $SiteName = $Site.Name
    $Outdir = $Site.Path
    
    Extract-BESSiteContents -Credential $Credential -Server $Server -Site $SiteName -OutDir $OutDir
}

