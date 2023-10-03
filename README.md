
# LibreTranslate Powershell Auto-Translator

Dieses Powershell Script dient dem automatisierten Übersetzen von Dateien, welche von der LibreTranslate [File API](https://de.libretranslate.com/docs/#/%C3%BCbersetzen/post_translate_file) unterstützt werden.

Dieses Script basiert auf PowerShell 7.

# Installation
Kopiere die Dateien an einen Ort deiner Wahl und führe das Script initial aus. Alle Ordner werden automatisch generiert.

# Konfiguration
Die Konfiguration wird in dem Ordner "config" als config.json (JSON Format) geführt.
Die folgenden Parameter sind derzeit unterstützt
```
{
    "translator_url": "http://<<url>>",
    "source_dir": "./input/",
    "target_dir": "./output/",
    "source_lang": "de",
    "target_lang": ["en", "tr"]
}
```

* translator_url => [String] Der Schlüssel "translator_url" dient der definition des Zielserver (Bsp. http://translate.jr.local:5000).
* source_dir => [String] Der Schlüssel "source_dir" beinhaltet alle noch nicht übersetzten Dateien. Jede fertig bearbeitete Datei wird in den Ordner "target_dir/source_lang" verschoben, sofern es bei der Umwandlung keinen Fehler gibt
* target_dir => [String] Der Schlüssel "target_dir" beinhaltet alle Übersetzten Dateien inkl. der Original Daten
* source_lang => [String] Der Schlüssel "source_lang" beinhaltet die Sprache der Ausgansdaten (Source_dir). Diese muss zwingend korrekt angegeben sein um eine Übersetzung zu erhalten
* target_lang => [Array] Der Schlüssel "target_lang" beinhaltet ein Array mit den Kürzeln der Zielsprachen (de => Deutsch, tr = Türkisch, en = Englisch usw.)

# Verwendung
Das Script muss erstmalig aufgerufen werden um alle Ordner anzulegen. Sobald geschehen schaut das Script im Src Ordner nach Dateien und versucht diese (sofern ein unterstütztes Dateiformat vorliegt) zu Übersetzen.


