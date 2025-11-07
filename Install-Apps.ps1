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

# --- Configuración del Registro (Log) ---
$LogFileName = "Installation_Log_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".txt"
$LogFilePath = Join-Path -Path $ScriptPath -ChildPath $LogFileName

try {
    # Inicia la transcripción (grabación) de toda la sesión de PowerShell.
    # El parámetro -Force permite sobrescribir si el archivo ya existe (aunque el timestamp lo evita).
    Start-Transcript -Path $LogFilePath -Force -Append
    Write-Host "Registro de sesión iniciado. Guardando salida en: $LogFilePath" -ForegroundColor DarkGray
    Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray
} catch {
    Write-Host "ADVERTENCIA: No se pudo iniciar el registro de la sesión." -ForegroundColor Red
}

# Ruta base donde se encuentran el script y los archivos de configuración
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Función para verificar y leer el archivo de configuración JSON
# Función para verificar y leer el archivo de configuración de texto plano (Lista de IDs)
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
        # Lee el contenido del archivo como una lista de líneas (IDs de Winget)
        $AppIDs = Get-Content -Path $FilePath -Encoding UTF8 -ErrorAction Stop | Where-Object { $_.Trim() -ne "" }
        
        # Convierta la lista de IDs de texto a un formato de objetos que el script pueda usar.
        # En este formato simplificado, el 'name' es igual al 'wingetId'.
        $Apps = @()
        foreach ($ID in $AppIDs) {
            $Apps += [PSCustomObject]@{
                name     = $ID
                wingetId = $ID
            }
        }
        
        if ($Apps.Count -gt 0) {
            return $Apps
        } else {
            Write-Error "ERROR: El archivo '$FileName' está vacío o no contiene IDs de Winget válidos."
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
    
    $TotalApps = $Apps.Count
    $Counter = 0
    
    Write-Host "`n--- Iniciando la instalación de $TotalApps aplicaciones... ---" -ForegroundColor Yellow
    
    foreach ($App in $Apps) {
        $Counter++
        $AppName = $App.name
        $WingetId = $App.wingetId
        
        # Muestra el contador (ej: [1 de 5])
        Write-Host "`n[$Counter de $TotalApps] --> Intentando instalar: $AppName (ID: $WingetId)..." -ForegroundColor Cyan
        
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

# Función para crear un punto de restauración del sistema
function New-RestorePoint {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Description
    )
    
    Write-Host "`n--> Creando Punto de Restauración... Por favor, espera." -ForegroundColor DarkYellow
    
    try {
        # El comando checkpoint-computer crea el punto de restauración.
        Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Host "    [OK] Punto de restauración '$Description' creado con éxito." -ForegroundColor Green
        return $true
    } catch {
        Write-Host "    [FALLO] No se pudo crear el punto de restauración. Asegúrate de que el 'Servicio de instantáneas de volumen' (VSS) esté activo." -ForegroundColor Red
        Write-Host "    Mensaje de error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# -----------------------------------------------------------------------------
# DEFINICIÓN DEL MENÚ
# -----------------------------------------------------------------------------

# El HashTable contiene la información para el menú:
# Clave: Número de opción.
# Valor: Un PSObject con 'Label' (lo que se muestra en el menú) y 'ConfigFile' (el list a cargar).
# R  Opción para crear el punto de restauración
$MenuOptions = @{
    R = @{ Label = "Crear un Punto de Restauración del Sistema"; ConfigFile = "RESTORE_POINT" }
    
    1 = @{ Label = "Instalar apps de Ofimática/Comunes"; ConfigFile = "office_apps.list" }
    2 = @{ Label = "Instalar apps de Desarrollo (Dev)"; ConfigFile = "dev_apps.list" }
    # ... otras opciones ...
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
        # --------------------------------------------------------
        # MANEJO DE LA OPCIÓN 'R' (PUNTO DE RESTAURACIÓN)
        # --------------------------------------------------------
        if ($Option -eq "R" -or $Option -eq "r") {
            $ValidSelectionMade = $true
            $RestorePointName = "worksatation-restore-point-($((Get-Date).ToString('yyyyMMdd_HHmmss')))"
            
            # Ejecutar la función de punto de restauración
            if (New-RestorePoint -Description $RestorePointName) {
                Write-Host "Continúa seleccionando las apps que deseas instalar." -ForegroundColor Yellow
            } else {
                Write-Host "AVISO: La instalación continuará, pero el punto de restauración falló." -ForegroundColor DarkRed
            }
            continue # Vuelve al inicio del bucle para que el usuario pueda seleccionar apps
        }

        # ------------------------------------------------
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
        
        # --- Detener el Registro (Log) ---
        if ($Host.UI.TranscribeState -eq "Started") {
            Stop-Transcript
            Write-Host "El registro de la sesión ha sido guardado en: $LogFilePath" -ForegroundColor DarkGray
        }
        # -----------------------------------
    }
} while (-not $ExitLoop)
