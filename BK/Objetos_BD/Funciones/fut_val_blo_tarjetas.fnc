CREATE OR REPLACE FUNCTION IT.fut_val_blo_tarjetas
(
   p_nro_tarjeta ta_tarjetas.nro_tarjeta%TYPE,
   p_fecha       DATE
) RETURN VARCHAR2 IS
   v_existe VARCHAR2(1);
BEGIN
   SELECT 'S'
     INTO v_existe
     FROM ta_blo_aut_tarjetas t
    WHERE t.fecha = nvl(p_fecha, pag_cal.fu_obt_fec_actual(5))
      AND t.nro_tarjeta = p_nro_tarjeta
      AND t.cod_motivo = 11;
   RETURN v_existe;
EXCEPTION
   WHEN no_data_found THEN
      RETURN 'N';
   WHEN too_many_rows THEN
      RETURN 'S';
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Al verificar bloqueos de tarjetas:' || SQLERRM);
END;
/

