CREATE OR REPLACE VIEW IT.SV_CRC_MOVIMIENTOS AS
SELECT o.linea, o.registro, o.fecha
  FROM (
    SELECT RPAD(s.nom_referencia, 10) ||
           RPAD(TO_CHAR(s.fec_periodo, 'yyyymmdd'), 8, ' ') ||
           LPAD(s.cod_entidad, 4, 0) ||
           LPAD(c.can_reg, 9, 0) linea,
           0 registro,
           s.fec_periodo fecha
      FROM sb_crc_movimientos s,
           (SELECT a.fecha fec, COUNT(*) can_reg
              FROM sb_crc_movimientos_det a
             GROUP BY a.fecha) c
     WHERE s.fec_periodo = c.fec
  ) o
UNION ALL
SELECT o2.linea, o2.registro, o2.fecha
  FROM (
    SELECT LPAD(nro_formulario, 3, 0) ||
           DECODE(pas_cri.fu_obt_cod_entidad,
                  2079, RPAD(LPAD(d.cod_oficina, 2, 0), 4, ' '),
                  1007, LPAD(d.cod_oficina, 4, 0),
                  2036, RPAD(LPAD(d.cod_oficina, 2, 0), 4, ' '),
                  2080, LPAD(d.cod_oficina, 4, 0),
                  2037, LPAD(NVL(fue_tab_dat_adicional('GE_CUENTAS','SIB_OFI_CRC_INACTIVAS', d.nro_operacion), d.cod_oficina), 4, 0),
                  RPAD(d.cod_oficina, 4, ' ')) ||
           LPAD(NVL(d.tip_operacion,0), 3, 0) ||
           RPAD(DECODE(pas_cri.fu_obt_cod_entidad, 2037,
                       NVL(fue_tab_dat_adicional('AH_CTA_CERTIFICADOS','SIB_CTA_CRC_INFORMADA', d.nro_operacion),
                           d.nro_operacion),
                       d.nro_operacion), 60, ' ') ||
           RPAD(d.cod_mon_iso, 3, ' ') ||
           RPAD(NVL(TO_CHAR(d.fec_operacion, 'yyyymmdd'),' '), 8, ' ') ||
           RPAD(NVL(REPLACE(fub_obt_rub_formateado(d.cta_con_capital),'.',NULL),' '), 18) ||
           LPAD(TO_CHAR(NVL((d.mto_capital*100),0)),20,'0') ||
           LPAD(TO_CHAR(NVL((d.mto_lin_credito*100),0)),20,'0') ||
           RPAD(NVL(REPLACE(fub_obt_rub_formateado(d.cta_con_interes),'.',NULL),' '), 18) ||
           LPAD(TO_CHAR(NVL((d.mto_interes*100),0)),20,'0') ||
           LPAD(TO_CHAR(NVL((d.tas_nominal*100),0)),5,'0') ||
           LPAD(NVL(d.dia_plazo,0), 5, 0) ||
           RPAD(d.tip_movimiento, 2, ' ') ||
           RPAD(' ', 200, ' ') ||
           LPAD(d.nro_registro, 9, 0) linea,
           d.nro_registro registro,
           d.fecha
      FROM IT.SV_CRC_MOV_DET_EQV d
     ORDER BY d.nro_registro
  ) o2
ORDER BY fecha, registro;
