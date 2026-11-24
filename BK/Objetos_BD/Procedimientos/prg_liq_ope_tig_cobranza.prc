create or replace procedure it.prg_liq_ope_tig_cobranza is

  v_cod_rubro        ge_movimientos.cod_rubro%TYPE;
  v_cod_rub_comision ge_movimientos.cod_rubro%TYPE;
  v_fecha            ge_calendarios.fec_anterior%TYPE;
  v_cod_ent_tigo     ge_entes.cod_ente%type;
  v_nro_secuencia    ge_movimientos.nro_secuencia%TYPE := 0;
  v_hor_cobro        ge_movimientos.hora%TYPE;
  v_hor_actual       VARCHAR2(08) := to_char(SYSDATE, 'HH24:MI:SS'); -- Hora actual
  v_fec_actual       ge_calendarios.fec_actual%type;
  v_fec_hoy          ge_calendarios.fec_actual%type;
  v_cod_ofi_origen   pr_movimientos_his.cod_ofi_origen%TYPE;
  v_cod_usuario      VARCHAR2(10) := upper(USER);
  v_moneda           ba_monedas.cod_moneda%type;
  v_cod_tra_padre    ge_movimientos.cod_tra_padre%TYPE;
  v_red_tigo         ba_cod_referencias.val_minimo%TYPE;
  v_nro_cuenta       bw_pag_servicios.nro_cuenta%type;
  v_cod_modulo       pr_cta_prestamos.cod_modulo%TYPE;
  v_cod_modalidad    pr_cta_prestamos.cod_modalidad%TYPE;
  v_horario          VARCHAR2(1) := 'D'; -- Dia normal
  v_es_mov_noc       VARCHAR2(1) := 'N'; -- Graba S/N mov nocturnos
  v_es_cta_noc       VARCHAR2(1) := 'N'; -- Graba S/N ctas noctunas
  v_fec_valor        ge_movimientos.fec_valor%type;
  v_msj_respuesta    VARCHAR2(250);
  v_cod_respuesta    NUMBER(2) := 0;
  v_est_modulo       ba_modulos.estado%TYPE;
  v_mod_estado       ba_modulos.estado%TYPE;
  RP_PCPRE           PR_CTA_PRESTAMOS%rowtype;
  r_gmovi            ge_movimientos%ROWTYPE;
  v_cta_liquidacion  cc_cta_bancarias.nro_cuenta%type;
  v_mto_total        number(18, 2) := 0;
  v_tot_comision     number(18, 2) := 0;
  v_monto            number(18, 2) := 0;
  v_comision         number(18, 2) := 0;
  v_mto_com_sin_iva  number(18, 2);
  v_cod_tas_iva      ge_tasas.cod_tasa%TYPE := NULL;
  v_cod_tasa         ge_tasas.cod_tasa%TYPE := NULL;
  v_val_tasa         ge_tas_fechas.val_tasa%TYPE;
  v_val_tas_iva      ge_tas_fechas.val_tasa%TYPE;
  v_fec_vigencia     ge_tas_fechas.fec_vigencia%TYPE;
  v_tip_valor        ge_tasas.tip_valor%TYPE;
  v_tipo             ge_tasas.tipo%TYPE;
  v_cargo_iva        ge_movimientos.monto%type;
  v_redondeo         NUMBER(1);
  v_mto_cobrado      bw_pag_servicios.mto_transaccion%type;
  v_det_error        ge_log_errores.det_error%type;
  c                  number := 0;
  v_fec_proceso      timestamp := sysdate;
  v_id               number(10);
  c_tot_procesado    number(10);
  c_can_reg_total    number(10);
  v_cod_oficina      ge_movimientos.cod_oficina%type;
  v_rollback         varchar(1) := 'N';
  cursor c_cobranzas is
    select distinct t.fec_pago,
                    t.transaccion,
                    t.nro_comprobante,
                    t.nro_doc_cliente,
                    t.token,
                    t.referencia,
                    t.mto_comision,
                    t.monto,
                    t.estado,
                    t.rowid
      from it.ge_mov_cob_tigo_tmp t
     where not exists (select 'x'
              from ge_mov_cob_tigo p
             where p.fec_pago = t.fec_pago
               and p.transaccion = t.transaccion
               and p.nro_comprobante = t.nro_comprobante
               and p.nro_doc_cliente = t.nro_doc_cliente
               and p.referencia = t.referencia);

  procedure lp_ver_horario IS

  BEGIN
    v_horario    := 'D'; -- Dia normal
    v_es_mov_noc := 'N'; -- Para grabar en las tablas nocturnas
    v_es_cta_noc := 'N';
    v_fec_actual := pag_cal.fu_obt_fec_actual(6);

    --se busca el estado del módulo 3 debido a ser el primer módulo cuyo estado es modificado
    --en el proceso de cierre
    v_est_modulo := pae_cnf.fu_obt_est_modulo(3);

    IF v_est_modulo = 6 THEN
      -- En cierre.
      v_horario    := 'N'; -- Noche
      v_fec_actual := pag_cal.fu_obt_fec_proxima(6);

      v_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
      v_es_cta_noc := 'S'; -- Solo para que llavee la cuenta nocturna

      v_cod_respuesta := -1;
      v_msj_respuesta := 'Sistema en cierre';
    ELSIF v_est_modulo = 2 THEN
      -- El modulo esta abierto
      -- Verifica la hora --
      NULL;
    ELSE
      v_horario := 'N'; -- Noche
      IF v_est_modulo = 1 THEN
        --En proceso de inicio
        v_fec_actual := pag_cal.fu_obt_fec_actual(6);
      ELSE
        v_fec_actual := pag_cal.fu_obt_fec_proxima(6);
      END IF;
      v_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
      v_es_cta_noc := 'S'; -- Solo para que llavee la cuenta nocturna
    END IF;
    v_fec_valor       := trunc(SYSDATE);
    pag_cta.g_horario := v_horario;
    v_mod_estado      := v_est_modulo;
  END lp_ver_horario;

begin
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;

  v_fecha          := pag_cal.FU_OBT_FEC_ANTERIOR(1); --día hábil anterior
  v_fec_actual     := pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_fec_hoy        := pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_cod_ofi_origen := fug_obt_ofi_usuario(v_cod_usuario);
  v_id             := it.s_liq_cobranzas.nextval;
  v_moneda         := pag_gen.FU_OBT_MON_LOCAL;
  v_cod_tra_padre  := 360;
  -- Call the procedure
  v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                    3,
                                    NULL,
                                    pag_gen.fu_obt_mon_local);
  begin
    select count(t.transaccion)
      into c_can_reg_total
      from it.ge_mov_cob_tigo_tmp t
     where  not exists (select 'x'
              from ge_mov_cob_tigo p
             where p.fec_pago = t.fec_pago
               and p.transaccion = t.transaccion
               and p.nro_comprobante = t.nro_comprobante
               and p.nro_doc_cliente = t.nro_doc_cliente
               and p.referencia = t.referencia);

  exception
    when others then
      v_cod_respuesta := 1;
      v_msj_respuesta := 'Error al obtener total de registros';
  end;
  if nvl(v_cod_respuesta, 0) = 0 then
    begin
      insert into it.ge_liq_red_cobranzas
        (id_proceso,
         red_cobranza,
         fec_proceso,
         usu_proceso,
         tot_reg_archivo,
         tot_reg_encontrado,
         tot_monto,
         tot_comision,
         bco_emisor,
         producto,
         moneda)
      values
        (v_id,
         'TIGO',
         v_fec_proceso,
         user,
         c_can_reg_total,
         null,
         null,
         null,
         null,
         'PRESTAMO',
         v_moneda);
    exception
      when others then
        v_cod_respuesta := 2;
        v_msj_respuesta := 'Error al insertar cabecera';
    end;
  end if;
  BEGIN
    SELECT val_minimo, abreviatura
      INTO v_red_tigo, v_cod_ent_tigo
      FROM ba_cod_referencias
     WHERE dominio = 'PRE_COM_TRA_PAGSER'
       AND significado = 'TIGO';
  EXCEPTION
    WHEN no_data_found THEN
      v_cod_respuesta := 3;
      v_msj_respuesta := 'Error al obtener parametros';
      raise_application_error(-20001, v_msj_respuesta);
  END;

  v_cod_rubro        := fug_obt_parentes(v_cod_ent_tigo, 'COD_RUB_INGRESO');
  v_cod_rub_comision := fug_obt_parentes(v_cod_ent_tigo, 'COD_RUB_COMISION');

  v_cta_liquidacion := fug_obt_pardinamico('CTA_LIQ_TIGO',
                                           NULL,
                                           NULL,
                                           pag_gen.fu_obt_mon_local);
  v_hor_cobro       := fug_obt_hor_disponible(v_fec_hoy,
                                              v_hor_actual,
                                              user,
                                              'N');
  c_tot_procesado   := 0;

  if nvl(v_cod_rubro, '0') = '0' then
    v_cod_respuesta := 8;
    v_msj_respuesta := 'Rubro no definido';
    raise_application_error(-20001, v_msj_respuesta);
  end if;
  if nvl(v_cod_rub_comision, '0') = '0' then
    v_cod_respuesta := 8;
    v_msj_respuesta := 'Rubro comision no definido';
    raise_application_error(-20001, v_msj_respuesta);
  end if;
  if nvl(v_cta_liquidacion, '0') = '0' then
    v_cod_respuesta := 9;
    v_msj_respuesta := 'Cuenta bancaria para liquidacion no definida';
    raise_application_error(-20001, v_msj_respuesta);
  end if;

  savepoint liquidar; ---SAVEPOINT
  for reg in c_cobranzas loop

    v_monto    := round(reg.monto, v_redondeo);
    v_comision := round(reg.mto_comision, v_redondeo);

    begin
      select distinct b.nro_cuenta, b.mto_transaccion
        into v_nro_cuenta, v_mto_cobrado
        from bw_pag_servicios b
       where b.nro_transaccion = reg.transaccion
         and b.red_pago = v_red_tigo
         and trunc(b.fec_insercion) = trunc(reg.fec_pago);
    exception
      when no_data_found then
        v_cod_respuesta := 4;
        v_msj_respuesta := 'No se encontro movimiento';
      WHEN OTHERS THEN
        v_cod_respuesta := 5;
        v_msj_respuesta := 'Error al obtener movimiento';
    end;

    if nvl(v_mto_cobrado, 0) <> reg.monto then
      v_cod_respuesta := 6;
      v_msj_respuesta := 'Monto incorrecto';
    end if;

    if nvl(v_cod_respuesta, 0) = 0 then
      PAP_PRE.PR_OBT_DAT_PRESTAMO(v_nro_cuenta, RP_PCPRE);

      v_cod_modulo    := RP_PCPRE.cod_modulo;
      v_cod_modalidad := RP_PCPRE.cod_modalidad;
      v_cod_oficina   := RP_PCPRE.Cod_Oficina;
      /*Si la moneda del prestamo es distinto a GS*/
      if v_moneda <> RP_PCPRE.Cod_Moneda then
        v_cod_respuesta := 7;
        v_msj_respuesta := 'Moneda incorrecta';
      end if;

      if nvl(v_monto, 0) = 0 then
        v_cod_respuesta := 10;
        v_msj_respuesta := 'Monto no puede ser cero';
      end if;

      IF v_cod_rubro is not null and nvl(v_cod_respuesta, 0) = 0 then
        -- Movimiento contra rubro contable --
        v_nro_secuencia       := nvl(v_nro_secuencia, 0) + 1;
        r_gmovi.cod_usuario   := user;
        r_gmovi.hora          := v_hor_cobro;
        r_gmovi.fecha         := v_fec_hoy;
        r_gmovi.nro_secuencia := v_nro_secuencia;
        r_gmovi.cod_modulo    := v_cod_modulo;
        r_gmovi.cod_modalidad := v_cod_modalidad;
        r_gmovi.cod_oficina   := v_cod_oficina;
        r_gmovi.cod_moneda    := v_moneda;
        r_gmovi.fec_valor     := trunc(sysdate);
        r_gmovi.cod_tra_padre := v_cod_tra_padre;
        r_gmovi.cod_mod_padre := v_cod_modulo;
        r_gmovi.cod_mad_padre := v_cod_modalidad;
        --Transaccion COBRO DE CUENTA CONTABLE
        r_gmovi.cod_transaccion := 842;
        r_gmovi.monto           := round(nvl(v_monto, 0), v_redondeo);
        --r_gmovi.nro_documento   := p_red_pago;
        r_gmovi.referencia     := reg.transaccion;
        r_gmovi.cod_ofi_origen := v_cod_ofi_origen;
        r_gmovi.emi_aviso      := 'N';
        r_gmovi.concepto       := 'Cobro prestamo TIGO ' || v_nro_cuenta;
        r_gmovi.estado         := 'N';
        r_gmovi.reversado      := 'N';
        --Entra el rubro contable
        r_gmovi.cod_rubro     := v_cod_rubro;
        r_gmovi.tip_mov_rubro := 'C';

        begin
          lp_ver_horario;
          pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_mov_noc);

        exception
          when others then
            v_cod_respuesta := 11;
            v_msj_respuesta := DBMS_UTILITY.format_error_backtrace || ' ' ||
                               DBMS_UTILITY.format_error_stack;
        end;

        if v_cta_liquidacion is not null then
          pag_cta.PR_OBT_CUENTA(v_cta_liquidacion);
          /*Debito a la cuenta bancaria*/
          pag_cta.pr_act_operacion(v_cta_liquidacion,
                                   v_hor_cobro,
                                   'D', -- Credito
                                   v_moneda,
                                   round(nvl(v_monto, 0), v_redondeo) -
                                   round(nvl(v_comision, 0), v_redondeo),
                                   8530, --v_cod_tra_padre,
                                   503, -- trans. hijo de efectivo
                                   v_red_tigo,
                                   null, -- cotizacion
                                   v_cod_ofi_origen,
                                   pag_cta.g_ctas.cod_modulo,
                                   pag_cta.g_ctas.cod_modalidad,
                                   null, -- tasa
                                   null, -- valor de tasa
                                   'Debito cobranzas-TIGO', --concepto
                                   'N', -- emitir aviso
                                   v_nro_secuencia, -- nro de secuencia
                                   v_fec_hoy);

          IF pag_cta.G_COD_ERROR <> 0 THEN
            v_cod_respuesta := 12;
            v_msj_respuesta := pag_cta.G_MSJ_ERROR;
          END IF;

        end if;

        if nvl(v_comision, 0) > 0 and nvl(v_cod_rub_comision, '0') != '0' and
           nvl(v_cod_respuesta, 0) = 0 then
          r_gmovi := null;
          -- Movimiento contra rubro contable --
          v_nro_secuencia       := nvl(v_nro_secuencia, 0) + 1;
          r_gmovi.cod_usuario   := user;
          r_gmovi.hora          := v_hor_cobro;
          r_gmovi.fecha         := v_fec_hoy;
          r_gmovi.nro_secuencia := v_nro_secuencia;
          r_gmovi.cod_modulo    := v_cod_modulo;
          r_gmovi.cod_modalidad := v_cod_modalidad;
          r_gmovi.cod_oficina   := v_cod_oficina;
          r_gmovi.cod_moneda    := v_moneda;
          r_gmovi.fec_valor     := trunc(sysdate);
          r_gmovi.cod_tra_padre := v_cod_tra_padre;
          r_gmovi.cod_mod_padre := v_cod_modulo;
          r_gmovi.cod_mad_padre := v_cod_modalidad;
          --Transaccion COBRO DE CUENTA CONTABLE
          r_gmovi.cod_transaccion := 842;
          r_gmovi.monto           := round(v_comision, v_redondeo);
          r_gmovi.nro_documento   := v_red_tigo;
          r_gmovi.referencia      := reg.transaccion;
          r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
          r_gmovi.emi_aviso       := 'N';
          r_gmovi.concepto        := 'Comision Cobro Tarjeta TIGO ' ||
                                     v_nro_cuenta;
          r_gmovi.estado          := 'N';
          r_gmovi.reversado       := 'N';
          --Entra el rubro contable
          r_gmovi.cod_rubro     := v_cod_rub_comision;
          r_gmovi.tip_mov_rubro := 'D';

          begin
            lp_ver_horario;
            pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_mov_noc);

          exception
            when others then
              v_cod_respuesta := 11;
              v_msj_respuesta := DBMS_UTILITY.format_error_backtrace || ' ' ||
                                 DBMS_UTILITY.format_error_stack;
          end;

        end if;

        /*Actualiza como liquidado si no hubo error en el proceso*/
        if nvl(v_cod_respuesta, 0) = 0 then
          v_mto_total     := v_mto_total +
                             round(nvl(v_monto, 0), v_redondeo);
          v_tot_comision  := v_tot_comision +
                             round(nvl(v_comision, 0), v_redondeo);
          c_tot_procesado := c_tot_procesado + 1;
          /*Inserta en la tabla definitiva*/
          insert into ge_mov_cob_tigo
            (fec_pago,
             transaccion,
             nro_comprobante,
             nro_doc_cliente,
             token,
             referencia,
             mto_comision,
             monto,
             estado,
             liquidado,
             nro_cuenta,
             fec_liquidacion,
             id_proceso)
          values
            (reg.fec_pago,
             reg.transaccion,
             reg.nro_comprobante,
             reg.nro_doc_cliente,
             reg.token,
             reg.referencia,
             reg.mto_comision,
             reg.monto,
             reg.estado,
             'S',
             v_nro_cuenta,
             v_fec_proceso,
             v_id);

        end if;

      end if;

    END IF;

    if nvl(v_cod_respuesta, 0) != 0 then
      v_rollback  := 'S';
      v_det_error := 'Fecha: ' || reg.fec_pago || ' Linea: ' || c ||
                     ' Monto: ' || reg.monto || ' Comision: ' ||
                     reg.mto_comision || ' Nro.Documento: ' ||
                     reg.nro_doc_cliente || ' Referencia: ' ||
                     reg.referencia || ' Token: ' || reg.token ||
                     ' Transaccion: ' || reg.transaccion ||
                     ' Nro. comprobante ' || reg.nro_comprobante ||
                     ' Estado: ' || reg.estado || ' Error: ' ||
                     v_cod_respuesta || ' - ' || v_msj_respuesta;

      PRG_INS_LOG_PROGRAMAS('PRG_LIQ_OPE_TIG_COBRANZA',
                            v_det_error,
                            null,
                            null);
    end if;
    v_cod_respuesta := 0;
    v_msj_respuesta := null;
  end loop;

  if nvl(v_rollback, 'N') = 'S' then
    rollback to liquidar;
  end if;

  if nvl(v_cod_respuesta, 0) = 0 then
    begin
      update it.ge_liq_red_cobranzas l
         set tot_reg_encontrado = c_tot_procesado,
             tot_monto          = v_mto_total,
             tot_comision       = v_tot_comision
       where id_proceso = v_id
         and fec_proceso = v_fec_proceso
         and l.red_cobranza = 'TIGO'
         and l.producto = 'PRESTAMO'
         and l.moneda = v_moneda;

    exception
      when others then
        v_cod_respuesta := 14;
        v_msj_respuesta := 'Error al actualizar cabecera';
    end;
    if nvl(v_cod_respuesta, 0) != 0 then
      v_det_error := 'Cta: ' || v_cta_liquidacion || ' Moneda ' || v_moneda ||
                     ' Monto total ' || v_mto_total || ' Total comision ' ||
                     v_tot_comision || ' Error: ' || v_cod_respuesta ||
                     ' - ' || v_msj_respuesta;

      PRG_INS_LOG_PROGRAMAS('PRG_LIQ_OPE_TIG_COBRANZA',
                            substr(v_det_error, 1, 4000),
                            null,
                            null);
    end if;

  end if;

  /*Borra tabla temporal*/

  begin
    delete from it.ge_mov_cob_tigo_tmp;
  exception
    when others then
      v_msj_respuesta := 'No se pudo borrar temporal';
      raise_application_error(-20001, v_msj_respuesta);
  end;

  if nvl(c_tot_procesado, 0) = 0 then
    v_msj_respuesta := 'No se encontraron registros para procesar';
    raise_application_error(-20001, v_msj_respuesta);
  end if;

exception
  when others then
    v_det_error := DBMS_UTILITY.format_error_backtrace || ' ' ||
                   DBMS_UTILITY.format_error_stack;

    PRG_INS_LOG_PROGRAMAS('PRG_LIQ_OPE_TIG_COBRANZA',
                          substr(v_det_error, 1, 4000),
                          null,
                          null);
end prg_liq_ope_tig_cobranza;
/

