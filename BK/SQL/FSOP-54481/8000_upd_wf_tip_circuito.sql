BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
UPDATE wf_tip_circuitos
SET    DET_SQL = 'SELECT ''Nro. Referencia: ''||chr(9)||p.cod_persona C1
       ,''Cliente : ''||chr(9)||chr(9)||chr(9)||p.cod_persona||'' ''||fue_obt_nom_persona(p.cod_persona) C2
       ,''Tipo : ''||chr(9)||chr(9)||chr(9)||decode(tipo, ''F'',''Física'', ''Jurídica'') C3
       ,''Nro. documento: ''||nro_documento C4
       ,(SELECT ''Monto Límite: ''||h.mto_limite||''(''||h.novedad||'')''||chr(10)||
       ''Fecha Inicio: ''||to_char(h.fec_inicio,''dd/mm/yyyy'')||chr(10)||
       ''Fecha Vto: ''||to_char(h.fec_vencimiento,''dd/mm/yyyy'') 
       FROM cr_per_tip_operaciones_his h 
       WHERE h.cod_persona = p.cod_persona 
       AND   h.cod_circuito = (select max(e.cod_circuito) from cr_per_tip_operaciones_his e where e.cod_persona = h.cod_persona)) C5
 FROM ba_personas p, CR_ACT_ESPERADAS a, CR_PER_TIP_OPERACIONES t
  WHERE p.cod_persona = a.cod_persona(+)
    AND p.cod_persona = t.cod_persona(+)
    AND p.cod_persona = ''&'||'REFERENCIA''
    and rownum = 1'
 WHERE cod_tip_circuito = 600;

COMMIT;   
