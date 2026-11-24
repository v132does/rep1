begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_arc_campos (referencia, nom_tabla, archivo, nro_secuencia, descripcion, tip_dato, formato, pos_inicial, longitud, pos_decimal, campo, funcion, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, saltar)
values ('PR_PRE_CHE_ROGA', 'PR_PRE_CHE_ROGA_TMP', 'PR_PLA_CHE_ROGA.XLS', 1, 'Nro.Oferta', 'VARCHAR2', null, 1, 10, null, 'NRO_OFERTA', 'to_char(replace($param,''.0'',''''))', user, sysdate, user, sysdate, null);

insert into ge_arc_campos (referencia, nom_tabla, archivo, nro_secuencia, descripcion, tip_dato, formato, pos_inicial, longitud, pos_decimal, campo, funcion, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, saltar)
values ('PR_PRE_CHE_ROGA', 'PR_PRE_CHE_ROGA_TMP', 'PR_PLA_CHE_ROGA.XLS', 2, 'Constructora.', 'VARCHAR2', null, 2, 100, null, 'CONSTRUCTORA', null, user, sysdate, user, sysdate, null);

insert into ge_arc_campos (referencia, nom_tabla, archivo, nro_secuencia, descripcion, tip_dato, formato, pos_inicial, longitud, pos_decimal, campo, funcion, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, saltar)
values ('PR_PRE_CHE_ROGA', 'PR_PRE_CHE_ROGA_TMP', 'PR_PLA_CHE_ROGA.XLS', 3, 'NombredelProyecto.', 'VARCHAR2', null, 3, 100, null, 'NOM_PROYECTO', null, user, sysdate, user, sysdate, null);

insert into ge_arc_campos (referencia, nom_tabla, archivo, nro_secuencia, descripcion, tip_dato, formato, pos_inicial, longitud, pos_decimal, campo, funcion, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, saltar)
values ('PR_PRE_CHE_ROGA', 'PR_PRE_CHE_ROGA_TMP', 'PR_PLA_CHE_ROGA.XLS', 4, 'TipodeProducto.', 'VARCHAR2', null, 4, 100, null, 'TIP_PRODUCTO', null, user, sysdate, user, sysdate, null);

insert into ge_arc_campos (referencia, nom_tabla, archivo, nro_secuencia, descripcion, tip_dato, formato, pos_inicial, longitud, pos_decimal, campo, funcion, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, saltar)
values ('PR_PRE_CHE_ROGA', 'PR_PRE_CHE_ROGA_TMP', 'PR_PLA_CHE_ROGA.XLS', 6, 'Nro.DocumentoSolicitante.', 'VARCHAR2', null, 5, 20, null, 'NRO_DOC_SOLICITANTE', 'to_char(replace($param,''.0'',''''))', user, sysdate, user, sysdate, null);

insert into ge_arc_campos (referencia, nom_tabla, archivo, nro_secuencia, descripcion, tip_dato, formato, pos_inicial, longitud, pos_decimal, campo, funcion, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, saltar)
values ('PR_PRE_CHE_ROGA', 'PR_PRE_CHE_ROGA_TMP', 'PR_PLA_CHE_ROGA.XLS', 12, 'PtoEquilibrio.', 'VARCHAR2', null, 25, 15, null, 'PTO_EQUILIBRIO', null, user, sysdate, user, sysdate, null);

insert into ge_arc_campos (referencia, nom_tabla, archivo, nro_secuencia, descripcion, tip_dato, formato, pos_inicial, longitud, pos_decimal, campo, funcion, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, saltar)
values ('PR_PRE_CHE_ROGA', 'PR_PRE_CHE_ROGA_TMP', 'PR_PLA_CHE_ROGA.XLS', 14, 'MontoTotal.', 'VARCHAR2', null, 11, 18, 2, 'MTO_TOTAL', null, user, sysdate, user, sysdate, null);

insert into ge_arc_campos (referencia, nom_tabla, archivo, nro_secuencia, descripcion, tip_dato, formato, pos_inicial, longitud, pos_decimal, campo, funcion, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, saltar)
values ('PR_PRE_CHE_ROGA', 'PR_PRE_CHE_ROGA_TMP', 'PR_PLA_CHE_ROGA.XLS', 15, 'MontoCuota.', 'VARCHAR2', null, 12, 18, 2, 'MTO_CUOTA', null, user, sysdate, user, sysdate, null);

insert into ge_arc_campos (referencia, nom_tabla, archivo, nro_secuencia, descripcion, tip_dato, formato, pos_inicial, longitud, pos_decimal, campo, funcion, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, saltar)
values ('PR_PRE_CHE_ROGA', 'PR_PRE_CHE_ROGA_TMP', 'PR_PLA_CHE_ROGA.XLS', 16, 'MontoProyecto.', 'VARCHAR2', null, 13, 18, 2, 'MTO_PROYECTO', null, user, sysdate, user, sysdate, null);

insert into ge_arc_campos (referencia, nom_tabla, archivo, nro_secuencia, descripcion, tip_dato, formato, pos_inicial, longitud, pos_decimal, campo, funcion, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, saltar)
values ('PR_PRE_CHE_ROGA', 'PR_PRE_CHE_ROGA_TMP', 'PR_PLA_CHE_ROGA.XLS', 17, 'MontoEquipamiento.', 'VARCHAR2', null, 14, 18, 2, 'MTO_EQUIPAMIENTO', null, user, sysdate, user, sysdate, null);

insert into ge_arc_campos (referencia, nom_tabla, archivo, nro_secuencia, descripcion, tip_dato, formato, pos_inicial, longitud, pos_decimal, campo, funcion, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, saltar)
values ('PR_PRE_CHE_ROGA', 'PR_PRE_CHE_ROGA_TMP', 'PR_PLA_CHE_ROGA.XLS', 18, 'MontoGarantia.', 'VARCHAR2', null, 12, 18, 2, 'MTO_GARANTIA', null, user, sysdate, user, sysdate, null);

insert into ge_arc_campos (referencia, nom_tabla, archivo, nro_secuencia, descripcion, tip_dato, formato, pos_inicial, longitud, pos_decimal, campo, funcion, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, saltar)
values ('PR_PRE_CHE_ROGA', 'PR_PRE_CHE_ROGA_TMP', 'PR_PLA_CHE_ROGA.XLS', 19, 'MontoNotario.', 'VARCHAR2', null, 12, 18, 2, 'MTO_NOTARIO', null, user, sysdate, user, sysdate, null);

insert into ge_arc_campos (referencia, nom_tabla, archivo, nro_secuencia, descripcion, tip_dato, formato, pos_inicial, longitud, pos_decimal, campo, funcion, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, saltar)
values ('PR_PRE_CHE_ROGA', 'PR_PRE_CHE_ROGA_TMP', 'PR_PLA_CHE_ROGA.XLS', 20, 'MontoTasacion.', 'VARCHAR2', null, 12, 18, 2, 'MTO_TASACION', null, user, sysdate, user, sysdate, null);

insert into ge_arc_campos (referencia, nom_tabla, archivo, nro_secuencia, descripcion, tip_dato, formato, pos_inicial, longitud, pos_decimal, campo, funcion, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, saltar)
values ('PR_PRE_CHE_ROGA', 'PR_PRE_CHE_ROGA_TMP', 'PR_PLA_CHE_ROGA.XLS', 21, 'GastosADM.', 'VARCHAR2', null, 12, 18, 2, 'MTO_ADM_GASTOS', null, user, sysdate, user, sysdate, null);

insert into ge_arc_campos (referencia, nom_tabla, archivo, nro_secuencia, descripcion, tip_dato, formato, pos_inicial, longitud, pos_decimal, campo, funcion, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, saltar)
values ('PR_PRE_CHE_ROGA', 'PR_PRE_CHE_ROGA_TMP', 'PR_PLA_CHE_ROGA.XLS', 22, 'MontoCuotaConstruccion.', 'VARCHAR2', null, 12, 18, 2, 'MTO_CUO_CONTRUCCION', null, user, sysdate, user, sysdate, null);

insert into ge_arc_campos (referencia, nom_tabla, archivo, nro_secuencia, descripcion, tip_dato, formato, pos_inicial, longitud, pos_decimal, campo, funcion, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, saltar)
values ('PR_PRE_CHE_ROGA', 'PR_PRE_CHE_ROGA_TMP', 'PR_PLA_CHE_ROGA.XLS', 23, 'CantidaddeCuotas.', 'VARCHAR2', null, 15, 5, null, 'CAN_CUOTAS', 'to_char(replace($param,''.0'',''''))', user, sysdate, user, sysdate, null);

insert into ge_arc_campos (referencia, nom_tabla, archivo, nro_secuencia, descripcion, tip_dato, formato, pos_inicial, longitud, pos_decimal, campo, funcion, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, saltar)
values ('PR_PRE_CHE_ROGA', 'PR_PRE_CHE_ROGA_TMP', 'PR_PLA_CHE_ROGA.XLS', 24, 'Equipamiento', 'VARCHAR2', null, 25, 20, null, 'EQUIPAMIENTO', null, user, sysdate, user, sysdate, null);

insert into ge_arc_campos (referencia, nom_tabla, archivo, nro_secuencia, descripcion, tip_dato, formato, pos_inicial, longitud, pos_decimal, campo, funcion, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, saltar)
values ('PR_PRE_CHE_ROGA', 'PR_PRE_CHE_ROGA_TMP', 'PR_PLA_CHE_ROGA.XLS', 26, 'Detalle1.', 'VARCHAR2', null, 18, 100, null, 'DETALLE_1', null, user, sysdate, user, sysdate, null);

insert into ge_arc_campos (referencia, nom_tabla, archivo, nro_secuencia, descripcion, tip_dato, formato, pos_inicial, longitud, pos_decimal, campo, funcion, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, saltar)
values ('PR_PRE_CHE_ROGA', 'PR_PRE_CHE_ROGA_TMP', 'PR_PLA_CHE_ROGA.XLS', 28, 'Ubicaciondelavivienda.', 'VARCHAR2', null, 19, 100, null, 'UBI_VIVIENDA', null, user, sysdate, user, sysdate, null);

insert into ge_arc_campos (referencia, nom_tabla, archivo, nro_secuencia, descripcion, tip_dato, formato, pos_inicial, longitud, pos_decimal, campo, funcion, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, saltar)
values ('PR_PRE_CHE_ROGA', 'PR_PRE_CHE_ROGA_TMP', 'PR_PLA_CHE_ROGA.XLS', 31, 'Fechadesolicitud.', 'VARCHAR2', null, 21, 10, null, 'FEC_OFERTA', 'to_date(Replace($param,''-'',''/''),''yyyy/mm/dd hh24:mi:ss'')', user, sysdate, user, sysdate, null);

insert into ge_arc_campos (referencia, nom_tabla, archivo, nro_secuencia, descripcion, tip_dato, formato, pos_inicial, longitud, pos_decimal, campo, funcion, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, saltar)
values ('PR_PRE_CHE_ROGA', 'PR_PRE_CHE_ROGA_TMP', 'PR_PLA_CHE_ROGA.XLS', 32, 'Estado', 'VARCHAR2', null, 25, 50, null, 'ESTADO', null, user, sysdate, user, sysdate, null);

insert into ge_arc_campos (referencia, nom_tabla, archivo, nro_secuencia, descripcion, tip_dato, formato, pos_inicial, longitud, pos_decimal, campo, funcion, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, saltar)
values ('PR_PRE_CHE_ROGA', 'PR_PRE_CHE_ROGA_TMP', 'PR_PLA_CHE_ROGA.XLS', 33, 'Fechadevencimiento.', 'VARCHAR2', null, 23, 10, null, 'FEC_VENCIMIENTO', 'to_date(Replace($param,''-'',''/''),''yyyy/mm/dd hh24:mi:ss'')', user, sysdate, user, sysdate, null);

insert into ge_arc_campos (referencia, nom_tabla, archivo, nro_secuencia, descripcion, tip_dato, formato, pos_inicial, longitud, pos_decimal, campo, funcion, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, saltar)
values ('PR_PRE_CHE_ROGA', 'PR_PRE_CHE_ROGA_TMP', 'PR_PLA_CHE_ROGA.XLS', 34, 'Nro.DocumentoInvitado.', 'VARCHAR2', null, 25, 20, null, 'NRO_DOC_INVITADO', 'to_char(replace($param,''.0'',''''))', user, sysdate, user, sysdate, null);

insert into ge_arc_campos (referencia, nom_tabla, archivo, nro_secuencia, descripcion, tip_dato, formato, pos_inicial, longitud, pos_decimal, campo, funcion, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, saltar)
values ('PR_PRE_CHE_ROGA', 'PR_PRE_CHE_ROGA_TMP', 'PR_PLA_CHE_ROGA.XLS', 30, 'Dimension', 'VARCHAR2', null, 25, 10, null, 'Dimension', null, 'VGONZALEZ', to_date('09-04-2024 13:39:11', 'dd-mm-yyyy hh24:mi:ss'), 'VGONZALEZ', to_date('09-04-2024 13:39:11', 'dd-mm-yyyy hh24:mi:ss'), null);

commit;
