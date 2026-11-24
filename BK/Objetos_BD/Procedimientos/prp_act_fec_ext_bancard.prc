CREATE OR REPLACE PROCEDURE IT.PRP_ACT_FEC_EXT_BANCARD
 IS
BEGIN
   update ge_procesos_aut a
   set    a.prox_ejecucion = null,
          a.ult_ejecucion = null,
          a.est_ult_eje = null,
          a.hash_dato = null,
          a.hash_proc = null
   where  a.cod_proceso = (fug_obt_pardinamico('PROCESOS_AUT')) ;
   if sql%notfound then
      raise_application_error(-20000,
      'El Proceso No Puede ser Actualizado');
   end if;
END;
/

