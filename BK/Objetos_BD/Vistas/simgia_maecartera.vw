create or replace force view it.simgia_maecartera as
select to_char(pag_cal.fu_obt_fec_actual(8), 'DDMMYY') fecha,
 sucursal,
 cliente riesgo,
       0 succuenta,
       0 propue,
       nvl(c.cod_rub_externo,0) codigo,
       /*substr(nro_cuenta, -6)*/ '' NUMDOC, --se toman los últimos 6 dígitos de la cuenta para adecuar al tamaño del archivo
       importe_ml importe,
       0 intereses,
       importe_me montodivis,
       decode(b.cod_moneda, 'GS', 0, 'XXX', 1, 'XXX', 2, 'XXX', 3, 'XXX', 4, 'USD', 5, 'XXX', 6, 'CHF', 7, 'XXX', 8, 'XXX', 9, 'GBP', 10,
                                  'XXX', 11, 'XXX', 12, 'XXX', 13, 'JPY', 14, 'ARS', 15, 'XXX', 16, 'EUR', 17, 'UYU', 20, 'CAD', 28) codivisa,
       fec_vencimiento venci,
       0 estado,
       0 indparaest,
       0 banren,
       0 doccodtasa,
       0 docnrolibr,
       31 origensucu,
       99 origenserv,
       rownum doclinea, --nro_secuencial dentro del archivo DOCLINEA
       0 ctaintact,
       0 ctaintpas,
       nro_cuenta||';' filler
       /*,cod_modalidad*/
from cb_rubros c,
      (

      /* m_cta_documentos y rev repo */
      select mcdoc.nro_cuenta nro_cuenta,
      mcdoc.cod_modalidad,
      mcdoc.cod_oficina sucursal,
      mcdoc.cod_persona cliente,
            /*fub_obt_rub_contable(mcdoc.cod_modulo, mcdoc.nro_cuenta, 'A' ) rubro,*/
            fub_obt_rub_transaccion(mcdoc.cod_modulo,
                                                        mcdoc.cod_modalidad,
                                                         case
                                                           when mcdoc.cod_sit_contable=10000001 then 805
                                                           when mcdoc.cod_sit_contable<>10000001 then 711
                                                         end, /*codigo transaccion*/
                                                        mcdoc.cod_moneda,
                                                        gccli.cod_persona,
                                                        fug_obt_plz_contable(mcdoc.fec_vencimiento - mcdoc.fec_inicio),
                                                        'D',
                                                        mcdoc.estado, null, null, null, null,
                                                        mcdoc.cod_sit_contable) rubro,
             decode(mcdoc.cod_moneda, 'GS',decode(mcdoc.cod_modalidad,104,mcdoc.val_presente,monto),
                        pag_gen.FU_CON_MON_A_MONEDA(mcdoc.cod_moneda, 'GS', decode(mcdoc.cod_modalidad,104,mcdoc.val_presente,monto) )) importe_ml, --en moneda local
             decode(mcdoc.cod_moneda, 'GS',0, decode(mcdoc.cod_modalidad,104,mcdoc.val_presente,monto) ) importe_me,
             mcdoc.cod_moneda,
             to_char(fec_vencimiento, 'DDMMYY') fec_vencimiento
      from md_cta_documentos mcdoc, ge_cta_clientes gccli
      where mcdoc.nro_cuenta = gccli.nro_cuenta
      and   gccli.relacion = 'P'
      and mcdoc.estado <> 'N'
      /*and  (mcdoc.cod_modalidad in (104,124) or (mcdoc.estado='C' and mcdoc.fec_ven_repo is not null))*/
      and  (mcdoc.cod_modalidad in (104,124) or mcdoc.val_bas_repo is null and mcdoc.fec_ven_repo is not null)
            ) b
where c.cod_rubro(+) = b.rubro
;

