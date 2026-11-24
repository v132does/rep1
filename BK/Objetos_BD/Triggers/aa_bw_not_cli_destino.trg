CREATE OR REPLACE TRIGGER IT.AA_BW_NOT_CLI_DESTINO
  AFTER DELETE OR UPDATE
     ON BW_NOT_CLI_DESTINO
    FOR EACH ROW
DECLARE
  v_mail       NUMBER(4);
  v_sms        NUMBER(4);
  v_ins_evento NUMBER(4);
  v_direccion  VARCHAR2(100);
  v_persona    VARCHAR2(10);
  r_uaudi BW_NOT_CLI_DESTINO_HIS%ROWTYPE;
  v_reg_oferta VARCHAR2(1) := 'N';
BEGIN
  -- Registrar Detalle
  r_uaudi.cod_persona_old := :old.cod_persona;
  r_uaudi.cod_persona_new := :new.cod_persona;
  r_uaudi.cod_destino_old := :old.cod_destino;
  r_uaudi.cod_destino_new := :new.cod_destino;
  r_uaudi.direccion_old   := :old.direccion;
  r_uaudi.direccion_new   := :new.direccion;
  r_uaudi.activo_old      := :old.activo;
  r_uaudi.activo_new      := :new.activo;
  
  IF :new.activo = 'N' AND :new.cod_origen IN ('ANDR', 'IOSX', 'HUA') THEN
     -- registro para ofertas mobile, no notificar
     v_reg_oferta := 'S';  
  END IF;
 
  IF updating THEN
  --Se envía notificacion de cambio al mail que acaba de ser modificado.
   IF :old.direccion <> :new.direccion  and :old.cod_destino IN (1, 2) and :old.activo = 'S' THEN
      v_direccion := :old.direccion;
      IF v_reg_oferta = 'N' THEN
         IF :old.cod_destino = 2 THEN
            v_mail:= paw_not.fu_env_email_prueba(v_direccion,fug_obt_pardinamico('NOM_BANCO')||' le informa: en la fecha se ha procedido conforme a su pedido de cambio de parametros del servicio de notificaciones.', 'NOTCAMBIO');
         ELSE
            v_sms:= paw_not.fu_env_sms_prueba(v_direccion,fug_obt_pardinamico('NOM_BANCO')||' le informa: en la fecha se ha procedido conforme a su pedido de cambio de parametros del servicio de notificaciones.', 'NOTCAMBIO');
         END IF;
      END IF;
   END IF;
   IF :new.activo = 'S' THEN
     v_persona  := :old.cod_persona;
     v_ins_evento:= paw_not.fu_not_env_evento(v_persona, 'NOTCAMBIO', 'NOTCAMBIO');
   END IF;
    r_uaudi.novedad := 'M';
  ELSIF deleting THEN
    IF :old.direccion <> :new.direccion  and :old.cod_destino = 2 and :old.activo ='S' THEN
      v_direccion:= :old.direccion;
      v_mail:= paw_not.fu_env_email_prueba(v_direccion,fug_obt_pardinamico('NOM_BANCO')||' le informa: en la fecha se ha procedido conforme a su pedido de cambio de parametros del servicio de notificaciones.', 'NOTCAMBIO');
   END IF;  
   --Se envía notificiacion de cambio al sms que acaba de ser modificado.
   IF :old.direccion <> :new.direccion  and :old.cod_destino = 1 and :old.activo ='S' THEN
      v_direccion := :old.direccion;
      v_sms:= paw_not.fu_env_sms_prueba(v_direccion,fug_obt_pardinamico('NOM_BANCO')||' le informa: en la fecha se ha procedido conforme a su pedido de cambio de parametros del servicio de notificaciones.', 'NOTCAMBIO');
 
   END IF;
   
   IF :new.activo = 'S' THEN
     v_persona  := :old.cod_persona;
     v_ins_evento:= paw_not.fu_not_env_evento(v_persona, 'NOTCAMBIO', 'NOTCAMBIO');
   END IF;
  
  
  
    r_uaudi.novedad := 'E';
  END IF;

  -- Insertar tabla de auditoria   
  BEGIN
     insert into bw_not_cli_destino_his
        (cod_persona_old, cod_persona_new, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, cod_destino_old, cod_destino_new, direccion_old, direccion_new, activo_old, activo_new, novedad)
     values
        (r_uaudi.cod_persona_old, r_uaudi.cod_persona_new, USER, SYSDATE, USER, SYSDATE, r_uaudi.cod_destino_old, r_uaudi.cod_destino_new, r_uaudi.direccion_old, r_uaudi.direccion_new, r_uaudi.activo_old, r_uaudi.activo_new, r_uaudi.novedad);
  END;

EXCEPTION
  when others then
   null;
END;
/

