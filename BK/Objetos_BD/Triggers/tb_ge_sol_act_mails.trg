CREATE OR REPLACE TRIGGER IT.TB_GE_SOL_ACT_MAILS
 BEFORE DELETE OR INSERT OR UPDATE
     ON GE_SOL_ACT_MAILS
    FOR EACH ROW
declare      
v_mod boolean := false; -- para identificar si el reg fue modificado realmente
begin
  IF inserting and nvl(:new.tip_modificacion,'I') <> 'N' THEN  -- si no es insercion inicial (carga datos)
     :new.tip_modificacion := 'I';
     :new.DET_MODIFICACION :='*Fecha :' || trunc(sysdate) ||' - Usuario: '||upper(USER) ||chr(10) ||
	                                '*Se agrega nuevo email : '||:new.dir_correo ||' [Principal] '||:new.principal||
                                  ' [Tipo] '||:new.tipo||chr(10) ||
                                  '-----------------------------------------';
  END IF;

  IF updating THEN
    :new.DET_MODIFICACION := null;
    if :old.tip_modificacion = 'I' then
        :new.tip_modificacion := 'I';-- mantiene como insert ya que es un registro nuevo que se debe insertar
        :new.DET_MODIFICACION :='*Fecha :' || trunc(sysdate) ||' - Usuario: '||upper(USER) ||chr(10) ||
	                                '*Se modif. nuevo email : '||:new.dir_correo ||' [Principal] '||:new.principal||
                                  ' [Tipo] '||:new.tipo||chr(10) ||
                                  '-----------------------------------------'||chr(10) ||
                                   :old.det_modificacion;
    end if;

    if :new.tip_modificacion = 'M' then
      -- tipo CORREO L=Laboral P=Particular
      IF (:OLD.TIPO <> :NEW.TIPO) or (:OLD.TIPO is null and :NEW.TIPO is not null) or 
         (:OLD.TIPO is not null and :NEW.TIPO is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Tipo Correo=> [Actual] '||:old.tipo||' [Nuevo] '||:new.tipo;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Tipo Correo=> [Actual] '||:old.tipo||' [Nuevo] '||:new.tipo;
        end if;
      end if;
      -- PRINCIPAL
      IF (:OLD.PRINCIPAL <> :NEW.PRINCIPAL) or (:OLD.PRINCIPAL is null and :NEW.PRINCIPAL is not null) or 
         (:OLD.PRINCIPAL is not null and :NEW.PRINCIPAL is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Principal=> [Actual] '||:old.principal||' [Nuevo] '||:new.principal;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Correo Principal=> [Actual] '||:old.principal||' [Nuevo] '||:new.principal;
        end if;
      end if;

      -- DIRECCION CORREO
      IF (:OLD.DIR_CORREO <> :NEW.DIR_CORREO) or (:OLD.DIR_CORREO is null and :NEW.DIR_CORREO is not null) or 
         (:OLD.DIR_CORREO is not null and :NEW.DIR_CORREO is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Dir.Correo=> [Actual] '||:old.dir_correo||' [Nuevo] '||:new.dir_Correo;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Dir.Correo=> [Actual] '||:old.dir_correo||' [Nuevo] '||:new.dir_correo;
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
         --- concateno el old para no perder el historico de cambios del registro para la misma solicitud
         if :new.DET_MODIFICACION is not null then
             :new.DET_MODIFICACION :=  '*Fecha :' || sysdate ||' - Usuario: '||upper(USER) ||chr(10) ||
                                      :new.DET_MODIFICACION ||chr(10) ||
                                      '-----------------------------------------'||chr(10) ||
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
	                                '*Eliminación de Mail: '||:new.dir_correo ||' [Principal] '||:new.principal||
                                  ' [Tipo] '||:new.tipo||chr(10) ||
                                  '-----------------------------------------'||chr(10) ||
                                   :old.det_modificacion;
    end if;
  END IF; -- end if updating
END;
/

