CREATE OR REPLACE VIEW IT.SV_CRC_SALDOS AS
SELECT o2.linea, o2.registro, o2.fecha
FROM (
  SELECT
    LPAD(e.nro_formulario, 3, '0') || ';' ||
    DECODE(pas_cri.fu_obt_cod_entidad,
           2079, LPAD(e.cod_oficina_eqv, 2, '0'),
           1007, LPAD(e.cod_oficina_eqv, 4, '0'),
           2036, LPAD(e.cod_oficina_eqv, 2, '0'),
           2080, LPAD(e.cod_oficina_eqv, 4, '0'),
           2037, LPAD(e.cod_oficina_eqv, 4, '0'),
                 e.cod_oficina_eqv
    ) || ';' ||
    LPAD(NVL(e.tip_operacion, 0), 3, '0') || ';' ||
    DECODE(pas_cri.fu_obt_cod_entidad,
           2037, NVL(fue_tab_dat_adicional('AH_CTA_CERTIFICADOS','SIB_CTA_CRC_INFORMADA', e.nro_operacion_eqv),
                     e.nro_operacion_eqv),
           e.nro_operacion_eqv) || ';' ||
    NVL(e.con_mon_iso, '') || ';' ||
    NVL(TO_CHAR(e.fec_corte,          'yyyymmdd'), '') || ';' ||
    NVL(TO_CHAR(e.fec_vto_cuota,      'yyyymmdd'), '') || ';' ||
    NVL(TO_CHAR(e.fec_vto_cuo_vencida,'yyyymmdd'), '') || ';' ||
    NVL(e.dia_atraso, 0) || ';' ||
    NVL(LTRIM(REPLACE(fub_obt_rub_formateado(e.rub_con_capital),'.',NULL), '0'),'') || ';' ||
    SUBSTR(TRIM(TO_CHAR(GREATEST(NVL(e.sal_capital, 0), 0), 'FM999999999999999990.00')), 1, 20) || ';' ||
    SUBSTR(TRIM(TO_CHAR(GREATEST(NVL(e.sal_cuo_vencida, 0), 0), 'FM999999999999999990.00')), 1, 20) || ';' ||
  NVL(LTRIM(REPLACE(fub_obt_rub_formateado(e.rub_con_int_devengar),'.',NULL), '0'),'') || ';' ||
    SUBSTR(TRIM(TO_CHAR(GREATEST(NVL(e.sal_int_devengar, 0), 0), 'FM999999999999999990.00')), 1, 20) || ';' ||
  NVL(LTRIM(REPLACE(fub_obt_rub_formateado(e.rub_con_dev_no_cobrado),'.',NULL), '0'),'') || ';' ||
    SUBSTR(TRIM(TO_CHAR(GREATEST(NVL(e.sal_int_dev_no_cobrado, 0), 0), 'FM999999999999999990.00')), 1, 20) || ';' ||
  NVL(LTRIM(REPLACE(fub_obt_rub_formateado(e.rub_con_int_dev_cobrado),'.',NULL), '0'),'') || ';' ||
    SUBSTR(TRIM(TO_CHAR(GREATEST(NVL(e.sal_int_dev_cobrado, 0), 0), 'FM999999999999999990.00')), 1, 20) || ';' ||
  NVL(LTRIM(REPLACE(fub_obt_rub_formateado(e.rub_con_dev_suspenso),'.',NULL), '0'),'') || ';' ||
    SUBSTR(TRIM(TO_CHAR(GREATEST(NVL(e.sal_int_suspenso, 0), 0), 'FM999999999999999990.00')), 1, 20) || ';' ||
  NVL(LTRIM(REPLACE(fub_obt_rub_formateado(e.rub_con_contingencia),'.',NULL), '0'),'') || ';' ||
    SUBSTR(TRIM(TO_CHAR(GREATEST(NVL(e.mto_contingencia, 0), 0), 'FM999999999999999990.00')), 1, 20) || ';' ||
    SUBSTR(TRIM(TO_CHAR(NVL(ROUND(NVL(fue_tab_dat_adicional('SB_CRC_SALDOS_DET','SIB_CRC_TAS_INFORMADA', e.nro_operacion_eqv), e.tas_efectiva), 2), 0), 'FM999990.00')), 1, 8) || ';' ||
  NVL(LTRIM(REPLACE(fub_obt_rub_formateado(e.rub_con_prevision),'.',NULL), '0'),'') || ';' ||
    SUBSTR(TRIM(TO_CHAR(GREATEST(NVL(e.mto_prevision, 0), 0), 'FM999999999999999990.00')), 1, 20) || ';' ||
    NVL(e.can_cuo_pagadas, 0) || ';' ||
    NVL(e.cla_riesgo, '') || ';' ||
    NVL(e.ind_movimiento, '') || ';' ||
    NVL(TO_CHAR(e.est_tarjeta), '') || ';' ||
	NVL(TO_CHAR(e.mto_deu_anterior, 'FM999999999999999990.00'), '') || ';' ||
	NVL(TO_CHAR(e.mto_pag_mes, 'FM999999999999999990.00'), '') || ';' ||
	NVL(TO_CHAR(e.mto_com_mes, 'FM999999999999999990.00'), '') || ';' ||
	NVL(TO_CHAR(e.mto_deu_facturar, 'FM999999999999999990.00'), '') || ';' ||
	NVL(TO_CHAR(e.mto_cargo, 'FM999999999999999990.00'), '') || ';' ||
	NVL(TO_CHAR(e.mto_lin_credito, 'FM999999999999999990.00'), '') || ';' ||
    e.nro_registro AS linea,
    e.nro_registro AS registro,
    e.fecha        AS fecha
  FROM IT.sv_crc_saldos_det_eqv e
  ORDER BY e.nro_registro
) o2
ORDER BY fecha, registro
