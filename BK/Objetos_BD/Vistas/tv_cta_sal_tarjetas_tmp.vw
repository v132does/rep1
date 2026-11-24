CREATE OR REPLACE FORCE VIEW IT.TV_CTA_SAL_TARJETAS_TMP AS
SELECT t.nro_cuenta, fue_obt_des_refcodes('COD_MON_BANCARD', t.cod_moneda) cod_moneda,
       t.cod_tip_saldo, fue_obt_des_refcodes('TIP_SAL_BANCARD', t.cod_tip_saldo) tip_saldo,
       nvl(t.mto_saldo, 0) mto_saldo, /*nvl(t.cod_deu_vigente, 'N') cod_deu_vigente,
       nvl(t.cod_disponible, 'N') cod_disponible,*/
       (select val_maximo from ba_cod_referencias
         where dominio = 'TIP_SAL_BANCARD'
           and t.cod_tip_saldo = val_minimo) tip_movimiento
  FROM ta_cta_sal_tarjetas_tmp t
 ORDER BY t.cod_moneda, t.cod_tip_saldo;

