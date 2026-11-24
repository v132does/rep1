begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end; 
/
--
insert into ba_consultas (COD_CONSULTA, DESCRIPCION, COD_USUARIO, TIPO, PERMISO, OBSERVACION, DET_SQL, FILTROS, COL_CORTES, COL_SUMAS, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values ('PRODEPLOG', 'CONSULTA DE LOG DE PRODEP CONECTOR DEPOSITO', 'RBARRIOS', 'P', 'CAJERO', 'Log de ejecucion del Conector deposito al finalizar el escaneo de los cheques', 'select nro_referencia, trunc(fec_insercion) as fecha, fec_insercion, usu_insercion, mensaje, estado, nro_ref_dep, nro_cuenta, cod_mon_iso, mon_total, can_cheques, cod_oficina, dia, estado_prodep, tip_conector from it.cj_log_prodep
where ('||'&'||'P_FILTROS)', 'ROWNUM IS NOT NULL', null, null, 'RBARRIOS', to_date('28-12-2023 08:49:29', 'dd-mm-yyyy hh24:mi:ss'), 'RBARRIOS', to_date('28-12-2023 09:52:53', 'dd-mm-yyyy hh24:mi:ss'));

commit;
/
