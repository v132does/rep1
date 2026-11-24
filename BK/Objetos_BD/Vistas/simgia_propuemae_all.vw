create or replace force view it.simgia_propuemae_all as
select
       nvl(gccli.cod_persona,0) PROPCLIEN,---numero cliente
       nvl(pcp.cod_oficina,0) PROPSUC,----sucursal
       nvl(to_number(substr(pcp.nro_cuenta,-6)),0) PROPNRO,
       nvl(to_char(pcp.fec_inicio, 'DDMMYY'),'0') PROPFECHA,
       nvl(decode(pcp.cod_moneda,'GS',pcp.mto_capital,
              pag_gen.FU_CON_MON_A_MONEDA(pcp.cod_moneda,'GS',pcp.monto)),0)PROPMONTO,---mto en guaranies
       0 PROPOPERAC,
       nvl(to_char(pcp.fec_vencimiento, 'DDMMYY'),'0') PROPVTO,
       0 PROPREN,
       nvl(decode(pcp.cod_moneda, 'GS', 0, 'XXX', 1, 'XXX', 2, 'XXX', 3, 'XXX', 4, 'USD', 5, 'XXX', 6, 'CHF', 7, 'XXX', 8, 'XXX', 9, 'GBP', 10,
                                 'XXX', 11, 'XXX', 12, 'XXX', 13, 'JPY', 14, 'ARS', 15, 'XXX', 16, 'EUR', 17, 'UYU', 20, 'CAD', 28),0)  PROPDIVI,
       decode(pcp.cod_moneda, 'GS',0,pcp.mto_capital)PROPME,---monto si es en moneda extranjera
       0 PROPTPGAR1,
       0 PROPMTGAR1,
       0 PROPTPGAR2,
       0 PROPMTGAR2,
       0 PROPTPGAR3,
       0 PROPMTGAR3,
       0 PROPTPGAR4,
       0 PROPMTGAR4,
       0 PROPTPGAR5,
       0 PROPMTGAR5,
       0 PROPTPGAR6,
       0 PROPMTGAR6,
       nvl(PAI_INT_F4.obt_cod_aval(pcp.nro_cuenta, 1),0) PROPAVAL1,---selecciona el codigo persona del aval
       nvl(PAI_INT_F4.obt_cod_aval(pcp.nro_cuenta, 2),0) PROPAVAL2,
       nvl(PAI_INT_F4.obt_cod_aval(pcp.nro_cuenta, 3),0) PROPAVAL3,
       nvl(PAI_INT_F4.obt_cod_aval(pcp.nro_cuenta, 4),0)PROPAVAL4,
       nvl(PAI_INT_F4.obt_cod_aval(pcp.nro_cuenta, 5),0)PROPAVAL5,
       0 PROPLINEA,
       '0' PROPOBS1,
       '0' PROPOBS2,
       '0' PROPOBS3,
       '0' PROPOBS4,
       0 PROPRELIQ,
       0 PROPSECTOR,
      decode(pcp.tip_destino, 3,3,4,2,1) PROPDESTIN,
       0 PROPREGION,
       0 PROPUSOCRE,
       0 PROPCEDNT,
       0 PROPNROFAC,
       0 PROPTASAMX,
       pcp.nro_cuenta

from pr_cta_prestamos pcp, ge_cta_clientes gccli
  where pcp.nro_cuenta = gccli.nro_cuenta
  and gccli.relacion = 'P'
;

