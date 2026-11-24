CREATE OR REPLACE FUNCTION IT.fut_obt_cod_procesadora(p_cod_modalidad VARCHAR2,
                                                      p_cod_afinidad VARCHAR2) RETURN NUMBER IS
   v_cod_procesadora ta_tipos.cod_ent_procesadora%type;
BEGIN
   SELECT cod_ent_procesadora
     INTO v_cod_procesadora
     FROM ta_tipos
    WHERE cod_modalidad = p_cod_modalidad
      AND afinidad = p_cod_afinidad
      AND rownum = 1;
   RETURN v_cod_procesadora;
EXCEPTION
   WHEN no_data_found THEN
      RAISE_APPLICATION_ERROR(-20000, 'fut_obt_cod_procesadora ' || SQLERRM);
END;
/

