CREATE OR REPLACE PROCEDURE IT.PRG_INI_PROPA_CIEDIA
 IS
BEGIN
   update ge_procesos
   set hor_inicio = null, hor_fin = null, cod_usuario = null, error = null
   where tipo = 'F'
   and cod_proceso not in (311,320); -- Cierre de contabilidad es independiente
   update ge_procesos_det d
   set d.hor_inicio = null, d.hor_fin = null, d.cod_usuario = null, error = null
   where exists (select 1
                   from ge_procesos p
                  where p.cod_proceso = d.cod_proceso
                    and p.tipo = 'F')
   and cod_proceso not in (311,320); -- Cierre de contabilidad es independiente
END;
/

