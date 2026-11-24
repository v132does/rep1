CREATE OR REPLACE PROCEDURE IT.prg_not_act_tar_debito IS

  --Cursor de la tabla temporal del proceso de importacion 
  CURSOR not_act_tar_debito IS
    SELECT a.cod_persona,a.nro_documento,a.nro_cuenta,a.nro_tarjeta
    FROM BW_NOT_ACT_TAR_DEB_TMP a ;
  v_encolado     VARCHAR(1);
  v_ret          NUMBER := 0;
  v_cod_destino  bw_not_destinos.cod_destino%type := 1;
  v_celular      varchar2(100);
  v_error        varchar2(100);
  v_cod_persona  varchar2(20);
  v_horario      varchar2(100);
  v_existe       varchar2(10);
  v_nom_destino bw_not_destinos.nombre%TYPE;
  v_tip_evento BW_NOT_TIP_EVENTOS.Cod_Tip_Evento%type:= 'TACTTARDEB';
                                                        
  v_cod_des_suscripcion bw_not_destinos.cod_destino%type :=0;
  v_ins_notificacion number(3);
  v_template       bw_not_tip_eventos.template%TYPE;
  v_mensaje        bw_not_mensajes.mensaje%TYPE;
  p_fecha       ge_calendarios.fec_actual%TYPE;
        
  ----
  FUNCTION lf_ver_not_suscripto(p_cod_persona IN ba_personas.cod_persona%TYPE)
  RETURN VARCHAR2 IS
  v_nom_destino bw_not_destinos.nombre%TYPE;
  BEGIN
    BEGIN
      SELECT d.nombre,d.cod_destino
        INTO v_nom_destino,v_cod_des_suscripcion
        FROM bw_not_cli_destino c, bw_not_destinos d
       WHERE c.cod_persona = p_cod_persona
         AND c.activo = 'S'
         AND d.cod_destino = c.cod_destino
         and d.cod_destino is not null;--SI ES SMS MAIL O PUSH
    EXCEPTION
      WHEN OTHERS THEN
        RETURN NULL;
    END;
    RETURN v_nom_destino;
  END;
  ----
BEGIN
  FOR destino IN not_act_tar_debito LOOP
    v_encolado := 'N';
    v_error:= null;
    --Sino tiene celular Buscamos en ba_telefonos
    v_celular:= null;
    v_cod_persona:= null;
    --p_nro_tarjeta:= destino.Nro_Tarjeta ;
    v_horario:= null;
    v_existe:= null;
  --Verificamos que exista la persona
    begin
      select a.cod_persona
        into v_cod_persona
         from ba_personas a
           where a.cod_persona = destino.cod_persona
            and rownum         =1;
    exception
      when no_data_found then
        v_cod_persona:=null;
      when others then
       v_cod_persona:=null;
    end;
    if v_cod_persona is not null then
       --Verificamos si ya existe en bw_not_suscripciones
       begin
         select 'S'
           into v_existe
           from bw_not_suscripciones a
          where a.cod_persona = v_cod_persona
            and a.nro_cuenta  = nvl(destino.nro_cuenta,a.nro_cuenta)
            and a.cod_evento  = 86  -- notificación por activación de TC
            and rownum        = 1;
       exception
         when no_data_found then
           v_existe:= 'N';
         when others then 
          v_existe:= 'S';
       end;
       IF NVL(v_existe,'S')= 'N' then
           BEGIN
             INSERT INTO bw_not_suscripciones
                (cod_persona, nro_cuenta, cod_evento, horario, mto_minimo, activo, frecuencia)
             VALUES
                (v_cod_persona, destino.nro_cuenta, 86, null, null, 'S', NULL);
           EXCEPTION
             WHEN OTHERS THEN
                null;
           END;
       END IF;
       
      --***********************************************************
      v_nom_destino:=  lf_ver_not_suscripto(destino.cod_persona);
      if  v_nom_destino is null then /* si no está suscripto */
       --Buscamos el celular del cliente, que no tenga observacion
       begin
           select a.area||a.telefono
             into v_celular
             from ba_telefonos a
               where a.cod_persona = destino.cod_persona
               and a.tip_linea     = 'C'
               and a.observacion is null
               and rownum          = 1;
        exception
          when no_data_found then
             v_error:='No se tiene registrado el Nro. de Celular del Cliente';
             v_celular:=  null;
          when others then
             v_error:='Error al consultar teléfono de la persona.';
             v_celular:=  null;
        end;
      
        --Doy de alta al cliente en el servicio de notificaciones SMS
        IF v_celular IS NOT NULL THEN
         
          v_ret :=fuw_alt_cli_not_deb(destino.cod_persona,
                                  v_cod_destino,
                                  v_celular,
                                  'ITGF',
                                   null,
                                   destino.nro_cuenta,
                                   destino.nro_tarjeta);
          if v_ret in (1,2) then
              update BW_NOT_ACT_TAR_DEB_TMP b
                 set b.error='Error al dar de alta en notificaciones.'
               where b.cod_persona = v_cod_persona
                 and b.nro_cuenta  = destino.nro_cuenta
                 and b.nro_tarjeta = destino.nro_tarjeta;             
          else 
               update BW_NOT_ACT_TAR_DEB_TMP b
                  set b.error='Notificación realizada correctamente'
                where b.cod_persona = v_cod_persona
                  and b.nro_cuenta  = destino.nro_cuenta
                  and b.nro_tarjeta = destino.nro_tarjeta;
           
          end if;
        else 
          update BW_NOT_ACT_TAR_DEB_TMP b
             set b.error= v_error
           where b.cod_persona = v_cod_persona
             and b.nro_cuenta  = destino.nro_cuenta
             and b.nro_tarjeta = destino.nro_tarjeta;  
        END IF;
               
      else
          --SI YA ESTA SUSCRIPTO

          IF paw_not.fu_obt_not_template(v_tip_evento, v_template, '00') <> 0 THEN
           raise_application_error(-20000,'No se ha definido template para el evento '||v_tip_evento);
        end if;
 
        
          
          v_mensaje := utl_lms.format_message(v_template, paw_not.lf_obt_ult_tarjeta(destino.nro_tarjeta), to_char(p_fecha, 'dd/mm/yyyy'));

          -- se inserta la notificación
          v_ins_notificacion:=paw_not.fu_ins_mensaje(86,
                                                     'ITGF',
                                                     v_mensaje,
                                                     destino.cod_persona,
                                                     DESTINO.NRO_CUENTA,
                                                     NULL,
                                                     'S');
           
           if v_ins_notificacion <> 0 then 
               -- se marca el registro con error.
              update BW_NOT_ACT_TAR_DEB_TMP b
                 set b.error='Error al insertar en bw_not_mensajes'
               where b.cod_persona = v_cod_persona
                 and b.nro_cuenta  = destino.nro_cuenta
                 and b.nro_tarjeta = destino.nro_tarjeta;
           
           else
               -- se insertó correctamente la notificación
              update BW_NOT_ACT_TAR_DEB_TMP b
                 set b.error='Notificación realizada correctamente'
               where b.cod_persona = v_cod_persona
                 and b.nro_cuenta  = destino.nro_cuenta
                 and b.nro_tarjeta = destino.nro_tarjeta;
           end if;
      end if;
     else 
        update BW_NOT_ACT_TAR_DEB_TMP b
           set b.error='Persona no registrada en el sistema. Verifique.'
         where b.cod_persona = v_cod_persona
           and b.nro_cuenta  = destino.nro_cuenta
           and b.nro_tarjeta = destino.nro_tarjeta;  
     end if;
  END LOOP;
END;
/

