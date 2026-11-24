CREATE OR REPLACE TRIGGER IT.TB_CB_INF_DER_GASTOS
 BEFORE DELETE OR INSERT OR UPDATE
  ON CB_INF_DER_GASTOS
 FOR EACH ROW
DECLARE 
v_cod_mon_local cb_inf_der_gastos.cod_moneda%type := pag_gen.fu_obt_mon_local;
BEGIN
  IF inserting THEN
     BEGIN
        IF :new.cod_rubro IS NULL THEN
           :new.cod_rubro := fub_obt_rub_transaccion(:new.cod_modulo, :new.cod_modalidad, :new.cod_transaccion, v_cod_mon_local, null, null, 'D');        
        END IF;
        --
        IF :new.cod_moneda <> v_cod_mon_local THEN
           :new.importe := ROUND((NVL(:old.importe,0) * pag_gen.fu_obt_cotizacion(:old.cod_moneda, :old.fec_proceso)),0);
           :new.cod_moneda := v_cod_mon_local;
        END IF;     
     EXCEPTION
        WHEN OTHERS THEN
           :new.importe := 0;
     END;
  END IF;  
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20003,'TB_CB_INF_DER_GASTOS -'||sqlerrm);
END TB_CB_INF_DER_GASTOS;
/

