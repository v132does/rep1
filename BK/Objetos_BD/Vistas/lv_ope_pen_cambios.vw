CREATE OR REPLACE FORCE VIEW IT.LV_OPE_PEN_CAMBIOS AS
SELECT a.nro_operacion     nro_operacion,
       a.cod_persona       cod_persona,
       a.cod_oficina       cod_oficina,
       a.fec_operacion     fec_operacion,
       a.ope_homebanking   ope_homebanking,
       a.liquidado         liquidado,
       a.nro_diario        nro_diario,
       a.rel_monedas       rel_monedas,
       a.usu_insercion||'-'||ui.nombre usu_insercion,
       a.usu_modificacion||'-'||um.nombre usu_modificacion,
       a.fec_insercion     fec_insercion,
       a.fec_modificacion  fec_modificacion,
       case when a.cod_persona = b.cod_persona then 'PROPIO' else 'TERCERO' end cli_destino,
       --Venta--
       a.cod_tip_operacion cod_tip_operacion,
       ax.descripcion      des_tip_operacion,
       a.cod_tip_ope_bcp   cod_tip_ope_bcp,
       az.descripcion      des_tip_ope_bcp,
       a.cod_moneda        cod_moneda,
       a.monto             monto,
       a.cotizacion        cotizacion,
       a.mto_equ_local     mto_equ_local,
       a.nro_documento     nro_documento,
       am.nom_completo     nom_persona,
       a.nro_cuenta        nro_cta_cambios,
       ag.cod_numerico     cod_numerico,
       a.cta_referencia    cta_referencia,
       a.cod_tra_cargo1    cod_tra_cargo1,
       a.mto_cargo1        mto_cargo1,
       a.mto_equ_cargo1    mto_equ_cargo1,
       a.cod_tra_cargo2    cod_tra_cargo2,
       a.mto_cargo2        mto_cargo2,
       a.mto_equ_cargo2    mto_equ_cargo2,
       a.cod_tra_cargo3    cod_tra_cargo3,
       a.mto_cargo3        mto_cargo3,
       a.mto_equ_cargo3    mto_equ_cargo3,
       ax.cod_modulo       cod_modulo,
       ax.cod_modalidad    cod_modalidad,
       a.referenciado      referenciado,
       a.cod_tip_referencia cod_tip_referencia,
       a.nro_referencia    nro_referencia,
       a.concepto          concepto,
       --Compra--
       b.cod_tip_operacion cod_tip_operacioc,
       bx.descripcion      des_tip_operacioc,
       b.cod_tip_ope_bcp   cod_tip_ope_bcc,
       bz.descripcion      des_tip_ope_bcc,
       b.cod_moneda        cod_monedc,
       b.monto             montc,
       b.cotizacion        cotizacioc,
       b.mto_equ_local     mto_equ_locac,
       b.nro_documento     nro_documentc,
       bm.nom_completo     nom_personc,
       b.nro_cuenta        nro_cta_cambioc,
       bg.cod_numerico     cod_numericc,
       b.cta_referencia    cta_referencic,
       b.referenciado      referenciadc,
       b.cod_tip_referencia cod_tip_referencic,
       b.nro_referencia    nro_referencic,
       --otros datos--
       a.fec_liquidacion   fec_liquidacion,
       a.cod_usu_liquidacion cod_usu_liquidacion,
       a.concepto          observacion,
       a.nro_operacion     nro_boleta,
       a.nro_cheque        nro_cheque,
       a.cta_referencia    nro_cta_bancaria,
       a.nro_cuenta        nro_cuenta,
       null                cta_ref_contra1,
       0                   mto_contra1,
       null                cta_ref_contra2,
       0                   mto_contra2,
       null                cta_ref_contra3,
       0                   mto_contra3,
       null                cta_ref_contra4,
       0                   mto_contra4,
       null                cta_ref_contra5,
       0                   mto_contra5,
       null                cod_tra_cargo4,
       0                   mto_cargo4
  FROM LC_OPE_PEN_CAMBIOS A,  LC_OPE_PEN_CAMBIOS B,
       lc_tip_operaciones ax, lc_tip_operaciones bx,
       lc_tip_ope_bcp az,     lc_tip_ope_bcp bz,
       ba_personas am,        ba_personas bm,
       ba_monedas ag,         ba_monedas bg,
       ba_usuarios ui,        ba_usuarios um
 WHERE A.NRO_OPERACION = B.NRO_OPERACION
   AND A.NRO_SECUENCIA = 1
   AND B.NRO_SECUENCIA = 2
   AND AX.COD_TIP_OPERACION = A.COD_TIP_OPERACION
   AND BX.COD_TIP_OPERACION = B.COD_TIP_OPERACION
   AND az.cod_tip_ope_bcp = a.cod_tip_ope_bcp
   and bz.cod_tip_ope_bcp = b.cod_tip_ope_bcp
   and am.cod_persona     = a.cod_persona
   and bm.cod_persona     = b.cod_persona
   and ag.cod_moneda      = a.cod_moneda
   and bg.cod_moneda      = b.cod_moneda
   and ui.cod_usuario     = a.usu_insercion
   and um.cod_usuario     = a.usu_modificacion
order by 1 desc
;

