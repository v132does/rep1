create or replace procedure it.prt_val_acr_gourmet is
  v_cod_ente       ge_entes.cod_ente%type;
  v_nro_cta_debito ge_cuentas.nro_cuenta%type;
  v_cta_tarjeta    ta_tarjetas.nro_cuenta%type;
  v_total          ah_cta_vistas.sal_total%type;
  v_saldo          ah_cta_vistas.sal_total%type;
  v_fec_actual     ge_movimientos.fecha%type := pag_cal.fu_obt_fec_actual(5);
  v_existe         varchar2(1) := 'S';
  v_cod_persona    ba_personas.cod_persona%type;
  v_error          varchar2(1) := 'N';
  v_salir          exception;
  v_nro_lote       ta_acr_gourmet.nro_archivo%type;
  v_tot_monto      ah_cta_vistas.sal_total%type;
  v_cantidad       number;
  v_can_tarjetas   number;
  v_cli_principal  ge_cta_clientes.cod_persona%type;
  v_nro_documento  ba_personas.nro_documento%type;
begin
  -- Author  : Gabriel Capo
  -- Created : 19/12/2013
  -- Purpose : Valida los datos insertados en ta_acr_gourmet_tmp, a través del proc. importacion de datos ACR_GOU_NOMINAS--
  begin
    select 'S' into v_existe from ta_acr_gourmet_tmp b;
  exception
    when no_data_found then
      v_error := 'S';
      RAISE_APPLICATION_ERROR(-20000,
                              'No hay datos que procesar, favor verifique');
    when too_many_rows then
      v_existe := 'S';
  end;
  
  begin
     select distinct b.cod_ente, b.nro_cta_debito
       into v_cod_ente, v_nro_cta_debito
       from ta_acr_gourmet_tmp b
      where fec_proceso is null;--rownum = 1;
  exception
    when no_data_found then
      v_error := 'S';
      RAISE_APPLICATION_ERROR(-20000,
                              'No hay datos que procesar, favor verifique');
    when too_many_rows then
      v_error := 'S';
      RAISE_APPLICATION_ERROR(-20000,
                              'Mas de un Ente o Cuenta de Débito a procesar, favor verifique');
  end;
      
  /*
  || Agregar fecha de proceso
  */
  -------------------------------
  DELETE FROM TA_VAL_ACR_ERRORES
   WHERE cod_ente = v_cod_ente
     AND nvl(fec_proceso,v_fec_actual) = v_fec_actual;
  COMMIT;
  -------------------------------  
  for xx in (select a.cod_ente, a.nro_cta_debito, a.nro_tarjeta, a.monto
               from ta_acr_gourmet_tmp a
              WHERE cod_ente = v_cod_ente
                AND fec_proceso is null) loop
  
    -------------- validacion --------------
  
    if v_cod_ente <> xx.cod_ente then
      v_error := 'S'; --Agregada esta línea
      insert into TA_VAL_ACR_ERRORES
        (cod_ente, nro_cta_debito, nro_tarjeta, monto, msj_error, fec_proceso)
      values
        (xx.cod_ente,
         xx.nro_cta_debito,
         xx.nro_tarjeta,
         xx.monto,
         'Solo puede realizarse el pago de un Ente por planilla. ' ||
         'Ente Correcto: ' || v_cod_ente || ' , Ente Incorrecto: ' ||
         xx.cod_ente, sysdate);
    end if;
    if v_nro_cta_debito <> xx.nro_cta_debito then
      v_error := 'S'; --Agregada esta línea
      insert into TA_VAL_ACR_ERRORES
        (cod_ente, nro_cta_debito, nro_tarjeta, monto, msj_error, fec_proceso)
      values
        (xx.cod_ente,
         xx.nro_cta_debito,
         xx.nro_tarjeta,
         xx.monto,
         'Las cuenta debito deben ser las mismas por importación. ' ||
         'Nro. Cuenta correcto: ' || v_nro_cta_debito ||
         ' , Nro. Cuenta incorrecto: ' || xx.nro_cta_debito, sysdate);
    end if;
    ------------------------------------------------
    -- COD_ENTE 
    ------------------------------------------------
    begin
      select 'S'
        into v_existe
        from ge_entes b
       where b.cod_ente = xx.cod_ente;
    exception
      when no_data_found then
        v_error := 'S';
        insert into TA_VAL_ACR_ERRORES
          (cod_ente, nro_cta_debito, nro_tarjeta, monto, msj_error, fec_proceso)
        values
          (xx.cod_ente,
           xx.nro_cta_debito,
           xx.nro_tarjeta,
           xx.monto,
           'No existe el nro ente : ' || xx.cod_ente || '.', sysdate);
    end;
    ------------------------------------------------
    -- NRO_CTA_DEBITO 
    ------------------------------------------------
    begin
      select b.cod_persona
        into v_cod_persona
        from ge_entes b
       where b.cod_ente = xx.cod_ente;
    exception
      when no_data_found then
        v_error := 'S';
        insert into TA_VAL_ACR_ERRORES
          (cod_ente, nro_cta_debito, msj_error, fec_proceso)
        values
          (v_cod_ente,
           v_nro_cta_debito,
           'El Ente : ' || xx.cod_ente || ', no existe. ', sysdate);
    end;
  
    begin
      select 'S'
        into v_existe
        from ge_cta_clientes a
       where a.cod_persona = v_cod_persona
         and a.relacion = 'P'
         and a.cod_modulo in (3, 4)
         and a.nro_cuenta = xx.nro_cta_debito;
    exception
      when no_data_found then
        v_error := 'S';
        insert into TA_VAL_ACR_ERRORES
          (cod_ente, nro_cta_debito, nro_tarjeta, monto, msj_error, fec_proceso)
        values
          (xx.cod_ente,
           xx.nro_cta_debito,
           xx.nro_tarjeta,
           xx.monto,
           'La cuenta debito : ' || xx.nro_cta_debito ||
           ', no pertenece al ente : ' || xx.cod_ente, sysdate);
    end;
    ------------------------------------------------
    -- NRO_TARJETA 
    ------------------------------------------------
    begin
      select 'S', c.nro_cuenta
        into v_existe, v_cta_tarjeta
        from ta_tarjetas c, ge_cta_clientes d
       where c.nro_tarjeta = xx.nro_tarjeta
         and c.cod_estado = 6 --Activa
         and c.cod_persona = d.cod_persona
         and c.nro_cuenta = d.nro_cuenta
         and d.cod_modalidad = 501; --Bancard Check
      ------------------------------------------------
      -- NRO_TARJETA PROCESADA
      ------------------------------------------------    
      begin
        --v_fec_actual := pag_cal.fu_obt_fec_actual(5);
      
        select 'S'
          into v_existe
          from ta_cobros c
         where c.fec_valor = v_fec_actual
           and c.fec_proceso = v_fec_actual
           and c.nro_cuenta = v_cta_tarjeta
           and c.nro_tarjeta = xx.nro_tarjeta
           and c.monto = xx.monto
           and c.nro_cta_debito is null
           and rownum = 1;
      
        v_error := 'S';
      
        insert into TA_VAL_ACR_ERRORES
          (cod_ente, nro_cta_debito, nro_tarjeta, monto, msj_error, fec_proceso)
        values
          (xx.cod_ente,
           xx.nro_cta_debito,
           xx.nro_tarjeta,
           xx.monto,
           'La tarjeta nro. : ' || xx.nro_tarjeta ||
           ', ha sido procesada en fecha : ' ||
           to_char(v_fec_actual, 'dd/mm/yyyy') || ', con importe: ' ||
           xx.monto, sysdate);
      
      exception
        when no_data_found then
          null;
      end;
    
    exception
      when no_data_found then
        v_error := 'S';
        insert into TA_VAL_ACR_ERRORES
          (cod_ente, nro_cta_debito, nro_tarjeta, monto, msj_error, fec_proceso)
        values
          (xx.cod_ente,
           xx.nro_cta_debito,
           xx.nro_tarjeta,
           xx.monto,
           'La tarjeta nro. : ' || xx.nro_tarjeta ||
           ', no pertenece a la modalidad 501-Bancard Check- o no está activa ',
           sysdate);
    end;
    ------------------------------------------------
    -- NRO_TARJETA - COD_ENTE
    ------------------------------------------------
    --A solicitud de los usuarios y no pertenece a la funcionalidad a ser implementada en el HB.
    /*begin
      select 'S'
        into v_existe
        from (select a.cod_ente
                from cc_cta_corrientes a, ge_cta_clientes b, ta_tarjetas c
               where a.nro_cuenta = b.nro_cuenta
                 and b.cod_persona = c.cod_persona
                 and b.cod_modulo in (3, 4)
                 and c.nro_tarjeta = xx.nro_tarjeta
              union
              select a.cod_ente
                from ah_cta_vistas a, ge_cta_clientes b, ta_tarjetas c
               where a.nro_cuenta = b.nro_cuenta
                 and b.cod_persona = c.cod_persona
                 and b.cod_modulo in (3, 4)
                 and c.nro_tarjeta = xx.nro_tarjeta) t
       where t.cod_ente = xx.cod_ente;
    
    exception
      when no_data_found then
        v_error := 'S';
        insert into TA_VAL_ACR_ERRORES
          (cod_ente, nro_cta_debito, nro_tarjeta, monto, msj_error)
        values
          (xx.cod_ente,
           xx.nro_cta_debito,
           xx.nro_tarjeta,
           xx.monto,
           'La tarjeta nro. : ' || xx.nro_tarjeta ||
           ', no está realcionada a un cliente de la nómina del ente : ' ||
           xx.cod_ente);
    end;*/
  
  end loop;

  begin
    select sum(a.monto), count(a.nro_tarjeta)
      into v_total, v_cantidad
      from ta_acr_gourmet_tmp a
     where a.cod_ente = v_cod_ente
       and a.nro_cta_debito = v_nro_cta_debito
       and a.fec_proceso is null;
  
    select sum(t.saldo)
      into v_saldo
      from (select cc.sal_total - cc.sal_retenido - cc.sal_bloqueado saldo
              from cc_cta_corrientes cc
             where cc.nro_cuenta = v_nro_cta_debito
            union
            select ah.sal_total - ah.sal_retenido - ah.sal_bloqueado saldo
              from ah_cta_vistas ah
             where ah.nro_cuenta = v_nro_cta_debito) t;
  
    if v_saldo - v_total < 0 then
      v_error := 'S';
    
      insert into TA_VAL_ACR_ERRORES
        (cod_ente, nro_cta_debito, msj_error, fec_proceso)
      values
        (v_cod_ente,
         v_nro_cta_debito,
         'La cuenta nro. : ' || v_nro_cta_debito ||
         ', no posee saldo suficiente para esta transacción. ' ||
         'Saldo Disponible : ' ||
         trim(to_char(v_saldo,
                      '99G999G999G990D90',
                      'NLS_NUMERIC_CHARACTERS = ''.,''')) ||
         ' , Total Transacción : ' ||
         trim(to_char(v_total,
                      '99G999G999G990D90',
                      'NLS_NUMERIC_CHARACTERS = ''.,''')) || '.',
         sysdate);
    end if;
  
  end;
  /*
  || Verificar si ya se proceso en el mismo dia
  */
  select sum(a.monto), count(a.nro_tarjeta)
    into v_tot_monto, v_can_tarjetas
    from ta_acr_gourmet_tmp a
   where a.cod_ente = v_cod_ente
     and a.nro_cta_debito = v_nro_cta_debito
     and a.fec_proceso = v_fec_actual;
     
   if v_tot_monto = v_total and v_cantidad = v_can_tarjetas then
      v_error := 'S';
    
      insert into TA_VAL_ACR_ERRORES
        (cod_ente, nro_cta_debito, msj_error, fec_proceso)
      values
        (v_cod_ente,
         v_nro_cta_debito,
         'Operación ya procesada para el Ente ' || v_cod_ente ||
         ', por monto total de ' ||
         trim(to_char(v_tot_monto,
                      '99G999G999G990D90',
                      'NLS_NUMERIC_CHARACTERS = ''.,''')) ||
         ' y para un total de ' || to_char(v_can_tarjetas) || ' Tarjetas.',
         sysdate);
   end if;
     
  ------------------------------------------------
  -- V_ERROR --
  ------------------------------------------------ 
  if v_error = 'S' then
    DELETE FROM ta_acr_gourmet_tmp
     WHERE cod_ente = v_cod_ente
       AND fec_proceso is null;
    COMMIT;
    RAISE_APPLICATION_ERROR(-20000,
                            'El proceso ha generado error/es durante su ejecución. ' ||
                            'Lo puede verificar en la consulta dinámica ERRORES DE IMPORTACION EN ACREDITACION VALES GOURMET. ');
  else
    /*
    || agregar nro de lote -- Numero de lote HB
    */
    begin
       select S_NRO_OPE_HOMEBANKING.NEXTVAL into v_nro_lote from dual;
    exception
       when others then
          RAISE_APPLICATION_ERROR(-20000,
                                  'Al Obt.Nro.Lote:'||sqlerrm);
    end;
    /*
    || Actualizar fecha de proceso
    */
    v_cli_principal := fug_obt_cli_principal(v_cta_tarjeta);
    v_nro_documento := fue_obt_nro_doc_persona(v_cli_principal);
    update ta_acr_gourmet_tmp a
       set a.fec_proceso = v_fec_actual,
           a.nro_documento = v_nro_documento,
           a.nro_archivo = v_nro_lote
     WHERE cod_ente = v_cod_ente
       AND fec_proceso is null;
    commit;
    ---
    prt_gen_acr_gourmet(v_nro_lote, v_cod_ente);
    ---
  end if;

end;
/

