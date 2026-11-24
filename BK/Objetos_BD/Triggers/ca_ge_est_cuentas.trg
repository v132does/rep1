CREATE OR REPLACE TRIGGER IT."CA_GE_EST_CUENTAS"
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_EST_CUENTAS
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into GE_EST_CUENTAS_CRM(COD_MODULO        ,
                                             COD_MODALIDAD     ,
                                             ESTADO            ,
                                             DESCRIPCION       ,
                                             ACTIVO            ,
                                             TIP_ACCION        )
                                     Values( :NEW.COD_MODULO   ,
                                             :NEW.COD_MODALIDAD,
                                             :NEW.ESTADO       ,
                                             :NEW.DESCRIPCION  ,
                                             :NEW.ACTIVO       ,
                                             'I'               );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If :new.estado      <> :old.estado      Or
                 :new.descripcion <> :old.descripcion Or
                 :new.activo      <> :old.activo      Then
                  insert into GE_EST_CUENTAS_CRM (COD_MODULO        ,
                                                  COD_MODALIDAD     ,
                                                  ESTADO            ,
                                                  DESCRIPCION       ,
                                                  ACTIVO            ,
                                                  TIP_ACCION        )
                                          Values( :NEW.COD_MODULO   ,
                                                  :NEW.COD_MODALIDAD,
                                                  decode(:OLD.ESTADO     ,:NEW.ESTADO     ,NULL,:NEW.ESTADO),
                                                  decode(:OLD.DESCRIPCION,:NEW.DESCRIPCION,NULL,:NEW.DESCRIPCION),
                                                  decode(:OLD.ACTIVO     ,:NEW.ACTIVO     ,NULL,:NEW.ACTIVO),
                                                  'U'               );
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into GE_EST_CUENTAS_CRM (COD_MODULO        ,
                                              COD_MODALIDAD     ,
                                              ESTADO            ,
                                              TIP_ACCION        )
                                       Values(:OLD.COD_MODULO   ,
                                              :OLD.COD_MODALIDAD,
                                              :OLD.ESTADO       ,
                                              'D'               );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('GE_EST_CUENTAS_CRM',v_lugar||' : '||SQLERRM);
END;
/

