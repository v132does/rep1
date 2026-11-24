BEGIN pre_ini_aplicacion; END; 
/
insert into ge_cta_def_adicionales (PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_BANCA, OBLIGATORIO, MODIFICABLE, TIP_CAMPO, TIP_DATO, LON_MAXIMA, VAL_DEFECTO, PERMISO, TIP_PERMISO)
values ('IND_NO_MOS_CTA_APP', 6, null, null, null, null, 'N', 'S', 'C', 'A', 1, 'N', null, null);

commit;