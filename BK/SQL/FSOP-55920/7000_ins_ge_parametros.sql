SET DEFINE OFF;

BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;
END;
/

-- ==========================================================
-- Parámetro: VAL_LOG_TAS_INT_SEM_DET_HAB
-- Controla el log en detalle de GE_LOG_TAS_INT_SEM_DET
-- Valores: 'S' (default, habilitado) / 'N' (deshabilitado)
-- ==========================================================

-- 1) Registro del parámetro en catálogo
INSERT INTO IT.GE_PARAMETROS (
  PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA,
  USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION,
  OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO
) VALUES (
  'VAL_LOG_TAS_INT_SEM_DET_HAB',         -- PARAMETRO
  'Habilita log detalle (S/N)',          -- DESCRIPCION (≤ 35)
  'GE_PAR_DINAMICOS',                    -- TAB_RELACION
  NULL,                                  -- REFERENCIA
  USER, SYSDATE,                         -- USU/FEC INSERCION
  USER, SYSDATE,                         -- USU/FEC MODIFICACION
  'Controla inserts en GE_LOG_TAS_INT_SEM_DET',  -- OBSERVACION
  NULL,                                  -- PRO_VERIFICACION
  NULL,                                  -- PERMISO
  'S',                                   -- MODIFICABLE
  'S'                                    -- VAL_DEFECTO
);

-- 2) Valor dinámico inicial (requiere que el parámetro exista en GE_PARAMETROS)
INSERT INTO IT.GE_PAR_DINAMICOS (
  PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA,
  USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD
) VALUES (
  'VAL_LOG_TAS_INT_SEM_DET_HAB',  -- PARAMETRO
  'S',                            -- VAL_PARAMETRO (default habilitado)
  NULL, NULL, NULL, NULL,         -- ámbito genérico
  USER, SYSDATE,                  -- USU/FEC INSERCION
  USER, SYSDATE,                  -- USU/FEC MODIFICACION
  NULL                            -- COD_SUB_MODALIDAD
);

COMMIT;
