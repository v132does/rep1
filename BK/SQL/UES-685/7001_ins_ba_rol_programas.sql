begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into ba_rol_programas (COD_PROGRAMA, COD_ROL, INSERTA, ACTUALIZA, ELIMINA, CONSULTA, IMPRIME)
values ('GPCTAIPS', 'ADM. DE SISTEMAS', 'S', 'S', 'S', 'S', 'S');

insert into ba_rol_programas (COD_PROGRAMA, COD_ROL, INSERTA, ACTUALIZA, ELIMINA, CONSULTA, IMPRIME)
values ('GPCTAIPS', 'OPERATIVO', 'S', 'S', 'N', 'S', 'S');

insert into ba_rol_programas (COD_PROGRAMA, COD_ROL, INSERTA, ACTUALIZA, ELIMINA, CONSULTA, IMPRIME)
values ('GPCTAIPS', 'USUARIOHML', 'S', 'S', 'S', 'S', 'S');

commit;
