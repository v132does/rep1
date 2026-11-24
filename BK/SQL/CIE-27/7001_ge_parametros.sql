begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_CAU_MULTA', 'CODIGO CAUSAL MULTA CHEQUE DEVUELTO', 'GE_PAR_DINAMICOS', null, null, null, null, 'N', null);

commit;
