BEGIN  PRE_INI_APLICACION;  PAE_CNF.G_COD_MODULO := 1; END;
/
INSERT INTO GE_PARAMETROS (
    PARAMETRO, 
    DESCRIPCION, 
    TAB_RELACION, 
    OBSERVACION, 
    MODIFICABLE)
VALUES(
    'TIP_DEU_SEC_FINANCIERO', 
    'TIPOS DE DEUDORES SECTOR FINANCIERO', 
    'GE_PAR_DINAMICOS', 
    'Bancos y Financieras que son excluidas de la facturación de compras de divisas.', 
    'N'
);
COMMIT;