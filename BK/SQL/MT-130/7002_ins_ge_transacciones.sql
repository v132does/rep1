begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
-- transaccion padre de carga - descargac
insert into ge_transacciones (cod_transaccion, cod_modulo, cod_modalidad, descripcion, ve_cliente, tipo, abreviatura, rutina1, rutina2, rutina3, cod_tip_asiento, cod_tasa, batch, cod_retencion, interno, afecta, cod_tip_asiento2, tip_despliegue, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values (1125, 4, 43, 'TRANSACCION DE CARGA DESCARGA - TED', 'S', 'P', 'TRXTCD', null, null, null, null, null, 'O', null, 'N', null, null, 'C', user, sysdate, user, sysdate);
insert into ge_transacciones (cod_transaccion, cod_modulo, cod_modalidad, descripcion, ve_cliente, tipo, abreviatura, rutina1, rutina2, rutina3, cod_tip_asiento, cod_tasa, batch, cod_retencion, interno, afecta, cod_tip_asiento2, tip_despliegue, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values (1125, 9, 91, 'TRANSACCION DE CARGA DESCARGA - TED', 'S', 'P', 'TRXTCD', null, null, null, null, null, 'O', null, 'N', 'N', null, null, user, sysdate, user, sysdate);
commit;
-- transaccion hijo de carga - descarga
insert into ge_transacciones (cod_transaccion, cod_modulo, cod_modalidad, descripcion, ve_cliente, tipo, abreviatura, rutina1, rutina2, rutina3, cod_tip_asiento, cod_tasa, batch, cod_retencion, interno, afecta, cod_tip_asiento2, tip_despliegue, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values (3691, 4, 43, 'TRANSACCION DE CARGA - TED', 'S', 'D', 'TRXCAR', 'PRA_ACT_SAL_BATCH', null, '*', null, null, 'B', null, 'N', null, null, null, user, sysdate, user, sysdate);
insert into ge_transacciones (cod_transaccion, cod_modulo, cod_modalidad, descripcion, ve_cliente, tipo, abreviatura, rutina1, rutina2, rutina3, cod_tip_asiento, cod_tasa, batch, cod_retencion, interno, afecta, cod_tip_asiento2, tip_despliegue, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values (3692, 4, 43, 'TRANSACCION DE DESCARGA - TED', 'S', 'D', 'TRXDES', 'PRA_ACT_SAL_BATCH', null, '*', null, null, 'B', null, 'N', null, null, null, user, sysdate, user, sysdate);

insert into ge_transacciones (cod_transaccion, cod_modulo, cod_modalidad, descripcion, ve_cliente, tipo, abreviatura, rutina1, rutina2, rutina3, cod_tip_asiento, cod_tasa, batch, cod_retencion, interno, afecta, cod_tip_asiento2, tip_despliegue, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values (3691, 4, 46, 'TRANSACCION DE CARGA - TED', 'S', 'C', 'TRXCAR', 'PRA_ACT_SAL_BATCH', null, null, null, null, 'B', null, 'N', 'S', null, null, user, sysdate, 'DVALDEZ', sysdate);
insert into ge_transacciones (cod_transaccion, cod_modulo, cod_modalidad, descripcion, ve_cliente, tipo, abreviatura, rutina1, rutina2, rutina3, cod_tip_asiento, cod_tasa, batch, cod_retencion, interno, afecta, cod_tip_asiento2, tip_despliegue, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values (3692, 4, 46, 'TRANSACCION DE DESCARGA - TED', 'S', 'D', 'TRXDES', 'PRA_ACT_SAL_BATCH', null, null, null, null, 'B', null, 'N', 'S', null, null, user, sysdate, 'DVALDEZ', sysdate);
insert into ge_transacciones (cod_transaccion, cod_modulo, cod_modalidad, descripcion, ve_cliente, tipo, abreviatura, rutina1, rutina2, rutina3, cod_tip_asiento, cod_tasa, batch, cod_retencion, interno, afecta, cod_tip_asiento2, tip_despliegue, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values (1125, 4, 46, 'TRANSACCION DE CARGA DESCARGA - TED', 'S', 'P', 'TRXTCD', null, null, null, null, null, 'O', null, 'N', 'N', null, null, user, sysdate, user, sysdate);


commit;
