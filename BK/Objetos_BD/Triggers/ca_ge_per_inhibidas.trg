CREATE OR REPLACE TRIGGER IT."CA_GE_PER_INHIBIDAS"
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_PER_INHIBIDAS
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into GE_PER_INHIBIDAS_CRM (COD_PERSONA        ,
                                                NRO_ORDEN          ,
                                                COD_CAUSA          ,
                                                FEC_INICIO         ,
                                                FEC_VENCIMIENTO    ,
                                                ORIGEN             ,
                                                ESTADO             ,
                                                FEC_REHABILITACION ,
                                                TIP_ACCION         )
                                         Values(:NEW.COD_PERSONA        ,
                                                :NEW.NRO_ORDEN          ,
                                                FUG_OBT_DES_CAUSA(:NEW.COD_CAUSA),
                                                :NEW.FEC_INICIO         ,
                                                :NEW.FEC_VENCIMIENTO    ,
                                                :NEW.ORIGEN             ,
                                                :NEW.ESTADO             ,
                                                :NEW.FEC_REHABILITACION ,
                                                'I'                     );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If :new.FEC_VENCIMIENTO    <> :old.FEC_VENCIMIENTO    Or
                 :new.ORIGEN             <> :old.ORIGEN             Or
                 :new.ESTADO             <> :old.ESTADO             Or
                 :new.FEC_REHABILITACION <> :old.FEC_REHABILITACION Then

                  insert into GE_PER_INHIBIDAS_CRM (COD_PERSONA        ,
                                                    NRO_ORDEN          ,
                                                    FEC_VENCIMIENTO    ,
                                                    ORIGEN             ,
                                                    ESTADO             ,
                                                    FEC_REHABILITACION ,
                                                    TIP_ACCION         )
                                             Values(:NEW.COD_PERSONA   ,
                                                    :NEW.NRO_ORDEN     ,
                                                    DECODE(:OLD.FEC_VENCIMIENTO   ,:NEW.FEC_VENCIMIENTO   ,NULL,:NEW.FEC_VENCIMIENTO),
                                                    DECODE(:OLD.ORIGEN            ,:NEW.ORIGEN            ,NULL,:NEW.ORIGEN),
                                                    DECODE(:OLD.ESTADO            ,:NEW.ESTADO            ,NULL,:NEW.ESTADO),
                                                    DECODE(:OLD.FEC_REHABILITACION,:NEW.FEC_REHABILITACION,NULL,:NEW.FEC_REHABILITACION),
                                                    'U'                );
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into GE_PER_INHIBIDAS_CRM (COD_PERSONA     ,
                                                NRO_ORDEN       ,
                                                TIP_ACCION      )
                                         Values(:OLD.COD_PERSONA,
                                                :OLD.NRO_ORDEN  ,
                                                'D'             );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_GE_PER_INHIBIDAS',v_lugar||' : '||SQLERRM);
END;
/

