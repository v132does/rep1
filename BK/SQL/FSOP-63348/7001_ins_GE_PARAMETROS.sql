begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end;
/
INSERT INTO GE_PARAMETROS (
    PARAMETRO, 
    DESCRIPCION, 
    TAB_RELACION, 
    OBSERVACION, 
    MODIFICABLE
)
VALUES (
    'ASI_DET_DIF_MAX_DIAS',
    'CANTIDAD DE DIAS DE HISTORIAL',
    'GE_PAR_DINAMICOS',
    'Cantidad de días que se mantienen los archivos del Detalle de Asientos con Diferencias en el servidor',
    'N'
);
INSERT INTO GE_PARAMETROS (
    PARAMETRO, 
    DESCRIPCION, 
    TAB_RELACION, 
    OBSERVACION, 
    MODIFICABLE
)
VALUES (
    'ASI_DET_DIF_SEQ_ARCHIVO',
    'SECUENCIA ACTUAL DEL ARCHIVO',
    'GE_PAR_DINAMICOS',
    'Numero de secuencia del ultimo archivo generado.',
    'S'
);
INSERT INTO GE_PARAMETROS (
    PARAMETRO, 
    DESCRIPCION, 
    TAB_RELACION, 
    OBSERVACION, 
    MODIFICABLE
)
VALUES (
    'ASI_DET_ACT_SIGNOS_CASO1_380',
    'ACTUALIZACION DE SIGNOS CASO 1',
    'GE_PAR_DINAMICOS',
    'Actualizacion de signos CASO 1 para el COD_TRA_PADRE 380',
    'N'
);

INSERT INTO GE_PARAMETROS (
    PARAMETRO, 
    DESCRIPCION, 
    TAB_RELACION, 
    OBSERVACION, 
    MODIFICABLE
)
VALUES (
    'ASI_DET_ACT_SIGNOS_CASO2_8914',
    'ACTUALIZACION DE SIGNOS CASO 2',
    'GE_PAR_DINAMICOS',
    'Actualizacion de signos CASO 2 para el COD_TRA_PADRE 8914',
    'N'
);

INSERT INTO GE_PARAMETROS (
    PARAMETRO, 
    DESCRIPCION, 
    TAB_RELACION, 
    OBSERVACION, 
    MODIFICABLE
)
VALUES (
    'ASI_DET_ACT_SIGNOS_CASO4_380',
    'ACTUALIZACION DE SIGNOS CASO 4',
    'GE_PAR_DINAMICOS',
    'Actualizacion de signos CASO 4 para el COD_TRA_PADRE 380',
    'N'
);
COMMIT;