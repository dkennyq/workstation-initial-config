# Requires -RunAsAdministrator
#------------------------------------------------------------------------------
# Script para Instalación Desatendida de Aplicaciones con Winget
# Creado por [Gemini AI]
#
# Este script lee la configuración de las aplicaciones desde archivos JSON en el 
# misma ruta y presenta un menú interactivo para seleccionar qué grupos de apps 
# instalar.
#
# **PRE-REQUISITO:** Asegúrate de que Winget esté instalado y disponible en el PATH.
# Ejecutar este script requiere permisos de administrador.
#------------------------------------------------------------------------------

# Ruta base donde se encuentran el script y los archivos de configuración
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Función para verificar y leer el archivo de configuración JSON
function Read-AppConfig {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FileName
    )
    $FilePath = Join-Path -Path $ScriptPath -ChildPath $FileName
    
    if (-not (Test-Path $FilePath)) {
        Write-Error "ERROR: Archivo de configuración '$FileName' no encontrado en '$ScriptPath'."
        return $null
    }
    
    try {
        # Lee el contenido del archivo JSON
        # Forzamos la lectura como UTF8 para evitar errores de codificación/BOM con ConvertFrom-Json
        $Config = Get-Content -Path $FilePath -Encoding UTF8 -Raw | ConvertFrom-Json -ErrorAction Stop
        
        # Validación simple de la estructura
        if ($Config -is [System.Collections.Generic.IDictionary[string,object]] -and $Config.ContainsKey('apps')) {
            return $Config.apps
        } else {
            Write-Error "ERROR: El archivo '$FileName' tiene un formato JSON inválido o le falta la clave 'apps'."
            return $null
        }
    } catch {
        Write-Error "ERROR al procesar el archivo '$FileName': $($_.Exception.Message)"
        return $null
    }
}

# Función principal para ejecutar la instalación con Winget
function Install-Apps {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Apps
    )
    
    Write-Host "`n--- Iniciando la instalación de $($Apps.Count) aplicaciones... ---" -ForegroundColor Yellow
    
    foreach ($App in $Apps) {
        $AppName = $App.name
        $WingetId = $App.wingetId
        
        Write-Host "`n--> Intentando instalar: $AppName (ID: $WingetId)..." -ForegroundColor Cyan
        
        # Ejecución de winget:
        # /s para desatendido, /accepteula para aceptar el acuerdo de licencia, 
        # /h para modo silencioso si el instalador lo soporta.
        # Winget buscará el paquete por el ID.
        try {
            winget install $WingetId --silent --accept-package-agreements --accept-source-agreements
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    [OK] Instalación de $AppName completada con éxito." -ForegroundColor Green
            } else {
                Write-Host "    [FALLO] Winget terminó con código de error $LASTEXITCODE para $AppName." -ForegroundColor Red
            }
        } catch {
            Write-Host "    [ERROR FATAL] No se pudo ejecutar winget para $AppName. Mensaje: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    Write-Host "`n--- Proceso de instalación finalizado. ---" -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# DEFINICIÓN DEL MENÚ
# -----------------------------------------------------------------------------

# El HashTable contiene la información para el menú:
# Clave: Número de opción.
# Valor: Un PSObject con 'Label' (lo que se muestra en el menú) y 'ConfigFile' (el JSON a cargar).
$MenuOptions = @{
    1 = @{ Label = "Instalar apps de Ofimática/Comunes"; ConfigFile = "office_apps.json" }
    2 = @{ Label = "Instalar apps de Desarrollo (Dev)"; ConfigFile = "dev_apps.json" }
    # -------------------------------------------------------------------------
    # COMENTARIO PARA AÑADIR NUEVAS OPCIONES DE MENÚ:
    # -------------------------------------------------------------------------
    # Para añadir una nueva opción de menú (ej: Opción 3):
    # 1. Crea un nuevo archivo JSON (ej: 'multimedia_apps.json') con la lista de apps.
    # 2. Añade una nueva entrada al HashTable $MenuOptions siguiendo el patrón:
    #    3 = @{ Label = "Instalar apps de Multimedia"; ConfigFile = "multimedia_apps.json" }
    # Asegúrate de usar un número de opción que no esté ya en uso.
    # -------------------------------------------------------------------------
}

# Opción especial para instalar TODO. Requiere que existan todos los archivos configurados.
$InstallAllOption = $MenuOptions.Count + 1
$MenuOptions.$InstallAllOption = @{ Label = "Instalar TODAS las configuraciones (${InstallAllOption})"; ConfigFile = "ALL" }

# -----------------------------------------------------------------------------
# LÓGICA DE INTERACCIÓN DEL MENÚ
# -----------------------------------------------------------------------------

function Show-Menu {
    Write-Host "=======================================================" -ForegroundColor White
    Write-Host "   ⚙️ INSTALADOR INTERACTIVO DE APLICACIONES (Winget)" -ForegroundColor Green
    Write-Host "=======================================================" -ForegroundColor White
    
    # Muestra las opciones estándar
    $MenuOptions.GetEnumerator() | Sort-Object Name | ForEach-Object {
        if ($_.Name -ne $InstallAllOption) {
            Write-Host "$($_.Name). $($_.Value.Label)" -ForegroundColor Cyan
        }
    }
    
    # Muestra la opción de Instalar Todo
    Write-Host "$InstallAllOption. $($MenuOptions.$InstallAllOption.Label)" -ForegroundColor Yellow
    
    Write-Host "0. Salir/Cancelar" -ForegroundColor Red
    Write-Host "-------------------------------------------------------" -ForegroundColor White
    Write-Host "Opción 'Varios': Puedes ingresar múltiples opciones separadas por coma (ej: 1,2)" -ForegroundColor DarkGray
    Write-Host "-------------------------------------------------------" -ForegroundColor White
}

# Bucle principal del script
do {
    Show-Menu
    $Selection = Read-Host "Por favor, ingresa el número de la opción o varias opciones (ej: 1,2)"
    
    # Divide la entrada por comas para manejar opciones múltiples
    $SelectedOptions = $Selection -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    
    # Si la selección está vacía, repite el bucle
    if (-not $SelectedOptions) {
        Write-Host "`nERROR: Selección inválida. Por favor, intenta de nuevo.`n" -ForegroundColor Red
        continue
    }

    # Si se selecciona '0', salimos
    if ($SelectedOptions -contains "0") {
        Write-Host "`nSaliendo del instalador. ¡Adiós!" -ForegroundColor Yellow
        break
    }
    
    # Lista para recolectar todas las apps de las opciones seleccionadas
    $AppsToInstall = @()
    $ValidSelectionMade = $false
    
    foreach ($Option in $SelectedOptions) {
        if ($MenuOptions.ContainsKey([int]$Option)) {
            $ValidSelectionMade = $true
            $ConfigInfo = $MenuOptions.[int]$Option
            
            # Caso "Instalar TODO"
            if ($ConfigInfo.ConfigFile -eq "ALL") {
                Write-Host "`nOpción 'Instalar TODAS' seleccionada. Cargando todos los archivos de configuración..." -ForegroundColor Yellow
                # Recorre todas las opciones estándar y carga sus apps
                $MenuOptions.GetEnumerator() | Sort-Object Name | ForEach-Object {
                    if ($_.Name -ne $InstallAllOption) {
                        $ConfigFile = $_.Value.ConfigFile
                        Write-Host "  -> Cargando apps de: $ConfigFile" -ForegroundColor DarkYellow
                        $Apps = Read-AppConfig -FileName $ConfigFile
                        if ($Apps) {
                            $AppsToInstall += $Apps
                        }
                    }
                }
                # Una vez que se procesa 'ALL', no procesamos más opciones en este ciclo.
                break 
            }
            # Caso opciones individuales (1, 2, etc.)
            else {
                Write-Host "`nOpción '$Option': Cargando apps desde $($ConfigInfo.ConfigFile)..." -ForegroundColor DarkYellow
                $Apps = Read-AppConfig -FileName $ConfigInfo.ConfigFile
                if ($Apps) {
                    $AppsToInstall += $Apps
                }
            }
        }
    }
    
    if (-not $ValidSelectionMade) {
        Write-Host "`nERROR: Opción(es) no reconocida(s). Por favor, intenta de nuevo.`n" -ForegroundColor Red
        continue
    }
    
    # Elimina duplicados antes de instalar (basado en el wingetId)
    $UniqueApps = $AppsToInstall | Select-Object -Unique -Property wingetId
    
    if ($UniqueApps.Count -gt 0) {
        Write-Host "`nTotal de aplicaciones únicas a instalar: $($UniqueApps.Count)" -ForegroundColor Green
        # Inicia la instalación
        Install-Apps -Apps $UniqueApps
    } else {
        Write-Host "`nNo se encontraron aplicaciones válidas para instalar en las opciones seleccionadas.`n" -ForegroundColor Red
    }
    
    # Pregunta al usuario si desea hacer otra instalación
    $Continue = Read-Host "`n¿Desea realizar otra instalación? (S/N)"
    if ($Continue -notmatch "^[Ss]") {
        Write-Host "`nSaliendo del instalador. ¡Adiós!" -ForegroundColor Yellow
        $ExitLoop = $true
    }
} while (-not $ExitLoop)
