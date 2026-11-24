Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
--Por el momento,se permitira solo moneda local
update ge_par_dinamicos s
set s.cod_moneda='GS'
where parametro='COD_MAD_DEB_COMBO2';
commit;