create or replace force view it.tv_ta_cta_tar_gp as
select null fec_presentacion,z.Nro_Cuenta,
(select a.nro_tarjeta from ta_tarjetas a
where a.vigente like 'S'
and a.nro_cuenta=z.nro_cuenta
and a.fec_activacion = (select max(s.fec_activacion) 
                         from ta_tarjetas s
                         where s.vigente like 'S'
                         and s.nro_cuenta=z.nro_cuenta)) nro_tarjeta,

null descripcion,
null comprobante,

(select a.fec_vencimiento from ta_tarjetas a
where a.vigente like 'S'
and a.nro_cuenta=z.nro_cuenta
and a.fec_activacion = (select max(s.fec_activacion) 
                         from ta_tarjetas s
                         where s.vigente like 'S'
                         and s.nro_cuenta=z.nro_cuenta)) Fecha_vencimiento,

(select floor(months_between(SYSDATE, fec_nacimiento) / 12)
          from ba_per_fisicas s
         where s.cod_persona =
               (select s.cod_persona
                  from ge_cta_clientes s
                 where s.nro_cuenta = z.nro_cuenta
                   and s.relacion = 'P'))edad,


        (select w.abreviatura
         from ba_personas s, ba_tip_documentos w
         where s.cod_persona =
               (select s.cod_persona
                  from ge_cta_clientes s
                 where s.nro_cuenta = z.nro_cuenta
                   and s.relacion = 'P')
           and s.cod_tip_documento = w.cod_tip_documento)Tip_documento,


           (select s.nro_documento
          from ba_personas s
         where s.cod_persona =
               (select s.cod_persona
                  from ge_cta_clientes s
                 where s.nro_cuenta = z.nro_cuenta
                   and s.relacion = 'P'))nro_documento,


                 'N' afectacion,
                 null Importe_movimiento,
                 null Importe_IVA,
                 null Importe_total

from ta_cta_tarjetas z
where z.cod_modalidad in (select distinct p.cod_modalidad from ta_tipos p
                                       where p.cod_ent_procesadora=fug_obt_pardinamico('COD_ENT_GLOBAL'));
/
