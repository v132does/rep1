create or replace force view it.gv_not_ips as
select a.cod_mensaje,
       a.cod_persona,
       fue_obt_nom_persona(a.cod_persona) Nombre_Completo,
       fug_obt_gestor(a.cod_persona) Oficial,
       a.lote,
       a.nro_celular nro_celular,
       a.mensaje,
       a.encolado,
       c.significado as error,
       a.fecha Fecha,
       to_char(a.fec_insercion, 'hh24:mm:ss') Hora,
       a.usu_insercion Usuario
  from BW_NOT_SMS_MASIVO a, bw_not_mensajes b, ba_cod_referencias c
 WHERE trunc(a.fecha) = trunc(b.fec_envio)
   and b.cod_evento = 69
   and b.cod_persona = a.cod_persona
   and b.cod_ult_error is not null
   and upper(b.cod_ult_error) = upper(c.val_minimo)
   and upper(c.dominio) = 'DES_RES_EDGE'
union all
select a.cod_mensaje,
       a.cod_persona,
       fue_obt_nom_persona(cod_persona) Nombre_Completo,
       fug_obt_gestor(a.cod_persona) Oficial,
       a.lote,
       a.nro_celular nro_celular,
       a.mensaje,
       a.encolado,
       nvl(a.error, 'Operacion Completada') error,
       a.fecha Fecha,
       to_char(a.fec_insercion, 'hh24:mm:ss') Hora,
       a.usu_insercion Usuario
  from BW_NOT_SMS_MASIVO a
 WHERE exists
       (select 1
          from bw_not_mensajes b
         WHERE trunc(a.fecha) = trunc(b.fec_envio)
           and b.cod_evento = 69
           and b.cod_persona = a.cod_persona
           and b.cod_ult_error is null
           and b.fec_envio is not null)
union all
select a.cod_mensaje,
       a.cod_persona,
       fue_obt_nom_persona(cod_persona) Nombre_Completo,
       fug_obt_gestor(a.cod_persona) Oficial,
       a.lote,
       a.nro_celular nro_celular,
       a.mensaje,
       a.encolado,
       nvl(a.error, 'Operacion no Finalizada') error,
       a.fecha Fecha,
       to_char(a.fec_insercion, 'hh24:mm:ss') Hora,
       a.usu_insercion Usuario
  from BW_NOT_SMS_MASIVO a
  where trunc(a.fecha) = trunc(pag_cal.FU_OBT_FEC_ACTUAL(1))
  and not exists
       (select 1
          from bw_not_mensajes b
         WHERE trunc(a.fecha) = trunc(b.fec_envio)
           and b.cod_evento = 69
           and b.cod_persona = a.cod_persona)
union all
select a.cod_mensaje,
       a.cod_persona,
       fue_obt_nom_persona(cod_persona) Nombre_Completo,
       fug_obt_gestor(a.cod_persona) Oficial,
       a.lote,
       a.nro_celular nro_celular,
       a.mensaje,
       a.encolado,
       nvl(a.error, 'En espera para envio') error,
       a.fecha Fecha,
       to_char(a.fec_insercion, 'hh24:mm:ss') Hora,
       a.usu_insercion Usuario
  from BW_NOT_SMS_MASIVO a
 WHERE exists
       (select a.cod_persona
          from bw_not_mensajes b
         WHERE trunc(a.fecha) = trunc(b.fec_envio)
           and b.cod_evento = 69
           and b.cod_persona = a.cod_persona
           and b.cod_ult_error is null
           and b.fec_envio is null)
/*Historicos*/
union all
select a.cod_mensaje,
       a.cod_persona,
       fue_obt_nom_persona(a.cod_persona) Nombre_Completo,
       fug_obt_gestor(a.cod_persona) Oficial,
       a.lote,
       a.nro_celular nro_celular,
       a.mensaje,
       a.encolado,
       c.significado as error,
       a.fecha Fecha,
       to_char(a.fec_insercion, 'hh24:mm:ss') Hora,
       a.usu_insercion Usuario
  from BW_NOT_SMS_MASIVO a, bw_not_mensajes_his b, ba_cod_referencias c
 WHERE trunc(a.fecha) = trunc(b.fec_envio)
   and b.cod_evento = 69
   and b.cod_persona = a.cod_persona
   and b.cod_ult_error is not null
   and upper(b.cod_ult_error) = upper(c.val_minimo)
   and upper(c.dominio) = 'DES_RES_EDGE'
union all
select a.cod_mensaje,
       a.cod_persona,
       fue_obt_nom_persona(cod_persona) Nombre_Completo,
       fug_obt_gestor(a.cod_persona) Oficial,
       a.lote,
       a.nro_celular nro_celular,
       a.mensaje,
       a.encolado,
       nvl(a.error, 'Operacion Completada') error,
       a.fecha Fecha,
       to_char(a.fec_insercion, 'hh24:mm:ss') Hora,
       a.usu_insercion Usuario
  from BW_NOT_SMS_MASIVO a
 WHERE exists
       (select 1
          from bw_not_mensajes_his b
         WHERE trunc(a.fecha) = trunc(b.fec_envio)
           and b.cod_evento = 69
           and b.cod_persona = a.cod_persona
           and b.cod_ult_error is null
           and b.fec_envio is not null)
union all
select a.cod_mensaje,
       a.cod_persona,
       fue_obt_nom_persona(cod_persona) Nombre_Completo,
       fug_obt_gestor(a.cod_persona) Oficial,
       a.lote,
       a.nro_celular nro_celular,
       a.mensaje,
       a.encolado,
       nvl(a.error, 'Operacion no Finalizada') error,
       a.fecha Fecha,
       to_char(a.fec_insercion, 'hh24:mm:ss') Hora,
       a.usu_insercion Usuario
  from BW_NOT_SMS_MASIVO a
 WHERE trunc(a.fecha) <>  trunc(pag_cal.FU_OBT_FEC_ACTUAL(1))
  and not exists
       (select 1
          from bw_not_mensajes_his b
         WHERE trunc(a.fecha) = trunc(b.fec_envio)
           and b.cod_evento = 69
           and b.cod_persona = a.cod_persona
           and b.cod_ult_error is null
           and b.fec_envio is not null)
union all
select a.cod_mensaje,
       a.cod_persona,
       fue_obt_nom_persona(cod_persona) Nombre_Completo,
       fug_obt_gestor(a.cod_persona) Oficial,
       a.lote,
       a.nro_celular nro_celular,
       a.mensaje,
       a.encolado,
       nvl(a.error, 'En espera para envio') error,
       a.fecha Fecha,
       to_char(a.fec_insercion, 'hh24:mm:ss') Hora,
       a.usu_insercion Usuario
  from BW_NOT_SMS_MASIVO a
 WHERE exists
       (select 1
          from bw_not_mensajes_his b
         WHERE trunc(a.fecha) = trunc(b.fec_envio)
           and b.cod_evento = 69
           and b.cod_persona = a.cod_persona
           and b.cod_ult_error is null
           and b.fec_envio is null)
 order by 1 desc;

