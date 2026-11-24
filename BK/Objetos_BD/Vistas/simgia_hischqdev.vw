create or replace force view it.simgia_hischqdev as
select to_char(nvl(to_char(ccde.fecha, 'yyyymmdd'),0)) BFECDIA,
       to_number(nvl(ccde.cod_bco_receptor,0)) BBCOINF,
       to_char(nvl((select a.cod_persona from ge_cta_clientes a where a.nro_cuenta = ccde.nro_cuenta and a.relacion like 'P'),0)) BCLIENTE,
       nvl(substr(ccde.nro_cuenta,1,2)||pai_int.FU_SIM_OBT_TIP_CUENTA(substr(ccde.nro_cuenta, 3, 2), ccde.cod_moneda),'') BCTIPCTA,
       nvl(substr(ccde.nro_cuenta, 5, 6),'') BCCUENTA,
       to_char(nvl(ccde.nro_cheque,0)) BCHQNRO,
       nvl(PAI_INT.FU_SIM_NORM_CADENA((select b.abreviatura from ba_tip_documentos b, ba_personas c, ge_cta_clientes d where c.cod_persona = d.cod_persona and d.nro_cuenta = ccde.nro_cuenta and c.cod_tip_documento = b.cod_tip_documento and d.relacion like 'P' ),3),'') BTIPDOC,
       nvl((select e.nro_documento from ba_personas e, ge_cta_clientes f where e.cod_persona = f.cod_persona and f.nro_cuenta = ccde.nro_cuenta and f.relacion like 'P'),'') BDOCUM,
       0 BFECGIR,
       nvl(ccde.monto,0) BIMPORTE,
       nvl(PAI_INT.FU_SIM_NORM_CADENA(decode(ccde.cod_causa,106,1,107,2,108,3,109,4,110,5,111,6,128,7,129,8,130,9)||substr((select g.descripcion from ge_causales g where g.cod_causa = ccde.cod_causa),1,16),17),'') BMOTIVO

from cc_che_devueltos ccde;

