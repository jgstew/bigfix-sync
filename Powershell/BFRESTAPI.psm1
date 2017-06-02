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

Function Get-BESFixlets {
    param (
        $Credential,
        $Server,
        $Site
    )
    #Query server for items in site
    $Response = invoke-webrequest -uri "https://$($Server):52311/api/fixlets/custom/$Site" -Credential $Credential -method get

    #Parse XML for items
    write-output ((select-xml -content ($Response) -xpath "/BESAPI/Fixlet").Node)
}

Function Get-BESFiles {
    param (
        $Credential,
        $Server,
        $Site
    )

}

Function Get-BESAnalyses {
    param (
        $Credential,
        $Server,
        $Site
    )
    #Query server for items in site
    $Response = invoke-webrequest -uri "https://$($Server):52311/api/analyses/custom/$Site" -Credential $Credential -method get

    #Parse XML for items
    write-output ((select-xml -content ($Response) -xpath "/BESAPI/Analysis").Node)
}

Function Get-BESAPIDashboardData {
    param (
        $Credential,
        $Dashboard,
        $Variable
    )

    write-error "Get-BESAPIDashboardData: Not Implemented"

    #invoke-webrequest -uri $Resource -Credential $Credential -method get | out-null
}

Function Set-BESAPIDashboardData {
    param (
        $Credential,
        $Dashboard,
        $Variable,
        $Value
    )

    write-error "Set-BESAPIDashboardData: Not Implemented"

    invoke-webrequest -uri $Resource -Credential $Credential -method post | out-null
}

Function Set-BESAPIResource {
    param (
        $Credential,
        $Resource,
        [xml]$XML
    )
    
    invoke-webrequest -uri $Resource -Credential $Credential -method put -body $XML.InnerXML | out-null

}

Function Add-BESAPIResource {
    param (
        $Credential,
        $Server,
        $Site,
        [xml]$XML
    )
    
    invoke-webrequest -uri "https://$Server`:52311/api/import/custom/$Site" -Credential $Credential -method post -body $XML.InnerXML | out-null

}

Function Get-BESAPIResource {
    param (
        $Credential,
        $Resource
    )
    
    $ItemRaw = invoke-webrequest -uri $Resource -Credential $Credential -method get

    return ((select-xml -content $ItemRaw -xpath "/").Node)
}

Function Sanitize-BESAPIResource {
    param (
        [xml] $XML
    )

    $Content = $XML
    $Content = Remove-BESMIMEField -XML $Content -Name "x-fixlet-first-propagation"
    #$Content = Remove-BESMIMEField -XML $Content -Name "x-fixlet-modification-time"
    $Content = Remove-BESMIMEField -XML $Content -Name "*bigfixme*"
            
    write-output $Content
}

function Remove-BESMIMEField {
    param (
        [xml] $XML,
        [string] $Name
    )

    foreach ($Node in $xml.SelectNodes("BES/*/MIMEField")) {
        if ($Node.Name -like $Name) {
            $xml.SelectNodes("BES/*").RemoveChild($Node) | out-null
        }
    }
    
    write-output $XML
}

function Get-BESTitle {
    param (
        [xml] $XML
    )

    write-output $XML.SelectSingleNode("BES/*/Title").innertext
}

function Get-BESMIMEField {
    param (
        [xml] $XML,
        [string] $Name
    )

    $MimeFields = $XML.SelectNodes("BES/*/MIMEField") 

    #$MimeFields = @($XML.BES.Analysis.MIMEField,$xml.BES.Fixlet.MIMEField)
    
    $MIMEField = $MimeFields | where-object {$_.Name -like "$Name"}

    return $MIMEField.Value
}

function Add-BESMIMEField {
    param (
        [xml] $XML,
        [string] $Name,
        [string] $Value
    )
    [xml]$mimefield = @"
<MIMEField>
	<Name>$Name</Name>
	<Value>$Value</Value>
</MIMEField>
"@

    $NewNode = $xml.ImportNode($mimefield.MIMEField, $true)

    $xml.SelectSingleNode("BES/*").InsertBefore($NewNode, $XML.SelectSingleNode("BES/*/Domain")) | out-null
   
    return $XML
}

#BigFix Powershell Sync GUID