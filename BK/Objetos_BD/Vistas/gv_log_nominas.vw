CREATE OR REPLACE FORCE VIEW IT.GV_LOG_NOMINAS AS
SELECT a.nro_cuenta,
       to_char(a.fecha,'dd/mm/yyyy')Fecha,
       decode(a.cod_error, NULL, 'Advertencia', 'Error') Tipo,
       a.descripcion,
       decode(a.cod_ent_desv,null,'N','S') desvinculada, a.cod_ent_desv
  FROM ge_log_pag_nominas a;

