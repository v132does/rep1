CREATE OR REPLACE FORCE VIEW IT.TV_OTR_PRO_MORA AS
select t.cod_persona,
       p.nom_completo,
       p.nro_documento,
       t.nro_cuenta,
       t.nro_tarjeta,
       cc.relacion,
       te.descripcion tar_est,
       (SELECT fug_obt_con_columnas('select distinct a.nro_cuenta from ta_cta_tarjetas a, ta_tarjetas b, ge_cta_clientes d where a.nro_cuenta = b.nro_cuenta and a.nro_cuenta = d.nro_cuenta and b.nro_cuenta = d.nro_cuenta and b.cod_persona = d.cod_persona and a.dia_mora > 60 and d.relacion = ''P'' and b.cod_persona =' ||
                         t.cod_persona || '') AS cuentas_tar_morosas
          FROM dual) cta_tar_mor,
       (SELECT fug_obt_con_columnas('select distinct a.mto_mora from ta_cta_tarjetas a, ta_tarjetas b, ge_cta_clientes d where a.nro_cuenta = b.nro_cuenta and a.nro_cuenta = d.nro_cuenta and b.nro_cuenta = d.nro_cuenta and b.cod_persona = d.cod_persona and a.dia_mora > 60 and d.relacion = ''P'' and b.cod_persona =' ||
                         t.cod_persona || '') AS cuentas_tar_mto_mora
          FROM dual) cta_tar_mto_mor,
       (SELECT fug_obt_con_columnas('select distinct a.dia_mora from ta_cta_tarjetas a, ta_tarjetas b, ge_cta_clientes d where a.nro_cuenta = b.nro_cuenta and a.nro_cuenta = d.nro_cuenta and b.nro_cuenta = d.nro_cuenta and b.cod_persona = d.cod_persona and a.dia_mora > 60 and d.relacion = ''P'' and b.cod_persona =' ||
                         t.cod_persona || '') AS cuentas_tar_dia_mora
          FROM dual) cta_tar_dia_mor,

       (SELECT fug_obt_con_columnas('select a.nro_cuenta from pr_cta_prestamos a, ge_cta_clientes b where a.dia_atraso > 60 and a.nro_cuenta = b.nro_cuenta and b.cod_persona =' ||
                         t.cod_persona || '') AS cuentas_pre_morosas
          FROM dual) cta_pre_mor,
       (SELECT fug_obt_con_columnas('select a.mto_mora from pr_cta_prestamos a, ge_cta_clientes b where a.dia_atraso > 60 and a.nro_cuenta = b.nro_cuenta and b.cod_persona =' ||
                         t.cod_persona || '') AS cuentas_pre_mto_mora
          FROM dual) cta_pre_mto_mor,
       (SELECT fug_obt_con_columnas('select a.dia_atraso from pr_cta_prestamos a, ge_cta_clientes b where a.dia_atraso > 60 and a.nro_cuenta = b.nro_cuenta and b.cod_persona =' ||
                         t.cod_persona || '') AS cuentas_pre_dia_mora
          FROM dual) cta_pre_dia_mor,

       d.direccion,
       t.fec_vencimiento
  from ta_tarjetas     t,
       ba_personas     p,
       ge_cta_clientes cc,
       ta_tar_estados  te,
       ba_direcciones  d,
       ta_cta_tarjetas ct

 where t.cod_persona = p.cod_persona
   and t.cod_persona = d.cod_persona
   and p.cod_persona = cc.cod_persona
   and cc.nro_cuenta = t.nro_cuenta
   and t.cod_estado = te.cod_estado
   and t.nro_cuenta = ct.nro_cuenta
   and cc.cod_persona not in ('11198')
   and ct.mto_mora > fug_obt_pardinamico('MTO_MORA')
   and te.cod_estado = 6
   and d.principal = 'S'
   and t.vigente = 'S'
   and nvl(ct.dia_mora,0)  < 61
   and cc.relacion = 'P'
   and (exists (select 1
                  from ta_cta_tarjetas a, ta_tarjetas b, ge_cta_clientes d
                 where a.nro_cuenta = b.nro_cuenta
                   and a.nro_cuenta = d.nro_cuenta
                   and b.nro_cuenta = d.nro_cuenta
                   and b.cod_persona = d.cod_persona
                   and a.nro_cuenta <> t.nro_cuenta
                   and b.cod_persona = p.cod_persona
                   and d.relacion = 'P'
                   and nvl(a.dia_mora,0) > 60) or exists
        (select 1
           from pr_cta_prestamos c, ge_cta_clientes d
          where c.nro_cuenta = d.nro_cuenta
            and d.cod_persona = p.cod_persona
            and nvl(c.dia_atraso,0) > 60
            and d.relacion = 'P'))
union
select distinct t1.cod_persona,
                p1.nom_completo,
                p1.nro_documento,
                t1.nro_cuenta,
                t1.nro_tarjeta,
                cc1.relacion,
                te1.descripcion  tar_est,
                null             cta_tar_mor,
                null,
                null,
                null             cta_pre_mor,
                null,
                null,
                d1.direccion,
                t1.fec_vencimiento
  from ta_cta_tarjetas ct1,
       ge_cta_clientes cc1,
       ta_tarjetas     t1,
       ba_personas     p1,
       ta_tar_estados  te1,
       ba_direcciones  d1
 where ct1.nro_cuenta = cc1.nro_cuenta
   and t1.cod_persona = p1.cod_persona
   and p1.cod_persona = cc1.cod_persona
   and cc1.nro_cuenta = t1.nro_cuenta
   and t1.cod_estado = te1.cod_estado
   and t1.cod_persona = d1.cod_persona
   and cc1.cod_persona not in ('11198')
   and ct1.mto_mora > fug_obt_pardinamico('MTO_MORA')
   and t1.vigente = 'S'
   and cc1.relacion = 'A'
   and t1.cod_estado = 6
   and d1.principal = 'S'
   and ct1.nro_cuenta =
       (select ct.nro_cuenta
          from ta_tarjetas     t,
               ba_personas     p,
               ge_cta_clientes cc,
               ta_tar_estados  te,
               ba_direcciones  d,
               ta_cta_tarjetas ct
         where t.cod_persona = p.cod_persona
           and p.cod_persona = cc.cod_persona
           and cc.nro_cuenta = t.nro_cuenta
           and t.cod_estado = te.cod_estado
           and t.cod_persona = d.cod_persona
           and d.principal = 'S'
           and t.cod_estado = 6
           and t.vigente = 'S'
           and t.nro_cuenta = ct.nro_cuenta
           and nvl(ct.dia_mora,0) < 61
           and cc.relacion = 'P'
           and ct1.nro_cuenta = ct.nro_cuenta
           and (exists
                (select 1
                   from ta_cta_tarjetas a, ta_tarjetas b, ge_cta_clientes d
                  where a.nro_cuenta = b.nro_cuenta
                    and a.nro_cuenta = d.nro_cuenta
                    and b.nro_cuenta = d.nro_cuenta
                    and b.cod_persona = d.cod_persona
                    and a.nro_cuenta <> t.nro_cuenta
                    and b.cod_persona = p.cod_persona
                    and d.relacion = 'P'
                    and nvl(a.dia_mora,0) > 60) or exists
                (select 1
                   from pr_cta_prestamos c, ge_cta_clientes d
                  where c.nro_cuenta = d.nro_cuenta
                    and d.cod_persona = p.cod_persona
                    and nvl(c.dia_atraso,0) > 60
                    and d.relacion = 'P'))
         group by T.COD_PERSONA,ct.nro_cuenta);

