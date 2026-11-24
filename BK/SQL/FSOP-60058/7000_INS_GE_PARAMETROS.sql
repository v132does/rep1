BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:= 1; END;
/
INSERT INTO GE_PARAMETROS (PARAMETRO,
                           DESCRIPCION,
                           TAB_RELACION,
                           OBSERVACION,
                           MODIFICABLE) 
                   VALUES ('CTA_FIN_INTERBANCARIA_USD',
                           'Cta Financiera Interbancaria USD',
                           'GE_PAR_DINAMICOS',
                           'Se utiliza para el envío de consulta de saldo MT985/STAT',
                           'S');

INSERT INTO GE_PARAMETROS (PARAMETRO,
                           DESCRIPCION,
                           TAB_RELACION,
                           OBSERVACION,
                           MODIFICABLE) 
                   VALUES ('CTA_FIN_INTERBANCARIA_GS',
                           'Cta Financiera Interbancaria GS',
                           'GE_PAR_DINAMICOS',
                           'Se utiliza para el envío de consulta de saldo MT985/STAT',
                           'S');

COMMIT;

