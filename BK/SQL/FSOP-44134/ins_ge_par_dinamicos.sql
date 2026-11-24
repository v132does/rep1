Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, MODIFICABLE)
values ('PER_CON_BCP', 'Periodo de Consulta BCP CRC', 'GE_PAR_DINAMICOS', 'Periodo de consulta a bcp por datos crc.', 'N');


insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('PER_CON_BCP', '202410');

commit;