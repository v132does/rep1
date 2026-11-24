CREATE OR REPLACE TRIGGER IT.CA_CC_CTA_CORRIENTES
 AFTER DELETE OR INSERT OR UPDATE
 ON CC_CTA_CORRIENTES
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Updating and :new.estado = 'N' and :old.estado <> 'N' Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into CC_CTA_CORRIENTES_CRM(NRO_CUENTA       ,
                                                COD_MODULO       ,
                                                COD_MODALIDAD    ,
                                                COD_OFICINA      ,
                                                DENOMINACION     ,
                                                FEC_APERTURA     ,
                                                TAS_PERSONALIZADA,
                                                CTA_COMBINADA    ,
                                                TRA_PROHIBIDA    ,
                                                ESTADO           ,
                                                NOM_CHEQUERA     ,
                                                FRE_EXTRACTO     ,
                                                TIP_ACCION       )
                                        Values( :NEW.NRO_CUENTA       ,
                                                :NEW.COD_MODULO       ,
                                                :NEW.COD_MODALIDAD    ,
                                                :NEW.COD_OFICINA      ,
                                                :NEW.DENOMINACION     ,
                                                :NEW.FEC_APERTURA     ,
                                                :NEW.TAS_PERSONALIZADA,
                                                :NEW.CTA_COMBINADA    ,
                                                :NEW.TRA_PROHIBIDA    ,
                                                :NEW.ESTADO           ,
                                                :NEW.NOM_CHEQUERA     ,
                                                :NEW.FRE_EXTRACTO     ,
                                                'I'                   );

        ElsIf Updating and :new.estado not in ('N','A') Then
              v_lugar := 'Actualizando Registro';
              If nvl(:new.cod_oficina,0) <> nvl(:old.cod_oficina,0)
                 or nvl(:new.tas_personalizada,'X') <> nvl(:old.tas_personalizada,'X')
                 or nvl(:new.cta_combinada,'X')     <> nvl(:old.cta_combinada,'X')
                 or nvl(:new.tra_prohibida,'X')     <> nvl(:old.tra_prohibida,'X')
                 or nvl(:new.estado,'X')            <> nvl(:old.estado,'X')
                 or nvl(:new.fre_extracto,'Z')      <> nvl(:old.fre_extracto,'Z') Then
                  insert into CC_CTA_CORRIENTES_CRM(NRO_CUENTA               ,
                                                    COD_OFICINA              ,
                                                    TAS_PERSONALIZADA        ,
                                                    CTA_COMBINADA            ,
                                                    TRA_PROHIBIDA            ,
                                                    ESTADO                   ,
                                                    FRE_EXTRACTO             ,
                                                    TIP_ACCION               )
                                            Values( :NEW.NRO_CUENTA          ,
                                                    DECODE(nvl(:new.cod_oficina,0),nvl(:old.cod_oficina,0),NULL,:NEW.COD_OFICINA),
                                                    DECODE(nvl(:new.tas_personalizada,'X'),nvl(:old.tas_personalizada,'X'),NULL,:NEW.TAS_PERSONALIZADA),
                                                    DECODE(nvl(:new.cta_combinada,'X'),nvl(:old.cta_combinada,'X'),NULL,:NEW.CTA_COMBINADA),
                                                    DECODE(nvl(:new.tra_prohibida,'X'),nvl(:old.tra_prohibida,'X'),NULL,:NEW.TRA_PROHIBIDA),
                                                    DECODE(nvl(:new.estado,'X'),nvl(:old.estado,'X'),NULL,:NEW.ESTADO),
                                                    DECODE(nvl(:new.fre_extracto,'Z'),nvl(:old.fre_extracto,'Z'),NULL,:new.fre_extracto),
                                                    'U'                      );
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into CC_CTA_CORRIENTES_CRM(NRO_CUENTA               ,
                                                TIP_ACCION               )
                                        Values( :OLD.NRO_CUENTA          ,
                                                'D'                      );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_CC_CTA_CORRIENTES',v_lugar||' : '||SQLERRM);
END;
/

