CREATE OR REPLACE TRIGGER IT.CA_CC_LIN_SOBREGIROS
 AFTER DELETE OR INSERT OR UPDATE
 ON CC_LIN_SOBREGIROS
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into CC_LIN_SOBREGIROS_CRM(NRO_CUENTA     ,
                                                FEC_VENCIMIENTO,
                                                MONTO          ,
                                                TIPO           ,
                                                COD_PERSONA    ,
                                                COD_MONEDA     ,
                                                ESTADO         ,
                                                FEC_INICIO     ,
                                                NRO_SECUENCIA  ,
                                                NRO_SEC_PADRE  ,
                                                TIP_ACCION     )
                                        Values( :NEW.NRO_CUENTA     ,
                                                :NEW.FEC_VENCIMIENTO,
                                                :NEW.MONTO          ,
                                                :NEW.TIPO           ,
                                                :NEW.COD_PERSONA    ,
                                                :NEW.COD_MONEDA     ,
                                                :NEW.ESTADO         ,
                                                :NEW.FEC_INICIO     ,
                                                :NEW.NRO_SECUENCIA  ,
                                                :NEW.NRO_SEC_PADRE  ,
                                                'I'                 );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If nvl(:new.monto,0)          <> nvl(:old.monto,0)
                 or nvl(:new.cod_persona,0) <> nvl(:old.cod_persona,0)
                 or nvl(:new.estado,'X')    <> nvl(:old.estado,'X') Then

                  insert into CC_LIN_SOBREGIROS_CRM(NRO_CUENTA               ,
                                                    COD_PERSONA              ,
                                                    NRO_SECUENCIA            ,
                                                    MONTO                    ,
                                                    ESTADO                   ,
                                                    TIP_ACCION               )
                                            Values( :NEW.NRO_CUENTA          ,
                                                    DECODE(NVL(:NEW.COD_PERSONA,0),NVL(:OLD.COD_PERSONA,0),NULL,NVL(:NEW.COD_PERSONA,0)),
                                                    :OLD.NRO_SECUENCIA,
                                                    DECODE(NVL(:NEW.MONTO,0),NVL(:OLD.MONTO,0),NULL,NVL(:NEW.MONTO,0)),
                                                    DECODE(NVL(:NEW.ESTADO,'X'),NVL(:OLD.ESTADO,'X'),NULL,NVL(:NEW.ESTADO,'X')),
                                                    'U'                      );
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into CC_LIN_SOBREGIROS_CRM(NRO_CUENTA               ,
                                                COD_PERSONA              ,
                                                NRO_SECUENCIA            ,
                                                TIP_ACCION               )
                                        Values( :OLD.NRO_CUENTA          ,
                                                :OLD.COD_PERSONA         ,
                                                :OLD.NRO_SECUENCIA       ,
                                                'D'                      );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_CC_LIN_SOBREGIROS',v_lugar||' : '||SQLERRM);
END;
/

