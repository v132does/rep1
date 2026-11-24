create or replace force view it.rv_cr_comisiones as
select xx.cod_persona cod_persona,xx.nombre nombre,xx.documento documento,xx.oficial oficial,
 xx.nom_oficial nom_oficial, xx.fecha fecha,
 xx.fec_modificacion fec_modificacion,xx.usu_modificacion usu_modificacion,
 xx.cod_campana cod_campana,xx.descripcion descripcion,xx.cod_respuesta cod_respuesta,
 xx.det_res det_res,xx.fec_actividad fec_actividad,xx.det_actividad det_actividad,
 substr(xx.det_respuesta,1,300) det_respuesta
  from (select a.cod_persona as cod_persona,
               fue_obt_nom_persona(a.cod_persona) as nombre,
               fue_obt_nro_doc_persona(a.cod_persona) as documento,
               a.cod_usu_encargado oficial,
               fue_obt_nom_usuario(a.cod_usu_encargado) nom_oficial,
               a.fec_realizacion ,
               a.fec_modificacion as fecha,
               a.cod_campana,
               b.descripcion,
               a.det_respuesta,
               c.cod_respuesta,
               c.descripcion as det_res,
               a.fec_actividad,
               a.fec_modificacion,
               a.fec_ini_asignacion,
               a.usu_modificacion,a.det_actividad
          from cr_agendas a, cr_campanas b, cr_age_res_actividades c
         where a.cod_campana = b.cod_campana
           and c.cod_actividad = a.cod_actividad
           and c.cod_respuesta = a.cod_respuesta) xx
 where det_respuesta is not null
   --and xx.cod_respuesta='16'
union all
   select xx.cod_persona cod_persona,xx.nombre nombre,xx.documento documento,xx.oficial oficial,
   xx.nom_oficial nom_oficial,xx.fecha fecha,
   xx.fec_modificacion fec_modificacion,
   xx.usu_modificacion usu_modificacion,xx.cod_campana cod_campana,xx.descripcion descripcion,
   xx.cod_respuesta cod_respuesta,xx.det_res det_res,xx.fec_actividad fec_actividad,
   xx.det_actividad det_actividad,substr(xx.det_respuesta,1,300) det_respuesta
  from (select a.cod_persona as cod_persona,
               fue_obt_nom_persona(a.cod_persona) as nombre,
               fue_obt_nro_doc_persona(a.cod_persona) as documento,
               a.cod_usu_encargado oficial,
               fue_obt_nom_usuario(a.cod_usu_encargado) nom_oficial,
               a.fec_realizacion as fecha,
               a.cod_campana,
               b.descripcion,
               a.det_respuesta,
               c.cod_respuesta,
               c.descripcion as det_res,
               a.fec_actividad,
               a.fec_modificacion,
               a.fec_ini_asignacion,
               a.usu_modificacion,a.det_actividad
          from cr_agendas a, cr_campanas b, cr_age_res_actividades c
         where a.cod_campana = b.cod_campana
           and c.cod_actividad = a.cod_actividad
           and c.cod_respuesta = a.cod_respuesta
           ) xx
 where det_respuesta is null
   --and xx.cod_respuesta='16'
   and to_char(xx.fec_actividad,'yyyy')= to_char(sysdate,'yyyy')
;

