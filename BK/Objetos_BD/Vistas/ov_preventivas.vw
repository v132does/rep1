create or replace force view it.ov_preventivas as
select cod_persona, nro_cuenta from (
select distinct a.cod_persona, a.nro_cuenta -- prestamos para preventiva
    from ov_prt_atrasos a,
         ov_car_vigente b,
         ov_cli_lineabaja c
   where a.cod_persona = b.cod_persona
     and c.cod_persona = a.cod_persona
     and a.nro_cuenta = b.nro_cuenta
union
-- tarjetas para preventiva
  select distinct a.cod_persona, a.nro_cuenta
    from ov_tar_atrasos a,
         ov_car_vigente b
   where a.cod_persona = b.cod_persona
     and a.nro_cuenta = b.nro_cuenta
union
-- Ex nóminas para preventiva
  select distinct cliente, nro_cuenta
    from (select distinct gv.cliente, gv.nro_cuenta
            from gv_pago_sueldo gv,
                (select a.cliente, max(a.fec_proceso) ult_fecha
                   from gv_pago_sueldo a
                  where a.fec_proceso >= add_months(pag_cal.fu_obt_fec_pri_dia_mes_habil(5),-6)
               group by a.cliente) ps
           where gv.cliente = ps.cliente
             and gv.fec_proceso = ps.ult_fecha
             and ps.ult_fecha < add_months(pag_cal.fu_obt_fec_pri_dia_mes_habil(5),-2)) x
union
-- Refinanciados y Restructurados para preventiva
  select distinct b.cod_persona, a.nro_cuenta
    from pr_cta_prestamos a, ge_cta_clientes b, ov_cli_lineabaja c, ov_car_vigente d
   where b.nro_cuenta = a.nro_cuenta
     and b.relacion = 'P'
     and a.tip_renovacion in ('R','E')
     and a.estado not in ('N','I')
     and a.dia_atraso = 0
     and c.cod_persona = b.cod_persona
     and d.cod_persona = c.cod_persona
union
-- CLASIFICACION BCP para preventiva
  select distinct a.cod_persona, b.nro_cuenta
    from ge_bcp_clasificacion_his a,
         ov_car_vigente b,
         ov_cli_lineabaja c
   where /*a.fecha*/a.fec_proceso = (select max(b.fec_proceso)/*max(b.fecha)*/
                      from ge_bcp_clasificacion_his b
                     where b.cod_persona = a.cod_persona
                       and /*b.clasif_sis*/ b.cla_sistema != '1')
     and b.cod_persona = a.cod_persona
     and c.cod_persona = b.cod_persona
union
-- FAJA BURO para preventiva
  select distinct a.cod_persona, null nro_cuenta
    from ge_cli_antecedentes a
   where a.faj_buro in ('L','M','N','X')
     and a.fec_ult_informconf = (select max(b.fec_ult_informconf)
                                   from ge_cli_antecedentes b
                                  where b.cod_persona = a.cod_persona)
) m
where not exists (select 1 from ov_cli_resto n
                    where n.cod_persona = m.cod_persona)
  and not exists (select 1 from ov_cli_nom_deb_aut o
                    where o.cod_persona = m.cod_persona)
;

