CREATE OR REPLACE PROCEDURE IT.prw_ina_est_clave IS
  v_max_dias  NUMBER;
  v_tip_clave bw_ope_claves.tip_clave%TYPE;
BEGIN
  BEGIN
    -- obtenemos la maxima cantidad de dias de uso de claves de Acceso
    BEGIN
      v_max_dias  := to_number(fug_obt_pardinamico('BWE_DIA_CLA_INHABILITADO'));
      v_tip_clave := 'A';
    EXCEPTION
      WHEN OTHERS THEN
        v_max_dias := 30;
    END;
    -- se inactiva solo si esta para cambiar y cumplio la cantidad de dias
    UPDATE bw_ope_claves
       SET est_clave     = 'X', --FSPC-300 Se cambia de 'I' a 'X' al vencer
           fec_est_clave = SYSDATE
     WHERE tip_clave = v_tip_clave
       AND est_clave IN ('A')
       AND (fec_est_clave IS NULL OR
           trunc(fec_est_clave) < SYSDATE - v_max_dias);
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000,'Error al inactivar claves de acceso/transaccional - Error : ' ||
                              SQLERRM);
  END;
  -- obtenemos la maxima cantidad de dias de uso de claves Transaccional
  BEGIN
    BEGIN
      v_max_dias  := to_number(fug_obt_pardinamico('BWE_DIA_CLA_INH_TRANSACCIONAL'));
      v_tip_clave := 'T';
    EXCEPTION
      WHEN OTHERS THEN
        v_max_dias := 30;
    END;
    -- se inactiva solo si esta para cambiar y cumplio la cantidad de dias
    UPDATE bw_ope_claves
       SET est_clave = 'X', fec_est_clave = SYSDATE
     WHERE tip_clave = v_tip_clave
       AND est_clave IN ('A')
       AND (fec_est_clave IS NULL OR
           trunc(fec_est_clave) < SYSDATE - v_max_dias);
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000,'Error al inactivar la clave transaccional - Error : ' ||
                              SQLERRM);
  END;
END;
/

