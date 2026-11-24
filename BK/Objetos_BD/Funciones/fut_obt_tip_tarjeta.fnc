CREATE OR REPLACE FUNCTION IT.fut_obt_tip_tarjeta
(
   p_cod_modalidad IN ta_tipos.cod_modalidad%TYPE,
   p_cod_modulo    IN ta_tipos.cod_modulo%TYPE,
   p_nro_bin       IN ta_tipos.nro_bin%TYPE,
   p_afinidad      IN ta_tipos.afinidad%TYPE,
   p_sub_afinidad  IN ta_tipos.sub_afinidad%TYPE default null

) RETURN VARCHAR2 IS
 
 --se utiliza desde la vista tv_arc_enviados
   v_cod_tip_tarjeta ta_tipos.cod_tip_tarjeta%TYPE;
BEGIN
   BEGIN
      SELECT a.cod_tip_tarjeta
        INTO v_cod_tip_tarjeta
        FROM ta_tipos a
       WHERE a.cod_modalidad = p_cod_modalidad
         AND a.cod_modulo = p_cod_modulo
         AND a.nro_bin = p_nro_bin
         and a.afinidad = p_afinidad
         and rownum = 1;
         --and a.sub_afinidad = p_sub_afinidad;
   EXCEPTION
     /* WHEN no_data_found THEN
       BEGIN
          SELECT a.cod_tip_tarjeta
            INTO v_cod_tip_tarjeta
            FROM ta_tipos a
           WHERE a.cod_modalidad = p_cod_modalidad
             AND a.cod_modulo = p_cod_modulo 
             and a.afinidad = p_afinidad
             --and a.sub_afinidad = p_sub_afinidad
             and rownum = 1;
       EXCEPTION*/
         WHEN others THEN
              v_cod_tip_tarjeta := 0;
       --END;          
   END;
   
   RETURN(v_cod_tip_tarjeta);
END fut_obt_tip_tarjeta;
/

