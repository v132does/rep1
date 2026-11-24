CREATE OR REPLACE FUNCTION IT.fut_obt_procesadora(p_nro_cuenta VARCHAR2) RETURN NUMBER IS
  v_cod_procesadora ta_tipos.cod_ent_procesadora%type := 0;
BEGIN
  SELECT b.cod_ent_procesadora
    INTO v_cod_procesadora
    FROM ta_cta_tarjetas a, ta_tipos b
   WHERE a.cod_modalidad = b.cod_modalidad
     AND a.afinidad = b.afinidad
     AND a.nro_cuenta IN p_nro_cuenta;
  RETURN(v_cod_procesadora);
EXCEPTION 
  WHEN no_data_found THEN
    -- devolver por defecto Bancard 
    --v_cod_procesadora := fug_obt_pardinamico('COD_PRO_BANCARD');
    RETURN(v_cod_procesadora);
  WHEN too_many_rows THEN
    --v_cod_procesadora := fug_obt_pardinamico('COD_PRO_BANCARD');
    RETURN(v_cod_procesadora);
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20000, 'fut_obt_procesadora ' || SQLERRM);
END fut_obt_procesadora;
/

