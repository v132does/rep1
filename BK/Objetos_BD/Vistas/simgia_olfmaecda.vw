create or replace force view it.simgia_olfmaecda as
select
/* CAPITAL */
nvl(e.cod_persona,0) riesgo,
nvl(c.cod_oficina,0) sucursal,
nvl(c.nro_certificado,0) numero,
c.nro_cuenta,
c.estado PAGADO,
nvl(
case
when c.cod_moneda = 'USD' then c.serie || 'D'
else
c.serie
end
,'') SERIE,
0 CUPON,
       c.capital MONTO,
       nvl(to_char(c.fec_apertura, 'ddmmyy'),'0') fecha,
       nvl((c.fec_vencimiento - c.fec_apertura),0) plazo,
       nvl(to_char(c.fec_vencimiento, 'yyyymmdd'),0) vencto,
       nvl(pai_int.fu_obt_val_tasa(c.cod_modulo, c.cod_modalidad, c.cod_oficina, c.nro_cuenta, c.cod_moneda, c.capital,
                               c.tas_personalizada, c.cod_tasa, c.fec_apertura),0)  tasa,
       nvl(decode(c.tip_capitalizacion,
       99,0,
       c.tip_capitalizacion),0) formpago,
       nvl(pai_int.fu_obt_cla_cliente(e.cod_persona),0) CLASE,
       nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(c.cod_modulo,
                                                           c.cod_modalidad,
                                                           CASE
                                                            when est_certificado = 'V' then 604
                                                            when est_certificado <> 'V' then 602
                                                           end,
                                                           c.cod_moneda,
                                                           e.cod_persona,
                                                           fug_obt_plz_contable(c.fec_vencimiento - c.fec_apertura),
                                                           'C',
                                                            c.estado)),0) CUENTA,
/*campo provisorio*/ fub_obt_rub_transaccion(c.cod_modulo,
                                                           c.cod_modalidad,
                                                           CASE
                                                            when est_certificado = 'V' then 604
                                                            when est_certificado <> 'V' then 602
                                                           end,
                                                           c.cod_moneda,
                                                           e.cod_persona,
                                                           fug_obt_plz_contable(c.fec_vencimiento - c.fec_apertura),
                                                           'C',
                                                            c.estado) cuenta_rub_transaccion,
       '0' CTAPREV,
       '' CTAPREV_rub_transaccion,
       nvl(pai_int.fu_obt_tip_deposito(c.cod_modalidad,
                                   c.cod_moneda),0) TIPODEP,
       nvl(pai_int.fu_obt_tip_relacion(c.nro_cuenta),'') CONJIND,
      /* nvl(pai_int.fu_obt_est_cuenta(c.cod_modalidad,
                                       c.estado ),0) ESTADO,*/
                                        0 ESTADO, /*solo se envia estado 0, Victor Palomar, 20091219*/
       nvl( pai_int.fu_ver_pignoracion(c.nro_cuenta),0) PIGNORADO,
        0 CTARESPIG,
       nvl(c.usu_insercion,'') USUARIOPR

from ah_cta_certificados c, ge_cta_clientes e
where c.nro_cuenta = e.nro_cuenta
and c.cod_modalidad !=36
and c.estado not in ('A','C','T','X')
and c.est_certificado <> 'P'
and c.nro_certificado <> 0
and e.relacion = 'P'

union all

/* INTERES */
select nvl(e.cod_persona,0) riesgo,
nvl(c.cod_oficina,0) sucursal,
nvl(c.nro_certificado,0) numero,
c.nro_cuenta,
c.estado PAGADO,
nvl(
case
when c.cod_moneda = 'USD' then c.serie || 'D'
else
c.serie
end
,'') SERIE,
nvl(o.nro_cupon,0) CUPON,
       nvl(o.mto_interes,0) MONTO,
       nvl(to_char(c.fec_apertura, 'ddmmyy'),'0') fecha,
       nvl((o.fec_vencimiento - c.fec_apertura),0) plazo,
       nvl(to_char(o.fec_vencimiento,'yyyymmdd'),'0') vencto,
       nvl(pai_int.fu_obt_val_tasa(c.cod_modulo, c.cod_modalidad, c.cod_oficina, c.nro_cuenta, c.cod_moneda, c.capital,
                               c.tas_personalizada, c.cod_tasa, c.fec_apertura),0)  tasa,
       nvl(decode(c.tip_capitalizacion,
       99,0,
       c.tip_capitalizacion),0) formpago,
       nvl(pai_int.fu_obt_cla_cliente(e.cod_persona),0) CLASE,
       nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(c.cod_modulo,
                                                           c.cod_modalidad,
                                                           CASE
                                                            when o.estado = 'V' then 609
                                                            when o.estado <> 'V' then 901
                                                           end,
                                                           c.cod_moneda,
                                                           e.cod_persona,
                                                           fug_obt_plz_contable(c.fec_vencimiento - c.fec_apertura),
                                                           'C',
                                                            c.estado)),0) CUENTA,
       /*campo provisorio*/ fub_obt_rub_transaccion(c.cod_modulo,
                                                           c.cod_modalidad,
                                                           CASE
                                                            when o.estado = 'V' then 609
                                                            when o.estado <> 'V' then 901
                                                           end,
                                                           c.cod_moneda,
                                                           e.cod_persona,
                                                           fug_obt_plz_contable(c.fec_vencimiento - c.fec_apertura),
                                                           'C',
                                                            c.estado) cuenta_rub_transaccion,
       nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(c.cod_modulo,
                                                           c.cod_modalidad,
                                                           400,
                                                           c.cod_moneda,
                                                           e.cod_persona,
                                                           fug_obt_plz_contable(c.fec_vencimiento - c.fec_apertura),
                                                           'C',
                                                            c.estado)),'0') CTAPREV,
        /*campo provisorio*/ fub_obt_rub_transaccion(c.cod_modulo,
                                                           c.cod_modalidad,
                                                           400,
                                                           c.cod_moneda,
                                                           e.cod_persona,
                                                           fug_obt_plz_contable(c.fec_vencimiento - c.fec_apertura),
                                                           'C',
                                                            c.estado) CTAPREV_rub_transaccion,
       nvl(pai_int.fu_obt_tip_deposito(c.cod_modalidad,
                                   c.cod_moneda),0) TIPODEP,
       nvl(pai_int.fu_obt_tip_relacion(c.nro_cuenta),'') CONJIND,
       /*nvl(pai_int.fu_obt_est_cuenta(c.cod_modalidad,
                                       c.estado ),0) ESTADO,*/
                                       0 ESTADO,/*solo se envia estado 0, Victor Palomar, 20091219*/
       /*pai_int.fu_ver_pignoracion(c.nro_cuenta) solo queda en la cabezera*/ 0 PIGNORADO,

        /*pai_int.fui_obt_dev_cda(c.nro_cuenta,
                               c.capital,
                               c.fec_apertura,
                               '31082009'pag_cal.fu_obt_fec_actual(c.cod_modulo))*/

        nvl(pai_int.FU_SIM_OBT_MTO_ADEV_CDA(c.nro_cuenta, o.nro_cupon, c.fec_apertura),0) CTARESPIG,

       nvl(c.usu_insercion,'') USUARIOPR
from ah_cta_certificados c, ge_cta_clientes e, ah_cupones o
where c.nro_cuenta = e.nro_cuenta
and o.nro_cuenta = c.nro_cuenta
and c.cod_modalidad !=36
and c.estado not in ('A','C','T','X')
and o.estado in ('E','V')
and c.nro_certificado <> 0
/*se omite 18 registros*/and e.relacion = 'P';

