-- Validacion post-deploy catalogo FLI/REPO (solo SELECT)
-- PASS: tips 9 lineas GS; trans producto + garantia; 819/822 ausentes en 138
-- Release path: SQL/MDD-91/8000_val_post_deploy.sql

prompt === ge_tip_asientos FLI/REPO (esperado 9 lineas GS) ===
select cod_tip_asiento, nro_linea, tip_movimiento, cod_rubro, descripcion, ind_plazo, ind_residente
  from it.ge_tip_asientos
 where cod_tip_asiento in (9901, 9902, 9903, 9904, 9908, 9909)
   and cod_moneda = 'GS'
 order by cod_tip_asiento, nro_linea;

prompt === ge_transacciones producto 138/139/140 ===
select cod_modalidad, cod_transaccion, abreviatura, descripcion, tipo, batch, detallado, cod_tip_asiento
  from it.ge_transacciones
 where cod_modulo = 10
   and cod_modalidad in (138, 139, 140)
   and cod_transaccion in (102, 815, 816, 818, 819, 820, 822)
 order by cod_modalidad, cod_transaccion;

prompt === ge_transacciones garantia 823/824 (6 mods de documento) ===
select cod_modalidad, cod_transaccion, abreviatura, descripcion, tipo, batch, cod_tip_asiento
  from it.ge_transacciones
 where cod_modulo = 10
   and cod_modalidad in (101, 105, 106, 123, 125, 129)
   and cod_transaccion in (823, 824)
 order by cod_modalidad, cod_transaccion;

prompt === RESUMEN CONTEOS (PASS si cnt = esperado) ===
select 'tip_asientos_gs' tabla, count(*) cnt, 9 esperado
  from it.ge_tip_asientos
 where cod_tip_asiento in (9901, 9902, 9903, 9904, 9908, 9909) and cod_moneda = 'GS'
union all
select 'trans_102', count(*), 3
  from it.ge_transacciones where cod_modulo=10 and cod_modalidad in (138,139,140) and cod_transaccion=102
union all
select 'trans_815_816', count(*), 6
  from it.ge_transacciones where cod_modulo=10 and cod_modalidad in (138,139,140) and cod_transaccion in (815,816)
union all
select 'trans_818_820', count(*), 6
  from it.ge_transacciones where cod_modulo=10 and cod_modalidad in (138,139,140) and cod_transaccion in (818,820)
union all
select 'trans_819_822_repo', count(*), 4
  from it.ge_transacciones where cod_modulo=10 and cod_modalidad in (139,140) and cod_transaccion in (819,822)
union all
select 'trans_819_822_fli', count(*), 0
  from it.ge_transacciones where cod_modulo=10 and cod_modalidad=138 and cod_transaccion in (819,822)
union all
select 'trans_823_824_doc', count(*), 12
  from it.ge_transacciones where cod_modulo=10 and cod_modalidad in (101,105,106,123,125,129) and cod_transaccion in (823,824)
union all
select 'trans_823_824_prod', count(*), 0
  from it.ge_transacciones where cod_modulo=10 and cod_modalidad in (138,139,140) and cod_transaccion in (823,824)
union all
select 'trans_741_842_prod', count(*), 0
  from it.ge_transacciones where cod_modulo=10 and cod_modalidad in (138,139,140) and cod_transaccion in (741,842)
union all
-- Descripciones de negocio (sin prefijo de ticket)
select 'tips_desc_negocio', count(*), 9
  from it.ge_tip_asientos
 where cod_tip_asiento in (9901, 9902, 9903, 9904, 9908, 9909)
   and cod_moneda = 'GS'
   and descripcion in (
         'ALTA ACUERDO DEAL',
         'ALTA INTERES PERDIDA',
         'BAJA ACUERDO DEAL',
         'BAJA INTERES PERDIDA',
         'BAJA INTERES',
         'ALTA GARANTIA DEUDORES',
         'ALTA GARANTIA TITULO',
         'BAJA GARANTIA DEUDORES',
         'BAJA GARANTIA TITULO'
       )
union all
-- Harness viejo de simulacion (9941-9946): no debe quedar en GS
select 'tips_harness_994x', count(*), 0
  from it.ge_tip_asientos
 where cod_moneda = 'GS'
   and cod_tip_asiento in (9941, 9942, 9943, 9946);
