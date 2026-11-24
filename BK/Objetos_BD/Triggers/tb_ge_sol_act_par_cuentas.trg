CREATE OR REPLACE TRIGGER IT.TB_GE_SOL_ACT_PAR_CUENTAS
 BEFORE INSERT OR UPDATE
     ON GE_SOL_ACT_PAR_CUENTAS
    FOR EACH ROW
declare      
v_mod boolean := false; -- para identificar si el reg fue modificado realmente
begin
  IF inserting and nvl(:new.tip_modificacion,'I') <> 'N' THEN  -- si no es insercion inicial (carga datos)
     :new.tip_modificacion := 'I';
     :new.DET_MODIFICACION :='*Fecha :' || sysdate ||' - Usuario: '||upper(USER) ||chr(10) ||
                              '*Se agrega nuevo parametro '||:new.parametro||' '||:new.NRO_CUENTA||' '||:new.valor;
  END IF;

  IF updating THEN
    :new.DET_MODIFICACION := null;
    if :old.tip_modificacion = 'I' then
         :new.tip_modificacion := 'I';-- mantiene como insert ya que es un registro nuevo que se debe insertar
         :new.DET_MODIFICACION :='*Fecha :' || trunc(sysdate) ||' - Usuario: '||upper(USER) ||chr(10) ||
	                                  '*Mod. de nuevo parametro: '||:new.parametro ||' [N° Cuenta] '||:new.nro_cuenta|| '*Valor '||:new.valor;
    end if;

    if :new.tip_modificacion = 'M' then
      -- PARAMETRO
      IF (:OLD.PARAMETRO <> :NEW.PARAMETRO) or (:OLD.PARAMETRO is null and :NEW.PARAMETRO is not null) or
         (:OLD.PARAMETRO is not null and :NEW.PARAMETRO is null) THEN
          v_mod:= TRUE;
          IF :new.DET_MODIFICACION IS NULL THEN
             :new.DET_MODIFICACION := '*Parametro=> [Actual] '||:old.PARAMETRO||' [Nuevo] '||:new.PARAMETRO;
          else
             :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Parametro=> [Actual] '||:old.PARAMETRO||' [Nuevo] '||:new.PARAMETRO;
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

      -- VALOR DEL PARAMETRO
      IF (:OLD.valor <> :NEW.valor) or (:OLD.valor is null and :NEW.valor is not null) or
         (:OLD.valor is not null and :NEW.valor is null) THEN
          v_mod:= TRUE;
          IF :new.DET_MODIFICACION IS NULL THEN
             :new.DET_MODIFICACION := '*Valor Parametro=> [Actual] '||:old.valor||' [Nuevo] '||:new.valor;
          else
             :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Observacion=> [Actual] '||:old.valor||' [Nuevo] '||:new.valor;
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
                                      '------------------------------------------------------------------'||chr(10) ||
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
	                                '*Eliminación de Parámetro: '||:new.parametro ||' [N° Cuenta] '||:new.nro_cuenta|| ' [Valor] '||:new.valor;
    end if;
  END IF; -- end if updating
END;
/

