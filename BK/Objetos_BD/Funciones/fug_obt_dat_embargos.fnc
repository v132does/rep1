CREATE OR REPLACE FUNCTION IT.fug_obt_dat_embargos
                                              (p_nro_cuenta in ge_embargos_det.nro_cuenta%TYPE,
                                               p_cod_embargo in ge_embargos_det.cod_embargo%TYPE,
                                               p_tipo_dat in pr_cta_prestamos.estado%TYPE) RETURN NUMBER IS
--si p_tipo_dat recibe como valor A, se busca el monto de embargo aplicado a la cuenta
--si p_tipo_dat recibe como valor S, Se busca el saldo del embargo
V_MONTO GE_EMBARGOS_DET.MTO_APLICADO%TYPE :=0;
BEGIN
  IF p_tipo_dat = 'A' THEN
    BEGIN
      SELECT NVL(A.MTO_APLICADO,0)
        INTO V_MONTO
        FROM GE_EMBARGOS_DET A
       WHERE A.COD_EMBARGO = p_cod_embargo
         AND A.NRO_CUENTA = p_nro_cuenta;
    EXCEPTION
      WHEN OTHERS THEN
        V_MONTO := 0;
    END;
  ELSE
    BEGIN
      SELECT NVL(A.SAL_EMBARGO,0)
        INTO V_MONTO
        FROM GE_EMBARGOS_DET A
       WHERE A.COD_EMBARGO = p_cod_embargo
         AND A.NRO_CUENTA = p_nro_cuenta;
    EXCEPTION
      WHEN OTHERS THEN
        V_MONTO := 0;
    END;
  END IF;
  RETURN V_MONTO;
END;
/

