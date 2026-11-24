begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into it.ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('MES_PRO_MODALIDAD', 'REPO BURSATIL - RECIBIDO', '149', null, 'MMCTARRE', 'S');
/
commit;
/