CREATE OR REPLACE TRIGGER IT."CA_GE_MODALIDADES"
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_MODALIDADES
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into GE_MODALIDADES_CRM(COD_MODULO        ,
                                             COD_MODALIDAD     ,
                                             DESCRIPCION       ,
                                             TIP_ACCION        )
                                     Values( :NEW.COD_MODULO   ,
                                             :NEW.COD_MODALIDAD,
                                             :NEW.DESCRIPCION  ,
                                             'I'               );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If :new.descripcion <> :old.descripcion Then
                  insert into GE_MODALIDADES_CRM (COD_MODULO        ,
                                                  COD_MODALIDAD     ,
                                                  DESCRIPCION       ,
                                                  TIP_ACCION        )
                                          Values( :NEW.COD_MODULO   ,
                                                  :NEW.COD_MODALIDAD,
                                                  :NEW.DESCRIPCION  ,
                                                  'U'               );
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into GE_MODALIDADES_CRM (COD_MODULO        ,
                                              COD_MODALIDAD     ,
                                              TIP_ACCION        )
                                       Values(:OLD.COD_MODULO   ,
                                              :OLD.COD_MODALIDAD,
                                              'D'               );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_GE_MODALIDADES',v_lugar||' : '||SQLERRM);
END;
/

