CREATE OR REPLACE TRIGGER IT.CA_AH_CTA_VISTAS
 AFTER DELETE OR INSERT OR UPDATE
 ON AH_CTA_VISTAS
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Updating and :new.estado = 'N' and :old.estado <> 'N' Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into AH_CTA_VISTAS_CRM(NRO_CUENTA       ,
                                            COD_MODULO       ,
                                            COD_MODALIDAD    ,
                                            COD_MONEDA       ,
                                            COD_OFICINA      ,
                                            FEC_APERTURA     ,
                                            DENOMINACION     ,
                                            ESTADO           ,
                                            FEC_CAM_ESTADO   ,
                                            TAS_PERSONALIZADA,
                                            TIP_ACCION       )
                                    Values( :NEW.NRO_CUENTA       ,
                                            :NEW.COD_MODULO       ,
                                            :NEW.COD_MODALIDAD    ,
                                            :NEW.COD_MONEDA       ,
                                            :NEW.COD_OFICINA      ,
                                            :NEW.FEC_APERTURA     ,
                                            :NEW.DENOMINACION     ,
                                            :NEW.ESTADO           ,
                                            :NEW.FEC_CAM_ESTADO   ,
                                            :NEW.TAS_PERSONALIZADA,
                                            'I'                   );

        ElsIf Updating and :new.estado not in ('N','A') Then
              v_lugar := 'Actualizando Registro';
              If nvl(:new.cod_oficina,1)            <> nvl(:old.cod_oficina,1)
                 or nvl(:new.estado,'X')            <> nvl(:old.estado,'X')
                 or nvl(:new.tas_personalizada,'T') <> nvl(:old.tas_personalizada,'T') Then
                  insert into AH_CTA_VISTAS_CRM(NRO_CUENTA       ,
                                                COD_OFICINA      ,
                                                ESTADO           ,
                                                TAS_PERSONALIZADA,
                                                TIP_ACCION       )
                                        Values( :NEW.NRO_CUENTA  ,
                                                DECODE(nvl(:NEW.COD_OFICINA,1),NVL(:OLD.COD_OFICINA,1),NULL,:NEW.COD_OFICINA),
                                                DECODE(nvl(:NEW.ESTADO,'X'),NVL(:OLD.ESTADO,'X'),NULL,:NEW.ESTADO),
                                                DECODE(nvl(:NEW.TAS_PERSONALIZADA,'T'),NVL(:OLD.TAS_PERSONALIZADA,'T'),NULL,:NEW.TAS_PERSONALIZADA),
                                                'U'              );
              End If;

        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into AH_CTA_VISTAS_CRM(NRO_CUENTA               ,
                                            TIP_ACCION               )
                                    Values( :OLD.NRO_CUENTA          ,
                                            'D'                      );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_AH_CTA_VISTAS',v_lugar||' : '||SQLERRM);
END;
/

