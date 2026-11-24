create or replace force view it.ov_cli_nom_deb_aut as
select distinct cod_persona from (
  select distinct d.cod_persona
    from pr_cta_prestamos a,
         (/*no_cuentas*/
          select b.cliente, b.nro_cuenta
            from gv_pago_sueldo b
           where b.fec_proceso >= add_months(pag_cal.fu_obt_fec_actual(1),-1)) c,
         ge_cta_clientes d
   where c.nro_cuenta = a.nro_cta_debito
     and d.nro_cuenta = a.nro_cuenta
     and d.relacion = 'P'
     and a.estado != 'N'
union
  select distinct cod_persona
    from ta_cta_tarjetas a,
         (/*no_cuentas*/
          select b.cliente, b.nro_cuenta
            from gv_pago_sueldo b
           where b.fec_proceso >= add_months(pag_cal.fu_obt_fec_actual(1),-1)) c,
         ge_cta_clientes d
   where c.nro_cuenta = a.nro_cta_debito
     and d.nro_cuenta = a.nro_cuenta
     and d.relacion = 'P'
     and a.estado != 'N'
) j
where not exists (  select distinct c.cod_persona
                      from pr_cta_prestamos a,
                           ge_cta_clientes c,
                           gv_pago_sueldo d
                     where a.nro_cuenta = c.nro_cuenta
                       and a.estado != 'N'
                       and c.relacion = 'P'
                       and d.cliente = c.cod_persona
                       and c.cod_persona = j.cod_persona
                       and d.fec_proceso >= add_months(pag_cal.fu_obt_fec_pri_dia_mes_habil(1),-1)
                       and not exists (select 1 from gv_pago_sueldo b
                                        where b.cliente = c.cod_persona
                                          and b.nro_cuenta = a.nro_cta_debito
                                          and b.fec_proceso >= add_months(pag_cal.fu_obt_fec_pri_dia_mes_habil(1),-1)))
  and not exists (  select distinct cod_persona
                      from ta_cta_tarjetas a,
                           ge_cta_clientes c,
                           gv_pago_sueldo d
                     where a.nro_cuenta = c.nro_cuenta
                       and a.estado != 'C'
                       and c.relacion = 'P'
                       and d.cliente = c.cod_persona
                       and c.cod_persona = j.cod_persona
                       and d.fec_proceso >= add_months(pag_cal.fu_obt_fec_pri_dia_mes_habil(1),-1)
                       and not exists (select 1 from gv_pago_sueldo b
                                        where b.cliente = c.cod_persona
                                          and b.nro_cuenta = a.nro_cta_debito
                                          and b.fec_proceso >= add_months(pag_cal.fu_obt_fec_pri_dia_mes_habil(1),-1)));

