create or replace procedure it.prg_act_sal_bts is
  v_cod_ente        ge_entes.cod_ente%type := fug_obt_pardinamico('COD_ENT_BTS',null,null,null,null); -- Codigo Ente Transaferencias BTS
  v_deb_nro_cta     ge_cuentas.nro_cuenta%type := fug_obt_pardinamico('BTS_CTA_CORRESPONSAL',null,null,null,null);
  v_cre_cod_rubro   ge_movimientos.cod_rubro%type := fug_obt_parentes(v_cod_ente,'COD_RUB_PPROV');
  v_monto           ge_movimientos.monto%type;
  v_cod_moneda      ge_movimientos.cod_moneda%type;
  v_cod_mon_credito ge_movimientos.cod_moneda%type;
  v_cod_mon_debito  ge_movimientos.cod_moneda%type;
  v_fec_actual      ge_movimientos.fecha%type := pae_cnf.fu_obt_fec_actual(4);
  --v_hor_actual      ge_movimientos.hora%type := fug_ini_hora(sysdate, 'HH24:MI:SS');
  v_hor_actual      ge_movimientos.hora%type := to_char(sysdate, 'HH24:MI:SS');
  v_cod_modulo      ge_movimientos.cod_modulo%type := 4; -- Cta Corriente
  v_cod_modalidad   ge_movimientos.cod_modalidad%type := 45; -- Corresponsal
  v_cod_transaccion ge_movimientos.cod_transaccion%type := 503; -- Debito en Cta. Corresponsal
  v_cod_oficina     ge_movimientos.cod_oficina%type;
  v_nro_secuencia   ge_movimientos.nro_secuencia%type := 0;
  --
  r_gmovi ge_movimientos%rowtype;
begin
  --
  begin
    select nvl(sum(monto),0)
      into v_monto
      from ge_movimientos
     where cod_tra_padre = 346
       and cod_mod_padre = 9
       and cod_mad_padre = 91
       and nvl(monto,0) > 0
       and cod_rubro = v_cre_cod_rubro
       and nro_documento = v_cod_ente
       and reversado = 'N';
  exception
    when others then
       raise_application_error(-20000,'Error al buscar Movimientos. '||sqlerrm);
  end;
  --
  /*begin
    select cod_oficina
      into v_cod_oficina
      from ba_usuarios
     where cod_usuario = user;
  exception
    when others then
      raise_application_error(-20000,'Error al Buscar la Oficina. '||sqlerrm);
  end;*/
  v_cod_oficina := fug_obt_ofi_usuario(user);
  -- Acreditar a la cuenta contable
  begin
     select c.cod_moneda
       into v_cod_mon_credito
       from cb_rubros c
      where c.cod_rubro = v_cre_cod_rubro;
  exception
     when no_data_found then
       raise_application_error(-20000,'Error al Buscar Mon. del Rub.Ctable. '||v_cre_cod_rubro||' '||sqlerrm);
  end;
  -- Debitar a la cuenta contable
  /*begin
     select c.cod_moneda
       into v_cod_mon_debito
       from ge_cuentas c
      where c.nro_cuenta = v_deb_nro_cta;
  exception
     when no_data_found then
       raise_application_error(-20000,'Error al Buscar la Monda del Rubro Contable. '||sqlerrm);
  end;*/
  v_cod_mon_debito := fug_obt_mon_cta(v_deb_nro_cta);
  --
  if v_cod_mon_credito <> v_cod_mon_debito then
    raise_application_error(-20000,'La Cuenta Contable Crédito y Débito tienen Monedas Diferentes.');
  else
    v_cod_moneda := v_cod_mon_credito;
  end if;
  --
  if nvl(v_monto,0) > 0 then
    --Incidencia DYDMR-2749
    --Se cambio lugar de obtencion de la hora, justo antes de ser utilizado por el movimiento
    --y evitar que la hora obtenida al principio sea usada por otro proceso
    v_hor_actual := fug_obt_hor_disponible(v_fec_actual,v_hor_actual,user,'N');
    pag_cta.pr_act_operacion(v_deb_nro_cta,--P_NRO_CUENTA,
                             v_hor_actual, --P_HORA,
                             'D', --P_TIP_MOVIMIENTO,
                             v_cod_moneda, --P_COD_MONEDA,
                             v_monto, --P_MONTO,
                             v_cod_transaccion, --P_COD_TRA_PADRE,
                             v_cod_transaccion, --P_COD_TRANSACCION,
                             v_cod_ente, -- P_NRO_DOCUMENTO
                             null, --P_COTIZACION,
                             v_cod_oficina, --P_COD_OFI_ORIGEN,
                             v_cod_modulo, --P_COD_MOD_PADRE,
                             v_cod_modalidad, --P_COD_MAD_PADRE,
                             null, --P_COD_TASA,
                             null, --P_VAL_TASA,
                             'Actualiza Saldo Trans BTS', --P_CONCEPTO,
                             'S', --P_EMI_AVISO,
                             v_nro_secuencia, --P_NRO_SECUENCIA,
                             v_fec_actual );--P_FEC_VALOR
    --
    v_nro_secuencia := v_nro_secuencia + 1;
    --
    r_gmovi.fecha 							  := v_fec_actual;
    r_gmovi.fec_valor 					  := v_fec_actual;    
    r_gmovi.hora 								  := v_hor_actual;
    r_gmovi.cod_usuario 				  := user;    
    r_gmovi.nro_secuencia 			  := v_nro_secuencia;
    --    
    r_gmovi.cod_moneda 					  := v_cod_moneda;
    r_gmovi.monto						 		  := v_monto;    
    --
    r_gmovi.cod_modulo 					  := v_cod_modulo; 
    r_gmovi.cod_modalidad 			  := v_cod_modalidad;
    r_gmovi.cod_transaccion 		  := null;    
    --
    r_gmovi.cod_oficina 			    := v_cod_oficina;
    r_gmovi.cod_ofi_origen        := v_cod_oficina;  
    r_gmovi.nro_documento         := v_cod_ente;
    --
    r_gmovi.cod_mod_padre 			  := v_cod_modulo;
    r_gmovi.cod_mad_padre 			  := v_cod_modalidad;
    r_gmovi.cod_tra_padre 			  := v_cod_transaccion;
    --
    r_gmovi.estado 							  := 'N';
    r_gmovi.emi_aviso 					  := 'N';
    r_gmovi.concepto 						  := 'Actualiza Saldo Trans BTS';
    r_gmovi.reversado 					  := 'N';
    r_gmovi.protegido 					  := 'N';
    r_gmovi.tip_mov_rubro  			  := 'C';
    r_gmovi.cod_rubro 					  := v_cre_cod_rubro;
    --
    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
    
  end if;
end;
/

