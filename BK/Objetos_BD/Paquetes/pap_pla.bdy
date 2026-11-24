CREATE OR REPLACE PACKAGE BODY IT.PAP_PLA is

  PROCEDURE pr_ver_horario(p_cod_ofi_origen ba_oficinas.cod_oficina%type,
                           p_horario        OUT VARCHAR2,
                           p_es_mov_noc     OUT VARCHAR2,
                           p_es_cta_noc     OUT VARCHAR2,
                           p_fec_actual     OUT DATE,
                           p_fec_valor      OUT DATE,
                           p_cod_error      OUT number,
                           p_men_error      OUT varchar2) is

    v_est_modulo ba_modulos.estado%TYPE;
  BEGIN
    p_cod_error  := v_pro_correcto;
    p_horario    := 'D'; -- Dia normal
    p_es_mov_noc := 'N'; -- Para grabar en las tablas nocturnas
    p_es_cta_noc := 'N';
    p_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(9);
    v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(9);

    IF v_est_modulo IN (6) THEN
      -- En cierre.
      p_cod_error := 1070;
      p_men_error := 'Proceso en cierre';
    ELSIF v_est_modulo = 2 THEN
      p_horario    := 'D'; -- Dia normal
      p_es_mov_noc := 'N'; -- Para grabar en las tablas nocturnas
      p_es_cta_noc := 'N';
      p_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(9);
    ELSE
      p_horario := 'N'; -- Noche
      IF v_est_modulo <> 1 THEN
        p_fec_actual := pag_cal.FU_OBT_FEC_HABIL(p_fec_actual + 1,
                                                 1,
                                                 p_cod_ofi_origen);
      END IF;
      p_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
      p_es_cta_noc := 'S'; -- Solo para que llavee la cuenta nocturna
    END IF;
    pag_cta.g_horario := p_horario;
    p_fec_valor       := trunc(sysdate);
  END pr_ver_horario;

  function fu_hora_disp(p_secuencia in varchar2) return varchar2 is
    v_hora    ge_movimientos.hora%type;
    v_nro_sec number;
    v_nro_hor number;
  BEGIN
    v_nro_sec := fue_obt_sig_secuencia(p_secuencia);

    if v_nro_sec <= 86400 then
      v_nro_hor := v_nro_sec;
    else
      v_nro_hor := mod(v_nro_sec, 86400);
    end if;

    v_hora := TO_CHAR(trunc(v_nro_hor / 3600), 'FM9900') || ':' ||
              TO_CHAR(TRUNC(MOD(v_nro_hor, 3600) / 60), 'FM00') || ':' ||
              TO_CHAR(MOD(v_nro_hor, 60), 'FM00');

    return v_hora;
  END fu_hora_disp;
  function fu_ver_movimientos(p_nro_cuenta in varchar2) return varchar2 is
    v_existe varchar2(3) := 'NO';
  BEGIN
    Select distinct('SI')
      into v_existe
      from ge_movimientos o
      where o.cod_tra_padre = '358' -- transaccion de desembolso
        and o.nro_cuenta    = p_nro_cuenta;

    return v_existe;
  exception
    when no_data_found then
      v_existe := 'NO';
      return v_existe;
    when others then
      v_existe := 'SI';
      return v_existe;
  END fu_ver_movimientos;

  /**
   Obtiene datos de la deuda para la plataforma
  **/
  procedure pr_obt_deu_pre_plataforma(p_nro_cuenta       in pr_cta_prestamos.nro_cuenta%type,
                                      p_cuo_desde        in pr_cuotas.nro_cuota%type,
                                      p_cuo_hasta        in pr_cuotas.nro_cuota%type,
                                      p_mto_capital      out pr_cuotas.mto_capital%type,
                                      p_mto_interes      out pr_cuotas.mto_interes%type,
                                      p_mto_int_ade      out pr_cuotas.mto_interes%type,
                                      p_mto_cargos       out pr_cuotas.sal_capital%type,
                                      p_mto_pagar        out pr_cuotas.sal_capital%type,
                                      p_dia_mora         out pr_cobros.dia_mora%type,
                                      p_mto_mora         out pr_cobros.mto_int_mor_interes%type,
                                      p_mto_mora_int     out pr_cobros.mto_int_mor_interes%type,
                                      p_mto_mora_int_ade out pr_cobros.mto_int_mor_interes%type,
                                      p_mto_punitor      out pr_cobros.mto_int_punitorio%type,
                                      p_mto_impuest      out pr_cobros.mto_impuesto%type,
                                      p_mto_cargo        out pr_cobros.mto_cargo%type,
                                      p_tot_car_iva      out pr_cobros.mto_cargo%type,
                                      p_mto_descont      out pr_cobros.mto_int_documentado%type,
                                      p_mto_iva_dev      out pr_cobros.mto_int_documentado%type,
                                      p_cod_error        out number,
                                      p_men_error        out varchar2) is

    v_nom_programa         varchar2(50) := 'PAP_PLA.PR_OBT_DEU_PRE_PLATAFORMA';
    v_nro_cuenta           pr_cta_prestamos.nro_cuenta%type;
    v_fec_actual           date;
    v_cuo_desde            pr_cuotas.nro_cuota%type;
    v_cuo_hasta            pr_cuotas.nro_cuota%type;
    v_oficina              ba_oficinas.cod_oficina%type;
    v_cod_error            number(6);
    v_men_error            varchar2(4000);
    v_mto_capital          pr_cobros.mto_capital%type;
    v_mto_interes          pr_cobros.mto_interes%type;
    v_tot_int_adelantado   pr_cuotas.mto_interes%type;
    v_tot_mora             pr_cta_prestamos.mto_capital%type;
    v_tot_mora_interes     pr_cobros.mto_int_moratorio%type;
    v_tot_mora_int_ade     pr_cobros.mto_int_mor_adelantado%type;
    v_tot_punitorio        pr_cobros.mto_int_punitorio%type;
    v_tot_impuesto         pr_cobros.mto_impuesto%type;
    v_tot_cargo            pr_cobros.mto_cargo%type;
    v_tot_cargo_iva        pr_cobros.mto_cargo_iva%type;
    v_tot_int_descontado   pr_cobros.mto_int_descontado%type;
    v_dia_mora             pr_cobros.dia_mora%type;
    v_lugar                varchar2(10) := '00';
    v_redondeo             NUMBER(1);
    v_cod_modulo           ba_modulos.cod_modulo%type;
    v_cod_modalidad        ge_modalidades.cod_modalidad%type;
    v_cod_moneda           ba_monedas.cod_moneda%type;
    v_fec_vigencia         date;
    val_tas_iva_descontado ge_movimientos.val_tasa%type;
    v_cod_tasa             ge_transacciones.cod_tasa%type;
    v_tip_valor            ge_tasas.tip_valor%type;
    v_tipo                 ge_tasas.tipo%type;
    v_nro_solicitud        pr_cta_prestamos.nro_solicitud%type;
    v_cob_iva              varchar2(1);
    v_tot_iva_descontado   pr_cobros.mto_int_descontado%type;

  begin
    /** Inicio del Programa **/

    v_lugar := '01';
    /** Inicializo las variables de retorno **/
    p_mto_capital := 0;
    p_mto_interes := 0;
    p_mto_cargos  := 0;
    p_mto_pagar   := 0;
    p_dia_mora    := 0;
    p_cod_error   := v_pro_correcto;
    p_men_error   := 'Consulta Exitosa!';

    v_lugar := '02';
    /** Asigno los valores de entrada **/
    v_nro_cuenta := p_nro_cuenta;
    v_cuo_desde  := nvl(p_cuo_desde, 0);
    v_cuo_hasta  := nvl(p_cuo_hasta, 999);

    /** obtengo los datos de la cuenta **/
    begin
      select a.cod_modulo, a.cod_modalidad, a.cod_moneda, p.nro_solicitud
        into v_cod_modulo, v_cod_modalidad, v_cod_moneda, v_nro_solicitud
        from ge_cuentas a, pr_cta_prestamos p
       where a.nro_cuenta = v_nro_cuenta
         and a.nro_cuenta = p.nro_cuenta;
    exception
      when others then
        v_cod_modulo    := null;
        v_cod_modalidad := null;
    end;

    /** obtengo el redondeo para la moneda **/
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                      v_cod_modulo,
                                      v_cod_modalidad,
                                      v_cod_moneda);

    v_lugar := '03';
    /** Obtiene la fecha y oficina **/
    v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(6);
    v_oficina    := fug_obt_ofi_cuenta(v_nro_cuenta);

    v_lugar := '04';
    /** Obtiene los datos del prestamo **/
    pap_pre.pr_obt_deu_prestamo(v_nro_cuenta,
                                v_fec_actual,
                                v_cuo_desde,
                                v_cuo_hasta,
                                v_oficina,
                                null,
                                v_cod_error,
                                v_men_error,
                                v_mto_capital,
                                v_mto_interes,
                                v_tot_int_adelantado,
                                v_tot_mora,
                                v_tot_mora_interes,
                                v_tot_mora_int_ade,
                                v_tot_punitorio,
                                v_tot_impuesto,
                                v_tot_cargo,
                                v_tot_cargo_iva,
                                v_tot_int_descontado,
                                v_dia_mora,
                                360);

    pag_gen.pr_obt_val_tasa(v_cod_modulo,
                            v_cod_modalidad,
                            v_oficina,
                            v_nro_cuenta,
                            v_cod_moneda,
                            v_tot_int_descontado,
                            'N',
                            v_cod_tasa,
                            1708,
                            v_fec_actual,
                            val_tas_iva_descontado,
                            v_fec_vigencia,
                            v_tip_valor,
                            v_tipo);

    IF fug_obt_pardinamico('PRE_IVA_INT_DESCONTADO') = 'S' THEN
      -- Verificar si se cobro iva en la solicitud
      begin
        select 'S'
          into v_cob_iva
          from pr_sol_cargos
         where nro_solicitud = v_nro_solicitud
           and cod_transaccion = 709;
      exception
        when others then
          v_cob_iva := 'N';
      end;

      if v_cob_iva = 'S' then
        v_tot_iva_descontado := round(nvl(v_tot_int_descontado, 0) *
                                      (val_tas_iva_descontado / 100),
                                      v_redondeo);
      else
        v_tot_iva_descontado := 0;
      end if;
    else
      v_tot_iva_descontado := 0;
    end if;

    /** Valida si no tuvo error **/
    if v_cod_error != v_pro_correcto then
      v_lugar     := '05';
      p_cod_error := v_cod_error;
      p_men_error := v_men_error;
      prg_ins_log_programas(v_nom_programa,
                            substr('1) Lugar: ' || v_lugar || ' - ' ||
                                   p_cod_error || ' - ' || p_men_error,
                                   1,
                                   4000),
                            null,
                            p_nro_cuenta);
    else
      v_lugar            := '06';
      p_mto_capital      := v_mto_capital;
      p_mto_interes      := v_mto_interes;
      p_mto_int_ade      := v_tot_int_adelantado;
      p_mto_cargos       := round((nvl(p_mto_interes, 0) * 10 / 100) +
                                  v_tot_cargo,
                                  v_redondeo);
      p_mto_pagar        := nvl(v_mto_capital, 0) + nvl(v_mto_interes, 0) +
                            nvl(v_tot_int_adelantado, 0) +
                            nvl(v_tot_mora, 0) + nvl(v_tot_mora_interes, 0) +
                            nvl(v_tot_mora_int_ade, 0) +
                            nvl(v_tot_punitorio, 0) +
                            nvl(v_tot_impuesto, 0) + nvl(v_tot_cargo, 0);
      p_dia_mora         := nvl(v_dia_mora, 0);
      p_mto_mora         := nvl(v_tot_mora, 0);
      p_mto_mora_int     := v_tot_mora_interes;
      p_mto_mora_int_ade := v_tot_mora_int_ade;
      p_mto_punitor      := v_tot_punitorio;
      p_mto_impuest      := v_tot_impuesto;
      p_mto_cargo        := v_tot_cargo;
      p_tot_car_iva      := v_tot_cargo + v_tot_cargo_iva;
      p_mto_descont      := v_tot_int_descontado;
      p_mto_iva_dev      := v_tot_iva_descontado;
    end if;

  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := sqlerrm;
      prg_ins_log_programas(v_nom_programa,
                            substr('2) Lugar: ' || v_lugar || ' - ' ||
                                   'Error: ' || p_men_error,
                                   1,
                                   4000),
                            null,
                            p_nro_cuenta);
  end;

  /**
   Programa que realiza el cobro de cuotas del prestamo
  **/
  procedure pr_cob_pre_plataforma(p_nro_cuenta       in pr_cta_prestamos.nro_cuenta%type,
                                  p_nro_cta_debito   in pr_cta_prestamos.nro_cta_debito%type,
                                  p_mto_cobrado      in pr_cobros.mto_capital%type,
                                  p_cuo_desde        in pr_cuotas.nro_cuota%type,
                                  p_cuo_hasta        in pr_cuotas.nro_cuota%type,
                                  p_concepto         in pr_cta_prestamos.descripcion%type,
                                  p_cod_error        out number,
                                  p_men_error        out varchar2,
                                  p_pag_parcial      in varchar2,
                                  p_pago_funcionario in varchar2 default 'N',
                                  p_cod_canal        in varchar2 default 'N',
                                  p_for_pago         in varchar2 default null,
                                  p_modo             in varchar2 default 'C') is

    v_nom_programa  varchar2(50) := 'PAP_PLA.PR_COB_PRE_PLATAFORMA';
    v_fecha         ge_calendarios.fec_actual%type;
    v_hora          ge_movimientos.hora%type;
    v_cod_modulo    ba_modulos.cod_modulo%type;
    v_cod_tra_padre ge_transacciones.cod_transaccion%type;
    v_cod_mon_local ba_monedas.cod_moneda%type;
    v_nro_secuencia ge_movimientos.nro_secuencia%type;
    r_gmovi         ge_movimientos%rowtype;
    v_pri_dia_mes   ge_calendarios.pri_dia_mes%type;
    v_ult_dia_mes   ge_calendarios.ult_dia_mes%type;
    -- Datos para recuperar deuda del prestamo
    v_pag_parcial    varchar2(01);
    v_sal_cobrado    pr_cuotas.sal_capital%type;
    v_sal_capital    pr_cuotas.sal_capital%type;
    v_sal_interes    pr_cuotas.sal_interes%type;
    v_sal_int_ade    pr_cuotas.sal_int_documentado%type;
    v_mora           pr_cuotas.sal_interes%type;
    v_mora_interes   pr_cuotas.sal_interes%type;
    v_mora_int_ade   pr_cuotas.sal_interes%type;
    v_impuesto       pr_cuotas.sal_interes%type;
    v_cargo          pr_cuotas.sal_interes%type;
    v_cargo_iva      pr_cuotas.sal_interes%type;
    v_punitorio      pr_cuotas.sal_interes%type;
    v_int_descontado pr_cuotas.sal_interes%type;
    v_mto_deuda      pr_cuotas.sal_capital%type;
    v_dias_mora      number(05);
    v_cuo_desde      pr_cuotas.nro_cuota%type;
    v_cuo_hasta      pr_cuotas.nro_cuota%type;
    -- Datos para utilizar la cuenta de debito
    v_mto_deu_deb        ge_cuentas.sal_contable%type;
    v_cot_mon_pre        ge_cotizaciones.val_conversion%type;
    v_cot_mon_deb        ge_cotizaciones.val_conversion%type;
    v_nvo_estado         ge_cuentas.estado%type;
    v_sal_disponible     ge_cuentas.sal_contable%type;
    v_procesa            varchar2(01);
    v_error              varchar2(10);
    v_mensaje            varchar2(1000);
    v_imp_cuenta         pr_cuotas.sal_interes%type;
    v_lin_sobregiro      number(18, 2);
    v_deb_aut_incobrable varchar2(1) := fug_obt_pardinamico('PRE_DEB_AUT_INCOBRABLE');
    v_cod_persona        ba_personas.cod_persona%type;
    v_nro_caja           ge_movimientos.nro_caja%type;
    v_cod_oficina        ge_movimientos.cod_oficina%type;
    v_cdusuar            ge_movimientos.cod_usuario%type;
    v_cancela            varchar2(01) := 'N';
    v_horario            varchar2(1);
    v_es_mov_noc         varchar2(1) := 'N';
    v_es_cta_noc         varchar2(1);
    v_fec_valor          ge_calendarios.fec_actual%type;
    c                    number := 0;
    datpre               pr_cta_prestamos%ROWTYPE;
    v_cod_usuario        ba_usuarios.cod_usuario%TYPE := USER;
    
    -- Cursor de prestamos
    cursor c_debitos is
      select pr.nro_cuenta,
             pr.cod_oficina,
             cu.nro_cuota,
             cu.estado,
             pr.cod_moneda,
             pr.cod_modulo,
             pr.cod_modalidad,
             cu.nro_documento,
             x.cuo_hasta,
             cu.fec_vencimiento,
             cu.estado est_cuota
        from ge_cta_clientes cl,
             pr_cta_prestamos pr,
             pr_cuotas cu,
             (select nro_cuenta cuenta, max(nro_cuota) cuo_hasta
                from pr_cuotas
               where estado <> 'N'
                 and nvl(sal_capital, 0) + nvl(sal_interes, 0) +
                     nvl(sal_int_documentado, 0) > 0
               group by nro_cuenta) x
       where pr.nro_cuenta = cu.nro_cuenta
         and pr.nro_cuenta = cl.nro_cuenta
         and pr.cod_modalidad not in (627, 608, 62) --- no incluir asociaciones ni descuentos documentos
         and cl.relacion = 'P' --- Cliente principal
         and pr.estado <> 'N' --- Prestamos no cancelados
         and x.cuenta = cu.nro_cuenta
         and cu.nro_cuota =
             (select min(nro_cuota)
                from pr_cuotas
               where nro_cuenta = pr.nro_cuenta
                 and (nvl(sal_capital, 0) <> 0 or nvl(sal_interes, 0) <> 0) -- Cuotas con saldo
                 and nro_cuota > 0)
         and cu.estado <> 'N' --- Cuotas no canceladas
         and ((v_deb_aut_incobrable = 'S') OR
             (v_deb_aut_incobrable = 'N' AND exists
              (select 1
                  from pr_cuotas c
                 where c.nro_cuenta = cu.nro_cuenta
                   and c.estado not in ('I', 'N'))))
         and pr.nro_cuenta = p_nro_cuenta
         and (v_cod_persona is null or cl.cod_persona = v_cod_persona)
            --si no proviene de gppagsue cobra a todos los resgistros de cuotas atrasadas y vencidas en el dia
         and ((P_PAGO_FUNCIONARIO = 'N') or
             (P_PAGO_FUNCIONARIO = 'S' and exists
              (select 1
                  from ge_clientes e
                 where e.cod_persona = cl.cod_persona
                   and e.cod_seg_cliente = 1)))
       order by pr.nro_cuenta, cu.fec_vencimiento, cu.nro_cuota;

    /* Inserta movimiento con error. */
    PROCEDURE LP_INS_MOV_ERROR IS
    BEGIN
      v_nro_secuencia := v_nro_secuencia + 1;
      --- Cargar registro de movimientos
      r_gmovi.fecha         := v_fecha;
      r_gmovi.fec_valor     := v_fec_valor;
      r_gmovi.cod_usuario   := user;
      r_gmovi.hora          := v_hora;
      r_gmovi.nro_secuencia := v_nro_secuencia;
      r_gmovi.cod_tra_padre := v_cod_tra_padre;
      r_gmovi.reversado     := 'N';
      r_gmovi.emi_aviso     := 'N';
      r_gmovi.protegido     := 'N';
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
    END;
   
  begin
    -- Recuperar datos de fecha calendario
    p_cod_error  := v_pro_correcto;
    p_men_error  := 'Operacion Exitosa!';
    v_cod_modulo := 6;
    v_fecha      := pag_cal.FU_OBT_FEC_ACTUAL(v_cod_modulo);
    
    --------------------------------------------------------
 
    v_hora          := fu_hora_disp('S_NRO_HORA_PREST'); --Seteo de v_hora      


    v_nro_secuencia := 0;
    v_cod_tra_padre := 360;
    v_cod_mon_local := pag_gen.fu_obt_mon_local;
    v_pri_dia_mes   := to_date('01' || to_char(v_fecha, 'MMYYYY'),
                               'DDMMYYYY');
    v_ult_dia_mes   := last_day(v_fecha);
    v_cuo_desde     := p_cuo_desde;
    v_cuo_hasta     := p_cuo_hasta;

    if p_cod_canal in ('W', 'M') then
      PRW_OBT_DAT_CAJA(p_cod_canal,
                       v_nro_caja,
                       v_cod_oficina,
                       v_cdusuar,
                       P_COD_ERROR,
                       P_MEN_ERROR);
    else
      v_cdusuar := substr(v_cod_usuario, 1, 10);
    end if;
    pap_pre.PR_OBT_DAT_PRESTAMO(p_nro_cuenta, datpre);
    if datpre.estado = 'N' and nvl(datpre.sal_capital, 0) = 0 and
       nvl(datpre.sal_interes, 0) = 0 then
      p_cod_error := v_err_sql;
      p_men_error := 'El prestamo ' || p_nro_cuenta ||
                     ' ya se encuentra cancelado';
    end if;   
    if nvl(p_cod_error, 0) = 0 AND datpre.cod_modalidad in (627, 608, 62) then
      p_cod_error := 10;
      p_men_error := 'Cobro de prestamo ' || p_nro_cuenta ||
                     ' con modalidad '|| datpre.cod_modalidad||
                     ' sólo por Caja.';
      prg_ins_log_programas(v_nom_programa,
                            substr('1-Error: ' || p_cod_error ||
                                   ' - ' || p_men_error,
                                   1,
                                   4000),
                            v_cod_persona,
                            p_nro_cuenta);               
    end if;   
    if nvl(p_cod_error, 0) = 0 then
      for pre in c_debitos loop
        -- Inicializar variables auxiliares
        r_gmovi          := null;
        v_sal_cobrado    := null;
        c                := c + 1;
        v_error          := null;
        v_mensaje        := null;
        v_sal_capital    := null;
        v_sal_interes    := null;
        v_sal_int_ade    := null;
        v_mora           := null;
        v_mora_interes   := null;
        v_mora_int_ade   := null;
        v_punitorio      := null;
        v_impuesto       := null;
        v_cargo          := null;
        v_cargo_iva      := null;
        v_int_descontado := null;
        v_cod_persona    := null;
        --cotizacion
        v_cot_mon_pre := null;
        v_cot_mon_deb := null;

        --obtiene la persona de la cuenta
        begin
          select a.cod_persona
            into v_cod_persona
            from ge_cta_clientes a
           where a.nro_cuenta = p_nro_cuenta;
        exception
          when others then
            v_cod_persona := null;
        end;

        -- Inicializar registro de movimiento por si da error
        r_gmovi.cod_ofi_origen := fug_obt_ofi_usuario(v_cod_usuario); --pre.cod_oficina;
        r_gmovi.cod_mod_padre  := pre.cod_modulo;
        r_gmovi.cod_mad_padre  := pre.cod_modalidad;
        r_gmovi.nro_documento  := pre.nro_documento;
        r_gmovi.concepto       := 'Prest.' || pre.nro_cuenta;

        if v_cuo_desde > pre.nro_cuota then
          v_cuo_desde := pre.nro_cuota;
        end if;

        if v_cuo_hasta > pre.cuo_hasta then
          v_cuo_hasta := pre.cuo_hasta;
        end if;

        PR_VER_HORARIO(pre.cod_oficina,
                       v_horario,
                       v_es_mov_noc,
                       v_es_cta_noc,
                       v_fecha,
                       v_fec_valor,
                       p_cod_error,
                       p_men_error);

        if fug_obt_pardinamico('ACT_NOCTURNO') = 'N' and v_es_mov_noc = 'S' then
          p_cod_error := '1070';
          p_men_error := 'Modulo en proceso de cierre';
        else

    --DA-6619
    --en caso que el desembolso se haya hecho en el d?a propio pueda obtener la hora distinta
    --al secuenciador de horas.

    if fu_ver_movimientos(p_nro_cuenta) = 'SI' then
         v_hora          := to_char(sysdate, 'hh24:mi:ss');    -- se pone el sysdate para setear fu_hora_disp('S_NRO_HORA_PREST')
          v_hora          := fug_obt_hor_disponible(v_fecha,
                                              v_hora,
                                              v_cod_usuario,
                                              v_es_mov_noc);
    end if;
          -- Recuperar deuda de la cuota

          pap_pre.pr_obt_deu_prestamo(pre.nro_cuenta,
                                      v_fecha,
                                      v_cuo_desde,
                                      v_cuo_hasta,
                                      pre.cod_oficina,
                                      v_sal_cobrado,
                                      v_error,
                                      v_mensaje,
                                      v_sal_capital,
                                      v_sal_interes,
                                      v_sal_int_ade,
                                      v_mora,
                                      v_mora_interes,
                                      v_mora_int_ade,
                                      v_punitorio,
                                      v_impuesto,
                                      v_cargo,
                                      v_cargo_iva,
                                      v_int_descontado,
                                      v_dias_mora,
                                      v_cod_tra_padre,
                                      v_cancela); --para realizar o no una cancelacion parcial
          if v_error <> 0 then
            p_cod_error := v_error;
            p_men_error := v_mensaje;
            prg_ins_log_programas(v_nom_programa,
                                  substr('1-Error: ' || p_cod_error ||
                                         ' - ' || p_men_error,
                                         1,
                                         4000),
                                  v_cod_persona,
                                  p_nro_cuenta);
          end if;
          v_mto_deuda := nvl(v_sal_capital, 0) + nvl(v_sal_interes, 0) +
                         nvl(v_sal_int_ade, 0) + nvl(v_mora, 0) +
                         nvl(v_mora_interes, 0) + nvl(v_mora_int_ade, 0) +
                         nvl(v_punitorio, 0) + nvl(v_impuesto, 0) +
                         nvl(v_cargo, 0);

          if p_mto_cobrado < v_mto_deuda then
            v_mto_deuda := p_mto_cobrado;
          end if;
          if nvl(v_mto_deuda, 0) = 0 then
            p_cod_error := v_err_sql;
            p_men_error := ' En el rango de cuotas desde: ' || v_cuo_desde ||
                           ' hasta ' || v_cuo_hasta || ' no tiene deuda';
            exit;
          end if;

          if nvl(v_es_mov_noc, 'N') = 'N' then
            v_nro_secuencia := v_nro_secuencia + 1;
            v_hora          := fug_obt_hor_disponible(v_fecha,
                                                      v_hora,
                                                      v_cod_usuario,
                                                      v_es_mov_noc);
            pag_cta.PR_SET_VARIABLES(v_cod_usuario,
                                     v_fec_valor,
                                     null,
                                     'N',
                                     'N',
                                     v_nro_secuencia,
                                     null,
                                     pre.cod_oficina,
                                     pre.cod_modulo,
                                     pre.cod_modalidad);
            pap_pre.pr_cob_prestamo(pre.nro_cuenta,
                                    v_mto_deuda,
                                    'N',
                                    pre.cod_oficina,
                                    v_cuo_desde,
                                    v_cuo_hasta,
                                    'COB. C/CTA ' || p_nro_cta_debito,
                                    v_fecha,
                                    -- in/out
                                    v_hora,
                                    v_nro_secuencia,
                                    v_cod_tra_padre,
                                    pre.cod_modulo,
                                    pre.cod_modalidad,
                                    null,
                                    null,
                                    null,
                                    'N',
                                    null,
                                    v_cod_usuario);
          else
            -- insert into pr_cobros_noc para procesar en el inicio de dia.
            insert into pr_cobros_noc
              (nro_cuenta,
               nro_cuota_desde,
               nro_cuota_hasta,
               fecha,
               hora,
               estado,
               mto_cobrado,
               cod_ofi_origen,
               cod_mod_padre,
               cod_mad_padre,
               cod_tra_padre,
               nro_secuencia)
            values
              (pre.nro_cuenta,
               v_cuo_desde,
               v_cuo_hasta,
               v_fecha,
               v_hora,
               'I',
               v_mto_deuda,
               r_gmovi.cod_ofi_origen,
               9,
               91,
               v_cod_tra_padre,
               v_nro_secuencia);

          end if;
          -- Recuperar datos de la cuenta de ahorro
          pag_cta.pr_obt_cuenta(p_nro_cta_debito);
          r_gmovi.cod_modulo      := pag_cta.g_ctas.cod_modulo;
          r_gmovi.cod_modalidad   := pag_cta.g_ctas.cod_modalidad;
          r_gmovi.nro_cuenta      := p_nro_cta_debito;
          r_gmovi.cod_moneda      := pag_cta.g_ctas.cod_moneda;
          r_gmovi.cod_usuario     := v_cod_usuario;
          r_gmovi.cod_transaccion := 503;
          if pag_cta.g_cod_error <> 0 then
            p_cod_error := v_error;
            p_men_error := v_mensaje;
            prg_ins_log_programas(v_nom_programa,
                                  substr('2-Error: ' || p_cod_error ||
                                         ' - ' || p_men_error,
                                         1,
                                         4000),
                                  v_cod_persona,
                                  p_nro_cuenta);
          end if;

          -- Verificar monedas --
          if pag_cta.g_ctas.cod_moneda <> pre.cod_moneda and -- Cta. Debito Vs Prestamo
             pag_cta.g_ctas.cod_moneda <> v_cod_mon_local and -- Cta. Debito Vs Local
             pre.cod_moneda <> v_cod_mon_local then
            -- Prestamo Vs Local
            p_cod_error := v_err_sql;
            p_men_error := 'Tipos de moneda no coinciden';
            prg_ins_log_programas(v_nom_programa,
                                  substr('3-Error: ' || p_cod_error ||
                                         ' - ' || p_men_error,
                                         1,
                                         4000),
                                  v_cod_persona,
                                  p_nro_cuenta);
          end if;
          -- Calculo el total a debitar en la moneda de la cuenta de debito
          pag_gen.pr_con_mon_a_moneda(pre.cod_moneda,
                                      pag_cta.g_ctas.cod_moneda,
                                      v_mto_deuda,
                                      v_mto_deu_deb,
                                      v_cot_mon_pre,
                                      v_cot_mon_deb);
          -- Verificar parametro de pago para identificar el monto de la deuda
          if p_pag_parcial is null then
            v_pag_parcial := nvl(fug_obt_pardinamico('PAG_COB_AUT',
                                                     pre.cod_modulo,
                                                     pre.cod_modalidad,
                                                     pre.cod_moneda,
                                                     pre.cod_oficina),
                                 'N');
          else
            v_pag_parcial := p_pag_parcial;
          end if;

          -- se tiene en cuenta la linea de sobregiro
          v_lin_sobregiro := 0;
          if pag_cta.g_ctas.cod_modalidad = 41 then
            v_lin_sobregiro := nvl(pag_cta.FU_OBT_LIN_SOBREGIRO(p_nro_cta_debito,
                                                                v_fecha),
                                   0);
          end if;

          if (v_pag_parcial = 'N' and
             nvl(pag_cta.g_ctas.sal_disponible, 0) + v_lin_sobregiro <
             nvl(v_mto_deu_deb, 0)) or
             (v_pag_parcial = 'S' and
             (nvl(pag_cta.g_ctas.sal_disponible, 0) + v_lin_sobregiro <= 0 or
             nvl(pag_cta.g_ctas.sal_disponible, 0) + v_lin_sobregiro <
             fug_obt_pardinamico('MIN_COB_AUT',
                                   pre.cod_modulo,
                                   pre.cod_modalidad,
                                   pre.cod_moneda,
                                   pre.cod_oficina))) then
            p_cod_error := v_err_sql;
            p_men_error := 'Saldo no cubre la deuda';
            prg_ins_log_programas(v_nom_programa,
                                  substr('4-Error: ' || p_cod_error ||
                                         ' - ' || p_men_error,
                                         1,
                                         4000),
                                  v_cod_persona,
                                  p_nro_cuenta);
          end if;

          --calcula impuesto si corresponde y genera movimiento, en moneda de cta debito
          begin
            prg_ver_cob_cargos(p_nro_cta_debito,
                               pre.nro_cuenta,
                               pre.cod_modulo,
                               pre.cod_modalidad,
                               pre.cod_oficina, --oficina del prestamo, oficina origen
                               pag_cta.g_ctas.cod_moneda,
                               v_mto_deu_deb,
                               'Cobro Prestamo ' || pre.nro_cuenta,
                               null, --v_nro_documento,
                               v_fecha,
                               v_hora,
                               v_imp_cuenta,
                               v_nro_secuencia,
                               'N'); -- no procesa
          exception
            when others then
              v_imp_cuenta := 0; --para que no caiga
          end;

          if v_pag_parcial = 'S' and
             (nvl(pag_cta.g_ctas.sal_disponible, 0) + v_lin_sobregiro) <
             nvl(v_mto_deu_deb, 0) + nvl(v_imp_cuenta, 0) then
            v_imp_cuenta := (nvl(pag_cta.g_ctas.sal_disponible, 0) +
                            v_lin_sobregiro) / nvl(v_mto_deu_deb, 0) *
                            nvl(v_imp_cuenta, 0);
            if pre.cod_moneda = pag_gen.FU_OBT_MON_LOCAL then
              v_imp_cuenta := ceil(v_imp_cuenta);
            end if;
            v_mto_deu_deb := (nvl(pag_cta.g_ctas.sal_disponible, 0) +
                             v_lin_sobregiro) - nvl(v_imp_cuenta, 0);
          else
            v_mto_deu_deb := nvl(v_mto_deu_deb, 0);
          end if;
          -- Verificar si puede realizarse la operacion sobre la cuenta de debito
          pag_cta.pr_ver_operacion(p_nro_cta_debito,
                                   v_cod_tra_padre,
                                   r_gmovi.cod_mod_padre,
                                   r_gmovi.cod_mad_padre,
                                   'D',
                                   pag_cta.g_ctas.cod_moneda,
                                   nvl(v_mto_deu_deb, 0) +
                                   nvl(v_imp_cuenta, 0),
                                   pre.cod_oficina,
                                   -- out
                                   pag_cta.g_ctas.cod_modulo,
                                   pag_cta.g_ctas.cod_modalidad,
                                   v_nvo_estado,
                                   v_sal_disponible,
                                   v_procesa,
                                   503);
          if pag_cta.g_cod_error <> 0 or v_procesa = 'N' then
            p_cod_error := v_err_sql;
            p_men_error := pag_cta.g_msj_error;
            prg_ins_log_programas(v_nom_programa,
                                  substr('5-Error: ' || p_cod_error ||
                                         ' - ' || p_men_error,
                                         1,
                                         4000),
                                  v_cod_persona,
                                  p_nro_cuenta);
          end if;
          if nvl(p_cod_error, 0) = 0 then
            -- COBRAR prestamos
            -- Convertir monto de la deuda a la del prestamo por si vario segun saldo disponible de la cuenta

            /*pag_gen.pr_con_mon_a_moneda(pag_cta.g_ctas.cod_moneda,
                                        pre.cod_moneda,
                                        nvl(v_mto_deu_deb, 0),
                                        v_mto_deuda,
                                        v_cot_mon_deb,
                                        v_cot_mon_pre);
            v_nro_secuencia := v_nro_secuencia + 1;*/

            /* pag_cta.PR_SET_VARIABLES(user,
            v_fec_valor,
            null,
            'N',
            'N',
            v_nro_secuencia,
            null,
            pre.cod_oficina,
            pre.cod_modulo,
            pre.cod_modalidad);*/

            /*  pap_pre.pr_cob_prestamo(pre.nro_cuenta,
            v_mto_deuda,
            'N',
            pre.cod_oficina,
            v_cuo_desde,
            v_cuo_hasta,
            'COB. C/CTA ' || p_nro_cta_debito,
            v_fecha,
            -- in/out
            v_hora,
            v_nro_secuencia,
            v_cod_tra_padre,
            pre.cod_modulo,
            pre.cod_modalidad);*/

            prg_gen_comprobantes('PC',
                                 v_fecha,
                                 v_hora,
                                 v_nro_secuencia,
                                 v_cod_usuario,
                                 'COB. C/CTA ' || p_nro_cta_debito,
                                 null,
                                 pre.cod_moneda,
                                 v_mto_deuda,
                                 v_cod_persona,
                                 p_nro_cta_debito,
                                 null,
                                 null,
                                 null,
                                 null,
                                 null,
                                 null,
                                 null,
                                 null,
                                 null,
                                 null,
                                 p_nro_cuenta,
                                 v_cuo_hasta,
                                 null,
                                 null,
                                 null,
                                 v_cdusuar,
                                 'Pago cuota/s desde ' || v_cuo_desde ||
                                 ' hasta ' || v_cuo_hasta,
                                 p_for_pago, --cuota o monto
                                 null,
                                 null,
                                 null,
                                 null);

            -- se vuelve a obtener los datos de la cuenta de debito, porque pudo haber cambiado en el pap_pre (x garantias cash)
            pag_cta.pr_obt_cuenta(p_nro_cta_debito);

            --calcula impuesto si corresponde y genera movimiento, en moneda de cta debito
            begin
              prg_ver_cob_cargos(p_nro_cta_debito,
                                 pre.nro_cuenta,
                                 pre.cod_modulo,
                                 pre.cod_modalidad,
                                 pre.cod_oficina, --oficina del prestamo, oficina origen
                                 pag_cta.g_ctas.cod_moneda,
                                 v_mto_deu_deb,
                                 'Cobro Prestamo ' || pre.nro_cuenta,
                                 null, --v_nro_documento,
                                 v_fecha,
                                 v_hora,
                                 v_imp_cuenta,
                                 v_nro_secuencia,
                                 'S');
            exception
              when others then
                v_imp_cuenta := 0; --para que no caiga
            end;
            -- DEBITAR de la cuenta
            v_nro_secuencia := v_nro_secuencia + 1;
            pag_cta.pr_act_operacion(p_nro_cta_debito,
                                     v_hora,
                                     'D',
                                     pag_cta.g_ctas.cod_moneda,
                                     nvl(v_mto_deu_deb, 0) +
                                     nvl(v_imp_cuenta, 0),
                                     v_cod_tra_padre,
                                     503,
                                     pre.nro_documento,
                                     null,
                                     pre.cod_oficina,
                                     pre.cod_modulo,
                                     pre.cod_modalidad,
                                     null,
                                     null,
                                     'COBRO PRESTAMO ' || pre.nro_cuenta,
                                     'S',
                                     v_nro_secuencia,
                                     v_fec_valor);
            if pag_cta.g_cod_error <> 0 or v_procesa = 'N' then
              p_cod_error := v_err_sql;
              p_men_error := pag_cta.g_msj_error;
              prg_ins_log_programas(v_nom_programa,
                                    substr('5-Error: ' || p_cod_error ||
                                           ' - ' || p_men_error,
                                           1,
                                           4000),
                                    v_cod_persona,
                                    p_nro_cuenta);
              exit;
            end if;
          else
            exit;
          end if;
        end if;
      end loop;

      if nvl(c, 0) = 0 and nvl(p_cod_error, 0) = 0 then
        p_cod_error := v_err_sql;
        p_men_error := 'No se proceso ningun registro';
      end if;
    end if;
  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := substr(sqlerrm, 1, 4000);
      prg_ins_log_programas(v_nom_programa,
                            substr('6-Error en iniciar cobro: ' ||
                                   p_cod_error || ' - ' || p_men_error,
                                   1,
                                   4000),
                            v_cod_persona,
                            p_nro_cuenta);
  end;

  /** Actualiza el nro de cuenta para debito automatico **/
  procedure pr_act_cta_deb_plataforma(p_nro_cuenta     in pr_cta_prestamos.nro_cuenta%type,
                                      p_nro_cta_debito in pr_cta_prestamos.nro_cta_debito%type,
                                      p_cod_error      out number,
                                      p_men_error      out varchar2) is
    v_nom_programa varchar2(50) := 'PAP_PLA.PR_ACT_CTA_DEB_PLATAFORMA';
    v_error        varchar2(10);
    v_mensaje      varchar2(1000);
    v_es_principal varchar2(1);
  begin

    v_error        := v_pro_correcto;
    v_mensaje      := 'Operacion Exitosa!';
    v_es_principal := 'N';
    -- se valida que la cuenta debito corresponde al mismo cliente
    if fug_obt_cli_principal(p_nro_cuenta) =
       fug_obt_cli_principal(p_nro_cta_debito) then
      v_es_principal := 'S';
    end if;

    -- Se actualiza el nro de cuenta para deb. automatico
    update pr_cta_prestamos a
       set a.nro_cta_debito = p_nro_cta_debito, a.cob_automatico = 'S'
     where a.nro_cuenta = p_nro_cuenta
       and v_es_principal = 'S';

    if sql%notfound then
      v_error   := v_err_sql;
      v_mensaje := substr(sqlerrm, 1, 4000);
      prg_ins_log_programas(v_nom_programa,
                            substr('1-Error: ' || v_error || ' - ' ||
                                   v_mensaje,
                                   1,
                                   4000),
                            fug_obt_cli_principal(p_nro_cuenta),
                            p_nro_cuenta);
    end if;

    p_cod_error := v_error;
    p_men_error := v_mensaje;

  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := substr(sqlerrm, 1, 4000);
      prg_ins_log_programas(v_nom_programa,
                            substr('2-Error: ' || p_cod_error || ' - ' ||
                                   p_men_error,
                                   1,
                                   4000),
                            fug_obt_cli_principal(p_nro_cuenta),
                            p_nro_cuenta);
  end;

  /** Cancelacion de Prestamo de plataforma **/
  procedure pr_can_pre_plataforma(p_nro_cuenta     in pr_cta_prestamos.nro_cuenta%type,
                                  p_nro_cta_debito in pr_cta_prestamos.nro_cta_debito%type,
                                  p_cod_canal      in varchar2 default 'N',
                                  p_cod_error      out number,
                                  p_men_error      out varchar2) is

    v_nom_programa         varchar2(50) := 'PAP_PLA.PR_CAN_PRE_PLATAFORMA';
    v_error                varchar2(10);
    v_tot_iva_descontado   pr_cobros.mto_int_descontado%type;
    v_tip_valor            ge_tasas.tip_valor%type;
    v_tipo                 ge_tasas.tipo%type;
    v_mensaje              varchar2(1000);
    v_cod_persona          ba_personas.cod_persona%type;
    v_fecha                date;
    v_redondeo             NUMBER(1);
    v_cob_iva              varchar2(1);
    v_tip_cancelacion      varchar2(1) := 'T';
    r_pcpre                pr_cta_prestamos%rowtype;
    v_fec_vigencia         date;
    v_tot_seg_descontado   pr_cobros.mto_int_descontado%type;
    v_mto_capital          pr_cobros.mto_capital%TYPE;
    v_mto_interes          pr_cobros.mto_capital%TYPE;
    v_sal_int_ade          pr_cobros.sal_interes_pre%TYPE;
    v_tot_mora             pr_cobros.mto_cargo%TYPE;
    v_tot_mor_interes      pr_cobros.mto_capital%TYPE;
    v_tot_mor_int_ade      pr_cobros.mto_capital%TYPE;
    v_tot_punitorio        pr_cobros.mto_capital%TYPE;
    v_tot_impuesto         pr_cobros.mto_capital%TYPE;
    v_tot_cargo            pr_cobros.mto_capital%TYPE;
    v_tot_car_iva          pr_cobros.mto_capital%TYPE;
    v_tot_int_descontado   pr_cobros.mto_capital%TYPE;
    v_dia_mora             pr_cta_prestamos.dia_atraso%TYPE;
    v_tot_deuda            pr_cobros.mto_capital%TYPE;
    v_impuesto             pr_cobros.mto_capital%TYPE;
    v_nro_documento        ge_movimientos.nro_documento%type;
    v_nro_secuencia        ge_movimientos.nro_secuencia%type;
    v_cdusuar              ge_movimientos.cod_usuario%type;
    val_tas_iva_descontado ge_movimientos.val_tasa%type;
    v_cod_tasa             ge_transacciones.cod_tasa%type;
    v_nro_caja             ge_movimientos.nro_caja%type;
    v_cod_oficina          ge_movimientos.cod_oficina%type;
    v_hora                 ge_movimientos.hora%type := to_char(sysdate,'hh24:mi:ss');
    v_cod_usuario          ba_usuarios.cod_usuario%TYPE;
    v_horario            varchar2(1);
    v_es_mov_noc         varchar2(1) := 'N';
    v_es_cta_noc         varchar2(1);
    v_fec_valor          ge_calendarios.fec_actual%type; 
                                                                                                                          
  begin

    v_error   := v_pro_correcto;
    v_mensaje := 'Operacion Exitosa!';
    v_fecha   := pag_cal.FU_OBT_FEC_ACTUAL(6);
                        
    -- Recuperar deuda total para la cancelacion.
    pap_pre.pr_ini_autorizacion;
    --- Inicializar variables de cobro
    pap_pre.pr_ini_var_cobro;
    pap_pre.pr_obt_dat_prestamo(p_nro_cuenta, r_pcpre);    
    
    PR_VER_HORARIO(r_pcpre.cod_oficina,
    v_horario,
    v_es_mov_noc,
    v_es_cta_noc,
    v_fecha,
    v_fec_valor,
    p_cod_error,
    p_men_error);
    
    /** obtengo el redondeo para la moneda **/
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                      r_pcpre.cod_modulo,
                                      r_pcpre.cod_modalidad,
                                      r_pcpre.cod_moneda);
                                      
    --------------------------------------------------------

      v_cod_usuario := user;
      v_hora          := fu_hora_disp('S_NRO_HORA_PREST'); --Seteo de v_hora      
                                     

    if p_cod_canal in ('W', 'M') then
      PRW_OBT_DAT_CAJA(p_cod_canal,
                       v_nro_caja,
                       v_cod_oficina,
                       v_cdusuar,
                       P_COD_ERROR,
                       P_MEN_ERROR);
    else
      v_cdusuar := substr(v_cod_usuario, 1, 10);
    end if;



    pap_pre.pr_obt_deu_prestamo(p_nro_cuenta,
                                v_fecha,
                                0,
                                999,
                                r_pcpre.cod_oficina,
                                null,
                                v_error,
                                v_mensaje,
                                v_mto_capital,
                                v_mto_interes,
                                v_sal_int_ade,
                                v_tot_mora,
                                v_tot_mor_interes,
                                v_tot_mor_int_ade,
                                v_tot_punitorio,
                                v_tot_impuesto,
                                v_tot_cargo,
                                v_tot_car_iva,
                                v_tot_int_descontado,
                                v_dia_mora,
                                359, --transaccion de cancelacion anticipada
                                v_tip_cancelacion);

    if v_error = v_pro_correcto then
      v_mto_capital := nvl(v_mto_capital, 0) + nvl(v_sal_int_ade, 0);

      v_tot_deuda := nvl(v_mto_capital, 0) + nvl(v_mto_interes, 0) +
                     nvl(v_tot_mora, 0) + nvl(v_tot_mor_interes, 0) +
                     nvl(v_tot_mor_int_ade, 0) + nvl(v_tot_punitorio, 0) +
                     nvl(v_tot_impuesto, 0) + nvl(v_tot_cargo, 0);

    end if;

    pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo,
                            r_pcpre.cod_modalidad,
                            r_pcpre.cod_oficina,
                            p_nro_cuenta,
                            r_pcpre.cod_moneda,
                            v_tot_int_descontado,
                            'N',
                            v_cod_tasa,
                            1708,
                            v_fecha,
                            val_tas_iva_descontado,
                            v_fec_vigencia,
                            v_tip_valor,
                            v_tipo);

    IF fug_obt_pardinamico('PRE_IVA_INT_DESCONTADO') = 'S' THEN
      -- Verificar si se cobro iva en la solicitud
      begin
        select 'S'
          into v_cob_iva
          from pr_sol_cargos
         where nro_solicitud = r_pcpre.nro_solicitud
           and cod_transaccion = 709;
      exception
        when others then
          v_cob_iva := 'N';
      end;

      if v_cob_iva = 'S' then
        v_tot_iva_descontado := round(nvl(v_tot_int_descontado, 0) *
                                      (val_tas_iva_descontado / 100),
                                      v_redondeo);
      else
        v_tot_iva_descontado := 0;
      end if;
    else
      v_tot_iva_descontado := 0;
    end if;

    if fug_obt_pardinamico('PRE_CAR_DEV_SEGURO') = 'S' then
      prp_obt_mto_seg_descontado(r_pcpre.nro_cuenta,
                                 v_tot_seg_descontado,
                                 v_impuesto);
      v_tot_iva_descontado := v_tot_iva_descontado + v_impuesto;
    else
      v_tot_seg_descontado := 0;
    end if;

    v_tot_deuda := v_tot_deuda - v_tot_iva_descontado -
                   v_tot_seg_descontado;

    pap_pre.pr_ini_autorizacion;
    pap_pre.pr_obt_deu_prestamo(r_pcpre.nro_cuenta,
                                v_fecha,
                                0,
                                999,
                                r_pcpre.cod_oficina,
                                nvl(v_tot_deuda, null),
                                v_error,
                                v_mensaje,
                                v_mto_capital,
                                v_mto_interes,
                                v_sal_int_ade,
                                v_tot_mora,
                                v_tot_mor_interes,
                                v_tot_mor_int_ade,
                                v_tot_punitorio,
                                v_tot_impuesto,
                                v_tot_cargo,
                                v_tot_car_iva,
                                v_tot_int_descontado,
                                v_dia_mora,
                                359,
                                v_tip_cancelacion);

    if v_error = v_pro_correcto then
      v_mto_capital := nvl(v_mto_capital, 0) + nvl(v_sal_int_ade, 0);

      v_tot_deuda := nvl(v_mto_capital, 0) + nvl(v_mto_interes, 0) +
                     nvl(v_tot_mora, 0) + nvl(v_tot_mor_interes, 0) +
                     nvl(v_tot_mor_int_ade, 0) + nvl(v_tot_punitorio, 0) +
                     nvl(v_tot_impuesto, 0) + nvl(v_tot_cargo, 0);

    end if;

    v_nro_secuencia := 0;
    pag_cta.PR_SET_VARIABLES(v_cod_usuario,
                             v_fecha,
                             null,
                             'N',
                             'N',
                             v_nro_secuencia,
                             null,
                             r_pcpre.cod_oficina,
                             r_pcpre.cod_modulo,
                             r_pcpre.cod_modalidad);
    pap_pre.pr_can_prestamo(r_pcpre.nro_cuenta,
                            nvl(v_tot_deuda, 0) +
                            nvl(v_tot_iva_descontado, 0) +
                            nvl(v_tot_seg_descontado, 0),
                            'N', --- Se pidio autorizacion
                            r_pcpre.cod_oficina, --- oficina origen
                            v_tip_cancelacion,
                            v_fecha,
                            v_hora,
                            v_nro_secuencia);

    --- Generar numeracion de recibo
    if v_mto_capital + v_mto_interes > 0 then
      v_nro_documento := fug_obt_lla_pardinamico('NRO_RECIBO',
                                                 6,
                                                 r_pcpre.cod_modalidad,
                                                 r_pcpre.cod_moneda,
                                                 r_pcpre.cod_oficina) + 1;
      prg_act_par_dinamico('NRO_RECIBO',
                           6,
                           r_pcpre.cod_modalidad,
                           r_pcpre.cod_moneda,
                           r_pcpre.cod_oficina,
                           v_nro_documento);
    end if;

    --calcula impuesto si corresponde y genera movimiento
    v_nro_secuencia := nvl(v_nro_secuencia, 0) + 1;
    prg_ver_cob_cargos(p_nro_cta_debito,
                       r_pcpre.nro_cuenta,
                       r_pcpre.cod_modulo,
                       r_pcpre.cod_modalidad,
                       r_pcpre.cod_oficina,
                       r_pcpre.cod_moneda,
                       v_tot_deuda,
                       'Cobro de Prestamo ' || r_pcpre.nro_cuenta,
                       v_nro_documento,
                       v_fecha,
                       v_hora,
                       v_impuesto,
                       v_nro_secuencia,
                       'S'); --procesar

/*    pag_cta.PR_SET_VARIABLES(v_cod_usuario,
                             v_fecha,
                             null,
                             'N',
                             'N',
                             v_nro_secuencia,
                             null,
                             r_pcpre.cod_oficina,
                             r_pcpre.cod_modulo,
                             r_pcpre.cod_modalidad);*/

    v_nro_secuencia := nvl(v_nro_secuencia, 0) + 1;

    pag_cta.pr_act_operacion(p_nro_cta_debito,
                             v_hora, --HORA
                             'D',
                             r_pcpre.cod_moneda, --Moneda de la Operacion
                             v_tot_deuda + nvl(v_impuesto, 0),
                             359, -- Cobro de prestamos
                             503, -- Debito
                             r_pcpre.nro_cuenta,
                             NULL, --COTIZACION
                             r_pcpre.cod_oficina, --cod_ofi_origen
                             r_pcpre.cod_modulo, --cod_mod_padre
                             r_pcpre.cod_modalidad, --cod_mad_padre
                             null, --cod_tasa
                             null, --val_tasa
                             'Cancelacion de prestamo ' ||
                             r_pcpre.nro_cuenta,
                             'S', --emi_aviso
                             v_nro_secuencia,
                             v_fecha);

    v_error := pag_cta.fu_obt_cod_error();

    if pag_cta.fu_obt_cod_error() <> 0 then
      v_mensaje := pag_cta.fu_obt_cod_error() || ' - ' ||
                   pag_cta.fu_obt_msj_error();
    end if;
    if nvl(v_error, 0) = 0 then
      --- Actualizar formas de cobro con el recibo y la factura
      if v_nro_documento is not null then
        update ge_movimientos
           set nro_documento = v_nro_documento
         where fecha = v_fecha
           and hora = v_hora
           and cod_usuario = v_cod_usuario
           and cod_transaccion in (503, 842);
      end if;

      select t.cod_persona
        into v_cod_persona
        from ge_cta_clientes t
       where t.nro_cuenta = r_pcpre.nro_cuenta
         and t.relacion = 'P';

      prg_gen_comprobantes('PC',
                           v_fecha,
                           v_hora,
                           v_nro_secuencia,
                           v_cod_usuario,
                           'COB. C/CTA ' || p_nro_cta_debito,
                           null,
                           r_pcpre.cod_moneda,
                           v_tot_deuda + nvl(v_impuesto, 0),
                           v_cod_persona,
                           p_nro_cta_debito,
                           null,
                           null,
                           null,
                           null,
                           null,
                           null,
                           null,
                           null,
                           null,
                           null,
                           p_nro_cuenta,
                           null,
                           null,
                           null,
                           null,
                           v_cdusuar,
                           'Cancelacion de Prestamo. ' || p_nro_cuenta,
                           null,
                           null,
                           null,
                           null,
                           null);
    end if;
    p_cod_error := v_error;
    p_men_error := v_mensaje;
    pap_pre.pr_ini_var_cobro;

  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := substr(sqlerrm, 1, 4000);
      prg_ins_log_programas(v_nom_programa,
                            substr('2-Error: ' || p_cod_error || ' - ' ||
                                   p_men_error,
                                   1,
                                   4000),
                            fug_obt_cli_principal(p_nro_cuenta),
                            p_nro_cuenta);
  end;
  procedure pr_cal_cuo_plataforma(p_tip_prestamo    in varchar2 default 'CONSUMO', --CONSUMO, HIPOTECARIO, ETC
                                  p_cod_moneda      in varchar2,
                                  p_dia_vencimiento in number, --1, 10, 15 (vto cada mes)
                                  p_monto           in number,
                                  p_can_cuotas      in number,
                                  p_mto_cuota       out number,
                                  p_error           out varchar2) IS

    v_dummy         NUMBER(9);
    v_tot_prestamo  NUMBER(18, 2) := 0; -- total del prestamo
    v_dia_plazo     NUMBER(8);
    v_cod_modulo    NUMBER(3) := 6; -- prestamos
    v_cod_modalidad NUMBER(3);
    v_cod_oficina   NUMBER(3) := fug_obt_pardinamico('COD_OFI_WERKING');
    v_mon_local     VARCHAR2(3) := pag_gen.fu_obt_mon_local;
    v_cotizacion    ge_cotizaciones.val_conversion%TYPE := pag_gen.fu_obt_cotizacion(p_cod_moneda);
    v_lugar         VARCHAR2(200) := NULL;
    v_exo_impuestos VARCHAR2(1) := 'N';
    v_val_tasa      NUMBER(18, 2); --:= p_val_tasa;
    v_fec_actual    DATE;
    v_fec_inicio    DATE; --:= nvl(p_Fec_inicio,v_fec_actual);
    v_tip_monto     VARCHAR2(1);
    v_var_fecha     VARCHAR2(10);
    -- Datos de los cargos -----------------------------------------------------

    v_cod_tas_cargo   NUMBER(4);
    v_val_tas_cargo   NUMBER(18, 4);
    v_cod_mon_cargo   VARCHAR2(3);
    v_tpvlpor         VARCHAR2(1);
    v_aplicar         VARCHAR2(3);
    v_tpdetas         VARCHAR2(1);
    v_val_cargo       NUMBER(18, 4);
    v_cargos          typ_listadescargo;
    v_des_transaccion VARCHAR2(120);
    -- control del redondeo ----------------------------------------------------
    v_redondeo NUMBER(2) := 0; -- redondeo a cero para moneda local
    --v_descripcion      VARCHAR2(100) := nvl(p_descripcion,fug_obt_des_modal(v_cod_modulo,p_cod_modalidad));
    v_tip_interes         varchar2(1) := 'A';
    v_mto_interes         number(20, 4);
    v_tot_cargo           number(18, 4);
    V_TTVALOR             number(18, 2);
    v_desembolsar         number(18, 2);
    v_cod_moneda          varchar2(3);
    V_FEC_PRI_VENCIMIENTO DATE; -- := P_FEC_PRI_VENCIMIENTO;
    v_FEC_VENCIMIENTO     date;
    v_mto_tot_seguro      NUMBER(18, 4);
    -- V_DIA_PLAZO        number;
    v_val_cuota  NUMBER(18, 2);
    v_por_ajuste NUMBER;
    v_mto_cargo  NUMBER(18, 2) := 0;
    g_lugar      VARCHAR2(250);
    g_msj_error  VARCHAR2(4000); --(250);
    g_cod_error  NUMBER(3) DEFAULT 0;

    ------------------ rutinas internas del procedimiento-----------------------
    --Calculo de cuotas
    PROCEDURE pr_gen_cuotas(ww_neto IN VARCHAR2, p_monto_cuota out number) IS

      ww_frances         NUMBER;
      ww_tasadiv         NUMBER := v_val_tasa / 36500;
      ww_vlsalan         NUMBER(18, 2) := v_tot_prestamo;
      ww_ttcuota         NUMBER(18, 2) := NULL;
      ww_dfcuota         NUMBER(18, 2);
      ww_ttcapit         NUMBER(18, 2) := 0;
      ww_ttrefue         NUMBER(18, 2) := 0;
      ww_refreal         NUMBER(18, 2) := 0;
      ww_ctrefue         NUMBER(6) := 0;
      ww_nro             NUMBER(6) := 0;
      ww_veces           NUMBER(3) := 0;
      v_val_int_original NUMBER(18, 2) := 0;
      --
      v_fec_vto_habil DATE;

      v_sal_cap_anterior NUMBER(18, 2);

      v_dia_interes NUMBER(6);
      v_val_interes NUMBER(18, 2);
      v_ttcuota     NUMBER(18, 2);
      v_dia_periodo NUMBER(8);
      v_mto_capital NUMBER(18, 2);
      v_ven_fijo    VARCHAR2(1) := 'S';
      v_per_interes NUMBER := 30;
      v_val_cuota   NUMBER;
      -------

      ww_redondeo        number(2) := 0; -- redondeo a cero para moneda local
      ww_limite          number := 10; -- limite superior para ajustes de cuotas iguales en moneda local
      v_dias             number;
      v_fec_ven_anterior date;
      v_val_cuo_ant      NUMBER(18, 2) := 0;

    BEGIN

      --- Veo el tipo de redondeo de los calculos ------------------------------------------
      ww_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                         V_cod_modulo,
                                         v_cod_modalidad,
                                         p_cod_moneda,
                                         v_cod_oficina);
      If ww_redondeo != 0 then
        ww_limite := 0.05;
      else
        ww_limite := 1;
      End If;

      If v_ven_fijo is null then
        v_ven_fijo := 'S';
      End if;
      ---
      if v_per_interes = 30 and v_ven_fijo = 'S' then
        v_dias := 30.416666666666666666666666666667;
      else
        v_dias := v_per_interes;
      end if;

      LOOP
        v_fec_ven_anterior := v_fec_inicio;
        ww_veces           := NVL(ww_veces, 0) + 1;

        --- calculo del valor del metodo frances -----------------------------
        IF (power((1 + (ww_tasadiv * v_dias)), (p_can_cuotas - ww_ctrefue)) - 1) > 0 THEN
          ww_frances := ((NVL(nvl(v_tot_prestamo, p_monto), 0) -
                        NVL(ww_ttrefue, 0)) * ww_tasadiv * v_dias) /
                        (power((1 + (ww_tasadiv * v_dias)),
                               (p_can_cuotas - ww_ctrefue)) - 1);

        ELSE
          --- Para los casos en que la tasa = 0 para que no de division por cero.
          ww_frances := ((NVL(v_tot_prestamo, 0) - NVL(ww_ttrefue, 0))) /
                        ((p_can_cuotas - ww_ctrefue));
        END IF;

        --- Veo el monto fijo de cuota si es de tipo Prestamos flexibles -----
        ----------------------------------------------------------------------
        v_mto_interes := 0;
        ww_vlsalan    := V_TOT_PRESTAMO;
        ww_ttcapit    := 0;
        ww_refreal    := 0;
        ww_nro        := 0; /* acumulador de cuotas calculadas automaticamente, sin refuerzo */

        FOR cuota IN 1 .. p_can_cuotas LOOP

          V_SAL_CAP_ANTERIOR := ww_vlsalan;
          IF CUOTA = 1 AND
             ABS(30 - (v_fec_pri_vencimiento - v_fec_inicio)) > 1 THEN
            /* se hace el calculo del interes por el plazo del periodo de gracia */
            V_DIA_PERIODO := v_fec_pri_vencimiento - v_fec_inicio;
            V_DIA_INTERES := v_fec_pri_vencimiento - v_fec_inicio;
            V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv * v_dias /*V_DIA_INTERES*/
                                   ),
                                   ww_redondeo);
            v_val_cuota   := null;
          ELSE
            if fug_obt_tip_entidad != 'F' then
              V_DIA_PERIODO := V_FEC_VTO_HABIL - v_Fec_ven_anterior;
              V_DIA_INTERES := V_FEC_VTO_HABIL - v_Fec_ven_anterior;
              V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv * v_dias /*v_dia_interes*/
                                     ),
                                     ww_redondeo);
            else
              V_DIA_PERIODO := v_per_interes;
              V_DIA_INTERES := v_per_interes;
              V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv * v_dias),
                                     ww_redondeo);
            end if;
          END IF;

          IF v_val_int_original > 0 THEN
            /* es una cuota con refuerzo */
            IF ww_neto = 'S' THEN
              V_MTO_CAPITAL := V_MTO_CAPITAL;
            ELSE
              V_MTO_CAPITAL := V_VAL_INT_ORIGINAL - V_VAL_INTERES;
            END IF;
            ww_refreal  := NVL(ww_refreal, 0) + NVL(V_MTO_CAPITAL, 0);
            v_val_cuota := null;
          ELSE
            ww_nro := ww_nro + 1;
            if v_val_cuota is not null and fug_obt_tip_entidad != 'F' then
              V_MTO_CAPITAL := v_val_cuota - V_VAL_INTERES;
            else
              V_MTO_CAPITAL := ROUND((ww_frances *
                                     power((1 + (ww_tasadiv * v_dias)),
                                            (ww_nro - 1))),
                                     ww_redondeo);
            end if;
            v_val_cuota := V_MTO_CAPITAL + V_VAL_INTERES;
          END IF;

          V_TTCUOTA  := NVL(V_MTO_CAPITAL, 0) + NVL(V_VAL_INTERES, 0);
          ww_dfcuota := NVL(ww_ttcuota, V_TTCUOTA) - NVL(V_TTCUOTA, 0);
          -- ajuste de cuotas para que sean iguales solo se hace si esta dentro del limite
          IF (ABS(ww_dfcuota) BETWEEN 0.001 AND ww_limite) THEN
            V_VAL_INTERES := V_VAL_INTERES + ww_dfcuota;
            V_TTCUOTA     := V_TTCUOTA + ww_dfcuota;
          END IF;
          ww_ttcuota         := V_TTCUOTA;
          ww_vlsalan         := NVL(ww_vlsalan, 0) - V_MTO_CAPITAL;
          ww_ttcapit         := NVL(ww_ttcapit, 0) + NVL(V_MTO_CAPITAL, 0);
          V_MTO_INTERES      := V_MTO_INTERES + NVL(V_VAL_INTERES, 0);
          v_fec_ven_anterior := V_FEC_VTO_HABIL;
          IF NVL(V_MTO_CAPITAL, 0) < 0 or NVL(V_VAL_INTERES, 0) < 0 THEN
            raise_application_error(-20000,
                                    'ERROR. Capital o Interes no puede quedar en negativo. Verifique');
          END IF;
          IF v_val_cuo_ant != v_val_cuota then
            v_val_cuo_ant := v_val_cuota;
          END IF;

        END LOOP;
        p_monto_cuota := v_val_cuo_ant;
        IF abs(nvl(ww_refreal, 0) - nvl(ww_ttrefue, 0)) < 10 OR
           ww_veces > 12 OR v_tip_monto = 'N' THEN
          EXIT;
        END IF;

      END LOOP;

      ww_dfcuota := nvl(V_TOT_PRESTAMO, 0) - NVL(ww_ttcapit, 0);
      IF ww_dfcuota <> 0 THEN
        V_MTO_CAPITAL := V_MTO_CAPITAL + ww_dfcuota;
        IF NVL(V_VAL_INTERES, 0) >= ww_dfcuota and abs(ww_dfcuota) <= 1 THEN
          /* solo se ajusta si existe interes*/
          V_VAL_INTERES := NVL(V_VAL_INTERES, 0) - ww_dfcuota;
          V_MTO_INTERES := V_MTO_INTERES - ww_dfcuota;
        ELSE
          V_TTCUOTA := NVL(V_MTO_CAPITAL, 0) + NVL(V_VAL_INTERES, 0);
        END IF;

      END IF;
      ---------------------------------------------------------
    EXCEPTION
      WHEN OTHERS THEN
        g_cod_error := 20;
        g_msj_error := 'Error en calculo de cuotas ' || sqlerrm;
        g_lugar     := 'pr_gen_cuotas';
    END;
    --
    PROCEDURE pr_val_tasa IS
      CURSOR pizarras IS
        SELECT a.tas_interes, a.tas_minima, a.tas_maxima
          FROM cr_piz_montos b, cr_piz_plazos a
         WHERE a.cod_modulo = v_cod_modulo
           AND a.cod_modalidad = v_cod_modalidad
           AND a.cod_moneda = p_cod_moneda
           AND b.cod_modulo = a.cod_modulo
           AND b.cod_modalidad = a.cod_modalidad
           AND b.cod_moneda = a.cod_moneda
           AND b.mto_desde = a.mto_desde
           AND p_monto BETWEEN b.mto_desde AND b.mto_hasta
           AND v_dia_plazo BETWEEN a.plz_desde AND a.plz_hasta;
      v_tas_interes NUMBER;
      v_tas_minima  NUMBER;
      v_tas_maxima  NUMBER;
    BEGIN
      v_lugar := 'obtener_tasas de pizarras';
      OPEN pizarras;
      FETCH pizarras
        INTO v_tas_interes, v_tas_minima, v_tas_maxima;
      CLOSE pizarras;
      IF v_val_tasa IS NULL THEN
        v_val_tasa := nvl(v_tas_interes, 32);
      ELSE
        -- valido la tasa ingresada---
        IF (NOT v_val_tasa BETWEEN nvl(v_tas_minima, 0) AND
           nvl(v_tas_maxima, 0)) or v_val_tasa = 0 THEN
          g_cod_error := 1;
          g_lugar     := 'Valida Tasa ingresada';
          g_msj_error := 'Tasa fuera de Rango. Verifique la Pizarra';
        END IF;
      END IF;
    END;
    /* Obtener tasas de pizarra. */
    /* PROCEDURE pr_obt_tas_pizarra
    (
       p_cod_modulo         IN ge_cuentas.cod_modulo%TYPE,
       p_cod_modalidad      IN ge_cuentas.cod_modalidad%TYPE,
       p_cod_moneda         IN ge_cuentas.cod_moneda%TYPE,
       p_plazo              IN NUMBER,
       p_monto              IN ge_cuentas.sal_promedio%TYPE
       p_tip_capitalizacion IN cr_piz_plazos.tip_capitalizacion%TYPE,
       p_tas_minima         IN OUT ge_tas_fechas.val_tasa%TYPE,
       p_tas_maxima         IN OUT ge_tas_fechas.val_tasa%TYPE,
       p_tas_interes        IN OUT ge_tas_fechas.val_tasa%TYPE,
       p_tas_efectiva       IN OUT cr_piz_plazos.tas_efectiva%TYPE
    ) IS
    v_tas_minima            ge_tas_fechas.val_tasa%TYPE;
    v_tas_maxima            ge_tas_fechas.val_tasa%TYPE;
    v_tas_interes           ge_tas_fechas.val_tasa%TYPE;
    v_tas_efectiva          cr_piz_plazos.tas_efectiva%TYPE;

    v_val_tasa              ge_tas_fechas.val_tasa%TYPE;
    BEGIN
       SELECT tas_minima, tas_maxima, tas_interes, tas_efectiva
         INTO v_tas_minima, v_tas_maxima, v_val_tasa, v_tas_efectiva
         FROM cr_piz_plazos b, cr_piz_montos a
        WHERE b.cod_moneda = p_cod_moneda
          AND b.cod_modulo = p_cod_modulo
          AND b.cod_modalidad = p_cod_modalidad
          AND p_plazo BETWEEN b.plz_desde AND b.plz_hasta
          AND p_monto BETWEEN a.mto_desde AND a.mto_hasta
          --AND nvl(b.tip_capitalizacion, nvl(p_tip_capitalizacion, 0)) = nvl(p_tip_capitalizacion, 0)
          AND a.cod_moneda = p_cod_moneda
          AND a.cod_modulo = p_cod_modulo
          AND a.cod_modalidad = p_cod_modalidad
          AND a.mto_desde = b.mto_desde;
    EXCEPTION
       WHEN no_data_found THEN
          -- se ponen los valores a cero para que no se corte la grabacion
          p_tas_minima   := 0;
          p_tas_maxima   := 0;
          p_tas_interes  := 0;
          p_tas_efectiva := 0;
       WHEN too_many_rows THEN
          --- Existe especificacion para nulos y tipo de capitalizacion
          BEGIN
             SELECT tas_minima, tas_maxima, tas_interes, tas_efectiva
               INTO v_tas_minima, v_tas_maxima, v_val_tasa, v_tas_efectiva
               FROM cr_piz_montos a, cr_piz_plazos b
              WHERE b.cod_moneda = p_cod_moneda
                AND b.cod_modulo = p_cod_modulo
                AND b.cod_modalidad = p_cod_modalidad
                AND p_plazo BETWEEN b.plz_desde AND b.plz_hasta
                AND p_monto BETWEEN a.mto_desde AND a.mto_hasta
                AND b.tip_capitalizacion IS NULL
                AND a.cod_moneda = p_cod_moneda
                AND a.cod_modulo = p_cod_modulo
                AND a.cod_modalidad = p_cod_modalidad
                AND a.mto_desde = b.mto_desde;
          EXCEPTION
             WHEN no_data_found THEN
                raise_application_error(-20000, 'Tasa de pizarra no definida ');
             WHEN too_many_rows THEN
                raise_application_error(-20000, 'Existe mas de una pizarra definida');
          END;
       WHEN OTHERS THEN
          IF SQLCODE <= -20000 THEN
             RAISE;
          ELSE
             raise_application_error(-20000, 'Obt. Tasa Pizarra ' || SQLERRM);
          END IF;
    END;*/
    -- Validacion del tipo de credito---------------------------------------------
    PROCEDURE pr_val_cod_modalidad IS
    BEGIN
      SELECT 0
        INTO v_dummy
        FROM ge_modalidades
       WHERE cod_modulo = v_cod_modulo
         AND cod_modalidad = v_cod_modalidad;
    EXCEPTION
      WHEN no_data_found THEN
        g_cod_error := 6;
        g_lugar     := 'Valida Modalidad';
        g_msj_error := 'Tipo de Prestamo no habilitado. Modalidad: ' ||
                       v_cod_modalidad;
      WHEN OTHERS THEN
        g_cod_error := 7;
        g_lugar     := 'Valida Modalidad';
        g_msj_error := 'Error al validar Modalidad ' || SQLERRM;
    END;
    -- Validacion del codigo de la moneda-----------------------------------------
    FUNCTION fu_val_cod_moneda(p_cod_moneda in varchar2) return varchar2 IS
    BEGIN
      SELECT cod_moneda
        INTO v_cod_moneda
        FROM ba_monedas
       WHERE cod_moneda = p_cod_moneda;
      return v_cod_moneda;
    EXCEPTION
      WHEN no_data_found THEN
        begin
          select cod_moneda
            into v_cod_moneda
            from ba_monedas m
           where m.cod_mon_iso = p_cod_moneda;
          return v_cod_moneda;
        exception
          when no_data_found then
            begin
              select cod_moneda
                into v_cod_moneda
                from ba_monedas m
               where m.cod_mon_bco_central = p_cod_moneda;
              return v_cod_moneda;
            exception
              when no_data_found then
                g_cod_error := 8;
                g_lugar     := 'Valida Moneda';
                g_msj_error := 'Codigo de Moneda inexistente';
            end;
        end;
        return null;
      WHEN OTHERS THEN
        g_cod_error := 9;
        g_lugar     := 'Valida Moneda';
        g_msj_error := 'Error al validar moneda ' || SQLERRM;
    END;

    FUNCTION fp_obt_tasa(P_TASA IN varchar2) RETURN VARCHAR2 IS
      V_RETORNO VARCHAR2(1) := 'N';
    BEGIN
      SELECT 'S'
        INTO v_retorno
        FROM ge_tasas
       WHERE cod_tasa = (replace(p_tasa, ',', '.'));
      RETURN v_retorno;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RETURN 'N';
      WHEN OTHERS THEN
        RETURN 'N';
    END;

    function fu_obt_nom_seguro(p_transaccion in varchar2,
                               p_cod_ente    in varchar2) RETURN VARCHAR2 IS
      v_tipo       VARCHAR2(3);
      v_nom_seguro ge_entes.descripcion%type;
    BEGIN
      IF p_transaccion IN (701, 735) THEN
        -- cargos de escribania ---
        v_tipo := 'ES';
      ELSE
        --- cargos de seguros -----
        v_tipo := 'SE';
      END IF;
      SELECT SUBSTR(DESCRIPCION, 1, 20)
        INTO v_nom_seguro
        FROM GE_ENTES
       WHERE COD_ENTE = p_cod_ente
         AND TIPO = v_tipo;

      RETURN v_nom_seguro;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        IF v_tipo = 'SE' THEN
          g_cod_error := 7;
          g_lugar     := 'Valida Seguro definido';
          g_msj_error := 'No se encuentra el Seguro.';
        ELSE
          g_cod_error := 8;
          g_lugar     := 'Valida Escribania definido';
          g_msj_error := 'Escribania no existe.';
        END IF;
      WHEN OTHERS THEN
        g_cod_error := 9;
        g_lugar     := 'Valida Seguro/Escribania';
        g_msj_error := 'ERROR: FU_OBT_NOM_SEGURO ' || SQLERRM;
    END;
    -- Carga de cargos de la propuesta-------------------------------------------
    function fu_obt_cargos return typ_listadescargo IS
      CURSOR cargos IS
        SELECT DISTINCT decode(a.cod_transaccion,
                               709,
                               1,
                               710,
                               2,
                               a.cod_transaccion) orden, -- solo para ordenamiento
                        a.cod_transaccion,
                        fug_obt_des_transaccion(a.cod_modulo,
                                                a.cod_modalidad,
                                                a.cod_transaccion) des_transaccion,
                        a.cod_ent_seguro,
                        nvl(b.obligatorio, 'N') obligator
          FROM ge_sol_cargos a, ge_transacciones_det b
         WHERE a.cod_transaccion = b.cod_tra_hijo(+)
           AND a.cod_modulo = b.cod_mod_hijo(+)
           AND a.cod_modalidad = b.cod_mad_hijo(+)
           AND a.cod_modulo = v_cod_modulo
           AND a.cod_modalidad = v_cod_modalidad
              --and a.cod_transaccion not in(736)
           AND ((nvl(v_exo_impuestos, 'N') = 'N') OR
               (nvl(v_exo_impuestos, 'N') = 'S' AND
               nvl(b.obligatorio, 'N') = 'N'))
         ORDER BY 1;

      detalleCargos typ_descargo := typ_descargo;
      listaCargos   typ_listadescargo := typ_listadesCargo();
      v_retorno     typ_listadescargo := typ_listadescargo();
      v_can_cargos  number(10);

    BEGIN
      v_can_cargos := 0;
      FOR cc IN cargos LOOP
        detalleCargos.COD_TRANSACCION := cc.cod_transaccion;
        detalleCargos.DES_TRANSACCION := cc.des_transaccion;
        detalleCargos.COD_ENT_SEGURO  := cc.cod_ent_seguro;

        IF detalleCargos.COD_TRANSACCION IN (701, 702, 735, 736, 737) THEN
          --- es un seguro -------------------
          IF detalleCargos.COD_ENT_SEGURO IS NULL THEN
            g_cod_error := 10;
            g_lugar     := 'Valida Seguro/Escribania';
            g_msj_error := 'Definir el Codigo del Seguro / Escribania(Cargos).';
          END IF;
        END IF;
        if nvl(g_cod_error, 0) = 0 then

          if detalleCargos.COD_TRANSACCION IN (701, 702, 735, 736, 737) THEN
            detalleCargos.NOM_SEGURO := fu_obt_nom_seguro(detalleCargos.COD_TRANSACCION,
                                                          detalleCargos.COD_ENT_SEGURO);
          end if;
          listacargos.extend;
          v_can_cargos := v_can_cargos + 1;
          listacargos(listaCargos.count) := detalleCargos;
        else
          exit;
        end if;
      end loop;

      v_retorno := listacargos;

      RETURN v_retorno;
    END;
    -- Procedimiento para obtener el tipo de tasa --------------------------------
    PROCEDURE pr_obt_tipo_de_tasa(ww_cdtrans IN NUMBER,
                                  ww_destran OUT VARCHAR2,
                                  ww_cddetas IN OUT NUMBER,
                                  ww_aplicar IN OUT VARCHAR2,
                                  ww_tpvlpor IN OUT VARCHAR2,
                                  ww_tpdetas IN OUT VARCHAR2) IS
    BEGIN
      v_lugar := 'OBTENER TIPO DE TASA ';
      --- 1. Busco la tasa asociada a la transaccion ingresada ---
      SELECT initcap(TR.DESCRIPCION),
             tr.cod_tasa,
             ta.aplicar,
             ta.tip_valor,
             ta.tipo
        INTO ww_destran, ww_cddetas, ww_aplicar, ww_tpvlpor, ww_tpdetas
        FROM ge_transacciones tr, ge_tasas ta
       WHERE tr.cod_modulo = v_cod_modulo
         AND tr.cod_modalidad = v_cod_modalidad
         AND tr.cod_transaccion = ww_cdtrans
         AND tr.tipo = 'D'
         AND tr.cod_tasa IS NOT NULL
         AND tr.cod_tasa = ta.cod_tasa
         AND EXISTS (SELECT 0
                FROM ge_transacciones_det
               WHERE cod_modulo = v_cod_modulo
                 AND cod_modalidad = v_cod_modalidad
                 AND cod_transaccion = 358 /* transaccion de desembolso de prestamos */
                 AND cod_mod_hijo = tr.cod_modulo
                 AND cod_mad_hijo = tr.cod_modalidad
                 AND cod_tra_hijo = tr.cod_transaccion);

    EXCEPTION
      WHEN no_data_found THEN
        g_cod_error := 11;
        g_lugar     := 'Valida Cargos';
        g_msj_error := 'Cargo no definido para Prestamos. ' || ww_cdtrans;
      WHEN OTHERS THEN
        g_cod_error := 12;
        g_lugar     := 'Valida Cargos';
        g_msj_error := 'ERROR: OBT_TIPO_TASA ' || SQLERRM;
    END;

    -- Funcion que obtiene el valor de la tasa fija ------------------------------
    FUNCTION fu_obt_valor_de_tasa_fija(ww_cddetas IN NUMBER,
                                       ww_fcinici IN DATE) RETURN NUMBER IS
      ww_vldetas NUMBER(15, 2);
    BEGIN
      v_lugar := 'OBTENER VALOR DE TASA FIJA ';
      -- tasa fija, buscar en tasa por fecha ---
      SELECT val_tasa
        INTO ww_vldetas
        FROM ge_tas_fechas f1
       WHERE f1.cod_tasa = ww_cddetas
         AND (f1.cod_modalidad IS NULL OR
             (f1.cod_modalidad = v_cod_modalidad))
         AND (f1.cod_modulo IS NULL OR (f1.cod_modulo = v_cod_modulo))
         AND (f1.cod_moneda IS NULL OR (f1.cod_moneda = v_cod_moneda))
         AND (f1.cod_oficina IS NULL OR (f1.cod_oficina = v_cod_oficina))
         AND f1.nro_cuenta IS NULL
         AND f1.fec_vigencia =
             (SELECT MAX(fec_vigencia)
                FROM ge_tas_fechas f2
               WHERE f2.cod_tasa = ww_cddetas
                 AND (f2.cod_modalidad IS NULL OR
                     (f2.cod_modalidad = v_cod_modalidad))
                 AND (f2.cod_modulo IS NULL OR
                     (f2.cod_modulo = v_cod_modulo))
                 AND (f2.cod_moneda IS NULL OR
                     (f2.cod_moneda = v_cod_moneda))
                 AND (f2.cod_oficina IS NULL OR
                     (f2.cod_oficina = v_cod_oficina))
                 AND f2.fec_vigencia <= ww_fcinici
                 AND f2.nro_cuenta IS NULL);
      RETURN ww_vldetas;
    EXCEPTION
      WHEN no_data_found THEN
        RETURN NULL;
      WHEN OTHERS THEN
        g_cod_error := 12;
        g_lugar     := 'Valida Cargos';
        g_msj_error := 'ERROR: OBT_TASA_FIJA ' || SQLERRM;
    END;

    -- Funcion que devuelve el valor de la tasa, si es variable ------------------
    FUNCTION fu_obt_valor_de_tasa_variable(ww_cddetas IN NUMBER,
                                           ww_vlmonto IN NUMBER,
                                           ww_fcinici IN DATE) RETURN NUMBER IS
      ww_vldetas NUMBER(15, 4);
      CURSOR tv IS
        SELECT tr.val_tasa
          FROM ge_tasas t, ge_tas_rangos tr
         WHERE t.cod_tasa = tr.cod_tasa
           AND t.cod_tasa = ww_cddetas
           AND (tr.cod_modulo = v_cod_modulo OR tr.cod_modulo IS NULL)
           AND (tr.cod_modalidad = v_cod_modalidad OR
               tr.cod_modalidad IS NULL)
           AND (tr.cod_moneda = v_cod_moneda OR tr.cod_moneda IS NULL)
           AND (tr.cod_oficina = v_cod_oficina OR tr.cod_oficina IS NULL)
           AND tr.val_hasta >= ww_vlmonto
           AND tr.nro_cuenta IS NULL
           AND tr.fec_vigencia =
               (SELECT MAX(tra.fec_vigencia)
                  FROM ge_tas_rangos tra
                 WHERE tra.cod_tasa = ww_cddetas
                   AND (tra.cod_modulo = v_cod_modulo OR
                       tra.cod_modulo IS NULL)
                   AND (tra.cod_modalidad = v_cod_modalidad OR
                       tra.cod_modalidad IS NULL)
                   AND (tra.cod_moneda = v_cod_moneda OR
                       tra.cod_moneda IS NULL)
                   AND (tra.cod_oficina = v_cod_oficina OR
                       tra.cod_oficina IS NULL)
                   AND tra.val_hasta >= ww_vlmonto
                   AND tra.nro_cuenta IS NULL
                   AND tra.fec_vigencia <= ww_fcinici)
         ORDER BY val_hasta;
    BEGIN
      v_lugar := 'OBTENER VALOR DE TASA VARIABLE ';
      -- tasa variable, buscar en tabla de tasas variables ---
      OPEN tv;
      FETCH tv
        INTO ww_vldetas;
      CLOSE tv;
      IF ww_vldetas IS NULL THEN
        g_cod_error := 12;
        g_lugar     := 'Valida Cargos';
        g_msj_error := 'No existe Valor para la Tasa ' ||
                       to_char(ww_cddetas) || ' y el Monto ' ||
                       to_char(ww_vlmonto) || ' Fecha ' ||
                       to_char(ww_fcinici, 'DD/MM/YYYY');
      END IF;
      RETURN ww_vldetas;
    EXCEPTION
      WHEN no_data_found THEN
        RETURN NULL;
      WHEN OTHERS THEN
        IF SQLCODE <= -20000 THEN
          RAISE;
        ELSE
          raise_application_error(-20000, 'obt_tasa_variable ' || SQLERRM);
        END IF;
    END;

    -- Verificacion del codigo de tasa--------------------------------------------
    PROCEDURE pr_obt_datos_cargo(p_cargos IN OUT typ_listadescargo) IS
      --declare
      v_cancargos        NUMBER := p_cargos.count;
      detalleCargos      typ_descargo := typ_descargo;
      listaCargos        typ_listadescargo := typ_listadesCargo();
      v_can_cargos       number(10) := 0;
      v_mto_mon_prestamo number(18, 4);
      v_cotizac          number(18, 2);

    BEGIN
      for x in 1 .. v_cancargos loop
        v_val_cargo     := 0;
        v_cod_mon_cargo := 0;
        -- obtengo los datos de la tasa-----------------
        pr_obt_tipo_de_tasa(p_cargos(x).cod_transaccion,
                            v_des_transaccion,
                            v_cod_tas_cargo,
                            v_aplicar,
                            v_tpvlpor,
                            v_tpdetas);

        --- la tasa es de tipo  valor ---
        IF v_tpdetas = 'F' THEN
          --- tipo de tasa fijo      ---
          v_val_tas_cargo := fu_obt_valor_de_tasa_fija(v_cod_tas_cargo,
                                                       v_fec_inicio);
        ELSE
          --- tipo de tasa variable  ---
          IF v_aplicar IN ('PI', 'PC', 'PT', 'PL', 'CP', 'IP', 'TP') THEN
            IF v_aplicar IN ('PI', 'PC', 'PT', 'PL') THEN
              --- El primer rango es por plazo
              v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_cod_tas_cargo,
                                                               v_dia_plazo,
                                                               v_fec_inicio);
            ELSE
              --- tipo de tasa variable  ---
              v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_cod_tas_cargo,
                                                               nvl(v_tot_prestamo,
                                                                   p_monto),
                                                               v_fec_inicio);
            END IF;

            IF fp_obt_tasa(v_val_tas_cargo) = 'S' AND
               v_tpvlpor NOT IN ('P', 'V') THEN
              IF v_aplicar IN ('CP', 'IP', 'TP') THEN
                -- aplicar al capital y plazo, busco ahora el valor por plazo
                v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_val_tas_cargo,
                                                                 v_dia_plazo,
                                                                 v_fec_inicio);
              ELSE
                v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_val_tas_cargo,
                                                                 nvl(v_tot_prestamo,
                                                                     p_monto),
                                                                 v_fec_inicio);
              END IF;
            END IF;

          ELSE
            v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_cod_tas_cargo,
                                                             nvl(v_tot_prestamo,
                                                                 p_monto),
                                                             v_fec_inicio);
          END IF;

        END IF;
        IF v_tpvlpor IN ('I', 'P') THEN
          --- porcentajes  o transacciones de seguros  ---
          v_cod_mon_cargo := v_mon_local;

          if v_tpvlpor = 'I' then
            v_cod_mon_cargo := v_mon_local;
          else
            v_cod_mon_cargo := v_cod_moneda;
          end if;
        ELSE

          IF v_val_tas_cargo IS NOT NULL THEN
            v_cod_mon_cargo := v_cod_moneda;
            v_val_cargo     := v_val_tas_cargo;
          END IF;
          /* solo si es valor */
          IF v_cod_mon_cargo = v_cod_moneda THEN
            -- moneda del cargo es igual a la moneda de la simulacion ----------------------
            v_mto_mon_prestamo := v_val_cargo;
          ELSE
            IF v_cod_moneda = v_mon_local THEN
              v_cotizac := null;
            END IF;
            -- monedas diferentes, se divide por la cotiz. de la moneda de la simulacion ---
            v_mto_mon_prestamo := pag_gen.fu_con_mon_a_moneda(v_cod_mon_cargo,
                                                              v_cod_moneda,
                                                              v_val_cargo,
                                                              V_COTIZAC);
          END IF;
          v_val_tas_cargo := NULL;
        END IF;
        IF v_cod_mon_cargo IS NULL THEN
          v_cod_mon_cargo := V_cod_moneda;
        END IF;

        detalleCargos.COD_TRANSACCION  := p_cargos(x).cod_transaccion;
        detalleCargos.DES_TRANSACCION  := p_cargos(x).des_transaccion;
        detalleCargos.COD_ENT_SEGURO   := p_cargos(x).cod_ent_seguro;
        detalleCargos.NOM_SEGURO       := p_cargos(x).NOM_SEGURO;
        detalleCargos.val_tasa         := v_val_tas_cargo;
        detalleCargos.COD_MONEDA       := v_cod_mon_cargo;
        detalleCargos.MONTO            := v_val_cargo;
        detalleCargos.MTO_MON_PRESTAMO := v_mto_mon_prestamo;
        detalleCargos.COD_TASA         := v_cod_tas_cargo;
        detalleCargos.FEC_TASA         := null;

        listacargos.extend;
        v_can_cargos := v_can_cargos + 1;
        listacargos(listaCargos.count) := detalleCargos;
      end loop;
      --v_retorno := listacargos;
      p_cargos := listacargos;
    END;

    -- Calculo de los cargos ----------------------------------------------------
    PROCEDURE pr_cal_cargos(p_tot_prestamo in number,
                            p_desembolsar  out number,
                            p_tot_cargo    out number,
                            p_ttvalor      out number,
                            p_cargos       in out typ_listadescargo) IS

      v_monto      NUMBER(18, 2);
      v_can_cargos number(10) := p_cargos.count;
      --V_DIA_PLAZO      NUMBER(18);
      v_ttvalor          NUMBER(18, 2);
      v_mto_cargo        NUMBER(18, 2);
      v_mto_mon_prestamo NUMBER(18, 2);
      v_des_transaccion  VARCHAR2(120);
      V_A_DESEMB         NUMBER(18, 2);
      detalleCargos      typ_descargo := typ_descargo;
      listaCargos        typ_listadescargo := typ_listadesCargo();

    BEGIN
      --- Calculo cada uno de los cargos en la moneda del cargo y en la de la simulacion ---
      --- cero los totales de cargo de tipo valor y el total general de cargos -------------
      v_ttvalor   := 0;
      v_mto_cargo := 0;
      --V_DIA_PLAZO := v_fec_vencimiento - v_fec_actual;
      FOR cc IN 1 .. v_can_cargos LOOP
        v_mto_mon_prestamo := 0;

        -- obtengo los datos de la tasa-----------------
        pr_obt_tipo_de_tasa(p_cargos         (cc).cod_transaccion,
                            v_des_transaccion,
                            p_cargos         (cc).cod_tasa,
                            v_aplicar,
                            v_tpvlpor,
                            v_tpdetas);

        IF v_tpvlpor = 'P' THEN
          v_mto_mon_prestamo := 0;
          --- la tasa es un porcentaje-----------------------------------------------------
          IF v_aplicar IN ('CI', 'IN', 'PI', 'IP', 'PT', 'TP') THEN
            --- aplicable al interes -----------------------------------------------------

            if p_cargos(cc).cod_transaccion in (736, 737) then
              ---v_tas_seguro := cc.val_tasa;
              v_mto_mon_prestamo := round(v_mto_tot_seguro, v_redondeo);
            else
              v_mto_mon_prestamo := round(v_mto_interes * p_cargos(cc).val_tasa / 100,
                                          v_redondeo);
            end if;

          END IF;
          IF v_aplicar IN ('CA', 'CI', 'PC', 'CP', 'PT', 'TP') THEN
            IF NVL(fug_obt_pardinamico('PRE_CAR_SEG_CAPITAL',
                                       v_cod_modulo,
                                       v_cod_modalidad,
                                       null),
                   'N') = 'S' AND NVL(fug_obt_pardinamico('PRE_MAD_CHE_COM',
                                                          v_cod_modulo,
                                                          v_cod_modalidad,
                                                          null),
                                      'N') = 'N' THEN
              if p_cargos(cc).cod_transaccion in (736, 737) then
                ---v_tas_seguro := cc.val_tasa;
                v_mto_mon_prestamo := round(v_mto_tot_seguro, v_redondeo);
              else
                v_mto_mon_prestamo := ROUND(((p_monto * p_cargos(cc).VAL_TASA *
                                            v_DIA_PLAZO) / 30) / 1000,
                                            v_redondeo);
              end if;
            ELSIF v_aplicar = 'CA' AND NVL(fug_obt_pardinamico('PRE_MAD_CHE_COM',
                                                               v_cod_modulo,
                                                               v_cod_modalidad,
                                                               null),
                                           'N') = 'S' THEN
              if p_cargos(cc).cod_transaccion in (736, 737) then
                ---v_tas_seguro := cc.val_tasa;
                v_mto_mon_prestamo := round(v_mto_tot_seguro, v_redondeo);
              else
                v_mto_mon_prestamo := ROUND(((p_monto * p_cargos(cc).VAL_TASA) / 100),
                                            v_redondeo);
              end if;
            ELSE
              if p_cargos(cc).cod_transaccion in (736, 737) then
                ---v_tas_seguro := cc.val_tasa;
                v_mto_mon_prestamo := round(v_mto_tot_seguro, v_redondeo);
              else
                v_mto_mon_prestamo := NVL(v_mto_mon_prestamo, 0) +
                                      ROUND(p_tot_prestamo * p_cargos(cc).VAL_TASA / 100,
                                            v_redondeo);
              end if;
            END IF;
          END IF;

          IF v_aplicar = 'MO' then
            --v_imp_cargo := 0;
            v_mto_mon_prestamo := NVL(v_mto_mon_prestamo, 0) +
                                  ROUND(p_monto * p_cargos(cc).VAL_TASA / 100,
                                        v_redondeo);
            --v_mto_mon_prestamo := v_imp_cargo + ROUND(p_cargos(cc).VAL_TASA * 10/100,v_redondeo);
          END IF;

          IF p_cargos(cc).COD_MONEDA = V_COD_MONEDA THEN
            -- moneda del cargo es igual a la moneda de la simulacion ----------------------
            V_MONTO := v_mto_mon_prestamo;
          ELSE
            -- monedas diferentes, se divide por la cotiz. de la moneda de la simulacion ---
            V_MONTO := ROUND(v_mto_mon_prestamo * v_cotizacion, v_redondeo);
          END IF;

        ELSIF v_tpvlpor = 'I' THEN
          v_mto_mon_prestamo := 0;
          --- la tasa es un impuesto ------------------------------------------------------
          IF v_aplicar IN ('CI', 'IN', 'PI', 'IP', 'PT', 'TP') THEN
            --- aplicable al interes -----------------------------------------------------
            IF v_dia_plazo < 365 THEN
              v_mto_mon_prestamo := round(v_mto_interes * v_dia_plazo * p_cargos(cc).val_tasa /
                                          36500,
                                          v_redondeo);
            ELSE
              v_mto_mon_prestamo := round(v_mto_interes * p_cargos(cc).val_tasa / 100,
                                          v_redondeo);
            END IF;
          END IF;
          IF v_aplicar IN ('CA', 'CI', 'PC', 'CP', 'PT', 'TP') THEN
            --- es aplicable al capital --------------------------------------------------
            IF p_cargos(cc).cod_ent_seguro IS NOT NULL THEN
              --- es un seguro ----------------------------------------------------------

              IF nvl(fug_obt_pardinamico('PRE_CAR_SEG_CAPITAL'), 'N') = 'S' THEN
                v_mto_mon_prestamo := ROUND(((P_MONTO * p_cargos(cc).val_tasa *
                                            v_dia_plazo) / 30) / 1000,
                                            v_redondeo);
              ELSE
                v_mto_mon_prestamo := NVL(v_mto_mon_prestamo, 0) +
                                      ROUND(p_tot_prestamo * p_cargos(cc).val_tasa / 100,
                                            v_redondeo);
              END IF;
            ELSE
              --- es un impuesto sobre el capital ---------------------------------------
              IF v_dia_plazo < 365 THEN
                v_mto_mon_prestamo := nvl(v_mto_mon_prestamo, 0) +
                                      round(p_tot_prestamo * v_dia_plazo * p_cargos(cc).val_tasa /
                                            36500,
                                            v_redondeo);
              ELSE
                v_mto_mon_prestamo := nvl(v_mto_mon_prestamo, 0) +
                                      round(p_tot_prestamo * p_cargos(cc).val_tasa / 100,
                                            v_redondeo);
              END IF;
            END IF;
          END IF;

          IF v_aplicar = 'MO' then
            --v_imp_cargo := 0;
            v_mto_mon_prestamo := NVL(v_mto_mon_prestamo, 0) +
                                  ROUND(p_monto * p_cargos(cc).VAL_TASA / 100,
                                        v_redondeo);
            --v_mto_mon_prestamo := v_imp_cargo + ROUND(p_cargos(cc).VAL_TASA * 10/100,v_redondeo);
          END IF;

          IF p_cargos(cc).COD_MONEDA = V_COD_MONEDA THEN
            -- moneda del cargo es igual a la moneda de la simulacion ----------------------
            V_MONTO := v_mto_mon_prestamo;
          ELSE
            -- monedas diferentes, se divide por la cotiz. de la moneda de la simulacion ---
            V_MONTO := ROUND(v_mto_mon_prestamo * v_cotizacion, v_redondeo);
          END IF;
        ELSIF v_tpvlpor = 'V' THEN
          --- es un monto valor -----------------------------------------------------------

          v_ttvalor          := nvl(v_ttvalor, 0) +
                                nvl(p_cargos(cc).mto_mon_prestamo, 0);
          v_mto_mon_prestamo := p_cargos(cc).mto_mon_prestamo;
          v_monto            := p_cargos(cc).mto_mon_prestamo;
        END IF;

        detalleCargos.COD_TRANSACCION := p_cargos(cc).cod_transaccion;
        detalleCargos.DES_TRANSACCION := p_cargos(cc).des_transaccion;
        detalleCargos.COD_ENT_SEGURO  := p_cargos(cc).cod_ent_seguro;
        detalleCargos.NOM_SEGURO      := p_cargos(cc).NOM_SEGURO;

        detalleCargos.val_tasa         := p_cargos(cc).val_tasa;
        detalleCargos.COD_MONEDA       := p_cargos(cc).cod_moneda;
        detalleCargos.COD_TASA         := p_cargos(cc).cod_tasa;
        detalleCargos.FEC_TASA         := p_cargos(cc).fec_tasa;
        detalleCargos.MONTO            := V_MONTO;
        detalleCargos.MTO_MON_PRESTAMO := v_mto_mon_prestamo;
        listacargos.extend;
        v_can_cargos := v_can_cargos + 1;
        listacargos(listaCargos.count) := detalleCargos;

        --- Acumular el total de cargos (Si el tipo es Valor viene directamente aqui -------
        v_mto_cargo := nvl(v_mto_cargo, 0) + nvl(v_mto_mon_prestamo, 0);
        ------------------------------------------------------------------------------------
      END LOOP;

      -- := listacargos;
      IF v_mto_cargo >= p_tot_prestamo THEN
        raise_application_error(-20000,
                                'ERROR. Total de Cargos ' || v_mto_cargo ||
                                ' es superior al Total del Prestamo ' ||
                                v_tot_prestamo);
      ELSE
        /*IF p_tip_monto = 'N' AND p_tot_prestamo <> p_monto THEN
          --- ya estoy en el ultimo calculo de cargos netos, veo si hay ajuste --------
          IF nvl(p_tot_prestamo, 0) - nvl(v_mto_cargo, 0) <>
             p_monto THEN
            -- es necesario un ajuste en el cargo del impuesto o primer cargo      ---
            v_dfcargos       := p_monto - (nvl(p_tot_prestamo, 0) -
                                 nvl(v_mto_cargo, 0));
            v_mto_mon_prestamo := NVL(v_mto_mon_prestamo,0) - v_dfcargos;

            v_mto_cargo       := nvl(v_mto_cargo, 0) - v_dfcargos;
          END IF;
        END IF;*/
        V_A_DESEMB := NVL(p_tot_prestamo, 0) - NVL(v_mto_cargo, 0);
        IF V_TIP_INTERES = 'A' THEN
          /* interes adelantado */
          V_A_DESEMB := NVL(V_A_DESEMB, 0) - NVL(V_MTO_INTERES, 0);
        END IF;
        p_cargos      := listacargos;
        p_ttvalor     := v_ttvalor;
        p_desembolsar := V_A_DESEMB;
        p_tot_cargo   := v_mto_cargo;
      END IF;

    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20000, 'CALCULAR_CARGOS ' || SQLERRM);
    END;
    --GENERAR CUOTAS---
  BEGIN
    --asignar fechas de acuerdo al dia de vto recibido.
    v_fec_actual := pag_cal.fu_obt_fec_actual(v_cod_modulo);
    /*v_var_fecha  := lpad(to_char(p_dia_vencimiento), 2, '0') || '/' ||
    to_char(to_date(v_fec_actual,'dd/mm/yyyy'), 'MM') || '/' ||
    to_char(to_date(v_fec_actual,'dd/mm/yyyy'), 'YYYY');*/
    v_var_fecha  := lpad(to_char(p_dia_vencimiento), 2, '0') || '/' ||
                    to_char(v_fec_actual, 'mm') || '/' ||
                    to_char(v_fec_actual, 'yyyy');
    v_fec_inicio := to_date(v_var_fecha, 'dd/mm/yyyy');
    --fecha de inicio no puede ser menor a la fecha actual, sumar un mes a la fecha de inicio
    if v_fec_inicio <= v_fec_actual then
      v_fec_inicio := add_months(v_fec_inicio, 1);
    end if;

    v_fec_pri_vencimiento := add_months(v_fec_inicio, 1);
    v_fec_vencimiento     := add_months(v_fec_pri_vencimiento,
                                        p_can_cuotas - 1);

    --recupero modalidad y tipo de monto de acuerdo al tipo de prestamo recibido
    v_cod_modalidad := fue_obt_val_max_referencia('PLA_TIP_PRESTAMO',
                                                  p_tip_prestamo);
    v_tip_monto     := fue_obt_des_refcodes('PLA_TIP_PRESTAMO',
                                            p_tip_prestamo);

    g_msj_error := ' ';
    g_cod_error := 0;

    if nvl(g_cod_error, 0) = 0 then
      -- Valido el codigo de la modalidad que recibo----------------------------
      pr_val_cod_modalidad;

      -- valido la moneda-------------------------------------------------------
      if nvl(g_cod_error, 0) = 0 then
        v_cod_moneda := fu_val_cod_moneda(upper(p_cod_moneda));
        v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                            v_cod_modulo,
                                            v_cod_modalidad,
                                            v_cod_moneda,
                                            v_cod_oficina);
      end if;

      if nvl(g_cod_error, 0) = 0 then
        IF nvl(p_monto, 0) <= 0 THEN
          g_cod_error := 1;
          g_lugar     := 'Valida Monto ingresado';
          g_msj_error := 'Ingrese Monto del Credito';
        END IF;
        if nvl(g_cod_error, 0) = 0 then
          IF nvl(p_can_cuotas, 0) <= 0 THEN
            g_cod_error := 1;
            g_lugar     := 'Valida Cantidad de Documentos';
            g_msj_error := 'Ingrese Cantidad de Documentos.';
          END IF;
        end if;
        --RECALCULAR CUOTAS
        if nvl(g_cod_error, 0) = 0 then
          -- raise_application_error(-20000,'v_fec_vencimiento '||v_fec_vencimiento);
          v_dia_plazo    := v_fec_vencimiento - v_fec_inicio;
          v_tot_prestamo := p_monto;
          --informacion de tasas de las pizarras
          pr_val_tasa;
        end if;

        --Cargos por defecto
        if nvl(g_cod_error, 0) = 0 then
          v_cargos := fu_obt_cargos;
        end if;
        --When validate cod_transaccion
        if nvl(g_cod_error, 0) = 0 then
          pr_obt_datos_cargo(v_cargos);
        end if;
        ---
        -- generar cuotas --------------------------------------------------------
        if nvl(g_cod_error, 0) = 0 then
          pr_gen_cuotas('N', p_mto_cuota);
        end if;
        -- Calculo los cargos ----------------------------------------------------
        if nvl(g_cod_error, 0) = 0 then
          pr_cal_cargos(v_tot_prestamo,
                        v_desembolsar,
                        v_tot_cargo,
                        v_ttvalor,
                        v_cargos);
        end if;
        if nvl(g_cod_error, 0) = 0 then
          -- verifico el tipo de prestamo
          IF v_tip_monto = 'B' THEN
            v_tot_prestamo := p_monto;
          ELSE
            --- monto ingresado es el neto -----------------------------------------------------
            v_por_ajuste := (p_monto - (v_tot_cargo - v_ttvalor)) * 100 /
                            (p_monto + v_ttvalor);
            --- calculo del nuevo capital (monto bruto -----------------------------------------
            v_tot_prestamo := round((p_monto * 100 / v_por_ajuste),
                                    v_redondeo);
            --- Vuelvo a generar las cuotas y calcular los cargos ------------------------------

            pr_gen_cuotas('S', p_mto_cuota);

          END IF;
        end if;
        ---
      else
        g_cod_error := '19';
        g_lugar     := 'Verifica Detalle Cheques';
        g_msj_error := 'No se encuentra el detalle de cheques.';
      end if;
    end if;
    if nvl(g_cod_error, 0) != 0 then
      p_error     := g_cod_error || ' - ' || g_msj_error;
      p_mto_cuota := 0;
    end if;

  EXCEPTION
    WHEN OTHERS THEN
      g_cod_error := '19';
      g_lugar     := 'Calcula Monto Cuota';
      g_msj_error := 'Error al calcular cuota' || sqlerrm;
      p_error     := g_cod_error || ' - ' || g_msj_error;
  END; --pr_cal_cuo_plataforma

  PROCEDURE pr_gen_sol_con_plataforma(p_cod_persona         IN VARCHAR2, -- codigo de la persona,
                                      p_tipo_prestamo       IN VARCHAR2, -- tipo de credito
                                      p_cod_moneda          IN VARCHAR2, -- moneda
                                      p_monto               IN NUMBER, -- monto del credito
                                      p_can_cuotas          IN NUMBER, -- nro de cuotas
                                      p_fec_pri_vencimiento IN DATE DEFAULT NULL, -- primer vencimiento
                                      p_nro_solicitud       OUT pr_solicitudes.nro_solicitud%TYPE,
                                      p_cod_error           OUT NUMBER, -- 0 = Exito
                                      p_msj_error           OUT VARCHAR2) IS
    ------------------ Variables del procedimiento -----------------------------
    v_dummy               NUMBER(9);
    v_cod_modulo          NUMBER(3) := 6; -- prestamos
    v_fec_actual          DATE := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
    v_cod_oficina         NUMBER(3) := fug_obt_pardinamico('COD_OFI_WERKING'); -- Codigo de oficina
    v_mon_local           VARCHAR2(3) := pag_gen.fu_obt_mon_local;
    v_cotizacion          ge_cotizaciones.val_conversion%TYPE := pag_gen.fu_obt_cotizacion(p_cod_moneda);
    v_lugar               VARCHAR2(200) := NULL;
    v_exo_impuestos       VARCHAR2(1) := 'N';
    v_cod_usu_oficial     VARCHAR2(10);
    v_tot_prestamo        NUMBER(18, 2) := 0; -- total del prestamo
    v_mto_interes         NUMBER(18, 2) := 0; -- total de interes
    v_mto_cargo           NUMBER(18, 2) := 0;
    v_fec_inicio          DATE;
    v_fec_pri_vencimiento DATE := p_fec_pri_vencimiento;
    v_fec_vencimiento     DATE := add_months(v_fec_pri_vencimiento,
                                             p_can_cuotas - 1);
    v_cod_sec_credito     NUMBER(3) := 701; -- OJO!!!. ver que valor tendra
    v_cod_rub_economico   VARCHAR2(6) := '970108'; ----- OJO!!!. ver que valor tendra
    v_cod_departamento    NUMBER(3) := NULL; -- Se obtiene de los datos del cliente o en su defecto de la oficina
    v_cod_dep_parametro   NUMBER(3) := NULL; -- Departamento de Parametros
    --v_tip_interes         VARCHAR2(1) := 'V';
    v_tip_amortizacion VARCHAR2(1) := 'P';
    --v_aju_ult_cuota       VARCHAR2(1) := 'N';
    --v_tip_aju_fecha       VARCHAR2(1) := 'E';
    --v_aju_gracia          VARCHAR2(1) := 'N';
    v_tip_documento NUMBER(1) := 1;
    --v_tipo                VARCHAR2(1) := 'A';
    v_cod_usu_promotor VARCHAR2(10);
    v_val_tasa         NUMBER;
    v_dia_plazo        NUMBER(8);
    v_per_gracia       NUMBER(8);
    v_per_vencimiento  NUMBER(4) := 30;
    v_per_capital      pr_solicitudes.per_vto_capital%TYPE;
    v_nro_solicitud    NUMBER(10);
    v_por_ajuste       NUMBER;
    v_ttvalor          NUMBER(18, 2);
    --v_nro_cuenta          VARCHAR2(15);
    --v_cantidad            NUMBER(3);
    --v_tip_destino         pr_solicitudes.tip_destino%TYPE;
    v_cod_canal      pr_solicitudes.cod_canal%TYPE;
    v_cod_campana    pr_solicitudes.cod_campana%TYPE;
    v_cod_banca      pr_solicitudes.cod_banca%TYPE;
    v_nro_cta_debito pr_solicitudes.nro_cta_debito%TYPE;
    -- Datos de los cargos -----------------------------------------------------
    v_cod_transaccion NUMBER(4);
    v_cod_tas_cargo   NUMBER(4);
    v_val_tas_cargo   NUMBER;
    v_cod_mon_cargo   VARCHAR2(3);
    v_tpvlpor         VARCHAR2(1);
    v_aplicar         VARCHAR2(3);
    v_tpdetas         VARCHAR2(1);
    v_val_cargo       NUMBER(18, 2);
    v_cod_ent_seguro  NUMBER(6);
    v_cod_garantia    NUMBER(3);
    v_can_codeudor    NUMBER(3);
    v_mon_garantia    NUMBER(18, 2);
    -- control del redondeo ----------------------------------------------------
    v_redondeo  NUMBER(2) := 0; -- redondeo a cero para moneda local
    v_limite    NUMBER := 10; -- limite superior para ajustes de cuotas iguales en moneda local
    v_ori_fondo NUMBER;
    --rg_cta_prestamo pr_cta_prestamos%ROWTYPE;
    --p_cargo         NUMBER;
    --p_seguro        NUMBER;
    --v_monto_total   NUMBER;
    --DA-990
    v_cod_modalidad  pr_cta_prestamos.cod_modalidad%TYPE;
    v_tip_monto      varchar(1);
    p_descripcion    varchar2(100) := 'SOLICITUD - PLATAFORMA';
    p_nro_cuenta     ge_cuentas.nro_cuenta%TYPE := null;
    p_nro_referencia ge_solicitudes.nro_solicitud%TYPE := null;
    g_lugar          VARCHAR2(250);
    g_msj_error      VARCHAR2(4000); --(250);
    g_cod_error      NUMBER(3) DEFAULT 0;
    ------------------ rutinas internas del procedimiento-----------------------
    CURSOR sol_destino(p_nro_cuenta VARCHAR2) IS
      SELECT sd.tip_des_especifico, sd.monto
        FROM pr_sol_destinos sd, pr_cta_prestamos cp
       WHERE cp.nro_solicitud = sd.nro_solicitud
         AND cp.nro_cuenta = p_nro_cuenta;

    CURSOR sol_garantia IS
      SELECT nro_solicitud, cod_persona
        FROM ge_sol_codeudores g
       where g.nro_solicitud = p_nro_referencia;

    PROCEDURE pr_val_tasa IS
      CURSOR pizarras IS
        SELECT a.tas_interes, a.tas_minima, a.tas_maxima
          FROM cr_piz_montos b, cr_piz_plazos a
         WHERE a.cod_modulo = v_cod_modulo
           AND a.cod_modalidad = v_cod_modalidad
           AND a.cod_moneda = p_cod_moneda
           AND b.cod_modulo = a.cod_modulo
           AND b.cod_modalidad = a.cod_modalidad
           AND b.cod_moneda = a.cod_moneda
           AND b.mto_desde = a.mto_desde
           AND p_monto BETWEEN b.mto_desde AND b.mto_hasta
           AND v_dia_plazo BETWEEN a.plz_desde AND a.plz_hasta;
      v_tas_interes NUMBER;
      v_tas_minima  NUMBER;
      v_tas_maxima  NUMBER;
    BEGIN
      v_lugar := 'obtener_tasas de pizarras';
      OPEN pizarras;
      FETCH pizarras
        INTO v_tas_interes, v_tas_minima, v_tas_maxima;
      CLOSE pizarras;
      IF v_val_tasa IS NULL THEN
        v_val_tasa := v_tas_interes;
      ELSE
        -- valido la tasa ingresada---
        IF NOT v_val_tasa BETWEEN v_tas_minima AND v_tas_maxima THEN
          --raise_application_error(-20000, 'ERROR. Tasa fuera de Rango. Verifique la Pizarra');
          g_lugar     := v_lugar;
          g_cod_error := 10;
          g_msj_error := 'Tasa fuera de Rango .Tasa' || v_val_tasa;
        END IF;
      END IF;
    END;
    -- Verificacion del codigo del cliente--------------------------------------
    PROCEDURE pr_val_cod_persona IS
    BEGIN
      v_lugar := 'OBTENER_CLIENTE ';
      SELECT exo_impuestos,
             cod_usu_oficial,
             cod_usu_promotor,
             cod_oficina,
             cod_departamento
        INTO v_exo_impuestos,
             v_cod_usu_oficial,
             v_cod_usu_promotor,
             v_cod_oficina,
             v_cod_departamento
        FROM ba_personas b, ge_clientes g
       WHERE b.cod_persona = g.cod_persona
         AND g.cod_persona = p_cod_persona;
    EXCEPTION
      WHEN no_data_found THEN
        -- Comentado por Ingrid Larrain 01/07/2004 y modificado para casos de generacion
        -- de solicitud
        BEGIN
          SELECT gen.cod_ofi_matriz, 'N', ciu.cod_departamento
            INTO v_cod_oficina, v_exo_impuestos, v_cod_departamento
            FROM ge_par_generales gen, ba_oficinas ofi, ba_ciudades ciu
           WHERE gen.cod_ofi_matriz = ofi.cod_oficina
             AND ofi.cod_ciudad = ciu.cod_ciudad
             AND ofi.cod_pais = ciu.cod_pais;
        END;
        ---    RAISE_APPLICATION_ERROR(-20000,'ERROR. Cliente no esta definido en el Sistema');
      WHEN OTHERS THEN
        g_lugar     := 'pr_val_cod_persona';
        g_cod_error := 1;
        g_msj_error := 'Error al validar la persona ' || p_cod_persona;
        --raise_application_error(-20000, 'pr_val_cod_persona ' || SQLERRM);
    END;
    -- Validacion del tipo de credito---------------------------------------------
    PROCEDURE pr_val_cod_modalidad IS
    BEGIN
      SELECT 0
        INTO v_dummy
        FROM ge_modalidades
       WHERE cod_modulo = v_cod_modulo
         AND cod_modalidad = v_cod_modalidad;
    EXCEPTION
      WHEN no_data_found THEN
        g_lugar     := 'pr_val_cod_modalidad';
        g_cod_error := 2;
        g_msj_error := 'Tipo de Prestamo no habilitado. Modalidad ' ||
                       v_cod_modalidad;
        /*raise_application_error(-20000,
        'ERROR. Tipo de Prestamo no habilitado. Modalidad ' ||
        v_cod_modalidad);*/
      WHEN OTHERS THEN
        g_lugar     := 'pr_val_cod_modalidad';
        g_cod_error := 3;
        g_msj_error := 'Validar Modalidad ' || v_cod_modalidad;

      /*raise_application_error(-20000,
      'ERROR: Validar Modalidad ' || SQLERRM);*/
    END;
    -- Validacion del codigo de la moneda-----------------------------------------
    PROCEDURE pr_val_cod_moneda IS
    BEGIN
      SELECT 0
        INTO v_dummy
        FROM ba_monedas
       WHERE cod_moneda = p_cod_moneda;
    EXCEPTION
      WHEN no_data_found THEN
        --raise_application_error(-20000, 'ERROR. Codigo de Moneda inexistente');
        g_lugar     := 'pr_val_cod_moneda';
        g_cod_error := 4;
        g_msj_error := 'Codigo de Moneda inexistente ' || p_cod_moneda;

      WHEN OTHERS THEN
        --raise_application_error(-20000, 'ERROR: Valida moneda ' || SQLERRM);
        g_lugar     := 'pr_val_cod_moneda';
        g_cod_error := 5;
        g_msj_error := 'Valida moneda ' || p_cod_moneda;
    END;
    -- Procedimiento para obtener el tipo de tasa --------------------------------
    PROCEDURE pr_obt_tipo_de_tasa(ww_cdtrans IN NUMBER,
                                  ww_cddetas IN OUT NUMBER,
                                  ww_aplicar IN OUT VARCHAR2,
                                  ww_tpvlpor IN OUT VARCHAR2,
                                  ww_tpdetas IN OUT VARCHAR2) IS
    BEGIN
      v_lugar := 'OBTENER TIPO DE TASA ';
      --- 1. Busco la tasa asociada a la transaccion ingresada ---
      SELECT tr.cod_tasa, ta.aplicar, ta.tip_valor, ta.tipo
        INTO ww_cddetas, ww_aplicar, ww_tpvlpor, ww_tpdetas
        FROM ge_transacciones tr, ge_tasas ta
       WHERE tr.cod_modulo = v_cod_modulo
         AND tr.cod_modalidad = v_cod_modalidad
         AND tr.cod_transaccion = ww_cdtrans
         AND tr.tipo = 'D'
         AND tr.cod_tasa IS NOT NULL
         AND tr.cod_tasa = ta.cod_tasa
         AND EXISTS (SELECT 0
                FROM ge_transacciones_det
               WHERE cod_modulo = v_cod_modulo
                 AND cod_modalidad = v_cod_modalidad
                 AND cod_transaccion = 358 /* transaccion de desembolso de prestamos */
                 AND cod_mod_hijo = tr.cod_modulo
                 AND cod_mad_hijo = tr.cod_modalidad
                 AND cod_tra_hijo = tr.cod_transaccion);

    EXCEPTION
      WHEN no_data_found THEN
        raise_application_error(-20000,
                                'ERROR: Cargo no definido para Prestamos ');
      WHEN OTHERS THEN
        raise_application_error(-20000, 'ERROR: OBT_TIPO_TASA ' || SQLERRM);
    END;
    -- Funcion que obtiene el valor de la tasa fija ------------------------------
    FUNCTION fu_obt_valor_de_tasa_fija(ww_cddetas IN NUMBER,
                                       ww_fcinici IN DATE) RETURN NUMBER IS
      ww_vldetas NUMBER(15, 2);
    BEGIN
      v_lugar := 'OBTENER VALOR DE TASA FIJA ';
      -- tasa fija, buscar en tasa por fecha ---
      SELECT val_tasa
        INTO ww_vldetas
        FROM ge_tas_fechas f1
       WHERE f1.cod_tasa = ww_cddetas
         AND (f1.cod_modalidad IS NULL OR
             (f1.cod_modalidad = v_cod_modalidad))
         AND (f1.cod_modulo IS NULL OR (f1.cod_modulo = v_cod_modulo))
         AND (f1.cod_moneda IS NULL OR (f1.cod_moneda = p_cod_moneda))
         AND (f1.cod_oficina IS NULL OR (f1.cod_oficina = v_cod_oficina))
         AND f1.nro_cuenta IS NULL
         AND f1.fec_vigencia =
             (SELECT MAX(fec_vigencia)
                FROM ge_tas_fechas f2
               WHERE f1.cod_tasa = f2.cod_tasa
                 AND (f2.cod_modalidad IS NULL OR
                     (f2.cod_modalidad = v_cod_modalidad))
                 AND (f2.cod_modulo IS NULL OR
                     (f2.cod_modulo = v_cod_modulo))
                 AND (f2.cod_moneda IS NULL OR
                     (f2.cod_moneda = p_cod_moneda))
                 AND (f2.cod_oficina IS NULL OR
                     (f2.cod_oficina = v_cod_oficina))
                 AND f2.fec_vigencia <= ww_fcinici
                 AND f2.nro_cuenta IS NULL);
      RETURN ww_vldetas;
    EXCEPTION
      WHEN no_data_found THEN
        RETURN NULL;
      WHEN OTHERS THEN
        raise_application_error(-20000, 'obt_tasa_fija ' || SQLERRM);
    END;
    -- Funcion que devuelve el valor de la tasa, si es variable ------------------
    FUNCTION fu_obt_valor_de_tasa_variable(ww_cddetas IN NUMBER,
                                           ww_vlmonto IN NUMBER,
                                           ww_fcinici IN DATE) RETURN NUMBER IS
      ww_vldetas NUMBER(15, 2);
      CURSOR tv IS
        SELECT tr.val_tasa
          FROM ge_tasas t, ge_tas_rangos tr
         WHERE t.cod_tasa = tr.cod_tasa
           AND t.cod_tasa = ww_cddetas
           AND (tr.cod_modulo = v_cod_modulo OR tr.cod_modulo IS NULL)
           AND (tr.cod_modalidad = v_cod_modalidad OR
               tr.cod_modalidad IS NULL)
           AND (tr.cod_moneda = p_cod_moneda OR tr.cod_moneda IS NULL)
           AND (tr.cod_oficina = v_cod_oficina OR tr.cod_oficina IS NULL)
           AND tr.val_hasta >= ww_vlmonto
           AND tr.nro_cuenta IS NULL
           AND tr.fec_vigencia =
               (SELECT MAX(tra.fec_vigencia)
                  FROM ge_tas_rangos tra
                 WHERE tra.cod_tasa = ww_cddetas
                   AND (tra.cod_modulo = v_cod_modulo OR
                       tra.cod_modulo IS NULL)
                   AND (tra.cod_modalidad = v_cod_modalidad OR
                       tra.cod_modalidad IS NULL)
                   AND (tra.cod_moneda = p_cod_moneda OR
                       tra.cod_moneda IS NULL)
                   AND (tra.cod_oficina = v_cod_oficina OR
                       tra.cod_oficina IS NULL)
                   AND tra.val_hasta >= ww_vlmonto
                   AND tra.nro_cuenta IS NULL
                   AND tra.fec_vigencia <= ww_fcinici)
         ORDER BY val_hasta;
    BEGIN
      v_lugar := 'OBTENER VALOR DE TASA VARIABLE ';
      -- tasa variable, buscar en tabla de tasas variables ---
      OPEN tv;
      FETCH tv
        INTO ww_vldetas;
      CLOSE tv;
      IF ww_vldetas IS NULL THEN
        raise_application_error(-20000,
                                'No existe Valor para la Tasa ' ||
                                to_char(ww_cddetas) || ' y el Monto ' ||
                                to_char(ww_vlmonto) || ' Fecha ' ||
                                to_char(ww_fcinici, 'DD/MM/YYYY'));
      END IF;
      RETURN ww_vldetas;
    EXCEPTION
      WHEN no_data_found THEN
        RETURN NULL;
      WHEN OTHERS THEN
        IF SQLCODE <= -20000 THEN
          RAISE;
        ELSE
          raise_application_error(-20000, 'obt_tasa_variable ' || SQLERRM);
        END IF;
    END;
    -- Verificacion del codigo de tasa--------------------------------------------
    PROCEDURE pr_obt_datos_cargo IS
    BEGIN

      -- obtengo los datos de la tasa-----------------
      pr_obt_tipo_de_tasa(v_cod_transaccion,
                          v_cod_tas_cargo,
                          v_aplicar,
                          v_tpvlpor,
                          v_tpdetas);

      --- la tasa es de tipo  valor ---
      IF v_tpdetas = 'F' THEN
        --- tipo de tasa fijo      ---
        v_val_tas_cargo := fu_obt_valor_de_tasa_fija(v_cod_tas_cargo,
                                                     v_fec_inicio);
      ELSE
        --- tipo de tasa variable  ---
        IF v_aplicar IN ('PI', 'PC', 'PT', 'PL', 'CP', 'IP', 'TP') THEN
          IF v_aplicar IN ('PI', 'PC', 'PT', 'PL') THEN
            --- El primer rango es por plazo
            v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_cod_tas_cargo,
                                                             v_dia_plazo,
                                                             v_fec_inicio);
          ELSE
            --- tipo de tasa variable  ---
            v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_cod_tas_cargo,
                                                             nvl(v_tot_prestamo,
                                                                 p_monto),
                                                             v_fec_inicio);
          END IF;
          IF v_aplicar IN ('CP', 'IP', 'TP') THEN
            -- aplicar al capital y plazo, busco ahora el valor por plazo
            v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_val_tas_cargo,
                                                             v_dia_plazo,
                                                             v_fec_inicio);

          END IF;
        ELSE
          v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_cod_tas_cargo,
                                                           nvl(v_tot_prestamo,
                                                               p_monto),
                                                           v_fec_inicio);
        END IF;

      END IF;
      IF v_tpvlpor IN ('I', 'P') OR v_cod_transaccion IN (735, 736) THEN
        --- porcentajes  o transacciones de seguros  ---
        v_cod_mon_cargo := v_mon_local;
      ELSE
        --- en caso de que sean valores ----------------
        v_cod_mon_cargo := p_cod_moneda;
        v_val_cargo     := v_val_tas_cargo;
        v_val_tas_cargo := NULL;
      END IF;
    END;

    -- Carga de cargos de la propuesta-------------------------------------------
    PROCEDURE pr_gen_cargos IS
      v_cod_tip_canal ge_tip_canales.cod_tip_canal%TYPE;
      --
      CURSOR cargos IS
        SELECT DISTINCT decode(a.cod_transaccion,
                               709,
                               1,
                               710,
                               2,
                               a.cod_transaccion) orden, -- solo para ordenamiento
                        a.cod_transaccion,
                        a.cod_ent_seguro,
                        nvl(b.obligatorio, 'N') obligator
          FROM ge_sol_cargos a, ge_transacciones_det b
         WHERE a.cod_transaccion = b.cod_tra_hijo(+)
           AND a.cod_modulo = b.cod_mod_hijo(+)
           AND a.cod_modalidad = b.cod_mad_hijo(+)
           AND a.cod_modulo = v_cod_modulo
           AND a.cod_modalidad = v_cod_modalidad
           AND ((nvl(v_exo_impuestos, 'N') = 'N') OR
               (nvl(v_exo_impuestos, 'N') = 'S' AND
               nvl(b.obligatorio, 'N') = 'N'))
           AND (a.cod_canal = v_cod_canal OR
               (a.cod_canal IS NULL AND NOT EXISTS
                (SELECT '1' FROM ge_sol_cargos WHERE cod_canal = v_cod_canal)))
           AND (a.cod_tip_canal = v_cod_tip_canal OR
               (a.cod_tip_canal IS NULL AND NOT EXISTS
                (SELECT '1'
                    FROM ge_sol_cargos
                   WHERE cod_tip_canal = v_cod_tip_canal)))
           AND (a.cod_campana = v_cod_campana OR
               (a.cod_campana IS NULL AND NOT EXISTS
                (SELECT '1'
                    FROM ge_sol_cargos
                   WHERE cod_campana = v_cod_campana)))
         ORDER BY 1;
    BEGIN
      IF v_cod_canal IS NOT NULL THEN
        SELECT cod_tip_canal
          INTO v_cod_tip_canal
          FROM ge_canales
         WHERE cod_canal = v_cod_canal;
      END IF;
      FOR cc IN cargos LOOP
        v_cod_transaccion := cc.cod_transaccion;
        v_cod_ent_seguro  := cc.cod_ent_seguro;
        v_val_tas_cargo   := NULL;
        v_val_cargo       := NULL;
        v_cod_tas_cargo   := NULL;
        v_cod_mon_cargo   := NULL;
        pr_obt_datos_cargo;
        IF cc.obligator = 'S' OR nvl(v_val_cargo, 0) != 0 OR
           nvl(v_val_tas_cargo, 0) != 0 THEN
          INSERT INTO pr_sol_cargos
            (nro_solicitud,
             cod_transaccion,
             fec_tasa,
             val_tasa,
             monto,
             cod_tasa,
             cod_ent_seguro,
             cod_moneda,
             mto_mon_prestamo)
          VALUES
            (v_nro_solicitud,
             v_cod_transaccion,
             v_fec_inicio,
             v_val_tas_cargo,
             v_val_cargo,
             v_cod_tas_cargo,
             cc.cod_ent_seguro,
             v_cod_mon_cargo,
             NULL);
        END IF;
      END LOOP;
    END;
    -- Generacion de cuotas -----------------------------------------------------
    PROCEDURE pr_gen_cuotas(ww_neto IN VARCHAR2) IS
      ww_diavenc         VARCHAR2(02);
      ww_frances         NUMBER;
      ww_tasadiv         NUMBER := v_val_tasa / 36500;
      ww_vlsalan         NUMBER(18, 2) := v_tot_prestamo;
      ww_ttcuota         NUMBER(18, 2) := NULL;
      ww_dfcuota         NUMBER(18, 2);
      ww_ttcapit         NUMBER(18, 2) := 0;
      ww_ttrefue         NUMBER(18, 2) := 0;
      ww_refreal         NUMBER(18, 2) := 0;
      ww_ctrefue         NUMBER(6) := 0;
      ww_nro             NUMBER(6) := 0;
      ww_veces           NUMBER(3) := 0;
      v_val_int_original NUMBER(18, 2) := 0;
      --
      v_fec_vto_habil     DATE;
      v_fec_vto_exacto    DATE;
      v_fec_vto_habil_ant DATE;
      v_fec_vcto          DATE;
      v_fec_vto_anterior  DATE := v_fec_inicio;
      v_sal_cap_anterior  NUMBER(18, 2);
      v_dia_perioro       NUMBER(6);
      v_dia_interes       NUMBER(6);
      v_val_interes       NUMBER(18, 2);
      v_ttcuota           NUMBER(18, 2);
      v_dia_periodo       NUMBER(8);
      v_mto_capital       NUMBER(18, 2);
      v_ven_fijo          VARCHAR2(1) := 'S';
      ww_ant_ven_fijo     VARCHAR2(1) := v_ven_fijo;
      v_per_interes       NUMBER := 30;
      v_val_cuota         NUMBER;
      -------

      ww_redondeo        number(2) := 0; -- redondeo a cero para moneda local
      ww_limite          number := 10; -- limite superior para ajustes de cuotas iguales en moneda local
      v_dias             number;
      v_fec_ven_anterior date;

    BEGIN

      --- Veo el tipo de redondeo de los calculos ------------------------------------------
      ww_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                         V_cod_modulo,
                                         v_cod_modalidad,
                                         p_cod_moneda,
                                         v_cod_oficina);
      If ww_redondeo != 0 then
        ww_limite := 0.05;
      else
        ww_limite := 1;
      End If;

      If v_ven_fijo is null then
        v_ven_fijo := 'S';
      End if;
      ---
      if v_per_interes = 30 and v_ven_fijo = 'S' then
        v_dias := 30.416666666666666666666666666667;
      else
        v_dias := v_per_interes;
      end if;

      LOOP
        v_fec_ven_anterior := v_fec_inicio;
        ww_veces           := NVL(ww_veces, 0) + 1;

        --- calculo del valor del metodo frances -----------------------------
        IF (power((1 + (ww_tasadiv * v_dias)), (p_can_cuotas - ww_ctrefue)) - 1) > 0 THEN
          ww_frances := ((NVL(nvl(v_tot_prestamo, p_monto), 0) -
                        NVL(ww_ttrefue, 0)) * ww_tasadiv * v_dias) /
                        (power((1 + (ww_tasadiv * v_dias)),
                               (p_can_cuotas - ww_ctrefue)) - 1);

        ELSE
          --- Para los casos en que la tasa = 0 para que no de division por cero.
          ww_frances := ((NVL(v_tot_prestamo, 0) - NVL(ww_ttrefue, 0))) /
                        ((p_can_cuotas - ww_ctrefue));
        END IF;

        --- Veo el monto fijo de cuota si es de tipo Prestamos flexibles -----
        ----------------------------------------------------------------------
        v_mto_interes := 0;
        ww_vlsalan    := V_TOT_PRESTAMO;
        ww_ttcapit    := 0;
        ww_refreal    := 0;
        ww_nro        := 0; /* acumulador de cuotas calculadas automaticamente, sin refuerzo */
        -- borro las cuotas si existen
        DELETE FROM pr_sol_cuotas WHERE nro_solicitud = v_nro_solicitud;
        FOR cuota IN 1 .. p_can_cuotas LOOP
          if cuota = 1 then
            v_fec_vto_habil  := p_fec_pri_vencimiento;
            v_fec_vto_exacto := p_fec_pri_vencimiento;
          else
            if v_per_interes = 30 then
              -- Sumo 1 mes...
              If v_ven_fijo = 'S' then
                v_fec_vcto := ADD_MONTHS(p_fec_pri_vencimiento, (cuota - 1));
              Else
                v_fec_vcto := p_fec_pri_vencimiento +
                              (((cuota - 1) * v_dias));
              End if;
              V_FEC_VTO_HABIL_ANT := v_fec_vcto;
              V_FEC_VTO_HABIL     := v_fec_vcto;
            else
              V_FEC_VTO_HABIL := p_fec_pri_vencimiento +
                                 (((cuota - 1) * v_dias));
            end if;
            V_FEC_VTO_EXACTO := p_fec_pri_vencimiento +
                                (((cuota - 1) * v_dias));
          end if;
          V_SAL_CAP_ANTERIOR := ww_vlsalan;
          IF CUOTA = 1 AND
             ABS(30 - (p_fec_pri_vencimiento - v_fec_inicio)) > 0 THEN
            /* se hace el calculo del interes por el plazo del periodo de gracia */
            V_DIA_PERIODO := p_fec_pri_vencimiento - v_fec_inicio;
            V_DIA_INTERES := p_fec_pri_vencimiento - v_fec_inicio;
            V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv * v_dias /*V_DIA_INTERES*/
                                   ),
                                   ww_redondeo);
            v_val_cuota   := null;
          ELSE
            if fug_obt_tip_entidad != 'F' then
              V_DIA_PERIODO := V_FEC_VTO_HABIL - v_Fec_ven_anterior;
              V_DIA_INTERES := V_FEC_VTO_HABIL - v_Fec_ven_anterior;
              V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv * v_dias /*v_dia_interes*/
                                     ),
                                     ww_redondeo);
            else
              V_DIA_PERIODO := v_per_interes;
              V_DIA_INTERES := v_per_interes;
              V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv * v_dias),
                                     ww_redondeo);
            end if;
          END IF;

          IF v_val_int_original > 0 THEN
            /* es una cuota con refuerzo */
            IF ww_neto = 'S' THEN
              V_MTO_CAPITAL := V_MTO_CAPITAL;
            ELSE
              V_MTO_CAPITAL := V_VAL_INT_ORIGINAL - V_VAL_INTERES;
            END IF;
            ww_refreal  := NVL(ww_refreal, 0) + NVL(V_MTO_CAPITAL, 0);
            v_val_cuota := null;
          ELSE
            ww_nro := ww_nro + 1;
            if v_val_cuota is not null and fug_obt_tip_entidad != 'F' then
              V_MTO_CAPITAL := v_val_cuota - V_VAL_INTERES;
            else
              V_MTO_CAPITAL := ROUND((ww_frances *
                                     power((1 + (ww_tasadiv * v_dias)),
                                            (ww_nro - 1))),
                                     ww_redondeo);
            end if;
            v_val_cuota := V_MTO_CAPITAL + V_VAL_INTERES;
          END IF;
          V_VAL_INT_ORIGINAL := NVL(V_VAL_INT_ORIGINAL, 0);
          V_TTCUOTA          := NVL(V_MTO_CAPITAL, 0) +
                                NVL(V_VAL_INTERES, 0);
          ww_dfcuota         := NVL(ww_ttcuota, V_TTCUOTA) -
                                NVL(V_TTCUOTA, 0);
          -- ajuste de cuotas para que sean iguales solo se hace si esta dentro del limite
          IF (ABS(ww_dfcuota) BETWEEN 0.001 AND ww_limite) THEN
            V_VAL_INTERES := V_VAL_INTERES + ww_dfcuota;
            V_TTCUOTA     := V_TTCUOTA + ww_dfcuota;
          END IF;
          ww_ttcuota         := V_TTCUOTA;
          ww_vlsalan         := NVL(ww_vlsalan, 0) - V_MTO_CAPITAL;
          ww_ttcapit         := NVL(ww_ttcapit, 0) + NVL(V_MTO_CAPITAL, 0);
          V_MTO_INTERES      := V_MTO_INTERES + NVL(V_VAL_INTERES, 0);
          v_fec_ven_anterior := V_FEC_VTO_HABIL;
          IF NVL(V_MTO_CAPITAL, 0) < 0 or NVL(V_VAL_INTERES, 0) < 0 THEN
            --raise_application_error(-20000, 'ERROR. Capital o Interes no puede quedar en negativo. Verifique');
            g_lugar     := 'pr_gen_cuotas';
            g_cod_error := 11;
            g_msj_error := 'Capital o Interes no puede quedar en negativo. Verifique';
          END IF;
          -- inserto el registro en la tabla de cuotas
          INSERT INTO pr_sol_cuotas
            (nro_solicitud,
             nro_cuota,
             mto_capital,
             fec_vto_habil,
             fec_vto_exacto,
             val_interes,
             sal_capital,
             sal_cap_anterior,
             dia_periodo,
             dia_transcurridos,
             dia_interes,
             tip_calculo,
             val_int_original,
             val_int_adelantado)
          VALUES
            (v_nro_solicitud,
             cuota,
             nvl(v_mto_capital, 0),
             v_fec_vto_habil,
             v_fec_vto_exacto,
             nvl(v_val_interes, 0),
             ww_vlsalan,
             ww_vlsalan + v_mto_capital,
             v_dia_periodo,
             v_dia_periodo,
             v_dia_interes,
             'V',
             v_val_int_original,
             0);

        END LOOP;

        IF abs(nvl(ww_refreal, 0) - nvl(ww_ttrefue, 0)) < 10 OR
           ww_veces > 12 OR v_tip_monto = 'N' THEN
          EXIT;
        END IF;

      END LOOP;

      ww_dfcuota := nvl(V_TOT_PRESTAMO, 0) - NVL(ww_ttcapit, 0);
      IF ww_dfcuota <> 0 THEN
        V_MTO_CAPITAL := V_MTO_CAPITAL + ww_dfcuota;
        IF NVL(V_VAL_INTERES, 0) >= ww_dfcuota and abs(ww_dfcuota) <= 1 THEN
          /* solo se ajusta si existe interes*/
          V_VAL_INTERES := NVL(V_VAL_INTERES, 0) - ww_dfcuota;
          V_MTO_INTERES := V_MTO_INTERES - ww_dfcuota;
        ELSE
          V_TTCUOTA := NVL(V_MTO_CAPITAL, 0) + NVL(V_VAL_INTERES, 0);
        END IF;
        -- Actualizo la ultima cuota
        UPDATE pr_sol_cuotas
           SET mto_capital = nvl(v_mto_capital, 0),
               val_interes = nvl(v_val_interes, 0)
         WHERE nro_solicitud = v_nro_solicitud
           AND nro_cuota = p_can_cuotas; -- ultima cuota
      END IF;
      -- vencimiento final del prestamo es igual al de la ult.cuota--
      UPDATE pr_solicitudes
         SET fec_vencimiento = v_fec_vto_habil, mto_interes = v_mto_interes
       WHERE nro_solicitud = v_nro_solicitud;
      ---------------------------------------------------------
    EXCEPTION
      WHEN OTHERS THEN
        --raise_application_error(-20000, 'GENERACION_CUOTAS ' || SQLERRM);
        g_lugar     := 'pr_gen_cuotas';
        g_cod_error := 12;
        g_msj_error := 'GENERACION_CUOTAS ' || SQLERRM;
    END;
    -- Calculo de los cargos ----------------------------------------------------
    PROCEDURE pr_cal_cargos IS
      ww_dfcargos       NUMBER(18, 2);
      v_mto_equivalente NUMBER(18, 2);
      v_cod_tra_ajuste  NUMBER(4);
      v_monto           NUMBER(18, 2);
      CURSOR cargos IS
        SELECT cod_transaccion,
               cod_tasa,
               cod_ent_seguro,
               val_tasa,
               monto,
               cod_moneda,
               mto_mon_prestamo
          FROM pr_sol_cargos
         WHERE nro_solicitud = v_nro_solicitud
           FOR UPDATE OF monto
         ORDER BY decode(cod_transaccion, 709, 1, 710, 2, cod_transaccion);
    BEGIN
      --- Calculo cada uno de los cargos en la moneda del cargo y en la de la simulacion ---
      --- cero los totales de cargo de tipo valor y el total general de cargos -------------
      v_ttvalor        := 0;
      v_mto_cargo      := 0;
      v_cod_tra_ajuste := NULL;
      FOR cc IN cargos LOOP
        v_mto_equivalente := 0;
        -- para realizar ajustes si es necesario----------
        IF v_cod_tra_ajuste IS NULL THEN
          v_cod_tra_ajuste := cc.cod_transaccion;
        END IF;
        -- obtengo los datos de la tasa-----------------
        pr_obt_tipo_de_tasa(cc.cod_transaccion,
                            cc.cod_tasa,
                            v_aplicar,
                            v_tpvlpor,
                            v_tpdetas);
        IF cc.cod_transaccion IS NOT NULL AND
           (cc.cod_moneda IS NULL OR
           (v_tpvlpor = 'V' AND nvl(cc.monto, 0) = 0)) THEN
          /*raise_application_error(-20000,
          'Valores nulos en Cargos. Verificar la Trans. ' ||
           to_char(cc.cod_transaccion));*/
          g_lugar     := 'pr_cal_cargos';
          g_cod_error := 13;
          g_msj_error := 'Valores nulos en Cargos. Verificar la Trans. ' ||
                         to_char(cc.cod_transaccion);
        END IF;
        IF v_tpvlpor = 'P' THEN
          v_mto_equivalente := 0;
          --- la tasa es un porcentaje-----------------------------------------------------
          IF v_aplicar IN ('CI', 'IN', 'PI', 'IP', 'PT', 'TP') THEN
            --- aplicable al interes -----------------------------------------------------
            v_mto_equivalente := round(v_mto_interes * cc.val_tasa / 100,
                                       v_redondeo);
          END IF;
          IF v_aplicar IN ('CA', 'CI', 'PC', 'CP', 'PT', 'TP') THEN
            --- es aplicable al capital --------------------------------------------------
            v_mto_equivalente := nvl(v_mto_equivalente, 0) +
                                 round(v_tot_prestamo * cc.val_tasa / 100,
                                       v_redondeo);
          END IF;
        ELSIF v_tpvlpor = 'I' THEN
          v_mto_equivalente := 0;
          --- la tasa es un impuesto ------------------------------------------------------
          IF v_aplicar IN ('CI', 'IN', 'PI', 'IP', 'PT', 'TP') THEN
            --- aplicable al interes -----------------------------------------------------
            IF v_dia_plazo < 365 THEN
              v_mto_equivalente := round(v_mto_interes * v_dia_plazo *
                                         cc.val_tasa / 36500,
                                         v_redondeo);
            ELSE
              v_mto_equivalente := round(v_mto_interes * cc.val_tasa / 100,
                                         v_redondeo);
            END IF;
          END IF;
          IF v_aplicar IN ('CA', 'CI', 'PC', 'CP', 'PT', 'TP') THEN
            --- es aplicable al capital --------------------------------------------------
            IF cc.cod_ent_seguro IS NOT NULL THEN
              --- es un seguro ----------------------------------------------------------
              v_mto_equivalente := nvl(v_mto_equivalente, 0) +
                                   round(v_tot_prestamo * cc.val_tasa / 100,
                                         v_redondeo);
            ELSE
              --- es un impuesto sobre el capital ---------------------------------------
              IF v_dia_plazo < 365 THEN
                v_mto_equivalente := nvl(v_mto_equivalente, 0) +
                                     round(v_tot_prestamo * v_dia_plazo *
                                           cc.val_tasa / 36500,
                                           v_redondeo);
              ELSE
                v_mto_equivalente := nvl(v_mto_equivalente, 0) +
                                     round(v_tot_prestamo * cc.val_tasa / 100,
                                           v_redondeo);
              END IF;
            END IF;
          END IF;
        ELSIF v_tpvlpor = 'V' THEN
          --- es un monto valor -----------------------------------------------------------
          v_mto_equivalente := cc.monto;
          v_ttvalor         := nvl(v_ttvalor, 0) +
                               nvl(v_mto_equivalente, 0);
        END IF;
        --- Acumular el total de cargos (Si el tipo es Valor viene directamente aqui -------
        v_mto_cargo := nvl(v_mto_cargo, 0) + nvl(v_mto_equivalente, 0);
        ------------------------------------------------------------------------------------
        v_monto := NULL;
        IF v_tpvlpor IN ('I', 'P') THEN
          /* solo si es porcentaje */
          IF cc.cod_moneda = p_cod_moneda THEN
            -- moneda del cargo es igual a la moneda de la simulacion ----------------------
            v_monto := v_mto_equivalente;
          ELSE
            -- monedas diferentes, se divide por la cotiz. de la moneda de la simulacion ---
            v_monto := round(v_mto_equivalente * v_cotizacion, v_redondeo);
          END IF;
        END IF;
        UPDATE pr_sol_cargos
           SET mto_mon_prestamo = nvl(v_mto_equivalente, 0),
               monto            = nvl(v_monto, monto)
         WHERE CURRENT OF cargos;
      END LOOP;
      IF v_mto_cargo >= v_tot_prestamo THEN
        /*raise_application_error(-20000,
        'ERROR. Total de Cargos ' || v_mto_cargo ||
         ' es superior al Total del Prestamo ' || v_tot_prestamo);*/
        g_lugar     := 'pr_cal_cargos';
        g_cod_error := 14;
        g_msj_error := 'Total de Cargos ' || v_mto_cargo ||
                       ' es superior al Total del Prestamo ' ||
                       v_tot_prestamo;
      ELSE
        IF v_tip_monto = 'N' AND v_tot_prestamo <> p_monto THEN
          --- ya estoy en el ultimo calculo de cargos netos, veo si hay ajuste --------
          IF nvl(v_tot_prestamo, 0) - nvl(v_mto_cargo, 0) <> p_monto THEN
            -- es necesario un ajuste en el cargo del impuesto o primer cargo      ---
            ww_dfcargos       := p_monto - (nvl(v_tot_prestamo, 0) -
                                 nvl(v_mto_cargo, 0));
            v_mto_equivalente := nvl(v_mto_equivalente, 0) - ww_dfcargos;
            v_mto_cargo       := nvl(v_mto_cargo, 0) - ww_dfcargos;
            UPDATE pr_sol_cargos
               SET mto_mon_prestamo = nvl(mto_mon_prestamo, 0) -
                                      nvl(ww_dfcargos, 0),
                   monto            = decode(cod_moneda,
                                             p_cod_moneda,
                                             nvl(mto_mon_prestamo, 0) -
                                             nvl(ww_dfcargos, 0),
                                             decode(cod_moneda,
                                                    v_mon_local,
                                                    round(((nvl(mto_mon_prestamo,
                                                                0) -
                                                          nvl(ww_dfcargos, 0)) *
                                                          v_cotizacion),
                                                          v_redondeo),
                                                    round(((nvl(mto_mon_prestamo,
                                                                0) -
                                                          nvl(ww_dfcargos, 0)) *
                                                          v_cotizacion),
                                                          v_redondeo)))
             WHERE nro_solicitud = v_nro_solicitud
               AND cod_transaccion = v_cod_tra_ajuste;
          END IF;
        END IF;
      END IF;
      -- actualizo el total de cargos de  la solicitud
      UPDATE pr_solicitudes
         SET mto_cargo = v_mto_cargo
       WHERE nro_solicitud = v_nro_solicitud;
    EXCEPTION
      WHEN OTHERS THEN
        --raise_application_error(-20000, 'CALCULAR_CARGOS ' || SQLERRM);
        g_lugar     := 'pr_cal_cargos';
        g_cod_error := 15;
        g_msj_error := 'CALCULAR_CARGOS ' || SQLERRM;
    END;

    -- INICIO DEL PROCEDIMIENTO PRINCIPAL----------------------------------------
  BEGIN
    v_fec_inicio := add_months(v_fec_pri_vencimiento, -1);
    --DA-990 Busca la modalidad de acuerdo al tipo de prestamo
    v_cod_modalidad := fue_obt_val_max_referencia('PLA_TIP_PRESTAMO',
                                                  p_tipo_prestamo);
    v_tip_monto     := fue_obt_des_refcodes('PLA_TIP_PRESTAMO',
                                            p_tipo_prestamo);
    v_cod_canal     := fue_obt_des_refcodes('COD_CANAL_BW', 'W');
    --
    --- Veo el tipo de redondeo de los calculos ------------------------------------------
    IF p_cod_moneda <> v_mon_local THEN
      v_limite := 0.05;
    END IF;
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                      6,
                                      v_cod_modalidad,
                                      p_cod_moneda);
    -- Valido el codigo del cliente-------------------------------------------
    if g_cod_error = 0 then
      pr_val_cod_persona;
    end if;
    -- Valido el codigo de la modalidad que recibo----------------------------
    if g_cod_error = 0 then
      pr_val_cod_modalidad;
    end if;
    -- valido la moneda-------------------------------------------------------
    if g_cod_error = 0 then
      pr_val_cod_moneda;
    end if;
    -- valido el monto -------------------------------------------------------
    if g_cod_error = 0 then
      IF nvl(p_monto, 0) <= 0 THEN
        --raise_application_error(-20000, 'ERROR. Ingrese Monto del Credito');
        g_lugar     := 'pr_gen_sol_con_plataforma';
        g_cod_error := 6;
        g_msj_error := 'Monto no debe ser menor o igual a cero.';
      END IF;
    end if;
    if g_cod_error = 0 then
      v_tot_prestamo := p_monto;
      -- valido el tipo de monto -----------------------------------------------
      IF nvl(v_tip_monto, 'X') NOT IN ('B', 'N') THEN
        --raise_application_error(-20000, 'ERROR. Tipo de Monto debe ser B-Bruto o N-Neto');
        g_lugar     := 'pr_gen_sol_con_plataforma';
        g_cod_error := 7;
        g_msj_error := 'Tipo de Monto debe ser B-Bruto o N-Neto';
      END IF;
    end if;
    -- valido la cantidad de cuotas ------------------------------------------
    if g_cod_error = 0 then
      IF nvl(p_can_cuotas, 0) < 1 THEN
        --raise_application_error(-20000, 'ERROR. Ingrese la cantidad de cuotas');
        g_lugar     := 'pr_gen_sol_con_plataforma';
        g_cod_error := 8;
        g_msj_error := 'Cuota no puede ser menor o igual a cero.';
      END IF;
    end if;
    -- Valido la fecha del primer vencimiento --------------------------------
    if g_cod_error = 0 then
      IF v_fec_pri_vencimiento <= v_fec_actual AND v_cod_modalidad <> 660 THEN
        /*raise_application_error(-20000,
        'ERROR. Primer Vencimiento debe ser posterior a la fecha de Hoy');*/
        g_lugar     := 'pr_gen_sol_con_plataforma';
        g_cod_error := 9;
        g_msj_error := 'Primer Vencimiento debe ser posterior a la fecha de Hoy';
      END IF;
    end if;
    If g_cod_error = 0 then
      v_dia_plazo   := add_months(v_fec_pri_vencimiento, p_can_cuotas - 1) -
                       v_fec_inicio;
      v_per_gracia  := v_fec_pri_vencimiento - v_fec_inicio;
      v_per_capital := 30;

      -- Valido la tasa de interes ---------------------------------------------
      pr_val_tasa;
    end if;
    if g_cod_error = 0 then
      -- Asigno el nro de la solicitud -----------------------------------------
      SELECT s_nro_sol_prestamos.nextval INTO v_nro_solicitud FROM dual;

      ---- Origen de Fondos
      IF p_cod_moneda IS NOT NULL AND v_cod_modalidad IS NOT NULL THEN
        v_ori_fondo := nvl(fup_obt_ori_fon_modalidad(v_cod_modalidad,
                                                     p_cod_moneda),
                           0);
      END IF;

      IF v_ori_fondo = 0 THEN
        v_ori_fondo := fug_obt_pardinamico('COD_ORI_FON_DESEMB',
                                           v_cod_modulo,
                                           v_cod_modalidad,
                                           p_cod_moneda,
                                           v_cod_oficina);
      END IF;

      -- inserto el registro en la tabla de solicitudes ------------------------
      INSERT INTO pr_solicitudes
        (nro_solicitud,
         descripcion,
         monto,
         tip_amortizacion,
         dia_plazo,
         fec_vencimiento,
         mto_interes,
         per_vto_capital,
         per_gracia,
         cod_persona,
         fec_inicio,
         tip_monto,
         tot_prestamo,
         cod_modulo,
         cod_modalidad,
         cod_moneda,
         cod_oficina,
         fec_pri_vencimiento,
         cod_sec_credito,
         cod_departamento,
         tip_documento,
         exo_impuesto,
         cod_usu_promotor,
         cod_canal,
         cod_campana,
         tip_destino,
         cod_banca,
         tip_renovacion,
         cod_ori_fondo,
         cod_rub_economico,
         por_ori_fondo,
         est_verificacion,
         nro_cta_debito)
      VALUES
        (v_nro_solicitud,
         nvl(p_descripcion, '.'),
         p_monto,
         v_tip_amortizacion, /* price */
         v_dia_plazo,
         v_fec_vencimiento,
         v_mto_interes,
         v_per_capital,
         v_per_gracia,
         p_cod_persona,
         v_fec_inicio,
         v_tip_monto,
         v_tot_prestamo,
         v_cod_modulo,
         v_cod_modalidad,
         p_cod_moneda,
         v_cod_oficina,
         v_fec_pri_vencimiento,
         v_cod_sec_credito,
         nvl(v_cod_departamento, v_cod_dep_parametro),
         v_tip_documento /* vista*/,
         v_exo_impuestos,
         v_cod_usu_promotor,
         v_cod_canal,
         v_cod_campana,
         4,
         v_cod_banca,
         'A',
         v_ori_fondo,
         v_cod_rub_economico,
         100,
         'N',
         v_nro_cta_debito);
    end if;
    if g_cod_error = 0 then
      -- genero los cargos por defecto
      pr_gen_cargos;
      -- generar cuotas --------------------------------------------------------
      pr_gen_cuotas('N');
    end if;
    if g_cod_error = 0 then
      -- Calculo los cargos ----------------------------------------------------
      pr_cal_cargos;
    end if;
    if g_cod_error = 0 then
      -- verifico el tipo de prestamo
      IF v_tip_monto = 'B' THEN
        v_tot_prestamo := p_monto;
      ELSE
        --- monto ingresado es el neto -----------------------------------------------------
        v_por_ajuste := (p_monto - (v_mto_cargo - v_ttvalor)) * 100 /
                        (p_monto + v_ttvalor);
        --- calculo del nuevo capital (monto bruto -----------------------------------------
        v_tot_prestamo := round((p_monto * 100 / v_por_ajuste), v_redondeo);
        --- Vuelvo a generar las cuotas y calcular los cargos ------------------------------
        pr_gen_cuotas('S');
        -- recalculo los cargos ------------------------------------------------------------
        pr_cal_cargos;
      end if;
      -- actualizo el total del prestamo -------------------------------------------------
      UPDATE pr_solicitudes
         SET tot_prestamo = v_tot_prestamo
       WHERE nro_solicitud = v_nro_solicitud;
      ------------------------------------------------------------------------------------
      --SoL Destinos y SoL Garantias
      DECLARE
        v_mto_destino pr_sol_destinos.monto%TYPE;
      BEGIN
        SELECT nvl(SUM(t.monto), 0)
          INTO v_mto_destino
          FROM pr_sol_cargos t
         WHERE t.nro_solicitud = v_nro_solicitud;

        INSERT INTO pr_sol_destinos
          (nro_solicitud, tip_des_especifico, monto)
        VALUES
          (v_nro_solicitud, 3, nvl(p_monto, 0) + nvl(v_mto_destino, 0));

        SELECT cod_garantia
          INTO v_cod_garantia
          FROM ge_solicitudes
         WHERE nro_solicitud = p_nro_referencia;

        IF v_cod_garantia = 1 THEN
          INSERT INTO pr_sol_garantias
            (nro_solicitud, cod_garantia, mto_aplicado)
          VALUES
            (v_nro_solicitud,
             v_cod_garantia,
             nvl(p_monto, 0) + nvl(v_mto_destino, 0));
        ELSE
          FOR r_sol IN sol_garantia LOOP

            INSERT INTO pr_sol_garantias
              (nro_solicitud, cod_garantia, nro_garantia, mto_aplicado)
            VALUES
              (v_nro_solicitud, v_cod_garantia, r_sol.cod_persona, 0);

            v_can_codeudor := nvl(v_can_codeudor, 0) + 1;

          END LOOP;

          IF v_can_codeudor > 1 THEN
            v_mon_garantia := (nvl(p_monto, 0) + nvl(v_mto_destino, 0)) /
                              v_can_codeudor;

          ELSE
            v_mon_garantia := (nvl(p_monto, 0) + nvl(v_mto_destino, 0));

          END IF;

          UPDATE pr_sol_garantias
             SET mto_aplicado = v_mon_garantia
           WHERE nro_solicitud = v_nro_solicitud;

        END IF;

      EXCEPTION
        WHEN no_data_found THEN
          NULL;
      END;

    END IF;
    -- finalmente inserto la cuota 0 ------------------------------------------------------
    BEGIN
      INSERT INTO pr_sol_cuotas
        (nro_solicitud,
         nro_cuota,
         fec_vto_exacto,
         fec_vto_habil,
         val_interes,
         val_int_adelantado,
         mto_capital,
         sal_capital,
         dia_transcurridos,
         dia_interes,
         dia_periodo)
      VALUES
        (v_nro_solicitud,
         0,
         v_fec_inicio,
         v_fec_inicio,
         0,
         0,
         0,
         v_tot_prestamo,
         0,
         0,
         0);
    EXCEPTION
      WHEN OTHERS THEN
        --raise_application_error(-20001, 'Error al insertar cuotas ' || SQLERRM);
        g_lugar     := 'pr_gen_sol_con_plataforma';
        g_cod_error := 16;
        g_msj_error := 'Error al insertar cuotas ' || SQLERRM;
    END;
    -- inserto el registro de la tasa ----------------------------------------------------
    BEGIN
      INSERT INTO pr_sol_tasas
        (nro_solicitud, fec_vigencia, val_tasa, tip_cobro, per_vencimiento)
      VALUES
        (v_nro_solicitud, v_fec_inicio, v_val_tasa, 'V', v_per_vencimiento);
    EXCEPTION
      WHEN OTHERS THEN
        --raise_application_error(-20002, 'Error al insertar el registro de tasas ' || SQLERRM);
        g_lugar     := 'pr_gen_sol_con_plataforma';
        g_cod_error := 16;
        g_msj_error := 'Error al insertar el registro de tasas ' || SQLERRM;
    END;
    if g_cod_error = 0 then
      p_nro_solicitud := v_nro_solicitud;
      p_cod_error     := 0;
      p_msj_error     := 'Solicitud generada';
    end if;

  EXCEPTION
    WHEN OTHERS THEN
      --raise_application_error(-20000, 'Propuesta ' || SQLERRM);
      p_cod_error := 17;
      p_msj_error := 'Error al generar Solicitud' || SQLERRM;
  END; -- prp_gen_sol_plataforma;

  /** Actualiza el nro de cuenta para debito automatico **/
  procedure pr_act_sol_con_plataforma(p_nro_solicitud in pr_solicitudes.nro_solicitud%TYPE,
                                      p_cod_canal     in varchar2 default 'N',
                                      p_cod_error     out number,
                                      p_men_error     out varchar2) is

    v_nom_programa varchar2(50) := 'PAP_PLA.PR_ACT_SOL_CON_PLATAFORMA';
    v_error        varchar2(10);
    v_mensaje      varchar2(1000);
    v_cdusuar      pr_solicitudes.usu_insercion%type;
    v_nro_caja     cj_cajas.nro_caja%type;
    v_cod_oficina  pr_solicitudes.cod_oficina%type;
    v_fec_actual   date;

  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;

    v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(6);
    v_error      := v_pro_correcto;
    v_mensaje    := 'Operacion Exitosa!';

    if p_cod_canal in ('W', 'M') then
      PRW_OBT_DAT_CAJA(p_cod_canal,
                       v_nro_caja,
                       v_cod_oficina,
                       v_cdusuar,
                       P_COD_ERROR,
                       P_MEN_ERROR);
    else
      v_cdusuar := substr(user, 1, 10);
    end if;

    UPDATE pr_solicitudes
       SET estado = 'L'
     WHERE nro_solicitud = p_nro_solicitud
       AND estado = 'S';

    if sql%notfound then
      v_error   := 999;
      v_mensaje := 'No esta recuperando datos de Solicitud nro. sol: ' ||
                   p_nro_solicitud;
      prg_ins_log_programas(v_nom_programa,
                            substr('1-Error: ' || v_error || ' - ' ||
                                   v_mensaje,
                                   1,
                                   4000),
                            null,
                            p_nro_solicitud);
    end if;

    p_cod_error := v_error;
    p_men_error := v_mensaje;

  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := substr(sqlerrm, 1, 4000);
      prg_ins_log_programas(v_nom_programa,
                            substr('2-Error: ' || p_cod_error || ' - ' ||
                                   p_men_error,
                                   1,
                                   4000),
                            null,
                            p_nro_solicitud);
  end;

  /**Cancelacion anticipada de cuotas**/
  PROCEDURE pr_can_cuo_pre_plataforma(p_nro_cuenta     in pr_cta_prestamos.nro_cuenta%type,
                                      p_nro_cta_debito in pr_cta_prestamos.nro_cta_debito%type,
                                      p_cuo_desde      in pr_cuotas.nro_cuota%type,
                                      p_cuo_hasta      in pr_cuotas.nro_cuota%type,
                                      p_cod_canal      in varchar2 default 'N',
                                      p_monto          in pr_cta_prestamos.monto%type default null,
                                      p_cod_error      out number,
                                      p_men_error      out varchar2,
                                      p_modo           in varchar2 default 'C',
                                      p_notas          in varchar2 default null) is

    v_nom_programa    varchar2(50) := 'PAP_PLA.PR_CAN_CUO_PRE_PLATAFORMA';
    v_cta_debito      ge_cta_clientes.nro_cuenta%type;
    v_cta_prestamos   ge_cta_clientes.nro_cuenta%type;
    datcuo            pr_cuotas%ROWTYPE;
    v_can_cuotas      number := 0;
    v_cant            number := 0;
    v_estado          pr_cta_prestamos.estado%type;
    v_fecha           ge_comprobantes.fecha%type;
    v_hora            ge_comprobantes.hora%type;
    v_cod_usuario     ge_comprobantes.cod_usuario%type;
    v_cod_persona     ge_cta_clientes.cod_persona%type;
    v_correo          ba_personas.dir_correo%type;
    v_nombre_cta      ba_personas.nom_completo%type;
    v_json            long;
    v_transaccion     number;
    v_monto           pr_cuotas.mto_capital%type;
    v_cod_moneda      pr_cta_prestamos.cod_moneda%type;
    v_descripcion     pr_cta_prestamos.descripcion%type;
    v_tot_can_cuotas  pr_cta_prestamos.can_cuotas%type;
    v_can_cuo_pagadas pr_cta_prestamos.can_cuo_pagadas%type;
    v_fec_insercion   date;
    v_cant_pagos      number := 0;
    v_nro_comprobante ge_comprobantes.nro_comprobante%type;
    v_exi_cuo_ant_pen number:=0;
    v_referencia1     ge_comprobantes.referencia1%type;
    cursor c_cuotas is
      select cu.nro_cuota
        from pr_cuotas cu
       where cu.nro_cuenta = p_nro_cuenta
         and cu.nro_cuota >= p_cuo_desde
         and cu.nro_cuota <= p_cuo_hasta
         and cu.estado != 'N'
       order by cu.nro_cuota;
  begin
    p_men_error := 'OK';
    -- se agrega la referencia si es pago parcial o cobro normal
    if p_monto is null then
      v_referencia1 := 'Pago por cuotas';
    else
      v_referencia1 := 'Pago parcial';
    end if;
    begin
      select count(*)
      into v_exi_cuo_ant_pen
      from pr_cuotas p
      where p.nro_cuenta=p_nro_cuenta
      and estado!='N'
    and p.nro_cuota <> 0
      and p.nro_cuota<p_cuo_desde;
    exception
      when no_data_found then
        v_exi_cuo_ant_pen:=0;
      when others then
         p_cod_error := v_err_sql;
         p_men_error := 'Error al verificar cuotas';
    end;

    if nvl(v_exi_cuo_ant_pen,0) > 0 then
       p_cod_error := v_err_sql;
       p_men_error := 'Tiene cuotas pendientes anteriores';
    end if;

 if nvl(p_cod_error,0) = 0 then

    select count(*)
      into v_cta_debito
      from ge_cta_clientes t
     where t.nro_cuenta = p_nro_cta_debito
       and t.cod_modulo in (3, 4);

    select count(*)
      into v_cta_prestamos
      from pr_cta_prestamos t
     where t.nro_cuenta = p_nro_cuenta
       and t.cod_modulo = 6
       and t.estado != 'N';

    if nvl(v_cta_debito, 0) != 0 and nvl(v_cta_prestamos, 0) != 0 then

      if p_cuo_desde is not null and p_cuo_hasta is not null then
        v_can_cuotas := p_cuo_hasta - p_cuo_desde;
        for i in 0 .. v_can_cuotas loop
          pap_pre.PR_OBT_DAT_CUOTA(p_nro_cuenta, p_cuo_desde + i, datcuo);
          if datcuo.estado = 'N' and nvl(datcuo.sal_capital, 0) = 0 and
             nvl(datcuo.sal_interes, 0) = 0 and i = v_can_cuotas then
            p_cod_error := v_err_sql;
            p_men_error := ' Las cuotas desde: ' || p_cuo_desde ||
                           ' hasta ' || p_cuo_hasta ||
                           ' ya fueron canceladas';
            return;
          end if;
        end loop;
      else
        p_cod_error := v_err_sql;
        p_men_error := ' Los nros de cuotas no pueden ser nulos';
        return;
      end if;

      for c in c_cuotas loop
        v_cant := v_cant + 1;
        select count(*)
          into v_cant_pagos
          from ge_comprobantes t
         where t.nro_cuenta = p_nro_cuenta
           and t.nro_cuota = c.nro_cuota
           and t.referencia1 = 'Pago por cuotas';

        if v_cant_pagos = 0 then
          pr_cob_pre_plataforma(p_nro_cuenta,
                                p_nro_cta_debito,
                                p_monto,--null,
                                c.nro_cuota,
                                c.nro_cuota,
                                null,
                                p_cod_error,
                                p_men_error,
                                'N',
                                'N',
                                p_cod_canal,
                                v_referencia1);
                               -- 'Pago por cuotas');
        else
          p_cod_error := 999;
          p_men_error := ' Las cuotas desde: ' || c.nro_cuota || ' hasta ' ||
                         c.nro_cuota || ' ya fueron canceladas';
          return;
        end if;
      end loop;

      if nvl(v_cant, 0) = 0 and nvl(p_cod_error, 0) = 0 then
        p_cod_error := v_err_sql;
        p_men_error := 'No se proceso ningun registro';
      end if;

      if nvl(p_cod_error, 0) <> 0 then
        prg_ins_log_programas(v_nom_programa,
                              substr('1-Error: ' || p_cod_error || ' - ' ||
                                     p_men_error,
                                     1,
                                     4000),
                              null,
                              p_nro_cuenta);
        --if p_modo = 'V' then
        rollback;
        --end if;
      elsif p_modo = 'V' then
        rollback;
      end if;
    else
      if v_cta_debito = 0 then
        p_cod_error := 1000;
        p_men_error := 'Cuenta de debito invalida';
      elsif v_cta_prestamos = 0 then
        p_cod_error := 1000;
        p_men_error := 'Cuenta de prestamo invalida';
      end if;
    end if;
  end if;
    if p_cod_error = 0 and p_modo = 'C' then
      p_men_error := 'OK';
      ---------------------------------------------------
      begin
        Select t.fecha,
               t.hora,
               t.cod_usuario,
               t.fec_insercion,
               t.monto,
               t.nro_comprobante
          into v_fecha,
               v_hora,
               v_cod_usuario,
               v_fec_insercion,
               v_monto,
               v_nro_comprobante
          from ge_comprobantes t
         where t.tip_comprobante = 'PC'
           and t.nro_cuenta = p_nro_cuenta
           and t.nro_cuota = p_cuo_hasta
           and t.nro_comprobante =
               (Select max(a.nro_comprobante)
                  from ge_comprobantes a
                 where a.tip_comprobante = 'PC'
                   and a.nro_cuenta = p_nro_cuenta
                   and a.nro_cuota = p_cuo_hasta);
      exception
        when others then
          prg_ins_log_programas(v_nom_programa,
                                substr('2-Error: ' || sqlerrm, 1, 4000),
                                null,
                                p_nro_cuenta);
      end;
      begin

        Select t.cod_moneda
          into v_cod_moneda
          from pr_cta_prestamos t
         where t.nro_cuenta = p_nro_cuenta;
      exception
        when no_data_found then
          prg_ins_log_programas(v_nom_programa,
                                substr('3-Error: ' || sqlerrm, 1, 4000),
                                null,
                                p_nro_cuenta);
      end;
      begin
        Select max(t.nro_documento)
          into v_transaccion
          from ge_movimientos t
         where t.fecha = v_fecha
           and t.hora = v_hora
           and t.cod_usuario = v_cod_usuario;
      exception
        when no_data_found then
          prg_ins_log_programas(v_nom_programa,
                                substr('4-Error: ' || sqlerrm, 1, 4000),
                                null,
                                p_nro_cuenta);
      end;
      begin

        select t.cod_persona
          into v_cod_persona
          from ge_cta_clientes t
         where t.nro_cuenta = p_nro_cta_debito
           and t.relacion = 'P';
      exception
        when no_data_found then
          prg_ins_log_programas(v_nom_programa,
                                substr('5-Error: ' || sqlerrm, 1, 4000),
                                null,
                                p_nro_cuenta);
      end;
      begin
        Select t.dir_correo, t.nom_completo
          into v_correo, v_nombre_cta
          from ba_personas t
         where t.cod_persona = v_cod_persona;
      exception
        when no_data_found then
          prg_ins_log_programas(v_nom_programa,
                                substr('6-Error: ' || sqlerrm, 1, 4000),
                                null,
                                p_nro_cuenta);
      end;
      begin
        Select t.estado, t.can_cuotas, t.can_cuo_pagadas
          into v_estado, v_tot_can_cuotas, v_can_cuo_pagadas
          from pr_cta_prestamos t
         where t.nro_cuenta = p_nro_cuenta;
      exception
        when no_data_found then
          prg_ins_log_programas(v_nom_programa,
                                substr('7-Error: ' || sqlerrm, 1, 4000),
                                null,
                                p_nro_cuenta);
      end;
-- PCON-14 Migracion de emails actuales en CORE a traves de la API de notificaciones
      /*if v_estado = 'N' and (v_tot_can_cuotas = p_cuo_hasta) then

        v_json := '{' || '"nro_transaccion":' || '"' ||
                  nvl(v_nro_comprobante, v_transaccion) || '"' || ',' ||
                  '"fec_realizado":' || '"' ||
                  to_char(v_fec_insercion, 'dd/mm/rrrr hh24:mi:ss') || '"' || ',' ||
                  '"nom_prestamo":' || '"' ||
                  nvl(fug_obt_paradicional(p_nro_cuenta, 'ALIAS_CTA'), '') ||
                  '... ' || rpad(p_nro_cuenta, 4) || '"' || ',' ||
                  '"nom_cue_debito":' || '"' || v_nombre_cta || '"' || ',' ||
                  '"num_cue_debito":' || '"' ||
                  nvl(fug_obt_paradicional(p_nro_cta_debito, 'ALIAS_CTA'),
                      '') || '... ' || rpad(p_nro_cta_debito, 4) || '"' || ',' ||
                  '"notas":' || '"' || p_notas || '"' || ',' || '"monto":' || '"' ||
                  v_monto || v_cod_moneda || '"' || ',' || '"aviso":' || '"' ||
                  fug_obt_pardinamico('MEN_AVI_PRE_CANC') || '"' || '}';

        if v_correo is not null then
          insert into ba_env_correos
            (cod_persona,
             tip_producto,
             estado,
             fec_registro,
             parametros,
             mai_destinatario)
          values
            (v_cod_persona, 7, 'P', sysdate, v_json, v_correo);
        else
          prg_ins_log_programas(v_nom_programa,
                                '8-Error: ' ||
                                'Correo no esta cargado en el cliente',
                                null,
                                p_nro_cuenta);
        end if;
      else

        v_json := '{' || '"nro_transaccion":' || '"' ||
                  nvl(v_nro_comprobante, v_transaccion) || '"' || ',' ||
                  '"fec_realizado":' || '"' || v_fecha || ' ' || v_hora || '"' || ',' ||
                  '"nom_prestamo":' || '"' ||
                  nvl(fug_obt_paradicional(p_nro_cuenta, 'ALIAS_CTA'), '') ||
                  '... ' || rpad(p_nro_cuenta, 4) || '"' || ',' ||
                  '"nom_cue_debito":' || '"' || v_nombre_cta || '"' || ',' ||
                  '"num_cue_debito":' || '"' ||
                  nvl(fug_obt_paradicional(p_nro_cta_debito, 'ALIAS_CTA'),
                      '') || '... ' || rpad(p_nro_cta_debito, 4) || '"' || ',' ||
                  '"cuotas":' || '"' || p_cuo_desde || '-' || p_cuo_hasta || '"' || ',' ||
                  '"notas":' || '"' || p_notas || '"' || ',' || '"monto":' || '"' ||
                  v_monto || v_cod_moneda || '"' || ',' || '"aviso":' || '"' ||
                  fug_obt_pardinamico('MEN_AVI_PRE_PAGO') || '"' || '}';

        if v_correo is not null then

          insert into ba_env_correos
            (cod_persona,
             tip_producto,
             estado,
             fec_registro,
             parametros,
             mai_destinatario)
          values
            (v_cod_persona, 6, 'P', sysdate, v_json, v_correo);
        else
          prg_ins_log_programas(v_nom_programa,
                                '9-Error: ' ||
                                'Correo no esta cargado en el cliente',
                                null,
                                p_nro_cuenta);
        end if;
      end if;*/
      ---------------------------------------------------
    end if;
  end;

  /**Obtener deuda por monto**/
  PROCEDURE pr_obt_deu_pre_monto_plat(p_nro_cuenta     in pr_cta_prestamos.nro_cuenta%type,
                                      p_nro_cta_debito in pr_cta_prestamos.nro_cta_debito%type,
                                      p_monto          in pr_cta_prestamos.sal_capital%type,
                                      p_cod_canal      in varchar2 default 'N',
                                      p_cod_error      out number,
                                      p_men_error      out varchar2) is
    cursor c_cuotas is
      select cu.nro_cuota
        from pr_cuotas cu
       where cu.nro_cuenta = p_nro_cuenta
         and cu.estado != 'N'
         and cu.nro_cuota > 0
       order by cu.nro_cuota;

    p_mto_capital      pr_cuotas.mto_capital%type;
    p_mto_interes      pr_cuotas.mto_interes%type;
    p_mto_int_ade      pr_cuotas.mto_interes%type;
    p_mto_cargos       pr_cuotas.sal_capital%type;
    p_mto_pagar        pr_cuotas.sal_capital%type;
    p_dia_mora         pr_cobros.dia_mora%type;
    p_mto_mora         pr_cobros.mto_int_mor_interes%type;
    p_mto_mora_int     pr_cobros.mto_int_mor_interes%type;
    p_mto_mora_int_ade pr_cobros.mto_int_mor_interes%type;
    p_mto_punitor      pr_cobros.mto_int_punitorio%type;
    p_mto_impuest      pr_cobros.mto_impuesto%type;
    p_mto_cargo        pr_cobros.mto_cargo%type;
    p_tot_car_iva      pr_cobros.mto_cargo%type;
    p_mto_descont      pr_cobros.mto_int_documentado%type;
    p_mto_iva_dev      pr_cobros.mto_int_documentado%type;
    v_mto_cuota        pr_cuotas.sal_capital%type;
    v_saldo            pr_cuotas.sal_capital%type;
    v_cod_mon_prest    pr_cta_prestamos.cod_moneda%type;
    v_cod_mon_ahorr    ah_cta_vistas.cod_moneda%type;
    v_cod_mon_comb     ah_cta_vistas.cod_moneda%type;
    v_VAL_COMPRA       ge_cotizaciones.val_compra%type;
    v_VAL_VENTA        ge_cotizaciones.val_venta%type;
    v_redondeo         NUMBER(1);

  begin
    if p_monto > 0 then
      select cod_moneda
        into v_cod_mon_prest
        from pr_cta_prestamos p
       where p.nro_cuenta = p_nro_cuenta;

      select cod_moneda
        into v_cod_mon_ahorr
        from ah_cta_vistas p
       where p.nro_cuenta = p_nro_cta_debito;

      if v_cod_mon_prest != v_cod_mon_ahorr then
        if pag_gen.fu_obt_mon_local() != v_cod_mon_prest then
          v_cod_mon_comb := v_cod_mon_prest;
        else
          v_cod_mon_comb := v_cod_mon_ahorr;
        end if;
        v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                          null,
                                          null,
                                          v_cod_mon_comb);

        if pag_gen.fu_obt_mon_local() != v_cod_mon_prest then
          v_saldo := round(p_monto /
                         pag_gen.fu_obt_cotizacion(v_cod_mon_comb,
                                                   pag_cal.FU_OBT_FEC_ACTUAL(6)),
                         v_redondeo);
        else
          v_saldo := round(p_monto *
                         pag_gen.fu_obt_cotizacion(v_cod_mon_comb,
                                                   pag_cal.FU_OBT_FEC_ACTUAL(6)),
                         v_redondeo);
        end if;

      else
        v_saldo := p_monto;
      end if;

      delete pr_cuo_montos c where c.nro_cuenta = p_nro_cuenta;

      for c in c_cuotas loop
        pr_obt_deu_pre_plataforma(p_nro_cuenta,
                                  c.nro_cuota,
                                  c.nro_cuota,
                                  p_mto_capital,
                                  p_mto_interes,
                                  p_mto_int_ade,
                                  p_mto_cargos,
                                  p_mto_pagar,
                                  p_dia_mora,
                                  p_mto_mora,
                                  p_mto_mora_int,
                                  p_mto_mora_int_ade,
                                  p_mto_punitor,
                                  p_mto_impuest,
                                  p_mto_cargo,
                                  p_tot_car_iva,
                                  p_mto_descont,
                                  p_mto_iva_dev,
                                  p_cod_error,
                                  p_men_error);

        v_saldo := v_saldo - p_mto_pagar;

        if v_saldo > 0 then
          v_mto_cuota := p_mto_pagar;
        else
          v_mto_cuota := p_mto_pagar + v_saldo;
        end if;

        insert into pr_cuo_montos
          (nro_cuenta, nro_cuota, fec_solic, mto_cuota)
        values
          (p_nro_cuenta, c.nro_cuota, trunc(sysdate), v_mto_cuota);

        exit when v_saldo <= 0;
      end loop;
    else
      p_cod_error := 999;
      p_men_error := 'Favor ingresar un valor mayor a 0';
    end if;
  end;

  /**Realizar cobro por monto**/
  PROCEDURE pr_cob_pre_monto_platafor(p_nro_cuenta     in pr_cta_prestamos.nro_cuenta%type,
                                      p_nro_cta_debito in pr_cta_prestamos.nro_cta_debito%type,
                                      p_monto          in pr_cta_prestamos.sal_capital%type,
                                      p_cod_canal      in varchar2 default 'N',
                                      p_cod_error      out number,
                                      p_men_error      out varchar2,
                                      p_modo           in varchar2 default 'C',
                                      p_notas          in varchar2 default null) is
    cursor c_deuda_monto is
      select t.* from pr_cuo_montos t where t.nro_cuenta = p_nro_cuenta;

    v_cta_debito      ge_cta_clientes.nro_cuenta%type;
    v_cta_prestamos   ge_cta_clientes.nro_cuenta%type;
    v_estado          pr_cta_prestamos.estado%type;
    v_fecha           ge_comprobantes.fecha%type;
    v_hora            ge_comprobantes.hora%type;
    v_cod_usuario     ge_comprobantes.cod_usuario%type;
    v_cod_persona     ge_cta_clientes.cod_persona%type;
    v_correo          ba_personas.dir_correo%type;
    v_nombre_cta      ba_personas.nom_completo%type;
    v_json            long;
    v_transaccion     number;
    v_monto           pr_cuotas.mto_capital%type;
    v_cod_moneda      pr_cta_prestamos.cod_moneda%type;
    v_descripcion     pr_cta_prestamos.descripcion%type;
    v_cuota           pr_cuo_montos.nro_cuota%type;
    v_cuota_min       pr_cuo_montos.nro_cuota%type;
    v_nom_programa    varchar2(50) := 'PAP_PLA.PR_COB_PRE_MONTO_PLATAFOR';
    v_tot_can_cuotas  pr_cta_prestamos.can_cuotas%type;
    v_fec_insercion   date;
    v_nro_comprobante ge_comprobantes.nro_comprobante%type;

  begin

    select count(*)
      into v_cta_debito
      from ge_cta_clientes t
     where t.nro_cuenta = p_nro_cta_debito
       and t.cod_modulo in (3, 4);

    select count(*)
      into v_cta_prestamos
      from pr_cta_prestamos t
     where t.nro_cuenta = p_nro_cuenta
       and t.cod_modulo = 6
       and t.estado != 'N';

    if v_cta_debito != 0 and v_cta_prestamos != 0 then
      IF p_modo = 'V' THEN

            pr_obt_deu_pre_monto_plat(p_nro_cuenta,
                                      p_nro_cta_debito,
                                      p_monto,
                                      p_cod_canal,
                                      p_cod_error,
                                      p_men_error);

            for c in c_deuda_monto loop

              pr_cob_pre_plataforma(p_nro_cuenta,
                                    p_nro_cta_debito,
                                    c.mto_cuota,
                                    c.nro_cuota,
                                    c.nro_cuota,
                                    null,
                                    p_cod_error,
                                    p_men_error,
                                    'N',
                                    'N',
                                    p_cod_canal,
                                    'Pago por monto');
            end loop;
            if p_modo = 'V' then
              rollback;
            end if;

      ELSE
        pr_can_pre_plataforma(p_nro_cuenta,
                              p_nro_cta_debito,
                              p_cod_canal,
                              p_cod_error,
                              p_men_error);

      END IF;
    else
      if v_cta_debito = 0 then
        p_cod_error := 1000;
        p_men_error := 'Cuenta de debito invalida';
      elsif v_cta_prestamos = 0 then
        p_cod_error := 1000;
        p_men_error := 'Cuenta de prestamo invalida';
      end if;
    end if;

    select max(t.nro_cuota), min(t.nro_cuota)
      into v_cuota, v_cuota_min
      from pr_cuo_montos t
     where t.nro_cuenta = p_nro_cuenta;

    if p_cod_error = 0 and p_modo = 'C' then
      p_men_error := 'OK';
      ---------------------------------------------------
      begin
        Select t.fecha,
               t.hora,
               t.cod_usuario,
               t.fec_insercion,
               t.nro_comprobante
          into v_fecha,
               v_hora,
               v_cod_usuario,
               v_fec_insercion,
               v_nro_comprobante
          from ge_comprobantes t
         where t.tip_comprobante = 'PC'
           and t.nro_cuenta = p_nro_cuenta
           and t.nro_cuota = v_cuota
           and t.nro_comprobante =
               (Select max(a.nro_comprobante)
                  from ge_comprobantes a
                 where a.tip_comprobante = 'PC'
                   and a.nro_cuenta = p_nro_cuenta
                   and a.nro_cuota = v_cuota);
      exception
        when others then
          prg_ins_log_programas(v_nom_programa,
                                substr('1-Error: ' || sqlerrm, 1, 4000),
                                null,
                                p_nro_cuenta);
      end;
      begin

        Select t.cod_moneda
          into v_cod_moneda
          from pr_cta_prestamos t
         where t.nro_cuenta = p_nro_cuenta;
      exception
        when no_data_found then
          prg_ins_log_programas(v_nom_programa,
                                substr('2-Error: ' || sqlerrm, 1, 4000),
                                null,
                                p_nro_cuenta);
      end;
      begin
        Select max(t.nro_documento)
          into v_transaccion
          from ge_movimientos t
         where t.fecha = v_fecha
           and t.hora = v_hora
           and t.cod_usuario = v_cod_usuario;
      exception
        when no_data_found then
          prg_ins_log_programas(v_nom_programa,
                                substr('3-Error: ' || sqlerrm, 1, 4000),
                                null,
                                p_nro_cuenta);
      end;
      begin

        select t.cod_persona
          into v_cod_persona
          from ge_cta_clientes t
         where t.nro_cuenta = p_nro_cta_debito
           and t.relacion = 'P';
      exception
        when no_data_found then
          prg_ins_log_programas(v_nom_programa,
                                substr('5-Error: ' || sqlerrm, 1, 4000),
                                null,
                                p_nro_cuenta);
      end;
      begin
        Select t.dir_correo, t.nom_completo
          into v_correo, v_nombre_cta
          from ba_personas t
         where t.cod_persona = v_cod_persona;
      exception
        when no_data_found then
          prg_ins_log_programas(v_nom_programa,
                                substr('6-Error: ' || sqlerrm, 1, 4000),
                                null,
                                p_nro_cuenta);
      end;
      begin
        Select t.estado, t.can_cuotas
          into v_estado, v_tot_can_cuotas
          from pr_cta_prestamos t
         where t.nro_cuenta = p_nro_cuenta;
      exception
        when no_data_found then
          prg_ins_log_programas(v_nom_programa,
                                substr('7-Error: ' || sqlerrm, 1, 4000),
                                null,
                                p_nro_cuenta);
      end;
--PCON-14 Migracion de emails actuales en CORE a traves de la API de notificaciones
     /* if v_estado = 'N' and (v_tot_can_cuotas = v_cuota) then

        v_json := '{' || '"nro_transaccion":' || '"' ||
                  nvl(v_nro_comprobante, v_transaccion) || '"' || ',' ||
                  '"fec_realizado":' || '"' ||
                  to_char(v_fec_insercion, 'dd/mm/rrrr hh24:mi:ss') || '"' || ',' ||
                  '"nom_prestamo":' || '"' ||
                  nvl(fug_obt_paradicional(p_nro_cuenta, 'ALIAS_CTA'), '') ||
                  '... ' || rpad(p_nro_cuenta, 4) || '"' || ',' ||
                  '"nom_cue_debito":' || '"' || v_nombre_cta || '"' || ',' ||
                  '"num_cue_debito":' || '"' ||
                  nvl(fug_obt_paradicional(p_nro_cta_debito, 'ALIAS_CTA'),
                      '') || '... ' || rpad(p_nro_cta_debito, 4) || '"' || ',' ||
                  '"notas":' || '"' || p_notas || '"' || ',' || '"monto":' || '"' ||
                  p_monto || v_cod_moneda || '"' || ',' || '"aviso":' || '"' ||
                  fug_obt_pardinamico('MEN_AVI_PRE_CANC') || '"' || '}';

        if v_correo is not null then
          insert into ba_env_correos
            (cod_persona,
             tip_producto,
             estado,
             fec_registro,
             parametros,
             mai_destinatario)
          values
            (v_cod_persona, 7, 'P', sysdate, v_json, v_correo);
        else
          prg_ins_log_programas(v_nom_programa,
                                '8-Error: ' ||
                                'Correo no esta cargado en el cliente',
                                null,
                                p_nro_cuenta);
        end if;
      else

        v_json := '{' || '"nro_transaccion":' || '"' ||
                  nvl(v_nro_comprobante, v_transaccion) || '"' || ',' ||
                  '"fec_realizado":' || '"' ||
                  to_char(v_fec_insercion, 'dd/mm/rrrr hh24:mi:ss') || '"' || ',' ||
                  '"nom_prestamo":' || '"' ||
                  nvl(fug_obt_paradicional(p_nro_cuenta, 'ALIAS_CTA'), '') ||
                  '... ' || rpad(p_nro_cuenta, 4) || '"' || ',' ||
                  '"nom_cue_debito":' || '"' || v_nombre_cta || '"' || ',' ||
                  '"num_cue_debito":' || '"' ||
                  nvl(fug_obt_paradicional(p_nro_cta_debito, 'ALIAS_CTA'),
                      '') || '... ' || rpad(p_nro_cta_debito, 4) || '"' || ',' ||
                  '"cuotas":' || '"' || v_cuota_min || '-' || v_cuota || '"' || ',' ||
                  '"notas":' || '"' || p_notas || '"' || ',' || '"monto":' || '"' ||
                  p_monto || v_cod_moneda || '"' || ',' || '"aviso":' || '"' ||
                  fug_obt_pardinamico('MEN_AVI_PRE_PAGO') || '"' || '}';

        if v_correo is not null then

          insert into ba_env_correos
            (cod_persona,
             tip_producto,
             estado,
             fec_registro,
             parametros,
             mai_destinatario)
          values
            (v_cod_persona, 6, 'P', sysdate, v_json, v_correo);
        else
          prg_ins_log_programas(v_nom_programa,
                                '9-Error: ' ||
                                'Correo no esta cargado en el cliente',
                                null,
                                p_nro_cuenta);
        end if;
      end if;*/
      ---------------------------------------------------
    else
      rollback;
    end if;
  end;
end PAP_PLA;
/
