CREATE OR REPLACE TRIGGER IT.CA_TA_CTA_TARJETAS
 AFTER DELETE OR INSERT OR UPDATE
 ON TA_CTA_TARJETAS
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into TA_CTA_TARJETAS_CRM (NRO_CUENTA          ,
                                               COD_MODULO          ,
                                               COD_MODALIDAD       ,
                                               ESTADO              ,
                                               FEC_ACTIVACION      ,
                                               FEC_CANCELACION     ,
                                               FEC_APERTURA        ,
                                               TIP_ACCION          )
                                       Values( :NEW.NRO_CUENTA     ,
                                               :NEW.COD_MODULO     ,
                                               :NEW.COD_MODALIDAD  ,
                                               :NEW.ESTADO         ,
                                               :NEW.FEC_ACTIVACION ,
                                               :NEW.FEC_CANCELACION,
                                               :NEW.FEC_APERTURA   ,
                                               'I'                 );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If :new.estado  <> :old.estado  OR
                 nvl(:new.fec_activacion, TO_DATE('01/01/2017','DD-MM-YYYY')) <> nvl(:old.fec_activacion,TO_DATE('01/01/2017','DD-MM-YYYY')) Or
                 nvl(:new.fec_cancelacion,TO_DATE('01/01/2017','DD-MM-YYYY'))<> nvl(:old.fec_cancelacion,TO_DATE('01/01/2017','DD-MM-YYYY')) Then 
                  insert into TA_CTA_TARJETAS_CRM (NRO_CUENTA          ,
                                                   COD_MODULO          ,
                                                   COD_MODALIDAD       ,
                                                   ESTADO              ,
                                                   FEC_ACTIVACION      ,
                                                   FEC_CANCELACION     ,
                                                   FEC_APERTURA        ,
                                                   TIP_ACCION          )
                                           Values( :NEW.NRO_CUENTA     ,
                                                   :OLD.COD_MODULO     ,
                                                   :OLD.COD_MODALIDAD  ,
                                                   DECODE(:OLD.ESTADO         ,:NEW.ESTADO         ,NULL,:NEW.ESTADO),
                                                   DECODE(:OLD.FEC_ACTIVACION ,:NEW.FEC_ACTIVACION ,NULL,:NEW.FEC_ACTIVACION),
                                                   DECODE(:OLD.FEC_CANCELACION,:NEW.FEC_CANCELACION,NULL,:NEW.FEC_CANCELACION),
                                                   DECODE(:OLD.FEC_APERTURA   ,:NEW.FEC_APERTURA   ,NULL,:NEW.FEC_APERTURA),
                                                   'U'                 );
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into TA_CTA_TARJETAS_CRM (NRO_CUENTA     ,
                                               TIP_ACCION     )
                                       Values( :OLD.NRO_CUENTA,
                                               'D'            );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_TA_CTA_TARJETAS',v_lugar||' : '||SQLERRM);
END;
/
