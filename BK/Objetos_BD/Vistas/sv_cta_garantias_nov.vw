CREATE OR REPLACE FORCE VIEW IT.SV_CTA_GARANTIAS_NOV AS
SELECT c.fecha,
          a.nro_operacion,
          a.cod_oficina cod_ofi_operacion,
          a.cod_moneda cod_mon_iso_operacion,
          c.cod_persona,
          a.tip_operacion,
          a.cod_modulo,
          d.cod_modalidad,
          c.nro_garantia,
          b.cod_oficina cod_ofi_garantia,
          b.cod_mon_iso_garantia,
          b.cod_ref_bco_central,
          decode(b.tip_gar_especifica, 'N', 'G', 'S', 'E') tip_gar_especifica,
          c.cod_garantia,
          c.mto_apl_computable
     FROM sb_crc_operaciones_det a, sb_crc_garantias_det b, sb_cta_garantias_nov c, ge_cuentas d, pr_gar_tipos e
    WHERE pae_uti.fu_obt_valor(a.nro_operacion, 1) = c.nro_cuenta
      AND c.nro_garantia  = b.nro_garantia
      AND pae_uti.fu_obt_valor(a.nro_operacion, 1) = d.nro_cuenta
      AND c.cod_garantia = e.cod_garantia
      AND e.computable = 'S'
      AND b.fecha = (select max (fecha) from sb_crc_garantias_det d where b.nro_garantia = d.nro_garantia)
      AND c.fecha = (select max (fec_insercion) from sb_cta_garantias_nov e where b.nro_garantia = e.nro_garantia);

