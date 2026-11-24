Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, MODIFICABLE)
values ('COD_USU_MIG_EXCLUIR', 'COD. USUARIO P/ EXCLUIR DE MAESTROS', 'GE_PAR_DINAMICOS', 'Utilizado para excluir en procesos de cierre de tablas maestras por datos migrados.', 'N');

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('COD_USU_MIG_EXCLUIR', 'MIGRAV');

commit;