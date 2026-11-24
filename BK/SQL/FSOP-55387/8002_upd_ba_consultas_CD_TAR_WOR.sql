declare
v_consulta varchar2(8000) := 'select cod_circuito Nro_Circuito,
Nombre_Cliente,
 COD_TIP_CIRCUITO Tipo_Circuito,
 Nombre_circuito,
 Cód_Tip_Tarea,
 Tipo_Tarea,
 Grupo_Tarea,
 fec_asignacion Fecha_Asignacion,
 fec_finalizacion Fecha_finalizacion_tarea,
 Estado_Tarea,
 cod_usu_responsable Usuario_Responsable,
 usu_modificacion Usuario_Modificacion,
 Hora,
 NRO_DOC,
 substr(comentario,1,300)comentario,
 observacion,
 fue_obt_tel_principa(cod_persona) Tel_Principal
  from (select c.cod_circuito,
   p.cod_persona,p.nom_completo Nombre_Cliente,
   C.COD_TIP_CIRCUITO,
   c.descripcion Nombre_circuito,
   t.cod_tip_tarea Cód_Tip_Tarea,
   ta.descripcion Tipo_Tarea,
   g.descripcion Grupo_Tarea,
   trunc(t.fec_asignacion) fec_asignacion,
   trunc(t.fec_finalizacion) fec_finalizacion,
   decode(t.estado,''P'', ''Pendiente'', ''A'',''Aprobado'',''R'',''Rechazado'', ''C'',''Cancelado'') Estado_Tarea,
   t.cod_usuario cod_usu_responsable,
   t.usu_modificacion,
   to_char(fec_asignacion,''hh24:mi:ss'') Hora,
   nro_documento NRO_DOC,
   comentario,
   null observacion
    from wf_circuitos c,
   wf_cir_tareas     t,
   ba_personas p,
   wf_grupos   g,
   wf_gru_usuarios   u,
   wf_tip_cir_tareas ta
   where c.cod_circuito = t.cod_circuito
     and c.cod_tip_circuito = t.cod_tip_circuito
     and c.cod_persona = p.cod_persona
     and t.cod_tip_circuito = ta.cod_tip_circuito
     and t.cod_tip_tarea = ta.cod_tip_tarea
     and t.cod_usu_responsable = u.cod_usuario(+)
     and t.cod_gru_responsable = u.cod_grupo(+)
     and g.cod_grupo(+) = u.cod_grupo
     and c.cod_tip_circuito!=48
     union
     select c.cod_circuito,
   p.cod_persona,p.nom_completo Nombre_Cliente,
   C.COD_TIP_CIRCUITO,
   c.descripcion Nombre_circuito,
   t.cod_tip_tarea Cód_Tip_Tarea,
   ta.descripcion Tipo_Tarea,
   g.descripcion Grupo_Tarea,
   trunc(t.fec_asignacion) fec_asignacion,
   trunc(t.fec_finalizacion) fec_finalizacion,
   decode(t.estado,''P'', ''Pendiente'', ''A'',''Aprobado'',''R'',''Rechazado'', ''C'', ''Cancelado'') Estado_Tarea,
   t.cod_usuario cod_usu_responsable,
   t.usu_modificacion,
   to_char(nvl(c.fec_fin,t.fec_asignacion),''hh24:mi:Ss'') Hora,
   nro_documento NRO_DOC,
   comentario,
   ima.observacion
    from wf_circuitos c,
   wf_cir_tareas     t,
   ba_personas p,
   wf_grupos   g,
   wf_gru_usuarios   u,
   wf_tip_cir_tareas ta,
   ba_per_ima_documentos ima
   where c.cod_circuito = t.cod_circuito
     and c.cod_tip_circuito = t.cod_tip_circuito
     and c.cod_persona = p.cod_persona
     and t.cod_tip_circuito = ta.cod_tip_circuito
     and t.cod_tip_tarea = ta.cod_tip_tarea
     and t.cod_usu_responsable = u.cod_usuario(+)
     and t.cod_gru_responsable = u.cod_grupo(+)
     and g.cod_grupo(+) = u.cod_grupo
     and c.cod_tip_circuito in (3,48)
     and c.cod_persona=ima.cod_persona(+)
     and ima.cod_tip_documento(+) = 64
     and ta.cod_tip_tarea = (select max(a.cod_tip_tarea)
from wf_cir_tareas a
 where a.cod_circuito = c.cod_circuito
    and a.cod_tip_circuito = c.cod_tip_circuito)
union
     select c.cod_circuito,
   p.cod_persona,p.nom_completo Nombre_Cliente,
   C.COD_TIP_CIRCUITO,
   c.descripcion Nombre_circuito,
   t.cod_tip_tarea Cód_Tip_Tarea,
   ta.descripcion Tipo_Tarea,
   g.descripcion Grupo_Tarea,
   trunc(t.fec_asignacion) fec_asignacion,
   trunc(t.fec_finalizacion) fec_finalizacion,
   decode(t.estado,''P'', ''Pendiente'', ''A'',''Aprobado'',''R'',''Rechazado'', ''C'', ''Cancelado'') Estado_Tarea,
   t.cod_usuario cod_usu_responsable,
   t.usu_modificacion,
   to_char(nvl(c.fec_fin,t.fec_asignacion),''hh24:mi:Ss'') Hora,
   nro_documento NRO_DOC,
   comentario,
   ima.observacion
    from wf_circuitos c,
   wf_cir_tareas     t,
   ba_personas p,
   wf_grupos   g,
   wf_gru_usuarios   u,
   wf_tip_cir_tareas ta,
   ba_per_ima_documentos ima
   where c.cod_circuito = t.cod_circuito
     and c.cod_tip_circuito = t.cod_tip_circuito
     and c.cod_persona = p.cod_persona
     and t.cod_tip_circuito = ta.cod_tip_circuito
     and t.cod_tip_tarea = ta.cod_tip_tarea
     and t.cod_usu_responsable = u.cod_usuario(+)
     and t.cod_gru_responsable = u.cod_grupo(+)
     and g.cod_grupo(+) = u.cod_grupo
     and c.cod_tip_circuito in (3,48)
     and c.cod_persona=ima.cod_persona(+)
     and ima.cod_tip_documento(+) = 64
     and ta.cod_tip_tarea = 1
     And t.estado = ''R''
     )WHERE &'||'P_FILTROS';
Begin 
  
  pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; 

update ba_consultas
set    det_sql = v_consulta,
       filtros = 'NULL'
where cod_consulta='CD_TAR_WOR';

delete from ba_par_consultas where cod_consulta = 'CD_TAR_WOR' and cod_campo='PERSONA';

commit;

end;



     
     
