CREATE OR REPLACE TRIGGER IT.CA_AH_CTA_CERTIFICADOS
 AFTER DELETE OR INSERT OR UPDATE
 ON AH_CTA_CERTIFICADOS
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Updating and :new.estado = 'N' and :old.estado <> 'N'  Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into AH_CTA_CERTIFICADOS_CRM( NRO_CUENTA,
                                                   COD_MODULO,
                                                   COD_MODALIDAD,
                                                   COD_MONEDA,
                                                   COD_OFICINA,
                                                   FEC_APERTURA,
                                                   DENOMINACION,
                                                   CAPITAL,
                                                   BENEFICIARIO,
                                                   BLOQUEADO,
                                                   ESTADO,
                                                   EST_CERTIFICADO,
                                                   FEC_CAM_ESTADO,
                                                   NRO_CERTIFICADO,
                                                   SERIE,
                                                   TAS_PERSONALIZADA,
                                                   TIP_ACCION               )
                                          Values( :NEW.NRO_CUENTA,
                                                  :NEW.COD_MODULO,
                                                  :NEW.COD_MODALIDAD,
                                                  :NEW.COD_MONEDA,
                                                  :NEW.COD_OFICINA,
                                                  :NEW.FEC_APERTURA,
                                                  :NEW.DENOMINACION,
                                                  :NEW.CAPITAL,
                                                  :NEW.BENEFICIARIO,
                                                  :NEW.BLOQUEADO,
                                                  :NEW.ESTADO,
                                                  :NEW.EST_CERTIFICADO,
                                                  :NEW.FEC_CAM_ESTADO,
                                                  :NEW.NRO_CERTIFICADO,
                                                  :NEW.SERIE,
                                                  :NEW.TAS_PERSONALIZADA,
                                                  'I'                      );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              if nvl(:new.cod_oficina,1)         <> nvl(:old.cod_oficina,1)
                or nvl(:new.beneficiario,'1')    <> nvl(:old.beneficiario,'1')
                or nvl(:new.estado,'W')          <> nvl(:old.estado,'W')
                or nvl(:new.est_certificado,'Z') <> nvl(:old.est_certificado,'Z')
                or nvl(:new.bloqueado,'X')       <> nvl(:old.bloqueado,'X') Then
                  insert into AH_CTA_CERTIFICADOS_CRM(NRO_CUENTA     ,
                                                      COD_OFICINA    ,
                                                      BENEFICIARIO   ,
                                                      ESTADO         ,
                                                      EST_CERTIFICADO,
                                                      BLOQUEADO      ,
                                                      TIP_ACCION     )
                                              Values( :NEW.NRO_CUENTA,
                                                      DECODE(NVL(:NEW.COD_OFICINA,'1'),NVL(:OLD.COD_OFICINA,'1'),NULL,:NEW.COD_OFICINA),
                                                      DECODE(NVL(:NEW.BENEFICIARIO,'1'),NVL(:OLD.BENEFICIARIO,'1'),NULL,:NEW.BENEFICIARIO),
                                                      DECODE(NVL(:NEW.ESTADO,'W'),NVL(:OLD.ESTADO,'W'),NULL,:NEW.ESTADO),
                                                      DECODE(NVL(:NEW.EST_CERTIFICADO,'Z'),NVL(:OLD.EST_CERTIFICADO,'Z'), NULL, :OLD.EST_CERTIFICADO),
                                                      DECODE(NVL(:NEW.BLOQUEADO,'X'),NVL(:OLD.BLOQUEADO,'X'),NULL,:NEW.BLOQUEADO),
                                                      'U');
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into AH_CTA_CERTIFICADOS_CRM(NRO_CUENTA               ,
                                                  TIP_ACCION               )
                                          Values( :OLD.NRO_CUENTA          ,
                                                  'D'                      );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_AH_CTA_CERTIFICADOS',v_lugar||' : '||SQLERRM);
END;
/

