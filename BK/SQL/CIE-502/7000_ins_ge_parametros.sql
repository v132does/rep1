begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, MODIFICABLE, VAL_DEFECTO)
values ('PRA_CON_TRA_DEL_FEC', 'LIMITE DE DIAS GE_CON_TRA_PROCESOS', 'GE_PAR_DINAMICOS', 'Dias a manatener los registros en la tabla ge_con_tra_procesos que guarda la consolidacion de movimientos', 'N', null);

commit;
