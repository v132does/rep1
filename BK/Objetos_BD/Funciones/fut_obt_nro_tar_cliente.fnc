CREATE OR REPLACE FUNCTION IT.fut_obt_nro_tar_cliente
(
   p_nro_solicitud IN ta_cta_tarjetas.nro_solicitud%TYPE,
   p_cod_persona   ba_personas.cod_persona%TYPE
) RETURN VARCHAR2 IS
   --se utiliza desde la vista tv_arc_enviados
   v_nro_tarjeta ta_tarjetas.nro_tarjeta%TYPE;
BEGIN
   BEGIN
      SELECT b.nro_tarjeta
        INTO v_nro_tarjeta
        FROM ta_cta_tarjetas a, ta_tarjetas b
       WHERE a.nro_cuenta = b.nro_cuenta
         AND a.nro_solicitud = p_nro_solicitud
         AND b.cod_persona = p_cod_persona
         AND b.vigente = 'S';
   EXCEPTION
      WHEN OTHERS THEN
         v_nro_tarjeta := NULL;
   END;
   RETURN(v_nro_tarjeta);
END fut_obt_nro_tar_cliente;
/

