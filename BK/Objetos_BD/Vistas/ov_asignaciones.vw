create or replace force view it.ov_asignaciones as
select distinct asig.nro_cuenta
  from (select distinct a.cod_persona, a.nro_cuenta
            from ge_cta_clientes a,
                 ta_tarjetas b,
                 ta_cta_tarjetas c
           where a.nro_cuenta = b.nro_cuenta
             and a.relacion = 'P'
             and b.cod_estado != 10 -- 10 = Bajas
             and c.nro_cuenta = a.nro_cuenta
             and c.dia_mora >= 1
             and a.cod_modalidad not in (55,58)
             and c.cod_modalidad != 501 -- BANCARD CHECK no
         union
          select distinct a.cod_persona, a.nro_cuenta
            from ge_cta_clientes a,
                 pr_cta_prestamos b
           where a.nro_cuenta = b.nro_cuenta
             and a.relacion = 'P'
             and b.estado not in ('N','I')
             and b.dia_atraso >= 1
         union
          select distinct a.cod_persona, a.nro_cuenta
            from ge_cta_clientes a,
                 cc_cta_corrientes b,
                 cc_sobregiros_res c
           where a.nro_cuenta = b.nro_cuenta
             and c.nro_cuenta = b.nro_cuenta
             and a.relacion = 'P'
             and b.estado = 'N'
             and c.can_dias > 31
          union
           select distinct a.cod_persona, a.nro_cuenta
             from ge_cta_clientes a,
                  ov_cta_vencidas b
            where b.nro_cuenta = a.nro_cuenta
              and a.relacion = 'P'
              and a.cod_modulo = 15
              and a.cod_modalidad in (151,152)
              and b.estado in ('G','M','V')
       ) asig
;

