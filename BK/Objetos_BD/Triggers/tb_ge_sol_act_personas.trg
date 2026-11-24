CREATE OR REPLACE TRIGGER IT.TB_GE_SOL_ACT_PERSONAS
 BEFORE DELETE OR INSERT OR UPDATE
     ON GE_SOL_ACT_PERSONAS
    FOR EACH ROW
declare      
v_mod boolean := false; -- para identificar si el reg fue modificado realmente      
begin
  IF inserting and nvl(:new.tip_modificacion,'I') <> 'N' THEN  -- si no es insercion inicial (carga datos)
     :new.tip_modificacion := 'I';
  END IF;

  IF updating THEN
   :new.DET_MODIFICACION := null;
   if :old.tip_modificacion = 'I' then
       :new.tip_modificacion := 'I';-- mantiene como insert ya que es un registro nuevo que se debe insertar
   end if;

   if :new.tip_modificacion = 'M' then
      -- tipo de persona
      IF (:OLD.TIPO <> :NEW.TIPO) or (:OLD.TIPO is null and :NEW.TIPO is not null) or
         (:OLD.TIPO is not null and :NEW.TIPO is null) THEN
          v_mod:= TRUE;
          IF :new.DET_MODIFICACION IS NULL THEN
            :new.DET_MODIFICACION := '*Tipo Persona: [Actual] '||:old.tipo||' [Nuevo] '||:new.tipo;
          else
             :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Tipo Persona=> [Actual] '||:old.tipo||' [Nuevo] '||:new.tipo;
          end if;
      end if;
      -- Tipo de documento
      IF (:OLD.COD_TIP_DOCUMENTO <> :NEW.COD_TIP_DOCUMENTO) or (:OLD.COD_TIP_DOCUMENTO is null and :NEW.COD_TIP_DOCUMENTO is not null) or
         (:OLD.COD_TIP_DOCUMENTO is not null and :NEW.COD_TIP_DOCUMENTO is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Tipo Doc.=> [Actual] '||:old.cod_tip_documento||' [Nuevo] '||:new.cod_tip_documento;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Tipo Doc.=> [Actual] '||:old.cod_tip_documento||' [Nuevo] '||:new.cod_tip_documento;
        end if;
      end if;

      -- Numero de documento
      IF (:OLD.NRO_DOCUMENTO <> :NEW.NRO_DOCUMENTO) or (:OLD.NRO_DOCUMENTO is null and :NEW.NRO_DOCUMENTO is not null) or
         (:OLD.NRO_DOCUMENTO is not null and :NEW.NRO_DOCUMENTO is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*N° Documento=> [Actual] '||:old.nro_documento||' [Nuevo] '||:new.nro_documento;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*N° Documento=> [Actual] '||:old.nro_documento||' [Nuevo] '||:new.nro_documento;
        end if;
      end if;

      -- fecha de vencimiento documento
      IF (:OLD.FEC_VTO_DOCUMENTO <> :NEW.FEC_VTO_DOCUMENTO) or (:OLD.FEC_VTO_DOCUMENTO is null and :NEW.FEC_VTO_DOCUMENTO is not null) or
         (:OLD.FEC_VTO_DOCUMENTO is not null and :NEW.FEC_VTO_DOCUMENTO is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Fec.Vto.Documento=> [Actual] '||:old.fec_vto_documento||' [Nuevo] '||:new.fec_vto_documento;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Fec.Vto.Documento=> [Actual] '||:old.fec_vto_documento||' [Nuevo] '||:new.fec_vto_documento;
        end if;
      end if;

      -- Pais Documento
      IF (:OLD.COD_PAI_DOCUMENTO <> :NEW.COD_PAI_DOCUMENTO) or (:OLD.COD_PAI_DOCUMENTO is null and :NEW.COD_PAI_DOCUMENTO is not null) or
         (:OLD.COD_PAI_DOCUMENTO is not null and :NEW.COD_PAI_DOCUMENTO is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Cod.Pais Documento=> [Actual] '||:old.cod_pai_documento||' [Nuevo] '||:new.cod_pai_documento;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Cod.Pais Documento=> [Actual] '||:old.cod_pai_documento||' [Nuevo] '||:new.cod_pai_documento;
        end if;
      end if;

       -- Direccion de correo
      IF (:OLD.DIR_CORREO <> :NEW.DIR_CORREO) or (:OLD.DIR_CORREO is null and :NEW.DIR_CORREO is not null) or
         (:OLD.DIR_CORREO is not null and :NEW.DIR_CORREO is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Dir.Correo=> [Actual] '||:old.dir_correo||' [Nuevo] '||:new.dir_correo;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Dir.Correo=> [Actual] '||:old.dir_correo||' [Nuevo] '||:new.dir_correo;
        end if;
      end if;

      -- Primer Nombre
      IF (:OLD.PRI_NOMBRE <> :NEW.PRI_NOMBRE) or (:OLD.PRI_NOMBRE is null and :NEW.PRI_NOMBRE is not null) or
         (:OLD.PRI_NOMBRE is not null and :NEW.PRI_NOMBRE is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Primer Nombre=> [Actual] '||:old.pri_nombre||' [Nuevo] '||:new.pri_nombre;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Primer Nombre=> [Actual] '||:old.pri_nombre||' [Nuevo] '||:new.pri_nombre;
        end if;
      end if;

      -- Segundo Nombre
      IF (:OLD.SEG_NOMBRE <> :NEW.SEG_NOMBRE) or (:OLD.SEG_NOMBRE is null and :NEW.SEG_NOMBRE is not null) or
         (:OLD.SEG_NOMBRE is not null and :NEW.SEG_NOMBRE is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Segundo Nombre=> [Actual] '||:old.seg_nombre||' [Nuevo] '||:new.seg_nombre;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Segundo Nombre=> [Actual] '||:old.seg_nombre||' [Nuevo] '||:new.seg_nombre;
        end if;
      end if;

      -- Primer Apellido
      IF (:OLD.PRI_APELLIDO <> :NEW.PRI_APELLIDO) or (:OLD.PRI_APELLIDO is null and :NEW.PRI_APELLIDO is not null) or
         (:OLD.PRI_APELLIDO is not null and :NEW.PRI_APELLIDO is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Primer Apellido=> [Actual] '||:old.pri_apellido||' [Nuevo] '||:new.pri_apellido;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Primer Apellido=> [Actual] '||:old.pri_apellido||' [Nuevo] '||:new.pri_apellido;
        end if;
      end if;

      -- Segundo Apellido
      IF (:OLD.SEG_APELLIDO <> :NEW.SEG_APELLIDO) or (:OLD.SEG_APELLIDO is null and :NEW.SEG_APELLIDO is not null) or
         (:OLD.SEG_APELLIDO is not null and :NEW.SEG_APELLIDO is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Segundo Apellido=> [Actual] '||:old.seg_apellido||' [Nuevo] '||:new.seg_apellido;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Segundo Apellido=> [Actual] '||:old.seg_apellido||' [Nuevo] '||:new.seg_apellido;
        end if;
      end if;

      -- Fecha de Nacimiento
      IF (:OLD.FEC_NACIMIENTO <> :NEW.FEC_NACIMIENTO) or (:OLD.FEC_NACIMIENTO is null and :NEW.FEC_NACIMIENTO is not null) or
         (:OLD.FEC_NACIMIENTO is not null and :NEW.FEC_NACIMIENTO is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Fec.Nacimiento=> [Actual] '||:old.fec_nacimiento||' [Nuevo] '||:new.fec_nacimiento;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Fec.Nacimiento=> [Actual] '||:old.fec_nacimiento||' [Nuevo] '||:new.fec_nacimiento;
        end if;
      end if;

      -- Razon Social
      IF (:OLD.RAZ_SOCIAL <> :NEW.RAZ_SOCIAL) or (:OLD.RAZ_SOCIAL is null and :NEW.RAZ_SOCIAL is not null) or
         (:OLD.RAZ_SOCIAL is not null and :NEW.RAZ_SOCIAL is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Razon Social=> [Actual] '||:old.raz_social||' [Nuevo] '||:new.raz_social;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Razon Social=> [Actual] '||:old.raz_social||' [Nuevo] '||:new.raz_social;
        end if;
      end if;

      -- Nombre Comercial
      IF (:OLD.NOM_COMERCIAL <> :NEW.NOM_COMERCIAL) or (:OLD.NOM_COMERCIAL is null and :NEW.NOM_COMERCIAL is not null) or
         (:OLD.NOM_COMERCIAL is not null and :NEW.NOM_COMERCIAL is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Nom.Comercial=> [Actual] '||:old.nom_comercial||' [Nuevo] '||:new.nom_comercial;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Nom.Comercial=> [Actual] '||:old.nom_comercial||' [Nuevo] '||:new.nom_comercial;
        end if;
      end if;

     -- Fecha de Apertura
      IF (:OLD.FEC_APERTURA <> :NEW.FEC_APERTURA) or (:OLD.FEC_APERTURA is null and :NEW.FEC_APERTURA is not null) or
         (:OLD.FEC_APERTURA is not null and :NEW.FEC_APERTURA is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Fec.Apertura=> [Actual] '||:old.fec_apertura||' [Nuevo] '||:new.fec_apertura;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Fec.Apertura=> [Actual] '||:old.fec_apertura||' [Nuevo] '||:new.fec_apertura;
        end if;
      end if;

      -- Naturaleza
      IF (:OLD.NATURALEZA <> :NEW.NATURALEZA) or (:OLD.NATURALEZA is null and :NEW.NATURALEZA is not null) or
         (:OLD.NATURALEZA is not null and :NEW.NATURALEZA is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Naturaleza=> [Actual] '||:old.naturaleza||' [Nuevo] '||:new.naturaleza;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Naturaleza=> [Actual] '||:old.naturaleza||' [Nuevo] '||:new.naturaleza;
        end if;
      end if;
      
      -- -MAO BSEVOCORE-511
      
         
      IF (:OLD.EST_CIVIL <> :NEW.EST_CIVIL) or (:OLD.EST_CIVIL is null and :NEW.EST_CIVIL is not null) or
         (:OLD.EST_CIVIL is not null and :NEW.EST_CIVIL is null) THEN
        v_mod:= TRUE;
        IF :new.DET_MODIFICACION IS NULL THEN
           :new.DET_MODIFICACION := '*Est. civil => [Actual] '||:old.EST_CIVIL||' [Nuevo] '||:new.EST_CIVIL;
        else
           :new.DET_MODIFICACION := :new.DET_MODIFICACION ||chr(10) || '*Est. civil.=> [Actual] '||:old.EST_CIVIL||' [Nuevo] '||:new.EST_CIVIL;
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
                                    '------------------------------------------------'||chr(10) ||
                                   :old.det_modificacion;
          else  -- si esta marcado como Modificacion pero no hubo cambios, setea el OLD para no perder el historico
             :new.DET_MODIFICACION := :old.det_modificacion;                           
         end if;                          
      else
         :new.tip_modificacion :='N';
      end if;    
    end if;
    --
    if :new.tip_modificacion in ('I','E') then
         :new.DET_MODIFICACION :=  '*Fecha :' || sysdate ||' - Usuario: '||upper(USER) ||chr(10) ||
                                  :new.DET_MODIFICACION ;
    end if;
 END IF; -- end if updating
END;
/

