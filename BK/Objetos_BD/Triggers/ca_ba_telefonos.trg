CREATE OR REPLACE TRIGGER IT."CA_BA_TELEFONOS"
 AFTER DELETE OR INSERT OR UPDATE
 ON BA_TELEFONOS
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into BA_TELEFONOS_CRM (  COD_PERSONA          ,
                                              TIPO                 ,
                                              TIP_LINEA            ,
                                              TELEFONO             ,
                                              PRINCIPAL            ,
                                              AREA                 ,
                                              INTERNO              ,
                                              OBSERVACION          ,
                                              COD_TELEFONO         ,
                                              TIP_ACCION           )
                                      Values( :NEW.COD_PERSONA     ,
                                              :NEW.TIPO            ,
                                              :NEW.TIP_LINEA       ,
                                              :NEW.TELEFONO        ,
                                              :NEW.PRINCIPAL       ,
                                              :NEW.AREA            ,
                                              :NEW.INTERNO         ,
                                              :NEW.OBSERVACION     ,
                                              :NEW.COD_TELEFONO    ,
                                              'I'                  );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If :new.PRINCIPAL <> :old.PRINCIPAL Or
                 :new.TIPO      <> :old.TIPO      Or
                 :new.AREA      <> :old.AREA      Or
                 :new.TELEFONO  <> :old.TELEFONO  Or
                 :new.TIP_LINEA <> :old.TIP_LINEA Then
                  insert into BA_TELEFONOS_CRM (  COD_PERSONA          ,
                                                  TIPO                 ,
                                                  TIP_LINEA            ,
                                                  TELEFONO             ,
                                                  PRINCIPAL            ,
                                                  AREA                 ,
                                                  COD_TELEFONO         ,
                                                  TIP_ACCION           )
                                          Values( :NEW.COD_PERSONA     ,
                                                  DECODE(:OLD.TIPO     ,:NEW.TIPO     ,NULL,:NEW.TIPO),
                                                  DECODE(:OLD.TIP_LINEA,:NEW.TIP_LINEA,NULL,:NEW.TIP_LINEA),
                                                  DECODE(:OLD.TELEFONO ,:NEW.TELEFONO ,:OLD.TELEFONO,:NEW.TELEFONO),
                                                  DECODE(:OLD.PRINCIPAL,:NEW.PRINCIPAL,NULL,:NEW.PRINCIPAL),
                                                  DECODE(:OLD.AREA     ,:NEW.AREA     ,NULL,:NEW.AREA),
                                                  :NEW.COD_TELEFONO    ,
                                                  'U'                  );
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into BA_TELEFONOS_CRM (  COD_PERSONA          ,
                                              COD_TELEFONO         ,
                          TELEFONO			   ,
                                              TIP_ACCION           )
                                      Values( :OLD.COD_PERSONA     ,
                                              :OLD.COD_TELEFONO    ,
                          :OLD.TELEFONO		   ,
                                              'D'                  );
        End If;
    End IF;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_BA_TELEFONOS',v_lugar||' : '||SQLERRM);
END;
/

