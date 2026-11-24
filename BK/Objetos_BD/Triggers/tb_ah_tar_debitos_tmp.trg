CREATE OR REPLACE TRIGGER IT.TB_AH_TAR_DEBITOS_TMP
BEFORE INSERT ON AH_TAR_DEBITOS_TMP
FOR EACH ROW

DECLARE
  v_nro_cuenta ge_cuentas.nro_cuenta%type;
BEGIN
-- Armar y cargar la cuenta
  v_nro_cuenta := pag_sue.Fu_dec_cuenta(substr(:new.nro_tarjeta,7,9));
 :new.nro_cuenta := v_nro_cuenta;

exception
   when others then
     if sqlcode < -20000  then
         raise;
     else
        raise_application_error(-20000,'TB_AH_TAR_DEBITOS_TMP : Maestro de T.Debitos ' || sqlerrm);
     end if;
END;
/

