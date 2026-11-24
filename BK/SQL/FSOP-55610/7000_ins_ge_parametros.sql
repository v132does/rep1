Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into it.ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('OPE_SUP_MON_DEPOSITO', 'OPERACIONES SUPERIORES MONTO DEP.', 'GE_PAR_DINAMICOS', null, 'Utilizado para el control de transacciones para Depositos cuando el monto supera lo estipulado.', null, null, 'S', null);

commit;
