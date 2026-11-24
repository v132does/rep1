CREATE OR REPLACE TRIGGER IT.CA_GE_POL_SEGUROS
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_POL_SEGUROS
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into GE_POL_SEGUROS_CRM (CODIGO                ,
                                              COD_PERSONA           ,
                                              COD_ENTE              ,
                                              SECCION               ,
                                              SUB_SECCION           ,
                                              OBSERVACIONES         ,
                                              NRO_POLIZA            ,
                                              PRODUCTO              ,
                                              FEC_INICIAL           ,
                                              FEC_FINAL             ,
                                              ESTADO                ,
                                              SITUACION             ,
                                              COD_SUB_SECCION       ,
                                              TIP_ACCION            )
                                       Values(:NEW.CODIGO           ,
                                              :NEW.COD_PERSONA      ,
                                              :NEW.COD_ENTE         ,
                                              :NEW.SECCION          ,
                                              :NEW.SUB_SECCION      ,
                                              :NEW.OBSERVACIONES    ,
                                              :NEW.NRO_POLIZA       ,
                                              :NEW.PRODUCTO         ,
                                              :NEW.FEC_INICIAL      ,
                                              :NEW.FEC_FINAL        ,
                                              :NEW.ESTADO           ,
                                              :NEW.SITUACION        ,
                                              :NEW.COD_SUB_SECCION  ,
                                              'I'                   );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If :new.ESTADO      <> :old.ESTADO      Or
                 :new.SITUACION   <> :old.SITUACION   Or
                 :new.COD_ENTE    <> :old.COD_ENTE    Or
                 :new.NRO_POLIZA  <> :old.NRO_POLIZA  Or
                 :new.PRODUCTO    <> :old.PRODUCTO    Or    
                 :new.FEC_INICIAL <> :old.FEC_INICIAL Or
                 :new.FEC_FINAL   <> :old.FEC_FINAL   Or
                 :new.SECCION     <> :old.SECCION     Or
                 :new.SUB_SECCION <> :old.SUB_SECCION Or
                 :new.COD_SUB_SECCION <> :old.COD_SUB_SECCION Or
                 :new.OBSERVACIONES <> :old.OBSERVACIONES Then                 

                  insert into GE_POL_SEGUROS_CRM (CODIGO                ,
                                                  COD_PERSONA           ,
                                                  COD_ENTE              ,
                                                  SECCION               ,
                                                  SUB_SECCION           ,
                                                  NRO_POLIZA            ,
                                                  PRODUCTO              ,
                                                  FEC_INICIAL           ,
                                                  FEC_FINAL             ,
                                                  OBSERVACIONES         ,
                                                  ESTADO                ,
                                                  SITUACION             ,
                                                  COD_SUB_SECCION       ,
                                                  TIP_ACCION            )
                                           Values(:NEW.CODIGO           ,
                                                  :NEW.COD_PERSONA      ,
                                                  DECODE(:OLD.COD_ENTE,:NEW.COD_ENTE,NULL,:NEW.COD_ENTE),
                                                  DECODE(:OLD.SECCION,:NEW.SECCION,NULL,:NEW.SECCION),
                                                  DECODE(:OLD.SUB_SECCION,:NEW.SUB_SECCION,NULL,:NEW.SUB_SECCION),
                                                  DECODE(:OLD.NRO_POLIZA ,:NEW.NRO_POLIZA ,NULL,:NEW.NRO_POLIZA),
                                                  DECODE(:OLD.PRODUCTO ,:NEW.PRODUCTO ,NULL,:NEW.PRODUCTO),
                                                  DECODE(:OLD.FEC_INICIAL,:NEW.FEC_INICIAL,NULL,:NEW.FEC_INICIAL),
                                                  DECODE(:OLD.FEC_FINAL  ,:NEW.FEC_FINAL  ,NULL,:NEW.FEC_FINAL),
                                                  DECODE(:OLD.OBSERVACIONES,:NEW.OBSERVACIONES,NULL,:NEW.OBSERVACIONES),
                                                  DECODE(:OLD.ESTADO     ,:NEW.ESTADO     ,NULL,:NEW.ESTADO),
                                                  DECODE(:OLD.SITUACION  ,:NEW.SITUACION  ,NULL,:NEW.SITUACION),
                                                  DECODE(:OLD.COD_SUB_SECCION,:NEW.COD_SUB_SECCION,NULL,:NEW.COD_SUB_SECCION),
                                                  'U'                   );
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into GE_POL_SEGUROS_CRM (CODIGO                ,
                                              COD_PERSONA           ,
                                              TIP_ACCION            )
                                       Values(:OLD.CODIGO           ,
                                              :OLD.COD_PERSONA      ,
                                              'D'                   );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_GE_POL_SEGUROS',v_lugar||': '||:NEW.COD_PERSONA||' - '||SQLERRM);
END;
/

