-- Validacion post-deploy (solo SELECT)
-- Esperado: 3 modalidades, 18 estados, 3x401, 9 par dinamicos, 3 refs, pizarra GS+USD, 3 rubros

prompt === ge_modalidades 138/139/140 ===
select cod_modalidad, descripcion, tipo, cod_pro_contable
  from it.ge_modalidades
 where cod_modulo = 10 and cod_modalidad in (138, 139, 140)
 order by cod_modalidad;

prompt === ge_est_cuentas (debe ser 6 por modalidad) ===
select cod_modalidad, count(*) cnt
  from it.ge_est_cuentas
 where cod_modulo = 10 and cod_modalidad in (138, 139, 140)
 group by cod_modalidad
 order by cod_modalidad;

prompt === ge_transacciones 401 CAMEST ===
select cod_modalidad, cod_transaccion, abreviatura, rutina1, batch
  from it.ge_transacciones
 where cod_modulo = 10 and cod_modalidad in (138, 139, 140) and cod_transaccion = 401
 order by cod_modalidad;

prompt === ge_par_dinamicos (3 por modalidad) ===
select cod_modalidad, parametro, val_parametro
  from it.ge_par_dinamicos
 where cod_modulo = 10 and cod_modalidad in (138, 139, 140)
   and parametro in ('SIG_NROCTA', 'MD_OPE_REPO', 'REP_TIP_NEGOCIACIONES')
 order by cod_modalidad, parametro;

prompt === ba_cod_referencias MES_PRO_MODALIDAD ===
select dominio, significado, val_minimo, abreviatura, activo
  from it.ba_cod_referencias
 where dominio = 'MES_PRO_MODALIDAD' and val_minimo in ('138', '139', '140')
 order by val_minimo;

prompt === cr_piz_plazos GS+USD ===
select cod_modalidad, cod_moneda, mto_desde, plz_desde, plz_hasta, tas_interes, tas_efectiva
  from it.cr_piz_plazos
 where cod_modulo = 10 and cod_modalidad in (138, 139, 140)
 order by cod_modalidad, cod_moneda;

prompt === cr_piz_montos GS+USD ===
select cod_modalidad, cod_moneda, mto_desde, mto_hasta
  from it.cr_piz_montos
 where cod_modulo = 10 and cod_modalidad in (138, 139, 140)
 order by cod_modalidad, cod_moneda;

prompt === pr_rub_eco_modalidades ===
select cod_modalidad, cod_rub_economico, referencia
  from it.pr_rub_eco_modalidades
 where cod_modulo = 10 and cod_modalidad in (138, 139, 140)
 order by cod_modalidad;

prompt === RESUMEN CONTEOS (PASS si todos OK) ===
select 'ge_modalidades' tabla, count(*) cnt, 3 esperado from it.ge_modalidades where cod_modulo=10 and cod_modalidad in (138,139,140)
union all
select 'ge_est_cuentas', count(*), 18 from it.ge_est_cuentas where cod_modulo=10 and cod_modalidad in (138,139,140)
union all
select 'ge_transacciones_401', count(*), 3 from it.ge_transacciones where cod_modulo=10 and cod_modalidad in (138,139,140) and cod_transaccion=401
union all
select 'ge_par_dinamicos', count(*), 9 from it.ge_par_dinamicos where cod_modulo=10 and cod_modalidad in (138,139,140) and parametro in ('SIG_NROCTA','MD_OPE_REPO','REP_TIP_NEGOCIACIONES')
union all
select 'ba_cod_referencias', count(*), 3 from it.ba_cod_referencias where dominio='MES_PRO_MODALIDAD' and val_minimo in ('138','139','140')
union all
select 'cr_piz_plazos', count(*), 6 from it.cr_piz_plazos where cod_modulo=10 and cod_modalidad in (138,139,140)
union all
select 'cr_piz_montos', count(*), 6 from it.cr_piz_montos where cod_modulo=10 and cod_modalidad in (138,139,140)
union all
select 'pr_rub_eco_modalidades', count(*), 3 from it.pr_rub_eco_modalidades where cod_modulo=10 and cod_modalidad in (138,139,140);
