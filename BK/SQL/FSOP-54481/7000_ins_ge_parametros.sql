Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_ROL_PER_PERFIL', 'COD. ROL VERIF. PERFIL', 'GE_PAR_DINAMICOS', null, 'Código de Rol utilizado para verificación de perfil (Ingresar Roles entre comas).', null, null, 'N', null);

COMMIT;
