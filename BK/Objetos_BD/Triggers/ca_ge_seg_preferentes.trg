CREATE OR REPLACE TRIGGER IT."CA_GE_SEG_PREFERENTES"
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_SEG_PREFERENTES
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into GE_SEG_PREFERENTES_CRM (COD_SEG_PREFERENTE     ,
                                                  DESCRIPCION            ,
                                                  RGB                    ,
                                                  FIN_NOM_ARCHIVO        ,
                                                  NOM_CAM_COLOR          ,
                                                  TIP_ACCION             )
                                           Values(:NEW.COD_SEG_PREFERENTE,
                                                  :NEW.DESCRIPCION       ,
                                                  :NEW.RGB               ,
                                                  :NEW.FIN_NOM_ARCHIVO   ,
                                                  :NEW.NOM_CAM_COLOR     ,
                                                  'I'                    );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If :new.DESCRIPCION   <> :old.DESCRIPCION Then

                  insert into GE_SEG_PREFERENTES_CRM (COD_SEG_PREFERENTE     ,
                                                      DESCRIPCION            ,
                                                      TIP_ACCION             )
                                               Values(:NEW.COD_SEG_PREFERENTE,
                                                      DECODE(:OLD.DESCRIPCION,:NEW.DESCRIPCION,NULL,:NEW.DESCRIPCION),
                                                      'U'                    );
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into GE_SEG_PREFERENTES_CRM (COD_SEG_PREFERENTE     ,
                                                  TIP_ACCION             )
                                           Values(:OLD.COD_SEG_PREFERENTE,
                                                  'D'                    );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_GE_SEG_PREFERENTES',v_lugar||' : '||SQLERRM);
END;
/

