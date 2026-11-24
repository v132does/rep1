CREATE OR REPLACE FORCE VIEW IT.SV_OPE_GARANTIAS AS
SELECT a.fecha,
       a.nro_operacion,
       a.cod_oficina cod_ofi_operacion,
       a.cod_moneda cod_mon_iso_operacion,
       a.cod_modulo,
       c.cod_modalidad,
       a.cod_persona,
       a.tip_operacion,
       b.nro_garantia,
       b.cod_oficina cod_ofi_garantia,
       b.cod_mon_iso_garantia,
       b.cod_ref_bco_central,
       DECODE (b.tip_gar_especifica,'N','G','S','E') tip_gar_especifica,
       c.cod_garantia,
       c.mto_aplicado,
       c.fec_insercion
  FROM sb_crc_operaciones_det a, sb_crc_garantias_det b, gv_cta_garantias c, pr_gar_tipos t
 WHERE a.nro_operacion = c.nro_cuenta
   AND c.nro_garantia  = b.nro_garantia
   AND t.cod_garantia = c.cod_garantia
   AND t.computable = 'S'
   AND a.fecha = (SELECT MAX (fecha) from sb_crc_operaciones_det o WHERE o.nro_operacion = a.nro_operacion)
   AND b.fecha = (SELECT MAX (fecha) FROM sb_crc_garantias_det d WHERE b.nro_garantia = d.nro_garantia)
   /*AND a.tip_operacion NOT IN ( select regexp_substr(fug_obt_pardinamico('SIB_CRC_GAR_EXC_TIP_OPE'),'[^,]+', 1, level) from dual
                            connect by regexp_substr(fug_obt_pardinamico('SIB_CRC_GAR_EXC_TIP_OPE'), '[^,]+', 1, level) is not null)*/;

