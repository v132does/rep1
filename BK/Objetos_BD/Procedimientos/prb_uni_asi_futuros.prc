CREATE OR REPLACE PROCEDURE IT.PRB_UNI_ASI_FUTUROS is
   /* union de asientos futuros */
   v_fec_actual     date      := pag_cal.fu_obt_fec_actual(2);
   v_nro_asiento    NUMBER;
   v_procesar       VARCHAR2(1) := 'N';
   v_existe         VARCHAR2(1) := 'S';
cursor asi is
   SELECT COD_OFICINA, NRO_ASIENTO, COD_CARGO, FECHA, ROWID FILA
     FROM CB_ASI_FUTUROS
    WHERE FECHA <= v_fec_actual
    and nro_asi_real is null;

begin
   pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
   v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
   FOR a in asi LOOP
     -- Se agregan nuevos datos el 07/10/2011 para dejar como backup del asiento futuro el asiento real
     -- Realizado por Ingrid Larraín para optimización de espacio
     -- inserto la cabecera
     insert into cb_asientos
           (cod_oficina, nro_asiento, cod_usuario, fecha,
            cod_modulo, cod_modalidad,
            tot_control, actualizado, reversado, cod_ofi_origen,
            ofi_integrada, confirmado, fec_valor, nro_asi_futuro, cod_cargo)
     select cod_oficina, v_nro_asiento, cod_usuario, v_fec_actual,
            cod_modulo, cod_modalidad,
            tot_control, actualizado, reversado, cod_ofi_origen,
            ofi_integrada, confirmado, fecha, nro_asiento, cod_cargo
       from cb_asi_futuros
      where cod_oficina = a.cod_oficina
        and nro_asiento = a.nro_asiento
        and nro_asi_real is null
        and fecha = a.fecha;
     -- actualizo el registro leido
     update cb_asi_futuros
        set nro_asi_real = v_nro_asiento
      where rowid = a.fila;
     -- inserto los detalles de los asientos
     insert into cb_asientos_det
           (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro,
            tip_movimiento, mto_mon_rubro, mto_mon_local,
            descripcion, referencia, protegido, actualizado,
            val_cotizacion, distribuido, ref_movimiento, fec_valor)
     select v_fec_actual, cod_oficina, v_nro_asiento, nro_linea, cod_rubro,
            tip_movimiento, mto_mon_rubro, mto_mon_local,
            descripcion, referencia, protegido, actualizado,
            val_cotizacion, distribuido, ref_movimiento, fecha
       from cb_asi_futuros_det
      where cod_oficina = a.cod_oficina
        and nro_asiento = a.nro_asiento
        and fecha = a.fecha;
     -- incrementa numero de asiento
     v_nro_asiento := v_nro_asiento + 1;
     v_procesar := 'S';

     -- veo si esta es la última cuota de este cargo ----------------------------------
     -- para pasar estado del gasto diferido a cancelado (iag190109) ------------------
     BEGIN
       SELECT distinct 'S'
         INTO v_existe
         FROM CB_ASI_FUTUROS C
        WHERE C.COD_CARGO = A.COD_CARGO
          AND C.NRO_ASI_REAL IS NULL;
     EXCEPTION
        WHEN OTHERS THEN
           v_existe := 'N';
     END;
     -- si no existe un asiento futuro, actualizar cb_gas_diferidos.estado = 'C';
     if v_existe = 'N' then
        Update cb_gas_diferidos g set g.estado = 'C' where g.cod_cargo = a.cod_cargo;
     end if;
     ----------------------------------------------------------------------------------

   END LOOP;

   ------- ACTUALIZA PARAMETROS -----
   if v_procesar = 'S' then
      prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, v_nro_asiento);
   end if;
end;
/

