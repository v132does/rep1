Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_per_def_adicionales (PARAMETRO, TIP_PERSONA, TIP_CAMPO, TIP_DATO, OBLIGATORIO, MODIFICABLE, VAL_DEFECTO, LON_MAXIMA, PERMISO, TIP_PERMISO)
values ('EXC_VAL_EFE_CAM_CAJA', 'T', 'T', 'A', 'N', 'S', null, 1, null, null);

commit;
