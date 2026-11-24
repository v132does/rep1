create or replace force view it.ov_prt_atrasos as
select distinct x.cod_persona, x.nro_cuenta from (
  select c.cod_persona, a.nro_cuenta, a.fec_vencimiento, a.fec_ult_pago,
         case when
           (a.fec_vencimiento < pag_cal.fu_obt_fec_actual(6)
            and a.estado != 'N') then
            pag_cal.fu_obt_fec_actual(6) - a.fec_vencimiento
            when
           (a.fec_vencimiento < a.fec_ult_pago
            and a.estado = 'N') then
            a.fec_ult_pago - a.fec_vencimiento
            else
            0 end as dia_mora
    from pr_cuotas a, pr_cta_prestamos b, ge_cta_clientes c
   where a.nro_cuenta = b.nro_cuenta
     and a.nro_cuota > 0
     and b.estado not in ('N','I')
     and c.nro_cuenta = b.nro_cuenta
     and c.relacion = 'P'
) x
where x.dia_mora > fug_obt_pardinamico('MIN_DIA_ATR_COB_TERCERIZADAS',6)
  and x.fec_vencimiento >= add_months(to_date('01/'||to_char(pag_cal.fu_obt_fec_actual(6),'mm/yyyy'),'dd/mm/yyyy') ,-3);

