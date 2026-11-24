CREATE OR REPLACE FUNCTION IT.fut_val_reg_tarjetas(p_nro_tarjeta ta_tarjetas.nro_tarjeta%TYPE) RETURN VARCHAR2 IS
   v_existe VARCHAR2(1);
   /**
    * Para verifcar las solicitudes de regrabaciones
    */
BEGIN
   SELECT 'S'
     INTO v_existe
     FROM ta_tar_regrabaciones_tmp t
    WHERE t.nro_tarjeta = p_nro_tarjeta
      AND t.cod_motivo = 157
      AND t.estado != 'R';
   RETURN v_existe;
EXCEPTION
   WHEN no_data_found THEN
      RETURN 'N';
   WHEN too_many_rows THEN
      RETURN 'S';
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Al verificar regrabaciones de tarjetas:' || SQLERRM);
END;
/

