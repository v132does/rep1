begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into it.ba_rol_programas (COD_PROGRAMA, COD_ROL, INSERTA, ACTUALIZA, ELIMINA, CONSULTA, IMPRIME)
values ('BLIMPRED', 'ADM. DE SISTEMAS', 'N', 'S', 'S', 'S', 'S');
/
commit;
