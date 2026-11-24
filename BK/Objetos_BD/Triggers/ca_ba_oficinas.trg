CREATE OR REPLACE TRIGGER IT."CA_BA_OFICINAS"
 AFTER DELETE OR INSERT OR UPDATE
 ON BA_OFICINAS
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into BA_OFICINAS_CRM ( COD_OFICINA            ,
                                            DESCRIPCION            ,
                                            COD_CIUDAD             ,
                                            COD_PAIS               ,
                                            COD_OFI_CAMBIO         ,
                                            DIRECCION              ,
                                            TELEFONO               ,
                                            SIGLA                  ,
                                            COD_USU_ENCARGADO      ,
                                            COD_GRU_OFICINA        ,
                                            COD_OFI_CAMARA         ,
                                            ESTADO                 ,
                                            TIP_ACCION             )
                                    Values( :NEW.COD_OFICINA       ,
                                            :NEW.DESCRIPCION       ,
                                            :NEW.COD_CIUDAD        ,
                                            :NEW.COD_PAIS          ,
                                            :NEW.COD_OFI_CAMBIO    ,
                                            :NEW.DIRECCION         ,
                                            :NEW.TELEFONO          ,
                                            :NEW.SIGLA             ,
                                            :NEW.COD_USU_ENCARGADO ,
                                            :NEW.COD_GRU_OFICINA   ,
                                            :NEW.COD_OFI_CAMARA    ,
                                            :NEW.ESTADO            ,
                                            'I'                    );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If :new.cod_gru_oficina <> :old.cod_gru_oficina or :new.descripcion <> :old.descripcion Then
                  insert into BA_OFICINAS_CRM ( COD_OFICINA            ,
                                                DESCRIPCION            ,
                                                COD_GRU_OFICINA        ,
                                                TIP_ACCION             )
                                        Values( :NEW.COD_OFICINA       ,
                                                DECODE(:OLD.DESCRIPCION    ,:NEW.DESCRIPCION    ,NULL,:NEW.DESCRIPCION),
                                                DECODE(:OLD.COD_GRU_OFICINA,:NEW.COD_GRU_OFICINA,NULL,:NEW.COD_GRU_OFICINA),
                                                'U'                    );
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into BA_OFICINAS_CRM ( COD_OFICINA            ,
                                            TIP_ACCION             )
                                    Values( :OLD.COD_OFICINA       ,
                                            'D'                    );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_BA_OFICINAS',v_lugar||' : '||SQLERRM);
END;
/

