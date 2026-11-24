Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
UPDATE ba_consultas
SET    DET_SQL = 'SELECT b.nro_documento nro_documento,
       b.nom_completo nom_completo,
       o.cod_moneda cod_moneda,
       to_char(o.fec_inicio, ''dd/mm/yyyy'') fec_inicio,
       to_char(o.fec_vencimiento, ''dd/mm/yyyy'') fec_vencimiento,
       o.mto_limite mto_limite,
       decode(o.novedad,''I'',''Inserción'',''E'',''Eliminación'',''M'',''Modificación'',''A'',''Actual'') novedad,
       to_char(o.fecha, ''dd/mm/yyyy'') fecha_modificacion,
       o.hora_modificacion hora_modificacion,
       o.usu_modificacion usu_modificacion,
       u.nombre usuario,
       a.descripcion area,
       f.tip_ope_otros otros_tip_operaciones
  FROM ba_personas b,
       ba_usuarios u,
       ba_areas    a,
       (SELECT c.cod_persona,
               c.cod_moneda cod_moneda,
               c.fec_inicio fec_inicio,
               c.fec_vencimiento fec_vencimiento,
               c.mto_limite mto_limite,
               c.novedad novedad,
               trunc(c.fec_insercion) fecha,
               to_char(c.fec_insercion, ''hh24:mi:ss'') hora_modificacion,
               c.usu_insercion usu_modificacion
          FROM cr_per_tip_operaciones_his c
        UNION
        SELECT c.cod_persona,
               c.cod_moneda cod_moneda,
               c.fec_inicio fec_inicio,
               c.fec_vencimiento fec_vencimiento,
               c.mto_limite mto_limite,
               ''A'' novedad,
               trunc(c.fec_modificacion) fecha,
               to_char(c.fec_modificacion, ''hh24:mi:ss'') hora_modificacion,
               c.usu_modificacion usu_modificacion
          FROM cr_per_tip_operaciones c) o,
          cr_inf_fondos f
 WHERE b.cod_persona = o.cod_persona
   AND u.cod_usuario = o.usu_modificacion
   AND u.cod_oficina = a.cod_oficina
   AND u.cod_area    = a.cod_area
   AND b.cod_persona = f.cod_persona(+)
   AND &'||'P_FILTROS 
 ORDER BY 1, 8, 9'
WHERE COD_CONSULTA = 'CD_PER_HIS';

commit;

