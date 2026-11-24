begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; pae_cnf.G_PROGRAMA := 'GPPROFIN'; end; 
/
insert into ba_usuarios (COD_USUARIO, NOMBRE, COD_OFICINA, COD_AREA, CATEGORIA, OFICIAL, VER_CTA_EMPLEADOS, PROMOTOR, ATN_PUBLICO, COD_PERSONA, FEC_INGRESO, CARGO, TELEFONO, NRO_INTERNO, DIR_CORREO, GRU_AGENDA, FEC_EXP_CLAVE, COD_BANCA, ESTADO, COD_USU_SUPERVISOR, VER_CLI_CONFIDENCIAL, COD_UNIDAD)
values ('MOVCIERRE7', 'Usuario para Mov. Cierre', 61, 1, 'US', 'N', 'N', 'N', 'N', null, to_date('28-05-2021', 'dd-mm-yyyy'), 'Perfil para procesos de Cierre.', null, null, null, null, null, null, 'A', 'IT', 'N', null);

insert into ba_usuarios (COD_USUARIO, NOMBRE, COD_OFICINA, COD_AREA, CATEGORIA, OFICIAL, VER_CTA_EMPLEADOS, PROMOTOR, ATN_PUBLICO, COD_PERSONA, FEC_INGRESO, CARGO, TELEFONO, NRO_INTERNO, DIR_CORREO, GRU_AGENDA, FEC_EXP_CLAVE, COD_BANCA, ESTADO, COD_USU_SUPERVISOR, VER_CLI_CONFIDENCIAL, COD_UNIDAD)
values ('MOVCIERRE8', 'Usuario para Mov. Cierre', 61, 1, 'US', 'N', 'N', 'N', 'N', null, to_date('28-05-2021', 'dd-mm-yyyy'), 'Perfil para procesos de Cierre.', null, null, null, null, null, null, 'A', 'IT', 'N', null);

insert into ba_usuarios (COD_USUARIO, NOMBRE, COD_OFICINA, COD_AREA, CATEGORIA, OFICIAL, VER_CTA_EMPLEADOS, PROMOTOR, ATN_PUBLICO, COD_PERSONA, FEC_INGRESO, CARGO, TELEFONO, NRO_INTERNO, DIR_CORREO, GRU_AGENDA, FEC_EXP_CLAVE, COD_BANCA, ESTADO, COD_USU_SUPERVISOR, VER_CLI_CONFIDENCIAL, COD_UNIDAD)
values ('MOVCIERRE9', 'Usuario para Mov. Cierre', 61, 1, 'US', 'N', 'N', 'N', 'N', null, to_date('28-05-2021', 'dd-mm-yyyy'), 'Perfil para procesos de Cierre.', null, null, null, null, null, null, 'A', 'IT', 'N', null);

commit;
