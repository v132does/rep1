CREATE OR REPLACE PROCEDURE IT.PRB_ASI_POS_CAMBIOS
IS
   -- Realiza apuntes contables, traslada el saldo de rubros en moneda extranjera que afectan la posicion de cambios de oficina origen a oficina destino 31.
   -- Variables.
   v_tip_movimiento         char := NULL;
   v_fecha                  date;
   v_cod_oficina            ba_oficinas.cod_oficina%type;
   v_cod_ofi_pos_cambios    ba_oficinas.cod_oficina%type := fug_obt_pardinamico('COD_OFI_POS_CAMBIOS');
   v_cod_mon_local          ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;   
   v_mto_mon_rubro          cb_asientos_det.mto_mon_local%type :=0;
   v_mto_mon_local          cb_asientos_det.mto_mon_local%type :=0;
   v_sal_deudor             cb_asientos_det.mto_mon_local%type :=0;
   v_sal_acrededor          cb_asientos_det.mto_mon_local%type :=0;
   v_mto_asiento            cb_asientos_det.mto_mon_local%type :=0;
   v_descripcion            cb_asientos_det.descripcion%type   := 'Cuadre Posicion de Cambios por Oficinas'; 
   v_cod_rub_interoficinas  cb_asientos_det.cod_rubro%type     :=0;
   v_nro_asiento            cb_asientos_det.nro_asiento%type;
   v_nro_linea              cb_asientos_det.nro_linea%type     := 1;       
   v_cod_cargo              cb_gas_diferidos.cod_cargo%type    := NULL;  
   
   -- Cursores.
   CURSOR c_pos_cambios IS
   SELECT bv.cod_divisa,
          bv.cod_oficina,
          bv.ofi_descripcion,
          bv.cod_moneda,
          bv.total_activo,
          bv.total_pasivo,
          bv.saldo_deudor,
          bv.saldo_acreedor,
          bv.cotiz,
          bv.cv_Guaranies
     FROM bv_pos_cam_ajuste bv
    WHERE (bv.saldo_acreedor <> 0 or bv.saldo_deudor <> 0) 
      AND bv.cod_oficina <> v_cod_ofi_pos_cambios;

BEGIN
  
   FOR reg IN c_pos_cambios LOOP
      
      -- Variables.
      v_fecha           := pag_cal.FU_OBT_FEC_ACTUAL(2);
      v_cod_oficina     := reg.cod_oficina;            
      v_mto_mon_local   := reg.cv_guaranies;
      v_sal_acrededor   := abs(reg.saldo_acreedor);
      v_sal_deudor      := reg.saldo_deudor;
      v_mto_asiento     := abs(v_mto_mon_local);
      
      -- Obtiene el nro. de asiento.
      v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
      prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, (v_nro_asiento + 1));

      -- Validaciones del Tipo de movimiento.
      IF (v_sal_acrededor <> 0 or v_sal_deudor <> 0) AND reg.cod_oficina <> v_cod_ofi_pos_cambios THEN               
         IF v_sal_acrededor > 0 AND v_sal_deudor <=0 THEN
            v_tip_movimiento := 'D';
         ELSE
            v_tip_movimiento := 'C';
         END IF;

         -- Obtiene el rubro interOficina.
         v_cod_rub_interoficinas := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL,reg.cod_moneda,v_cod_ofi_pos_cambios);
--         v_cod_rub_interoficinas :=  substr(v_cod_rub_interoficinas, 1, 10) || ltrim(to_char(v_cod_ofi_pos_cambios, '000')) ||substr(v_cod_rub_interoficinas, 14, 2);                                            
         
         -- Inserto la Cabecera.    
         INSERT INTO cb_asientos(fecha, cod_oficina, nro_asiento, cod_usuario, cod_modulo, cod_modalidad, tot_control, 
                                 actualizado, reversado, cod_ofi_origen, ofi_integrada, confirmado, cod_cargo, fec_valor)
              VALUES (v_fecha, v_cod_oficina, v_nro_asiento, user, 2, 21, round(v_mto_asiento*2), 'N', 'N', v_cod_oficina,
                      'N', 'S', v_cod_cargo, v_fecha);
        
         --Trasnlada saldo acrededor o deudor dependiendo de la fuente.
         IF v_tip_movimiento = 'D' THEN
            v_mto_mon_rubro := v_sal_acrededor;
         ELSE
            v_mto_mon_rubro := v_sal_deudor;
         END IF;
         
         --Inserta Detalle 1.
         INSERT INTO cb_asientos_det(fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_rubro, mto_mon_local,
                                        descripcion, referencia, protegido, actualizado, val_cotizacion, distribuido, ref_movimiento, fec_valor)
              VALUES (v_fecha, v_cod_oficina, v_nro_asiento, v_nro_linea, v_cod_rub_interoficinas, v_tip_movimiento, v_mto_mon_rubro, v_mto_asiento,
                      v_descripcion, 'ASI_POSIC', 'N', 'N', null, 'N', NULL, v_fecha);
        
         --Cambio el tipo de movimiento para tener Debito y Credito en el Detalle del asiento.
         IF v_tip_movimiento = 'C' THEN
            v_tip_movimiento := 'D';
         ELSE
            v_tip_movimiento := 'C';
         END IF;
        
         --Obtiene el codigo de rubro interOficina 31 con moneda GS.
         v_cod_rub_interoficinas := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL,v_cod_mon_local,v_cod_ofi_pos_cambios);
         --v_cod_rub_interoficinas :=  substr(v_cod_rub_interoficinas, 1, 10) || ltrim(to_char(31, '000'))||substr(v_cod_rub_interoficinas, 14, 2);
        
         --Trasnlada saldo acrededor o deudor dependiendo de la fuente.
         IF v_tip_movimiento = 'D' THEN
            v_mto_mon_rubro := v_sal_acrededor;
         ELSE
            v_mto_mon_rubro := v_sal_deudor;
         END IF;
         
         -- Asigno el número de línea.
         v_nro_linea:= v_nro_linea + 1;
        
         --Inserta Detalle 2.         
         INSERT INTO cb_asientos_det(fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_rubro, mto_mon_local,
                                     descripcion, referencia, protegido, actualizado, val_cotizacion, distribuido, ref_movimiento, fec_valor)
              VALUES (v_fecha, v_cod_oficina, v_nro_asiento, v_nro_linea, v_cod_rub_interoficinas, v_tip_movimiento, v_mto_mon_rubro, v_mto_asiento,
                      v_descripcion, 'ASI_POSIC', 'N', 'N', null, 'N', NULL, v_fecha);
                                                  
         --Traslado a la oficina parametrizada.
         v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
         prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, (v_nro_asiento + 1));

         --obtiene el codigo de rubro interOficina.
         v_cod_rub_interoficinas := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL,reg.cod_moneda,v_cod_ofi_pos_cambios);
         --v_cod_rub_interoficinas :=  substr(v_cod_rub_interoficinas, 1, 10) || ltrim(to_char(reg.cod_oficina, '000'))||substr(v_cod_rub_interoficinas, 14, 2);

         --Asignamos el valor de la oficina parametrizada en el parametro dinamico.
         v_cod_oficina := v_cod_ofi_pos_cambios;
         
         -- Asigno el número de línea.
         v_nro_linea:= 1;
                                                     
         --Inserta Cabecera.
         INSERT INTO cb_asientos(fecha, cod_oficina, nro_asiento, cod_usuario, cod_modulo, cod_modalidad, tot_control, 
                                 actualizado, reversado, cod_ofi_origen, ofi_integrada, confirmado, cod_cargo, fec_valor)
              VALUES (v_fecha, v_cod_oficina, v_nro_asiento, user, 2, 21, round(v_mto_asiento*2), 'N', 'N', v_cod_oficina,
                      'N', 'S', v_cod_cargo, v_fecha);
              
         --Trasnlada saldo acrededor o deudor dependiendo de la fuente.
         IF v_tip_movimiento = 'D' THEN
            v_mto_mon_rubro := v_sal_deudor;
         ELSE
            v_mto_mon_rubro := v_sal_acrededor;
         END IF;
         
         --Inserta Detalle 1.
         INSERT INTO cb_asientos_det(fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_rubro, mto_mon_local,
                                     descripcion, referencia, protegido, actualizado, val_cotizacion, distribuido, ref_movimiento, fec_valor)
              VALUES (v_fecha, v_cod_oficina, v_nro_asiento, v_nro_linea, v_cod_rub_interoficinas, v_tip_movimiento, v_mto_mon_rubro, v_mto_asiento,
                      v_descripcion, 'ASI_POSIC', 'N', 'N', null, 'N', NULL, v_fecha);

         --Cambio el tipo de movimiento para tener Debito y Credito en el Detalle del asiento.
         IF v_tip_movimiento = 'C' THEN
            v_tip_movimiento := 'D';
         ELSE
            v_tip_movimiento := 'C';
         END IF;
         
         --Obtiene el codigo de rubro interOficina con moneda GS.
         v_cod_rub_interoficinas := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL,v_cod_mon_local,v_cod_ofi_pos_cambios);
         --v_cod_rub_interoficinas :=  substr(v_cod_rub_interoficinas, 1, 10) || ltrim(to_char(reg.cod_oficina, '000'))||substr(v_cod_rub_interoficinas, 14, 2);
        
         --Trasnlada saldo acrededor o deudor dependiendo de la fuente.
         IF v_tip_movimiento = 'D' then
            v_mto_mon_rubro := v_sal_deudor;
         ELSE
            v_mto_mon_rubro := v_sal_acrededor;
         END IF;
         
         -- Asigno el número de línea.
         v_nro_linea:= v_nro_linea + 1;
        
         --Inserta Detalle 2.
         INSERT INTO cb_asientos_det(fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_rubro, mto_mon_local,
                                     descripcion, referencia, protegido, actualizado, val_cotizacion, distribuido, ref_movimiento, fec_valor)
              VALUES (v_fecha, v_cod_oficina, v_nro_asiento, v_nro_linea, v_cod_rub_interoficinas, v_tip_movimiento, v_mto_mon_rubro, v_mto_asiento,
                      v_descripcion, 'ASI_POSIC', 'N', 'N', null, 'N', NULL, v_fecha);              
      END IF;
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'ERROR : Oficina: '|| v_cod_oficina || ',Monto Moneda Local:  ' || v_mto_mon_local ||' Rubro = '||v_cod_rub_interoficinas||' '||SQLERRM ); 
END PRB_ASI_POS_CAMBIOS;
/

