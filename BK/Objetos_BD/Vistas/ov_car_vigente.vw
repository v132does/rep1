create or replace force view it.ov_car_vigente as
select distinct b.cod_persona, b.nro_cuenta
    from ta_cta_tarjetas a,
         ge_cta_clientes b
   where a.nro_cuenta = b.nro_cuenta
     and b.relacion = 'P'
     and a.estado = 'N'
     and a.dia_mora = 0
     and a.nro_cta_debito is null
     and a.sal_procesadora > 0
     and to_char(a.fec_ult_pago,'mm/yyyy') != to_char(pag_cal.fu_obt_fec_actual(5),'mm/yyyy')
     and a.fec_vct_ult_cierre >= pag_cal.fu_obt_fec_proxima(5)
     and a.fec_vct_ult_cierre <= pag_cal.fu_obt_fec_sig_hab(pag_cal.fu_obt_fec_actual(5),a.cod_oficina,5)
  union
  select distinct c.cod_persona, a.nro_cuenta
    from pr_cta_prestamos a,
         ge_cta_clientes c
   where c.nro_cuenta = a.nro_cuenta
     and c.relacion = 'P'
     and a.estado not in ('N','I')
     and a.dia_atraso = 0
     and a.nro_cta_debito is null
     and exists (select 1 from pr_cuotas b
                  where b.nro_cuenta = a.nro_cuenta
                    and b.fec_vencimiento >= pag_cal.fu_obt_fec_proxima(6)
                    and b.fec_vencimiento <= pag_cal.fu_obt_fec_sig_hab(pag_cal.fu_obt_fec_actual(6),a.cod_oficina,5)
                    and b.sal_capital > 0);

