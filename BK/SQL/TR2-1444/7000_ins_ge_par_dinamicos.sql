begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
end;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, MODIFICABLE)
values ('TAR_COD_USU_EXCLUIDO', 'Usuarios excluidos para Triggers', 'GE_PAR_DINAMICOS', 'Parámetro que sirve de indicador para identificar usuarios excluidos en ejecución de triggers de auditoria para la tabla ta_cta_tarjetas', 'N');

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('TAR_COD_USU_EXCLUIDO', 'CREDCARDS');

commit;
