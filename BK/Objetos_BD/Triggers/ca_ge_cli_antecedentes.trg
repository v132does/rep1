CREATE OR REPLACE TRIGGER IT."CA_GE_CLI_ANTECEDENTES"
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_CLI_ANTECEDENTES
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into GE_CLI_ANTECEDENTES_CRM (COD_PERSONA      ,
                                                   FAJ_BURO         ,
                                                   TIP_ACCION       )
                                           Values (:NEW.COD_PERSONA ,
                                                   :NEW.FAJ_BURO    ,
                                                   'I'              );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If :new.FAJ_BURO <> :old.FAJ_BURO Then
                  insert into GE_CLI_ANTECEDENTES_CRM (COD_PERSONA     ,
                                                       FAJ_BURO        ,
                                                       TIP_ACCION      )
                                               Values (:NEW.COD_PERSONA,
                                                       :NEW.FAJ_BURO   ,
                                                       'U'             );
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into GE_CLI_ANTECEDENTES_CRM (COD_PERSONA     ,
                                                   TIP_ACCION      )
                                           Values (:OLD.COD_PERSONA,
                                                   'D'             );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_GE_CLI_ANTECEDENTES',v_lugar||' : '||SQLERRM);
END;
/

