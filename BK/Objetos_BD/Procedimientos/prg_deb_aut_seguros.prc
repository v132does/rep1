create or replace procedure it.PRG_DEB_AUT_SEGUROS is

  v_procesar        varchar2(1) := 'S';
  v_cod_tra_padre   ge_transacciones.cod_transaccion%type := fug_obt_pardinamico('COD_TRA_SEGUROS');--nueva transaccion
  v_cod_mod_deb     ge_cuentas.cod_modulo%type;
  v_cod_mad_deb     ge_cuentas.cod_modalidad%type;
  v_cod_ofi_deb     ge_cuentas.cod_oficina%type;
  v_cod_mon_deb     ge_cuentas.cod_moneda%type;
  v_sal_disponible  ge_cuentas.sal_contable%type;
  v_nvo_estado      ge_cuentas.estado%type;
  v_hora            ge_movimientos.hora%TYPE := to_char(SYSDATE, 'hh24:mi:ss');
  v_nro_documento   ge_movimientos.nro_documento%type;
  v_nro_secuencia   ge_movimientos.nro_secuencia%type default 0;
  v_fec_actual      date default pag_cal.fu_obt_fec_actual(1);
  v_mto_debitado    ge_movimientos.monto%type;
  v_cod_ofi_origen  ge_movimientos.cod_ofi_origen%type;
  v_mto_cargo       ge_movimientos.monto%type;
  v_cod_tra_impuesto ge_movimientos.cod_transaccion%type;
  v_cod_tas_impuesto ge_movimientos.cod_tasa%type;
  v_val_tas_impuesto ge_movimientos.val_tasa%type;
  v_mto_impuesto     ge_movimientos.monto%type;
  r_gmovi           ge_movimientos%rowtype;
  v_iva             number(3,1) := 1.1;
  v_lugar           varchar2(200);
  v_can_cuo_baja    number(10) := nvl(fug_obt_pardinamico('CAN_CUO_BAJ_SEGUROS'),12);--Cantidad de Cuotas para Baja de Seguro
  v_can_dia_int_cob number := fug_obt_pardinamico('REN_SEG_INT_COB'); 
  
/*Debito de Cuotas por seguros vendidos por el Banco.
01/2017- Se agrega cancelación de Cuenta por no pago de 3 meses de seguros
*/
  cursor c_seg is
    select a.cod_persona,a.nro_seguro,a.nro_cta_debito,b.nro_cuota,b.monto,b.fec_vencimiento,a.cod_canal,
           a.cod_tip_seguro
      from ge_cli_seguros a, ge_cuo_seguros b
     where a.nro_seguro = b.nro_seguro
       and a.estado = 'V'
       and b.estado = 'V'
       and a.cod_tip_seguro not in (2,3) -- vida y AP
       and (b.fec_vencimiento <= pae_cnf.FU_OBT_FEC_ACTUAL(1)
            or (b.nro_cuota = 1 and b.fec_ult_pago is null))
    union all
    select a.cod_persona,a.nro_seguro,a.nro_cta_debito,b.nro_cuota,b.monto,b.fec_vencimiento,a.cod_canal,
       a.cod_tip_seguro
      from ge_cli_seguros a, ge_cuo_seguros b
     where a.nro_seguro = b.nro_seguro
       and a.estado = 'V'
       and b.estado = 'V'
       and a.cod_tip_seguro in (2,3) -- vida y AP
       and a.fec_inicio <= pae_cnf.FU_OBT_FEC_ACTUAL(1) -- para que no traiga los seguros no iniciados generados en la renovación
       and (b.fec_vencimiento <= pae_cnf.FU_OBT_FEC_ACTUAL(1)
            or (b.nro_cuota = 1 and b.fec_ult_pago is null));
  /*Baja de seguros -- EXCLUIR PARA SEGUROS DE VIDA Y AP (por que en este caso no cubriría el seguro, si luego de los 
    3 meses paga ese mes le cubriría*/
  cursor  c_baj is
  select count(*) cantidad, a.nro_seguro
    from ge_cuo_seguros a, ge_cli_seguros cl
      where trunc(a.fec_vencimiento) < trunc(pag_cal.FU_OBT_FEC_ACTUAL(1)) --La Fec.Vto es menor a la fecha el sistema
        and a.estado='N' --No Pagado (La cuota) 
        and a.nro_seguro = cl.nro_seguro
        and cl.cod_tip_seguro not in (2,3)
        and a.nro_seguro in (select w.nro_seguro 
                               from Ge_Cli_Seguros w where w.nro_seguro=a.nro_seguro
                               and w.estado='V' and rownum=1) --Si esta vigente el seguro
    group by a.nro_seguro
    having count(*) >= v_can_cuo_baja;
begin
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
  v_mto_debitado:=0;
  v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
  v_cod_ofi_origen := fug_obt_ofi_usuario(user);

  for k in c_seg loop
    v_lugar:= null; 
     -- Obtener datos cta débito
    begin
      select a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.cod_moneda
        into v_cod_mod_deb, v_cod_mad_deb, v_cod_ofi_deb, v_cod_mon_deb
        from ge_cuentas a
       where a.nro_cuenta = k.nro_cta_debito;
    exception
      when no_data_found then
        v_cod_mod_deb := null;
        v_cod_mad_deb := null;
        v_cod_ofi_deb := null;
        v_cod_mon_deb := null;
      when others then
        v_cod_mod_deb := null;
        v_cod_mad_deb := null;
        v_cod_ofi_deb := null;
        v_cod_mon_deb := null;
    end;

    if k.cod_canal = 29 then --WEB
       v_cod_tra_padre  := fug_obt_pardinamico('COD_TRA_SEGUROS_WEB');
    else
       v_cod_tra_padre  := fug_obt_pardinamico('COD_TRA_SEGUROS');
    end if;

    -- Verifica la operación de débito
     v_lugar:= 'Al Verificar Operacion - Cta: '||k.nro_cta_debito; 
     pag_cta.pr_ver_operacion(k.nro_cta_debito,
                              v_cod_tra_padre,
                              v_cod_mod_deb,
                              v_cod_mad_deb,
                              'D',
                              v_cod_mon_deb,
                              k.monto,
                              v_cod_ofi_deb,
                              -- out
                              pag_cta.g_ctas.cod_modulo,
                              pag_cta.g_ctas.cod_modalidad,
                              v_nvo_estado,
                              v_sal_disponible,
                              v_procesar,
                              503);
    if pag_cta.g_cod_error <> 0 or v_procesar = 'N' then
       v_lugar:= 'En Update: '||k.nro_seguro||'-'||k.nro_cuota;
       if k.cod_tip_seguro not in (2,3) then
          update ge_cuo_seguros a
            set a.estado = 'N'
             where a.nro_seguro = k.nro_seguro
              and a.nro_cuota = k.nro_cuota;
       else
         if (pae_cnf.FU_OBT_FEC_ACTUAL(1) >= k.fec_vencimiento + v_can_dia_int_cob) or nvl(v_can_dia_int_cob, 0) = 0 then
           update ge_cuo_seguros a
            set a.estado = 'N'
             where a.nro_seguro = k.nro_seguro
              and a.nro_cuota = k.nro_cuota;
         end if;
       end if;
    end if;

    if v_procesar = 'S' then
       if v_nro_secuencia > 990 then
          v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
          v_nro_secuencia := 1;
       end if;

       --Actualizar el Saldo cta débito
       pag_cta.pr_act_operacion(k.nro_cta_debito,
              v_hora,
              'D',
              pag_cta.g_ctas.cod_moneda,
              k.monto,
              v_cod_tra_padre,
              503,
              v_nro_documento,          --nro documento
              null,
              v_cod_ofi_origen,         --cod_ofi_origen
              v_cod_mod_deb,             --cod_mod_padre
              v_cod_mad_deb,             --cod_mad_padre
              null,                      --cod_tasa
              null,                      --val_tasa
              substr('DÉBITO POR COBRO DE SEGURO.',1,99) ,
              'S',                       --emi_aviso
              v_nro_secuencia,
              v_fec_actual);
       if pag_cta.g_cod_error <> 0 or v_procesar = 'N' then
         if k.cod_tip_seguro not in (2,3) then
            v_lugar:= 'En Update I: '||k.nro_seguro||'-'||k.nro_cuota;
            update ge_cuo_seguros a
               set a.estado = 'N'
             where a.nro_seguro = k.nro_seguro
               and a.nro_cuota = k.nro_cuota;
         else
           if pae_cnf.FU_OBT_FEC_ACTUAL(1) >= k.fec_vencimiento + v_can_dia_int_cob then
             update ge_cuo_seguros a
              set a.estado = 'N'
               where a.nro_seguro = k.nro_seguro
                and a.nro_cuota = k.nro_cuota;
           end if;
        end if;
       else

         v_mto_cargo        := null;
         v_cod_tra_impuesto := null;
         v_cod_tas_impuesto := null;
         v_mto_impuesto     := null;
         v_val_tas_impuesto := null;
        --calcular impuesto
         v_lugar:= 'Obtener Impuesto: '||k.nro_cta_debito;
         prg_obt_car_impuesto(v_cod_ofi_origen, k.nro_cta_debito, v_cod_mon_deb, v_cod_mod_deb, v_cod_mad_deb,
         v_cod_tra_padre, v_mto_cargo, v_cod_tra_impuesto, v_cod_tas_impuesto, v_val_tas_impuesto, v_mto_impuesto);
         v_mto_impuesto := nvl(v_mto_impuesto,0);
         if v_mto_impuesto = 0 then
           v_mto_cargo := round(k.monto / v_iva);
           v_mto_impuesto := round((round(v_mto_cargo*v_val_tas_impuesto))/100);
         end if;
        --Insertar el Movimiento Por el Cargo
        r_gmovi.cod_usuario     := substr(user,1,10);
        r_gmovi.hora            := v_hora;
        r_gmovi.fecha           := v_fec_actual;
        -- Aumento la secuencia
        v_nro_secuencia         := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        --
        r_gmovi.cod_modulo      := v_cod_mod_deb;
        r_gmovi.cod_modalidad   := v_cod_mad_deb;
        r_gmovi.cod_oficina     := v_cod_ofi_origen;
        r_gmovi.nro_cuenta      := k.nro_cta_debito;
        r_gmovi.cod_moneda      := v_cod_mon_deb;
        r_gmovi.fec_valor       := v_fec_actual;
        r_gmovi.cod_tra_padre   := v_cod_tra_padre;--nvl(reg.cod_tra_padre,150);
        r_gmovi.cod_mod_padre   := v_cod_mod_deb;--nvl(reg.cod_mod_padre,3);
        r_gmovi.cod_mad_padre   := v_cod_mad_deb;--nvl(reg.cod_mad_padre,31);
        r_gmovi.cod_transaccion := v_cod_tra_padre;
        r_gmovi.monto           := v_mto_cargo;
        r_gmovi.nro_documento   := v_nro_documento;
        r_gmovi.nro_documento2  := null;
        r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.concepto        := 'DÉBITO POR COBRO DE SEGURO.';
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.cod_rubro       := null;
        r_gmovi.cod_tasa        := null;
        r_gmovi.val_tasa        := null;
        r_gmovi.tip_mov_rubro   := null;
         v_lugar:= 'Insertar Movimiento Normal: '||k.nro_cta_debito;
         pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
         --Insertar el Movimiento Por el Impuesto
         r_gmovi.cod_usuario     := substr(user,1,10);
         r_gmovi.hora            := v_hora;
         r_gmovi.fecha           := v_fec_actual;
         -- Aumento la secuencia
         v_nro_secuencia         := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia   := v_nro_secuencia;
         --
         r_gmovi.cod_modulo      := v_cod_mod_deb;
         r_gmovi.cod_modalidad   := v_cod_mad_deb;
         r_gmovi.cod_oficina     := v_cod_ofi_origen;
         r_gmovi.nro_cuenta      := k.nro_cta_debito;
         r_gmovi.cod_moneda      := v_cod_mon_deb;
         r_gmovi.fec_valor       := v_fec_actual;
         r_gmovi.cod_tra_padre   := v_cod_tra_padre;--nvl(reg.cod_tra_padre,150);
         r_gmovi.cod_mod_padre   := v_cod_mod_deb;--nvl(reg.cod_mod_padre,3);
         r_gmovi.cod_mad_padre   := v_cod_mad_deb;--nvl(reg.cod_mad_padre,31);
         r_gmovi.cod_transaccion := v_cod_tra_impuesto;
         r_gmovi.monto           := v_mto_impuesto;
         r_gmovi.nro_documento   := v_nro_documento;
         r_gmovi.nro_documento2  := null;
         r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
         r_gmovi.emi_aviso       := 'N';
         r_gmovi.concepto        := 'DÉBITO POR COBRO DE SEGURO.';
         r_gmovi.estado          := 'N';
         r_gmovi.reversado       := 'N';
         r_gmovi.cod_rubro       := null;
         r_gmovi.cod_tasa        := v_cod_tas_impuesto;
         r_gmovi.val_tasa        := v_val_tas_impuesto;
         r_gmovi.tip_mov_rubro   := null;
         v_lugar:= 'Insertar Movimiento Cargo: '||k.nro_cta_debito; 
         pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
       end if;

       if v_procesar = 'S' then
         --Acumulamos el monto débito
         v_lugar:= 'Insertar ge_cob_seguros: '||k.nro_seguro||'-'||k.nro_cuota;
         v_mto_debitado := nvl(v_mto_debitado,0) + nvl(k.monto,0);
         insert into ge_cob_seguros a
           (nro_seguro, nro_cuota, monto, fecha, hora, fec_vencimiento, estado)
         values
           (k.nro_seguro, k.nro_cuota, k.monto, v_fec_actual, v_hora, k.fec_vencimiento,'P');
       end if;
     end if;
  end loop;
  --Para dar de Baja en forma automática sino paga x dias
  for j in c_baj loop
     --Ponemos en Estado de Baja la Cabecera
     v_lugar:= 'Act.Cab.Seg.Baja: '||j.nro_seguro;
 
     Update ge_cli_seguros a
        set a.estado='B',
            a.motivo='Baja Automatica'
      where a.nro_seguro= j.nro_seguro;
                 
      --Damos de Baja las cuotas registradas que no se pagaron
      v_lugar:= 'Act.Cuotas.Seg.Baja: '||j.nro_seguro;       
      Update ge_cuo_seguros a
         set a.estado='B'
       where a.nro_seguro= j.nro_seguro
         and a.fec_ult_pago is null; --Todos los que no se pagaron   
  end loop;
  
exception
  when others then
      RAISE_APPLICATION_ERROR(-20001,'Error- Deb.Seg-Lugar: '||v_lugar||'-'||sqlerrm); 
end PRG_DEB_AUT_SEGUROS;
/

