CREATE OR REPLACE TRIGGER IT."CA_BA_DIRECCIONES"
 AFTER DELETE OR INSERT OR UPDATE
 ON BA_DIRECCIONES
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into BA_DIRECCIONES_CRM (COD_PERSONA          ,
                                              COD_DIRECCION        ,
                                              TIPO                 ,
                                              PRINCIPAL            ,
                                              DIRECCION            ,
                                              COD_PAIS             ,
                                              COD_CIUDAD           ,
                                              COD_BARRIO           ,
                                              OBSERVACION          ,
                                              NUMERO               ,
                                              DEPARTAMENTO         ,
                                              PISO                 ,
                                              EDIFICIO             ,
                                              COD_POSTAL           ,
                          DIR_LATERAL		   ,
                                              TIP_ACCION           )
                                       Values(:NEW.COD_PERSONA     ,
                                              :NEW.COD_DIRECCION   ,
                                              :NEW.TIPO            ,
                                              :NEW.PRINCIPAL       ,
                                              :NEW.DIRECCION       ,
                                              :NEW.COD_PAIS        ,
                                              :NEW.COD_CIUDAD      ,
                                              :NEW.COD_BARRIO      ,
                                              :NEW.OBSERVACION     ,
                                              :NEW.NUMERO          ,
                                              :NEW.DEPARTAMENTO    ,
                                              :NEW.PISO            ,
                                              :NEW.EDIFICIO        ,
                                              :NEW.COD_POSTAL      ,
                          :NEW.DIR_LATERAL	   ,
                                              'I'                  );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If :new.PRINCIPAL     <> :old.PRINCIPAL     Or
                 :new.DIRECCION     <> :old.DIRECCION     Or
                 :new.COD_PAIS      <> :old.COD_PAIS      Or
                 :new.COD_CIUDAD    <> :old.COD_CIUDAD    Or
                 :new.COD_BARRIO    <> :old.COD_BARRIO    Or
                 :new.COD_DIRECCION <> :old.COD_DIRECCION Or
           :new.DIR_LATERAL	<> :old.DIR_LATERAL	  Then

                  insert into BA_DIRECCIONES_CRM (COD_PERSONA          ,
                                                  COD_DIRECCION        ,
                                                  PRINCIPAL            ,
                                                  DIRECCION            ,
                                                  COD_PAIS             ,
                                                  COD_CIUDAD           ,
                                                  COD_BARRIO           ,
                            DIR_LATERAL		   ,
                                                  TIP_ACCION           )
                                           Values(:NEW.COD_PERSONA     ,
                                                  :NEW.COD_DIRECCION   ,
                                                  decode(:OLD.PRINCIPAL  ,:NEW.PRINCIPAL  ,NULL,:NEW.PRINCIPAL  ),
                                                  decode(:OLD.DIRECCION  ,:NEW.DIRECCION  ,NULL,:NEW.DIRECCION  ),
                                                  decode(:OLD.COD_PAIS   ,:NEW.COD_PAIS   ,NULL,:NEW.COD_PAIS   ),
                                                  decode(:OLD.COD_CIUDAD ,:NEW.COD_CIUDAD ,NULL,:NEW.COD_CIUDAD ),
                                                  decode(:OLD.COD_BARRIO ,:NEW.COD_BARRIO ,NULL,:NEW.COD_BARRIO ),
                            decode(:OLD.DIR_LATERAL,:NEW.DIR_LATERAL,NULL,:NEW.DIR_LATERAL),
                                                  'U'                   );
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into BA_DIRECCIONES_CRM (COD_PERSONA          ,
                                              COD_DIRECCION        ,
                                              TIP_ACCION           )
                                       Values(:OLD.COD_PERSONA     ,
                                              :OLD.COD_DIRECCION   ,
                                              'D'                  );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_BA_DIRECCIONES',v_lugar||' : '||SQLERRM);
END;
/

