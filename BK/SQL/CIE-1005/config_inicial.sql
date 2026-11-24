begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/

Insert into GE_PARAMETROS (PARAMETRO,DESCRIPCION,TAB_RELACION,OBSERVACION,MODIFICABLE,VAL_DEFECTO)
values ('OCO_CADENAS_HABILITADAS','CADENAS HABILITADAS ORQUESTA OCO','GE_PAR_DINAMICOS','Lista de códigos de proceso habilitados para ser orquestados de manera externa al CORE por OCO','S',null);

Insert into GE_PAR_DINAMICOS (PARAMETRO,VAL_PARAMETRO)
values ('OCO_CADENAS_HABILITADAS','7');

Insert into BA_COD_REFERENCIAS (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_CIERRE', 'Usuario de Cierre', 'OPECLOSURE', 'OPECLOSURE', 'OPECLOSURE', 'S');

COMMIT;
