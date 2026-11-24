create or replace procedure it.prf_uni_asientos is
   /* union de asientos automaticos */
   v_fec_actual     date      := pag_cal.fu_obt_fec_actual(13);
   v_nro_asiento    NUMBER;

cursor asi is
   SELECT FECHA, COD_OFICINA, NRO_ASIENTO, ROWID FILA
     FROM CB_ASI_AUTOMATICOS
    WHERE FECHA = v_fec_actual
      and cod_modulo = 13
      and nro_asi_real is null;

begin
   --
   v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
   FOR a in asi LOOP
     -- inserto la cabecera
     insert into cb_asientos
           (cod_oficina, nro_asiento, cod_usuario, fecha,
            cod_modulo, cod_modalidad,
            tot_control, actualizado, reversado, cod_ofi_origen,
            ofi_integrada, confirmado)
     select cod_oficina, v_nro_asiento, cod_usuario, fecha,
            cod_modulo, cod_modalidad,
            tot_control, actualizado, reversado, cod_ofi_origen,
            ofi_integrada, confirmado
       from cb_asi_automaticos
      where cod_oficina = a.cod_oficina
        and nro_asiento = a.nro_asiento
        and cod_modulo  = 13
        and fecha = v_fec_actual;
     -- actualizo el registro leido
     update cb_asi_automaticos
        set nro_asi_real = v_nro_asiento
      where FECHA = A.FECHA
      AND   COD_OFICINA = A.COD_OFICINA
      AND   NRO_ASIENTO = a.nro_asiento
      and   cod_modulo  = 13
      and   nro_asi_real is null;
            --rowid = a.fila;
     -- inserto los detalles de los asientos
   
    insert into cb_asientos_det
           (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro,
            tip_movimiento, mto_mon_rubro, mto_mon_local,
            descripcion, referencia, protegido, actualizado,
            val_cotizacion, distribuido, ref_movimiento)
     select fecha, cod_oficina, v_nro_asiento, nro_linea, cod_rubro,
            tip_movimiento, mto_mon_rubro, mto_mon_local,
            descripcion, referencia, protegido, actualizado,
            val_cotizacion, distribuido, ref_movimiento
       from cb_asi_automaticos_det
      where cod_oficina = a.cod_oficina
        and nro_asiento = a.nro_asiento
        and cod_modulo  = 13
        and fecha = v_fec_actual;
        
     -- incrementa numero de asiento
     v_nro_asiento := v_nro_asiento + 1;
  
   END LOOP;
   ------- ACTUALIZA PARAMETROS -----
   prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, v_nro_asiento);
exception 
  when others then    
    raise_application_error(-20000, ' Error  ' || sqlerrm);
end;
/

