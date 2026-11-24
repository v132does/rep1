Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
update ba_consultas
set    det_sql =
'select t.fec_inicio , t.fec_vencimiento , t.cod_causa , c.descripcion desc_causa,t.usu_insercion usuario,
      (case when add_months(t.fec_inicio,1) =  trunc(sysdate) then
          ''A cancelar en el dia''
          when (trunc(sysdate) - t.fec_inicio) > 30 and  (trunc(sysdate) - t.fec_inicio) < 46 then
          ''Pendiente de cancelar''
          when (trunc(sysdate) - t.fec_inicio)  > 45 then
          ''No canceladas por algun motivo''
      end) as observacion,
      cc.sal_total,
  (case when cc.sal_total < 0 then cc.cod_moneda end) as moneda , tip.abreviatura tipo_doc, p.nro_documento, cc.denominacion as denominacion
  from  GE_PER_INHIBIDAS t , ge_causales c , ge_cta_clientes ct , cc_cta_corrientes cc, ba_personas p, ba_tip_documentos tip
  where t.cod_causa = c.cod_causa
  and  t.cod_causa in (246,247,248,249,250)
  and  t.estado = ''I''
  and  ct.relacion = ''P''
  and  t.cod_persona = ct.cod_persona
  and  ct.cod_modulo = cc.cod_modulo
  and  ct.Cod_Modalidad = cc.cod_modalidad
  and  ct.nro_cuenta = cc.nro_cuenta
  and  cc.estado <> ''C''
  and  t.fec_inicio < add_months(trunc(sysdate),-1)
  and  t.cod_persona = p.cod_persona
  and  p.cod_tip_documento = tip.cod_tip_documento(+)
  and ('||'&'||'P_FILTROS)
order by t.fec_inicio desc',
   filtros = 'NULL'
where cod_consulta='CANC_CTA';

commit;