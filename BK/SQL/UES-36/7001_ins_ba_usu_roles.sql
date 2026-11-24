begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into ba_usu_roles (COD_ROL, COD_USUARIO)
values ('FIELCO_MEDIOSPAGO', 'COMPANIES');

commit;
