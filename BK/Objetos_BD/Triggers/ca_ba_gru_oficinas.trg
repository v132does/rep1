CREATE OR REPLACE TRIGGER IT."CA_BA_GRU_OFICINAS"
 AFTER DELETE OR INSERT OR UPDATE
 ON BA_GRU_OFICINAS
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into BA_GRU_OFICINAS_CRM (COD_GRU_OFICINA        ,
                                               DESCRIPCION            ,
                                               COD_USU_ENCARGADO      ,
                                               TIP_ACCION             )
                                        Values(:NEW.COD_GRU_OFICINA   ,
                                               :NEW.DESCRIPCION       ,
                                               :NEW.COD_USU_ENCARGADO ,
                                               'I'                    );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If :new.DESCRIPCION   <> :old.DESCRIPCION Then

                  insert into BA_GRU_OFICINAS_CRM (COD_GRU_OFICINA        ,
                                                   DESCRIPCION            ,
                                                   TIP_ACCION             )
                                            Values(:NEW.COD_GRU_OFICINA   ,
                                                   :NEW.DESCRIPCION       ,
                                                   'U'                    );
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into BA_GRU_OFICINAS_CRM (COD_GRU_OFICINA        ,
                                               TIP_ACCION             )
                                        Values(:OLD.COD_GRU_OFICINA   ,
                                               'D'                    );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_BA_GRU_OFICINAS',v_lugar||' : '||SQLERRM);
END;
/

