CREATE OR REPLACE FUNCTION IT.fut_obt_sol_nro_cuenta(p_nro_solicitud IN ta_cta_tarjetas.nro_solicitud%TYPE)
--- Se llama desde la vista TV_ARC_ENVIADOS
 RETURN VARCHAR2 IS
   v_nro_cuenta ta_cta_tarjetas.nro_cuenta%TYPE;
BEGIN
   BEGIN
      SELECT nro_cuenta
        INTO v_nro_cuenta
        FROM ta_cta_tarjetas
       WHERE nro_solicitud = p_nro_solicitud;
   EXCEPTION
      WHEN OTHERS THEN
         v_nro_cuenta := NULL;
   END;
   RETURN(v_nro_cuenta);
END fut_obt_sol_nro_cuenta;
/

