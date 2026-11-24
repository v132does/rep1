create or replace force view it.gv_qry_cta_ctes as
Select CTA.NRO_CUENTA, CLI.COD_PERSONA, CTA.DENOMINACION, CTA.COD_MONEDA, det.fec_apertura fec_inicio, CLI.RELACION, -- ctas ctes
       CTA.COD_MODULO, CTA.COD_MODALIDAD, CTA.ESTADO, DECODE(dat.val_parametro,null,EST.DESCRIPCION,'CARTERA VENDIDA') DESCRIPCION, EST.ACTIVO,
       MAD.DESCRIPCION SC_NMMODAL, det.cta_combinada
from GE_MODALIDADES MAD,GE_EST_CUENTAS EST, cc_cta_corrientes det, GE_CUENTAS CTA, GE_CTA_CLIENTES CLI,
      (select nro_cuenta, val_parametro from ge_cta_dat_adicionales where parametro = 'ENT_ADM_CARTERA') DAT
where EST.COD_MODULO = CTA.COD_MODULO
  AND EST.COD_MODALIDAD = CTA.COD_MODALIDAD
  AND EST.ESTADO = CTA.ESTADO
  AND CTA.NRO_CUENTA = CLI.NRO_CUENTA
  AND MAD.COD_MODULO = CTA.COD_MODULO
  AND MAD.COD_MODALIDAD = CTA.COD_MODALIDAD
  and cta.nro_cuenta = det.nro_cuenta
  and cta.nro_cuenta = dat.nro_cuenta(+)
union all
-- ctas bancarias
Select CTA.NRO_CUENTA, CLI.COD_PERSONA, CTA.DENOMINACION, CTA.COD_MONEDA, ban.fec_apertura fec_inicio, CLI.RELACION, -- ctas ctes
       CTA.COD_MODULO, CTA.COD_MODALIDAD, CTA.ESTADO, DECODE(dat.val_parametro,null,EST.DESCRIPCION,'CARTERA VENDIDA') DESCRIPCION, EST.ACTIVO,
       MAD.DESCRIPCION SC_NMMODAL, null cta_combinada
from GE_MODALIDADES MAD,GE_EST_CUENTAS EST, cc_cta_bancarias ban, GE_CUENTAS CTA, GE_CTA_CLIENTES CLI,
      (select nro_cuenta, val_parametro from ge_cta_dat_adicionales where parametro = 'ENT_ADM_CARTERA') DAT
where EST.COD_MODULO = CTA.COD_MODULO
  AND EST.COD_MODALIDAD = CTA.COD_MODALIDAD
  AND EST.ESTADO = CTA.ESTADO
  AND CTA.NRO_CUENTA = CLI.NRO_CUENTA
  AND MAD.COD_MODULO = CTA.COD_MODULO
  AND MAD.COD_MODALIDAD = CTA.COD_MODALIDAD
  and cta.nro_cuenta = ban.nro_cuenta
  and cta.nro_cuenta = dat.nro_cuenta(+)
;

