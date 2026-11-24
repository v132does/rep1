create or replace force view it.simgia_archcerti as
select
cc.cod_oficina CSUC,
substr(pai_int.FU_OBT_CTA_CONTABLE(cb.cod_rubro),1,6) CCTA,
substr(ch.nro_cuenta,-6) CSUB,
nvl(ch.nro_cheque,0) CNRO,
nvl(ch.monto,0) CIMPORTE,
nvl(to_char(ch.fec_pago,'DDMMYY'),0) CFEPAGO,
nvl(to_char(ch.fecha,'DDMMYY'),0) CFEMISI
 from cc_che_certificados ch, ge_cta_clientes gc, ge_clientes c, cc_cta_corrientes cc, cc_cta_bancarias cb
    where ch.nro_cuenta=gc.nro_cuenta--cheque con cta-cliente
    and gc.cod_persona=c.cod_persona--cta-cliente con cliente
    and cc.nro_cuenta=ch.nro_cuenta--cta-corriente con che-certificado
    and ch.nro_cta_certificado=cb.nro_cuenta
    and ch.fec_pago is null
    and gc.relacion='P'
;

