begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('USU_ONB_PERSONAS', 'USU PARA ONB PER.FISICA', 'GE_PAR_DINAMICOS', null, 'CURIARTE', to_date('02-07-2024 13:10:04', 'dd-mm-yyyy hh24:mi:ss'), 'CURIARTE', to_date('02-07-2024 13:10:25', 'dd-mm-yyyy hh24:mi:ss'), 'USUARIO QUE SE UTILIZA EN EL ONB PERSONAS FISICAS', null, null, 'N', null);

commit
