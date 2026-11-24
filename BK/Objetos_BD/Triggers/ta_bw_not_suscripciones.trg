CREATE OR REPLACE TRIGGER IT.TA_BW_NOT_SUSCRIPCIONES
 AFTER DELETE OR INSERT OR UPDATE
 ON BW_NOT_SUSCRIPCIONES
 FOR EACH ROW

DECLARE
   v_evento NUMBER(3);

BEGIN
   IF inserting OR updating then
      v_evento := paw_not.fu_not_env_evento(:new.cod_persona, 'NOTCAMBIO', 'NOTCAMBIO');
   END IF;
END;
/

