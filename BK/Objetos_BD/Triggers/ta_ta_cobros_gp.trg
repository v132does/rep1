CREATE OR REPLACE TRIGGER IT.ta_ta_cobros_gp
 AFTER INSERT OR UPDATE
 ON "IT"."TA_COBROS_GP"
 FOR EACH ROW
DECLARE
  v_sal_pag_minimo ta_cta_tarjetas.sal_pag_minimo%TYPE;
  v_saldo          ta_cta_tarjetas.sal_pag_minimo%TYPE;
BEGIN  
  IF fug_obt_pardinamico('MAR_ACT_SAL_MIN_GP') = 'S' THEN
    SELECT sal_pag_minimo
      INTO v_sal_pag_minimo
      FROM ta_cta_tarjetas
     WHERE nro_cuenta = :new.nro_Cuenta;
    IF updating  and :new.est_envio = 'E' THEN
      v_saldo := v_sal_pag_minimo - :new.monto;
      IF v_saldo < 0 THEN
        v_saldo := 0;
      END IF;
      UPDATE ta_cta_tarjetas t
         SET t.sal_pag_minimo = v_saldo
       WHERE t.nro_cuenta = :new.nro_Cuenta;   
    END IF;
  END IF; 
END;
/

