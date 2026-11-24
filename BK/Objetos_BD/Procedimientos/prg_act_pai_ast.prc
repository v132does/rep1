CREATE OR REPLACE PROCEDURE IT.PRG_ACT_PAI_AST
IS
  V_COD_PAIS BA_PAISES.COD_PAIS%TYPE;
  ----
  CURSOR C_CURSOR IS
    SELECT COD_AST_PAIS, UPPER(DESCRIPCION) DESCRIPCION, RISK_LEVEL_ISO,
      RISK_LEVEL_ASSIGNED
    FROM GE_AST_PAISES_TEMP;
BEGIN
  -- Inicializar variables ITGF
  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo:=1;
  -- Abre el cursor
  FOR F_CURSOR IN C_CURSOR
  LOOP
    BEGIN
      SELECT COD_PAIS
      INTO V_COD_PAIS
      FROM GE_AST_PAI_ISO
      WHERE COD_ISO_PAIS = F_CURSOR.COD_AST_PAIS;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
         NULL;
      WHEN OTHERS THEN
         NULL;
    END;
    -- Inserta si no existe el pais
    BEGIN
      INSERT INTO GE_AST_PAISES (COD_AST_PAIS,
                                        DESCRIPCION,
                                        COD_PAIS,
                                        RISK_LEVEL_ISO,
                                        RISK_LEVEL_ASSIGNED)
                                  VALUES (F_CURSOR.COD_AST_PAIS,
                                         F_CURSOR.DESCRIPCION,
                                         V_COD_PAIS,
                                         F_CURSOR.RISK_LEVEL_ISO,
                                         F_CURSOR.RISK_LEVEL_ASSIGNED
                                      );
    EXCEPTION
      WHEN DUP_VAL_ON_INDEX THEN
        -- Actualiza si ya existe el código de país ISO
        UPDATE GE_AST_PAISES
        SET RISK_LEVEL_ISO = F_CURSOR.RISK_LEVEL_ISO,
          RISK_LEVEL_ASSIGNED = F_CURSOR.RISK_LEVEL_ASSIGNED
        WHERE COD_AST_PAIS = F_CURSOR.COD_AST_PAIS;
    END;
  --
  END LOOP;
  --
  COMMIT;
  --
EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20001,'Ocurrió un error en la importación de Países. '||sqlerrm);
END;
/

