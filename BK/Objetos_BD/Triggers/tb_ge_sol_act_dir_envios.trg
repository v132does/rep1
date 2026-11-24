CREATE OR REPLACE TRIGGER IT.TB_GE_SOL_ACT_DIR_ENVIOS
 BEFORE DELETE OR INSERT OR UPDATE
     ON GE_SOL_ACT_DIR_ENVIOS
    FOR EACH ROW
declare      
v_mod boolean := false; -- para identificar si el reg fue modificado realmente
begin
  IF inserting and nvl(:new.tip_modificacion,'I') <> 'N' THEN  -- si no es insercion inicial (carga datos)
     :new.tip_modificacion := 'I';
      :new.DET_MODIFICACION :='*Fecha :' || sysdate ||' - Usuario: '||upper(USER) ||chr(10) ||
                              '*Se agrega nueva dirección de envío: [Tipo Envio] '||:new.tip_envio||'[Referencia] '||:new.referencia||' [Nro.Cuenta] '||:new.NRO_CUENTA;
  END IF;


  IF updating THEN
    :new.DET_MODIFICACION := null;
    if :old.tip_modificacion = 'I' then
         :new.tip_modificacion := 'I';-- mantiene como insert ya que es un registro nuevo que se debe insertar
         :new.DET_MODIFICACION :='*Fecha :' || trunc(sysdate) ||' - Usuario: '||upper(USER) ||chr(10) ||
	                                '*Modif. de nueva Dir.Envío:[Tip.Envio] '||:new.tip_envio ||' [N° Cuenta] '||:new.nro_cuenta|| ' [Referencia] '||:new.referencia;
    end if;

    if :new.tip_modificacion = 'M' then
        -- tipo envio: Direccion, Retener
        IF (:OLD.TIP_ENVIO <> :NEW.TIP_ENVIO) or (:OLD.TIP_ENVIO is null and :NEW.TIP_ENVIO is not null) or
           (:OLD.TIP_ENVIO is not null and :NEW.TIP_ENVIO is null) THEN
          v_mod:= TRUE;
          IF :new.DET_MODIFICACION IS NULL THEN
             :new.DET_MODIFICACION := '*Tipo Envio=> [Actual] '||:old.tip_envio||' [Nuevo] '||:new.tip_envio;
          else
             :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Tipo Envio=> [Actual] '||:old.tip_envio||' [Nuevo] '||:new.tip_envio;
          end if;
        end if;
        -- REFERENCIA
        IF (:OLD.REFERENCIA <> :NEW.REFERENCIA) or (:OLD.REFERENCIA is null and :NEW.REFERENCIA is not null) or
           (:OLD.REFERENCIA is not null and :NEW.REFERENCIA is null) THEN
          v_mod:= TRUE;
          IF :new.DET_MODIFICACION IS NULL THEN
             :new.DET_MODIFICACION := '*Referencia=> [Actual] '||:old.referencia||' [Nuevo] '||:new.referencia;
          else
             :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Referencia=> [Actual] '||:old.referencia||' [Nuevo] '||:new.referencia;
          end if;
        end if;

        -- Numero de cuenta
        IF (:OLD.NRO_CUENTA <> :NEW.NRO_CUENTA) or (:OLD.NRO_CUENTA is null and :NEW.NRO_CUENTA is not null) or
           (:OLD.NRO_CUENTA is not null and :NEW.NRO_CUENTA is null) THEN
          v_mod:= TRUE;
          IF :new.DET_MODIFICACION IS NULL THEN
             :new.DET_MODIFICACION := '*N° Cuenta=> [Actual] '||:old.nro_cuenta||' [Nuevo] '||:new.nro_cuenta;
          else
             :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*N° Cuenta=> [Actual] '||:old.nro_cuenta||' [Nuevo] '||:new.nro_cuenta;
          end if;
        end if;

        -- OBSERVACION
        IF (:OLD.OBSERVACION <> :NEW.OBSERVACION) or (:OLD.OBSERVACION is null and :NEW.OBSERVACION is not null) or
           (:OLD.OBSERVACION is not null and :NEW.OBSERVACION is null) THEN
          v_mod:= TRUE;
          IF :new.DET_MODIFICACION IS NULL THEN
             :new.DET_MODIFICACION := '*Observacion=> [Actual] '||:old.observacion||' [Nuevo] '||:new.observacion;
          else
             :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Observacion=> [Actual] '||:old.observacion||' [Nuevo] '||:new.observacion;
          end if;
        end if;
        
        -- para los casos que el usuario ingreso un cambio y luego dejo como estaba el registro
        -- a nivel de form ya toma como una modificacion, controlamos de vuelta en el trigger para no registrar una 
        -- modificacion que no fue hecha
        IF (v_mod or :old.tip_modificacion ='M')  then
          if :new.DET_MODIFICACION is not null then
            --- concateno el old para no perder el historico de cambios del registro para la misma solicitud
            :new.DET_MODIFICACION :=  '*Fecha :' || sysdate ||' - Usuario: '||upper(USER) ||chr(10) ||
                                      :new.DET_MODIFICACION ||chr(10) ||
                                      '---------------------------------------------'||chr(10) ||
                                       :old.det_modificacion;
          else -- si esta marcado como Modificacion pero no hubo cambios, setea el OLD para no perder el historico
             :new.DET_MODIFICACION := :old.det_modificacion;                               
          end if;                             
        else
            :new.tip_modificacion :='N';
        end if;                             
      end if;
      --
      if :new.tip_modificacion = 'E' then
       :new.DET_MODIFICACION :='*Fecha :' || trunc(sysdate) ||' - Usuario: '||upper(USER) ||chr(10) ||
	                                '*Eliminación de Dir.Envío:[Tip.Envio] '||:new.tip_envio ||' [N° Cuenta] '||:new.nro_cuenta||
                                  ' [Referencia] '||:new.referencia||chr(10) ||
                                  '---------------------------------------------'||chr(10) ||
                                  :old.DET_MODIFICACION ;
      end if;
  END IF; -- end if updating
END;
/

