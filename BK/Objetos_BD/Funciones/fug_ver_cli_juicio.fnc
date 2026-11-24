CREATE OR REPLACE FUNCTION IT.FUG_VER_CLI_JUICIO ( P_COD_PERSONA IN VARCHAR2 ) RETURN VARCHAR2 IS
   v_en_juicio varchar2(1) := 'N';
BEGIN
   SELECT distinct 'S'
     INTO v_en_juicio
     FROM ge_cta_clientes t, ge_cuentas u
    WHERE t.cod_persona = P_COD_PERSONA
      AND t.relacion IN( 'P' )
      AND t.nro_cuenta = u.nro_cuenta
      AND nvl( u.en_juicio, 'N' ) = 'S'
      AND u.estado <> 'N';
    RETURN v_en_juicio;
EXCEPTION
   WHEN others THEN
      v_en_juicio := 'N';
      RETURN v_en_juicio;
END;
/

