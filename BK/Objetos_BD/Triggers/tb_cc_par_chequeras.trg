CREATE OR REPLACE TRIGGER IT."TB_CC_PAR_CHEQUERAS"
 BEFORE DELETE OR INSERT OR UPDATE
  ON CC_PAR_CHEQUERAS
 FOR EACH ROW
DECLARE
  v_lon_ser_cheque     number := fug_obt_pardinamico('LON_SER_CHEQUE');
  v_lon_sig_nro_che    number := fug_obt_pardinamico('LON_SIG_NRO_CHE');
BEGIN
  if (inserting or updating) then
     --Se controla la longitud de la serie.
     if length(:new.serie) > v_lon_ser_cheque and :new.serie <> :old.serie then
        raise_application_error(-20001,'La serie sólo puede ser de '||v_lon_ser_cheque||' dígitos.');
     end if;
     
     --Se controla la longitud del nro de cheque siguiente.
     if length(:new.sig_nro_cheque) > v_lon_sig_nro_che and :new.sig_nro_cheque <> :old.sig_nro_cheque then
        raise_application_error(-20002,'El número de cheque sólo puede ser de '||v_lon_sig_nro_che||' dígitos.');
     end if;
     
     --Verifica que el valor ingresado en la serie sea numerico
     if fug_val_es_numerico(:new.serie) = 'N' then
        raise_application_error(-20003,'La serie debe ser numérica.');
     end if;
     
  end if;
EXCEPTION
  WHEN OTHERS THEN
   raise_application_error(-20003,'TB_GE_MOVIMIENTOS -'||sqlerrm);
END TB_CC_PAR_CHEQUERAS;
/

