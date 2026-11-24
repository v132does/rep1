CREATE OR REPLACE TRIGGER IT.tb_co_inf_cob_diarios
   BEFORE INSERT OR UPDATE ON co_inf_cob_diarios
   FOR EACH ROW
BEGIN
   IF inserting THEN
      --Calculamos los días de atraso
      :new.dia_atraso := (:new.fec_envio - :new.fec_vencimiento);
   ELSIF updating AND nvl(:new.mto_cobrado, 0) > 0 THEN
      :new.dia_atraso := (:new.fec_envio - :new.fec_vencimiento);
   END IF;
END;
/

