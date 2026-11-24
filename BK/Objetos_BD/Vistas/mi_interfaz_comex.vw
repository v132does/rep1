create or replace force view it.mi_interfaz_comex as
select to_char(pag_cal.fu_obt_fec_actual(8), 'DDMMYY') fecha, sucursal, cliente riesgo,
       0 succuenta, 0 propue,
       nvl(c.cod_rub_externo,0) codigo,
       /*substr(nro_cuenta, -6)*/ '' NUMDOC, --se toman los últimos 6 dígitos de la cuenta para adecuar al tamaño del archivo
       importe_ml importe, 0 intereses, importe_me montodivis,
       decode(b.cod_moneda, 'GS', 0, 'XXX', 1, 'XXX', 2, 'XXX', 3, 'XXX', 4, 'USD', 5, 'XXX', 6, 'CHF', 7, 'XXX', 8, 'XXX', 9, 'GBP', 10,
                                  'XXX', 11, 'XXX', 12, 'XXX', 13, 'JPY', 14, 'ARS', 15, 'XXX', 16, 'EUR', 17, 'UYU', 20, 'CAD', 28) codivisa,
       fec_vencimiento vencimiento,
       0 estado, 0 indparaest, 0 banren, 0 doccodtasa, 0 docnrolibr,
       31 origensucu, 99 origenserv,
       rownum doclinea, --nro_secuencial dentro del archivo DOCLINEA
       0 ctaintact, 0 ctaintpas, nro_cuenta||';' filler
from cb_rubros c,
      (
      --cci utilizadas con saldo
      select a.nro_cuenta nro_cuenta, a.cod_modalidad, a.cod_oficina sucursal, b.cod_persona cliente,
             fub_obt_rub_contable(a.cod_modulo, a.nro_cuenta, 'U' ) rubro,
             decode(a.cod_moneda, 'GS', nvl(x.sal_utilizado,0),
                    pag_gen.FU_CON_MON_A_MONEDA(a.cod_moneda, 'GS',nvl(x.sal_utilizado,0))) importe_ml, --en moneda local
             decode(a.cod_moneda, 'GS', 0, nvl(x.sal_utilizado,0)) importe_me,
             a.cod_moneda, to_char(x.fec_vencimiento, 'DDMMYY') fec_vencimiento
      from  cx_cta_importaciones a, ge_cta_clientes b, (select nro_cuenta cuenta, fec_vencimiento, sum(saldo) sal_utilizado
                                                          from cx_embarques
                                                         group by nro_cuenta, fec_vencimiento) x
      where a.nro_cuenta = b.nro_cuenta
        and b.relacion ='P'
        and x.cuenta = a.nro_cuenta
        and fux_obt_sal_mto_utilizado(a.nro_cuenta) > 0 --sólo si tiene saldo utilizado pendiente de cobro
      union all
      select a.nro_cuenta nro_cuenta, a.cod_modalidad, a.cod_oficina sucursal, b.cod_persona cliente,
             fub_obt_rub_contable(a.cod_modulo, a.nro_cuenta, 'A' ) rubro,
             decode(a.cod_moneda, 'GS', (saldo - fux_obt_sal_mto_utilizado(a.nro_cuenta)),
                    pag_gen.FU_CON_MON_A_MONEDA(a.cod_moneda, 'GS', (saldo - fux_obt_sal_mto_utilizado(a.nro_cuenta)))) importe_ml, --en moneda local
             decode(a.cod_moneda, 'GS',0,(saldo - fux_obt_sal_mto_utilizado(a.nro_cuenta))) importe_me,
             a.cod_moneda,
             -- en cx_embarques se registran los saldos utilizados con pendiente de cobro o utilizados parcialmente
             -- si en cta_importaciones el monto utilizado es 0 no se generan archivos en cx_embarques y y la fecha de vencimiento es la de cta_importaciones
             -- si existen monto utilizados se utiliza la fec_vto_plazo de cta_importaciones q equivale a la fec_vencimiento de cx_embarques
             decode( fec_vto_plazo,null, to_char(fec_vencimiento, 'DDMMYY'),to_char(fec_vto_plazo, 'DDMMYY') ) fec_vencimiento
      from  cx_cta_importaciones a, ge_cta_clientes b
      where a.nro_cuenta = b.nro_cuenta
        and b.relacion ='P'
        and (saldo - fux_obt_sal_mto_utilizado(a.nro_cuenta)) > 0--sólo si tiene saldo no utilizado
      union all
      --cce sólo confirmadas
      select a.nro_cuenta nro_cuenta, a.cod_modalidad, a.cod_oficina sucursal, b.cod_persona cliente,
             fub_obt_rub_contable(a.cod_modulo, a.nro_cuenta, 'A' ) rubro,
             decode(a.cod_moneda, 'GS', (saldo - fux_obt_sal_mto_utilizado(a.nro_cuenta)),
                    pag_gen.FU_CON_MON_A_MONEDA(a.cod_moneda, 'GS', (saldo - fux_obt_sal_mto_utilizado(a.nro_cuenta)))) importe_ml, --en moneda local
             decode(a.cod_moneda, 'GS',0,(saldo - fux_obt_sal_mto_utilizado(a.nro_cuenta))) importe_me,
             a.cod_moneda,
             --to_char(fec_vencimiento, 'DDMMYY') fec_vencimiento --hasta 20100531
             --al igual que en importaciones, se toma la fecha de la ultima cuota para saldos parcialmente utilizadas
             decode( pai_int.exp_fec_ult_cuota(b.nro_cuenta),null, to_char(a.fec_vencimiento, 'DDMMYY'), to_char( pai_int.exp_fec_ult_cuota(b.nro_cuenta), 'DDMMYY') ) fec_vencimiento
      from  cx_cta_exportaciones a, ge_cta_clientes b
      where a.nro_cuenta = b.nro_cuenta
        and b.relacion ='P'
        and (saldo - fux_obt_sal_mto_utilizado(a.nro_cuenta)) > 0--sólo si tiene saldo no utilizado
        and confirmado = 'S'
      union all
      select a.nro_cuenta nro_cuenta, a.cod_modalidad, a.cod_oficina sucursal, b.cod_persona cliente,
             fub_obt_rub_contable(a.cod_modulo, a.nro_cuenta, 'U' ) rubro,
             decode(a.cod_moneda, 'GS', nvl(x.sal_utilizado,0),
                    pag_gen.FU_CON_MON_A_MONEDA(a.cod_moneda, 'GS',nvl(x.sal_utilizado,0))) importe_ml, --en moneda local
             decode(a.cod_moneda, 'GS',0, nvl(x.sal_utilizado,0)) importe_me,
             a.cod_moneda, to_char(x.fec_vencimiento, 'DDMMYY') fec_vencimiento
      from  cx_cta_exportaciones a, ge_cta_clientes b, (select nro_cuenta cuenta, fec_vencimiento, sum(saldo) sal_utilizado
                                                          from cx_embarques
                                                         group by nro_cuenta, fec_vencimiento) x
      where a.nro_cuenta = b.nro_cuenta
        and b.relacion ='P'
        and x.cuenta = a.nro_cuenta
        and a.confirmado = 'S'
        and (fux_obt_sal_mto_utilizado(a.nro_cuenta)) > 0--sólo si tiene saldo no utilizado
      union all
      --cobranzas de importación avaladas
      select a.nro_cuenta nro_cuenta, a.cod_modalidad, a.cod_oficina sucursal, b.cod_persona cliente,
             fub_obt_rub_contable(a.cod_modulo, a.nro_cuenta, 'A' ) rubro,
             decode(a.cod_moneda, 'GS', saldo,
                    pag_gen.FU_CON_MON_A_MONEDA(a.cod_moneda, 'GS', saldo)) importe_ml, --en moneda local
             decode(a.cod_moneda, 'GS',0, saldo) importe_me, a.cod_moneda, to_char(fec_vencimiento, 'DDMMYY') fec_vencimiento
      from  cx_cta_cobranzas a, ge_cta_clientes b
      where a.nro_cuenta = b.nro_cuenta
        and b.relacion ='P'
        and a.cod_modalidad = 83
        and a.avalada = 'S'
        and a.estado = 'A'
        and saldo > 0 --sólo si tiene saldo
      union all
      --fianzas emitidas
      select a.nro_cuenta nro_cuenta, a.cod_modalidad, a.cod_oficina sucursal, b.cod_persona cliente,
             fub_obt_rub_contable(a.cod_modulo, a.nro_cuenta, 'A' ) rubro,
             decode(a.cod_moneda, 'GS', monto,
                    pag_gen.FU_CON_MON_A_MONEDA(a.cod_moneda, 'GS', monto)) importe_ml, --en moneda local
             decode(a.cod_moneda, 'GS',0,monto) importe_me, a.cod_moneda, to_char(fec_vencimiento, 'DDMMYY') fec_vencimiento
      from  cx_fianzas a, ge_cta_clientes b
      where a.nro_cuenta = b.nro_cuenta
        and b.relacion ='P'
        and a.cod_modalidad = 88
        and a.estado = 'A'
      ) b
where c.cod_rubro(+) = b.rubro
;

