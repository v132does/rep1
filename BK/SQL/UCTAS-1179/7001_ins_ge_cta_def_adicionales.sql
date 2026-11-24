begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_cta_def_adicionales (parametro, obligatorio, modificable, tip_campo, tip_dato, lon_maxima)
values ('LOT_MIG_MODALIDAD', 'N', 'N', 'T', 'A', 200);

commit;
