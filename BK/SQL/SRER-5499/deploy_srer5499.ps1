# =============================================================================
# deploy_srer5499.ps1
# Script de despliegue SRER-5499: Proceso CF Alta Personas BCP
#
# Uso: .\deploy_srer5499.ps1  (doble click o desde terminal)
#   Lee tnsnames.ora, lista conexiones disponibles y pide elegir una.
#   Luego solicita usuario y clave.
#
# El script ubica los archivos relativos a su propia carpeta.
# No requiere rutas hardcodeadas.
# =============================================================================

# Sin StrictMode para evitar cierres silenciosos
$ErrorActionPreference = "Continue"

# Evitar que la ventana se cierre si hay error inesperado
trap {
    Write-Host ""
    Write-Host "ERROR INESPERADO: $_" -ForegroundColor Red
    Read-Host "`nPresionar Enter para salir"
    exit 1
}

# =============================================================================
# FUNCIONES
# =============================================================================
function Find-SqlPlus {
    # 1. En el PATH
    $found = Get-Command sqlplus -ErrorAction SilentlyContinue
    if ($found) { return $found.Source }
    # 2. Rutas comunes de Oracle (excluye .patch_storage y directorios de backup)
    foreach ($root in @($env:ORACLE_HOME, $env:IT_ORACLE_HOME, "C:\Oracle", "C:\oracle", "C:\app", "D:\Oracle") | Where-Object { $_ }) {
        if (-not (Test-Path $root)) { continue }
        $hit = Get-ChildItem -Path $root -Recurse -Filter "sqlplus.exe" -ErrorAction SilentlyContinue |
               Where-Object { $_.FullName -notmatch '\\\.patch_storage\\|\\inventory\\|\\backup\\|\\patch\\' } |
               Sort-Object { $_.FullName.Length } |   # preferir ruta mas corta = la real
               Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

function Find-TnsNamesOra {
    $candidatos = [System.Collections.Generic.List[string]]::new()
    if ($env:TNS_ADMIN)     { $candidatos.Add((Join-Path $env:TNS_ADMIN "tnsnames.ora")) }
    if ($env:ORACLE_HOME)   { $candidatos.Add((Join-Path $env:ORACLE_HOME "network\admin\tnsnames.ora")) }
    if ($env:IT_ORACLE_HOME){ $candidatos.Add((Join-Path $env:IT_ORACLE_HOME "network\admin\tnsnames.ora")) }
    foreach ($root in @("C:\Oracle","C:\oracle","C:\app","D:\Oracle","D:\app")) {
        if (Test-Path $root) {
            Get-ChildItem -Path $root -Recurse -Filter "tnsnames.ora" -ErrorAction SilentlyContinue |
                ForEach-Object { $candidatos.Add($_.FullName) }
        }
    }
    foreach ($c in $candidatos) {
        if ($c -and (Test-Path $c)) { return $c }
    }
    return $null
}

function Get-TnsAliases([string]$tnsFile) {
    $aliases = [System.Collections.Generic.List[string]]::new()
    foreach ($line in (Get-Content $tnsFile -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ($line -match '^([A-Za-z0-9_\.\-]{2,})\s*=') {
            $alias = $Matches[1].Trim().ToUpper()
            if ($alias -and -not $aliases.Contains($alias)) { $aliases.Add($alias) }
        }
    }
    return @($aliases | Sort-Object)
}

# =============================================================================
# ENCABEZADO
# =============================================================================
Clear-Host
Write-Host ""
Write-Host "  =============================================" -ForegroundColor Cyan
Write-Host "     DEPLOY SRER-5499 - CF Alta Personas BCP  " -ForegroundColor Cyan
Write-Host "  =============================================" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# BUSCAR SQLPLUS
# =============================================================================
$sqlplusExe = Find-SqlPlus
if ($sqlplusExe) {
    Write-Host "  sqlplus: $sqlplusExe" -ForegroundColor DarkGreen

    # Setear ORACLE_HOME si no esta definido o apunta a otro lado
    # sqlplus.exe vive en $ORACLE_HOME\bin\sqlplus.exe
    $oracleHomeDet = Split-Path (Split-Path $sqlplusExe -Parent) -Parent
    if (-not $env:ORACLE_HOME -or $env:ORACLE_HOME -ne $oracleHomeDet) {
        $env:ORACLE_HOME = $oracleHomeDet
        Write-Host "  ORACLE_HOME seteado: $env:ORACLE_HOME" -ForegroundColor DarkGreen
    }
    # Asegurar que bin este en PATH
    $binDir = Split-Path $sqlplusExe -Parent
    if ($env:PATH -notlike "*$binDir*") {
        $env:PATH = "$binDir;$env:PATH"
    }
    # NLS_LANG para evitar problemas de codificacion
    if (-not $env:NLS_LANG) { $env:NLS_LANG = "AMERICAN_AMERICA.WE8MSWIN1252" }

} else {
    Write-Host "  sqlplus.exe no encontrado en PATH ni en Oracle Home." -ForegroundColor Yellow
    $sqlplusExe = Read-Host "  Ruta completa a sqlplus.exe"
    if (-not (Test-Path $sqlplusExe)) {
        Write-Host "  Ruta invalida. Abortando." -ForegroundColor Red
        Read-Host "`n  Presionar Enter para salir"
        exit 1
    }
    $env:ORACLE_HOME = Split-Path (Split-Path $sqlplusExe -Parent) -Parent
    $env:PATH = "$(Split-Path $sqlplusExe -Parent);$env:PATH"
    if (-not $env:NLS_LANG) { $env:NLS_LANG = "AMERICAN_AMERICA.WE8MSWIN1252" }
}
Write-Host ""

# =============================================================================
# SELECCION DE CONEXION TNS
# =============================================================================
$tnsAlias = $null
$tnsFile  = Find-TnsNamesOra

if ($tnsFile) {
    Write-Host "  tnsnames.ora: $tnsFile" -ForegroundColor DarkGreen
    $aliases = Get-TnsAliases $tnsFile

    if ($aliases -and $aliases.Count -gt 0) {
        Write-Host ""
        Write-Host "  Conexiones disponibles:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $aliases.Count; $i++) {
            Write-Host ("    [{0,2}] {1}" -f ($i + 1), $aliases[$i])
        }
        Write-Host ""
        $valido = $false
        while (-not $valido) {
            $sel = Read-Host "  Numero de conexion (Enter para escribir manualmente)"
            if ($sel -eq "") { $valido = $true; break }
            if ($sel -match '^\d+$') {
                $idx = [int]$sel - 1
                if ($idx -ge 0 -and $idx -lt $aliases.Count) {
                    $tnsAlias = $aliases[$idx]
                    $valido = $true
                } else {
                    Write-Host "  Numero fuera de rango." -ForegroundColor Red
                }
            } else {
                Write-Host "  Solo el numero." -ForegroundColor Red
            }
        }
        if ($tnsAlias) { Write-Host "  >> Conexion: $tnsAlias" -ForegroundColor Green }
    } else {
        Write-Host "  Sin aliases en tnsnames.ora." -ForegroundColor Yellow
    }
} else {
    Write-Host "  tnsnames.ora no encontrado." -ForegroundColor Yellow
}

if (-not $tnsAlias) {
    $tnsAlias = Read-Host "  Alias TNS (ej: FINDIA_OCI)"
}

Write-Host ""
$usuario = Read-Host "  Usuario Oracle"
$claveSecure = Read-Host "  Clave" -AsSecureString
$bstr  = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($claveSecure)
$clave = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
$ConnStr = "${usuario}/${clave}@${tnsAlias}"
Write-Host ""

# =============================================================================
# RUTAS
# =============================================================================
$base   = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$objBD  = Join-Path $base "Objetos_BD"
$sqlDir = $PSScriptRoot

Write-Host "  Base: $base" -ForegroundColor DarkCyan
Write-Host ""

# =============================================================================
# ARCHIVOS EN ORDEN
# =============================================================================
$archivos = [ordered]@{
    "1.  ALTER   GE_ARCHIVOS DIRECT_PATH" = Join-Path $sqlDir "1000_alter_ge_archivos_direct_path.sql"
    "2a. TABLA   sb_bcp_ciu_tmp"          = Join-Path $objBD  "Tablas\sb_bcp_ciu_tmp.tab"
    "2b. TABLA   sb_per_ref_tmp"          = Join-Path $objBD  "Tablas\sb_per_ref_tmp.tab"
    "2c. TABLA   sb_bcp_personas_ref"     = Join-Path $objBD  "Tablas\sb_bcp_personas_ref.tab"
    "2d. TABLA   sb_cf_pro_log"           = Join-Path $objBD  "Tablas\sb_cf_pro_log.tab"
    "2e. TABLA   sb_cf_reg_log"           = Join-Path $objBD  "Tablas\sb_cf_reg_log.tab"
    "2f. TABLA   sb_cf_alt_personas"      = Join-Path $objBD  "Tablas\sb_cf_alt_personas.tab"
    "2g. TABLA   sb_cf_excl_detalle"      = Join-Path $objBD  "Tablas\sb_cf_excl_detalle.tab"
    "3.  SECUENC se_cf_id_ejecucion"      = Join-Path $objBD  "Secuencias\se_cf_id_ejecucion.seq"
    "4a. PROC    prs_car_personas_ref"    = Join-Path $objBD  "Procedimientos\prs_car_personas_ref.prc"
    "4b. PROC    prs_act_ref_ciudades"    = Join-Path $objBD  "Procedimientos\prs_act_ref_ciudades.prc"
    "5a. VISTA   sv_cf_alt_personas"      = Join-Path $objBD  "Vistas\sv_cf_alt_personas.vw"
    "5b. VISTA   sv_cf_excl_detalle"      = Join-Path $objBD  "Vistas\sv_cf_excl_detalle.vw"
    "6a. PKG SPC pas_cf"                  = Join-Path $objBD  "Paquetes\pas_cf.spc"
    "6b. PKG BDY pas_cf"                  = Join-Path $objBD  "Paquetes\pas_cf.bdy"
    "7a. CONFIG  GE_ARCHIVOS/GE_CAMPOS"   = Join-Path $sqlDir "7000_ins_ge_archivos_campos.sql"
    "7b. CONFIG  GE_PROCESOS 314"         = Join-Path $sqlDir "7001_ins_ge_procesos_314.sql"
    "7c. CONFIG  GE_PROCESOS 315"         = Join-Path $sqlDir "7002_ins_ge_procesos_315.sql"
    "7d. CONFIG  GE_FILTROS/BA_PAR"       = Join-Path $sqlDir "7003_ins_ge_filtros_par_consultas.sql"
}

# =============================================================================
# VERIFICACION
# =============================================================================
Write-Host "  === Verificando archivos ===" -ForegroundColor Yellow
$faltantes = 0
foreach ($desc in $archivos.Keys) {
    $path = $archivos[$desc]
    if (Test-Path $path) {
        Write-Host ("  OK   {0}" -f $desc) -ForegroundColor Green
    } else {
        Write-Host ("  FALTA  {0}" -f $path) -ForegroundColor Red
        $faltantes++
    }
}

if ($faltantes -gt 0) {
    Write-Host ""
    Write-Host "  Faltan $faltantes archivo(s). Verificar repo actualizado." -ForegroundColor Red
    Read-Host "`n  Presionar Enter para salir"
    exit 1
}

Write-Host ""
Write-Host "  Todos los archivos OK." -ForegroundColor Green
$confirmar = Read-Host "`n  Confirmar ejecucion en $tnsAlias ? (S/N)"
if ($confirmar -ne "S" -and $confirmar -ne "s") {
    Write-Host "  Cancelado." -ForegroundColor Yellow
    Read-Host "`n  Presionar Enter para salir"
    exit 0
}

# =============================================================================
# EJECUCION
# =============================================================================
Write-Host ""
Write-Host "  === Ejecutando ===" -ForegroundColor Yellow
$errores    = 0
$ejecutados = 0

foreach ($desc in $archivos.Keys) {
    $path = $archivos[$desc]
    Write-Host ""
    Write-Host ("  --- {0} ---" -f $desc) -ForegroundColor Cyan

    $tmpFile = [System.IO.Path]::GetTempFileName() + ".sql"
    try {
        # Leer archivo con StreamReader (stripea BOM automaticamente)
        # y escribir en temp sin BOM + SET DEFINE OFF
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        $reader = [System.IO.StreamReader]::new($path, $true)
        $fileContent = $reader.ReadToEnd()
        $reader.Close()
        $sqlContent = "SET DEFINE OFF`r`nSET FEEDBACK ON`r`n$fileContent`r`nEXIT`r`n"
        [System.IO.File]::WriteAllText($tmpFile, $sqlContent, $utf8NoBom)

        $output  = & "$sqlplusExe" -S $ConnStr "@$tmpFile" 2>&1
        # SP2-0042 = BOM residual (warning, no error real)
        # SP2-0734 = SET DEFINE con BOM (warning, no error real)
        $hayError = $LASTEXITCODE -ne 0 -or ($output | Where-Object { $_ -match "ORA-|SP2-0[^7]" -and $_ -notmatch "SP2-0042|SP2-0734" })

        $output | ForEach-Object { Write-Host "      $_" }

        if (-not $hayError) {
            Write-Host "      [OK]" -ForegroundColor Green
            $ejecutados++
        } else {
            Write-Host "      [ERROR]" -ForegroundColor Red
            $errores++
            $resp = Read-Host "      Continuar de todas formas? (S/N)"
            if ($resp -ne "S" -and $resp -ne "s") {
                Write-Host "  Detenido." -ForegroundColor Yellow
                break
            }
        }
    } catch {
        Write-Host "      [EXCEPCION] $_" -ForegroundColor Red
        $errores++
        $resp = Read-Host "      Continuar? (S/N)"
        if ($resp -ne "S" -and $resp -ne "s") { break }
    } finally {
        Remove-Item $tmpFile -ErrorAction SilentlyContinue
    }
}

# =============================================================================
# RESUMEN
# =============================================================================
Write-Host ""
Write-Host "  =================================================" -ForegroundColor Cyan
Write-Host "  RESUMEN SRER-5499" -ForegroundColor Cyan
Write-Host ("  Ejecutados OK : {0} / {1}" -f $ejecutados, $archivos.Count)
Write-Host ("  Con errores   : {0}" -f $errores)
if ($errores -eq 0) {
    Write-Host "  Estado: EXITOSO" -ForegroundColor Green
} else {
    Write-Host "  Estado: CON ERRORES - revisar output" -ForegroundColor Yellow
}
Write-Host "  ================================================="

Read-Host "`n  Presionar Enter para salir"
