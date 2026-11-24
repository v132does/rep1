CREATE OR REPLACE TRIGGER IT.CA_PR_SOLICITUDES
 AFTER DELETE OR INSERT OR UPDATE
 ON PR_SOLICITUDES
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into PR_SOLICITUDES_CRM(NRO_SOLICITUD       ,
                                             DESCRIPCION         ,
                                             DIA_PLAZO           ,
                                             FEC_VENCIMIENTO     ,
                                             COD_PERSONA         ,
                                             FEC_INICIO          ,
                                             TIP_MONTO           ,
                                             ESTADO              ,
                                             COD_MONEDA          ,
                                             COD_OFICINA         ,
                                             TOT_DESEMBOLSAR     ,
                                             TIP_ACCION          )
                                     Values( :NEW.NRO_SOLICITUD  ,
                                             :NEW.DESCRIPCION    ,
                                             :NEW.DIA_PLAZO      ,
                                             :NEW.FEC_VENCIMIENTO,
                                             :NEW.COD_PERSONA    ,
                                             :NEW.FEC_INICIO     ,
                                             :NEW.TIP_MONTO      ,
                                             :NEW.ESTADO         ,
                                             :NEW.COD_MONEDA     ,
                                             :NEW.COD_OFICINA    ,
                                             :NEW.TOT_DESEMBOLSAR,
                                             'I'                 );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If nvl(:new.estado,'X') <> nvl(:old.estado,'X') Then
                  insert into PR_SOLICITUDES_CRM(NRO_SOLICITUD            ,
                                                 ESTADO                   ,
                                                 TOT_DESEMBOLSAR          ,
                                                 TIP_ACCION               )
                                         Values( :NEW.NRO_SOLICITUD       ,
                                                 :NEW.ESTADO              ,
                                                 decode(nvl(:NEW.TOT_DESEMBOLSAR,0),nvl(:old.tot_desembolsar,0),null,nvl(:NEW.TOT_DESEMBOLSAR,0)),
                                                 'U'                      );
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into PR_SOLICITUDES_CRM(NRO_SOLICITUD            ,
                                             TIP_ACCION               )
                                     Values( :OLD.NRO_SOLICITUD       ,
                                             'D'                      );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_PR_SOLICITUDES',v_lugar||' : '||SQLERRM);
END;
/

