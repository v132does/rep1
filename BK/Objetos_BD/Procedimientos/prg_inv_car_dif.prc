create or replace procedure it.PRG_INV_CAR_DIF is

  cursor invent_cur is
    select i.fecha fecha,
           i.cod_modulo modulo,
           i.cod_modalidad modalidad,
           i.cod_oficina oficina,
           i.cod_moneda moneda,
           i.tip_saldo tipo_saldo,
           i.cod_rubro rubro,
           g.cod_rub_debito rub_debito,
           g.cod_cargo cod_cargo,
           g.fec_desde fecha_desde,
           g.fec_hasta fec_hasta,
           g.nro_factura nro_factura,
           g.descripcion descripcion,
           g.monto monto,
           d.sal_actual saldo_contable,
           (g.monto - d.sal_actual) as devengado_total,
           (g.fec_hasta - i.fecha) as dias_restantes
      from cb_sal_inventarios_his     i,
           cb_sal_inventarios_det_his d,
           cb_gas_diferidos           g
     where i.nro_referencia = d.nro_referencia
       and i.fecha = d.fecha
       and g.cod_cargo = d.nro_cuenta
       and i.cod_rubro in ('150102430100299', '150102430100605',
            '150102430100699', '150102430160299');
  
  invent_reg                invent_cur%rowtype;
  v_fecha_sgte              date := pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_cant_meses_entre_fechas numeric(3);
  v_cant_dias_mes           numeric(3);
  v_devengado               number(18, 2);
  v_fecha                   date := pag_cal.FU_OBT_FEC_ACTUAL(1);

begin

  delete TMP_INV_CARG_DIFERIDOS;
  commit;
  for invent_reg in invent_cur loop
    -- cantidad de meses entre fechas
    v_cant_meses_entre_fechas := round(months_between(invent_reg.fec_hasta,
                                                      invent_reg.fecha));
  
    for cont in 0 .. (v_cant_meses_entre_fechas - 1) loop
      -- fecha siguiente
      v_fecha_sgte := add_months(invent_reg.fecha,cont + 1);
    
      -- obtener la cantidad de dias del mes correspondiente a fecha siguiente
      v_cant_dias_mes := to_number(substr(v_fecha_sgte,0,2));
    
      v_fecha := v_fecha_sgte;
    
      -- obtener devengado para el mes actual
      v_devengado := (invent_reg.saldo_contable / invent_reg.dias_restantes) *
                    v_cant_dias_mes;
    
      insert into TMP_INV_CARG_DIFERIDOS
        (FECHA,
         MODULO,
         MODALIDAD,
         OFICINA,
         MONEDA,
         TIPO_SALDO,
         COD_RUBRO,
         COD_RUBRO_DEB,
         COD_CARGO,
         FEC_DESDE,
         FEC_HASTA,
         NRO_FACTURA,
         DESCRIPCION,
         MONTO,
         SALDO_CONTABLE,
         DEVENGADO_TOTAL,
         DIAS_RESTANTES,
         FECHA_DEVENGADO,
         MONTO_DEVENGADO
         
         )
      values
        (invent_reg.fecha,
         invent_reg.modulo,
         invent_reg.modalidad,
         invent_reg.oficina,
         invent_reg.moneda,
         invent_reg.tipo_saldo,
         invent_reg.rubro,
         invent_reg.rub_debito,
         invent_reg.cod_cargo,
         invent_reg.fecha_desde,
         invent_reg.fec_hasta,
         invent_reg.nro_factura,
         invent_reg.descripcion,
         invent_reg.monto,
         invent_reg.saldo_contable,
         invent_reg.devengado_total,
         invent_reg.dias_restantes,
         v_fecha,
         v_devengado);
    
    end loop;
  
  end loop;

  commit;

end;
/

