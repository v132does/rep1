Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_consultas (COD_CONSULTA, DESCRIPCION, COD_USUARIO, TIPO, PERMISO, OBSERVACION, DET_SQL)
values ('CD_SAL_ACU', 'CONSULTA SALDO ACUMULADO UMBRAL', NULL, 'P', NULL, 
'Saldo Acumulado Mensual de Clientes - Umbral.', 
'SELECT a.nro_documento nro_documento,
       a.nom_completo nom_completo,
       a.nro_cuenta nro_cuenta,
       a.fecha fecha,
       a.hora hora,
       a.cod_transaccion cod_transaccion,
       a.descripcion descripcion,
       a.cod_moneda cod_moneda,
       a.tot_credito tot_credito
  FROM gv_sal_acu_umbral a
 WHERE &'||'P_FILTROS
 ORDER BY 1, 4, 5');

commit;
