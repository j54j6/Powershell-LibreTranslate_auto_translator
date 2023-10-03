<# Copyright 2023 - Justin Ritter #>
<# Dieses Script dient dem automatisierten uebersetzen von Word Dokumenten in eine definierte Zielsprache #>
<#>
<# Laden der Konfigurationsdatei (Standard: ./config/config.json) #>

<# ---------------   WICHTIG : DIESES SCRIPT BENÖTIGT POWERSHELL 7 oder höher! --------------------#>
$configFile = "./config/config.json"
[array]$allowed_file_types = ".docx", ".txt", ".odt", ".odp", ".pptx", ".epub", ".html"

Write-Debug("Lese Config File von definiertem Pfad...")

#Pruefe ob die angegebene Konfigurationsdatei exisitert
if(!(Test-Path $configFile -PathType Leaf))
{
    Write-Error("Die definierte Config Datei $configFile existiert nicht. Bitte gebe den korrekten Pfad an!")
    Exit-PSHostProcess
}
#Lade die Konfigurationsdatei in ein PSO für die weiterverwendung
try {
    $config=Get-Content -Path $configFile | ConvertFrom-Json
}
catch {
    Write-Error("Fehler beim lesen der Konfigurationsdatei! - Bitte das Format ueberpruefen!")
    Exit-PSHostProcess
}
Write-Debug("Config Datei wurde geladen... - Prüfe Verbindung zum translator unter $config.translator_url")

#Prüfe ob ein gegebener Ordner exisitert inkl. Switch für Programmabbruch
function dir_exist 
{
    param(
        [Parameter(Mandatory=$true)]
        [psobject]$dir,
        
        [bool]$errorOnFail = $false
    )

    if(!(Test-Path $dir))
    {
        if($errorOnFail)
        {
            Write-Error("Der angegebene Ordner $dir existiert nicht auf dem Dateisystem!")
            Exit-PSHostProcess
        }
        else {
            return $false
        }
    }
    else
    {
        return $true
    }
}

#Diese Funktion dient dem pre_run_check. Hier werden alle benötigten Konfigurationsparameter geprüft.
#
#Der Parameter $config (Typ PSO) beinhaltet die als PSO geladenen Konfiguration aus der Datei $configFile
#Der Parameter $errorID (Typ int16) dient der automatisierten Fehlerkorrektur. Dieser kann verwendet werden um im loop mode diese Funktion erneut aufzurufen ohne in eine Schleife zu kommen. 
#Der ErrorCode wird an der jeweiligen Code Stelle (Prüfung) angegeben.
function pre_run_checks
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [psobject]$config_f, 
        [int]$error_id
    )

        #Prüfe ob der benötigte Punkt in der Konfigurationsdatei vorhanden ist
        if(![bool]($config_f.PSobject.Properties.name -match "translator_url"))
        {
            Write-Error("Der zwingende Konfigurationsparameter 'translator_url' ist in der gegebenen Konfigurationsdatei nicht vorhanden!")
            return $false
        }

        $server_url = $config_f.translator_url
        #Prüfe ob der Server erreicht werden kann...
        try
        {
            if((Invoke-WebRequest -Uri $server_url -UseBasicParsing -DisableKeepAlive).StatusCode)
            {
                Write-Debug("Server vergfuegbar")
            }
        }
        catch [Net.WebException]
        {
            Write-Error("Der angegebene Server $server_url, ist nicht erreichbar! - Bitte Verbindung pruefen!")
            return $false
        }

        #Prüfe ob die benötigten ordner vorhanden sind
        if(![bool]($config_f.PSobject.Properties.name -match "source_dir") -or ![bool]($config_f.PSobject.Properties.name -match "target_dir"))
        {
            Write-Error("Die Konfigurationsdatei beinhaltet nicht die beiden erwarteten Werte 'source_dir' und/oder 'target_dir. Diese werden benoetigt um Dateien einzulesen und abzuspeichern.")
            return $false
        }

        #Prüfe ob die angegebenen Ordner auf dem System existieren - Source Dir - ERROR ID = 1000
        $source_dir = $config_f.source_dir
        $source_dir = [IO.Path]::GetFullPath($source_dir)

        if(!(Test-Path $source_dir))
        {
            Write-Host("Source Ordner existiert nicht! - Erstelle Ordner unter $source_dir")
            try {
                New-Item -ItemType Directory -Path $source_dir
            }
            catch {
                Write-Error("Unerwarteter Fehler beim erstellen des Source Ordner!")
                return $false
            }
            dir_exist -dir $source_dir -errorOnFail $true
        }

        #Prüfe ob die angegebenen Ordner auf dem System existieren - Target Dir - ERROR ID = 1001
        $target_dir = $config_f.target_dir
        $target_dir = [IO.Path]::GetFullPath($target_dir)
        if(!(Test-Path $target_dir) -and ($error_id -ne 1001))
        {
            Write-Host("Target Ordner existiert nicht! - Erstelle Ordner unter $target_dir")
            try {
                New-Item -ItemType Directory -Path $target_dir
            }
            catch {
                Write-Error("Unerwarteter Fehler beim erstellen des Target Ordner!")
                return $false
            }
            dir_exist -dir $target_dir -errorOnFail $true
        }

        #Prüfe ob der Ordner für die original Files bereits vorhanden ist
        $drop_dir = $target_dir + $config_f.source_lang
        $drop_dir = [IO.Path]::GetFullPath($drop_dir)
        if(!(Test-Path $drop_dir) -and ($error_id -ne 1003))
        {
            Write-Host("Drop Ordner existiert nicht! - Erstelle Ordner unter $drop_dir")
            try {
                New-Item -ItemType Directory -Path $drop_dir
            }
            catch {
                Write-Error("Unerwarteter Fehler beim erstellen des Target Ordner!")
                return $false
            }
            dir_exist -dir $drop_dir -errorOnFail $true
        }


        #Prüfe ob die sub Ordner existieren (Target dir - lang ordner - zum Beispiel für Englisch => ./target_dir/en)
        [array]$langs = $config.target_lang
        #Iteriere über alle Sprachen und prüfe ob 
        foreach ($lang in $langs)
        {
            $lang_dir = $target_dir + $lang
            $lang_dir = [IO.Path]::GetFullPath($lang_dir)
            if(!(Test-Path $lang_dir))
            {
                Write-Host("Sprach Ordner existiert nicht! - Erstelle Ordner unter $lang_dir")
                try {
                    New-Item -ItemType Directory -Path $lang_dir
                }
                catch {
                    Write-Error("Unerwarteter Fehler beim erstellen des Sprach Ordner!")
                    return $false
                }
                dir_exist -dir $target_dir -errorOnFail $true
            }
        }
        return $true
}

$pre_check = pre_run_checks -config_f $config

if(!$pre_check)
{
    Write-Host("Fehler bei Pre Check! - Siehe log")
}

Write-Host("Pre Check abgeschlossen - Pruefe Src Ordner")

#Prüfe ob Dokumente zum Übersetzen bereit liegen
$srcInfo = Get-ChildItem $config.source_dir | Measure-Object

if($srcInfo.Count -eq 0)
{
    Write-Host("Es gibt keine Dokumente die übersetzt werden müssen. Programm beendet")
    return
}
$fC = $srcInfo.Count

#Starte Übersetzung der vorhandenen Dateien
Write-Host("Im Src Ordner befinden sich $fC Datei(en). Starte Konvertierung")

#Iteriere über alle Dateien
Get-ChildItem $config.source_dir |

Foreach-Object {

    #Pruefe ob Word Dokument (docx) und konvertiere mit Server
    $file_name_path = $_.FullName
    $file_name = $_.BaseName
    $extn = [IO.Path]::GetExtension($file_name_path)
    
    #Prüfe ob der verwendete Dateityp nutzbar ist (Anhand der Extension)
    if(!($allowed_file_types -contains $extn))
    {
        Write-Host("Die Datei $file_name wird nicht uebersetzt. Die Datei ist nicht im korrekten Format!")
        continue
    }

    $target_dir = $config.target_dir
    $target_dir = [IO.Path]::GetFullPath($target_dir)

    [array]$langs = $config.target_lang

    $error_during_translate = $false
    #Iteriere über alle Zielsprachen um die Datei in diesen verfuegbar zu machen
    foreach($lang in $langs)
    {

        $src_lang = $config.source_lang
        $Uri = $config.translator_url + "/translate_file";
        $Form = @{
        source  = "$src_lang"
        target   = "$lang"
        file     = Get-Item -Path "$file_name_path"
        }
        #Passe die Zieldatei an und füge den lang Stempel am Ende an
        $target_file_path = $target_dir + $lang + "\" + "$file_name" + "_" + "$lang" + "$extn"

        #Prüfe ob die Datei bereits für diese Sprache Übersetzt worden ist. Falls dem so ist, ist keine erneute Ressourcenbelegung notwendig - Skip
        if((Test-Path -Path $target_file_path -PathType Leaf))
        {
            Write-Host("SKIP | Die Datei $file_name wurde bereits in die Sprache $lang Uebersetzt.")
            continue
        }

        #Sende den Request zum Übersetzen an den in der Config definierten Server
        try {
            $Result = Invoke-WebRequest -Uri $Uri -Method Post -Form $Form

            #Prüfe ob der Status Code 200 ist (OK) - falls nicht stoppe die Verarbeitung
            if($Result.StatusCode -eq "200")
            {
                Write-Host("Datei Uebersetzt - Download nach $target_file_path")
                Write-Debug("Datei $file_name wurde erfolgreich Uebersetzt.")
                #Speichere die Datei auf dem System im definierten lang Ordner ab
                try {
                    $download_url = $Result| ConvertFrom-Json
                    $download_url = $download_url.translatedFileUrl
                    
                    Invoke-WebRequest -Uri "$download_url" -OutFile "$target_file_path"
                }
                catch {
                    $error_during_translate = $true
                    Write-Error("Fehler beim herunterladen der Datei $file_name")
                    $_.Exception 
                    continue
                }
            }
            else
            {
                $error_during_translate = $true
                Write-Error("Fehler beim uebersetzen der Datei $file_name")
                $_.Exception 
                continue
            }
        }   
        catch {
            $error_during_translate = $true
            Write-Error("Fehler beim Übersetzen der Datei $file_name")
            $_.Exception 
            continue
        }
    }

    #Zur Protokollierungs vereinfachung wird am Ende jeder Iteration des Lang Array (s. Config) zusammengefasst, ob Fehler aufgetreten sind
    if($error_during_translate)
    {
        #Gebe aus das ein Fehler entstanden ist und setze den Error switch für die nächste Datei auf $false
        Write-Error("Beim Uebersetzen der Datei $file_name sind ein oder mehrere Fehler aufgetreten!")
        $error_during_translate = $false
        continue
    }
    else
    {
        #Bestätige die Fehlerfreie Übersetzung und setze den Switch error auf $false
        $error_during_translate = $false
        Write-Host("Die Datei $file_name wurde in die gewuenschten Sprachen Uebersetzt und in den entsprechenden Ordnern gesichert!")
        
        #Entferne die Datei aus dem Intput Ordner und verschiebe diese in den DROP Ordner (Drop Ordner = target_dir + src_lang)
        try {
            $drop_dir = $target_dir + $config.source_lang
            $drop_dir = [IO.Path]::GetFullPath($drop_dir)
            Move-Item -Path $file_name_path -Destination $drop_dir
            Write-Host("DROP | Die Datei $file_name ist fertig bearbeitet")
        }
        catch {
            Write-Error("Fehler beim verschieben der Datei $file_name in den Drop Ordner! - Bitte manuell erledigen!")
        }
        continue
    }
}
