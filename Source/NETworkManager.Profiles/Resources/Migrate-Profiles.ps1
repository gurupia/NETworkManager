<#      
    Migrate NETworkManager profiles 
        from 2021.11.30.0 and before 
        to 2021.x.x.x and later
#>

[CmdletBinding()]
param (
    [Parameter(
        Position=0,
        Mandatory=$false,
        HelpMessage='Profile file or folder path')]    
    [String]$Path="$($env:APPDATA)\NETworkManager\Profiles",

    [Parameter(
        Position=1,
        Mandatory=$false,
        HelpMessage='Path of the NETworkManager.exe')]    
    [String]$NETworkManagerPath,

    [Parameter(
        Position=2,
        Mandatory=$false,
        HelpMessage='Version of NETworkManager')]    
    [String]$NETworkManagerVersion
)

Write-Host "=== NETworkManager ===`n" -ForegroundColor Green
Write-Host "Migrate profiles to version $NETworkManagerVersion`n"

Write-Host "If you use encrypted profiles:`n  1) Disable profile encryption for all encrypted profiles with the previous NETworkManager version`n     https://borntoberoot.net/NETworkManager/FAQ#how-to-disable-profile-file-encryption`n  2) Run this script to migrate the profiles`n  3) Re-enable profile encryption with the newest release of NETworkManager`n     https://borntoberoot.net/NETworkManager/FAQ#how-to-enable-profile-file-encryption`n" -ForegroundColor Yellow

$defaultValue = $Path
$prompt = Read-Host "Profile file or folder [$($defaultValue)] (Enter to continue | CTRL+C to cancel)"
$prompt = ($defaultValue,$prompt)[[bool]$prompt]

Write-Host ""

if(-not(Test-Path -Path $prompt -PathType Container))
{
    Write-Host "$prompt does not exist!" -ForegroundColor Red
    return
}

foreach($file in Get-ChildItem -Path $prompt -Filter "*.xml")
{
    # Check if the file has the latest format
    if(Select-String -Path $file.FullName -Pattern "<ProfileInfoSerializable>")
    {
        Write-Host "$($file.FullName) already has the latest format! [Skipped]"
        continue
    }
    
    Copy-Item $file.FullName -Destination "$($file.FullName).$(Get-Date -f yyyyMMdd_HHmmss).backup"

    $Content = Get-Content -Path $file.FullName -Raw
    $Content = $Content -replace "<ProfileInfo>","<ProfileInfoSerializable>"
    $Content = $Content -replace "</ProfileInfo>","</ProfileInfoSerializable>"
    $Content | Set-Content -Path $file.FullName

    [xml]$XmlDocument = Get-Content -Path $file.FullName

    $Groups = ($XmlDocument.ArrayOfProfileInfo.ProfileInfoSerializable | Group-Object Group)

    $xmlsettings = New-Object System.Xml.XmlWriterSettings
    $xmlsettings.Indent = $true
    $xmlsettings.IndentChars = "  "

    $XmlWriter = [System.XML.XmlWriter]::Create($file.FullName, $xmlsettings)

    $xmlWriter.WriteStartDocument()

    $xmlWriter.WriteStartElement("ArrayOfGroupInfoSerializable")

    foreach($Group in $Groups)
    {
        $xmlWriter.WriteStartElement("GroupInfoSerializable")

        $xmlWriter.WriteElementString("Name", $Group.Name)

        $xmlWriter.WriteStartElement("Profiles")

        foreach($Profile in $Group.Group)
        {
            $xmlWriter.WriteStartElement("ProfileInfoSerializable")
            $XmlWriter.WriteRaw($Profile.InnerXml)
            $xmlWriter.WriteEndElement() # ProfileInfoSerializable
        }

        $xmlWriter.WriteEndElement() # Profiles
        $xmlWriter.WriteEndElement() # GroupInfoSerializable
    }
    
    $xmlWriter.WriteEndElement() # ArrayOfGroupInfoSerializable

    $xmlWriter.WriteEndDocument()
    $xmlWriter.Flush()
    $xmlWriter.Close()

    Write-Host "$($file.FullName) successfully converted!" -ForegroundColor Green
}

Write-Host "`nScript completed!" -ForegroundColor Green

if(-not([String]::IsNullOrEmpty($NETworkManagerPath)))
{
    Write-Host "`nThe NETworkManager will be restarted afterwards!"
    $StartNETworkManager = $true
}

$x = Read-Host "`nPress enter to continue"

if($StartNETworkManager)
{
    Start-Process -FilePath $NETworkManagerPath
}
