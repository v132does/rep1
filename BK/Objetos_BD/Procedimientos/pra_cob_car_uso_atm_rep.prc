create or replace procedure it.pra_cob_car_uso_atm_rep
 (p_nro_cuenta in varchar2 default null) is

  V_COD_TAS_CARGO     GE_MOVIMIENTOS.COD_TASA%TYPE;
  V_VAL_TAS_CARGO     GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_VAL_CARGO         GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_COD_TRA_IMPUESTO  GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;
  V_COD_TAS_IMPUESTO  GE_MOVIMIENTOS.COD_TASA%TYPE;
  V_VAL_TAS_IMPUESTO  GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_VAL_IMPUESTO      GE_MOVIMIENTOS.VAL_TASA%TYPE;
  v_car_mas_iva       GE_MOVIMIENTOS.VAL_TASA%TYPE;
  v_cod_gru_transaccion GE_GRU_TRANSACCIONES.COD_GRU_TRANSACCION%type;

  v_hor_actual        GE_MOVIMIENTOS.HORA%TYPE;
  v_fec_actual        GE_MOVIMIENTOS.FECHA%TYPE;
  v_nro_secuencia     GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE := 0;
  v_nvo_estado        GE_MOVIMIENTOS.ESTADO%TYPE;
  v_sal_disponible    GE_CUENTAS.SAL_CONTABLE%TYPE;
  v_procesa           varchar2(1);
  --
  v_cod_mod_cargo     GE_MOVIMIENTOS.COD_MODULO%TYPE;
  v_cod_mad_cargo     GE_MOVIMIENTOS.COD_MODALIDAD%TYPE;
  --RI: 15/12/2010: Parametro creado para determinar si se procesa cuenta de nomina
  v_pro_cta_nomina varchar2(1) := nvl(fug_obt_pardinamico('PRO_CTA_NOMINA'),'S');

cursor cargos is
  select cod_gru_transaccion,
         decode(cod_gru_transaccion, 51, 'Extracciones', -- Extracciones nuestro atm
                                     52, 'Extracciones', -- Extracciones otro atm
                                     53, 'Consultas',    -- Consultas nuestro atm
                                     54, 'Consultas',    -- Consultas otro atm
                                     57, 'Extracc.Ext.', -- Extracciones atm extranjero
                                     58, 'Consul..Ext.'  -- Cosultas atm extranjero
               ) tipo,
         decode(cod_gru_transaccion, 51, 148,
                                     52, 145,
                                     53, 146,
                                     54, 147,
                                     57, 129,
                                     58, 128
               ) cod_tra_cargo,
         decode(cod_gru_transaccion, 51, 'CAN_MAX_EXT_PRO_ATM',
                                     52, 'CAN_MAX_EXT_OTR_ATM',
                                     53, 'CAN_MAX_CON_PRO_ATM',
                                     54, 'CAN_MAX_CON_OTR_ATM',
                                     57, 'CAN_MAX_CON_EXT_ATM',
                                     58, 'CAN_MAX_CON_EXT_ATM'
               ) par_dinamico,
         decode(cod_gru_transaccion, 51, 'S',
                                     52, 'N',
                                     53, 'S',
                                     54, 'N',
                                     57, 'N',
                                     58, 'N'
               ) ntr_atm
    from ge_mov_sin_costo
   where cod_gru_transaccion in (51, 52, 53, 54, 57, 58)
   order by cod_gru_transaccion;

cursor ctas is
  select nro_cuenta, cod_moneda, cod_oficina, cod_modulo, cod_modalidad, a.cod_ente
    from ah_cta_vistas a
   where (nro_cuenta = p_nro_cuenta or p_nro_cuenta is null)
     and estado not in ('T','C','A','X')
     /*RI: 15/12/2010: para que evalue si procesar o no cuentas de nomina */
     /*and ((a.cod_ente is null and v_pro_cta_nomina ='N')
      or v_pro_cta_nomina = 'S')*/
     and not exists (select 1
                       from ge_par_entes p
                      where p.parametro = 'NRO_CUENTA'
                        and p.val_parametro = a.nro_cuenta) -- cuenta sponsor
     and exists (select 1
                   from ge_movimientos_ant           m,
                        ge_gru_transacciones_det g
                  where m.nro_cuenta = a.nro_cuenta
                    and m.estado = 'N'
                    and m.reversado = 'N'
                    and m.cod_transaccion = (case WHEN v_cod_gru_transaccion = 53 THEN  389
                                                  WHEN v_cod_gru_transaccion = 54 THEN 389 
                                                  ELSE 503 END)                                  
                    and ((g.cod_gru_transaccion in(53,54) and nvl(m.monto,0)= 0)
                      or(m.monto > 0))
                    and cod_mod_padre = g.cod_modulo
                    and cod_mad_padre = g.cod_modalidad
                    and cod_tra_padre = g.cod_transaccion
                    and g.cod_gru_transaccion = v_cod_gru_transaccion)
  union all
  select nro_cuenta, cod_moneda, cod_oficina, cod_modulo, cod_modalidad, a.cod_ente
    from cc_cta_corrientes a
   where (nro_cuenta = p_nro_cuenta or p_nro_cuenta is null)
     and estado not in ('T','C','A','X')
     /*RI: 15/12/2010: para que evalue si procesar o no cuentas de nomina */
     /*and ((a.cod_ente is null and v_pro_cta_nomina ='N')
      or v_pro_cta_nomina = 'S')*/
     and not exists (select 1
                       from ge_par_entes p
                      where p.parametro = 'NRO_CUENTA'
                        and p.val_parametro = a.nro_cuenta) -- cuenta sponsor
     and exists (select 1
                   from ge_movimientos_ant           m,
                        ge_gru_transacciones_det g
                  where m.nro_cuenta = a.nro_cuenta
                    and m.estado = 'N'
                    and m.reversado = 'N'
                    and m.cod_transaccion = (case WHEN v_cod_gru_transaccion = 53 THEN  389
                                                  WHEN v_cod_gru_transaccion = 54 THEN 389 
                                                  ELSE 503 END)                                  
                    and ((g.cod_gru_transaccion in(53,54) and nvl(m.monto,0)= 0)
                      or(m.monto > 0))
                    and cod_mod_padre = g.cod_modulo
                    and cod_mad_padre = g.cod_modalidad
                    and cod_tra_padre = g.cod_transaccion
                    and g.cod_gru_transaccion = v_cod_gru_transaccion);
begin
  v_fec_actual := pag_cal.fu_obt_fec_actual('4');
  --v_hor_actual := fug_ini_hora(sysdate,'HH24:MI:SS');
  --JIRA 1399 optimizacion de busqueda de hora
  v_hor_actual := to_char(sysdate,'HH24:MI:SS');
  v_hor_actual := fug_obt_hor_disponible(v_fec_actual, v_hor_actual, user, 'N');
  for cg in cargos loop
    v_cod_gru_transaccion := cg.cod_gru_transaccion;
    for reg in ctas loop
      v_cod_mod_cargo := reg.cod_modulo;
      v_cod_mad_cargo := reg.cod_modalidad;
      if v_nro_secuencia > 990 then
         -- v_hor_actual := pag_gen.fu_obt_sig_segundo(v_hor_actual);
         v_hor_actual := fug_obt_hor_disponible(v_fec_actual, v_hor_actual, user, 'N');
         v_nro_secuencia := 0;
      end if;

      --Se cobra cargos por la operacion si corresponde
      if cg.ntr_atm = 'S' then
        prg_obt_car_uso_pro_atm_rep (reg.nro_cuenta,
                                     cg.cod_gru_transaccion,
                                     cg.cod_tra_cargo,
                                     cg.par_dinamico,
                                     V_COD_TAS_CARGO,
                                     V_VAL_TAS_CARGO,
                                     V_VAL_CARGO,
                                     V_COD_TRA_IMPUESTO,
                                     V_COD_TAS_IMPUESTO,
                                     V_VAL_TAS_IMPUESTO,
                                     V_VAL_IMPUESTO);
      else
        prg_obt_car_uso_otr_atm_rep (reg.nro_cuenta,
                                     cg.cod_gru_transaccion,
                                     cg.cod_tra_cargo,
                                     cg.par_dinamico,
                                     V_COD_TAS_CARGO,
                                     V_VAL_TAS_CARGO,
                                     V_VAL_CARGO,
                                     V_COD_TRA_IMPUESTO,
                                     V_COD_TAS_IMPUESTO,
                                     V_VAL_TAS_IMPUESTO,
                                     V_VAL_IMPUESTO);
      end if;

      /*
      || PCC-Exoneración y Extorno de Comisiones y Tasas
      */
      if (reg.cod_ente is null and v_pro_cta_nomina ='N') or v_pro_cta_nomina = 'S' then
         ---
         v_car_mas_iva := nvl(v_val_cargo,0) + nvl(v_val_impuesto,0);
         if v_car_mas_iva > 0 then
           pag_cta.G_COD_ERROR := 0;
           -- verifico si puedo o no cobrar el cargo + iva
           pag_cta.PR_VER_OPERACION(reg.nro_cuenta,
                                    cg.cod_tra_cargo, -- padre
                                    v_cod_mod_cargo,
                                    v_cod_mad_cargo,
                                    'D', -- TIPO DEBITO
                                    reg.cod_moneda,
                                    v_car_mas_iva,
                                    reg.cod_oficina,
                                    pag_cta.G_CTAS.COD_MODULO,
                                    pag_cta.G_CTAS.COD_MODALIDAD,
                                    v_nvo_estado,
                                    v_sal_disponible,
                                    v_procesa,
                                    cg.cod_tra_cargo);
           if v_procesa = 'N' then -- no se puede debitar
             -- RI : 02/02/2010 : Si la cuenta esta inactiva y no tiene saldo no se graba mov.pendiente
             If  v_sal_disponible = 0 and pag_cta.G_CTAS.estado = 'I' then
                 null;
             else
              insert into ge_mov_pendientes
                          (nro_cuenta,fecha, cod_modulo, cod_modalidad, cod_transaccion,
                           cod_mod_padre, cod_mad_padre, cod_tra_padre, monto,
                           hora, cod_usuario,  cod_moneda,
                           cod_oficina, cod_error, estado, cod_ofi_origen,
                           concepto, cod_tasa, val_tasa, nro_documento, saldo,
                           motivo)
                   values (reg.nro_cuenta, v_fec_actual, v_cod_mod_cargo, v_cod_mad_cargo, cg.cod_tra_cargo,
                           v_cod_mod_cargo, v_cod_mad_cargo, cg.cod_tra_cargo, v_car_mas_iva,
                           v_hor_actual, user, reg.cod_moneda,
                           reg.cod_oficina, pag_cta.g_cod_error, 'I', reg.cod_oficina,
                           'Cargo x '||cg.tipo,V_COD_TAS_CARGO, V_VAL_TAS_CARGO,
                           reg.nro_cuenta /* nro_documento=cuenta*/, v_car_mas_iva,
                           pag_cta.G_MSJ_ERROR);
              end if;
           end if;

           if nvl(v_val_cargo,0) > 0 then
             pag_cta.G_COD_ERROR := 0;
             pag_cta.pr_act_operacion(reg.nro_cuenta,
                                      v_hor_actual,
                                      'D', -- debito a la cuenta del cliente
                                      reg.cod_moneda,
                                      v_val_cargo,
                                      cg.cod_tra_cargo,
                                      cg.cod_tra_cargo, -- trans. hijo
                                      reg.nro_cuenta,
                                      null, -- cotizacion
                                      reg.cod_oficina,
                                      v_cod_mod_cargo,
                                      v_cod_mad_cargo,
                                      V_COD_TAS_CARGO, -- tasa
                                      V_VAL_TAS_CARGO, -- valor de tasa
                                      'Cargo x '||cg.tipo , --concepto
                                      'N', -- emitir aviso
                                      v_nro_secuencia, -- nro de secuencia
                                      v_fec_actual);

             if v_val_impuesto > 0 and  pag_cta.g_cod_error = 0 then
               pag_cta.pr_act_operacion(reg.nro_cuenta,
                                        v_hor_actual,
                                        'D', -- debito a la cuenta del cliente
                                        reg.cod_moneda,
                                        v_val_impuesto,
                                        V_COD_TRA_IMPUESTO,
                                        V_COD_TRA_IMPUESTO, -- trans. hijo
                                        reg.nro_cuenta,
                                        null, -- cotizacion
                                        reg.cod_oficina,
                                        v_cod_mod_cargo,
                                        v_cod_mad_cargo,
                                        V_COD_TAS_IMPUESTO, -- tasa
                                        V_VAL_TAS_IMPUESTO, -- valor de tasa
                                        'IVA s/Cargo x '||cg.tipo, --concepto
                                        'N', -- emitir aviso
                                        v_nro_secuencia, -- nro de secuencia
                                        v_fec_actual);

             End if;

           End if;
         end if;
      else
         prg_ins_exoneracion(cg.cod_tra_cargo,v_cod_mod_cargo,v_cod_mad_cargo,
                             reg.cod_moneda,reg.nro_cuenta,null,
                             V_COD_TAS_CARGO,v_car_mas_iva,v_car_mas_iva,
                             null,v_car_mas_iva);
      end if;
    end loop;
  end loop;
end pra_cob_car_uso_atm_rep;
/

