# Jira MDD-111 Crear nuevas modalidades para FLIs / REPO ON / REPO Tripartito (implementación)
**Referencia diseño:** modalidad **127** (REPO INTERBANCARIO RECIBIDO)  
**Ambiente:** homolog `uenodesa5` primero; prod tras aprobación.

## Alcance

Parametrización catálogo módulo 10 — **sin** trans 102/811/812, **sin** `SNP_MTO_UNI_TITULO`, **sin** `ba_consultas`/NVB.

## Orden de ejecución

| Orden | Script | Tabla(s) |
|------:|--------|----------|
| 1 | `7000_ins_ge_modalidades.sql` | `ge_modalidades` |
| 2 | `7001_ins_ge_est_cuentas.sql` | `ge_est_cuentas` |
| 3 | `7002_ins_ge_transacciones.sql` | `ge_transacciones` (solo 401) |
| 4 | `7003_ins_ge_par_dinamicos.sql` | `ge_par_dinamicos` |
| 5 | `7004_ins_ba_cod_referencias.sql` | `ba_cod_referencias` |
| 6 | `7005_ins_cr_piz_plazos.sql` | `cr_piz_plazos` |
| 7 | `7006_ins_cr_piz_montos.sql` | `cr_piz_montos` |
| 8 | `7007_ins_pr_rub_eco_modalidades.sql` | `pr_rub_eco_modalidades` |
| 9 | `8000_val_post_deploy.sql` | Validación (solo SELECT) |

Cada script incluye `pre_ini_aplicacion` y es **idempotente** (`NOT EXISTS`).

## Baseline mod 127 (uenodesa5, 2026-08-11)

| Objeto | Valor referencia |
|--------|------------------|
| `ge_modalidades` | REPO INTERBANCARIO - RECIBIDO, tipo P |
| `ge_est_cuentas` | S,E,C,N,R,X (6 estados) |
| `ge_transacciones` 401 | CAMEST / PRM_ACT_EST_BATCH / batch O |
| `SIG_NROCTA` 127 | 12700114 (no copiar a 138/139/140) |
| `ge_par_dinamicos` MDD-111 | SIG_NROCTA, MD_OPE_REPO, REP_TIP_NEGOCIACIONES |
| Pizarra GS | mto_desde 10.000.000, plz 1–9999 |
| Pizarra USD | mto_desde 1.000, plz 1–9999 |
| `pr_rub_eco_modalidades` | 659900 / ref 904 |
| `ba_cod_referencias` | MES_PRO_MODALIDAD → MMCTARRE |


## Semillas destino

| Modalidad | SIG_NROCTA | Descripción |
|-----------|------------|-------------|
| 138 | 13800001 | FLI RECIBIDO |
| 139 | 13900001 | REPO OVERNIGHT RECIBIDO |
| 140 | 14000001 | REPO TRIPARTITO RECIBIDO |

## Validación

- Técnica: `8000_val_post_deploy.sql`

## Fuera de alcance

Alta/cancelación cuenta MMCTARRE, deploy prod sin homolog PASS
