begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_consultas (COD_CONSULTA, DESCRIPCION, COD_USUARIO, TIPO, PERMISO, OBSERVACION, DET_SQL, FILTROS, COL_CORTES, COL_SUMAS)
values ('CD_BLO_CRE', 'Cuentas con Bloqueo de Crédito', 'UGENERICO', 'P', null, null, 
'select nro_cuenta, to_char(fec_bloqueo,''dd/mm/yyyy'') fec_bloqueo, cod_usu_bloqueo, b.cod_gru_transaccion||'' - ''|| t.descripcion gru_transaccion
  from ge_cta_blo_creditos b,
       ge_gru_transacciones t
 where b.cod_gru_transaccion = t.cod_gru_transaccion
   and nvl(b.estado,''D'') = ''B''
   and (&'||'P_FILTROS)', null, '1,2', null);

insert into ba_consultas (COD_CONSULTA, DESCRIPCION, COD_USUARIO, TIPO, PERMISO, OBSERVACION, DET_SQL, FILTROS, COL_CORTES, COL_SUMAS)
values ('CD_BLO_CRD', 'Detalle de Cuentas con Bloqueo de Crédito', 'UGENERICO', 'P', null, null, 
'select nro_cuenta, to_char(fec_bloqueo,''dd/mm/yyyy'') , cod_usu_bloqueo, b.cod_gru_transaccion||'' - ''||g.descripcion gru_transaccion,
       d.cod_modulo modulo, d.cod_modalidad modalidad, d.cod_transaccion||'' - ''||t.descripcion transacciones
  from ge_cta_blo_creditos b,
       ge_gru_transacciones g,
       ge_cta_blo_creditos_det d,
       ge_transacciones t
 where b.cod_gru_transaccion = g.cod_gru_transaccion
   and b.cod_blo_credito = d.cod_blo_credito
   and d.cod_transaccion = t.cod_transaccion
   and d.cod_modulo = t.cod_modulo
   and d.cod_modalidad = t.cod_modalidad
   and nvl(b.estado,''D'') = ''B''
   and (&'||'P_FILTROS)', null, '1,2,3,4,5,6', null);

commit;

