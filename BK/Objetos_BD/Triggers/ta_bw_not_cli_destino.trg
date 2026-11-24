CREATE OR REPLACE TRIGGER IT.TA_BW_NOT_CLI_DESTINO
AFTER DELETE OR INSERT OR UPDATE
 ON BW_NOT_CLI_DESTINO
 FOR EACH ROW
DECLARE
   v_update NUMBER;
   v_reg_oferta VARCHAR2(1) := 'N';
BEGIN
   IF :new.activo = 'N' AND :new.cod_origen IN ('ANDR', 'IOSX', 'HUA') THEN
      -- registro para ofertas mobile, no notificar
      v_reg_oferta := 'S';  
   END IF;
--Cuenta para que no envie si no tiene activo ningun servicio
   IF (inserting OR updating) THEN
     IF (:new.cod_origen<>'COMP' AND v_reg_oferta = 'N') THEN
        v_update := paw_not.fu_not_env_evento(:new.cod_persona, 'NOTCAMBIO', 'NOTCAMBIO');
     END IF;
   END IF;
END;
/

