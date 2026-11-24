create or replace force view it.tv_cobros_gp as
select "NRO_CUENTA","NRO_TARJETA","NRO_CTA_DEBITO","FEC_PROCESO","MONTO","ESTADO",
       "FEC_VALOR","OBSERVACION","USU_INSERCION","FEC_INSERCION","USU_MODIFICACION",
       "FEC_MODIFICACION","EST_ENVIO","HORA","COD_USUARIO","DIA_MORA","TIP_ENVIO",
       "TIPO","RED_PAGO","CANAL"
  from ta_cobros_gp cob
 where cob.est_envio = 'P'
   and cob.estado in ('C','P')
   and exists (select 1
                 from ta_tipos tip, ta_cta_tarjetas cta, ta_tarjetas tar
                where cta.nro_cuenta = cob.nro_cuenta
                  and cta.nro_cuenta = tar.nro_cuenta
                  and tar.nro_tarjeta = cob.nro_tarjeta
                  and cta.cod_modalidad = tip.cod_modalidad
                  and cta.afinidad = tip.afinidad
                  and tip.cod_ent_procesadora = fug_obt_pardinamico('COD_ENT_GLOBAL'))
order by cob.fec_insercion;

