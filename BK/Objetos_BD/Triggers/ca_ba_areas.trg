CREATE OR REPLACE TRIGGER IT."CA_BA_AREAS"
 AFTER DELETE OR INSERT OR UPDATE
 ON BA_AREAS
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into BA_AREAS_CRM ( COD_OFICINA            ,
                                         COD_AREA               ,
                                         DESCRIPCION            ,
                                         SIGLA                  ,
                                         COD_USU_SUPERVISOR     ,
                                         TIP_ACCION             )
                                 Values( :NEW.COD_OFICINA       ,
                                         :NEW.COD_AREA          ,
                                         :NEW.DESCRIPCION       ,
                                         :NEW.SIGLA             ,
                                         :NEW.COD_USU_SUPERVISOR,
                                         'I'                    );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If :new.descripcion <> :old.descripcion Then
                  insert into BA_AREAS_CRM ( COD_OFICINA            ,
                                             COD_AREA               ,
                                             DESCRIPCION            ,
                                             TIP_ACCION             )
                                     Values( :NEW.COD_OFICINA       ,
                                             :NEW.COD_AREA          ,
                                             :NEW.DESCRIPCION       ,
                                             'U'                    );
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into BA_AREAS_CRM ( COD_OFICINA            ,
                                         COD_AREA               ,
                                         TIP_ACCION             )
                                 Values( :OLD.COD_OFICINA       ,
                                         :OLD.COD_AREA          ,
                                         'D'                      );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_BA_AREAS',v_lugar||' : '||SQLERRM);
END;
/

