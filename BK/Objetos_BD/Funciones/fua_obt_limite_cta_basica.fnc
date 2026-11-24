create or replace function it.fua_obt_limite_cta_basica(p_nro_cuenta ge_cta_clientes.nro_cuenta%type default null,
                                                        p_monto      ge_snp_transferencias.monto%type default null,
                                                        p_fecha      ge_snp_transferencias.fec_valor%type default null,
                                                        p_modalidad  ge_snp_transferencias.cod_modalidad%type default null,
                                                        p_moneda     ge_snp_transferencias.cod_moneda%type default 'GS')
  return varchar2 is

  -- Variables.
  v_mto_sue_minimo     number;
  v_can_sue_minimo     number := 0;
  v_mto_lim_cta_basica number := 0;
  v_sal_acu_mes        number;
  v_supera_limite      varchar2(1);
  v_sal_acu_diario     number:=0;
  v_sal_acu_nocturno   number:=0;
  v_cod_error          number;
  v_mensaje            varchar2(2000);
  v_mod_cb             number(3) := fug_obt_pardinamico('COD_MOD_CUENTA_BASICA');
  v_modulo             number(3) := 3;
  v_anho               number := to_number(to_char(p_fecha, 'yyyy'));
  v_mes                number := to_number(to_char(p_fecha, 'mm'));
begin
  v_supera_limite := 'N';
 
  if fua_es_cta_basica(p_nro_cuenta)= 'S' then /*DA-10343*/ 
    begin
      select a.sal_min_vigente
        into v_mto_sue_minimo
        from pr_parametros a
       where rownum = 1;
    exception
      when no_data_found then
        v_mto_sue_minimo := fuh_obt_sal_minimo;
      when others then
        v_mto_sue_minimo := fuh_obt_sal_minimo;
    end;
    v_can_sue_minimo     := fug_obt_pardinamico('CAN_SUE_MINIMO',
                                                v_modulo,
                                                v_mod_cb);
    v_mto_lim_cta_basica := nvl(v_mto_sue_minimo, 0) *
                            nvl(v_can_sue_minimo, 1);
    begin
      select sum(a.tot_creditos)
        into v_sal_acu_mes
        from ah_sal_mensuales a
       where a.nro_cuenta = p_nro_cuenta
         and a.ano = v_anho
         and a.mes = v_mes;
    exception
      when no_data_found then
        v_sal_acu_mes := 0;
      when others then
        v_sal_acu_mes := 0;
    end;
    -- Validacion de Monedas.
    if p_moneda <> pag_gen.FU_OBT_MON_LOCAL then
      begin
        v_mto_lim_cta_basica := pag_gen.FU_CON_MON_A_MONEDA(pag_gen.FU_OBT_MON_LOCAL,
                                                            p_moneda,
                                                            v_mto_lim_cta_basica);
      exception
        when others then
          v_mto_lim_cta_basica := 0;
      end;
    end if;
    -- Control de Limite de Cuenta Basica por operación.
    if p_monto > v_mto_lim_cta_basica then
      v_supera_limite := 'S';
    
    end if;
  
    -- Control de Limite de Cuenta Basica acumulado.
    if nvl(pae_cnf.g_programa, 'X') <> 'AMCANCEL' then
      if ((p_monto) + v_sal_acu_mes) > v_mto_lim_cta_basica then
        v_supera_limite := 'S';
      
      end if;
    end if;
    select sum(m.monto)
        into v_sal_acu_diario
        from ge_movimientos m, ge_transacciones t
        where m.nro_cuenta = p_nro_cuenta
        and m.cod_transaccion = t.cod_transaccion
        and m.cod_modulo = t.cod_modulo
        and m.cod_modalidad = t.cod_modalidad
        and nvl(m.reversado,'N') = 'N'
        and m.cod_moneda = 'GS'
        and nvl(m.monto, 0) != 0
        and t.tipo = 'C'
        and t.afecta='S';
  
        select sum(m.monto)
        into v_sal_acu_nocturno
        from ge_movimientos_noc m, ge_transacciones t
        where m.nro_cuenta = p_nro_cuenta
        and m.cod_transaccion = t.cod_transaccion
        and m.cod_modulo = t.cod_modulo
        and m.cod_modalidad = t.cod_modalidad
        and nvl(m.reversado,'N') = 'N'
        and m.cod_moneda = 'GS'
        and nvl(m.monto, 0) != 0
        and t.tipo = 'C'
        and t.afecta='S';
  
        --Acumulado diario
        v_sal_acu_diario  :=nvl(v_sal_acu_diario,0);
        --Acumulado Nocturno
        v_sal_acu_nocturno:=nvl(v_sal_acu_nocturno,0);
  
        -- Control de Limite de Cuenta Basica acumulado diario.
          if ((p_monto) + (v_sal_acu_diario+v_sal_acu_nocturno)) > v_mto_lim_cta_basica then
            v_supera_limite := 'S';
          
          end if;
    /*Cuenta bajo riesgo*/
  elsif /*:new.cod_modalidad = 334*/
   fug_obt_paradicional(p_nro_cuenta, 'LIM_CRE_TRANSACCIONES') is not null and
   user not in ('APICAJERO') then
    --control solo si es credito
    it.prg_val_cta_baj_riesgo(p_nro_cuenta,
                              p_moneda,
                              v_modulo,
                              p_modalidad,
                              p_monto,
                              v_cod_error,
                              v_mensaje);
  
    if nvl(v_cod_error, 0) != 0 then
      v_supera_limite := 'S';
    end if;
  end if;
   return v_supera_limite;
end;
/

