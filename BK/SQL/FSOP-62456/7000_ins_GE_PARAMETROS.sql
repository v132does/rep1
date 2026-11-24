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
    'TIP_TRANSACCION_FAC_ELE',
    'TIPO TRANSACCION FACTURA ELECT.',
    'GE_PAR_DINAMICOS',
    'Tipo de transaccion de la factura electrónica',
    'N'
);

COMMIT;