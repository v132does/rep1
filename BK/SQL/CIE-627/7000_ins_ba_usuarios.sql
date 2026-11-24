begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
insert into ba_usuarios (COD_USUARIO, NOMBRE, COD_OFICINA, COD_AREA, CATEGORIA, OFICIAL, VER_CTA_EMPLEADOS, PROMOTOR, ATN_PUBLICO, COD_PERSONA, FEC_INGRESO, CARGO, TELEFONO, NRO_INTERNO, DIR_CORREO, GRU_AGENDA, FEC_EXP_CLAVE, COD_BANCA, ESTADO, COD_USU_SUPERVISOR, VER_CLI_CONFIDENCIAL, COD_UNIDAD)
values ('MOVCIERRE3', 'Usuario para Mov. Cierre 3', 61, 1, 'US', 'N', 'N', 'N', 'N', null, trunc(sysdate), 'Perfil para procesos de Cierre.', null, null, null, null, null, null, 'A', 'IT', 'N', null);

insert into ba_usuarios (COD_USUARIO, NOMBRE, COD_OFICINA, COD_AREA, CATEGORIA, OFICIAL, VER_CTA_EMPLEADOS, PROMOTOR, ATN_PUBLICO, COD_PERSONA, FEC_INGRESO, CARGO, TELEFONO, NRO_INTERNO, DIR_CORREO, GRU_AGENDA, FEC_EXP_CLAVE, COD_BANCA, ESTADO, COD_USU_SUPERVISOR, VER_CLI_CONFIDENCIAL, COD_UNIDAD)
values ('MOVCIERRE4', 'Usuario para Mov. Cierre 4', 61, 1, 'US', 'N', 'N', 'N', 'N', null, trunc(sysdate), 'Perfil para procesos de Cierre.', null, null, null, null, null, null, 'A', 'IT', 'N', null);

insert into ba_usuarios (COD_USUARIO, NOMBRE, COD_OFICINA, COD_AREA, CATEGORIA, OFICIAL, VER_CTA_EMPLEADOS, PROMOTOR, ATN_PUBLICO, COD_PERSONA, FEC_INGRESO, CARGO, TELEFONO, NRO_INTERNO, DIR_CORREO, GRU_AGENDA, FEC_EXP_CLAVE, COD_BANCA, ESTADO, COD_USU_SUPERVISOR, VER_CLI_CONFIDENCIAL, COD_UNIDAD)
values ('MOVCIERRE5', 'Usuario para Mov. Cierre 5', 61, 1, 'US', 'N', 'N', 'N', 'N', null, trunc(sysdate), 'Perfil para procesos de Cierre.', null, null, null, null, null, null, 'A', 'IT', 'N', null);

commit;
