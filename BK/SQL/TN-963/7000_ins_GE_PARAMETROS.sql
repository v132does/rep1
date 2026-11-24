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
    'PRO_EJE_PROCESOS_LOCK',
    'PROCESOS CON EXCLUSION MUTUA',
    'GE_PAR_DINAMICOS',
    'Procesos con bloqueos de exclusion mutua en PRG_EJE_PROCESOS',
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
    'PRO_320_ERR_NO_BLOQUEANTE',
    'ERRORES NO BLOQUEANTES PRO 320',
    'GE_PAR_DINAMICOS',
    'Errores no bloqueantes del proceso 320 (FIN DE DIA CONTABLE)',
    'N'
);
COMMIT;