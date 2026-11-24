CREATE OR REPLACE TRIGGER IT.TB_GE_SOL_ACT_DIRECCIONES
 BEFORE DELETE OR INSERT OR UPDATE
     ON GE_SOL_ACT_DIRECCIONES
    FOR EACH ROW
declare      
v_mod boolean := false; -- para identificar si el reg fue modificado realmente
begin
  IF inserting and nvl(:new.tip_modificacion,'I') <> 'N' THEN  -- si no es insercion inicial (carga datos)
     :new.tip_modificacion := 'I';
     :new.DET_MODIFICACION :='*Fecha :' || sysdate ||' - Usuario: '||upper(USER) ||chr(10) ||
                              '*Se agrega nueva dirección: '||:new.cod_direccion ||' [Direccion] '||:new.direccion||' [N°] '||
		                                :new.numero||' [Lateral] '||:new.dir_lateral||' [Principal] '|| :new.principal ||
		                                ' [Tipo] '||:new.tipo||chr(10) ||
                                    '---------------------------------------------';

  END IF;

  IF updating THEN
     :new.DET_MODIFICACION  := null;
    if :old.tip_modificacion = 'I' then
         :new.tip_modificacion := 'I';-- mantiene como insert ya que es un registro nuevo que se debe insertar
         :new.DET_MODIFICACION :='*Fecha :' || sysdate ||' - Usuario: '||upper(USER) ||chr(10) ||
          '*Se modif. nueva dirección: '||:new.cod_direccion ||' [Direccion] '||:new.direccion||' [N°] '||
		                                :new.numero||' [Lateral] '||:new.dir_lateral||' [Principal] '|| :new.principal ||
		                                ' [Tipo] '||:new.tipo||chr(10) ||
                                    '---------------------------------------------'||chr(10) ||
                                    :old.det_modificacion;
    end if;
	
   if :new.tip_modificacion = 'M' then
      -- tipo de direccion
      IF (:OLD.TIPO <> :NEW.TIPO) or (:OLD.TIPO is null and :NEW.TIPO is not null) or
         (:OLD.TIPO is not null and :NEW.TIPO is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
          :new.DET_MODIFICACION := '*Tipo Dirección=> [Actual] '||:old.tipo||' [Nuevo] '||:new.tipo;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Tipo Dirección=> [Actual] '||:old.tipo||' [Nuevo] '||:new.tipo;
        end if;
      end if;
      -- PRINCIPAL
      IF (:OLD.PRINCIPAL <> :NEW.PRINCIPAL) or (:OLD.PRINCIPAL is null and :NEW.PRINCIPAL is not null) or
         (:OLD.PRINCIPAL is not null and :NEW.PRINCIPAL is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Dir.Principal=> [Actual] '||:old.principal||' [Nuevo] '||:new.principal;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Dir.Principal=> [Actual] '||:old.principal||' [Nuevo] '||:new.principal;
        end if;
      end if;

      -- direccion
      IF (:OLD.DIRECCION <> :NEW.DIRECCION) or (:OLD.DIRECCION is null and :NEW.DIRECCION is not null)  or
         (:OLD.DIRECCION is not null and :NEW.DIRECCION is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Dirección=> [Actual] '||:old.direccion||' [Nuevo] '||:new.direccion;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Dirección=> [Actual] '||:old.direccion||' [Nuevo] '||:new.direccion;
        end if;
      end if;

      -- numero
      IF (:OLD.NUMERO <> :NEW.NUMERO) or (:OLD.NUMERO is null and :NEW.NUMERO is not null) or
         (:OLD.NUMERO is not null and :NEW.NUMERO is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Número=> [Actual] '||:old.numero||' [Nuevo] '||:new.numero;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Número=> [Actual] '||:old.numero||' [Nuevo] '||:new.numero;
        end if;
      end if;

      -- DIRECCION LATERAL
      IF (:OLD.DIR_LATERAL <> :NEW.DIR_LATERAL) or (:OLD.DIR_LATERAL is null and :NEW.DIR_LATERAL is not null) or
         (:OLD.DIR_LATERAL is not null and :NEW.DIR_LATERAL is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Dir.Lateral=> [Actual] '||:old.dir_lateral||' [Nuevo] '||:new.dir_lateral;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Dir.Lateral=> [Actual] '||:old.dir_lateral||' [Nuevo] '||:new.dir_lateral;
        end if;
      end if;

       -- EDIFICIO
      IF (:OLD.EDIFICIO <> :NEW.EDIFICIO) or (:OLD.EDIFICIO is null and :NEW.EDIFICIO is not null)  or
         (:OLD.EDIFICIO is not null and :NEW.EDIFICIO is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Edificio=> [Actual] '||:old.edificio||' [Nuevo] '||:new.edificio;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Edificio=> [Actual] '||:old.edificio||' [Nuevo] '||:new.edificio;
        end if;
      end if;

      -- PISO
      IF (:OLD.PISO <> :NEW.PISO) or (:OLD.PISO is null and :NEW.PISO is not null) or
         (:OLD.PISO is not null and :NEW.PISO is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Piso=> [Actual] '||:old.piso||' [Nuevo] '||:new.piso;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Piso=> [Actual] '||:old.piso||' [Nuevo] '||:new.piso;
        end if;
      end if;

      -- DEPARTAMENTO
      IF (:OLD.DEPARTAMENTO <> :NEW.DEPARTAMENTO) or (:OLD.DEPARTAMENTO is null and :NEW.DEPARTAMENTO is not null) or
         (:OLD.DEPARTAMENTO is not null and :NEW.DEPARTAMENTO is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Departamento=> [Actual] '||:old.departamento||' [Nuevo] '||:new.departamento;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Departamento=> [Actual] '||:old.departamento||' [Nuevo] '||:new.departamento;
        end if;
      end if;

      -- COD_PAIS
      IF (:OLD.COD_PAIS <> :NEW.COD_PAIS) or (:OLD.COD_PAIS is null and :NEW.COD_PAIS is not null)  or
         (:OLD.COD_PAIS is not null and :NEW.COD_PAIS is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Cod.Pais=> [Actual] '||:old.cod_pais||' [Nuevo] '||:new.cod_pais;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Cod.Pais=> [Actual] '||:old.cod_pais||' [Nuevo] '||:new.cod_pais;
        end if;
      end if;

      -- CODIGO DE CIUDAD
      IF (:OLD.COD_CIUDAD <> :NEW.COD_CIUDAD) or (:OLD.COD_CIUDAD is null and :NEW.COD_CIUDAD is not null) or
         (:OLD.COD_CIUDAD is not null and :NEW.COD_CIUDAD is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Cod.Ciudad=> [Actual] '||:old.cod_ciudad||' [Nuevo] '||:new.cod_ciudad;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Cod.Ciudad=> [Actual] '||:old.cod_ciudad||' [Nuevo] '||:new.cod_ciudad;
        end if;
      end if;

      -- CODIGO DE BARRIO
      IF (:OLD.COD_BARRIO <> :NEW.COD_BARRIO)  or (:OLD.COD_BARRIO is null and :NEW.COD_BARRIO is not null) or
         (:OLD.COD_BARRIO is not null and :NEW.COD_BARRIO is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Cod.Barrio=> [Actual] '||:old.cod_barrio||' [Nuevo] '||:new.cod_barrio;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Cod.Barrio=> [Actual] '||:old.cod_barrio||' [Nuevo] '||:new.cod_barrio;
        end if;
      end if;

      -- CODIGO POSTAL
      IF (:OLD.COD_POSTAL <> :NEW.COD_POSTAL) or (:OLD.COD_POSTAL is null and :NEW.COD_POSTAL is not null)  or
         (:OLD.COD_POSTAL is not null and :NEW.COD_POSTAL is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Cod.Postal=> [Actual] '||:old.cod_postal||' [Nuevo] '||:new.cod_postal;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Cod.Postal=> [Actual] '||:old.cod_postal||' [Nuevo] '||:new.cod_postal;
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
                                    '--------------------------------------------------'||chr(10) ||
                                    :old.det_modificacion;
         else -- si esta marcado como Modificacion pero no hubo cambios, setea el OLD para no perder el historico
             :new.DET_MODIFICACION := :old.det_modificacion;                             
         end if;                           
      else
         :new.tip_modificacion :='N';
      end if;                              
    end if;
    --
    if :new.tip_modificacion ='E' then
         :new.DET_MODIFICACION :='*Fecha :' || sysdate ||' - Usuario: '||upper(USER) ||chr(10) ||
		                                '*Eliminación de dirección: '||:new.cod_direccion ||' [Direccion] '||:new.direccion||' [N°] '||
		                                :new.numero||' [Lateral] '||:new.dir_lateral||' [Principal] '|| :new.principal ||
		                                ' [Tipo] '||:new.tipo||chr(10) ||
                                    '--------------------------------------------------'||chr(10) ||
                                   :old.det_modificacion;
    end if;
  END IF; -- end if updating
END;
/

