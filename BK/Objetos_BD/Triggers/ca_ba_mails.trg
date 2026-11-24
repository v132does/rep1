CREATE OR REPLACE TRIGGER IT."CA_BA_MAILS"
 AFTER DELETE OR INSERT OR UPDATE
 ON BA_MAILS
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into BA_MAILS_CRM (COD_PERSONA          ,
                                        TIPO                 ,
                                        DIR_CORREO           ,
                                        PRINCIPAL            ,
                                        OBSERVACION          ,
                                        TIP_ACCION           )
                                 Values(:NEW.COD_PERSONA     ,
                                        :NEW.TIPO            ,
                                        :NEW.DIR_CORREO      ,
                                        :NEW.PRINCIPAL       ,
                                        :NEW.OBSERVACION     ,
                                        'I'                  );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If :new.TIPO       <> :old.TIPO       Or
                 :new.DIR_CORREO <> :old.DIR_CORREO Or
                 :new.PRINCIPAL  <> :old.PRINCIPAL  Then

                  insert into BA_MAILS_CRM (COD_PERSONA          ,
                                            TIPO                 ,
                                            DIR_CORREO           ,
                                            PRINCIPAL            ,
                        DIR_CORREO_OLD       ,
                                            TIP_ACCION           )
                                     Values(:NEW.COD_PERSONA     ,
                                            DECODE(:OLD.TIPO      ,:NEW.TIPO      ,NULL,:NEW.TIPO      ),
                                            DECODE(:OLD.DIR_CORREO,:NEW.DIR_CORREO,NULL,:NEW.DIR_CORREO),
                                            DECODE(:OLD.PRINCIPAL ,:NEW.PRINCIPAL ,NULL,:NEW.PRINCIPAL ),
                        DECODE(:OLD.DIR_CORREO,:NEW.DIR_CORREO,NULL,:OLD.DIR_CORREO),
                                            'U'                  );
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into BA_MAILS_CRM (COD_PERSONA          ,
                                        DIR_CORREO           ,
                                        TIP_ACCION           )
                                 Values(:OLD.COD_PERSONA     ,
                                        :OLD.DIR_CORREO      ,
                                        'D'                  );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_BA_MAILS',v_lugar||' : '||SQLERRM);
END;
/

