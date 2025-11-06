# ⚙️ WorkStation Initial Setup (Winget Scripts)

Este repositorio contiene scripts de **PowerShell** y archivos de configuración **JSON** diseñados para automatizar la instalación desatendida de aplicaciones comunes en Windows 11 utilizando el gestor de paquetes **Winget**.

El objetivo es simplificar la configuración inicial de nuevas máquinas de trabajo o desarrollo.

---

## 🚀 Empezando

Sigue estos pasos para poner en marcha el instalador en tu nueva estación de trabajo.

### 📋 Prerrequisitos

Asegúrate de que tu sistema cumple con lo siguiente:

* **Sistema Operativo:** Windows 11 (compatible con Windows 10 con Winget instalado).
* **Winget:** El Administrador de Paquetes de Windows debe estar instalado y disponible.
* **Permisos de Administrador:** El script debe ejecutarse con permisos de administrador.

### 💾 Instalación (Uso)

1.  **Clonar o Descargar:** Clona o descarga el contenido completo de este repositorio en una carpeta local de la máquina de destino (ej: `C:\Setup`).

2.  **Ejecutar como Administrador:**
    * Abre el menú de Windows y busca **PowerShell**.
    * Haz clic derecho en "Windows PowerShell" y selecciona **"Ejecutar como administrador"**.

3.  **Navegar a la carpeta:** En PowerShell, navega a la ruta donde guardaste los archivos:
    ```powershell
    cd C:\ruta\a\tu\carpeta\
    ```

4.  **Ejecutar el Script:**
    ```powershell
    .\Install-Apps.ps1
    ```

5.  **Seleccionar Opciones:** El script mostrará un menú interactivo. Ingresa la opción deseada (ej: `1` para Ofimática) o varias opciones separadas por coma (ej: `1,2`) para instalar múltiples grupos.

---

## 📁 Estructura del Repositorio

| Archivo/Directorio | Descripción |
| :--- | :--- |
| **`Install-Apps.ps1`** | El script principal de PowerShell. Contiene el menú interactivo, la lógica de lectura de JSON y la ejecución de `winget`. |
| **`office_apps.json`** | Archivo de configuración JSON con la lista de apps comunes (Slack, Teams, Adobe Reader, 7zip, Notepad++, etc.). |
| **`dev_apps.json`** | Archivo de configuración JSON con la lista de apps de desarrollo (VS Code, Git, Python, etc.). |
| `README.md` | Este archivo. |

---

## 🛠️ Personalización y Extensión

El diseño del script permite una fácil modificación y expansión.

### A. Modificar Aplicaciones

Para cambiar las aplicaciones instaladas en un grupo existente, solo necesitas editar el archivo **JSON** correspondiente (`office_apps.json`, `dev_apps.json`, etc.).

```json
// Ejemplo de estructura de aplicación
{
    "name": "Nombre visible",
    "wingetId": "Identificador.Exacto.Winget" // ¡Crucial! Obténlo con 'winget search'
}
