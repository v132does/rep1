CREATE OR REPLACE TRIGGER IT.CA_BA_PER_FISICAS
 AFTER DELETE OR INSERT OR UPDATE
 ON BA_PER_FISICAS
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into BA_PER_FISICAS_CRM (COD_PERSONA          ,
                                              PRI_NOMBRE           ,
                                              PRI_APELLIDO         ,
                                              SEG_NOMBRE           ,
                                              SEG_APELLIDO         ,
                                              FEC_NACIMIENTO       ,
                                              EST_CIVIL            ,
                                              TIP_ACCION           )
                                       Values(:NEW.COD_PERSONA     ,
                                              :NEW.PRI_NOMBRE      ,
                                              :NEW.PRI_APELLIDO    ,
                                              :NEW.SEG_NOMBRE      ,
                                              :NEW.SEG_APELLIDO    ,
                                              :NEW.FEC_NACIMIENTO  ,
                                              :NEW.EST_CIVIL       ,
                                              'I'                  );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If :new.PRI_NOMBRE     <> :old.PRI_NOMBRE   Or
                 :new.SEG_NOMBRE     <> :old.SEG_NOMBRE   Or
                 :new.PRI_APELLIDO   <> :old.PRI_APELLIDO Or
                 :new.SEG_APELLIDO   <> :old.SEG_APELLIDO Or
                 :new.fec_nacimiento <> :old.fec_nacimiento Or
                 :new.est_civil      <> :old.est_civil      Then

                  insert into BA_PER_FISICAS_CRM (COD_PERSONA          ,
                                                  PRI_NOMBRE           ,
                                                  PRI_APELLIDO         ,
                                                  SEG_NOMBRE           ,
                                                  SEG_APELLIDO         ,
                                                  FEC_NACIMIENTO       ,
                                                  EST_CIVIL            ,
                                                  TIP_ACCION           )
                                           Values(:NEW.COD_PERSONA     ,
                                                  DECODE(:OLD.PRI_NOMBRE    ,:NEW.PRI_NOMBRE    ,NULL,:NEW.PRI_NOMBRE),
                                                  DECODE(:OLD.PRI_APELLIDO  ,:NEW.PRI_APELLIDO  ,NULL,:NEW.PRI_APELLIDO),
                                                  DECODE(:OLD.SEG_NOMBRE    ,:NEW.SEG_NOMBRE    ,NULL,:NEW.SEG_NOMBRE),
                                                  DECODE(:OLD.SEG_APELLIDO  ,:NEW.SEG_APELLIDO  ,NULL,:NEW.SEG_APELLIDO),
                                                  DECODE(:OLD.FEC_NACIMIENTO,:NEW.FEC_NACIMIENTO,NULL,:NEW.FEC_NACIMIENTO),
                                                  DECODE(:OLD.EST_CIVIL     ,:NEW.EST_CIVIL     ,NULL,:NEW.EST_CIVIL),
                                                  'U'                       );
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into BA_PER_FISICAS_CRM (COD_PERSONA            ,
                                              TIP_ACCION             )
                                       Values(:OLD.COD_PERSONA       ,
                                              'D'                    );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_BA_PER_FISICAS',v_lugar||' : '||SQLERRM);
END;
/

