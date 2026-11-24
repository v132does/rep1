Begin 
  dbms_session.set_identifier('FSOP-63106');
  pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
end; 
/
insert into ba_consultas (COD_CONSULTA, DESCRIPCION, COD_USUARIO, TIPO, PERMISO, OBSERVACION, DET_SQL, FILTROS, COL_CORTES, COL_SUMAS)
values ('CD_CAUSAL', 'LISTADO CAUSALES', NULL, 'P', NULL, 'Listado general de códigos causales.', 
'SELECT g.cod_causa cod_causa, g.descripcion descripcion, g.tipo tipo, b.abreviatura tipo_desc
  FROM ge_causales g, ba_cod_referencias b
 WHERE g.tipo = b.val_minimo
   AND b.dominio = ''TIP_CAUSA''
   AND '||'&'||'P_FILTROS
 ORDER BY 1', NULL, NULL, NULL);
 
COMMIT;


