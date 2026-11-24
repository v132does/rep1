CREATE OR REPLACE TRIGGER IT.CA_AH_TAR_DEBITOS
 AFTER DELETE OR INSERT OR UPDATE
 ON AH_TAR_DEBITOS
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into AH_TAR_DEBITOS_CRM(NRO_CUENTA              ,
                                             TAR_ACTIVA              ,
                                             FEC_INGRESO             ,
                                             COD_PERSONA             ,
                                             EMBOZADO                ,
                                             ADHERENTE               ,
                                             NRO_EMISION             ,
                                             FEC_VENCIMIENTO         ,
                                             COD_ENT_PROCESADORA     ,
                                             NRO_TARJETA             ,
                                             NRO_BIN                 ,
                                             TIP_ACCION              )
                                     Values( :NEW.NRO_CUENTA         ,
                                             :NEW.TAR_ACTIVA         ,
                                             :NEW.FEC_INGRESO        ,
                                             :NEW.COD_PERSONA        ,
                                             :NEW.EMBOZADO           ,
                                             :NEW.ADHERENTE          ,
                                             :NEW.NRO_EMISION        ,
                                             :NEW.FEC_VENCIMIENTO    ,
                                             :NEW.COD_ENT_PROCESADORA,
                                             :NEW.NRO_TARJETA        ,
                                             :NEW.NRO_BIN            ,
                                             'I'                     );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If nvl(:NEW.TAR_ACTIVA,'X') <> nvl(:old.TAR_ACTIVA,'X')
                 or nvl(:new.nro_emision,00) <> nvl(:old.nro_emision,00) Then
                  insert into AH_TAR_DEBITOS_CRM(NRO_CUENTA               ,
                                                 TAR_ACTIVA               ,
                                                 ADHERENTE                ,
                                                 NRO_EMISION              ,
                                                 NRO_TARJETA              ,
                                                 COD_PERSONA              ,
                                                 NRO_BIN                  ,
                                                 FEC_ENTREGA              ,
                                                 TIP_ACCION               )
                                         Values( :OLD.NRO_CUENTA          ,
                                                 DECODE(NVL(:NEW.TAR_ACTIVA,'X'),NVL(:OLD.TAR_ACTIVA,'X'),NULL,:NEW.TAR_ACTIVA),
                                                 :OLD.ADHERENTE           ,
                                                 DECODE(NVL(:NEW.NRO_EMISION,00),NVL(:OLD.NRO_EMISION,00),NULL,:NEW.NRO_EMISION),
                                                 :OLD.NRO_TARJETA         ,
                                                 :OLD.COD_PERSONA         ,
                                                 :OLD.NRO_BIN             ,
                                                 DECODE(:OLD.FEC_ENTREGA ,:NEW.FEC_ENTREGA ,NULL,:NEW.FEC_ENTREGA),
                                                 'U'                      );
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into AH_TAR_DEBITOS_CRM(NRO_CUENTA               ,
                                             NRO_TARJETA              ,
                                             COD_PERSONA              ,
                                             ADHERENTE                ,
                                             NRO_EMISION              ,
                                             NRO_BIN                  ,
                                             TIP_ACCION               )
                                     Values( :OLD.NRO_CUENTA          ,
                                             :OLD.NRO_TARJETA         ,
                                             :OLD.COD_PERSONA         ,
                                             :OLD.ADHERENTE           ,
                                             :OLD.NRO_EMISION         ,
                                             :OLD.NRO_BIN             ,
                                             'D'                      );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_AH_TAR_DEBITOS',v_lugar||' : '||SQLERRM);
END;
/

