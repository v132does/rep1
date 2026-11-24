create or replace procedure it.prg_ins_notificacion( p_fecha in date,
                                                  p_remitente in varchar2,
                                                  p_destinatario in varchar2,
                                                  p_asunto in varchar2,
                                                  p_mensaje in varchar2,
                                                  p_proceso in varchar2 default null,
                                                  p_tipo in varchar2 default 'NOTPROBATCH',
                                                  p_formato varchar2 default 'text/html',
                                                  p_tip_notificacion number default 2 -- 2-email
) is
  /*
  DYDMR-11036 - SOPORTE-BS 10/2019 NAF
  Permite Insertar Notificaciones en tabla GE_NOTIFICACIONES para ser enviadas por servicio scheduler-0.0.2.jar
  Actualmente solo es para envio de emails
  */
  v_nro_notificacion number;
  v_error            varchar2(400);
  v_lugar            varchar2(60);
  v_fec_insercion    ge_notificaciones.fec_insercion%type;
  
  -- cursor destinos
  -- divide destinos separado por comas y los inserta en registros separados
  cursor c_destinos(v_destinos varchar2) 
  is
  select regexp_substr(v_destinos,'[^,]+', 1, level) destino 
  from dual
  connect by regexp_substr(v_destinos, '[^,]+', 1, level) is not null;
  
  -- Manejo de fec insercion
  function fu_obt_fec_insercion return date is
  v_max_hora             varchar2(5);
  v_fec_maxima           ge_notificaciones.fec_insercion%type;
  v_fec_actual           ge_notificaciones.fec_insercion%type; 
  v_fec_calculada        ge_notificaciones.fec_insercion%type;
  v_horas                number;
  v_minutos              number;
  begin
      v_lugar              := 'Obtener Fecha Insercion';
      v_max_hora           := fug_obt_pardinamico('NOT_PRO_MAX_HORA');
      v_fec_actual         := sysdate;
      v_fec_calculada      := null;
      IF v_max_hora IS NOT NULL THEN
         v_max_hora    := REGEXP_SUBSTR(v_max_hora,'^(0[1-9]|1\d|2[0-3]):([0-5]\d)$',1,1);
         v_fec_maxima  := to_date(to_char(v_fec_actual,'dd/mm/yyyy') || ' ' || nvl(v_max_hora,'18:00'),'dd/mm/yyyy HH24:mi');
         IF v_fec_actual > v_fec_maxima THEN
             -- se cambia a fecha siguiente
             v_minutos := trunc((v_fec_actual-v_fec_maxima)*24*60);
             IF v_minutos > 60 THEN
                v_horas   := trunc(v_minutos/60);
                v_minutos := to_char(v_fec_actual,'mi');
             ELSE
                v_horas   := 0;
             END IF;
             v_fec_calculada := to_date( to_char(v_fec_actual+1, 'dd/mm/yyyy') || ' ' || 
                                         lpad(to_char(v_horas),2,'0') || ':' ||
                                         lpad(to_char(v_minutos),2,'0'), 
                                         'dd/mm/yyyy HH24:mi');
         ELSE
             v_fec_calculada := v_fec_actual;
         END IF;
      ELSE
         v_fec_calculada := v_fec_actual;
      END IF;
      RETURN v_fec_calculada;
  end;

begin
  v_fec_insercion := fu_obt_fec_insercion;
  v_lugar         := 'Insert Ge_Notificaciones';
  for d in c_destinos(replace(p_destinatario, ';', ',')) loop 
    v_nro_notificacion := s_nro_notificacion.nextval;  
    insert into ge_notificaciones
      (NRO_NOTIFICACION,
       FECHA,
       ENV_POR,
       ENV_PARA,
       ASUNTO,
       DETALLE,
       COD_USUARIO,
       TIPO,
       FORMATO,
       TIP_NOTIFICACION,
       FEC_INSERCION)
    values
      (v_nro_notificacion,
       nvl(p_fecha, trunc(sysdate)),
       nvl(p_remitente, fug_obt_dir_correo),
       d.destino,
       p_asunto,
       p_mensaje,
       user,
       nvl(p_tipo, 'NOTPROBATCH'),
       nvl(p_formato, 'text/html'),
       nvl(p_tip_notificacion, 2),--actualmente solo 2-email
       nvl(v_fec_insercion,sysdate));
  end loop;
exception
   when others then
      v_error := substr(trim(p_proceso || ' ' || SQLERRM),1,400);
      PRG_ACT_LOG_PROCESOS('PRG_INS_NOTIFICACION',v_lugar,trunc(sysdate),to_char(sysdate,'HH24:mi:ss'),to_char(sysdate,'HH24:mi:ss'),v_error);
end;
/

