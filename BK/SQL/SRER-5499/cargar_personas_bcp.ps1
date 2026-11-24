# =============================================================================
# cargar_personas_bcp.ps1
# Carga DIRECT PATH del padron BCP en IT.SB_PER_REF_TMP via sqlldr
# y luego ejecuta PRS_CAR_PERSONAS_REF (staging -> SB_BCP_PERSONAS_REF).
#
# Uso: .\cargar_personas_bcp.ps1
#   - Busca PERSONAS_BCP.tar.gz en la misma carpeta del script
#   - Descomprime si el DAT no existe aun
#   - Lee tnsnames.ora para listar conexiones disponibles
#   - Pide usuario y clave
#   - Encuentra sqlldr y sqlplus automaticamente
# =============================================================================

$ErrorActionPreference = "Continue"

trap {
    Write-Host ""
    Write-Host "ERROR INESPERADO: $_" -ForegroundColor Red
    Read-Host "`nPresionar Enter para salir"
    exit 1
}

# =============================================================================
# FUNCIONES (reutilizadas del deploy)
# =============================================================================
function Find-OracleExe([string]$nombre) {
    $cmd = Get-Command $nombre -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($root in @($env:ORACLE_HOME, $env:IT_ORACLE_HOME, "C:\Oracle","C:\oracle","C:\app","D:\Oracle") | Where-Object { $_ }) {
        if (-not (Test-Path $root)) { continue }
        $hit = Get-ChildItem -Path $root -Recurse -Filter "$nombre.exe" -ErrorAction SilentlyContinue |
               Where-Object { $_.FullName -notmatch '\\\.patch_storage\\|\\inventory\\|\\backup\\|\\patch\\' } |
               Sort-Object { $_.FullName.Length } | Select-Object -First 1
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
Write-Host "  ================================================" -ForegroundColor Cyan
Write-Host "     CARGA PADRON BCP - PERSONAS (SQLLDR)         " -ForegroundColor Cyan
Write-Host "     SB_PER_REF_TMP -> SB_BCP_PERSONAS_REF        " -ForegroundColor Cyan
Write-Host "  ================================================" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# BUSCAR SQLLDR Y SQLPLUS
# =============================================================================
$sqlldrExe  = Find-OracleExe "sqlldr"
$sqlplusExe = Find-OracleExe "sqlplus"

foreach ($pair in @(@("sqlldr", $sqlldrExe), @("sqlplus", $sqlplusExe))) {
    if ($pair[1]) {
        Write-Host "  $($pair[0]): $($pair[1])" -ForegroundColor DarkGreen
    } else {
        Write-Host "  $($pair[0]) no encontrado." -ForegroundColor Yellow
        $path = Read-Host "  Ruta completa a $($pair[0]).exe"
        if ($pair[0] -eq "sqlldr")  { $sqlldrExe  = $path }
        if ($pair[0] -eq "sqlplus") { $sqlplusExe = $path }
    }
}

# Setear ORACLE_HOME desde sqlldr
$oracleHome = Split-Path (Split-Path $sqlldrExe -Parent) -Parent
$env:ORACLE_HOME = $oracleHome
$env:PATH = "$(Split-Path $sqlldrExe -Parent);$env:PATH"
if (-not $env:NLS_LANG) { $env:NLS_LANG = "AMERICAN_AMERICA.WE8MSWIN1252" }
Write-Host "  ORACLE_HOME: $env:ORACLE_HOME" -ForegroundColor DarkGreen
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
                    $tnsAlias = $aliases[$idx]; $valido = $true
                } else { Write-Host "  Fuera de rango." -ForegroundColor Red }
            } else { Write-Host "  Solo el numero." -ForegroundColor Red }
        }
        if ($tnsAlias) { Write-Host "  >> Conexion: $tnsAlias" -ForegroundColor Green }
    }
} else {
    Write-Host "  tnsnames.ora no encontrado." -ForegroundColor Yellow
}
if (-not $tnsAlias) { $tnsAlias = Read-Host "  Alias TNS (ej: FINDIAOCI)" }

Write-Host ""
$usuario = Read-Host "  Usuario Oracle"
$claveSecure = Read-Host "  Clave" -AsSecureString
$bstr  = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($claveSecure)
$clave = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
$ConnStr = "${usuario}/${clave}@${tnsAlias}"
Write-Host ""

# =============================================================================
# BUSCAR / DESCOMPRIMIR PERSONAS_BCP.DAT
# =============================================================================
$scriptDir = $PSScriptRoot
$datFile   = Get-ChildItem $scriptDir -Filter "PERSONAS_BCP.DAT"   -ErrorAction SilentlyContinue |
             Select-Object -First 1
$tarFile   = Get-ChildItem $scriptDir -Filter "PERSONAS_BCP.tar.gz" -ErrorAction SilentlyContinue |
             Select-Object -First 1

if (-not $datFile) {
    if (-not $tarFile) {
        # Buscar en subdirectorios cercanos
        $tarFile = Get-ChildItem (Split-Path $scriptDir -Parent) -Recurse -Filter "PERSONAS_BCP.tar.gz" -ErrorAction SilentlyContinue |
                   Select-Object -First 1
    }
    if ($tarFile) {
        Write-Host "  Descomprimiendo: $($tarFile.FullName)" -ForegroundColor Yellow
        Write-Host "  Destino        : $scriptDir"
        Write-Host "  (puede tardar unos minutos para un archivo de ~1.5 GB...)"
        # Intentar con tar nativo (Win10 1803+)
        $tarExe = Get-Command tar -ErrorAction SilentlyContinue
        if ($tarExe) {
            & tar -xzf $tarFile.FullName -C $scriptDir
        } else {
            # Fallback: 7-Zip
            $7z = Get-Command 7z -ErrorAction SilentlyContinue
            if (-not $7z) { $7z = Get-ChildItem "C:\Program Files\7-Zip\7z.exe" -ErrorAction SilentlyContinue }
            if ($7z) {
                # 7zip necesita dos pasos: .tar.gz -> .tar -> directorio
                $tmpTar = Join-Path $scriptDir "PERSONAS_BCP.tar"
                & $7z.Source e $tarFile.FullName -o"$scriptDir" -y | Out-Null
                & $7z.Source e $tmpTar -o"$scriptDir" -y | Out-Null
                Remove-Item $tmpTar -ErrorAction SilentlyContinue
            } else {
                Write-Host "  ERROR: no se encontro tar ni 7-Zip para descomprimir." -ForegroundColor Red
                $datPath = Read-Host "  Ruta completa al PERSONAS_BCP.DAT descomprimido manualmente"
                $datFile = [System.IO.FileInfo]::new($datPath)
            }
        }
        if (-not $datFile) {
            $datFile = Get-ChildItem $scriptDir -Filter "PERSONAS_BCP.DAT" -ErrorAction SilentlyContinue |
                       Select-Object -First 1
        }
    } else {
        Write-Host "  PERSONAS_BCP.tar.gz no encontrado en $scriptDir" -ForegroundColor Yellow
        $datPath = Read-Host "  Ruta completa al PERSONAS_BCP.DAT"
        $datFile = [System.IO.FileInfo]::new($datPath)
    }
}

if (-not $datFile -or -not (Test-Path $datFile.FullName)) {
    Write-Host "  PERSONAS_BCP.DAT no encontrado. Abortando." -ForegroundColor Red
    Read-Host "`n  Presionar Enter para salir"
    exit 1
}

Write-Host "  DAT : $($datFile.FullName) ($([math]::Round($datFile.Length/1MB,1)) MB)" -ForegroundColor Green

# =============================================================================
# GENERAR CTL DINAMICO
# =============================================================================
$ctlFile = Join-Path $scriptDir "BCP_PERSONAS_REF_dynamic.ctl"
$logFile = Join-Path $scriptDir "BCP_PERSONAS_REF.log"
$badFile = Join-Path $scriptDir "BCP_PERSONAS_REF.bad"

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$ctlContent = @"
LOAD DATA
INFILE '$($datFile.FullName.Replace('\','\\'))'
APPEND INTO TABLE IT.SB_PER_REF_TMP
(
  TIPO_IDENT    POSITION(1:2)    CHAR,
  NRO_DOCUMENTO POSITION(4:18)  CHAR,
  PAIS_SWIFT    POSITION(19:20) CHAR,
  NOMBRE        POSITION(22:81) CHAR,
  APELLIDO      POSITION(82:111) CHAR,
  TIPO_PER      POSITION(112:114) CHAR,
  FECHA_NAC     POSITION(115:122) CHAR
)
"@
[System.IO.File]::WriteAllText($ctlFile, $ctlContent, $utf8NoBom)
Write-Host "  CTL : $ctlFile (generado)" -ForegroundColor Green
Write-Host "  LOG : $logFile"
Write-Host "  BAD : $badFile"
Write-Host ""

# =============================================================================
# CONFIRMAR
# =============================================================================
Write-Host "  NOTA: sqlldr DIRECT PATH requiere que el usuario sea dueno de la tabla" -ForegroundColor DarkYellow
Write-Host "        (IT) o tenga ALTER TABLE sobre IT.SB_PER_REF_TMP." -ForegroundColor DarkYellow
Write-Host "        Si aparece ORA-01031, usar el usuario IT en vez de otro." -ForegroundColor DarkYellow
Write-Host ""
$confirmar = Read-Host "  Confirmar carga en $tnsAlias ? (S/N)"
if ($confirmar -ne "S" -and $confirmar -ne "s") {
    Write-Host "  Cancelado." -ForegroundColor Yellow
    Remove-Item $ctlFile -ErrorAction SilentlyContinue
    Read-Host "`n  Presionar Enter para salir"
    exit 0
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

# =============================================================================
# PASO 1: TRUNCATE IT.SB_PER_REF_TMP
# =============================================================================
Write-Host ""
Write-Host "  --- PASO 1: TRUNCATE TABLE IT.SB_PER_REF_TMP ---" -ForegroundColor Cyan
$tmpSql = [System.IO.Path]::GetTempFileName() + ".sql"
[System.IO.File]::WriteAllText($tmpSql, "TRUNCATE TABLE IT.SB_PER_REF_TMP;`r`nEXIT`r`n", $utf8NoBom)
$out = & "$sqlplusExe" -S $ConnStr "@$tmpSql" 2>&1
Remove-Item $tmpSql -ErrorAction SilentlyContinue
$out | ForEach-Object { Write-Host "      $_" }
if ($out -match "ORA-") {
    Write-Host "  ERROR en TRUNCATE. Continuar de todas formas? (S/N)" -ForegroundColor Red
    $r = Read-Host
    if ($r -ne "S" -and $r -ne "s") {
        Remove-Item $ctlFile -ErrorAction SilentlyContinue
        Read-Host "`n  Presionar Enter para salir"; exit 1
    }
} else {
    Write-Host "  Truncate OK" -ForegroundColor Green
}

# =============================================================================
# PASO 2: SQLLDR DIRECT PATH
# =============================================================================
Write-Host ""
Write-Host "  --- PASO 2: sqlldr DIRECT PATH ---" -ForegroundColor Cyan
Write-Host "  Inicio: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

& "$sqlldrExe" `
    "userid=`"$ConnStr`"" `
    "control=$ctlFile" `
    "log=$logFile" `
    "bad=$badFile" `
    direct=TRUE `
    rows=500000 `
    bindsize=33554432 `
    readsize=33554432

$exitCode = $LASTEXITCODE
Remove-Item $ctlFile -ErrorAction SilentlyContinue

Write-Host "  Fin   : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "  Exit  : $exitCode"

if   ($exitCode -eq 0) { Write-Host "  Carga exitosa" -ForegroundColor Green }
elseif ($exitCode -eq 2) { Write-Host "  Carga con advertencias (revisar .bad)" -ForegroundColor Yellow }
else { Write-Host "  ERROR en carga (revisar .log)" -ForegroundColor Red }

if (Test-Path $logFile) {
    Write-Host ""
    Write-Host "  === Resumen del log ===" -ForegroundColor DarkCyan
    Get-Content $logFile | Select-String -Pattern "Row|row|Logical|error|Error|rejected|loaded|discarded|elapsed|CPU" |
        ForEach-Object { Write-Host "      $($_.Line)" }
}

# =============================================================================
# PASO 3: PRS_CAR_PERSONAS_REF
# =============================================================================
if ($exitCode -le 2) {
    Write-Host ""
    Write-Host "  --- PASO 3: EXEC IT.PRS_CAR_PERSONAS_REF ---" -ForegroundColor Cyan
    Write-Host "  (mueve SB_PER_REF_TMP -> SB_BCP_PERSONAS_REF, puede tardar varios minutos)"
    $tmpSql2 = [System.IO.Path]::GetTempFileName() + ".sql"
    [System.IO.File]::WriteAllText($tmpSql2,
        "SET FEEDBACK ON`r`nEXEC IT.PRS_CAR_PERSONAS_REF;`r`nSELECT 'SB_BCP_PERSONAS_REF: ' || COUNT(*) total FROM IT.SB_BCP_PERSONAS_REF;`r`nEXIT`r`n",
        $utf8NoBom)
    $out3 = & "$sqlplusExe" -S $ConnStr "@$tmpSql2" 2>&1
    Remove-Item $tmpSql2 -ErrorAction SilentlyContinue
    $out3 | ForEach-Object { Write-Host "      $_" }
    if ($out3 -match "ORA-") {
        Write-Host "  ERROR en PRS_CAR_PERSONAS_REF" -ForegroundColor Red
    } else {
        Write-Host "  PRS_CAR_PERSONAS_REF OK" -ForegroundColor Green
    }
} else {
    Write-Host "  PASO 3 omitido: sqlldr fallo (exit $exitCode)." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  ================================================" -ForegroundColor Cyan
Write-Host "  PROCESO FINALIZADO" -ForegroundColor Cyan
Write-Host "  ================================================"
Read-Host "`n  Presionar Enter para salir"
