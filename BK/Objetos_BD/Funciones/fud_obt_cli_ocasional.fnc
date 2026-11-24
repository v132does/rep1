CREATE OR REPLACE FUNCTION IT.fud_obt_cli_ocasional(p_tip_documento IN ba_personas.cod_tip_documento%TYPE,
p_nro_documento IN ba_personas.nro_documento%TYPE)
   RETURN VARCHAR2 IS
   v_retorno ba_personas.nom_completo%TYPE;
BEGIN
   BEGIN
      SELECT a.pri_nombre || ' ' || a.seg_nombre || ' ' || a.pri_apellido || ' ' || a.seg_apellido
        INTO v_retorno
        FROM ba_cli_ocasionales a
       WHERE a.cod_tip_documento = p_tip_documento
         AND a.nro_documento     = p_nro_documento;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
        BEGIN
           SELECT a.pri_nombre || ' ' || a.seg_nombre || ' ' || a.pri_apellido || ' ' || a.seg_apellido
            INTO v_retorno
            FROM ba_cli_ocasionales a
           WHERE a.nro_documento     = p_nro_documento
           AND ROWNUM=1;
        EXCEPTION
          WHEN OTHERS THEN
            v_retorno := NULL;
        END;
      WHEN OTHERS THEN
         v_retorno := NULL;
   END;
   RETURN v_retorno;
END;
/

