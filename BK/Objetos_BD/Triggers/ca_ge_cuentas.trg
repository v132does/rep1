CREATE OR REPLACE TRIGGER IT.CA_GE_CUENTAS
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_CUENTAS
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
       If inserting and :new.cod_modulo in (5,6) Then
           v_lugar := 'Insertando Nuevo Registro';
              insert into GE_CUENTAS_CRM (NRO_CUENTA            ,
                                          DENOMINACION          ,
                                          COD_MODULO            ,
                                          COD_MODALIDAD         ,
                                          ESTADO                ,
                                          FEC_CAM_ESTADO        ,
                                          FEC_APERTURA          ,
                                          FEC_VENCIMIENTO       ,
                                          OBS_VERIFICACION      ,
                                          TIP_ACCION            )
                                   Values(:NEW.NRO_CUENTA       ,
                                          :NEW.DENOMINACION     ,
                                          :NEW.COD_MODULO       ,
                                          :NEW.COD_MODALIDAD    ,
                                          :NEW.ESTADO           ,
                                          :NEW.FEC_CAM_ESTADO   ,
                                          :NEW.FEC_APERTURA     ,
                                          :NEW.FEC_VENCIMIENTO  ,
                                          :NEW.OBS_VERIFICACION ,
                                          'I'                   );
       ElsIf    Updating and ((:new.cod_modulo in (3,4,5,7) and :new.estado = 'N' and :old.estado <> 'N')
                            or (:new.cod_modulo in (6,10) and :new.estado = 'C' and :old.estado <> 'C')
                            or (:new.cod_modulo in (8) and :new.estado = 'A' and :old.estado <> 'A')) Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into GE_CUENTAS_CRM (NRO_CUENTA            ,
                                          DENOMINACION          ,
                                          COD_MODULO            ,
                                          COD_MODALIDAD         ,
                                          ESTADO                ,
                                          FEC_CAM_ESTADO        ,
                                          FEC_APERTURA          ,
                                          FEC_VENCIMIENTO       ,
                                          OBS_VERIFICACION      ,
                                          TIP_ACCION            )
                                   Values(:NEW.NRO_CUENTA       ,
                                          :NEW.DENOMINACION     ,
                                          :NEW.COD_MODULO       ,
                                          :NEW.COD_MODALIDAD    ,
                                          :NEW.ESTADO           ,
                                          :NEW.FEC_CAM_ESTADO   ,
                                          :NEW.FEC_APERTURA     ,
                                          :NEW.FEC_VENCIMIENTO  ,
                                          :NEW.OBS_VERIFICACION ,
                                          'I'                   );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If :new.FEC_APERTURA     <> :old.FEC_APERTURA    Or
                 :new.FEC_CAM_ESTADO   <> :old.FEC_CAM_ESTADO  Or
                 :new.FEC_VENCIMIENTO  <> :old.FEC_VENCIMIENTO Or
                 nvl(:new.ESTADO,'W')  <> nvl(:old.ESTADO,'W') Then

                 IF :new.FEC_CAM_ESTADO is not null and nvl(:new.ESTADO,'W') <> nvl(:old.ESTADO,'W') Then
                    insert into GE_CUENTAS_CRM (NRO_CUENTA            ,
                                                COD_MODULO            ,
                                                COD_MODALIDAD         ,
                                                ESTADO                ,
                                                FEC_CAM_ESTADO        ,
                                                FEC_APERTURA          ,
                                                FEC_VENCIMIENTO       ,
                                                OBS_VERIFICACION      ,
                                                TIP_ACCION            )
                                         Values(:NEW.NRO_CUENTA       ,
                                                :OLD.COD_MODULO       ,
                                                :OLD.COD_MODALIDAD    ,
                                                DECODE(nvl(:OLD.ESTADO,'W'),nvl(:NEW.ESTADO,'W'),NULL,:NEW.ESTADO),
                                                DECODE(:OLD.FEC_CAM_ESTADO ,:NEW.FEC_CAM_ESTADO ,NULL,:NEW.FEC_CAM_ESTADO),
                                                DECODE(:OLD.FEC_APERTURA   ,:NEW.FEC_APERTURA   ,NULL,:NEW.FEC_APERTURA),
                                                DECODE(:OLD.FEC_VENCIMIENTO,:NEW.FEC_VENCIMIENTO,NULL,:NEW.FEC_VENCIMIENTO),
                                                :NEW.OBS_VERIFICACION ,
                                                'U'                   );
                 End If;
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into GE_CUENTAS_CRM (NRO_CUENTA            ,
                                          TIP_ACCION            )
                                   Values(:OLD.NRO_CUENTA       ,
                                          'D'                   );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_GE_CUENTAS',v_lugar||' : '||SQLERRM);
END;
/

