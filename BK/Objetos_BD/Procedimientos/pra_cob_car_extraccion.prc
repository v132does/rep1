create or replace procedure it.pra_cob_car_extraccion (p_nro_cuenta in varchar2 default null) is

  v_cod_tas_cargo     ge_movimientos.cod_tasa%type;
  v_val_tas_cargo     ge_movimientos.val_tasa%type;
  v_val_cargo         ge_movimientos.val_tasa%type;
  v_cod_tra_impuesto  ge_movimientos.cod_transaccion%type;
  v_cod_tas_impuesto  ge_movimientos.cod_tasa%type;
  v_val_tas_impuesto  ge_movimientos.val_tasa%type;
  v_val_impuesto      ge_movimientos.val_tasa%type;
  v_car_mas_iva       number(18,2);
  --
  v_cod_tra_cargo     ge_transacciones.cod_transaccion%type := 137; -- transaccion para cargo
  v_cod_gru_transaccion ge_gru_transacciones.cod_gru_transaccion%type := 50; -- grupo para contar transacciones
  v_par_entes         ge_parametros.parametro%type := 'CAN_MAX_TRANSACCION'; -- parametro de entes para plan sueldo
  --
  v_hor_actual        varchar2(8);
  v_fec_actual        date;
  v_fec_inicial       date;
  v_nro_secuencia     number(3) := 0;
  v_nvo_estado        varchar2(1);
  v_sal_disponible    number;
  v_procesa           varchar2(1);
  --
  v_cod_mod_cargo     number(3);
  v_cod_mad_cargo     number(3);
  ---
  v_fre_proceso VARCHAR2(1) := fug_obt_fre_proceso('PRA_COB_CAR_EXTRACCION');
  v_db_prod     VARCHAR2(1) := fug_ind_produccion;
  v_val_exo_cargo    ge_movimientos.val_tasa%TYPE;
  v_val_exo_impuesto ge_movimientos.val_tasa%TYPE;
  v_can_pag_permitidos ge_tas_rangos.val_hasta%TYPE;
  v_nro_cuenta        ge_cuentas.nro_cuenta%type;

cursor ctas is
  select nro_cuenta, cod_moneda, cod_oficina, cod_modulo, cod_modalidad, cod_ente, 'A' tipo
    from ah_cta_vistas a
   where nro_cuenta = nvl(p_nro_cuenta, nro_cuenta)
     and estado not in ('T', 'C', 'A', 'X')
     and ((exists (select 1
                   from ah_movimientos_his           m,
                        ge_gru_transacciones_det g
                  where m.nro_cuenta = a.nro_cuenta
                    and fecha between v_fec_inicial and v_fec_actual
                    and m.estado = 'N'
                    and m.reversado = 'N'
                    and cod_mod_padre = g.cod_modulo
                    and cod_mad_padre = g.cod_modalidad
                    and cod_tra_padre = g.cod_transaccion
                    and g.cod_gru_transaccion = v_cod_gru_transaccion))
      or  (exists (select 1
                   from ge_movimientos          m,
                        ge_gru_transacciones_det g
                  where m.nro_cuenta = a.nro_cuenta
                    and m.estado = 'N'
                    and m.reversado = 'N'
                    and cod_mod_padre = g.cod_modulo
                    and cod_mad_padre = g.cod_modalidad
                    and cod_tra_padre = g.cod_transaccion
                    and g.cod_gru_transaccion = v_cod_gru_transaccion)))
  union all
  select nro_cuenta, cod_moneda, cod_oficina, cod_modulo, cod_modalidad, cod_ente, 'C' tipo
    from cc_cta_corrientes a
   where nro_cuenta = nvl(p_nro_cuenta, nro_cuenta)
     and estado not in ('T', 'C', 'A', 'X')
     and cod_ente is not null -- Solo cuentas de plan sueldo
     and ((exists (select 1
                   from cc_movimientos_his         m,
                        ge_gru_transacciones_det g
                  where m.nro_cuenta = a.nro_cuenta
                    and fecha between v_fec_inicial and v_fec_actual
                    and m.estado = 'N'
                    and m.reversado = 'N'
                    and cod_mod_padre = g.cod_modulo
                    and cod_mad_padre = g.cod_modalidad
                    and cod_tra_padre = g.cod_transaccion
                    and g.cod_gru_transaccion = v_cod_gru_transaccion))
      or  (exists (select 1
                   from ge_movimientos      m,
                        ge_gru_transacciones_det g
                  where m.nro_cuenta = a.nro_cuenta
                    and m.estado = 'N'
                    and m.reversado = 'N'
                    and cod_mod_padre = g.cod_modulo
                    and cod_mad_padre = g.cod_modalidad
                    and cod_tra_padre = g.cod_transaccion
                    and g.cod_gru_transaccion = v_cod_gru_transaccion)));
begin
  v_fec_actual := pag_cal.fu_obt_fec_actual('4');
  v_fec_inicial:= to_date('01/'||to_char(v_fec_actual,'MM/YYYY'),'DD/MM/YYYY');
  v_hor_actual := fug_ini_hora(sysdate,'HH24:MI:SS');
  v_hor_actual := pag_gen.FU_OBT_SIG_SEGUNDO(v_hor_actual);
  v_hor_actual := fug_obt_hor_disponible(v_fec_actual,v_hor_actual,user,'N');

  for reg in ctas loop
    v_nro_cuenta := reg.nro_cuenta;
    v_cod_mod_cargo := reg.cod_modulo;
    v_cod_mad_cargo := reg.cod_modalidad;
    if v_nro_secuencia > 990 then
       v_hor_actual := fug_obt_hor_disponible(v_fec_actual,v_hor_actual,user,'N');
       v_nro_secuencia := 0;
    end if;

    --Verificar si es una cuenta de Plan Sueldo
    If reg.cod_ente Is Not Null Then
      v_cod_tra_cargo := 172;--cargo x extraccion Plan Sueldo
    Else
      v_cod_tra_cargo := 137;--cargo x extraccion normal
    End If;

    --Se cobra cargos por la operacion si corresponde
    prg_obt_car_extraccion (reg.nro_cuenta,
                            reg.tipo,   -- Tipo de cuenta A=Ahorro, C=Cta.CTe.
                            v_cod_gru_transaccion,
                            v_cod_tra_cargo,
                            v_par_entes,
                            v_cod_tas_cargo,
                            v_val_tas_cargo,
                            v_val_cargo,
                            v_cod_tra_impuesto,
                            v_cod_tas_impuesto,
                            v_val_tas_impuesto,
                            v_val_impuesto);

    v_car_mas_iva := nvl(v_val_cargo,0) + nvl(v_val_impuesto,0);
    /*
    || PCC-Exoneración y Extorno de Comisiones y Tasas
    || Se ejecuta si el proceso no es mensual
    || o la base de datos no es producción
    */
    IF v_fre_proceso <> 'M' OR v_db_prod = 'N' THEN
       -- Proceso que obtiene el valor de la tasa a partir del saldo y la cantidad de extracciones
       prc_obt_cargos(reg.cod_oficina,
                      null,
                      reg.cod_moneda,
                      0,
                      0,   -- cantidad de extracciones
                      reg.cod_modulo,
                      reg.cod_modalidad,
                      v_cod_tra_cargo, --Transaccion para el cobro de cargos por extraccion
                      v_cod_tas_cargo,
                      v_val_tas_cargo,
                      v_val_exo_cargo,
                      v_cod_tra_impuesto,
                      v_cod_tas_impuesto,
                      v_val_tas_impuesto,
                      v_val_exo_impuesto,
                      v_can_pag_permitidos);

       if pag_cta.fu_ver_tra_prohibida(reg.nro_cuenta,
                                       v_cod_tra_cargo,
                                       reg.cod_modulo,
                                       reg.cod_modalidad) = 'S' then
          prg_ins_exoneracion(v_cod_tra_cargo, reg.cod_modulo,
                              reg.cod_modalidad, reg.cod_moneda,
                              reg.nro_cuenta, null, v_cod_tas_cargo,
                              v_val_exo_cargo,
                              v_val_exo_cargo, null,
                              v_val_exo_cargo);
       elsif (nvl(v_val_cargo, 0) <> nvl(v_val_exo_cargo, 0)) or
             (nvl(v_val_cargo, 0) = 0 and nvl(v_val_exo_cargo, 0) <> 0) then
          prg_ins_exoneracion(v_cod_tra_cargo, reg.cod_modulo,
                              reg.cod_modalidad, reg.cod_moneda,
                              reg.nro_cuenta, null, v_cod_tas_cargo,
                              (nvl(v_val_exo_cargo, 0) - nvl(v_val_cargo, 0)),
                               v_val_exo_cargo, null,
                              (nvl(v_val_exo_cargo, 0) - nvl(v_val_cargo, 0)));
       end if;
       if pag_cta.fu_ver_tra_prohibida(reg.nro_cuenta,
                                       v_cod_tra_impuesto,
                                       reg.cod_modulo,
                                       reg.cod_modalidad) = 'S' then
          prg_ins_exoneracion(v_cod_tra_impuesto, reg.cod_modulo,
                              reg.cod_modalidad, reg.cod_moneda,
                              reg.nro_cuenta, null, v_cod_tas_impuesto,
                              (nvl(v_val_impuesto, 0) - nvl(v_val_exo_impuesto, 0)),
                               v_val_exo_impuesto, null,
                              (nvl(v_val_impuesto, 0) - nvl(v_val_exo_impuesto, 0)));
       elsif pag_cta.fu_ver_tra_prohibida(reg.nro_cuenta,
                                          v_cod_tra_cargo,
                                          reg.cod_modulo,
                                          reg.cod_modalidad) = 'S' then
          null;
       elsif (nvl(v_val_impuesto, 0) <> nvl(v_val_exo_impuesto, 0)) or
             (nvl(v_val_impuesto, 0) = 0 and nvl(v_val_exo_impuesto, 0) <> 0) then
          prg_ins_exoneracion(v_cod_tra_impuesto, reg.cod_modulo,
                              reg.cod_modalidad, reg.cod_moneda,
                              reg.nro_cuenta, null, v_cod_tas_impuesto,
                              (nvl(v_val_exo_impuesto, 0) - nvl(v_val_impuesto, 0)),
                               v_val_exo_impuesto, null,
                              (nvl(v_val_exo_impuesto, 0) - nvl(v_val_impuesto, 0)));
       end if;
    end if;
    ---
    if pag_cta.fu_ver_tra_prohibida(reg.nro_cuenta,
                                    v_cod_tra_cargo,
                                    reg.cod_modulo,
                                    reg.cod_modalidad) = 'N' then
       if v_car_mas_iva > 0 then
         pag_cta.G_COD_ERROR := 0;
         -- verifico si puedo o no cobrar el cargo + iva
         pag_cta.PR_VER_OPERACION(reg.nro_cuenta,
                                  382, -- padre
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
                                  v_cod_tra_cargo);
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
                 values (reg.nro_cuenta, v_fec_actual, v_cod_mod_cargo, v_cod_mad_cargo, v_cod_tra_cargo,
                         v_cod_mod_cargo, v_cod_mad_cargo, v_cod_Tra_cargo, v_car_mas_iva,
                         v_hor_actual, user, reg.cod_moneda,
                         reg.cod_oficina, pag_cta.g_cod_error, 'I', reg.cod_oficina,
                         'Cargo x Extraccion',V_COD_TAS_CARGO, V_VAL_TAS_CARGO,
                         reg.nro_cuenta /* nro_documento=cuenta*/, v_car_mas_iva,
                         pag_cta.G_MSJ_ERROR);
            end if;
         end if;

         if nvl(v_val_cargo,0) > 0 THEN
           ---Se agrega el bloque de control de nro de secuencia - DYDMR-10234
           if v_nro_secuencia > 990 then
              v_hor_actual := fug_obt_hor_disponible(v_fec_actual,v_hor_actual,user,'N');
              v_nro_secuencia := 0;
           end if;
           pag_cta.G_COD_ERROR := 0;
           pag_cta.pr_act_operacion(reg.nro_cuenta,
                                    v_hor_actual,
                                    'D', -- debito a la cuenta del cliente
                                    reg.cod_moneda,
                                    v_val_cargo,
                                    v_cod_tra_cargo, -- trans. padre
                                    v_cod_tra_cargo, -- trans. hijo
                                    reg.nro_cuenta,
                                    null, -- cotizacion
                                    reg.cod_oficina,
                                    v_cod_mod_cargo,
                                    v_cod_mad_cargo,
                                    V_COD_TAS_CARGO, -- tasa
                                    V_VAL_TAS_CARGO, -- valor de tasa
                                    'Cargo x Extraccion', --concepto
                                    'N', -- emitir aviso
                                    v_nro_secuencia, -- nro de secuencia
                                    v_fec_actual);
           if pag_cta.fu_ver_tra_prohibida(reg.nro_cuenta,
                                       v_cod_tra_impuesto,
                                       reg.cod_modulo,
                                       reg.cod_modalidad) = 'N' and
             v_val_impuesto > 0 and  pag_cta.g_cod_error = 0 THEN
             ---Se agrega el bloque de control de nro de secuencia - DYDMR-10234
             if v_nro_secuencia > 990 then
                v_hor_actual := fug_obt_hor_disponible(v_fec_actual,v_hor_actual,user,'N');
                v_nro_secuencia := 0;
             end if;
             pag_cta.pr_act_operacion(reg.nro_cuenta,
                                      v_hor_actual,
                                      'D', -- debito a la cuenta del cliente
                                      reg.cod_moneda,
                                      v_val_impuesto,
                                      v_cod_tra_impuesto, -- trans. padre
                                      V_COD_TRA_IMPUESTO, -- trans. hijo
                                      reg.nro_cuenta,
                                      null, -- cotizacion
                                      reg.cod_oficina,
                                      v_cod_mod_cargo,
                                      v_cod_mad_cargo,
                                      V_COD_TAS_IMPUESTO, -- tasa
                                      V_VAL_TAS_IMPUESTO, -- valor de tasa
                                      'IVA s/Cargo x Extraccion', --concepto
                                      'N', -- emitir aviso
                                      v_nro_secuencia, -- nro de secuencia
                                      v_fec_actual);

           End if;

         End if;
       end if;
    END IF;
  end loop;
exception
  when others then
     raise_application_error(-20111,'Error Cta '||v_nro_cuenta||'-'||sqlerrm);
end pra_cob_car_extraccion;
/

