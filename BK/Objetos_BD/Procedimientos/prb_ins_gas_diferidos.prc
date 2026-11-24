CREATE OR REPLACE PROCEDURE IT.PRB_INS_GAS_DIFERIDOS IS
  v_monto_total     number(18, 2) := 0;
  v_diferencia      number(18, 2) := 0;
  v_cant_cuotas     number(18, 2) := 0;
  v_monto_cuota     number(18, 2) := 0;
  v_cont            number(10) := 0;
  v_mto_mon_local   number(18, 2);
  v_mto_mon_rubro   number(18, 2);
  v_nro_asiento     cb_asi_futuros.nro_asiento%type;
  v_fecha           cb_asi_futuros.fecha%type;
  v_nro_linea       number(10) := 0;
  v_cot_debito      ge_cotizaciones.val_conversion%type := 0;
  v_cot_credito     ge_cotizaciones.val_conversion%type := 0;
  v_fec_futuro      date;
  v_ctrl_fec_habil  date := trunc(sysdate);
  v_fec_actual      date := pag_cal.fu_obt_fec_actual(2);
  v_fec_desde       date;
  v_fec_hasta       date;
  v_mto_diferido    number(18, 2) := 0;
  v_des_rub_debito  cb_asi_futuros_det.descripcion%type;
  v_cod_mon_debito  varchar2(3);
  v_des_rub_credito cb_asi_futuros_det.descripcion%type;
  v_cod_mon_credito varchar2(3);
  v_existe          varchar2(1) := 'N';
  ex_salir          exception;
  v_msj_error       varchar2(1000);
  v_cod_mon_local   ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
  
  cursor c_gastos is
    Select fecha,
           periodicidad,
           cod_oficina,
           cod_tip_cargo,
           cod_cargo,
           cod_rub_debito,
           cod_rub_credito,
           fec_desde,
           fec_hasta,
           descripcion,
           nro_factura,
           nro_orden,
           monto
      from cb_gas_diferidos_tmp;

BEGIN
  FOR i IN c_gastos LOOP
    v_diferencia := 0;
    IF i.fec_desde is not null and i.fec_hasta is not null and
       i.monto is not null THEN
      if (i.fec_desde > i.fec_hasta) then
        v_msj_error := 'ERROR: La fecha de Inicio debe ser menor a la Fecha Final. Cod_cargo = ' || i.cod_cargo;
        raise ex_salir;
      end if;
    ELSE
      v_msj_error := 'ERROR: Faltan completar datos. Favor Verifique las Fechas y Monto. Cod_cargo = ' || i.cod_cargo;
      raise ex_salir;
    END IF;
    IF to_char(i.fec_hasta, 'yyyy') <> to_char(sysdate, 'yyyy') then
      v_msj_error := 'El tipo de Cargo impide que se difieran gastos fuera del año actual. Favor Verifique la Fecha Final. Cod_cargo = ' || i.cod_cargo;
      raise ex_salir;
    END IF;
    
    IF i.periodicidad <> 'M' THEN
      v_msj_error := 'Solo se permite la periodicidad mensual. cod_cargo: ' || i.cod_cargo;
      raise ex_salir;
    END IF;
  
    IF i.cod_rub_debito IS NOT NULL THEN
      begin
        select descripcion, COD_MONEDA
          into v_des_rub_debito, v_COD_MON_DEBITO
          from cb_rubros
         where cod_rubro = i.cod_rub_debito;
      exception
        when no_data_found then
          v_msj_error := 'No se encontró la moneda para el rubro: ' || i.cod_rub_debito;
          raise ex_salir;
      end;
    END IF;
  
    IF i.cod_rub_credito IS NOT NULL THEN
      begin
        select descripcion, cod_moneda
          into v_des_rub_credito, v_COD_MON_CREDITO
          from cb_rubros
         where cod_rubro = i.cod_rub_credito;
      exception
        when no_data_found then
          v_msj_error := 'No se encontró la moneda para el rubro: ' || i.cod_rub_credito;
          raise ex_salir;
      end;
    END IF;
   -- verifica si la moneda que obtiene sea local o sino emitir el error
   IF v_cod_mon_credito != v_cod_mon_local OR v_cod_mon_debito != v_cod_mon_local THEN
      v_msj_error := 'ERROR: Debe ser Moneda Local tanto para Crédito ó Débito. Cod_cargo = ' || i.cod_cargo;
      raise ex_salir;
   END IF;
   IF i.descripcion IS NULL THEN
      v_msj_error := 'ERROR: El Cargo debe tener una Descripción . Cod_cargo = ' || i.cod_cargo;
      raise ex_salir;
   END IF;
    IF i.monto <= 0 THEN    
        v_msj_error := 'ERROR: El Monto debe ser mayor a 0(cero). Cod_cargo = ' || i.cod_cargo;
        raise ex_salir;
    END IF;
    
    BEGIN
      Select 'S'
        into v_existe
        from cb_gas_diferidos
       where cod_cargo = i.cod_cargo;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_existe := 'N';
    END;
    
    if v_existe = 'N' then
      BEGIN
        -- INSERT CB_GAS_DIFERIDOS
        insert into cb_gas_diferidos
          (cod_cargo,
           cod_rub_credito,
           fec_desde,
           fec_hasta,
           monto,
           estado,
           descripcion,
           cod_rub_debito,
           periodicidad,
           cod_oficina,
           cod_tipo_cargo,
           nro_orden,
           nro_factura,
           fecha)
        values
          (i.cod_cargo,
           i.cod_rub_credito,
           i.fec_desde,
           i.fec_hasta,
           i.monto,
           'V',
           i.descripcion,
           i.cod_rub_debito,
           i.periodicidad,
           i.cod_oficina,
           i.cod_tip_cargo,
           i.nro_orden,
           i.nro_factura,
           i.fecha);
      EXCEPTION
        WHEN OTHERS THEN
          v_msj_error := 'No se pudo insertar en gastos diferidos cod_cargo: ' || i.cod_cargo;
          raise ex_salir;
      END;
    else
      v_msj_error := 'Código de Cargo duplicado, favor verificar. Cod_cargo: ' || i.cod_cargo;
      raise ex_salir;
    end if;
    -- VALIDACIONES Y CÁLCULOS DE ASI_FUTUROS   
    IF i.periodicidad = 'M' THEN
      IF i.monto is not null THEN
        -- validacion para obtener la cantidad de cuotas a generar
        Begin
          v_fec_actual  := pag_cal.FU_OBT_FEC_ANT_HAB(last_day(v_fec_actual), null, 0);
          v_fec_desde   := pag_cal.FU_OBT_FEC_ANT_HAB(last_day(i.fec_desde), null, 0);
          v_fec_hasta   := pag_cal.FU_OBT_FEC_ANT_HAB(last_day(i.fec_hasta), null, 0);
          v_cant_cuotas := fug_obt_dif_meses(v_fec_hasta, v_fec_desde);
        end;
        --agregado para actualizaciones de cuotas
        Begin
          select nvl(sum(nvl(mto_mon_local, 0)), 0),
                 nvl(sum(nvl(mto_mon_rubro, 0)), 0),
                 max(fut.fecha)
            into v_mto_mon_local, v_mto_mon_rubro, v_fec_futuro
            from cb_asi_futuros_det det, cb_asi_futuros fut
           where det.fecha = fut.fecha
             and det.cod_oficina = fut.cod_oficina
             and det.nro_asiento = fut.nro_asiento
             and fut.nro_asi_real is not null
             and det.tip_movimiento = 'D'
                --  and fut.confirmado = 'S'
             and fut.cod_cargo = i.cod_cargo;
        Exception
          when others then
            v_mto_mon_local := 0;
            v_mto_mon_rubro := 0;
            v_fec_futuro    := null;
        End;
        --agregado para actualizaciones de cuotas
        v_monto_cuota := (i.monto - nvl(v_mto_mon_local, 0)) /
                         v_cant_cuotas;
        IF round(v_monto_cuota * v_cant_cuotas) + nvl(v_mto_mon_local, 0) = i.monto THEN
          --para update
          IF v_monto_cuota <> round(v_monto_cuota) THEN
            IF v_monto_cuota > round(v_monto_cuota) THEN
              v_diferencia := (v_monto_cuota * v_cant_cuotas) -
                              (round(v_monto_cuota) * v_cant_cuotas);
            ELSE
              v_diferencia := ((round(v_monto_cuota) * v_cant_cuotas) -
                              (v_monto_cuota * v_cant_cuotas)) * -1;
            END IF;
          END IF;
          v_cont := 0;
          loop
            v_cont      := v_cont + 1;
            v_nro_linea := 1;
          
            IF nvl(v_fec_futuro, v_fec_desde) > v_fec_desde THEN
              select add_months(nvl(v_fec_futuro, v_fec_desde), v_cont - 1 + decode(v_fec_futuro, null, 0, 1))
                into v_fecha
                from dual;
            ELSIF v_fec_actual >= v_fec_desde THEN
              if v_cont = 1 then
                v_fecha        := v_fec_actual;
                v_cont         := fug_obt_dif_meses(v_fec_actual, v_fec_desde);
                v_mto_diferido := round(v_monto_cuota) * abs(v_cont);
                IF v_cont = v_cant_cuotas THEN
                  v_monto_cuota := round(v_mto_diferido);
                END IF;
              else
                v_fecha := pag_cal.FU_OBT_FEC_ANT_HAB(last_day(add_months(v_fecha, 1)), null, 0);
              end if;
            ELSE
              v_fecha := pag_cal.FU_OBT_FEC_ANT_HAB(last_day(add_months(v_fec_desde, v_cont - 1)), null, 0);
            END IF;
          
            select pag_cal.FU_OBT_FEC_HABIL(v_fecha, -1, null)
              into v_ctrl_fec_habil
              from dual;
            if v_fecha <> v_ctrl_fec_habil then
              if to_char(v_fecha, 'mm/yyyy') <> to_char(v_ctrl_fec_habil, 'mm/yyyy') then
                select pag_cal.FU_OBT_FEC_HABIL(v_fecha, +1, null)
                  into v_ctrl_fec_habil
                  from dual;
              end if;
              v_fecha := v_ctrl_fec_habil;
            end if;
          
            IF v_cont = v_cant_cuotas THEN
              v_monto_total := round(v_monto_cuota + v_diferencia);
            ELSIF v_mto_diferido > 0 then
              -- rabf - 14/dic/2010
              v_monto_total  := round(v_mto_diferido);
              v_mto_diferido := 0;
            ELSE
              v_monto_total := round(v_monto_cuota);
            END IF;
            begin
              v_nro_asiento := fub_obt_sig_nro_asi_futuro(i.cod_oficina, v_fecha);
              -- Obtinene la cotización
              v_cot_debito  := fug_obt_cotizacion(v_cod_mon_debito);
              v_cot_credito := fug_obt_cotizacion(v_cod_mon_credito);
              IF v_cot_debito is null or v_cot_credito is null then
                if v_cod_mon_debito = pag_gen.fu_obt_mon_local then
                  v_cot_debito := 1;
                end if;
                if v_cod_mon_debito = pag_gen.fu_obt_mon_local then
                  v_cot_credito := 1;
                end if;
                IF v_cot_debito is null or v_cot_credito is null then
                  raise_application_error(-20000, 'Error al obtener cotización. Cargue primero la cotización del día.');
                end if;
              end if;
            
              --Igualar ultima cuota con el vencimiento
              if v_cont >= v_cant_cuotas then
                if v_fec_hasta <> v_fecha then
                  v_fecha := v_fec_hasta;
                end if;
              end if;
            
              insert into cb_asi_futuros
                (FECHA,
                 COD_OFICINA,
                 NRO_ASIENTO,
                 COD_USUARIO,
                 COD_MODULO,
                 COD_MODALIDAD,
                 COD_CARGO,
                 TOT_CONTROL)
              values
                (v_fecha,
                 i.cod_oficina,
                 v_nro_asiento,
                 user,
                 2,
                 21,
                 i.cod_cargo,
                 (v_monto_total * v_cot_debito) * 2);
            
              insert into cb_asi_futuros_det
                (fecha,
                 cod_oficina,
                 nro_asiento,
                 nro_linea,
                 cod_rubro,
                 tip_movimiento,
                 mto_mon_local,
                 descripcion,
                 mto_mon_rubro)
              values
                (v_fecha,
                 i.cod_oficina,
                 v_nro_asiento,
                 v_nro_linea,
                 i.cod_rub_debito,
                 'D',
                 v_monto_total * v_cot_debito,
                 i.descripcion,
                 decode(v_cod_mon_debito, 'GS', null, v_monto_total));
            
              insert into cb_asi_futuros_det
                (fecha,
                 cod_oficina,
                 nro_asiento,
                 nro_linea,
                 cod_rubro,
                 tip_movimiento,
                 mto_mon_local,
                 descripcion,
                 mto_mon_rubro)
              values
                (v_fecha,
                 i.cod_oficina,
                 v_nro_asiento,
                 v_nro_linea + 1,
                 i.cod_rub_credito,
                 'C',
                 v_monto_total * v_cot_credito,
                 i.descripcion,
                 decode(v_cod_mon_credito, 'GS', null, v_monto_total));
            
            end;
          
            exit when v_cont >= v_cant_cuotas;
          end loop;
        END IF;
      ELSE
        v_msj_error := 'El monto no puede ser nulo. cod_cargo: ' || i.cod_cargo;
        raise ex_salir;
      END IF;
    ELSE
      IF i.monto is not null THEN
        Begin
          v_cant_cuotas := fuh_obt_dif_dias(i.fec_desde, i.fec_hasta) + 1;
        end;
        --agregado para actualizaciones de cuotas
        Begin
          select nvl(sum(nvl(mto_mon_local, 0)), 0),
                 nvl(sum(nvl(mto_mon_rubro, 0)), 0),
                 max(fut.fecha)
            into v_mto_mon_local, v_mto_mon_rubro, v_fec_futuro
            from cb_asi_futuros_det det, cb_asi_futuros fut
           where det.fecha = fut.fecha
             and det.cod_oficina = fut.cod_oficina
             and det.nro_asiento = fut.nro_asiento
             and fut.nro_asi_real is not null
             and det.tip_movimiento = 'D'
             and fut.cod_cargo = i.cod_cargo;
        Exception
          when others then
            v_mto_mon_local := 0;
            v_mto_mon_rubro := 0;
            v_fec_futuro    := null;
        End;
        --agregado para actualizaciones de cuotas
        v_monto_cuota := (i.monto - nvl(v_mto_mon_local, 0)) / v_cant_cuotas;
        IF round(v_monto_cuota * v_cant_cuotas) + nvl(v_mto_mon_local, 0) = i.monto THEN
          IF v_monto_cuota <> round(v_monto_cuota) THEN
            v_diferencia := (i.monto - nvl(v_mto_mon_local, 0)) -
                            (round(v_monto_cuota) * v_cant_cuotas);
          else
            v_diferencia := 0;
          END IF;
        
          v_cont := 0;
        
          loop
            v_cont      := v_cont + 1;
            v_nro_linea := 1;
            -- AAP - CONTROL DE FECHA HABIL PARA RECALCULOS
            IF nvl(v_fec_futuro, i.fec_desde) > i.fec_desde THEN
              select nvl(v_fec_futuro, i.fec_desde) + (v_cont - 1) + decode(v_fec_futuro, null, 0, 1)
                into v_fecha
                from dual;
            elsif v_fec_actual > i.fec_desde then
              if v_cont = 1 then
                v_fecha := v_fec_actual;
                if i.fec_hasta < v_fec_actual then
                  v_cont := i.fec_hasta - i.fec_desde - 1;
                else
                  v_cont := v_fec_actual - i.fec_desde - 1;
                end if;
                v_mto_diferido := round(v_monto_cuota) * abs(v_cont);
              else
                v_fecha := pag_cal.fu_obt_fec_sig_hab(v_fecha, null, 1); --v_fecha + 1;
              end if;
            ELSE
              if v_cont = 1 then
                v_fecha := i.fec_desde;
              else
                v_fecha := pag_cal.fu_obt_fec_sig_hab(v_fecha, null, 1);
              end if;
            END IF;
          
            select pag_cal.FU_OBT_FEC_HABIL(v_fecha, -1, null)
              into v_ctrl_fec_habil
              from dual;
            if v_fecha <> v_ctrl_fec_habil then
              select pag_cal.FU_OBT_FEC_HABIL(v_fecha, +1, null)
                into v_ctrl_fec_habil
                from dual; -- rabf - 14/dic/2010
              v_fecha := v_ctrl_fec_habil;
            end if;
          
            IF v_cont = v_cant_cuotas THEN
              v_monto_total := round(v_monto_cuota + v_diferencia);
            elsif v_mto_diferido > 0 then
              -- rabf - 14/dic/2010
              v_monto_total  := round(v_mto_diferido);
              v_mto_diferido := 0;
            ELSE
              v_monto_total := round(v_monto_cuota);
            END IF;
            begin
              v_nro_asiento := fub_obt_sig_nro_asi_futuro(i.cod_oficina, v_fecha);
            
              -- Obtinene la cotización
              v_cot_debito  := null;
              v_cot_credito := null;
              select fug_obt_cotizacion(v_cod_mon_debito), fug_obt_cotizacion(v_cod_mon_credito)
                into v_cot_debito, v_cot_credito
                from dual;
              IF v_cot_debito is null or v_cot_credito is null then
                if v_cod_mon_debito = pag_gen.fu_obt_mon_local then 
                  v_cot_debito := 1;
                end if;
                if v_cod_mon_debito = pag_gen.fu_obt_mon_local then
                  v_cot_credito := 1;
                end if;
                IF v_cot_debito is null or v_cot_credito is null then
                  raise_application_error(-20000, 'Error al obtener cotización. Cargue primero la cotización del día.');
                end if;
              end if;
            
              --Igualar ultima cuota con el vencimiento
              if v_cont > v_cant_cuotas then
                if i.fec_hasta < v_fecha then
                  v_fecha := i.fec_hasta;
                end if;
              end if;
              insert into cb_asi_futuros
                (FECHA,
                 COD_OFICINA,
                 NRO_ASIENTO,
                 COD_USUARIO,
                 COD_MODULO,
                 COD_MODALIDAD,
                 COD_CARGO,
                 TOT_CONTROL)
              values
                (v_fecha,
                 i.cod_oficina,
                 v_nro_asiento,
                 user,
                 2,
                 21,
                 i.cod_cargo,
                 (v_monto_total * v_cot_debito) * 2);
              insert into cb_asi_futuros_det
                (fecha,
                 cod_oficina,
                 nro_asiento,
                 nro_linea,
                 cod_rubro,
                 tip_movimiento,
                 mto_mon_local,
                 descripcion,
                 mto_mon_rubro)
              values
                (v_fecha,
                 i.cod_oficina,
                 v_nro_asiento,
                 v_nro_linea,
                 i.cod_rub_debito,
                 'D',
                 v_monto_total * v_cot_debito,
                 i.descripcion,
                 decode(v_cod_mon_debito, 'GS', null, v_monto_total));
              insert into cb_asi_futuros_det
                (fecha,
                 cod_oficina,
                 nro_asiento,
                 nro_linea,
                 cod_rubro,
                 tip_movimiento,
                 mto_mon_local,
                 descripcion,
                 mto_mon_rubro)
              values
                (v_fecha,
                 i.cod_oficina,
                 v_nro_asiento,
                 v_nro_linea + 1,
                 i.cod_rub_credito,
                 'C',
                 v_monto_total * v_cot_credito,
                 i.descripcion,
                 decode(v_cod_mon_credito, 'GS', null, v_monto_total));
            
            end;
            exit when v_cont >= v_cant_cuotas;
          end loop;
        END IF;
      ELSE
        v_msj_error := 'El monto no puede ser nulo. cod_cargo: ' || i.cod_cargo;
        raise ex_salir;
      END IF;
    END IF;
  
  END LOOP;
EXCEPTION
  WHEN ex_salir THEN
    raise_application_error(-20000, v_msj_error);
  WHEN OTHERS THEN
    raise_application_error(-20001, 'Error no manejado en el proceso PRB_INS_GAS_DIFERIDOS ' || sqlerrm);
END;
/

