BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into BA_PAR_reporteS (COD_PROGRAMA, COD_CAMPO, ALIAS, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('CLCHPLLO', 'FEC_ENCHE', 'ge_che_exterior', 'F', 13, 'V', 'S', 'N');

COMMIT;
