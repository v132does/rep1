CREATE OR REPLACE FORCE VIEW IT.SV_CTA_GAR_ELIMINADAS AS
SELECT  distinct c.fecha,
          c.nro_cuenta,
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
     FROM sb_crc_operaciones_det a, sb_crc_garantias_det b, sb_cta_gar_eliminadas c, ge_cuentas d, pr_gar_tipos e
    WHERE a.nro_operacion = c.nro_cuenta
      AND c.nro_garantia  = b.nro_garantia
      AND d.nro_cuenta    = c.nro_cuenta
      AND a.nro_operacion = d.nro_cuenta
      AND c.cod_garantia = e.cod_garantia
      --ITGF - Error Post Cierre Proc - 257 SC 15855
      and a.fecha = (select  max(trunc(x.fecha))
                               from  sb_crc_operaciones_det x
                              where  x.nro_operacion = a.nro_operacion)
      AND e.computable = 'S'
      AND b.fecha  = (select distinct (max(fecha)) from sb_crc_garantias_det d where b.nro_garantia = d.nro_garantia)
      AND c.fecha  = (select distinct (max(fecha))
                        from sb_cta_gar_eliminadas e
                       where b.nro_garantia = e.nro_garantia
                         and e.nro_cuenta = c.nro_cuenta)
      -- DYDMR-3142 excluye tipos de operacion que no deben informarse
      AND a.tip_operacion NOT IN ( select regexp_substr(fug_obt_pardinamico('SIB_CRC_GAR_EXC_TIP_OPE'),'[^,]+', 1, level) from dual
                            connect by regexp_substr(fug_obt_pardinamico('SIB_CRC_GAR_EXC_TIP_OPE'), '[^,]+', 1, level) is not null)
;

