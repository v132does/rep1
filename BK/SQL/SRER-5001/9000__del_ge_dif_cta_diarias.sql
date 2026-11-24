
-- Se eliminan datos de la tabla para que no rompa PK 

BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/


DELETE FROM IT.GE_DIF_CTA_DIARIAS; 

COMMIT;