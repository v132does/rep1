# Contabilización FLI / REPO O/N / REPO Tripartito — SQL

Parametrización módulo 10. Homolog `uenodesa5` primero. FINDIA es solo lectura.

## Pase a producción (solo esto)

| Orden | Script | Qué hace |
|------:|--------|----------|
| 1 | `7000_ins_ge_tip_asientos.sql` | Tips **9901–9904 / 9908–9909**, solo GS |
| 2 | `7001_ins_ge_transacciones.sql` | **102** + **815/816/818/820** (138/139/140); **819/822** (139/140); **823/824** (garantía) |
| 3 | `8000_val_post_deploy.sql` | Validación SELECT post-deploy |

Cada script: `pre_ini_aplicacion` + `pae_cnf.g_cod_modulo := 1`, idempotente (`MERGE` / `NOT EXISTS`), `COMMIT`.

### Respaldo previo (`BKP/MDD-91/`)

Copia de **master** antes del cambio (rollback):

| Archivo | Origen |
|---------|--------|
| `../../BKP/MDD-91/pam_frc.spc` | `Objetos_BD/Paquetes/pam_frc.spc` @ master |
| `../../BKP/MDD-91/pam_frc.bdy` | `Objetos_BD/Paquetes/pam_frc.bdy` @ master |

### Nombres en catálogo (sin prefijo ticket)

| Trans | Abrev. | Descripción |
|------:|--------|-------------|
| 815 | LISIAL | LIQUIDACION SIPAP ALTA |
| 816 | LISIBA | LIQUIDACION SIPAP BAJA |
| 818 | ALACDE | ALTA ACUERDO DEAL |
| 819 | ALTINT | ALTA INTERES |
| 820 | BAACDE | BAJA ACUERDO DEAL |
| 822 | BAJINT | BAJA INTERES |
| 823 | ALTGAR | ALTA GARANTIA |
| 824 | BAJGAR | BAJA GARANTIA |

Tips: `ALTA/BAJA ACUERDO DEAL`, `ALTA INTERES PERDIDA`, `BAJA INTERES PERDIDA` / `BAJA INTERES`, `ALTA/BAJA GARANTIA DEUDORES` y `TITULO`.

## Numeración de cuentas (semilla `SIG_NROCTA`)

Solo afecta el **siguiente** `nro_cuenta` al alta. Modalidades producto siguen **138 / 139 / 140**. Contabilización / PAM_FRC no dependen del prefijo.

| Mod | `SIG_NROCTA` (post salto sep-2026) | Prefijo nro (ofi 61) |
|----:|------------------------------------|----------------------|
| 138 | `23800001` | `61238…` |
| 139 | `23900001` | `61239…` |
| 140 | `24000001` | `61240…` |

Reservas de catálogo (no producto): modalidades **238 / 239 / 240**. Cuentas ya creadas con prefijo viejo `61138/61139/61140` quedan intactas.

`PAM_FRC` (feature contabilización asientos): al pedir número, si ya existe en `ge_cuentas` o `md_cta_documentos`, salta al siguiente (hasta 50).

## Decisiones que el SQL materializa

- FLI (138): DEAL = capital. **Sin PERD** (no 819/822).
- REPO 139/140: PERD + DEAL capital+interés. Interés a resultado en la BAJA (822).
- Garantía: mismos rubros las 6 mods. `P` = plazo del documento.
- **823/824** solo en modalidades de documento (no en 138/139/140).
- SIPAP: trans **815/816** nuevas (no copiar 741/842).

## Fuera de alcance

Quién inserta los movimientos en prod (`PAM_FRC`). USD. Clonar tips por sector I/F/N/P.

Harness de simulación / cleanup de homolog: **no forman parte de este directorio en el repo** (solo scripts de pase arriba).
