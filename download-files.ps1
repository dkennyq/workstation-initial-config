# Script para descargar, descomprimir y ejecutar el instalador principal.
# Debe ejecutarse en PowerShell como Administrador.

# 1. Configuración de Variables
$RepoName = "workstation-initial-config"
$ZipFileName = "$RepoName.zip"
$TargetDir = Join-Path -Path $env:TEMP -ChildPath $RepoName # Usamos la carpeta TEMP para descargas temporales

# 2. Definición de URLs y Rutas
# El enlace de descarga de GitHub ZIP. Reemplaza 'main' si usas otra rama.
$URL = "https://github.com/dkennyq/workstation-initial-config/archive/refs/heads/main.zip"
$DownloadPath = Join-Path -Path $env:TEMP -ChildPath $ZipFileName # Ruta completa del ZIP descargado

# 3. Descarga y Preparación
Write-Host "Descargando $ZipFileName desde GitHub..." -ForegroundColor Cyan

# Creamos la carpeta de destino y forzamos la descarga del ZIP
mkdir $TargetDir -Force
Invoke-WebRequest -Uri $URL -OutFile $DownloadPath

# 4. Descompresión y Navegación
Write-Host "Descomprimiendo archivos..." -ForegroundColor DarkYellow

# La carpeta extraída de GitHub siempre tiene el sufijo '-main' o la rama.
$ExtractedFolderName = "$RepoName-main"
$SourcePath = Join-Path -Path $env:TEMP -ChildPath $ExtractedFolderName

# Descomprimir el ZIP
Expand-Archive -Path $DownloadPath -DestinationPath $env:TEMP -Force

# Navegar a la carpeta descomprimida (donde están los scripts)
cd $SourcePath

# 5. Ejecución
Write-Host "¡Instalador listo! Ejecutando el menú principal..." -ForegroundColor Green
Write-Host "--------------------------------------------------------" -ForegroundColor White

# Ejecutar el script principal de instalación
.\Install-Apps.ps1
