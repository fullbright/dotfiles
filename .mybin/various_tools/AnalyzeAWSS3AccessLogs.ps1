# Définir le chemin du dossier contenant les fichiers .txt
$folderPath = "C:\myOfflineDATA\essilor-rxit-logs-analysis"

# Définir le chemin du fichier de sortie
$outputFile = "C:\myOfflineDATA\essilor-rxit-logs-analysis\resultats.csv"

# Initialiser ou vider le fichier de sortie
if (Test-Path $outputFile) {
    Remove-Item $outputFile
}

# Récupérer tous les fichiers .txt dans le dossier
Get-ChildItem -Path $folderPath -Filter "*.txt" | ForEach-Object {
    # Lire chaque fichier
    Get-Content $_.FullName | ForEach-Object {
        # Diviser chaque ligne par l'espace
        $splitLine = $_ -split ' '
        # Joindre les éléments séparés par une virgule ou autre séparateur si nécessaire
        $joinedLine = $splitLine -join ','
        # Ajouter la ligne transformée au fichier de sortie
        Add-Content -Path $outputFile -Value $joinedLine
    }
}