Begin pre_ini_aplicacion; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('PRE_DIG_COD_CAMPANA', 'COD DE CAMPAÑA P/ASIG PRE. DIGITAL', 'GE_PAR_DINAMICOS', null, 'IT', to_date('26-11-2024 10:31:14', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('26-11-2024 10:35:27', 'dd-mm-yyyy hh24:mi:ss'), 'Código de campaña para los productos que se expiden digitalmente, por app o por servicios', null, null, 'N', null);

commit;
