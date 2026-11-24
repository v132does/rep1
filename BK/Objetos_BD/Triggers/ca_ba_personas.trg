CREATE OR REPLACE TRIGGER IT."CA_BA_PERSONAS"
 AFTER DELETE OR INSERT OR UPDATE
 ON BA_PERSONAS
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into BA_PERSONAS_CRM ( COD_PERSONA              ,
                                            NOM_COMPLETO             ,
                                            COD_TIP_DOCUMENTO        ,
                                            NRO_DOCUMENTO            ,
                                            COD_PAIS                 ,
                        TIPO                     ,
                                            TIP_ACCION               )
                                    Values( :NEW.COD_PERSONA         ,
                                            :NEW.NOM_COMPLETO        ,
                                            :NEW.COD_TIP_DOCUMENTO   ,
                                            :NEW.NRO_DOCUMENTO       ,
                                            :NEW.COD_PAIS            ,
                        :NEW.TIPO                ,
                                            'I'                      );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              /*Al crear una persona en ERREPERS primero inserta el registro y el NOM_COMPLETO en nulo, posterior al insert
                hace un Update del campo, motivo por el cual viajaría al CRM dos registros por cada alta. Se ajusta este
                disparador previendo esos casos*/
              If nvl(:old.NOM_COMPLETO,'X') <> 'X' Then -- Si no es Nulo es una actualización de una persona ya existente
                  If nvl(:new.NOM_COMPLETO,'X') <> nvl(:old.NOM_COMPLETO,'X') Or
                     :new.NRO_DOCUMENTO         <> :old.NRO_DOCUMENTO     Or
                     :new.COD_TIP_DOCUMENTO     <> :old.COD_TIP_DOCUMENTO Or
                     :new.COD_PAIS              <> :old.COD_PAIS          Then
                      insert into BA_PERSONAS_CRM ( COD_PERSONA              ,
                                                    NOM_COMPLETO             ,
                                                    COD_TIP_DOCUMENTO        ,
                                                    NRO_DOCUMENTO            ,
                                                    COD_PAIS                 ,
                                                    TIP_ACCION               )
                                            Values( :NEW.COD_PERSONA         ,
                                                    DECODE(:OLD.NOM_COMPLETO     ,:NEW.NOM_COMPLETO     ,NULL,:NEW.NOM_COMPLETO),
                                                    DECODE(:OLD.COD_TIP_DOCUMENTO,:NEW.COD_TIP_DOCUMENTO,NULL,:NEW.COD_TIP_DOCUMENTO),
                                                    DECODE(:OLD.NRO_DOCUMENTO    ,:NEW.NRO_DOCUMENTO    ,NULL,:NEW.NRO_DOCUMENTO),
                                                    DECODE(:OLD.COD_PAIS         ,:NEW.COD_PAIS         ,NULL,:NEW.COD_PAIS),
                                                    'U'                      );
                  End If;
               Else
                  Update ba_personas_crm a 
                     set a.nom_completo = :NEW.NOM_COMPLETO
                   where a.cod_persona  = :NEW.COD_PERSONA
                     and a.tip_accion   = 'I';
               End IF;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into BA_PERSONAS_CRM ( COD_PERSONA              ,
                                            TIP_ACCION               )
                                    Values( :OLD.COD_PERSONA         ,
                                            'D'                      );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_BA_PERSONAS',v_lugar||' : '||SQLERRM);
END;
/

