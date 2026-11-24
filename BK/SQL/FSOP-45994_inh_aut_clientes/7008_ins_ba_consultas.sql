BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_consultas (COD_CONSULTA, DESCRIPCION, TIPO, OBSERVACION, DET_SQL)
values ('CD_WF_INH', 'WF VERIFICACION OPERATIVA - INHIBICION CLIENTES', 'G', 'WF VERIFICACION OPERATIVA - INHIBICION DE CLIENTES POR CHEQUES DEVUELTOS', 
'SELECT trunc(c.fec_inicio) fecha, c.cod_tip_circuito||''-''||y.descripcion tip_circuito,
       c.cod_circuito, c.usu_insercion usu_solicitante,
       fue_obt_titulo(fue_obt_nom_usuario(c.usu_insercion)) nom_solicitante,
       t.cod_gru_responsable grupo_responsable,
       fue_obt_titulo(fuw_obt_des_grupo(t.cod_gru_responsable)) nom_grupo,
       t.cod_usuario usuario_responsable,
       decode(t.cod_usuario,NULL,NULL,fue_obt_titulo(fue_obt_nom_usuario(t.cod_usuario))) nom_responsable,
       c.referencia nro_cuenta, z.cod_persona, z.nom_completo nom_cliente,
       t.estado est_wf, t.comentario
  FROM wf_circuitos c, wf_cir_tareas t, wf_tip_circuitos y, ba_personas z
 WHERE c.cod_circuito = t.cod_circuito
   AND c.cod_tip_circuito = y.cod_tip_circuito
   AND c.cod_persona      = z.cod_persona  
   AND c.cod_tip_circuito IN (SELECT b.val_maximo FROM ba_cod_referencias b WHERE b.dominio = ''COD_WF_INH_PER'')
   and (&'||'P_FILTROS)
   ORDER BY c.cod_tip_circuito, t.cod_tarea');

insert into ba_consultas (COD_CONSULTA, DESCRIPCION, TIPO, OBSERVACION, DET_SQL)
values ('CD_INH_ERR', 'VERIFICACION DE ERRORES - INHIBICION CLIENTES', 'G', 'VERIFICACION DE ERRORES - INHIBICION DE CLIENTES POR CHEQUES DEVUELTOS', 
'SELECT g.fecha, g.cod_persona, g.nro_cuenta, g.det_error
FROM cc_log_errores g
WHERE cod_programa=''PRC_INH_CLI_CHE_DEVUELTOS''
AND (&'||'P_FILTROS)
ORDER BY g.fecha');

COMMIT;
