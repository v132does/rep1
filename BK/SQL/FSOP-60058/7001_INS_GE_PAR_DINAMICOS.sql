BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:= 1; END;
/
INSERT INTO GE_PAR_DINAMICOS (PARAMETRO,
                              VAL_PARAMETRO,
                              COD_MONEDA)
                      VALUES ('CTA_FIN_INTERBANCARIA_USD',
                              'COMA1001USD',
                              'USD'); 

INSERT INTO GE_PAR_DINAMICOS (PARAMETRO,
                              VAL_PARAMETRO,
                              COD_MONEDA)
                      VALUES ('CTA_FIN_INTERBANCARIA_GS',
                              'COMA1001PYG',
                              'GS'); 

COMMIT;