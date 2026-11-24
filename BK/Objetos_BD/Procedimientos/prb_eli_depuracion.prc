create or replace procedure it.PRB_ELI_DEPURACION is
--- Proceso de depuración de tablas para Optimización de espacio
--- Realizado por Ingrid Larraín - 07/10/2011
---
   v_fec_actual  ge_calendarios.fec_actual%type;
   Cursor c_eli_asi_aut is
   select fecha, cod_oficina, nro_asiento
     from cb_asi_automaticos
    where fecha < v_fec_actual;
   Cursor c_eli_asi_fut is
   select fecha, cod_oficina, nro_asiento
     from cb_asi_futuros
    where fecha < v_fec_actual;
     
begin
   v_fec_actual := add_months(pag_cal.FU_OBT_FEC_ACTUAL(2),-1);
   --- Eliminar asientos automáticos hasta un mes atras
   for reg in c_eli_asi_aut loop
       delete cb_asi_automaticos_det
        where fecha=reg.fecha
          and cod_oficina=reg.cod_oficina
          and nro_asiento=reg.nro_asiento;
       delete cb_asi_automaticos
        where fecha=reg.fecha
          and cod_oficina=reg.cod_oficina
          and nro_asiento=reg.nro_asiento;
   end loop;
   --- Eliminar asientos futuros hasta un mes atras
   for reg in c_eli_asi_fut loop
       delete cb_asi_futuros_det
        where fecha=reg.fecha
          and cod_oficina=reg.cod_oficina
          and nro_asiento=reg.nro_asiento;
       delete cb_asi_futuros
        where fecha=reg.fecha
          and cod_oficina=reg.cod_oficina
          and nro_asiento=reg.nro_asiento;
   end loop;
   --- Eliminar tabla temporal de asientos para importación
   delete cb_asi_cuadres_tmp;
   delete cb_asi_masivos_tmp;
end PRB_ELI_DEPURACION;
/

