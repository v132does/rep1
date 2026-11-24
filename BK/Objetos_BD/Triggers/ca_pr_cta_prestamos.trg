CREATE OR REPLACE TRIGGER IT.CA_PR_CTA_PRESTAMOS
 AFTER DELETE OR INSERT OR UPDATE
 ON PR_CTA_PRESTAMOS
 FOR EACH ROW
DECLARE
   v_lugar    varchar2(500);
   v_programa varchar2(200) := nvl(pae_cnf.G_PROGRAMA,'X');
BEGIN
    If NVL(INSTR(FUG_OBT_PARDINAMICO('CRM_PAN_EXLUIDAS'), V_PROGRAMA),0) = 0 Then
        If    Inserting Then
              v_lugar := 'Insertando Nuevo Registro';
              insert into PR_CTA_PRESTAMOS_CRM(NRO_CUENTA        ,
                                               COD_MODULO        ,
                                               COD_MODALIDAD     ,
                                               COD_OFICINA       ,
                                               NRO_CTA_DEBITO    ,
                                               FEC_CANCELACION   ,
                                               NRO_SOLICITUD     ,
                                               ESTADO            ,
                                               COB_AUTOMATICO    ,
                                               FEC_INICIO        ,
                                               FEC_VENCIMIENTO   ,
                                               VAL_TASA          ,
                                               CAN_CUOTAS        ,
                                               CAN_CUO_PAGADAS   ,
                                               DESCRIPCION       ,
                                               TIP_RENOVACION    ,
                                               TIP_ACCION        )
                                       Values( :NEW.NRO_CUENTA        ,
                                               :NEW.COD_MODULO        ,
                                               :NEW.COD_MODALIDAD     ,
                                               :NEW.COD_OFICINA       ,
                                               :NEW.NRO_CTA_DEBITO    ,
                                               :NEW.FEC_CANCELACION   ,
                                               :NEW.NRO_SOLICITUD     ,
                                               :NEW.ESTADO            ,
                                               :NEW.COB_AUTOMATICO    ,
                                               :NEW.FEC_INICIO        ,
                                               :NEW.FEC_VENCIMIENTO   ,
                                               :NEW.VAL_TASA          ,
                                               :NEW.CAN_CUOTAS        ,
                                               :NEW.CAN_CUO_PAGADAS   ,
                                               :NEW.DESCRIPCION       ,
                                               :NEW.TIP_RENOVACION    ,
                                               'I'                    );

        ElsIf Updating  Then
              v_lugar := 'Actualizando Registro';
              If nvl(:new.cod_oficina,0)          <> nvl(:old.cod_oficina,0)
                  or nvl(:new.nro_cta_debito,0)   <> nvl(:old.nro_cta_debito,0)
                  or nvl(:new.cob_automatico,'X') <> nvl(:old.cob_automatico,'X')
                  or nvl(:new.estado,'X')         <> nvl(:old.estado,'X')
                  or nvl(:new.fec_cancelacion,'01/01/2017')  <> nvl(:old.fec_cancelacion,'01/01/2017')
                  or nvl(:new.can_cuo_pagadas,0)  <> nvl(:old.can_cuo_pagadas,0)
                  or nvl(:new.tip_renovacion,'X') <> nvl(:old.tip_renovacion,'X') Then
              insert into PR_CTA_PRESTAMOS_CRM(NRO_CUENTA        ,
                                               COD_OFICINA       ,
                                               NRO_CTA_DEBITO    ,
                                               FEC_CANCELACION   ,
                                               ESTADO            ,
                                               COB_AUTOMATICO    ,
                                               CAN_CUO_PAGADAS   ,
                                               TIP_RENOVACION    ,
                                               TIP_ACCION        )
                                       Values( :NEW.NRO_CUENTA          ,
                                               decode(nvl(:new.cod_oficina,0),nvl(:old.cod_oficina,0),null,:new.cod_oficina),
                                               decode(nvl(:new.nro_cta_debito,0),nvl(:old.nro_cta_debito,0),null,:new.nro_cta_debito),
                                               decode(nvl(:new.cob_automatico,'X'),nvl(:old.cob_automatico,'X'),null,:new.cob_automatico),
                                               decode(nvl(:new.estado,'X'),nvl(:old.estado,'X'),null,:new.estado),
                                               decode(nvl(:new.fec_cancelacion,'01/01/2017'),nvl(:old.fec_cancelacion,'01/01/2017'),null,:new.fec_cancelacion),
                                               decode(nvl(:new.can_cuo_pagadas,0),nvl(:old.can_cuo_pagadas,0),null,:new.can_cuo_pagadas),
                                               decode(nvl(:new.tip_renovacion,'X'),nvl(:old.tip_renovacion,'X'),null,:new.tip_renovacion),
                                               'U'                      );
              End If;
        ElsIf Deleting  Then
              v_lugar := 'Borrando Registro';
              insert into PR_CTA_PRESTAMOS_CRM(NRO_CUENTA               ,
                                               TIP_ACCION               )
                                       Values( :OLD.NRO_CUENTA          ,
                                               'D'                      );
        End If;
    End If;
EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('CA_PR_CTA_PRESTAMOS',v_lugar||' : '||SQLERRM);
END;
/

