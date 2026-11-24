CREATE OR REPLACE PROCEDURE IT.PRC_COB_GAS_COS_REAL IS
   
   v_car_mas_iva       ge_movimientos.val_tasa%TYPE;

   v_hor_actual        ge_movimientos.hora%TYPE;
   v_fec_actual        ge_movimientos.fecha%TYPE := pag_cal.fu_obt_fec_actual('4');
   v_nro_secuencia     ge_movimientos.nro_secuencia%TYPE := 0;
   v_nvo_estado        ge_movimientos.estado%TYPE;
   v_sal_disponible    ge_cuentas.sal_contable%TYPE;
   v_procesa           varchar2(1);
   --
   v_tra_iva           ge_transacciones.cod_transaccion%type;
   v_cargo             pr_cuotas.sal_interes%type;
   v_cod_tasa          ge_tasas.cod_tasa%type;
   v_cod_oficina       cc_cta_corrientes.cod_oficina%type;
   v_val_tasa          ge_tas_fechas.val_tasa%type;
   v_fec_vigencia      ge_tas_fechas.fec_vigencia%type;
   v_tip_valor         ge_tasas.tip_valor%type;
   v_tipo              ge_tasas.tipo%type;
   v_cargo_iva         pr_cuotas.sal_interes%type;
   v_redondeo          number(02);
   v_cod_moneda        ba_monedas.cod_moneda%type;
   v_cod_transaccion   ge_transacciones.cod_transaccion%type;
   v_cod_persona       ge_clientes.cod_persona%type;
   v_error             varchar2(2000);
   r_gmovi             ge_movimientos%rowtype;
   v_mto_pendiente     pr_cuotas.sal_interes%type;
   
   CURSOR gas_varios IS
      SELECT nro_cuenta, cod_modulo, cod_modalidad, cod_moneda, cod_transaccion, sum(monto) monto
        FROM cc_cta_gastos a
       WHERE (fec_vencimiento >= v_fec_actual or fec_vencimiento is null)
         AND fec_ult_pago is null
         AND cod_transaccion=7712 
         AND referencia = 'GASCOBREAL'
       GROUP BY nro_cuenta, cod_modulo, cod_modalidad, cod_moneda, cod_transaccion
       ORDER BY cod_moneda;
         
   /* veo si tiene IVA asociada a la transaccion */
   PROCEDURE LP_OBT_TRA_IVA_ASOCIADA (P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
                                      P_COD_MODULO      IN GE_TRANSACCIONES.COD_MODULO%TYPE,
                                      P_COD_MODALIDAD   IN GE_TRANSACCIONES.COD_MODALIDAD%TYPE,
                                      P_TRA_IVA        OUT GE_TRANSACCIONES.COD_TRANSACCION%TYPE ) IS
   BEGIN
      SELECT cod_tra_hijo
        INTO p_tra_iva
        FROM ge_transacciones_det
       WHERE cod_transaccion = p_cod_transaccion
         AND cod_modulo      = p_cod_modulo
         AND cod_modalidad   = p_cod_modalidad;
   EXCEPTION
      WHEN no_data_found THEN
         p_tra_iva := null;
   END;
   
   
   
BEGIN
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;  
  IF nvl(fug_obt_pardinamico('COS_REAL_DEB_SOB'), 'N') = 'S' THEN
     v_hor_actual := to_char(sysdate,'HH24:MI:SS');
     v_hor_actual := fug_obt_hor_disponible(v_fec_actual, v_hor_actual, user, 'N');
     v_cod_moneda := 'X';
     FOR reg IN gas_varios LOOP
        r_gmovi       := null;
        v_tipo        := null;
        v_error       := null;
        v_cod_tasa    := null;
        v_val_tasa    := null;
        v_tip_valor   := null;
        v_fec_vigencia:= null;
        v_cargo_iva   := 0;
        v_car_mas_iva := 0;
        v_cargo       := reg.monto;
        v_cod_persona := fug_obt_cli_principal(reg.nro_cuenta);
        v_cod_oficina := fug_obt_ofi_cliente(v_cod_persona);
          
        IF v_cod_moneda <> reg.cod_moneda THEN
           v_cod_moneda := reg.cod_moneda;
           v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 4, null, reg.cod_moneda);
        END IF;
        
        IF v_tra_iva is null THEN
           lp_obt_tra_iva_asociada(reg.cod_transaccion,reg.cod_modulo,reg.cod_modalidad,v_tra_iva);
        END IF;
        IF nvl(v_cargo,0) > 0 and v_tra_iva is not null THEN
           pag_gen.pr_obt_val_tasa(reg.cod_modulo, reg.cod_modalidad, v_cod_oficina, reg.nro_cuenta, 
                                   reg.cod_moneda, 1, 'N', v_cod_tasa, v_tra_iva,
                                   v_fec_actual, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
           v_cargo_iva := nvl(v_cargo_iva,0) + round((v_cargo * v_val_tasa / 100), v_redondeo);
        END IF;
        
        v_car_mas_iva := nvl(v_cargo,0) + nvl(v_cargo_iva,0);
        IF v_car_mas_iva > 0 THEN
           v_procesa           := 'N';
           pag_cta.g_sobregira := 'S';
           pag_cta.g_cod_error := 0;
           v_sal_disponible    := 0;
           pag_cta.pr_ver_operacion(reg.nro_cuenta,
                                    reg.cod_transaccion,
                                    reg.cod_modulo,
                                    reg.cod_modalidad,
                                    'D', -- TIPO DEBITO
                                    reg.cod_moneda,
                                    v_car_mas_iva,
                                    v_cod_oficina,
                                    reg.cod_modulo,
                                    reg.cod_modalidad,
                                    v_nvo_estado,
                                    v_sal_disponible,
                                    v_procesa);
           IF v_procesa = 'S' THEN
              IF v_nro_secuencia > 990 THEN
                 v_hor_actual := fug_obt_hor_disponible(v_fec_actual, v_hor_actual, user, 'N');
                 v_nro_secuencia := 0;
              END IF;
              ----------------------------------------
              v_cod_transaccion := reg.cod_transaccion;
              v_mto_pendiente   := 0;
              IF nvl(v_sal_disponible, 0) = 0 THEN
                 v_mto_pendiente   := v_car_mas_iva;
                 v_cargo           := 0;
              ELSIF nvl(v_sal_disponible, 0) < 0 THEN
                 v_cod_transaccion := 984;
              ELSIF nvl(v_sal_disponible, 0) - v_car_mas_iva < 0 THEN
                 v_mto_pendiente   := v_car_mas_iva - nvl(v_sal_disponible, 0);
                 v_cargo           := round(nvl(v_sal_disponible,0) * v_cargo / v_car_mas_iva, v_redondeo);
                 v_cargo_iva       := round(nvl(v_sal_disponible,0) - v_cargo, v_redondeo);
                 v_car_mas_iva     := nvl(v_cargo,0) + nvl(v_cargo_iva,0);
              END IF;
              ----------------------------------------
              IF nvl(v_cargo,0) > 0 THEN
                 r_gmovi.cod_usuario     := user;
                 r_gmovi.hora            := v_hor_actual;
                 r_gmovi.fecha           := v_fec_actual;
                 -- Aumento la secuencia
                 v_nro_secuencia         := v_nro_secuencia + 1;
                 r_gmovi.nro_secuencia   := v_nro_secuencia;
                 --
                 r_gmovi.nro_cuenta      := null;
                 r_gmovi.cod_modulo      := reg.cod_modulo;
                 r_gmovi.cod_modalidad   := reg.cod_modalidad;
                 r_gmovi.cod_oficina     := v_cod_oficina;
                 r_gmovi.cod_moneda      := reg.cod_moneda;
                 r_gmovi.fec_valor       := v_fec_actual;
                 r_gmovi.cod_transaccion := v_cod_transaccion;
                 r_gmovi.cod_tra_padre   := reg.cod_transaccion;
                 r_gmovi.cod_mod_padre   := reg.cod_modulo;
                 r_gmovi.cod_mad_padre   := reg.cod_modalidad;        
                 r_gmovi.monto           := v_cargo;
                 r_gmovi.nro_documento   := null;--nvl(:variables.wk_nro_documento,v_nro_documento);
                 r_gmovi.nro_documento2  := null;--nvl(:variables.wk_nro_documento2,null);         
                 r_gmovi.cod_ofi_origen  := v_cod_oficina;
                 r_gmovi.emi_aviso       := 'N';
                 r_gmovi.concepto        := 'Cargo x Costo Real';
                 r_gmovi.estado          := 'N';    
                 r_gmovi.reversado       := 'N';
                 r_gmovi.cod_rubro       := null;
                 r_gmovi.cod_tasa        := null;--:comision.cod_tasa;
                 r_gmovi.val_tasa        := null;--:comision.val_tasa;
                 r_gmovi.tip_mov_rubro   := null;--'C';
                 r_gmovi.cod_persona     := v_cod_persona;
                 r_gmovi.referencia      := reg.nro_cuenta;
                 r_gmovi.fec_fin_retencion := null;
                 PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
                    
                 IF nvl(v_cargo_iva,0) > 0 THEN
                    -- Aumento la secuencia
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.nro_cuenta      := null;
                    r_gmovi.cod_transaccion := v_tra_iva;
                    r_gmovi.monto           := v_cargo_iva;
                    r_gmovi.concepto        := 'IVA s/Cargo x Costo Real';
                    r_gmovi.cod_rubro       := null;
                    r_gmovi.cod_tasa        := v_cod_tasa;
                    r_gmovi.val_tasa        := v_val_tasa;
                    PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
                 END IF;
                 pag_cta.pr_act_operacion(reg.nro_cuenta,
                     v_hor_actual,       
                     'D',
                     reg.cod_moneda,     
                     v_car_mas_iva,
                     reg.cod_transaccion,
                     503,
                     reg.nro_cuenta,
                     NULL,
                     v_cod_oficina,      
                     reg.cod_modulo,    
                     reg.cod_modalidad,    
                     null,               --cod_tasa
                     null,               --val_tasa
                     'Débito x Costo Real',
                     'N',
                     v_nro_secuencia,
                     v_fec_actual);
                 IF pag_cta.g_cod_error <> 0 THEN
                    v_error := substr('Error al insertar Mov. de débito: '||pag_cta.G_COD_ERROR||' - '||pag_cta.g_msj_error, 1, 2000);
                    INSERT INTO ge_gas_cobranzas_log (cod_persona, cod_oficina, cod_modulo, cod_modalidad, nro_cuenta, 
                          nro_cuota, cod_tra_cargo, fec_vencimiento, monto, cod_emp_cob, error, hora, referencia)
                    VALUES (v_cod_persona, v_cod_oficina, reg.cod_modulo, reg.cod_modalidad, reg.nro_cuenta, 
                          null, v_cod_transaccion, v_fec_actual, v_car_mas_iva, null, v_error,
                          v_hor_actual, 'DEBCOBREAL');
                 END IF;
              END IF;
              IF nvl(v_mto_pendiente,0) > 0 THEN
                 BEGIN
                    INSERT INTO ge_mov_pendientes (cod_usuario, hora,  cod_modulo, cod_modalidad, cod_oficina, 
                        nro_cuenta, cod_moneda, cod_tra_padre, cod_transaccion, fecha, 
                        monto, estado, cod_ofi_origen, cod_tasa, val_tasa, car_manual,
                        cod_mod_padre, cod_mad_padre, nro_documento, concepto, saldo,
                        cod_persona, referencia)
                    VALUES (user, v_hor_actual, reg.cod_modulo, reg.cod_modalidad, v_cod_oficina,
                        reg.nro_cuenta, reg.cod_moneda, reg.cod_transaccion, v_cod_transaccion, v_fec_actual,
                        nvl(v_mto_pendiente,0), 'I', v_cod_oficina, v_cod_tasa, v_val_tasa, 'S',
                        reg.cod_modulo, reg.cod_modalidad, 1, 'Débito x Costo Real', nvl(v_mto_pendiente,0),
                        v_cod_persona, reg.nro_cuenta );
                 EXCEPTION
                    WHEN others THEN
                       v_error := substr('Error al insertar Mov. Pendiente: '||sqlcode||' - '||sqlerrm, 1, 2000);
                       INSERT INTO ge_gas_cobranzas_log (cod_persona, cod_oficina, cod_modulo, cod_modalidad, nro_cuenta, 
                          nro_cuota, cod_tra_cargo, fec_vencimiento, monto, cod_emp_cob, error, hora, referencia)
                       VALUES (v_cod_persona, v_cod_oficina, reg.cod_modulo, reg.cod_modalidad, reg.nro_cuenta, 
                          null, v_cod_transaccion, v_fec_actual, v_mto_pendiente, null, v_error,
                          v_hor_actual, 'DEBCOBREAL');
                 END;
              END IF;  
              IF v_error is null THEN
                 BEGIN
                    UPDATE cc_cta_gastos
                       SET fec_ult_pago = v_fec_actual,
                           hor_ult_pago = v_hor_actual
                     WHERE nro_cuenta = reg.nro_cuenta
                       AND cod_modulo = reg.cod_modulo
                       AND cod_modalidad = reg.cod_modalidad
                       AND cod_moneda = reg.cod_moneda
                       AND cod_transaccion = reg.cod_transaccion;
                 EXCEPTION
                    WHEN others THEN
                       NULL;
                 END;
                 IF v_cod_transaccion = 984 THEN
                    INSERT INTO cc_sob_suspenso (nro_cuenta,fecha,cod_modulo,cod_modalidad,cod_transaccion,monto)
                    VALUES (reg.nro_cuenta, v_fec_actual, reg.cod_modulo, reg.cod_modalidad, v_cod_transaccion,
                           nvl(v_cargo,0));
                    -- Actualizar el monto en suspenso en Cta.Cte.
                    BEGIN
                       UPDATE cc_sobregiros_res
                          SET mto_sob_suspenso = nvl(mto_sob_suspenso,0)+nvl(v_cargo,0)
                        WHERE nro_cuenta = reg.nro_cuenta;
                    EXCEPTION
                      WHEN others THEN
                         null;
                    END;
                 END IF;
              END IF;
           ELSE
           
              IF pag_cta.g_cod_error <> 0 THEN
                 v_error := substr('Error al verificar Mov.: '||pag_cta.G_COD_ERROR||' - '||pag_cta.g_msj_error, 1, 2000);
                 INSERT INTO ge_gas_cobranzas_log (cod_persona, cod_oficina, cod_modulo, cod_modalidad, nro_cuenta, 
                       nro_cuota, cod_tra_cargo, fec_vencimiento, monto, cod_emp_cob, error, hora, referencia)
                 VALUES (v_cod_persona, v_cod_oficina, reg.cod_modulo, reg.cod_modalidad, reg.nro_cuenta, 
                       null, v_cod_transaccion, v_fec_actual, v_car_mas_iva, null, v_error,
                       v_hor_actual, 'DEBCOBREAL');
              END IF;   
            
           END IF;
        END IF;
     END LOOP;
   END IF;
   COMMIT;
END PRC_COB_GAS_COS_REAL;
/

