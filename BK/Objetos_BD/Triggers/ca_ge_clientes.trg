CREATE OR REPLACE TRIGGER IT.CA_GE_CLIENTES
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_CLIENTES
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into GE_CLIENTES_CRM ( COD_PERSONA               ,
                                            COD_OFICINA               ,
                                            COD_SEG_PREFERENTE        ,
                                            COD_GRU_ECONOMICO         ,
                                            COD_USU_OFICIAL           ,
                                            TIP_ACCION                )
                                    Values( :NEW.COD_PERSONA          ,
                                            :NEW.COD_OFICINA          ,
                                            :NEW.COD_SEG_PREFERENTE   ,
                                            :NEW.COD_GRU_ECONOMICO    ,
                                            :NEW.COD_USU_OFICIAL      ,
                                            'I'                       );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If :new.COD_USU_OFICIAL   <> :old.COD_USU_OFICIAL   Or
                 :new.COD_OFICINA       <> :old.COD_OFICINA       Or
                 nvl(:new.COD_GRU_ECONOMICO,0) <> nvl(:old.COD_GRU_ECONOMICO,0) Or
                 nvl(:new.COD_SEG_PREFERENTE,0) <> nvl(:old.COD_SEG_PREFERENTE,0) Then

                  insert into GE_CLIENTES_CRM ( COD_PERSONA               ,
                                                COD_OFICINA               ,
                                                COD_GRU_ECONOMICO         ,
                                                COD_SEG_PREFERENTE        ,
                                                COD_USU_OFICIAL           ,
                                                TIP_ACCION                )
                                        Values( :NEW.COD_PERSONA          ,
                                                DECODE(:OLD.COD_OFICINA      ,:NEW.COD_OFICINA      ,NULL,:NEW.COD_OFICINA),
                                                DECODE(:OLD.COD_GRU_ECONOMICO,:NEW.COD_GRU_ECONOMICO,NULL,:NEW.COD_GRU_ECONOMICO),
                                                DECODE(:OLD.COD_SEG_PREFERENTE,:NEW.COD_SEG_PREFERENTE,NULL,:NEW.COD_SEG_PREFERENTE),
                                                DECODE(:OLD.COD_USU_OFICIAL  ,:NEW.COD_USU_OFICIAL  ,NULL,:NEW.COD_USU_OFICIAL),
                                                'U'                       );
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into GE_CLIENTES_CRM ( COD_PERSONA               ,
                                            TIP_ACCION                )
                                    Values( :OLD.COD_PERSONA          ,
                                            'D'                    );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_GE_CLIENTES',v_lugar||' : '||SQLERRM);
END;
/

