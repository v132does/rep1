CREATE OR REPLACE TRIGGER IT.TB_CC_CHE_RECHAZADOS_TMP
BEFORE INSERT ON CC_CHE_RECHAZADOS_TMP
FOR EACH ROW

DECLARE

BEGIN

  --:NEW.NRO_CUENTA := FUC_OBT_CTA_REMITIDOS(:NEW.NRO_CUENTA); se asigna la cuenta en el proceso prc_act_che_rch_camara
  null;  

EXCEPTION
   WHEN OTHERS THEN
     IF SQLCODE < -20000  THEN
         RAISE;
     ELSE
        raise_application_error(-20000,'Error en Trigger TB_CC_CHE_RECHAZADOS_TMP : ' || sqlerrm);
     END IF;
END;
/

