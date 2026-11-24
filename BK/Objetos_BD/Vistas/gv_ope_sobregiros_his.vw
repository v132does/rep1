create or replace force view it.gv_ope_sobregiros_his as
select nro_cuenta, mon_sobregiro, cuota_sobregiro,
       fecha_sobregiro, saldo_anterior, fec_liquidacion,fec_apertura_cc, cod_moneda,
       saldo_sobregiro, decode(calculado,'N',dias_sobregiro,null) dias_sobregiro, can_dias,
       tipo_ope_cc, decode(calculado,'N',mto_pagar_cc,0) mto_pagar_cc
from
   (select t.nro_cuenta,cc.cod_moneda mon_sobregiro,1 cuota_sobregiro,
           t.fecha fecha_sobregiro,lag(t.saldo) over (order by t.fecha) saldo_anterior,
           l.fec_liquidacion fec_liquidacion,cc.fec_apertura fec_apertura_cc, cc.cod_moneda cod_moneda,
           t.saldo saldo_sobregiro,t.can_dias dias_sobregiro, l.can_dias can_dias, '189' tipo_ope_cc,
           t.saldo mto_pagar_cc,
           decode (t.fecha + 1, lead(t.fecha) over (order by t.fecha),'S','N') calculado
      from cc_sobregiros t, cc_cta_corrientes cc, cc_liq_sobregiros l
     where t.nro_cuenta = cc.nro_cuenta
       and t.nro_cuenta = l.nro_cuenta(+)
       and t.fecha = l.fecha (+))
     order by fecha_sobregiro;

