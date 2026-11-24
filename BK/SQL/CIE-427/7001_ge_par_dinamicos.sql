begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;  
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('CAN_MES_METRICAS', '0', null, null, null, null, null);

commit;
