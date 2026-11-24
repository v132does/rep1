CREATE OR REPLACE PROCEDURE IT.PRG_COB_CAR_SRV
   IS

   v_hora             ge_movimientos.hora%type := pag_gen.fu_obt_sig_segundo(to_char(sysdate,'hh24:mi:ss'));
   v_nro_secuencia    ge_movimientos.nro_secuencia%type := -999;
   v_fec_actual       ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(1);
   v_cod_tra_cargo    ge_transacciones.cod_transaccion%type := null;

   v_cod_tas_car_efe  ge_tasas.cod_tasa%type;
   v_cod_tas_car_cob  ge_tasas.cod_tasa%type;
   v_cod_tas_car_men  ge_tasas.cod_tasa%type;

   v_cod_ente         ge_entes.cod_ente%type;
   v_cod_moneda       ge_cuentas.cod_moneda%type;

   v_cod_modulo       ge_transacciones.cod_modulo%type;
   v_cod_modalidad    ge_transacciones.cod_modalidad%type;
   v_cod_mod_padre    ge_transacciones.cod_modulo%type;
   v_cod_mad_padre    ge_transacciones.cod_modalidad%type;
   v_cod_ofi_origen   ge_cuentas.cod_oficina%type;

   v_cta_cargo        ge_cuentas.nro_cuenta%type;
   v_nvo_estado       ge_cuentas.estado%type;
   v_sal_disponible   cc_cta_corrientes.sal_total%type;
   v_cod_tra_padre    ge_transacciones.cod_transaccion%type;

   v_val_tasa         ge_tas_fechas.val_tasa%type;
   v_val_cargo        ge_tas_fechas.val_tasa%type;
   v_cod_tra_impuesto ge_transacciones.cod_transaccion%type;
   v_cod_tas_impuesto ge_transacciones.cod_tasa%type;
   v_val_tas_impuesto ge_tas_fechas.val_tasa%type;
   v_val_impuesto     ge_tas_fechas.val_tasa%type;
   v_procesado        varchar2(1) := 'S' ;
   v_redondeo         number;
   v_cod_tas_cargo    ge_tasas.cod_tasa%type;

   CURSOR c_entes is
     select distinct a.cod_ente
       from ge_rec_movimientos a
      where a.fec_operacion = pag_cal.fu_obt_fec_actual(1);
   -- cobro de cargo por cantidad de operaciones para efect. y cheq. bbva
   CURSOR c_efec_cnb(p_cod_ente ge_entes.cod_ente%type) is
   select a.nro_cta_credito nro_cta_recaudora,
          sum(nvl(a.mto_efectivo,0) + nvl(a.mto_che_cnb,0)) total,
          a.cod_moneda,
          count(1) cantidad
     from ge_rec_movimientos a
    where a.fec_operacion = pag_cal.FU_OBT_FEC_ACTUAL(4)
      and a.cod_ente = p_cod_ente
      and a.estado = 'N'
      and nvl(fug_obt_parentes(a.cod_ente,'FRE_COB_CARGO'),'D') = 'D'
      and (nvl(a.mto_efectivo,0) + nvl(a.mto_che_cnb,0)) > 0
 group by a.nro_cta_credito, a.cod_moneda;

   -- cobro de cargo por cantidad de operaciones para cheq. c.o.b.
    CURSOR c_che_ob(p_cod_ente ge_entes.cod_ente%type) is
   select a.nro_cta_credito nro_cta_recaudora,
          sum(a.mto_che_cob) total,
          a.cod_moneda,
          count(1) cantidad
     from ge_rec_movimientos a
    where a.fec_operacion = pag_cal.FU_OBT_FEC_ACTUAL(4)
      and a.cod_ente = p_cod_ente
      and a.estado = 'N'
      and nvl(fug_obt_parentes(a.cod_ente,'FRE_COB_CARGO'),'D') = 'D'
      and a.mto_che_cob > 0
 group by a.nro_cta_credito, a.cod_moneda;

   -- cobro de cargo mensual
    CURSOR c_mensual is
    select a.cod_ente, a.nro_cta_credito nro_cta_recaudora,
           sum(nvl(a.tot_deposito,0)) total,
           a.cod_moneda, 1 cantidad
      from ge_rec_movimientos a
     where a.fec_operacion between pag_cal.fu_obt_fec_pri_dia_mes_habil(4)
           and pag_cal.FU_OBT_FEC_ACTUAL(4)
       and a.estado = 'N'
       and nvl(fug_obt_parentes(a.cod_ente,'FRE_COB_CARGO'),'D') = 'M'
       and nvl(a.tot_deposito,0) > 0
  group by a.cod_ente, a.nro_cta_credito, a.cod_moneda
  order by 1,2;
  -- Obtener valor de impuesto
procedure lp_obt_car_impuesto
 (P_COD_OFI_ORIGEN   IN GE_CUENTAS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA       IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MONEDA       IN GE_CUENTAS.COD_MONEDA%TYPE
 ,P_COD_MODULO       IN GE_CUENTAS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD    IN GE_CUENTAS.COD_MODALIDAD%TYPE
 ,P_COD_TRA_CARGO    IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
 ,P_VAL_CARGO        IN OUT GE_MOVIMIENTOS.VAL_TASA%TYPE   -- SE CONSIDERA QUE SIEMPRE EL CARGO INCLUYE IVA
 ,P_COD_TRA_IMPUESTO OUT GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
 ,P_COD_TAS_IMPUESTO OUT GE_MOVIMIENTOS.COD_TASA%TYPE
 ,P_VAL_TAS_IMPUESTO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 ,P_VAL_IMPUESTO     OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 )
 IS
v_fec_vigencia  date;
v_tip_valor     varchar2(1);
v_tipo          varchar2(1);
v_redondeo      number(1);
v_tas_personalizada varchar2(1);
begin
    -- no tiene transaccion prohibida, se calcula
    begin
       select tas_personalizada
         into v_tas_personalizada
         from ge_cuentas
         where nro_cuenta = p_nro_cuenta;
    exception
       when no_data_found then
          raise_application_error(-20000,'Cuenta '||p_nro_cuenta||' no registrada');
    end;
    if p_cod_moneda = pag_gen.FU_OBT_MON_LOCAL then
      v_redondeo := 0;
    else
      v_redondeo := 2;
    end if;
    -- busco el impuesto asociado a este cargo
    begin
      select cod_tra_hijo
        into p_cod_tra_impuesto
        from ge_transacciones_det
       where cod_modulo = p_cod_modulo
         and cod_modalidad = p_cod_modalidad
         and cod_transaccion = p_cod_tra_cargo
         and cod_mod_hijo = p_cod_modulo
         and cod_mad_hijo = p_cod_modalidad
         and rownum = 1;
      -- veo si la cuenta tiene exoneracion de impuestos
      if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                      p_cod_tra_impuesto,
                                      p_cod_modulo,
                                      p_cod_modalidad) = 'N' then
         -- Se encontro impuesto asociado, se calcula
         pag_gen.pr_obt_val_tasa(p_cod_modulo, p_cod_modalidad,
               p_cod_ofi_origen, p_nro_cuenta, p_cod_moneda,
               p_val_cargo, nvl(v_tas_personalizada,'N'), p_cod_tas_impuesto,
               p_cod_tra_impuesto, trunc(sysdate),
               p_val_tas_impuesto, v_fec_vigencia, v_tip_valor, v_tipo);  

         if v_tip_valor = 'V' then
            -- si es un valor, se toma directamente
            p_val_impuesto := nvl(p_val_tas_impuesto,0);
         else
            --
            -- es un porcentaje, se considera incluido en el cargo
            p_val_impuesto := round(nvl(p_val_cargo,0)*
                                    nvl(p_val_tas_impuesto,0)/100,v_redondeo);
         end if;

         if p_val_cargo < 0 then
            raise_application_error(-20000,'Impuesto mas alto que el Cargo');
         end if;
       else
          p_val_impuesto := 0;
       end if;
    exception
       when no_data_found then
          p_val_impuesto := 0;
       when others then
          raise_application_error(-20000,'Al leer Impuesto '||sqlerrm);
    end;
end ;

 
-- Generar movimientos pendientes
procedure lp_gen_mov_pendiente is
   begin
      insert into ge_mov_pendientes
            (nro_cuenta, fecha, cod_modulo, cod_modalidad,
             cod_transaccion, cod_mod_padre, cod_mad_padre, cod_tra_padre,
             monto, hora, cod_usuario, cod_moneda, cod_oficina, cod_error,
             estado, cod_ofi_origen, concepto, cod_tasa,
             val_tasa, nro_documento, saldo, motivo, referencia)
      values
            (v_cta_cargo, v_fec_actual, v_cod_modulo, v_cod_modalidad,
             v_cod_tra_cargo, v_cod_mod_padre, v_cod_mad_padre, v_cod_tra_padre,
             (v_val_cargo + v_val_impuesto), v_hora, user, v_cod_moneda, v_cod_ofi_origen, pag_cta.g_cod_error,
            'I', v_cod_ofi_origen, 'Cargo Serv. Rec. en Ventanilla', v_cod_tas_cargo,
            v_val_tasa, v_cod_ente, v_sal_disponible, pag_cta.G_MSJ_ERROR,v_cta_cargo);
exception
  when others then
    raise_application_error(-20000,'Error al tratar de insertar mov_pendeinte '||v_cta_cargo||'-'||sqlerrm);
end;

--
procedure lp_cob_cargos(p_nro_cuenta ge_cuentas.nro_cuenta%type,
                        p_monto number,
                        p_cod_moneda ba_monedas.cod_moneda%type,
                        p_cantidad number,
                        p_cod_tas_cargo in out number,
                        p_cod_tra_cargo number,
                        p_cod_ente ge_entes.cod_ente%type) is
begin
  pag_cta.PR_OBT_CUENTA(p_nro_cuenta);
  if nvl(p_cantidad,0) > 0 and p_cod_tas_cargo is not null then
       v_cod_tas_cargo := p_cod_tas_cargo;
       v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',NULL,NULL,p_cod_moneda);
           PAG_REC.PR_OBT_CARGOS(pag_cta.G_CTAS.cod_oficina, p_nro_cuenta, p_cod_moneda, p_cantidad,
                                 p_monto, pag_cta.G_CTAS.cod_modulo, pag_cta.G_CTAS.cod_modalidad,
                                 p_cod_tra_cargo,'N', p_cod_tas_cargo, v_val_tasa, v_val_cargo,
                                 v_cod_tra_impuesto, v_cod_tas_impuesto, v_val_tas_impuesto, v_val_impuesto);

              v_cod_mod_padre  := pag_cta.G_CTAS.cod_modulo ;
              v_cod_mad_padre  := pag_cta.G_CTAS.cod_modalidad ;
              v_cod_ofi_origen := pag_cta.G_CTAS.cod_oficina ;
              v_cod_moneda     := pag_cta.G_CTAS.cod_moneda;
              
              --Obtiene valores del impuesto.
        --v_val_cargo := 0;
        v_cod_tra_impuesto := 0;
        v_cod_tas_impuesto := 0;
        v_val_tas_impuesto := 0;
        v_val_impuesto := 0;
        --
        lp_obt_car_impuesto(pag_cta.G_CTAS.cod_oficina,
                             p_nro_cuenta,
                             p_cod_moneda,
                             pag_cta.G_CTAS.cod_modulo,
                             pag_cta.G_CTAS.cod_modalidad,
                             p_cod_tra_cargo,
                             v_val_cargo,
                             v_cod_tra_impuesto,
                             v_cod_tas_impuesto,
                             v_val_tas_impuesto,
                             v_val_impuesto);
        --
        v_val_impuesto := round(nvl(v_val_cargo,0) * (v_val_tas_impuesto/100),v_redondeo);

              if nvl(v_val_cargo, 0) > 0 then
                 -- Verifico si se puede debitar el total del cargo (cargo + Iva)
                 pag_cta.pr_ver_operacion(p_nro_cuenta,
                                          p_cod_tra_cargo,       -- COD_TRA_PADRE
                                          v_cod_mod_padre,       --cod_mod_padre
                                          v_cod_mad_padre,       --cod_mad_padre
                                          'D',
                                          p_cod_moneda,                   --Moneda de la Operacion
                                          v_val_cargo + v_val_impuesto,   -- Valor del Cargo más el impuesto
                                          v_cod_ofi_origen,               --cod_ofi_origen
                                          v_cod_modulo,
                                          v_cod_modalidad,
                                          v_nvo_estado,
                                          v_sal_disponible,
                                          v_procesado,
                                          p_cod_tra_cargo) ;

                 if pag_cta.fu_obt_cod_error() <> 0 or v_procesado = 'N' then
                    v_procesado  := 'N' ;
                 else
                     if v_nro_secuencia > 990 then
                        v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
                        v_nro_secuencia := -999;
                     end if;
                     pag_cta.PR_SET_REFERENCIA(p_nro_cuenta);
                     -- Débito a la Cta. Recaudadora
                     pag_cta.pr_act_operacion(p_nro_cuenta,
                                              v_hora,--HORA
                                              'D',
                                              p_cod_moneda,              --Moneda de la Operacion
                                              v_val_cargo,
                                              p_cod_tra_cargo,           -- COD_TRA_PADRE
                                              p_cod_tra_cargo,           -- COD_TRA_HIJO
                                              p_cod_ente,
                                              null,                      --COTIZACION
                                              v_cod_ofi_origen,          --cod_ofi_origen
                                              v_cod_mod_padre,           --cod_mod_padre
                                              v_cod_mad_padre,           --cod_mad_padre
                                              p_cod_tas_cargo,           --cod_tasa
                                              v_val_tasa,                --val_tasa
                                             'Débito de Cargo de Servicio de Recaudación en Ventanilla.',
                                             'S',                       --emi_aviso
                                             v_nro_secuencia,
                                             v_Fec_actual);

                     if pag_cta.fu_obt_cod_error() <> 0 then
                        v_procesado  := 'N' ;
                     else
                        v_procesado  := 'S' ;
                        if nvl(v_val_impuesto,0) > 0 then
                           pag_cta.PR_SET_REFERENCIA(p_nro_cuenta);
                           --
                           PAG_CTA.PR_ACT_OPERACION(p_nro_cuenta,        -- P_NRO_CUENTA
                                                    v_hora,             -- P_HORA
                                                    'D',                -- P_TIP_MOVIMIENTO
                                                    p_cod_moneda,       -- P_COD_MONEDA
                                                    v_val_impuesto,     -- P_MONTO
                                                    p_cod_tra_cargo,    -- P_COD_TRA_PADRE
                                                    v_cod_tra_impuesto, -- P_COD_TRANSACCION
                                                    p_cod_ente,         --P_NRO_DOCUMENTO
                                                    null,                --P_COTIZACION
                                                    v_cod_ofi_origen,    --cod_ofi_origen
                                                    v_cod_mod_padre,     --cod_mod_padre
                                                    v_cod_mad_padre,     --cod_mad_padre
                                                    v_cod_tas_impuesto,            --P_COD_TASA
                                                    v_val_tas_impuesto,            --P_VAL_TASA
                                                    'Impuesto por Cargo de Servicio de Recaudación en Ventanilla.',  -- P_CONCEPTO
                                                    'S',                           -- p_EMI_AVISO
                                                    v_nro_secuencia,               -- P_NRO_SECUENCIA IN OUT
                                                    v_Fec_actual );

                           if pag_cta.fu_obt_cod_error() <> 0 then
                              raise_application_error(-20000,'Error en mov. impuesto '||v_cta_cargo||'-'||sqlerrm);
                           else
                              v_procesado  := 'S' ;
                           end if;
                       end if;
                    end if ;
                 end if;
              end if ;
              -- Si existe cargo y no pudo debitar genera movimiento pendiente
              if nvl(v_val_cargo, 0) > 0 and v_procesado = 'N' then
                 -- Si existe cargo a cobrar y no se puede procesar se debe generar movimiento pendiente.
                 lp_gen_mov_pendiente ;
              end if ;
           end if ;
  end;

Begin
  Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; End;
  pag_cal.pr_obt_dat_calendar(4);
  for e in c_entes loop

    v_cod_tra_cargo    := fug_obt_parentes(e.cod_ente,'COD_TRA_CAR_SRV');
    v_cod_tra_padre    := v_cod_tra_cargo;
    -- tasas de cargos.
    v_cod_tas_car_efe  := fug_obt_parentes(e.cod_ente,'COD_TAS_CAR_EFE');
    v_cod_tas_car_cob  := fug_obt_parentes(e.cod_ente,'COD_TAS_CAR_COB');


    v_cod_ente        := e.cod_ente ;
    -- efectivo y cheques n.b.
    for k in c_efec_cnb(e.cod_ente) loop
        v_cta_cargo := k.nro_cta_recaudora;
        lp_cob_cargos(k.nro_cta_recaudora,
                      k.total,
                      k.cod_moneda,
                      k.cantidad,
                      v_cod_tas_car_efe,
                      v_cod_tra_cargo,
                      v_cod_ente);

    end loop;
    -- cheques c.o.b.
    for k in c_che_ob(e.cod_ente) loop
        v_cta_cargo := k.nro_cta_recaudora;
        lp_cob_cargos(k.nro_cta_recaudora,
                      k.total,
                      k.cod_moneda,
                      k.cantidad,
                      v_cod_tas_car_cob,
                      v_cod_tra_cargo,
                      v_cod_ente);

    end loop;

    v_cod_tra_cargo    := null;

    v_cod_tas_car_efe  := null;
    v_cod_tas_car_cob  := null;
    v_cod_tas_car_men  := null;
    --
    v_cod_ente         := null;

  end loop;
  -- Mensual
  if v_fec_actual = pag_cal.g_ult_dia_mes_habil then
    for k in c_mensual loop

        v_cod_tas_car_men  := fug_obt_parentes(k.cod_ente,'COD_TAS_MENSUAL');
        v_cod_tra_cargo    := fug_obt_parentes(k.cod_ente,'COD_TRA_CAR_SRV');

        v_cta_cargo := k.nro_cta_recaudora;
        lp_cob_cargos(k.nro_cta_recaudora,
                      k.total,
                      k.cod_moneda,
                      k.cantidad,
                      v_cod_tas_car_men,
                      v_cod_tra_cargo,
                      k.cod_ente);

    end loop;
  end if;
End ;
/

