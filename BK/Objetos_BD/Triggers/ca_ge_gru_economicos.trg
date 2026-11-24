CREATE OR REPLACE TRIGGER IT."CA_GE_GRU_ECONOMICOS"
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_GRU_ECONOMICOS
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into GE_GRU_ECONOMICOS_CRM (COD_GRU_ECONOMICO       ,
                                                 DESCRIPCION             ,
                                                 CAT_AUTOMATICA          ,
                                                 TOT_DEU_REAL            ,
                                                 TOT_DEU_CONTINGENTE     ,
                                                 TIP_ACCION              )
                                          Values(:NEW.COD_GRU_ECONOMICO  ,
                                                 :NEW.DESCRIPCION        ,
                                                 :NEW.CAT_AUTOMATICA     ,
                                                 :NEW.TOT_DEU_REAL       ,
                                                 :NEW.TOT_DEU_CONTINGENTE,
                                                 'I'                     );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If :new.DESCRIPCION   <> :old.DESCRIPCION Then

                  insert into GE_GRU_ECONOMICOS_CRM (COD_GRU_ECONOMICO       ,
                                                     DESCRIPCION             ,
                                                     CAT_AUTOMATICA          ,
                                                     TOT_DEU_REAL            ,
                                                     TOT_DEU_CONTINGENTE     ,
                                                     TIP_ACCION              )
                                              Values(:NEW.COD_GRU_ECONOMICO  ,
                                                     DECODE(:OLD.DESCRIPCION        ,:NEW.DESCRIPCION        ,NULL,:NEW.DESCRIPCION),
                                                     DECODE(:OLD.CAT_AUTOMATICA     ,:NEW.CAT_AUTOMATICA     ,NULL,:NEW.CAT_AUTOMATICA),
                                                     DECODE(:OLD.TOT_DEU_REAL       ,:NEW.TOT_DEU_REAL       ,NULL,:NEW.TOT_DEU_REAL),
                                                     DECODE(:OLD.TOT_DEU_CONTINGENTE,:NEW.TOT_DEU_CONTINGENTE,NULL,:NEW.TOT_DEU_CONTINGENTE),
                                                     'U'                     );
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into GE_GRU_ECONOMICOS_CRM (COD_GRU_ECONOMICO       ,
                                                 TIP_ACCION              )
                                          Values(:OLD.COD_GRU_ECONOMICO  ,
                                                 'D'                     );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_GE_GRU_ECONOMICOS',v_lugar||' : '||SQLERRM);
END;
/

