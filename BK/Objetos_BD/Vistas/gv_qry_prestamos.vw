CREATE OR REPLACE FORCE VIEW IT.GV_QRY_PRESTAMOS AS
Select CTA.NRO_CUENTA, CLI.COD_PERSONA, CTA.DENOMINACION, CTA.COD_MONEDA, nvl(det.fec_ini_rrr,det.fec_inicio) fec_inicio, det.fec_vencimiento, --préstamos
       CLI.RELACION, CTA.COD_MODULO, CTA.COD_MODALIDAD, CTA.ESTADO, DECODE(dat.val_parametro,null,EST.DESCRIPCION,'CARTERA VENDIDA') DESCRIPCION, EST.ACTIVO,
       MAD.DESCRIPCION SC_NMMODAL, det.can_cuo_pagadas, det.can_cuotas
  from GE_MODALIDADES MAD,GE_EST_CUENTAS EST, pr_cta_prestamos det, GE_CUENTAS CTA, GE_CTA_CLIENTES CLI,
      (select nro_cuenta, val_parametro from ge_cta_dat_adicionales where parametro = 'ENT_ADM_CARTERA') DAT
 where EST.COD_MODULO = CTA.COD_MODULO
   AND EST.COD_MODALIDAD = CTA.COD_MODALIDAD
   AND EST.ESTADO = CTA.ESTADO
   AND CTA.NRO_CUENTA = CLI.NRO_CUENTA
   AND MAD.COD_MODULO = CTA.COD_MODULO
   AND MAD.COD_MODALIDAD = CTA.COD_MODALIDAD
   and cta.nro_cuenta = det.nro_cuenta
   and cta.nro_cuenta = dat.nro_cuenta(+)
UNION ALL
--solicitudes
Select 'Prop.Nro.'||to_char(det.nro_solicitud) nro_cuenta, DET.COD_PERSONA, DET.DESCRIPCION, DET.COD_MONEDA, nvl(det.fec_ini_rrr,det.fec_inicio), det.fec_vencimiento,
       'P' RELACION, DET.COD_MODULO, DET.COD_MODALIDAD, DET.ESTADO, EST.SIGNIFICADO, DECODE(DET.ESTADO,'N','N','R','N','S') ACTIVO,
       MAD.DESCRIPCION SC_NMMODAL, 0 can_cuo_pagadas, CUO.CAN_CUOTAS
  from GE_MODALIDADES MAD,BA_COD_REFERENCIAS EST, (SELECT MAX(NRO_CUOTA) CAN_CUOTAS, NRO_SOLICITUD FROM PR_SOL_CUOTAS GROUP BY NRO_SOLICITUD) CUO, pr_solicitudes det
 where EST.DOMINIO = 'EST_SOLICITUD'
   AND EST.VAL_MINIMO = DET.ESTADO
   AND MAD.COD_MODULO = DET.COD_MODULO
   AND MAD.COD_MODALIDAD = DET.COD_MODALIDAD
   AND DET.NRO_SOLICITUD = CUO.NRO_SOLICITUD
   AND DET.ESTADO <> 'A' --ya es un préstamo
--Validación Dto. de Cheques
UNION ALL
SELECT 'Sol.Nro.'||to_char(det.nro_solicitud) nro_cuenta, det.cod_persona, det.descripcion, det.cod_moneda, det.fecha, det.fec_vencimiento,
       'P' relacion, det.cod_modulo, det.cod_modalidad, det.estado, est.significado, DECODE(det.estado,'C','N','D','N','S') ACTIVO,
       'Fabrica Dto. de Cheques' sc_nmmodal, 0 can_cuo_pagadas, cuo.can_cuotas
  FROM ba_cod_referencias est, pr_fad_solicitudes det,
       (SELECT max(nro_cuota) can_cuotas, nro_solicitud FROM pr_fad_che_custodias GROUP BY nro_solicitud) CUO
 WHERE EST.DOMINIO = 'FAD_ESTADOS'
   AND EST.VAL_MINIMO = DET.ESTADO
   AND DET.NRO_SOLICITUD = CUO.NRO_SOLICITUD
;

