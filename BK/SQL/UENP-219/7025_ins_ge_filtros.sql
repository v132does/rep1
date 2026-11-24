begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_filtros
  (cod_campo,
   descripcion,
   tip_campo,
   lon_campo,
   tip_dato,
   val_max_permitido,
   val_min_permitido,
   nom_tab_asociada,
   nom_referencia,
   nro_orden,
   det_sql,
   usu_insercion,
   fec_insercion,
   usu_modificacion,
   fec_modificacion,
   observacion,
   tipo,
   afe_segmentacion,
   afe_puntuacion,
   afe_reportes,
   afe_consultas,
   afe_reclamos,
   tip_sol_igual)
values
  ('EST_OFERTA',
   'Estado Oferta',
   'S',
   1,
   'V',
   null,
   null,
   null,
   'ESTADO',
   null,
   'select ''Ingresado'' Descripcion, ''I'' Codigo
  from dual
union
select ''Desembolsado'', ''D''
  from dual

union
select ''Vencido'', ''V''
  from dual
union
select ''En proceso'', ''G''
  from dual
union
select ''Rechazado'', ''R''
  from dual',
   user,
   sysdate,
   user,
  sysdate,
   'Ingrese Estado de Oferta',
   'G',
   'N',
   'N',
   'S',
   'S',
   'N',
   'N');

commit;

insert into ge_filtros (cod_campo, descripcion, tip_campo, lon_campo, tip_dato, val_max_permitido, val_min_permitido, nom_tab_asociada, nom_referencia, nro_orden, det_sql, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, observacion, tipo, afe_segmentacion, afe_puntuacion, afe_reportes, afe_consultas, afe_reclamos, tip_sol_igual)
values ('FEC_OFE', 'Fecha de Oferta', 'F', 10, 'R', null, null, null, 'FEC_OFERTA', null, null, 'VGONZALEZ', to_date('20-09-2023 15:38:38', 'dd-mm-yyyy hh24:mi:ss'), 'VGONZALEZ', to_date('20-09-2023 15:38:47', 'dd-mm-yyyy hh24:mi:ss'), null, 'G', 'N', 'S', 'S', 'S', 'N', 'N');
commit;
--insert into ge_filtros (cod_campo, descripcion, tip_campo, lon_campo, tip_dato, val_max_permitido, val_min_permitido, nom_tab_asociada, nom_referencia, nro_orden, det_sql, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, observacion, tipo, afe_segmentacion, afe_puntuacion, afe_reportes, afe_consultas, afe_reclamos, tip_sol_igual)
--values ('NRO_DOC_SO', 'Nro doc Solicitante', 'S', 40, 'R', null, null, null, 'NRO_DOC_SOLICITANTE', null, null, 'FDIAZDEVIV', to_date('16-03-2023 19:10:18', 'dd-mm-yyyy hh24:mi:ss'), 'FDIAZDEVIV', to_date('16-03-2023 19:10:18', 'dd-mm-yyyy hh24:mi:ss'), null, 'G', 'N', 'N', 'N', 'N', 'N', 'N');
commit;
