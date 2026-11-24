begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
-- insert ge entes prosegur asuncion
insert into ge_entes (cod_ente, descripcion, cod_persona, tipo, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values ((select max(cod_ente) from ge_entes ge) + 1, 'PROSEGUR ASUNCION', '1', 'CD', user, sysdate, user, sysdate);
 commit;
 
insert into ge_par_entes (cod_ente, parametro, val_parametro, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values ((select cod_ente from ge_entes where descripcion = 'PROSEGUR ASUNCION' and cod_persona = 1 and tipo = 'CD'), 'NRO_CTA_GS', '6111520005', user, sysdate, user, sysdate);
 commit;
 
insert into ge_par_entes (cod_ente, parametro, val_parametro, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values ((select cod_ente from ge_entes where descripcion = 'PROSEGUR ASUNCION' and cod_persona = 1 and tipo = 'CD'), 'NRO_CTA_US', '6111520001', user, sysdate, user, sysdate);
 commit;
 
-- insert ge entes prosegur cde
insert into ge_entes (cod_ente, descripcion, cod_persona, tipo, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values ((select max(cod_ente) from ge_entes ge) + 1, 'PROSEGUR CDE', '1', 'CD', user, sysdate, user, sysdate);
 commit;
 
insert into ge_par_entes (cod_ente, parametro, val_parametro, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values ((select cod_ente from ge_entes where descripcion = 'PROSEGUR CDE' and cod_persona = 1 and tipo = 'CD'), 'NRO_CTA_GS', '6111520010', user, sysdate, user, sysdate);
 commit;
 
insert into ge_par_entes (cod_ente, parametro, val_parametro, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values ((select cod_ente from ge_entes where descripcion = 'PROSEGUR CDE' and cod_persona = 1 and tipo = 'CD'), 'NRO_CTA_US', '6111520006', user, sysdate, user, sysdate);
 commit;
-- insert ge entes forsite 
insert into ge_entes (cod_ente, descripcion, cod_persona, tipo, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values ((select max(cod_ente) from ge_entes ge) + 1, 'FORTSITE', '1', 'CD', user, sysdate, user, sysdate);
commit;
insert into ge_par_entes (cod_ente, parametro, val_parametro, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values ((select cod_ente from ge_entes where descripcion = 'FORTSITE' and cod_persona = 1 and tipo = 'CD'), 'NRO_CTA_GS', '614800206', user, sysdate, user, sysdate);
commit;
insert into ge_par_entes (cod_ente, parametro, val_parametro, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values ((select cod_ente from ge_entes where descripcion = 'FORTSITE' and cod_persona = 1 and tipo = 'CD'), 'NRO_CTA_US', '614800590', user, sysdate, user, sysdate);
commit;
-- insert ge entes yrendague 
insert into ge_entes (cod_ente, descripcion, cod_persona, tipo, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values ((select max(cod_ente) from ge_entes ge) + 1, 'YRENDAGUE', '1', 'CD', user, sysdate, user, sysdate);
commit;
insert into ge_par_entes (cod_ente, parametro, val_parametro, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values ((select cod_ente from ge_entes where descripcion = 'YRENDAGUE' and cod_persona = 1 and tipo = 'CD'), 'NRO_CTA_GS', '614800207', user, sysdate, user, sysdate);
commit;
insert into ge_par_entes (cod_ente, parametro, val_parametro, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values ((select cod_ente from ge_entes where descripcion = 'YRENDAGUE' and cod_persona = 1 and tipo = 'CD'), 'NRO_CTA_US', '6111520043', user, sysdate, user, sysdate);
commit;
-- insert ge entes indefinido 
insert into ge_entes (cod_ente, descripcion, cod_persona, tipo, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values ((select max(cod_ente) from ge_entes ge) + 1, 'INDEFINIDO', '1', 'CD', user, sysdate, user, sysdate);
commit;
insert into ge_par_entes (cod_ente, parametro, val_parametro, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values ((select cod_ente from ge_entes where descripcion = 'INDEFINIDO' and cod_persona = 1 and tipo = 'CD'), 'NRO_CTA_GS', '0', user, sysdate, user, sysdate);
commit;
insert into ge_par_entes (cod_ente, parametro, val_parametro, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values ((select cod_ente from ge_entes where descripcion = 'INDEFINIDO' and cod_persona = 1 and tipo = 'CD'), 'NRO_CTA_US', '0', user, sysdate, user, sysdate);
commit;
