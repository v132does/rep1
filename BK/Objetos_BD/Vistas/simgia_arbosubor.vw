create or replace force view it.simgia_arbosubor as
select accer.ser_titulo BSSERIE,
       accer.nro_certificado BSNUMERO,
       acup.nro_cupon BSCUPON,
       accer.nro_titulo BSTITUR,
       accer.cod_oficina BSSUC,
       gccli.cod_persona BSNUMCLIEN,
       '0' BSAGENTE,
       decode(accer.cod_moneda,'GS','0','USD','5','EUR','17') BSMONEDA,
       acup.mto_interes BSMONTO, to_char(accer.fec_hor_emision, 'yyyymmdd') BSFEMISI,
       to_char(accer.fec_vencimiento, 'yyyymmdd') BSVENCIM,
       'F' BSTIPOT,
       round(nvl(gtfe.val_tasa,0), 2) BSTASA1,
       round(nvl(gtfe.val_tasa,0), 2) BSTASA2,
       round(nvl(gtfe.val_tasa,0), 2) BSTASA3,
       round(nvl(gtfe.val_tasa,0), 2) BSTASA4,
       '0.00' BSLRM_LIB,
       to_char(PAI_INT.FU_SIM_OBT_FECHAINI_CUPONES(acup.nro_cuenta, acup.nro_cupon),'yyyymmdd') BSFEINI,
       nvl(PAI_INT.FU_SIM_OBT_MTO_ADEV_CDA(acup.nro_cuenta, acup.nro_cupon, accer.fec_apertura),0) BSDEVENG,
       accer.usu_insercion BSUSUARIO,
       to_char(accer.fec_apertura, 'yyyymmdd') BSFEREG,
       ' ' BSPIGNO
from   ge_tas_fechas gtfe, ah_cta_certificados accer, ah_cupones acup, ge_cta_clientes gccli
where  accer.nro_cuenta = acup.nro_cuenta
and    gccli.nro_cuenta = accer.nro_cuenta
and    gtfe.nro_cuenta(+) = accer.nro_cuenta
and    gccli.relacion = 'P'
and    accer.cod_modalidad = 36
and    acup.estado in ('E','V')

UNION ALL
/* se agrega para capital */

select accer.ser_titulo BSSERIE,
       accer.nro_certificado BSNUMERO,
       0 BSCUPON,
       accer.nro_titulo BSTITUR,
       accer.cod_oficina BSSUC,
       gccli.cod_persona BSNUMCLIEN,
       '0' BSAGENTE,
       decode(accer.cod_moneda,'GS','0','USD','5','EUR','17') BSMONEDA,
       accer.capital BSMONTO,
       to_char(accer.fec_hor_emision, 'yyyymmdd') BSFEMISI,
       to_char(accer.fec_vencimiento, 'yyyymmdd') BSVENCIM,
       'F' BSTIPOT,
       round(nvl(gtfe.val_tasa,0), 2) BSTASA1,
       round(nvl(gtfe.val_tasa,0), 2) BSTASA2,
       round(nvl(gtfe.val_tasa,0), 2) BSTASA3,
       round(nvl(gtfe.val_tasa,0), 2) BSTASA4,
       '0.00' BSLRM_LIB,
       '0' BSFEINI,
       0 BSDEVENG,
       accer.usu_insercion BSUSUARIO,
       to_char(accer.fec_apertura, 'yyyymmdd') BSFEREG,
       ' ' BSPIGNO
from   ge_tas_fechas gtfe, ah_cta_certificados accer, ge_cta_clientes gccli
where  gccli.nro_cuenta = accer.nro_cuenta
and    gtfe.nro_cuenta(+) = accer.nro_cuenta
and    gccli.relacion = 'P'
and    accer.cod_modalidad = 36
and    accer.estado not in ('A','C','T','X')
and    accer.est_certificado <> 'P';

