CREATE OR REPLACE FUNCTION IT.fut_obt_cta_tokenizacion_gp(p_nro_cuenta VARCHAR2) RETURN NUMBER IS
  v_cod_persona ba_personas.cod_persona%TYPE;
BEGIN
  
select DISTINCT cod_persona
  INTO v_cod_persona
  from(
  SELECT cod_persona
    FROM ah_tar_debitos a
   WHERE a.nro_cta_global= p_nro_cuenta
  UNION ALL
  SELECT cod_persona
    FROM ta_tarjetas s
   WHERE s.nro_cuenta = p_nro_cuenta
  UNION ALL
  SELECT cod_persona
    from ta_tar_global_tmp s
   where s.nro_cuenta = p_nro_cuenta);
  RETURN(v_cod_persona);
EXCEPTION
  WHEN no_data_found THEN
    RETURN NULL;
  WHEN too_many_rows THEN
    RETURN NULL;
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20000, 'Error IT.fut_obt_cta_tokenizacion_gp' || SQLERRM);
END fut_obt_cta_tokenizacion_gp;
/

