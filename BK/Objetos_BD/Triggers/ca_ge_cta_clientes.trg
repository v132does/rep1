CREATE OR REPLACE TRIGGER IT.CA_GE_CTA_CLIENTES
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_CTA_CLIENTES
 FOR EACH ROW
DECLARE
   v_lugar  varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into GE_CTA_CLIENTES_CRM ( COD_PERSONA           ,
                                                COD_MODULO            ,
                                                COD_MODALIDAD         ,
                                                NRO_CUENTA            ,
                                                RELACION              ,
                                                TIP_ACCION            )
                                         Values(:NEW.COD_PERSONA      ,
                                                :NEW.COD_MODULO       ,
                                                :NEW.COD_MODALIDAD    ,
                                                :NEW.NRO_CUENTA       ,
                                                :NEW.RELACION         ,
                                                'I'                   );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If :new.RELACION <> :old.RELACION  Then

                  insert into GE_CTA_CLIENTES_CRM ( COD_PERSONA           ,
                                                    COD_MODULO            ,
                                                    COD_MODALIDAD         ,
                                                    NRO_CUENTA            ,
                                                    RELACION              ,
                                                    TIP_ACCION            )
                                             Values(:NEW.COD_PERSONA      ,
                                                    :OLD.COD_MODULO       ,
                                                    :OLD.COD_MODALIDAD    ,
                                                    :NEW.NRO_CUENTA       ,
                                                    DECODE(:OLD.RELACION,:NEW.RELACION,NULL,:NEW.RELACION),
                                                    'U'                   );
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into GE_CTA_CLIENTES_CRM ( COD_PERSONA           ,
                                                NRO_CUENTA            ,
                                                TIP_ACCION            )
                                         Values(:OLD.COD_PERSONA      ,
                                                :OLD.NRO_CUENTA       ,
                                                'D'                   );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_GE_CTA_CLIENTES',v_lugar||' : '||SQLERRM);
END;
/

