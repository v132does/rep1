Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_consultas (COD_CONSULTA, DESCRIPCION, COD_USUARIO, TIPO, PERMISO, OBSERVACION, DET_SQL)
values ('CD_AUT_UMB', 'CONSULTA PEDIDOS DE AUTORIZACION UMBRAL', NULL, 'P', NULL, 
'Pedidos de Autorización de depósitos por superar Umbral', 
'SELECT g.nro_cuenta nro_cuenta,
       g.cod_persona cod_persona,
       fue_obt_nom_persona(g.cod_persona) nombre,
       g.fecha fecha,
       g.hora hora,
       g.cod_usuario cod_usuario,
       g.monto_loa monto_loa,
       g.monto_acumulado monto_acumulado,
       g.monto_total monto_total,
       g.cod_usu_autorizador cod_usu_autorizador,
       g.fec_hor_autorizacion fec_hor_autorizacion,
       decode(g.estado,''S'',''Solicitado'',''C'',''Confirmado'',''A'',''Rechazado'') estado,
       g.observacion observacion
  FROM ge_aut_umbral g
 WHERE &'||'P_FILTROS
 ORDER BY 4,5');

commit;
