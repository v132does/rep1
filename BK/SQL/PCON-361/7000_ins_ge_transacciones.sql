begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_transacciones (cod_transaccion, cod_modulo, cod_modalidad, descripcion, ve_cliente, tipo, abreviatura, rutina1, rutina2, rutina3, cod_tip_asiento, cod_tasa, batch, cod_retencion, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, interno, afecta, cod_tip_asiento2, detallado, cod_tip_asi_resultado, tip_despliegue)
values (703, 6, 668, 'COMISION FOGAPY', 'N', 'D', 'GASTVA', null, null, null, 3831, 340, 'B', null, user, sysdate, user, sysdate, 'N', 'G', null, 'N', null, null);

commit;

insert into ge_transacciones_det (cod_transaccion, cod_modulo, cod_modalidad, cod_tra_hijo, cod_mod_hijo, cod_mad_hijo, nro_orden, obligatorio, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values (358, 6, 668, 703, 6, 668, 6, 'S', user, sysdate, user, sysdate);

commit;
