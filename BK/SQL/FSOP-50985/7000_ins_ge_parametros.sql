BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, MODIFICABLE)
values ('CAN_DIAS_VIGIA', 'DIAS HISTORICO VIGIA', 'GE_PAR_DINAMICOS', 'Cantidad de días para la consulta de histórico de vista Vigia.', 'N');

COMMIT;
