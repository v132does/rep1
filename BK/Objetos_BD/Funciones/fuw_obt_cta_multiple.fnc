CREATE OR REPLACE FUNCTION IT.fuw_obt_cta_multiple(p_cod_persona IN ba_personas.cod_persona%TYPE) RETURN VARCHAR2 IS
   v_cuenta bw_tra_cta_configurado.nro_cuenta%TYPE;
BEGIN
   SELECT a.nro_cuenta
     INTO v_cuenta
     FROM bw_tra_cta_configurado a
    WHERE a.cod_persona = p_cod_persona
      AND a.estado = 'A';
  RETURN v_cuenta;
EXCEPTION
   WHEN OTHERS THEN
      RETURN NULL;
END;
/

