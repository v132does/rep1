create or replace procedure it.prt_gen_acr_gourmet(p_nro_lote number default null,
                                                p_cod_ente number default null)
  is
  v_cod_modalidad  ge_modalidades.cod_modalidad%type;
  v_cod_modulo     ge_movimientos.cod_modulo%type;
  v_cod_mad_padre  ge_modalidades.cod_modalidad%type;
  v_cod_mod_padre  ge_movimientos.cod_modulo%type;
  v_cta_tarjeta    ta_tarjetas.nro_cuenta%type;
  r_gmovi          ge_movimientos%rowtype;
  v_nro_secuencia  ge_movimientos.nro_secuencia%type := 0;
  v_hora           ge_movimientos.hora %type := to_char(sysdate,'hh24:mi:ss');
  v_cod_ente       ge_entes.cod_ente%type;
  v_nro_cta_debito ge_cuentas.nro_cuenta%type;
  v_monto          ge_movimientos.monto%type;
  v_cod_moneda     ge_movimientos.cod_moneda%type;
  v_fec_actual     ge_movimientos.fecha%type := pag_cal.fu_obt_fec_actual(5);
  v_cod_ofi_origen ge_movimientos.cod_ofi_origen%type;
  v_cod_persona    ge_cta_clientes.cod_persona%type;
  v_cod_oficina    ge_movimientos.cod_oficina%type;
  v_cod_envio      ge_par_web_servicios.cod_envio%type;
  v_cli_principal  ge_cta_clientes.cod_persona%type;
  v_nro_documento  ba_personas.nro_documento%type;
  
  v_est_modulo ba_modulos.estado%type;
  v_horario     varchar2(1) := 'D'; -- Dia normal 
  v_es_nocturno varchar2(1) := 'N'; -- No es Nocturno 
  
  
  cursor c_nomina is
    select cod_ente, nro_cta_debito, nro_tarjeta, monto
      from ta_acr_gourmet_tmp
     where cod_ente = p_cod_ente
       and trunc(fec_insercion) = trunc(sysdate)
       and nro_archivo = p_nro_lote;
    
begin
  -- Author  : Edgar González.
  -- Created : 24/04/2014.
  -- Purpose : Movimiento de débito en la cuenta del ente pago de salario. Movimiento de credito y envio a bancard, en las
  --           cuentas de la nómina a partir de lo registrado en la tabla TA_ACR_GOURMET_TMP.as --
  
  v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(4);

  If v_est_modulo = 2 then
         v_horario := 'D';     -- N=Cerrado,  D=Abierto
         v_es_nocturno := 'N'; -- N=Abierto,  S=Cerrado
     else
         v_horario := 'N' ; -- N=Cerrado, D=Abierto
         v_es_nocturno := 'S'; -- N=Abierto,  S=Cerrado
   end if;
   pag_cta.g_horario := v_horario;
  begin
    select distinct b.cod_ente, b.nro_cta_debito
      into v_cod_ente, v_nro_cta_debito
      from ta_acr_gourmet_tmp b
     where b.cod_ente = p_cod_ente
       and trunc(b.fec_insercion) = trunc(sysdate) --rownum = 1;
       and nro_archivo = p_nro_lote;
  exception
    when no_data_found then
      RAISE_APPLICATION_ERROR(-20000,'No existen datos para realizar los movimientos.');
    when too_many_rows then
      RAISE_APPLICATION_ERROR(-20000,
                              'Mas de un Ente o Cuenta de Débito a procesar, favor verifique');
    when others then
      RAISE_APPLICATION_ERROR(-20000,
                              'Al consultar temp: '|| sqlerrm);
  end;
  
  -- Importe total a debitar de la cuenta del ente.
  select sum(a.monto)
    into v_monto
    from ta_acr_gourmet_tmp a
   where a.cod_ente = v_cod_ente
     and a.nro_cta_debito = v_nro_cta_debito
     and trunc(a.fec_insercion) = trunc(sysdate) --rownum = 1;
     and nro_archivo = p_nro_lote;
     
  -- Moneda, modalidad y módulo de la cuenta del ente.
  select cod_moneda, c.cod_modalidad, c.cod_modulo
    into v_cod_moneda, v_cod_mad_padre, v_cod_mod_padre
    from ge_cuentas c
   where c.nro_cuenta = v_nro_cta_debito;

  v_cod_ofi_origen := fug_obt_ofi_usuario(user);
  --v_fec_actual     := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_nro_secuencia  := nvl(v_nro_secuencia, 0) + 1;

  --------------------------------------------------
  -- MOVIMIENTO DEBITO EN LA CUENTA DEL ENTE
  --------------------------------------------------
  pag_cta.PR_SET_NRO_DOCUMENTO2(p_cod_ente);
  v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, user, v_es_nocturno);
  pag_cta.pr_act_operacion(v_nro_cta_debito,
                           v_hora, --HORA
                           'D',
                           v_cod_moneda, --Moneda de la Operación
                           v_monto,
                           5166, -- COD_TRA_PADRE 
                           5166, -- COD_TRA_HIJO CREDITO CUENTA CLIENTE
                           v_nro_cta_debito, --nro_documento
                           null, --COTIZACION, los pagos son en moneda local
                           v_cod_ofi_origen, --cod_ofi_origen
                           v_cod_mod_padre, --cod_mod_padre
                           v_cod_mad_padre, --o abmc.modalidad --cod_mad_padre 
                           null, --cod_tasa
                           null, --val_tasa
                           'Acreditacion Gourmet Card PS',
                           'S', --emi_aviso
                           v_nro_secuencia,
                           v_fec_actual);

  --------------------------------------------------
  -- MOVIMIENTO CREDITO EN LAS CUENTAS DE LA NOMINA
  --------------------------------------------------
  for i in c_nomina loop
    -- Cuenta y persona al que corresponde la tarjeta.
    select t.nro_cuenta, t.cod_persona
      into v_cta_tarjeta, v_cod_persona
      from ta_tarjetas t
     where t.nro_tarjeta = i.nro_tarjeta;
      
    
    -- Modalidad, módulo y moneda de la cuenta(tarjeta).
    select cod_modalidad, cod_modulo, cod_moneda
      into v_cod_modalidad, v_cod_modulo, v_cod_moneda
      from ge_cuentas
     where nro_cuenta = v_cta_tarjeta;

    --Oficina de la cuenta(tarjeta).
    select c.cod_oficina
      into v_cod_oficina
      from ge_cta_clientes c
     where c.cod_persona = v_cod_persona
       and c.nro_cuenta = v_cta_tarjeta;
  
    --Generar el movimiento por el credito.
    if (pae_cnf.FU_OBT_EST_MODULO(v_cod_mod_padre) = 2  and  nvl(pag_cta.g_horario, 'D') = 'D') or
       (nvl(PAE_CNF.G_PROGRAMA,'x') = 'GPPROFIN') then
        r_gmovi.fecha := PAG_CAL.FU_OBT_FEC_ACTUAL(v_cod_mod_padre);
     else
        pag_cal.pr_obt_dat_calendar(v_cod_mod_padre);
        r_gmovi.fecha :=  pag_cal.g_fec_proxima;
     end if;
    r_gmovi.cod_usuario := user;
    r_gmovi.hora        := v_hora;
    -- Aumento la secuencia.
    v_nro_secuencia         := v_nro_secuencia + 1;
    r_gmovi.nro_secuencia   := v_nro_secuencia;
    r_gmovi.cod_modulo      := v_cod_modulo;
    r_gmovi.cod_modalidad   := v_cod_modalidad;
    r_gmovi.cod_oficina     := v_cod_oficina;
    r_gmovi.cod_moneda      := v_cod_moneda;
    r_gmovi.fec_valor       := v_fec_actual;
    r_gmovi.cod_tra_padre   := 250;
    r_gmovi.cod_mod_padre   := NVL(v_cod_mod_padre, 5);
    r_gmovi.cod_mad_padre   := NVL(v_cod_mad_padre, 501);
    r_gmovi.cod_transaccion := 978;
    r_gmovi.monto           := i.monto;
    r_gmovi.nro_documento   := v_cta_tarjeta;
    r_gmovi.nro_documento2  := p_cod_ente;
    r_gmovi.nro_cuenta      := v_cta_tarjeta;
    r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
    r_gmovi.emi_aviso       := 'N';
    r_gmovi.concepto        := 'Crédito de tarjeta:' || i.nro_tarjeta;
    r_gmovi.estado          := 'N'; -- Movimiento normal
    r_gmovi.reversado       := 'N';
    PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi,v_es_nocturno);
  
    begin
        pat_val.G_PROCESO := 'PRT_GEN_ACR_GOURMET';
       insert into ta_cobros
         (nro_cuenta,
          nro_tarjeta,
          nro_cta_debito,
          fec_proceso,
          monto,
          estado,
          fec_valor,
          observacion,
          hora,
          cod_usuario)
       values
         (v_cta_tarjeta,
          i.nro_tarjeta,
          null,
          v_fec_actual,
          i.monto,
          'P',
          v_fec_actual,
          'Pago por debito en cuenta',
          v_hora,
          user);
    exception
       when others then
          RAISE_APPLICATION_ERROR(-20000,
                                  'Al Ins.TA_COBROS:'||sqlerrm);
    end;
    /*declare
      v_cod_envio ge_par_web_servicios.cod_envio%type;*/
    begin
      select S_COD_ENVIO.NEXTVAL into v_cod_envio from dual;
    exception
       when others then
          RAISE_APPLICATION_ERROR(-20000,
                                  'Al Obt.Cod.Envio:'||sqlerrm);
    end;
   /* begin
      insert into ge_par_web_servicios
        (cod_envio,
         fecha,
         cod_servicio,
         estado,
         dat_enviados,
         cod_programa)
      values
        (v_cod_envio,
         v_fec_actual,
         '000002', --codigo para el servicio de pago de tarjetas
         'P',
         'cardNumber=' || i.nro_tarjeta || '&' || 'amount=' || i.monto, --cardNumber=NRO_TARJETA&amount=MONTO
         'FUJ_PRO_TRANSACCION_250');
     exception
       when others then
          RAISE_APPLICATION_ERROR(-20000,
                                  'Al Ins.GE_PAR_WEB_SERVICIOS:'||sqlerrm);
   end;*/
   /*
   || Obtener nro_documento del titular de la tarjeta
   */
   v_cli_principal := fug_obt_cli_principal(v_cta_tarjeta);
   v_nro_documento := fue_obt_nro_doc_persona(v_cli_principal);
   begin
     insert into ta_acr_gourmet
        (cod_ente,
         nro_cta_debito,
         nro_tarjeta,
         monto,
         nro_archivo,
         estado,
         msj_error,
         nro_documento,
         fec_recepcion)
     values
        (p_cod_ente,
         v_nro_cta_debito,
         i.nro_tarjeta,
         i.monto,
         p_nro_lote,
         'A',--autorizado
         null,--msj_error
         v_nro_documento,--nro_documento del titular de la tarjeta
         v_fec_actual);
     exception
       when others then
          RAISE_APPLICATION_ERROR(-20000,
                                  'Al Ins.TA_ACR_GOURMET:'||sqlerrm);
   end;
    
  end loop;

end;
/

