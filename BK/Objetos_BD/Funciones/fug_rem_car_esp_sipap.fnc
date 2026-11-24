CREATE OR REPLACE FUNCTION IT.fug_rem_car_esp_sipap(p_cadena VARCHAR2)
 RETURN VARCHAR2 IS
/* Autor:     Vidal Amarilla
   Propuesta: Función reemplazar caracteres especiales de forma dinámica en mensajeria SIPAP.
   Fecha:     16/02/2021*/
 v_existe       number:=0;
 v_remitente    varchar2(150):=fug_obt_pardinamico('CAM_MAR_DIR_MAIL');--'info@bancognbcaminamosjuntos.com.py';
 v_destinatario varchar2(150):=fug_obt_pardinamico('MAIL_CAR_RECH_SIPAP');--notificar al SAU
 v_asunto       varchar2(150):='SIPAP - Caracteres especiales a descartar';
 v_texto        varchar2(4000):=null;
 v_val_minimo   ba_cod_referencias.val_minimo%type;
 v_val_maximo   ba_cod_referencias.val_maximo%type;
 v_cadena       VARCHAR2(4000);
BEGIN
 begin
   select val_minimo, val_maximo
     into v_val_minimo, v_val_maximo
     from ba_cod_referencias
    where dominio    = 'REM_CAR_ESP_SIPAP';
    if length(v_val_minimo) <> length(v_val_maximo) --si son de longitudes diferentes
      or v_val_minimo is null or v_val_maximo is null --si alguno de los valores es nulo
       then
      v_texto :='Favor verificar valores val_minimo y val_maximo del dominio REM_CAR_ESP_SIPAP en la tabla BA_COD_REFERENCIAS, ambos valores deben contener la misma cantidad de caracteres';
     
    end if;
 exception
     when no_data_found then
        v_texto :='Favor verificar, No se encuentra el dominio REM_CAR_ESP_SIPAP en la tabla BA_COD_REFERENCIAS';
     when others then
        v_texto :='Favor verificar el dominio REM_CAR_ESP_SIPAP en la tabla BA_COD_REFERENCIAS, esta referencia es utilizada para depurar los caracteres invalidos de mensajeria SIPAP';
 end;
 if v_texto is not null then
   begin
     Select 1 
     into v_existe 
     From ge_notificaciones g
     where trunc(g.fec_insercion,'HH24') = trunc(sysdate,'HH24')--ENVIA UNA NOTIFICACION POR HORA
     and   g.asunto = v_asunto
     and rownum =1;
     exception
       when no_Data_found then
         v_existe := 0;
     end;
     if v_existe  = 0 then   
       --si no existe la notificacion en la hora Se genera la notificacion
        prg_ins_aut_notificacion(sysdate,
                                   v_remitente,
                                   v_destinatario,
                                   v_asunto,--asunto
                                   v_texto,--mensaje
                                   'FUG_REM_CAR_ESP_SIPAP',--PROCESO
                                   'NOTPROBATCH',--p_tipo
                                   'text/html',--p_formato
                                   2);--p_tip_notificacion
     end if; 
 else
   IF p_cadena IS NOT NULL THEN
    v_cadena := translate(p_cadena,
                          v_val_minimo,
                          v_val_maximo);
    v_cadena := translate(v_cadena, '''', '  ');
   END IF;
 end if;  
 RETURN nvl(v_cadena,p_cadena);
END fug_rem_car_esp_sipap;
/

