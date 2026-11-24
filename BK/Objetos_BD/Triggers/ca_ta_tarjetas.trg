CREATE OR REPLACE TRIGGER IT.CA_TA_TARJETAS
 AFTER DELETE OR INSERT OR UPDATE
 ON TA_TARJETAS
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into TA_TARJETAS_CRM ( NRO_CUENTA            ,
                                            NRO_TARJETA           ,
                                            COD_PERSONA           ,
                                            COD_ESTADO            ,
                                            NOM_EMBOZAR           ,
                                            VIGENTE               ,
                                            FEC_EMISION           ,
                                            FEC_VENCIMIENTO       ,
                                            TIP_ACCION            )
                                     Values(:NEW.NRO_CUENTA       ,
                                            :NEW.NRO_TARJETA      ,
                                            :NEW.COD_PERSONA      ,
                                            :NEW.COD_ESTADO       ,
                                            :NEW.NOM_EMBOZAR      ,
                                            :NEW.VIGENTE          ,
                                            :NEW.FEC_EMISION      ,
                                            :NEW.FEC_VENCIMIENTO  ,
                                            'I'                   );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If :new.VIGENTE         <> :old.VIGENTE         Or
                 :new.COD_ESTADO      <> :old.COD_ESTADO      Or
                 :new.NOM_EMBOZAR     <> :old.NOM_EMBOZAR     Or
                 nvl(:new.fec_emision,    TO_DATE('01/01/2017','DD-MM-YYYY')) <> nvl(:old.fec_emision,    TO_DATE('01/01/2017','DD-MM-YYYY')) Or
                 nvl(:new.fec_vencimiento,TO_DATE('01/01/2017','DD-MM-YYYY')) <> nvl(:old.fec_vencimiento,TO_DATE('01/01/2017','DD-MM-YYYY')) Or
                 nvl(:new.fec_activacion, TO_DATE('01/01/2017','DD-MM-YYYY')) <> nvl(:old.fec_activacion, TO_DATE('01/01/2017','DD-MM-YYYY')) Then 
                 insert into TA_TARJETAS_CRM  ( NRO_CUENTA            ,
                                                NRO_TARJETA           ,
                                                COD_PERSONA           ,
                                                COD_ESTADO            ,
                                                NOM_EMBOZAR           ,
                                                VIGENTE               ,
                                                FEC_EMISION           ,
                                                FEC_VENCIMIENTO       ,
                                                FEC_ACTIVACION        ,
                                                TIP_ACCION            )
                                         Values(:NEW.NRO_CUENTA       ,
                                                :NEW.NRO_TARJETA      ,
                                                :NEW.COD_PERSONA      ,
                                                DECODE(:OLD.COD_ESTADO     ,:NEW.COD_ESTADO     ,NULL,:NEW.COD_ESTADO),
                                                DECODE(:OLD.NOM_EMBOZAR    ,:NEW.NOM_EMBOZAR    ,NULL,:NEW.NOM_EMBOZAR),
                                                DECODE(:OLD.VIGENTE        ,:NEW.VIGENTE        ,NULL,:NEW.VIGENTE),
                                                DECODE(:OLD.FEC_EMISION    ,:NEW.FEC_EMISION    ,NULL,:NEW.FEC_EMISION),
                                                DECODE(:OLD.FEC_VENCIMIENTO,:NEW.FEC_VENCIMIENTO,NULL,:NEW.FEC_VENCIMIENTO),
                                                DECODE(:OLD.FEC_ACTIVACION ,:NEW.FEC_ACTIVACION ,NULL,:NEW.FEC_ACTIVACION),
                                                'U'                   );
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into TA_TARJETAS_CRM ( NRO_CUENTA            ,
                                            NRO_TARJETA           ,
                                            TIP_ACCION            )
                                     Values(:OLD.NRO_CUENTA       ,
                                            :OLD.NRO_TARJETA      ,
                                            'D'                  );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_TA_TARJETAS',v_lugar||' : '||SQLERRM);
END;
/

