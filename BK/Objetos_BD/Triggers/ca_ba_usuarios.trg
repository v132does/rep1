CREATE OR REPLACE TRIGGER IT."CA_BA_USUARIOS"
 AFTER DELETE OR INSERT OR UPDATE
 ON BA_USUARIOS
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into BA_USUARIOS_CRM ( COD_USUARIO              ,
                                            COD_OFICINA              ,
                                            COD_AREA                 ,
                                            CATEGORIA                ,
                                            OFICIAL                  ,
                                            CARGO                    ,
                                            DIR_CORREO               ,
                                            COD_USU_SUPERVISOR       ,
                                            TIP_ACCION)
                                    Values( :NEW.COD_USUARIO         ,
                                            :NEW.COD_OFICINA         ,
                                            :NEW.COD_AREA            ,
                                            :NEW.CATEGORIA           ,
                                            :NEW.OFICIAL             ,
                                            :NEW.CARGO               ,
                                            :NEW.DIR_CORREO          ,
                                            :NEW.COD_USU_SUPERVISOR  ,
                                            'I'                      );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If :new.ESTADO             <> :old.ESTADO      or
                 :new.COD_OFICINA        <> :old.COD_OFICINA or
                 :new.COD_AREA           <> :old.COD_AREA    or
                 :new.CATEGORIA          <> :old.CATEGORIA   or
                 :new.OFICIAL            <> :old.OFICIAL     or
                 :new.DIR_CORREO         <> :old.DIR_CORREO  or
                 :NEW.CARGO              <> :old.CARGO       or
                 :new.COD_USU_SUPERVISOR <> :old.COD_USU_SUPERVISOR Then
                 
                  insert into BA_USUARIOS_CRM ( COD_USUARIO              ,
                                                COD_OFICINA              ,
                                                COD_AREA                 ,
                                                CATEGORIA                ,
                                                OFICIAL                  ,
                                                DIR_CORREO               ,
                                                CARGO                    ,
                                                COD_USU_SUPERVISOR       ,
                                                TIP_ACCION               )
                                        Values( :NEW.COD_USUARIO         ,
                                                decode(:OLD.COD_OFICINA  , :NEW.COD_OFICINA,NULL,:NEW.COD_OFICINA),
                                                decode(:OLD.COD_AREA     , :NEW.COD_AREA   ,NULL,:NEW.COD_AREA   ),
                                                decode(:OLD.CATEGORIA    , :NEW.CATEGORIA  ,NULL,:NEW.CATEGORIA  ),
                                                decode(:OLD.OFICIAL      , :NEW.OFICIAL    ,NULL,:NEW.OFICIAL    ),
                                                decode(:OLD.DIR_CORREO   , :NEW.DIR_CORREO ,NULL,:NEW.DIR_CORREO ),
                                                decode(:OLD.CARGO        , :NEW.CARGO      ,NULL,:NEW.CARGO      ),
                                                decode(:OLD.COD_USU_SUPERVISOR,:NEW.COD_USU_SUPERVISOR,NULL,:NEW.COD_USU_SUPERVISOR),
                                                'U'                      );
              End IF;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into BA_USUARIOS_CRM ( COD_USUARIO              ,
                                            TIP_ACCION               )
                                    Values( :OLD.COD_USUARIO         ,
                                            'D'                      );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_BA_USUARIOS',v_lugar||' : '||SQLERRM);
END;
/

