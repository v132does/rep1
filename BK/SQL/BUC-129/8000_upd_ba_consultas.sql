Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
UPDATE ba_consultas
SET    DET_SQL = 'SELECT b.nro_documento nro_documento,
       b.nom_completo  nom_completo,
       c.cod_moneda cod_moneda,
       to_char(c.fec_inicio,''dd/mm/yyyy'') fec_inicio,
       to_char(c.fec_vencimiento,''dd/mm/yyyy'') fec_vencimiento,
       c.mto_limite mto_limite,
       c.novedad novedad,
       c.fec_insercion fecha_modificacion,
       c.usu_modificacion usu_modificacion
  FROM cr_per_tip_operaciones_his c, ba_personas b
 WHERE c.cod_persona = b.cod_persona
   AND &'||'P_FILTROS
 UNION
 SELECT b.nro_documento nro_documento,
       b.nom_completo  nom_completo,
       c.cod_moneda cod_moneda,
       to_char(c.fec_inicio,''dd/mm/yyyy'') fec_inicio,
       to_char(c.fec_vencimiento,''dd/mm/yyyy'') fec_vencimiento,
       c.mto_limite mto_limite,
       ''ACTUAL'' novedad,
       c.fec_modificacion fecha_modificacion,
       c.usu_modificacion usu_modificacion
  FROM cr_per_tip_operaciones c, ba_personas b
 WHERE c.cod_persona = b.cod_persona
   AND &'||'P_FILTROS 
 ORDER BY 8'
WHERE COD_CONSULTA = 'CD_PER_HIS';

commit;
