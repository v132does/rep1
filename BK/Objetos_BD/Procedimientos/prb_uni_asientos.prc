CREATE OR REPLACE PROCEDURE IT.PRB_UNI_ASIENTOS is
   /* union de asientos automaticos */
   v_fec_actual     date      := pag_cal.fu_obt_fec_actual(2);
   v_nro_asiento       NUMBER;
cursor asi is
   SELECT FECHA, COD_OFICINA, NRO_ASIENTO, ROWID FILA
     FROM CB_ASI_AUTOMATICOS
    WHERE FECHA = v_fec_actual  --debe tomar todos, af hace como cualquier modulo VC 3-11-2010
    /*and  (cod_modulo <> 13
       or(cod_modulo = 13 and nro_asi_real is null))*/;

begin
  -- borro los asientos unidos anteriormente
   DELETE FROM  CB_ASIENTOS_DET
          WHERE NRO_ASIENTO IN (SELECT NRO_ASIENTO
                                FROM   CB_ASIENTOS
                                WHERE  COD_MODULO not in (2));
   DELETE FROM  CB_ASIENTOS
          WHERE COD_MODULO not in (2);
   --
   v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
   FOR a in asi LOOP
     -- Se agregan nuevos datos el 07/10/2011 para dejar como backup del asiento automatico en el asiento real
     -- Realizado por Ingrid Larrain para optimizacion de espacio
     -- inserto la cabecera
     insert into cb_asientos
           (cod_oficina, nro_asiento, cod_usuario, fecha,
            cod_modulo, cod_modalidad,
            tot_control, actualizado, reversado, cod_ofi_origen,
            ofi_integrada, confirmado, fec_valor, nro_asi_automatico)
     select cod_oficina, v_nro_asiento, cod_usuario, fecha,
            cod_modulo, cod_modalidad,
            tot_control, actualizado, reversado, cod_ofi_origen,
            ofi_integrada, confirmado, nvl(fec_valor, fecha), nro_asiento
       from cb_asi_automaticos
      where cod_oficina = a.cod_oficina
        and nro_asiento = a.nro_asiento
        and fecha = v_fec_actual;
     -- actualizo el registro leido
     update cb_asi_automaticos
        set nro_asi_real = v_nro_asiento
      where /*rowid = a.fila;*/
            FECHA = A.FECHA
      AND   COD_OFICINA = A.COD_OFICINA
      AND   NRO_ASIENTO = a.nro_asiento/*
      and  (cod_modulo <> 13
         or(cod_modulo = 13 and nro_asi_real is null))*/;
     -- inserto los detalles de los asientos
     insert into cb_asientos_det
           (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro,
            tip_movimiento, mto_mon_rubro, mto_mon_local,
            descripcion, referencia, protegido, actualizado,
            val_cotizacion, distribuido, ref_movimiento, fec_valor)
     select fecha, cod_oficina, v_nro_asiento, nro_linea, cod_rubro,
            tip_movimiento, mto_mon_rubro, mto_mon_local,
            descripcion, referencia, protegido, actualizado,
            val_cotizacion, distribuido, ref_movimiento, nvl(fec_valor, fecha)
       from cb_asi_automaticos_det
      where cod_oficina = a.cod_oficina
        and nro_asiento = a.nro_asiento
        and fecha = v_fec_actual;
     -- incrementa numero de asiento
     if v_nro_asiento >= 999999 then
        v_nro_asiento := 0;
     end if;
     v_nro_asiento := v_nro_asiento + 1;
   END LOOP;
   ------- ACTUALIZA PARAMETROS -----
   prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, v_nro_asiento);
exception
   when others then
      if sqlcode <= -20000 then
         raise;
      else
         raise_application_error(-20000,'Error.PRB_UNI_ASIENTOS - '||sqlerrm);
      end if;
end;
/

