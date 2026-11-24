CREATE OR REPLACE TRIGGER IT."CA_GE_COTIZACIONES"
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_COTIZACIONES
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into GE_COTIZACIONES_CRM ( COD_MONEDA                ,
                                                FECHA                     ,
                                                VAL_CONVERSION            ,
                                                VAL_COMPRA                ,
                                                VAL_VENTA                 ,
                                                VAL_VEN_CHEQUE            ,
                                                VAL_COM_CHEQUE            ,
                                                VAL_COM_ELECTRONICA       ,
                                                VAL_VEN_ELECTRONICA       ,
                                                VAL_COM_INTERBANCARIA     ,
                                                VAL_VEN_INTERBANCARIA     ,
                                                TIP_ACCION                )
                                        Values( :NEW.COD_MONEDA           ,
                                                :NEW.FECHA                ,
                                                :NEW.VAL_CONVERSION       ,
                                                :NEW.VAL_COMPRA           ,
                                                :NEW.VAL_VENTA            ,
                                                :NEW.VAL_VEN_CHEQUE       ,
                                                :NEW.VAL_COM_CHEQUE       ,
                                                :NEW.VAL_COM_ELECTRONICA  ,
                                                :NEW.VAL_VEN_ELECTRONICA  ,
                                                :NEW.VAL_COM_INTERBANCARIA,
                                                :NEW.VAL_VEN_INTERBANCARIA,
                                                 'I'                      );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If :new.val_conversion      <> :old.val_conversion      Or
                 :new.val_compra          <> :old.val_compra          Or
                 :new.val_venta           <> :old.val_venta           Or
                 :new.val_ven_cheque      <> :old.val_ven_cheque      Or
                 :new.val_com_cheque      <> :old.val_com_cheque      Or
                 :new.val_com_electronica <> :old.val_com_electronica Or
                 :new.val_ven_electronica <> :old.val_ven_electronica Then
                 
                  insert into GE_COTIZACIONES_CRM (COD_MONEDA                ,
                                                   FECHA                     ,
                                                   VAL_CONVERSION            ,
                                                   VAL_COMPRA                ,
                                                   VAL_VENTA                 ,
                                                   VAL_VEN_CHEQUE            ,
                                                   VAL_COM_CHEQUE            ,
                                                   VAL_COM_ELECTRONICA       ,
                                                   VAL_VEN_ELECTRONICA       ,
                                                   TIP_ACCION                )
                                           Values( :NEW.COD_MONEDA           ,
                                                   :OLD.FECHA                ,
                                                   decode(:OLD.VAL_CONVERSION     , :NEW.VAL_CONVERSION     , NULL, :NEW.VAL_CONVERSION),
                                                   decode(:OLD.VAL_COMPRA         , :NEW.VAL_COMPRA         , NULL, :NEW.VAL_COMPRA    ),
                                                   decode(:OLD.VAL_VENTA          , :NEW.VAL_VENTA          , NULL, :NEW.VAL_VENTA     ),
                                                   decode(:OLD.VAL_VEN_CHEQUE     , :NEW.VAL_VEN_CHEQUE     , NULL, :NEW.VAL_VEN_CHEQUE),
                                                   decode(:OLD.VAL_COM_CHEQUE     , :NEW.VAL_COM_CHEQUE     , NULL, :NEW.VAL_COM_CHEQUE),
                                                   decode(:OLD.VAL_COM_ELECTRONICA, :NEW.VAL_COM_ELECTRONICA, NULL, :NEW.VAL_COM_ELECTRONICA),
                                                   decode(:OLD.VAL_VEN_ELECTRONICA, :NEW.VAL_VEN_ELECTRONICA, NULL, :NEW.VAL_VEN_ELECTRONICA),
                                                   'U'                       );
              End If;
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_GE_COTIZACIONES',v_lugar||' : '||SQLERRM);
END;
/

