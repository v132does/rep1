create or replace procedure it.prg_liq_ope_doc_cobranza is

  RP_PCPRE            PR_CTA_PRESTAMOS%rowtype;
  v_cod_rubro         ge_movimientos.cod_rubro%TYPE;
  v_cod_rub_usd       ge_movimientos.cod_rubro%TYPE;
  v_cod_rub_gs        ge_movimientos.cod_rubro%TYPE;
  v_fecha             ge_calendarios.fec_anterior%TYPE;
  v_cod_ent_documenta ge_entes.cod_ente%type;
  v_nro_secuencia     ge_movimientos.nro_secuencia%TYPE := 0;
  v_hor_cobro         ge_movimientos.hora%TYPE;
  v_hor_actual        VARCHAR2(08) := to_char(SYSDATE, 'HH24:MI:SS'); -- Hora actual
  v_fec_actual        ge_calendarios.fec_actual%type;
  v_fec_hoy           ge_calendarios.fec_actual%type;
  v_cod_ofi_origen    pr_movimientos_his.cod_ofi_origen%TYPE;
  v_cod_usuario       VARCHAR2(10) := upper(USER);
  v_moneda            ba_monedas.cod_moneda%type;
  v_par_moneda        ba_monedas.cod_mon_bco_central%type;
  v_cod_tra_padre     ge_movimientos.cod_tra_padre%TYPE;
  v_red_documenta     ba_cod_referencias.val_minimo%TYPE;
  v_horario           VARCHAR2(1) := 'D'; -- Dia normal
  v_es_mov_noc        VARCHAR2(1) := 'N'; -- Graba S/N mov nocturnos
  v_es_cta_noc        VARCHAR2(1) := 'N'; -- Graba S/N ctas noctunas
  v_fec_valor         ge_movimientos.fec_valor%type;
  v_msj_respuesta     VARCHAR2(4000);
  v_cod_respuesta     NUMBER(2) := 0;
  v_est_modulo        ba_modulos.estado%TYPE;
  v_mod_estado        ba_modulos.estado%TYPE;
  r_gmovi             ge_movimientos%ROWTYPE;
  v_cta_liquidacion   cc_cta_bancarias.nro_cuenta%type;
  v_mto_total         number(18, 2) := 0;
  v_tot_comision      number(18, 2) := 0;
  v_monto             number(18, 2) := 0;
  v_comision          number(18, 2) := 0;
  v_mora              number(18, 2) := 0;
  v_int_punitorio     number(18, 2) := 0;
  v_mto_com_sin_iva   number(18, 2);
  v_cod_tas_iva       ge_tasas.cod_tasa%TYPE := NULL;
  v_cod_tasa          ge_tasas.cod_tasa%TYPE := NULL;
  v_val_tasa          ge_tas_fechas.val_tasa%TYPE;
  v_val_tas_iva       ge_tas_fechas.val_tasa%TYPE;
  v_fec_vigencia      ge_tas_fechas.fec_vigencia%TYPE;
  v_tip_valor         ge_tasas.tip_valor%TYPE;
  v_tipo              ge_tasas.tipo%TYPE;
  v_cargo_iva         ge_movimientos.monto%type;
  v_redondeo          NUMBER(1);
  v_mto_cobrado       bw_pag_servicios.mto_transaccion%type;
  v_error             ge_log_errores.det_error%type;
  v_det_error         ge_log_errores.det_error%type;
  v_en_juicio         ta_cta_tarjetas.en_juicio%TYPE;
  v_estado            ta_cta_tarjetas.estado%type;
  c                   number := 0;
  v_nro_tarjeta       ta_tarjetas.nro_tarjeta%type;
  v_nro_cuenta        ta_cta_tarjetas.nro_cuenta%type;
  v_nro_documento     ba_personas.nro_documento%type;
  v_nom_embozar       ta_tarjetas.nom_embozar%type;
  v_des_modalidad     ge_modalidades.descripcion%type;
  v_cod_moneda        ta_cta_tarjetas.cod_moneda%type;
  v_sal_pag_minimo    ta_cta_tarjetas.sal_pag_minimo%type;
  v_mto_pag_minimo    ta_cta_tarjetas.mto_pag_minimo%type;
  v_sal_ult_extracto  ta_cta_tarjetas.sal_ult_extracto%type;
  v_deu_tot_actual    ta_cta_tarjetas.sal_ult_extracto%type;
  v_fec_ult_cierre    ta_cta_tarjetas.fec_ult_cierre%type;
  v_cod_modulo        ta_cta_tarjetas.cod_modulo%type;
  v_cod_modalidad     ta_cta_tarjetas.cod_modalidad%type;
  v_cod_oficina       ta_cta_tarjetas.cod_oficina%type;
  v_dia_mora          ta_cta_tarjetas.dia_mora%type;
  v_cod_error         number;
  v_respuesta         varchar2(500);
  v_banco             ba_cod_referencias.val_minimo%type;
  v_tip_producto      varchar2(2); --01 prestamos 02 tarjetas
  v_bco_emisor        ge_mov_cob_documenta.bco_emisor%type;
  v_fec_proceso       timestamp := sysdate;
  v_id                number(10);
  c_tot_procesado     number(10);
  v_producto          VARCHAR2(20);
  v_red_pago          varchar2(50) := 'DOCUMENTA';
  v_rollback          varchar2(1):='N';-- bandera para hacer el rollback al final
  v_reg_existe        varchar2(1):='N'; -- bandera que indica que hay por lo menos un registro
  cursor c_cobranzas(p_par_moneda in varchar2,
                     p_producto   in varchar2,
                     p_bco_emisor in varchar2) is
    select distinct t.terminal,
           t.fec_proceso,
           t.fec_pago,
           t.hor_pago,
           t.nro_boleta,
           t.referencia,
           t.nro_operacion,
           t.nro_tarjeta,
           t.nro_cuenta,
           t.importe,
           t.comision,
           t.cod_producto,
           t.moneda,
           t.bco_emisor
      from it.ge_mov_cob_documenta_tmp t
     where t.cod_producto = p_producto
       and t.moneda = p_par_moneda
       and t.bco_emisor = p_bco_emisor
       and not exists
     (select 'x'
              from ge_mov_cob_documenta p
             where t.fec_proceso = p.fec_pago
               and to_number(t.referencia) = to_number(p.referencia)
               and t.nro_operacion = p.nro_operacion
               and t.bco_emisor = p.bco_emisor
               and t.cod_producto = p.cod_producto
               and t.moneda = p.moneda);

  cursor c_liq_cuentas is
    select distinct r.val_minimo    tip_producto,
                    r.abreviatura   nom_producto,
                    p.cod_moneda,
                    p.val_parametro cta_liquidacion,
                    c.val_minimo    bco_emisor
      from ba_cod_referencias r, ge_par_dinamicos p, ba_cod_referencias c
     where r.dominio = 'TIP_OPE_DOCUMENTA'
       and p.parametro = c.abreviatura
       and c.dominio = 'BCO_DOCUMENTA';

  cursor c_tot_archivo is
    select t.cod_producto,
           fue_obt_mon_bcp(t.moneda) moneda,
           t.bco_emisor,
           count(t.nro_boleta) can_reg_total
      from it.ge_mov_cob_documenta_tmp t
     where not exists
     (select 'x'
              from ge_mov_cob_documenta p
             where t.fec_pago = p.fec_pago
               and to_number(t.referencia) = to_number(p.referencia)
               and t.nro_operacion = p.nro_operacion
               and t.bco_emisor = p.bco_emisor
               and t.cod_producto = p.cod_producto
               and t.moneda = p.moneda)
     group by t.cod_producto, t.moneda, t.bco_emisor;

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
  v_fecha          := pag_cal.FU_OBT_FEC_ANTERIOR(1); --día hábil anterior
  v_fec_hoy        := pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_cod_ofi_origen := fug_obt_ofi_usuario(v_cod_usuario);
  v_id             := it.s_liq_cobranzas.nextval;
  -- Call the procedure

  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  for tot in c_tot_archivo loop
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
         v_red_pago,
         v_fec_proceso,
         user,
         tot.can_reg_total,
         null,
         null,
         null,
         tot.bco_emisor,
         decode(tot.cod_producto, '01', 'PRESTAMO', '02', 'TARJETA'),
         tot.moneda);
    exception
      when others then
        v_cod_respuesta := 1;
        v_msj_respuesta := 'Error al insertar cabecera';
    end;
  end loop;


  v_hor_cobro   := fug_obt_hor_disponible(v_fec_hoy,
                                          v_hor_actual,
                                          user,
                                          'N');
  savepoint liquidar;
  for cta in c_liq_cuentas loop
    v_mto_total       := 0;
    v_tot_comision    := 0;
    c_tot_procesado   := 0;
    v_banco           := cta.bco_emisor;
    v_cta_liquidacion := cta.cta_liquidacion;
    begin
      select m.cod_mon_bco_central
        into v_par_moneda
        from ba_monedas m
       where cod_moneda = cta.cod_moneda;
    exception
      when others then
        v_cod_respuesta := 3;
        v_msj_respuesta := 'Error al obtener moneda';
    end;
    v_bco_emisor   := cta.bco_emisor;
    v_tip_producto := cta.tip_producto;

    if cta.tip_producto = '01' then
      v_producto      := 'PRESTAMO';
      v_cod_tra_padre := 360;
    elsif cta.tip_producto = '02' then
      v_producto      := 'TARJETA';
      v_cod_tra_padre := 250;
    end if;
    if cta.tip_producto = '01' then
      --Prestamos
      BEGIN
        SELECT val_minimo, abreviatura
          INTO v_red_documenta, v_cod_ent_documenta
          FROM ba_cod_referencias
         WHERE dominio = 'PRE_COM_TRA_PAGSER'
           AND significado = 'PRACTIPAGO';
      EXCEPTION
        WHEN no_data_found THEN
          v_cod_respuesta := 4;
          v_msj_respuesta := 'Error al obtener parametros';
      END;
        v_cod_rub_gs  := fug_obt_parentes(v_cod_ent_documenta,
                                      'COD_RUB_INGRESO');
       v_cod_rub_usd := fug_obt_parentes(v_cod_ent_documenta,
                                      'COD_RUB_INGRESO_USD');
    elsif cta.tip_producto = '02' then
      --Tarjetas
      BEGIN
        SELECT val_minimo, abreviatura
          INTO v_red_documenta, v_cod_ent_documenta
          FROM ba_cod_referencias
         WHERE dominio = 'TAR_COM_TRA_PAGSER'
           AND significado = 'PRACTIPAGO';
      EXCEPTION
        WHEN no_data_found THEN
          v_cod_respuesta := 5;
          v_msj_respuesta := 'Error al obtener parametros';
      END;
      v_cod_rub_gs  := fug_obt_parentes(v_cod_ent_documenta, 'PAG_TAR_RUBRO'); --Rubro para pagos de tarjeta por boca de cobranza
       v_cod_rub_usd := null;-- no existen tarjetas en dolares
    else
      v_cod_respuesta := 6;
      v_msj_respuesta := 'Tipo producto no definido';
    end if;

    for reg in c_cobranzas(v_par_moneda, v_tip_producto, v_bco_emisor) loop
      v_reg_existe:='S';
      if fue_obt_mon_bcp(reg.moneda) = pag_gen.fu_obt_mon_local then
        v_moneda    := pag_gen.fu_obt_mon_local;
        v_cod_rubro := v_cod_rub_gs;
        v_redondeo  := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                           3,
                                           NULL,
                                           v_moneda);

      elsif fue_obt_mon_bcp(reg.moneda) = pag_gen.FU_OBT_MON_FUERTE then
        v_moneda    := pag_gen.FU_OBT_MON_FUERTE;
        v_cod_rubro := v_cod_rub_usd;
        v_redondeo  := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                           3,
                                           NULL,
                                           v_moneda);
      else
        v_cod_respuesta := 7;
        v_msj_respuesta := 'Moneda incorrecta';
      end if;
      v_monto    := to_number(substr(lpad(round(reg.importe, v_redondeo),
                                          15,
                                          '0'),
                                     1,
                                     13) || '.' ||
                              substr(lpad(round(reg.importe, v_redondeo),
                                          15,
                                          '0'),
                                     14,
                                     2),
                              '9999999999999.99');
      v_comision := to_number(substr(lpad(round(reg.comision, v_redondeo),
                                          15,
                                          '0'),
                                     1,
                                     13) || '.' ||
                              substr(lpad(round(reg.comision, v_redondeo),
                                          15,
                                          '0'),
                                     14,
                                     2),
                              '9999999999999.99');

      if v_tip_producto = '01' then
        begin
          select distinct b.nro_cuenta, b.mto_transaccion
            into v_nro_cuenta, v_mto_cobrado
            from bw_pag_servicios b
           where b.nro_transaccion = to_number(reg.referencia)
             and b.red_pago = v_red_documenta
             and trunc(b.fec_insercion) = trunc(reg.fec_pago);

        exception
          when no_data_found then
            v_cod_respuesta := 8;
            v_msj_respuesta := 'No se encontro movimiento';
          WHEN OTHERS THEN
            v_cod_respuesta := 9;
            v_msj_respuesta := DBMS_UTILITY.format_error_backtrace || ' ' ||
                               DBMS_UTILITY.format_error_stack;
        end;
      elsif v_tip_producto = '02' then
        begin
          select distinct b.nro_cuenta, b.monto
            into v_nro_cuenta, v_mto_cobrado
            from gv_movimientos b
           where b.REFERENCIA = to_number(reg.referencia)
             and b.nro_documento = v_red_documenta
             and reversado = 'N'
             and b.nro_cuenta is not null
             and trunc(b.fec_insercion) = trunc(reg.fec_pago);
        exception
          when no_data_found then
            v_cod_respuesta := 10;
            v_msj_respuesta := 'No se encontro movimiento';
          WHEN OTHERS THEN
            v_cod_respuesta := 11;
            v_msj_respuesta := DBMS_UTILITY.format_error_backtrace || ' ' ||
                               DBMS_UTILITY.format_error_stack;
        end;
      end if;
      if round(nvl(v_mto_cobrado, 0), v_redondeo) <>
         round(v_monto, v_redondeo) then
        v_cod_respuesta := 12;
        v_msj_respuesta := 'Monto incorrecto';
      end if;

      if nvl(v_cod_respuesta, 0) = 0 then
        if v_tip_producto = '01' then
          PAP_PRE.PR_OBT_DAT_PRESTAMO(v_nro_cuenta, RP_PCPRE);

          v_cod_modulo    := RP_PCPRE.cod_modulo;
          v_cod_modalidad := RP_PCPRE.cod_modalidad;
          v_cod_oficina   := RP_PCPRE.Cod_Oficina;
          /*Si la moneda del prestamo es al del archivo*/
          if v_moneda <> RP_PCPRE.Cod_Moneda then
            v_cod_respuesta := 13;
            v_msj_respuesta := 'Moneda incorrecta';
          end if;
        elsif v_tip_producto = '02' then

          pag_ser.pr_obt_dat_tarjetas(v_nro_cuenta,
                                      v_nro_tarjeta,
                                      v_nro_documento,
                                      v_nom_embozar,
                                      v_des_modalidad,
                                      v_cod_moneda,
                                      v_sal_pag_minimo,
                                      v_mto_pag_minimo,
                                      v_sal_ult_extracto,
                                      v_deu_tot_actual,
                                      v_fec_ult_cierre,
                                      v_cod_modulo,
                                      v_cod_modalidad,
                                      v_cod_oficina,
                                      v_dia_mora,
                                      v_error,
                                      v_en_juicio,
                                      v_estado,
                                      v_cod_error,
                                      v_respuesta);
         if nvl(v_cod_error,0) != 0 then
            v_cod_respuesta := 22;
            v_msj_respuesta := 'Error al obtener datos de la tarjeta '||v_error;
        end if;
         /*Si la moneda del prestamo es al del archivo*/
          if v_moneda <> v_cod_moneda then
            v_cod_respuesta := 14;
            v_msj_respuesta := 'Moneda incorrecta';
          end if;

        end if;
        if nvl(v_cod_rubro, '0') = '0' then
          v_cod_respuesta := 15;
          v_msj_respuesta := 'Cod. ' || v_cod_respuesta || ' ' ||
                             'Rubro en la moneda ' || v_moneda ||
                             ' no definido';
          --raise_application_error(-20001, v_msj_respuesta);
        end if;
        if nvl(v_cta_liquidacion, '0') = '0' then
          v_cod_respuesta := 10;
          v_msj_respuesta := 'Cuenta bancaria ' ||
                             'para la liquidacion en la moneda ' ||
                             v_moneda || ' no definida';
          --raise_application_error(-20001, v_msj_respuesta);
        end if;
        IF v_cod_rubro is not null and v_cod_respuesta = 0 then
          if nvl(v_monto, 0) > 0 then
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
            r_gmovi.monto           := round(v_monto, v_redondeo);
            r_gmovi.nro_documento   := reg.nro_boleta;
            r_gmovi.referencia      := to_number(reg.referencia);
            r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
            r_gmovi.emi_aviso       := 'N';
            r_gmovi.concepto        := 'Cobro por- ' || v_red_pago || ' ' ||
                                       v_nro_cuenta;
            r_gmovi.estado          := 'N';
            r_gmovi.reversado       := 'N';
            --Entra el rubro contable
            r_gmovi.cod_rubro     := v_cod_rubro;
            r_gmovi.tip_mov_rubro := 'C';

            begin
              lp_ver_horario;
              pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_mov_noc);

            exception
              when others then
                v_cod_respuesta := 16;
                v_msj_respuesta := DBMS_UTILITY.format_error_backtrace || ' ' ||
                                   DBMS_UTILITY.format_error_stack;
            end;

            if v_cta_liquidacion is not null and
               nvl(v_cod_respuesta, 0) = 0 then
              pag_cta.PR_OBT_CUENTA(v_cta_liquidacion);
              /*Debito a la cuenta bancaria*/
              pag_cta.pr_act_operacion(v_cta_liquidacion,
                                       v_hor_cobro,
                                       'D', -- debito
                                       v_moneda,
                                       round(v_monto, v_redondeo),
                                       8530, --v_cod_tra_padre,
                                       503, -- trans. hijo de efectivo
                                       v_red_documenta,
                                       null, -- cotizacion
                                       v_cod_ofi_origen,
                                       pag_cta.g_ctas.cod_modulo,
                                       pag_cta.g_ctas.cod_modalidad,
                                       null, -- tasa
                                       null, -- valor de tasa
                                       'Debito cobranzas - ' || v_red_pago, --concepto
                                       'N', -- emitir aviso
                                       v_nro_secuencia, -- nro de secuencia
                                       v_fec_hoy);

              IF pag_cta.G_COD_ERROR <> 0 THEN
                v_cod_respuesta := 17;
                v_msj_respuesta := pag_cta.G_MSJ_ERROR;
              END IF;
              if nvl(v_comision, 0) > 0 then
                pag_cta.pr_act_operacion(v_cta_liquidacion,
                                         v_hor_cobro,
                                         'D', -- debito
                                         v_moneda,
                                         v_comision,
                                         8530, --padre
                                         8531, --
                                         v_red_documenta,
                                         null, -- cotizacion
                                         v_cod_ofi_origen,
                                         pag_cta.g_ctas.cod_modulo,
                                         pag_cta.g_ctas.cod_modalidad,
                                         null, -- tasa
                                         null, -- valor de tasa
                                         'Debito comision cobranzas - ' ||
                                         v_red_pago, --concepto
                                         'N', -- emitir aviso
                                         v_nro_secuencia, -- nro de secuencia
                                         v_fec_hoy);

                IF pag_cta.G_COD_ERROR <> 0 THEN
                  v_cod_respuesta := 19;
                  v_msj_respuesta := pag_cta.G_MSJ_ERROR;
                END IF;
              END IF;

            END IF;
            /*Si no hubo error acumula los montos*/
            if nvl(v_cod_respuesta, 0) = 0 then
              v_mto_total     := v_mto_total +
                                 round(nvl(v_monto, 0), v_redondeo);
              v_tot_comision  := v_tot_comision +
                                 round(nvl(v_comision, 0), v_redondeo);
              c_tot_procesado := c_tot_procesado + 1;

              /*Inserta en la tabla definitiva*/
              begin
                insert into it.ge_mov_cob_documenta
                  (terminal,
                   fec_proceso,
                   fec_pago,
                   hor_pago,
                   nro_boleta,
                   referencia,
                   nro_operacion,
                   nro_tarjeta,
                   nro_cuenta,
                   importe,
                   comision,
                   cod_producto,
                   moneda,
                   bco_emisor,
                   liquidado,
                   fec_liquidacion,
                   usu_liquidacion,
                   nro_cta_cliente,
                   id_proceso)
                values
                  (reg.terminal,
                   reg.fec_proceso,
                   reg.fec_pago,
                   reg.hor_pago,
                   reg.nro_boleta,
                   to_number(reg.referencia),
                   reg.nro_operacion,
                   reg.nro_tarjeta,
                   reg.nro_cuenta,
                   v_monto,
                   v_comision,
                   reg.cod_producto,
                   v_moneda,
                   reg.bco_emisor,
                   'S',
                   v_fec_proceso,
                   substr(user,1,10),
                   v_nro_cuenta,
                   v_id);
              exception
                when others then
                  v_cod_respuesta := 20;
                  v_msj_respuesta := 'Cod. ' || v_cod_respuesta || ' ' ||
                                     DBMS_UTILITY.format_error_backtrace || ' ' ||
                                     DBMS_UTILITY.format_error_stack;
              end;
            end if;

          else
            v_cod_respuesta := 21;
            v_msj_respuesta := 'Monto no puede ser menor cero';
          end if;

        end if;

      END IF;

      if nvl(v_cod_respuesta, 0) != 0 then
        v_rollback:='S';
        v_det_error := 'Fecha: ' || reg.fec_pago || ' Refrencia ' ||
                       to_number(reg.referencia) || ' Monto: ' ||
                       reg.importe || ' Comision: ' || reg.comision ||
                       ' Cuenta ' || reg.nro_cuenta || ' Tarjeta ' ||
                       reg.nro_tarjeta || ' Moneda: ' || reg.moneda || /*' Bco Emisor: '||reg.bco_emisor||*/
                       ' Operacion: ' || reg.nro_operacion ||
                       ' Cod Producto ' || reg.cod_producto || ' Error: ' ||
                       v_cod_respuesta || ' - ' || v_msj_respuesta;

        PRG_INS_LOG_PROGRAMAS('PRG_LIQ_OPE_DOC_COBRANZA',
                              substr(v_det_error, 1, 4000),
                              null,
                              null);
        --raise_application_error(-20001, 'Registro ' || v_det_error);
      end if;
      v_cod_respuesta:=0;
      v_msj_respuesta:=null;
      v_moneda:=null;
    end loop;

    /*Si termino correctamente actualiza resumen*/
    if nvl(v_cod_respuesta, 0) = 0 then

      begin
        update it.ge_liq_red_cobranzas
           set tot_reg_encontrado = c_tot_procesado,
               tot_monto         = v_mto_total,
               tot_comision      = v_tot_comision
         where id_proceso = v_id
           and bco_emisor = cta.bco_emisor
           and moneda = cta.cod_moneda
           and producto = v_producto
           and fec_proceso = v_fec_proceso
           and red_cobranza = v_red_pago;
      exception
        when others then
          v_cod_respuesta := 21;
          v_msj_respuesta := 'Error al actualizar cabera id ' || v_id;
      end;
      if nvl(v_cod_respuesta, 0) != 0 then
        v_det_error := 'Cta: ' || cta.cta_liquidacion || ' Moneda ' ||
                       cta.cod_moneda || ' Monto total ' || v_mto_total ||
                       ' Total comision ' || v_tot_comision ||
                       ' Tipo producto: ' || cta.nom_producto || ' Error: ' ||
                       v_cod_respuesta || ' - ' || v_msj_respuesta;

        PRG_INS_LOG_PROGRAMAS('PRG_LIQ_OPE_DOC_COBRANZA',
                              substr(v_det_error, 1, 4000),
                              null,
                              null);
        --raise_application_error(-20001, 'Registro ' || v_det_error);
      end if;
    end if;

  end loop;
  if nvl(v_rollback, 'N') = 'S' then
    rollback to liquidar;
  end if;
  /*Borra tabla temporal*/

   begin
    delete from it.ge_mov_cob_documenta_tmp;

  exception
    when others then
       v_msj_respuesta := 'No se pudo borrar temporal';
       raise_application_error(-20001, v_msj_respuesta);
  end;

  if nvl(v_reg_existe,'N') = 'N' then
    v_msj_respuesta := 'No se encontraron registros para procesar';
    raise_application_error(-20001, v_msj_respuesta);
  end if;

exception
  when others then
    v_det_error := DBMS_UTILITY.format_error_backtrace || ' ' ||
                   DBMS_UTILITY.format_error_stack;

    PRG_INS_LOG_PROGRAMAS('PRG_LIQ_OPE_DOC_COBRANZA',
                          substr(v_det_error, 1, 4000),
                          null,
                          null);
end prg_liq_ope_doc_cobranza;
/

