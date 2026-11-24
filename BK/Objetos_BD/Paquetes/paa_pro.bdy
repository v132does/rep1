CREATE OR REPLACE PACKAGE BODY IT.PAA_PRO IS
  v_msg_error varchar2(300);
  g_movs pag_cta.rg_movs;

  procedure pr_obt_saldo(p_nro_cuenta varchar2,
                        p_nro_cta_capitalizacion varchar2,
                        p_sal_total number,
                        p_sal_disponible out number,
                        p_mto_car_fijo out number,
                        p_imp_car_fijo out number,
                        p_mto_car_por out number,
                        p_imp_car_por out number) IS

    --- variables para validacion de saldo de cuenta para cobro de cargo por cancelacion
    v_interes           ge_movimientos.monto%type := 0;
    v_sal_cta_capitalizacion ah_cta_vistas.sal_total%type;
    v_mto_car_fijo      ge_movimientos.monto%type;
    v_imp_car_fijo      ge_movimientos.monto%type;
    v_mto_car_por       ge_movimientos.monto%type;
    v_imp_car_por       ge_movimientos.monto%type;
    v_mto_cre_neto     ge_movimientos.monto%type;

    --- variables de error
    v_err_sal_insuficiente exception;
    v_cta_err           tm_log_nominas.nro_cuenta%type;
    v_err_mto           tm_log_nominas.monto%type;
    v_err_sal_total     tm_log_nominas.sal_total%type;
    v_err_lugar         tm_log_nominas.lugar%type;
    v_err_observacion   tm_log_nominas.observacion%type;

  begin

    /*** INICIO PROGRAMA ***/
    p_sal_disponible := 0;
    p_mto_car_fijo   := 0;
    p_imp_car_fijo   := 0;
    p_mto_car_por    := 0;
    p_imp_car_por    := 0;

   -- obtiene el interes de la cuenta
    v_interes := paa_pro.fu_rec_int_ap(p_nro_cuenta);

    --obtiene datos de la cta capitalizacion
    pag_cta.pr_obt_cuenta(p_nro_cta_capitalizacion);

    --obtiene saldo disponible de la cta capitalizacion + saldo del AP
    v_sal_cta_capitalizacion := pag_cta.fu_sal_disponible + nvl(p_sal_total,0) + nvl(v_interes, 0);

    --Calcula monto Cargo
    pr_can_cal_mto_aho_pro(p_nro_cuenta, v_mto_car_fijo, v_imp_car_fijo, v_mto_car_por, v_imp_car_por, v_mto_cre_neto);
                        
   /**** Datos de retorno ****/
    p_sal_disponible := v_sal_cta_capitalizacion;
    p_mto_car_fijo   := v_mto_car_fijo;
    p_imp_car_fijo   := v_imp_car_fijo;
    p_mto_car_por    := v_mto_car_por;
    p_imp_car_por    := v_imp_car_por;

  exception
    when others then
      pr_ins_log_error(v_cta_err, v_err_mto, v_err_sal_total, v_err_lugar, substr('-20068 '||v_err_observacion,1,300));
  end;

  PROCEDURE pr_mov_nocturno (p_es_nocturno out varchar2) is
    v_est_modulo    ba_modulos.estado%type;
    v_es_nocturno   varchar2(1)  := 'N';
    v_error         exception;
  begin
    v_est_modulo  := pae_cnf.fu_obt_est_modulo(3);
    if v_est_modulo in (1,6) then -- volcado del noc al maestro y viceversa
       raise v_error;
    elsif v_est_modulo = 2 then -- el modulo esta abierto
       v_es_nocturno := 'N';
       pag_cta.g_horario := 'D';--dia
    else -- en cierre.
       v_es_nocturno  := 'S'; -- para grabar en las tablas nocturnas
       pag_cta.g_horario := 'N';--noche
    end if;
    p_es_nocturno := v_es_nocturno;
  exception
   when v_error then
     raise_application_error(-20061, 'Sistema en cierre');
   when others then
     raise_application_error(-20062, SQLERRM);
  end;

  PROCEDURE lp_act_fec_vencimiento IS
   /**
      Programa para actualizar la fecha de vencimiento del ahorro programado.
      Para la fecha se utiliza el valor del campo fec_ult_pago si el pago fue realizado en la ultima cuota.
      Si el ultimo pago no fue en la ultima cuota entonces se utiliza el ultimo dia del periodo de pago de la ultima cuota
      como referencia.
      Luego a esa fecha se le suma 30 dias para actualizar.
   **/
   v_fec_ven_ahp_cuota   ah_pro_cuotas.fec_vencimiento%type;
   v_fec_ult_pago        ah_pro_cuotas.fec_ult_pago%type;
   v_periodo             ah_pro_cuotas.periodo%type;
   v_ini_periodo         varchar2(2);
   v_fin_periodo         varchar2(2);
   v_fec_ini_periodo     ah_cta_plazos.fec_vencimiento%type;
   v_fec_fin_periodo     ah_cta_plazos.fec_vencimiento%type;
   v_fec_actual          ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(3);
   v_fec_anterior        ge_calendarios.fec_actual%type;
   v_act_fec_vencimiento ge_calendarios.fec_actual%type;

   cursor cur_ahp_act_fec_vencimiento is
    select a.nro_cuenta
      from ah_cta_plazos a
     where a.estado not in ('C','P','T')
     and a.cod_modalidad = 38
     and a.fec_vencimiento between v_fec_anterior and v_fec_actual;

  begin
    v_fec_anterior := v_fec_actual-30;
    for reg in cur_ahp_act_fec_vencimiento loop
      begin
        select a.fec_vencimiento, a.fec_ult_pago, a.periodo
          into v_fec_ven_ahp_cuota, v_fec_ult_pago, v_periodo
          from ah_pro_cuotas a
         where a.nro_cuenta = reg.nro_cuenta
           and a.tipo = 'C'
           and a.nro_cuota = (select max(b.nro_cuota)
                                from ah_pro_cuotas b
                               where b.nro_cuenta = a.nro_cuenta
                                 and b.tipo = 'C');
      exception
        when others then
          v_fec_ven_ahp_cuota := null;
          v_fec_ult_pago      := null;
      end;

      v_ini_periodo         := v_periodo;
      v_fin_periodo         := fue_obt_val_max_referencia ('FEC_DEB_AHO_PROGRAMADO', v_ini_periodo);
      v_fec_ini_periodo     := to_date(v_ini_periodo||'/'||to_char(v_fec_ven_ahp_cuota,'mm/yyyy'), 'dd/mm/yyyy');
      v_fec_fin_periodo     := to_date(v_fin_periodo||'/'||to_char(v_fec_ven_ahp_cuota,'mm/yyyy'), 'dd/mm/yyyy');
      if v_ini_periodo = 21 then
         v_fec_fin_periodo := last_day(v_fec_ven_ahp_cuota);
      end if;
      v_act_fec_vencimiento := v_fec_fin_periodo + 30;

      if v_fec_actual > v_fec_fin_periodo then
        if v_fec_ult_pago is not null and v_fec_ven_ahp_cuota is not null
          and v_fec_ult_pago >= v_fec_ini_periodo and v_fec_ult_pago <= v_fec_fin_periodo then
           v_act_fec_vencimiento := v_fec_ult_pago + 30;
        end if;

        v_act_fec_vencimiento := PAG_CAL.FU_OBT_FEC_HABIL(v_act_fec_vencimiento,1,61);

        update ah_cta_plazos a
           set a.fec_vencimiento = v_act_fec_vencimiento
         where a.nro_cuenta = reg.nro_cuenta;
      end if;
    end loop;
  exception
   when others then
      pr_ins_log_error('0', 0, 0, 'PAA_PRO.LP_ACT_FEC_VENCIMIENTO', sqlerrm);
  end;

  /** Determina si la cuenta es una Cuenta Conjunta **/
  FUNCTION fu_es_conjunta(p_numeroCuenta IN VARCHAR2) RETURN VARCHAR2 IS
     v_can_conjunta NUMBER;
  BEGIN
    -- veo si la cuenta no es conjunta
    SELECT COUNT(*)
      INTO v_can_conjunta
      FROM ge_cta_clientes
     WHERE nro_cuenta = p_numeroCuenta
       AND relacion = 'Y'
       AND rownum = 1;
    IF v_can_conjunta > 0  THEN
       /* no requiere autorizacion y la cuenta es conjunta, no debe acceder*/
       RETURN 'S';
    ELSE
       RETURN 'N';
    END IF;
  END;

  PROCEDURE pr_obt_mto_pizarra(p_piz_monto         IN OUT cr_piz_montos%ROWTYPE,
                               p_cod_modulo        IN cr_piz_montos.cod_modulo%TYPE,
                               p_cod_modalidad     IN cr_piz_montos.cod_modalidad%TYPE,
                               p_cod_moneda        IN cr_piz_montos.cod_moneda%TYPE,
                               p_cod_sub_modalidad IN cr_piz_montos.cod_sub_modalidad%TYPE DEFAULT NULL) IS
  BEGIN
     SELECT *
       INTO p_piz_monto
       FROM cr_piz_montos m
      WHERE m.cod_modulo = p_cod_modulo
        AND m.cod_modalidad = p_cod_modalidad
        AND m.cod_moneda = p_cod_moneda
        AND NVL(m.cod_sub_modalidad, -1) = NVL(p_cod_sub_modalidad, -1);
  EXCEPTION
     WHEN OTHERS THEN
        p_piz_monto := NULL;
  END;
  ---
  PROCEDURE pr_obt_plz_pizarra(p_cod_modulo        IN cr_piz_montos.cod_modulo%TYPE,
                               p_cod_modalidad     IN cr_piz_montos.cod_modalidad%TYPE,
                               p_cod_moneda        IN cr_piz_montos.cod_moneda%TYPE,
                               p_cod_sub_modalidad IN cr_piz_montos.cod_sub_modalidad%TYPE DEFAULT NULL,
                               p_min_plazo         OUT cr_piz_plazos.plz_desde%TYPE,
                               p_max_plazo         OUT cr_piz_plazos.plz_hasta%TYPE) IS
  BEGIN
    --plazos
    SELECT nvl(MIN(pz.plz_desde), 0), nvl(MAX(pz.plz_hasta), 0)
      INTO p_min_plazo, p_max_plazo
      FROM cr_piz_plazos pz
     WHERE pz.cod_modulo = p_cod_modulo
       AND pz.cod_modalidad = p_cod_modalidad
       AND NVL(pz.cod_sub_modalidad, -1) = NVL(p_cod_sub_modalidad, -1)
       AND pz.cod_moneda = p_cod_moneda ;
  EXCEPTION
    WHEN OTHERS THEN
      p_min_plazo := NULL;
      p_max_plazo := NULL;
  END;
  --
  FUNCTION fu_sim_aho_programado(p_monto      IN cr_piz_plazos.mto_desde%TYPE,
                                 p_tipo       IN VARCHAR2,
                                 p_cod_moneda IN cr_piz_plazos.cod_moneda%TYPE) RETURN typ_simulador IS

     v_tasa        cr_piz_plazos.tas_interes%TYPE;
     v_retorno     typ_simulador := typ_simulador();
     v_tip_pizarra typ_pizarra := typ_pizarra();
     v_tip_plazos  typ_pizarraplazos := typ_pizarraplazos();
     v_total     number;
     v_monto     number;
     v_mto_cuota   number;
     v_mto_interes number;

     CURSOR c_plazos IS
      SELECT a.significado, a.val_minimo
        FROM ba_cod_referencias a
       WHERE a.dominio = 'PLA_AHO_PROGRAMADO'
       ORDER BY to_number(a.val_minimo);
  BEGIN
     v_retorno.listaPizarra  := typ_listapizarra();
     v_retorno.listaPlazos   := typ_listapizarraplazos();
     v_tip_pizarra.modulo    := 3;
     v_tip_pizarra.modalidad := 38;
     v_tip_pizarra.codMoneda := substr(p_cod_moneda, 1, 3);
     v_tip_plazos.modulo     := 3;
     v_tip_plazos.modalidad  := 38;
     v_tip_plazos.codMoneda  := substr(p_cod_moneda, 1, 3);

     FOR c IN c_plazos
     LOOP
       --AIU-342
        if p_tipo = 'C' then
          v_monto := p_monto * c.val_minimo;
        else
          v_monto := p_monto;
        end if;

        v_retorno.cantDetallesPizarra := v_retorno.cantDetallesPizarra + 1;
        v_retorno.cantDetallesPlazos  := v_retorno.cantDetallesPlazos + 1;
        v_tasa                        := paw_bas.fu_obt_tas_pizarra(c.val_minimo, v_monto, p_cod_moneda, 3, 38, NULL, 1);
        v_mto_cuota                   := v_monto/ c.val_minimo;
        v_mto_interes                 := pag_gen.fu_cal_int_simple(v_monto, (c.val_minimo * 30), v_tasa);
        v_total                       := v_monto + v_mto_interes;
        v_tip_pizarra.descripcion     := substr(c.significado, 1, 60);
        v_tip_pizarra.montoDesde      := v_total;
        v_tip_plazos.plzDesde         := to_number(c.val_minimo);
        v_tip_plazos.tasInteres       := v_tasa;

        -- se agrega el item a la lista
        IF v_total > 0 THEN
           v_retorno.listaPizarra.extend;
           v_retorno.listaPlazos.extend;
           v_retorno.listaPizarra(v_retorno.listaPizarra.count) := v_tip_pizarra;
           v_retorno.listaPlazos(v_retorno.listaPlazos.count)   := v_tip_plazos;
        END IF;
     END LOOP;

     v_retorno.error               := 'N';
     v_retorno.cantDetallesPizarra := v_retorno.listaPizarra.count;
     v_retorno.cantDetallesPlazos  := v_retorno.listaPlazos.count;
     RETURN v_retorno;
  END;
  --
  PROCEDURE pr_cal_aho_programado(p_monto      IN cr_piz_plazos.mto_desde%TYPE,
                                  p_plazo      IN cr_piz_plazos.plz_hasta%TYPE,
                                  p_tipo       IN VARCHAR2,
                                  p_cod_moneda IN cr_piz_plazos.cod_moneda%TYPE,
                                  p_tasa       OUT cr_piz_plazos.tas_interes%TYPE,
                                  p_tot_ahorro OUT cr_piz_montos.mto_hasta%TYPE) IS
     v_tot_ap   NUMBER;
     v_redondeo NUMBER(2);

  BEGIN
     p_tasa     := paw_bas.fu_obt_tas_pizarra(p_plazo, p_monto, p_cod_moneda, 3, 38, NULL, 1);
     v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 3, 38, p_cod_moneda);

     IF p_tipo = 'M' THEN
        --pasa monto cuota
        v_tot_ap     := p_monto * (power(1 + ((p_tasa / 12) / 100), p_plazo) - 1) / ((p_tasa / 12) / 100);
        p_tot_ahorro := round(v_tot_ap + (p_monto * (power(1 + ((p_tasa / 12) / 100), p_plazo) - 1)),v_redondeo);
     ELSIF p_tipo = 'T' THEN
        v_tot_ap     := p_monto * ((p_tasa / 12) / 100) / (power(1 + ((p_tasa / 12) / 100), p_plazo) - 1);
        p_tot_ahorro := round(v_tot_ap,v_redondeo);
     END IF;
  END;

  -- obtener detalle de ahorro para notificacion
  FUNCTION lf_obt_det_pro_notificacion(p_nro_cuenta     IN ah_cta_plazos.nro_cuenta%TYPE,
                                       p_tip_operacion  IN VARCHAR2,
                                       p_nro_cta_debito IN ge_cuentas.nro_cuenta%TYPE DEFAULT NULL,
                                       p_monto          IN NUMBER DEFAULT NULL) RETURN VARCHAR2 IS

     v_cabecera    VARCHAR2(800)  := NULL;
     v_detalle     VARCHAR2(3100) := NULL;
     v_pie         VARCHAR2(500)  := NULL;
     v_mto_cuota   ah_pro_cuotas.mto_cuota%TYPE;
     v_moneda      NUMBER;
     v_plazo       NUMBER;
     rg_cta_plazo  ah_cta_plazos%ROWTYPE;
     v_titulo      VARCHAR2(50);
     v_descripcion VARCHAR2(50);

  BEGIN
     -- detalles de la cuenta
     SELECT *
       INTO rg_cta_plazo
       FROM ah_cta_plazos p
      WHERE p.nro_cuenta = p_nro_cuenta;

     SELECT COUNT(0), c.mto_cuota
       INTO v_plazo, v_mto_cuota
       FROM ah_pro_cuotas c
      WHERE c.nro_cuenta = p_nro_cuenta
        AND c.tipo = 'C'
      GROUP BY c.mto_cuota;

     SELECT decode(p_tip_operacion, 'A', 'ALTA', 'M', 'MODIFICACION', 'C', 'CANCELACION ANTICIPADA', 'R', 'REFUERZO', 'T', 'FINALIZADO')
       INTO v_titulo
       FROM dual;

     SELECT decode(p_tip_operacion, 'A', 'la solicitud', 'M', 'la modificacion', 'C', 'la cancelacion anticipada', 'R', 'el refuerzo', 'T', 'el pago total')
       INTO v_descripcion
       FROM dual;

     v_cabecera := 'Estimado Usuario:<br><p>'||
                   fug_obt_pardinamico('NOM_BANCO')||' le comunica que se ha registrado '||v_descripcion||' de su ahorro programado.<p>';
     v_cabecera := v_cabecera ||
                   paw_pro.fu_not_titulo('AHORRO PROGRAMADO') || -- titulo
                   paw_pro.fu_not_titulo2(v_titulo) || -- subtitulo
                   paw_pro.fu_not_ini_tabla || -- inicio tabla
                   paw_pro.fu_not_ini_tab_cuerpo; -- inicio tbody

     v_pie := paw_pro.fu_not_fin_tab_cuerpo || -- fin tbody
              paw_pro.fu_not_fin_tabla; -- fin table

     SELECT decode(rg_cta_plazo.cod_moneda, 'GS', 600, 100)
       INTO v_moneda
       FROM dual;
     IF p_tip_operacion = 'R' THEN -- refuerzo
        v_detalle := paw_pro.fu_not_row_tag('Nro. Cuenta', rg_cta_plazo.nro_cuenta)
                     || paw_pro.fu_not_row_tag('Mi Objetivo', rg_cta_plazo.denominacion)
                     || paw_pro.fu_not_row_tag('Cuenta Debito', nvl(p_nro_cta_debito, rg_cta_plazo.nro_cta_capitalizacion))
                     || paw_pro.fu_not_row_tag('Monto Refuerzo', rg_cta_plazo.cod_moneda ||' '|| paw_not.lf_obt_mto_formateado(nvl(p_monto, v_mto_cuota), v_moneda))
                     || paw_pro.fu_not_row_tag('Plazo', v_plazo||' meses')
                     || paw_pro.fu_not_row_tag('Fecha Operacion', to_char(sysdate, 'dd/mm/yyyy'));
     ELSE
        v_detalle := paw_pro.fu_not_row_tag('Nro. Cuenta', rg_cta_plazo.nro_cuenta)
                     || paw_pro.fu_not_row_tag('Mi Objetivo', rg_cta_plazo.denominacion)
                     || paw_pro.fu_not_row_tag('Cuenta Debito', rg_cta_plazo.nro_cta_capitalizacion)
                     || paw_pro.fu_not_row_tag('Monto Cuota', rg_cta_plazo.cod_moneda ||' '|| paw_not.lf_obt_mto_formateado(v_mto_cuota, v_moneda))
                     || paw_pro.fu_not_row_tag('Fecha Vencimiento', replace(to_char(rg_cta_plazo.fec_vencimiento, 'month/yyyy'), ' ', ''))
                     || paw_pro.fu_not_row_tag('Plazo', v_plazo||' meses')
                     || paw_pro.fu_not_row_tag('Tasa', paw_uti.lf_for_money(rg_cta_plazo.val_tasa)||'%')
                     || paw_pro.fu_not_row_tag('Periodo Debito', fue_obt_sig_refcodes('FEC_DEB_AHO_PROGRAMADO', rg_cta_plazo.per_debito));
     END IF;
     RETURN v_cabecera || v_detalle || v_pie;
  END;

  PROCEDURE pr_env_contrato(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE) IS
     v_dir_correo ba_mails.dir_correo%TYPE;
     v_data       bw_archivos.contenido%TYPE;
     v_mime       bw_archivos.mim_type%TYPE;
     v_filename   bw_archivos.nombre%TYPE;
     v_membrete   VARCHAR2(3000);

  BEGIN
     v_dir_correo := fug_obt_dir_mail_per(fug_obt_cli_principal(p_nro_cuenta));

     SELECT utl_compress.lz_uncompress(a.contenido), a.mim_type, a.nombre
       INTO v_data, v_mime, v_filename
       FROM (SELECT *
               FROM bw_archivos a
              WHERE a.cod_persona = '11198'
                AND a.cod_tip_operacion = '125'
              ORDER BY a.nro_documento DESC) a
      WHERE rownum = 1;

     -- envio de mail con adjunto
     v_membrete := fug_gen_template('M');
     it_mail.mail_attach_blob(fug_obt_dir_correo, v_dir_correo,
                              'Notificaciones',
                              v_membrete||
                              lf_obt_det_pro_notificacion(p_nro_cuenta, 'A') ||
                              fug_gen_template('F') || fug_gen_template('P'),
                              v_data,
                              'text/html',
                              v_mime,
                              v_filename);
  EXCEPTION
     WHEN OTHERS THEN
        pr_ins_log_error(p_nro_cuenta, 0, 0, 'PAA_PRO.PR_ENV_CONTRATO', sqlerrm);
  END;
  --
  PROCEDURE pr_gen_aho_programado(p_mto_cuota      IN ah_pro_cuotas.mto_cuota%TYPE,
                                  p_per_debito     IN number,--periodo de debito AP
                                  p_plazo          IN number, -- en meses
                                  p_nro_cta_debito IN ah_cta_plazos.nro_cta_capitalizacion%TYPE,
                                  p_meta           IN ah_cta_plazos.denominacion%TYPE,
                                  p_cod_canal      IN ge_canales.cod_canal%TYPE,
                                  p_nro_cuenta     OUT ah_cta_plazos.nro_cuenta%TYPE,
                                  p_cod_error      OUT number) IS

    v_cod_persona     ba_personas.cod_persona%TYPE;
    v_nro_cuenta      ge_cuentas.nro_cuenta%TYPE;
    v_cod_oficina     ge_clientes.cod_oficina%TYPE;
    v_denominacion    ah_cta_plazos.denominacion%TYPE;
    v_fec_apertura    ah_cta_plazos.fec_vencimiento%TYPE := pag_cal.fu_obt_fec_actual(3);
    v_fec_vencimiento ah_cta_plazos.fec_vencimiento%TYPE;
    v_cod_modulo      ah_cta_plazos.cod_modulo%TYPE := 3;
    v_cod_modalidad   ah_cta_plazos.cod_modalidad%TYPE := 38;
    v_val_tasa        ah_cta_plazos.val_tasa%TYPE;
    v_cod_moneda      ba_monedas.cod_moneda%TYPE;
    v_mto_tot_ahor    NUMBER(18,2) := 0;
    v_plz_min         NUMBER(5);
    v_plz_max         NUMBER(5);
    v_mto_cuota       NUMBER(18,2) := 0;
    v_redondeo        NUMBER(2);
    v_can_dias        NUMBER(5);
    rv_aplazo         ah_cta_plazos%ROWTYPE;
    rv_apcuotas       ah_pro_cuotas%ROWTYPE;
    v_programa        varchar2(60) := 'PAA_PRO.PR_GEN_AHO_PROGRAMADO';
    v_fecha           date := pag_Cal.FU_OBT_FEC_ACTUAL(1);
    v_edad            number;
    v_fec_nacimiento  ba_per_fisicas.fec_nacimiento%type;

  BEGIN
    BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;

    -- Recuperar moneda y titular de la cuenta
    BEGIN
      SELECT a.cod_moneda, fug_obt_cli_principal(a.nro_cuenta)
        INTO v_cod_moneda, v_cod_persona
        FROM ge_cuentas a
       WHERE a.nro_cuenta = p_nro_cta_debito;
    EXCEPTION
      WHEN others THEN
        raise_application_error(-20000,'Error en '||v_programa||' - Cuenta '||p_nro_cta_debito||' Inexistente.'||' # '||sqlerrm);
    END;

    if nvl(fu_es_conjunta(p_nro_cta_debito), 'N') = 'S' then
      raise_application_error(-20001,'No se puede utilizar cuentas conjuntas'||' - '||v_programa);
    end if;

    -- Recuperar oficina del cliente VERIFICAR OFICINA
    BEGIN
      v_cod_oficina := fug_obt_ofi_cliente(v_cod_persona);
    EXCEPTION
      WHEN OTHERS THEN
        v_cod_oficina := 31;
    END;

    v_can_dias        := p_plazo * 30;
    v_redondeo        := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad, v_cod_moneda);
    v_mto_cuota       := round(p_mto_cuota,v_redondeo);
    v_fec_vencimiento := fu_obt_fec_vencimiento(v_fec_apertura, p_plazo, v_cod_oficina);

    -- Validaciones de monto minimo para crear ahorro programado
    IF nvl(v_mto_cuota, 0) < nvl(fug_obt_pardinamico('MTO_MIN_CUO_AHO_PROGRAMADO', v_cod_modulo, v_cod_modalidad, v_cod_moneda), 0)  THEN
       raise_application_error(-20002,'Monto no valido o menor al parametro MTO_MIN_CUO_AHO_PROGRAMADO.'||' - '||v_programa);
    END IF;

    pr_obt_plz_pizarra(v_cod_modulo,v_cod_modalidad,v_cod_moneda,null,v_plz_min,v_plz_max);

    IF nvl(v_can_dias, 0) not between v_plz_min and v_plz_max THEN
       raise_application_error(-20003,'Plazo no valido o fuera de rango. Verificar Pizarra de Productos.'||' - '||v_programa);
    END IF;

    v_mto_tot_ahor := v_mto_cuota * p_plazo;
    -- Recuperar Tasa
    v_val_tasa     := paw_bas.fu_obt_tas_pizarra(p_plazo, v_mto_tot_ahor, v_cod_moneda, v_cod_modulo, v_cod_modalidad, null, 1 /*mensual*/);

    IF nvl(v_val_tasa, 0) = 0 THEN
       raise_application_error(-20004,'No se encontro Tasa.');
    END IF;

    -- Realizar en procedimientos los inserts
    v_denominacion := upper(p_meta);
    v_nro_cuenta   := fug_obt_sig_nro_cuenta(v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_moneda, v_cod_persona);

    -- Verifica si es menor de edad --
    begin
     select a.fec_nacimiento
       into v_fec_nacimiento
       from ba_per_fisicas a
      where a.cod_persona = v_cod_persona;
    exception
      when others then
        v_fec_nacimiento := trunc(sysdate);
    end;

    v_edad := trunc(MONTHS_BETWEEN(v_fecha, v_fec_nacimiento) / 12);

    if v_edad < nvl(to_number(fug_obt_pardinamico('BA_MAY_EDAD')), 18) then
      pr_ins_log_error(p_nro_cta_debito,0,0,'paa_pro.pr_gen_aho_programado','No se puede crear cuenta de ahorro programado a un menor de edad. Persona: '||v_cod_persona);
      raise_application_error(-20060,'No se puede crear cuenta de ahorro programado a un menor de edad. Persona: '||v_cod_persona||' - Programa: '||v_programa);
    else
      -- Insertar en GE_CTA_CLIENTES
      pr_ins_cta_cliente(v_cod_persona,
                         v_nro_cuenta,
                         substr(v_nro_cuenta,-1,1),
                         v_cod_oficina,
                         v_cod_modulo,
                         v_cod_modalidad,
                         'P');

      -- Insertar en AH_CTA_PLAZOS
      rv_aplazo.nro_cuenta             := v_nro_cuenta;
      rv_aplazo.dig_verificador        := substr(v_nro_cuenta,-1,1);
      rv_aplazo.cod_modulo             := v_cod_modulo;
      rv_aplazo.cod_modalidad          := v_cod_modalidad;
      rv_aplazo.cod_oficina            := v_cod_oficina;
      rv_aplazo.cod_moneda             := v_cod_moneda;
      rv_aplazo.denominacion           := v_denominacion;
      rv_aplazo.fec_apertura           := v_fec_apertura;
      rv_aplazo.fec_vencimiento        := v_fec_vencimiento;
      rv_aplazo.capital                := 0;
      rv_aplazo.val_tasa               := v_val_tasa;
      rv_aplazo.tip_capitalizacion     := 99; -- Al Vencimiento
      rv_aplazo.nro_cta_capitalizacion := p_nro_cta_debito;
      rv_aplazo.est_batch              := 'A';
      rv_aplazo.estado                 := 'A'; -- Se crea la cuenta en estado Abierto
      rv_aplazo.cod_canal              := p_cod_canal;
      rv_aplazo.sal_tot_batch          := 0;
      rv_aplazo.sal_total              := 0;
      rv_aplazo.per_debito             := p_per_debito; -- para poder recuperar descripcion en base a val_minimo
      pr_ins_cta_aho_programado(rv_aplazo);

      -- Insertar en AH_PRO_CUOTAS
      rv_apcuotas.nro_cuenta      := v_nro_cuenta;
      rv_apcuotas.mto_cuota       := v_mto_cuota;
      rv_apcuotas.fec_vencimiento := v_fec_apertura;
      pr_ins_cuo_ahorro(rv_apcuotas,p_plazo,v_val_tasa,v_cod_oficina,v_cod_moneda,p_per_debito);

      -- Cobramos la primera cuota
      pr_cob_cuota(v_nro_cuenta, 1);

      -- se devuelve nro_cuenta
      p_nro_cuenta := v_nro_cuenta;
      pr_env_contrato(v_nro_cuenta);
    end if;
  END;
  --
  PROCEDURE pr_ins_cta_cliente(p_cod_persona     IN ge_cta_clientes.cod_persona%TYPE,
                               p_nro_cuenta      IN ge_cta_clientes.nro_cuenta%TYPE,
                               p_dig_verificador IN ge_cta_clientes.dig_verificador%TYPE,
                               p_cod_oficina     IN ge_cta_clientes.cod_oficina%TYPE,
                               p_cod_modulo      IN ge_cta_clientes.cod_modulo%TYPE,
                               p_cod_modalidad   IN ge_cta_clientes.cod_modalidad%TYPE,
                               p_relacion        IN ge_cta_clientes.relacion%TYPE) IS
  BEGIN
    INSERT INTO ge_cta_clientes
       (cod_persona, nro_cuenta, dig_verificador, cod_oficina, cod_modulo, cod_modalidad, relacion)
    VALUES
       (p_cod_persona, p_nro_cuenta, p_dig_verificador, p_cod_oficina, p_cod_modulo, p_cod_modalidad, p_relacion);
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20005, 'Error al insertar datos en GE_CTA_CLIENTES. Persona: '||p_cod_persona||' Cuenta: '||p_nro_cuenta||SQLERRM);
  END;
  --
  PROCEDURE pr_ins_cta_aho_programado(rp_aplazo IN ah_cta_plazos%ROWTYPE) IS
    v_tabla VARCHAR2(50);
  BEGIN
    v_tabla := 'AH_CTA_PLAZOS';
    INSERT INTO ah_cta_plazos
      (nro_cuenta, dig_verificador, cod_modulo, cod_modalidad, cod_oficina,
       cod_moneda, denominacion, can_fir_registradas, can_fir_requeridas, fec_apertura,
       fec_vencimiento, capital, tas_personalizada, cod_tasa, tip_capitalizacion,
       ren_automatica, nro_cta_capitalizacion, cod_usu_promotor, est_batch, estado,
       fec_ult_movimiento, hor_ult_movimiento, fec_cam_estado, fec_ult_capitalizacion, aut_pendiente,
       sal_blo_batch, sal_bloqueado, sal_ret_batch, sal_retenido, sal_tot_batch,
       sal_total, tra_prohibida, nro_cta_renovada, cod_canal, cod_campana,
       reg_firma, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion,
       fec_pago, cod_cau_cancelacion, val_tasa, per_debito)
    VALUES
      (rp_aplazo.nro_cuenta, rp_aplazo.dig_verificador, rp_aplazo.cod_modulo, rp_aplazo.cod_modalidad, rp_aplazo.cod_oficina,
       rp_aplazo.cod_moneda, rp_aplazo.denominacion, rp_aplazo.can_fir_registradas, rp_aplazo.can_fir_requeridas, rp_aplazo.fec_apertura,
       rp_aplazo.fec_vencimiento, rp_aplazo.capital, nvl(rp_aplazo.tas_personalizada,'N'), rp_aplazo.cod_tasa, rp_aplazo.tip_capitalizacion,
       nvl(rp_aplazo.ren_automatica,'N'), rp_aplazo.nro_cta_capitalizacion, rp_aplazo.cod_usu_promotor, rp_aplazo.est_batch, rp_aplazo.estado,
       rp_aplazo.fec_ult_movimiento, rp_aplazo.hor_ult_movimiento, rp_aplazo.fec_cam_estado, rp_aplazo.fec_ult_capitalizacion, nvl(rp_aplazo.aut_pendiente,'N'),
       nvl(rp_aplazo.sal_blo_batch,0), nvl(rp_aplazo.sal_bloqueado,0), nvl(rp_aplazo.sal_ret_batch,0), nvl(rp_aplazo.sal_retenido,0), nvl(rp_aplazo.sal_tot_batch,0),
       nvl(rp_aplazo.sal_total,0), nvl(rp_aplazo.tra_prohibida,'N'), rp_aplazo.nro_cta_renovada, rp_aplazo.cod_canal, rp_aplazo.cod_campana,
       rp_aplazo.reg_firma, rp_aplazo.usu_insercion, rp_aplazo.fec_insercion, rp_aplazo.usu_modificacion, rp_aplazo.fec_modificacion,
       rp_aplazo.fec_pago, rp_aplazo.cod_cau_cancelacion, rp_aplazo.val_tasa, rp_aplazo.per_debito);

    -- para indicar que la cuenta esta habilitada para refuerzos
    v_tabla := 'GE_CTA_DAT_ADICIONALES';
    INSERT INTO ge_cta_dat_adicionales
       (nro_cuenta, parametro, val_parametro)
    VALUES
       (rp_aplazo.nro_cuenta, 'HAB_REFUERZO', nvl(trim(fug_obt_pardinamico('AHO_PRO_REFUERZO')), 'S'));
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20006, 'Error al insertar datos en '||v_tabla||'. Cuenta = '||rp_aplazo.nro_cuenta||' '||SQLERRM);
  END;

  PROCEDURE pr_ins_cuo_ahorro(rp_apcuota    IN ah_pro_cuotas%ROWTYPE,
                              p_plazo       IN NUMBER,
                              p_tasa        IN NUMBER,
                              p_cod_oficina IN ah_cta_plazos.cod_oficina%TYPE,
                              p_cod_moneda  IN ah_cta_plazos.cod_moneda%TYPE,
                              p_periodo     IN ah_cta_plazos.per_debito%TYPE) IS

    v_fec_vto_cuota      ah_cta_plazos.fec_vencimiento%TYPE;
    v_fec_vto            ah_cta_plazos.fec_vencimiento%TYPE;
    v_fec_actual         DATE := pag_cal.FU_OBT_FEC_ACTUAL(3);
    v_mto_interes        NUMBER;
    v_fec_apertura       DATE;
    v_can_dias           NUMBER;
    v_tip_capitalizacion NUMBER(1) := 1;--Mensual para generar cuotas
    v_can_cuotas         NUMBER(3);
    v_nro_cuota          NUMBER(3);
    v_numero             NUMBER(3) := 0;
    v_programa           varchar2(60) := 'PAA_PRO.PR_INS_CUO_AHORRO';

  BEGIN
    v_can_dias        := p_plazo * 30;
    v_fec_apertura    := rp_apcuota.fec_vencimiento;
    v_fec_vto_cuota   := to_date(p_periodo||'/'||to_char(v_fec_actual,'mm/yyyy'), 'dd/mm/yyyy');
    v_can_cuotas      := trunc(v_can_dias / (v_tip_capitalizacion *30));

    If v_fec_vto_cuota > v_fec_apertura + v_can_dias Then
       v_can_cuotas := 1;
    End If;
    v_nro_cuota     := 1;

    LOOP
      v_nro_cuota := v_nro_cuota + 1;
      v_fec_vto   := v_fec_vto_cuota;
      v_numero    := v_numero + 1;
      IF v_numero > 1 THEN
        -- Debe ser una cuota por mes
        v_fec_vto_cuota := add_months(v_fec_vto_cuota,1);
      END IF;
      v_mto_interes := 0;

      -- Insertar cuotas
      BEGIN
        INSERT INTO ah_pro_cuotas
          (nro_cuenta, nro_cuota, mto_cuota,
           fec_vencimiento, mto_interes, estado, periodo)
        VALUES
          (rp_apcuota.nro_cuenta, v_numero, rp_apcuota.mto_cuota,
           v_fec_vto_cuota, v_mto_interes, 'E', p_periodo);
      EXCEPTION
        WHEN OTHERS THEN
          pr_ins_log_error(rp_apcuota.nro_cuenta, 0, 0, v_programa, substr(sqlerrm,1,300));
          raise_application_error(-20007, 'Error al insertar datos en AH_PRO_CUOTAS. Cuenta: '||rp_apcuota.nro_cuenta||SQLERRM);
      END;
      IF v_nro_cuota > v_can_cuotas THEN
        exit;
      END IF;
    END LOOP;
    --- Actualizamos la fecha vencimiento de la cta de ah. programado ---
    ----------------------------  AIU-1573  -----------------------------
    declare
      v_fecha ah_cta_plazos.fec_vencimiento%type;
    begin

      v_fecha := pag_cal.FU_OBT_FEC_HABIL(add_months(v_fec_vto_cuota,1),1,p_cod_oficina);

      update ah_cta_plazos a
         set a.fec_vencimiento = v_fecha
       where a.nro_cuenta = rp_apcuota.nro_cuenta;
    exception
      when others then
        pr_ins_log_error(rp_apcuota.nro_cuenta, 0, 0, v_programa, 'Error en actualizar fecha vencimiento de la cta ah. prog. - '||substr(sqlerrm,1,300));
    end;
  END;
  --
  FUNCTION fu_obt_dia_debito(p_fecha IN DATE) RETURN VARCHAR2 IS
    v_per_debito VARCHAR2(2);
    v_num_dia    NUMBER;
  BEGIN
    SELECT extract(day from p_fecha)
      INTO v_num_dia
      FROM dual;

    CASE
      WHEN v_num_dia < 11 THEN
        v_per_debito := '1';
      WHEN v_num_dia < 21 THEN
        v_per_debito := '11';
      ELSE
        v_per_debito := '21';
    END CASE;
    RETURN v_per_debito;
  END;
  --
  FUNCTION fu_obt_ult_dia_debito(p_cod_oficina IN ba_oficinas.cod_oficina%TYPE,
                                 p_periodo     IN ah_cta_plazos.per_debito%TYPE) RETURN DATE IS
     v_fecha    DATE;
     v_mes_anho VARCHAR2(8) := to_char(sysdate, 'mm/yyyy');
  BEGIN
     CASE p_periodo
        WHEN 1 THEN
           v_fecha := pag_cal.fu_obt_fec_ant_hab(to_date('11/'||v_mes_anho, 'dd/mm/yyyy'), p_cod_oficina);
        WHEN 11 THEN
           v_fecha := pag_cal.fu_obt_fec_ant_hab(to_date('21/'||v_mes_anho, 'dd/mm/yyyy'), p_cod_oficina);
        WHEN 21 THEN
           SELECT c.ult_dia_mes_habil
             INTO v_fecha
             FROM ge_calendarios c
            WHERE c.cod_modulo = 3;
     END CASE;
     RETURN v_fecha;
  END;
  --
  PROCEDURE pr_cob_cuota(p_nro_cuenta IN ah_pro_cuotas.nro_cuenta%TYPE,
                         p_nro_cuota  IN ah_pro_cuotas.nro_cuota%TYPE) IS

    v_nro_cta_credito ge_movimientos.nro_cuenta%TYPE;
    v_nro_cta_debito  ge_movimientos.nro_cuenta%TYPE;
    v_monto           ge_movimientos.monto%TYPE;
    v_cod_mod_padre   ge_movimientos.cod_modulo%TYPE := 3;
    v_cod_mad_padre   ge_movimientos.cod_modalidad%TYPE := 38;
    v_cod_tra_padre   ge_movimientos.cod_transaccion%TYPE := 2203;
    v_cod_modulo      ge_movimientos.cod_modulo%TYPE;
    v_cod_modalidad   ge_movimientos.cod_modalidad%TYPE;
    v_cod_moneda      ge_movimientos.cod_moneda%TYPE;
    v_cod_usuario     ge_movimientos.cod_usuario%TYPE := USER;
    v_cod_ofi_credito ge_movimientos.cod_oficina%TYPE;
    v_cod_ofi_origen  ge_movimientos.cod_oficina%TYPE;
    v_fec_valor       ge_movimientos.fec_valor%TYPE := trunc(sysdate);
    v_fec_proceso     ge_movimientos.fecha%TYPE := pag_cal.fu_obt_fec_actual(v_cod_mod_padre);
    v_hor_actual      ge_movimientos.hora%TYPE := to_char(SYSDATE, 'HH24:MI:SS');
    v_nro_secuencia   ge_movimientos.nro_secuencia%TYPE;
    v_per_debito      ah_cta_plazos.per_debito%TYPE;
    v_act_operacion   VARCHAR2(1) := 'N';
    v_estado          ah_cta_plazos.estado%TYPE;
    v_fec_apertura    ah_cta_plazos.fec_apertura%TYPE;
    v_fec_vencimiento ah_cta_plazos.fec_vencimiento%TYPE;
    v_can_intentos    NUMBER := 1;
    v_err_code        NUMBER := 0;
    v_err_movimiento  VARCHAR2(1000);
    v_savepoint       VARCHAR2(50);
    v_nvo_estado      VARCHAR2(1) := NULL; -- cambio de estado de cuenta
    v_procesa         VARCHAR2(1) := 'N';
    v_sal_disponible  NUMBER(18, 2);
    v_sal_acumulado   ah_cta_plazos.sal_total%TYPE;
    v_nocturno        varchar2(1);

  BEGIN
    v_msg_error := null;
    BEGIN
      -- datos del ahorro
      SELECT p.nro_cuenta, p.nro_cta_capitalizacion, c.mto_cuota, p.cod_moneda, p.cod_modulo, p.cod_modalidad, p.cod_oficina, p.per_debito, p.estado, p.fec_apertura, p.fec_vencimiento
        INTO v_nro_cta_credito, v_nro_cta_debito, v_monto, v_cod_moneda, v_cod_modulo, v_cod_modalidad, v_cod_ofi_credito, v_per_debito, v_estado, v_fec_apertura, v_fec_vencimiento
        FROM ah_cta_plazos p, ah_pro_cuotas c
       WHERE p.nro_cuenta = p_nro_cuenta
         AND p.cod_modulo = v_cod_mod_padre
         AND p.cod_modalidad = v_cod_mad_padre
         AND p.nro_cuenta = c.nro_cuenta
         AND c.nro_cuota = p_nro_cuota
         AND p.estado in ('N','A')
         AND c.estado <> 'P';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_msg_error := substr( '-20009 Error Cobro Cuota '||p_nro_cuota||'. Cuenta: '||p_nro_cuenta||' '||'No recupera datos de la Cuota-AP',1,300);
        raise_application_error(-20009, 'Error al cobrar cuota '||p_nro_cuota||'. Cuenta: '||p_nro_cuenta||' '||SQLERRM);
       when others then
        v_msg_error := substr( '-20059 Error Cobro Cuota '||p_nro_cuota||'. Cuenta: '||p_nro_cuenta||' '||SQLERRM,1,300);
        raise_application_error(-20059, 'Error al cobrar cuota '||p_nro_cuota||'. Cuenta: '||p_nro_cuenta||' '||SQLERRM);
    END;
    v_cod_ofi_origen := fug_obt_ofi_usuario(v_cod_usuario);

    -- verificacion operacion debito
    pag_cta.pr_ver_operacion(v_nro_cta_debito, v_cod_tra_padre, v_cod_mod_padre, v_cod_mad_padre, 'D', v_cod_moneda, v_monto, v_cod_ofi_origen, v_cod_modulo, v_cod_modalidad, v_nvo_estado, v_sal_disponible, v_procesa, 503);
    IF pag_cta.g_cod_error <> 0 OR v_procesa = 'N' THEN
       v_msg_error := substr( '-20010 No se puede debitar '||v_monto||' de '||v_nro_cta_debito||'. '||pag_cta.g_msj_error,1,300);
       raise_application_error(-20010, 'No se puede debitar '||v_monto||' de '||v_nro_cta_debito||'. '||pag_cta.g_msj_error);
    END IF;

    -- seteo de variables para movimiento
    v_savepoint := 'sp_'||p_nro_cuenta||'_'||p_nro_cuota;
    pag_cta.pr_set_variables(v_cod_usuario, v_fec_valor, v_cod_tra_padre, 'N', 'N', v_nro_secuencia, NULL, v_cod_ofi_origen, v_cod_mod_padre, v_cod_mad_padre);
    -- buscamos segundo disponible para movimientos
    v_hor_actual := fug_obt_hor_disponible(v_fec_proceso, v_hor_actual, v_cod_usuario, 'N');

    WHILE v_act_operacion = 'N' AND v_can_intentos <= 5 LOOP
       -- para safe rollback
       prg_cre_savepoint(v_savepoint);
       BEGIN
         -- Si el estado esta Abierto actualizar de fec_vencimiento
         v_nro_secuencia  := 0;
         ----------- AUI-1903 -----------
         pr_mov_nocturno(v_nocturno);
         ---------------------------------
         -- procesar debito
         pag_cta.pr_act_operacion(v_nro_cta_debito, v_hor_actual, 'D', v_cod_moneda, v_monto, v_cod_tra_padre, 503, v_nro_cta_credito, NULL, v_cod_ofi_origen, v_cod_mod_padre, v_cod_mad_padre, NULL, NULL, 'Debito cuota ' || p_nro_cuota || ' ahorro programado', 'N', v_nro_secuencia, v_fec_valor);
         v_err_code       := pag_cta.g_cod_error;
         v_err_movimiento := substr(pag_cta.g_msj_error, 1, 1000);
         -- si no hubo error procesamos el credito
         IF nvl(v_err_code, 0) = 0 THEN
            pag_cta.pr_act_operacion(v_nro_cta_credito, v_hor_actual, 'C', v_cod_moneda, v_monto, v_cod_tra_padre, 602, v_nro_cta_credito, NULL, v_cod_ofi_origen, v_cod_mod_padre, v_cod_mad_padre, NULL, NULL, 'Credito cuota '||p_nro_cuota||' ahorro programado', 'N', v_nro_secuencia, v_fec_valor);
            v_err_code       := pag_cta.g_cod_error;
            v_err_movimiento := substr(pag_cta.g_msj_error, 1, 1000);
         ELSIF v_err_code IN (25, 29, 31, 36) THEN
            -- sin saldo suficiente, no se necesita reintentar
            v_can_intentos := 5;
         END IF;
       EXCEPTION
          WHEN OTHERS THEN
             v_err_code       := sqlcode;
             v_err_movimiento := substr(sqlerrm, 1, 1000);
       END;

     -- verificamos si se pudo procesar
       IF nvl(v_err_code, 0) <> 0 THEN
          -- deshacemos cualquier transaccion previa
          prg_rol_savepoint(v_savepoint);
          -- reintento con nueva hora
          v_hor_actual   := fug_obt_hor_disponible(v_fec_proceso, v_hor_actual, v_cod_usuario, 'N');
          v_can_intentos := v_can_intentos + 1;
       ELSE
          v_act_operacion := 'S';
          -- actualizacion capital de ahorro
          UPDATE ah_cta_plazos c
             SET c.capital = c.capital + v_monto
           WHERE c.nro_cuenta = v_nro_cta_credito;
          BEGIN
            SELECT a.sal_total
              INTO v_sal_acumulado
              FROM ah_cta_plazos a
             WHERE a.nro_cuenta = v_nro_cta_credito;
          EXCEPTION
            WHEN no_data_found THEN
              v_msg_error := substr( '-20011 Error al obtener saldo de '||v_nro_cta_credito||'. ',1,300);
              raise_application_error(-20011,'Error al obtener saldo de '||v_nro_cta_credito);
            when others then
              v_msg_error := substr( '-20066 Error al obtener saldo de '||v_nro_cta_credito||'. '||sqlerrm,1,300);
              raise_application_error(-20066,'Error al obtener saldo de '||v_nro_cta_credito||' - '||sqlerrm);

          END;
          -- actualizacion estado cuota
          UPDATE ah_pro_cuotas c
             SET c.estado = 'P',
                 c.fec_ult_pago = v_fec_proceso,
                 c.sal_acumulado = v_sal_acumulado
           WHERE c.nro_cuenta = v_nro_cta_credito
             AND c.nro_cuota = p_nro_cuota;

       END IF;
    END LOOP;
    IF v_act_operacion = 'N' THEN
       v_msg_error := substr( '-20012 '||v_err_movimiento,1,300);
       raise_application_error(-20012, v_err_movimiento);
    END IF;
  END;

  PROCEDURE pr_deb_automatico(p_nro_cuenta IN ah_cta_plazos.nro_cuenta%TYPE DEFAULT NULL) IS
    v_fecha          ge_calendarios.fec_actual%TYPE;
    v_cod_modulo     ge_modalidades.cod_modulo%TYPE := 3;
    v_cod_modalidad  ge_modalidades.cod_modalidad%TYPE := 38;
    v_mto_cuota      ah_pro_cuotas.nro_cuota%TYPE;
    v_mto_deu_deb    ge_cuentas.sal_contable%TYPE;
    v_sal_disponible ge_cuentas.sal_contable%TYPE;
    v_nro_cuenta_ant ah_cta_plazos.nro_cuenta%TYPE;
    v_error          VARCHAR2(10);
    v_mensaje        VARCHAR2(1000);
    v_programa       VARCHAR2(60) := 'PAA_PRO.PR_DEB_AUTOMATICO';

    CURSOR c_cuotas is
      -- Cob Cuotas
      SELECT a.nro_cuenta, a.nro_cuota, a.mto_cuota, a.fec_vencimiento, b.nro_cta_capitalizacion, b.cod_moneda
        FROM ah_pro_cuotas a, ah_cta_plazos b
       WHERE a.estado = 'V'-- Ver estado A vencido
         AND a.nro_cuenta = b.nro_cuenta
         AND b.estado != 'C'
         AND b.cod_modalidad = v_cod_modalidad
         AND a.periodo = paa_pro.fu_obt_dia_debito(pag_cal.FU_OBT_FEC_ACTUAL(3))
         AND a.tipo = 'C'
         AND (p_nro_cuenta IS NULL OR a.nro_cuenta = p_nro_cuenta)
         AND to_char(a.fec_vencimiento, 'yyyymm') = to_char(pag_cal.FU_OBT_FEC_ACTUAL(3), 'yyyymm')
       ORDER BY 1,2;

  BEGIN
    v_fecha          := pag_cal.FU_OBT_FEC_ACTUAL(v_cod_modulo);
    v_nro_cuenta_ant := 'x';

    FOR c IN c_cuotas LOOP
      -- Inicializar variables
      v_error          := NULL;
      v_mensaje        := NULL;
      v_mto_cuota      := NULL;
      v_mto_deu_deb    := NULL;
      v_sal_disponible := NULL;

      -- Recuperar datos de la cuenta de ahorro
      pag_cta.pr_obt_cuenta(c.nro_cta_capitalizacion);
      IF pag_cta.g_cod_error <> 0 THEN
         pr_ins_log_error(c.nro_cuenta,
                          c.mto_cuota,
                          0,
                          v_programa,
                          '#1'||' - '||substr(pag_cta.FU_OBT_MSJ_ERROR, 1, 299));
         GOTO siguiente_registro;
      END IF;
      -- Verificar monedas
      IF pag_cta.g_ctas.cod_moneda <> c.cod_moneda THEN -- Moneda Cta. Debito Vs Moneda Ahorro P
         pr_ins_log_error(c.nro_cuenta,
                          c.mto_cuota,
                          0,
                          v_programa,
                          '#2'||' - '||'Moneda del Ahorro diferente a la de la Cta Debito');
         GOTO siguiente_registro;
      END IF;

      -- Verificar si tiene el total de la cuota, para cta cte no contempla la linea de sobregiro.
      IF (nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0) < nvl(c.mto_cuota, 0)) THEN
         pr_ins_log_error(c.nro_cuenta,
                          c.mto_cuota,
                          nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0),
                          v_programa,
                          '#3'||' - '|| 'Saldo no cubre totalidad de la deuda');
         --- Solo se cobra si el saldo de la cuenta cubre toda la deuda
         GOTO siguiente_registro;
      END IF;

      -- Se cobra la cuota si esta ok
      BEGIN
      pr_cob_cuota(c.nro_cuenta,c.nro_cuota);
      commit;
      EXCEPTION
        WHEN OTHERS THEN
          pr_ins_log_error(c.nro_cuenta,
                           c.mto_cuota,
                           nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0),
                           v_programa,
                           substr( '#4'||' - '||'Error al cobrar cuota.'||v_msg_error,1,300));
          GOTO siguiente_registro;
      END;
      -- Siguiente registro
      <<siguiente_registro>>
      null;
    END LOOP;
    /**
      Actualiza la fecha vencimiento del ahorro programado - AIU-806
    **/
    lp_act_fec_vencimiento;

  END;

  FUNCTION fu_cal_interes(p_nro_cuenta IN ah_pro_cuotas.nro_cuenta%TYPE,
                          p_nro_cuota  IN ah_pro_cuotas.nro_cuota%TYPE,
                          p_mto_cuota  IN ah_pro_cuotas.mto_cuota%TYPE) RETURN NUMBER IS
    v_tasa          NUMBER;
    v_int_acumulado NUMBER;
    v_interes       NUMBER;
    v_mto_interes   NUMBER;
    v_redondeo      NUMBER(2) := 0;
    v_nro_cuota     ah_pro_cuotas.nro_cuota%TYPE;
    v_mto_cuota     ah_pro_cuotas.mto_cuota%TYPE;
    rg_ahorro       ah_cta_plazos%ROWTYPE;
  BEGIN
    pr_obt_dat_ahorro(p_nro_cuenta,rg_ahorro);
    v_redondeo      := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', rg_ahorro.cod_modulo, rg_ahorro.cod_modalidad, rg_ahorro.cod_moneda);
    v_nro_cuota     := p_nro_cuota;
    v_mto_cuota     := p_mto_cuota;
    v_tasa          := rg_ahorro.val_tasa;
    v_interes       := ((v_tasa/12)/100);
    v_int_acumulado := (power(1 + v_interes,v_nro_cuota) - 1);
    v_mto_interes   := round(v_mto_cuota * v_int_acumulado,v_redondeo);

    RETURN v_mto_interes;
  END;
  --
  PROCEDURE pr_obt_dat_ahorro(p_nro_cuenta  IN ah_pro_cuotas.nro_cuenta%TYPE,
                              rp_dat_ahorro OUT ah_cta_plazos%ROWTYPE) is

  BEGIN
    SELECT a.nro_cuenta, a.dig_verificador, a.cod_modulo, a.cod_modalidad, a.cod_oficina,
           a.cod_moneda, a.denominacion, a.can_fir_registradas, a.can_fir_requeridas, a.fec_apertura,
           a.fec_vencimiento, a.capital, a.tas_personalizada, a.cod_tasa, a.tip_capitalizacion,
           a.ren_automatica, a.nro_cta_capitalizacion, a.cod_usu_promotor, a.est_batch, a.estado,
           a.fec_ult_movimiento, a.hor_ult_movimiento, a.fec_cam_estado, a.fec_ult_capitalizacion, a.aut_pendiente,
           a.sal_blo_batch, a.sal_bloqueado, a.sal_ret_batch, a.sal_retenido, a.sal_tot_batch,
           a.sal_total, a.tra_prohibida, a.nro_cta_renovada, a.cod_canal, a.cod_campana,
           a.reg_firma, a.fec_pago, a.cod_cau_cancelacion, a.val_tasa, a.per_debito
      INTO rp_dat_ahorro.nro_cuenta, rp_dat_ahorro.dig_verificador, rp_dat_ahorro.cod_modulo, rp_dat_ahorro.cod_modalidad, rp_dat_ahorro.cod_oficina,
           rp_dat_ahorro.cod_moneda, rp_dat_ahorro.denominacion, rp_dat_ahorro.can_fir_registradas, rp_dat_ahorro.can_fir_requeridas, rp_dat_ahorro.fec_apertura,
           rp_dat_ahorro.fec_vencimiento, rp_dat_ahorro.capital, rp_dat_ahorro.tas_personalizada, rp_dat_ahorro.cod_tasa, rp_dat_ahorro.tip_capitalizacion,
           rp_dat_ahorro.ren_automatica, rp_dat_ahorro.nro_cta_capitalizacion, rp_dat_ahorro.cod_usu_promotor, rp_dat_ahorro.est_batch, rp_dat_ahorro.estado,
           rp_dat_ahorro.fec_ult_movimiento, rp_dat_ahorro.hor_ult_movimiento, rp_dat_ahorro.fec_cam_estado, rp_dat_ahorro.fec_ult_capitalizacion, rp_dat_ahorro.aut_pendiente,
           rp_dat_ahorro.sal_blo_batch, rp_dat_ahorro.sal_bloqueado, rp_dat_ahorro.sal_ret_batch, rp_dat_ahorro.sal_retenido, rp_dat_ahorro.sal_tot_batch,
           rp_dat_ahorro.sal_total, rp_dat_ahorro.tra_prohibida, rp_dat_ahorro.nro_cta_renovada, rp_dat_ahorro.cod_canal, rp_dat_ahorro.cod_campana,
           rp_dat_ahorro.reg_firma, rp_dat_ahorro.fec_pago, rp_dat_ahorro.cod_cau_cancelacion, rp_dat_ahorro.val_tasa, rp_dat_ahorro.per_debito
      FROM ah_cta_plazos a
     WHERE a.nro_cuenta = p_nro_cuenta;
  EXCEPTION
    WHEN no_data_found THEN
      raise_application_error(-20013, 'Numero de cuenta no existe');
  END;
  --
  PROCEDURE pr_act_dat_ahorro(p_nro_cuenta  IN ah_cta_plazos.nro_cuenta%TYPE,
                              p_meta        IN ah_cta_plazos.denominacion%TYPE DEFAULT NULL,
                              p_cta_debito  IN ah_cta_plazos.nro_cta_capitalizacion%TYPE DEFAULT NULL,
                              p_per_debito  IN ah_cta_plazos.per_debito%TYPE DEFAULT NULL) IS

  v_nro_cuenta ah_cta_plazos.nro_cuenta%TYPE;

  BEGIN
    IF p_meta IS NULL AND p_cta_debito IS NULL AND p_per_debito IS NULL THEN
      raise_application_error(-20014, 'Ingresar al menos un dato para modificar.');
    END IF;
    BEGIN
      SELECT a.nro_cuenta
        INTO v_nro_cuenta
        FROM ah_cta_plazos a
       WHERE a.nro_cuenta = p_nro_cuenta;
    EXCEPTION
      WHEN no_data_found THEN
        raise_application_error(-20015, 'Numero de Cuenta ' || p_nro_cuenta || ' no existe.');
    END;
    IF p_meta IS NOT NULL OR p_cta_debito IS NOT NULL OR p_per_debito IS NOT NULL THEN
      UPDATE ah_cta_plazos a
         SET a.denominacion = nvl(p_meta, a.denominacion),
             a.nro_cta_capitalizacion = nvl(p_cta_debito, a.nro_cta_capitalizacion),
             a.per_debito = nvl(p_per_debito, a.per_debito) --VERIFICAR cuando realizar el cambio para periodo de fecha
       WHERE a.nro_cuenta = p_nro_cuenta;
    END IF;
    IF p_per_debito IS NOT NULL THEN
       UPDATE ah_pro_cuotas c
          SET c.periodo = p_per_debito,
              c.fec_vencimiento = to_date(p_per_debito||'/'||to_char(c.fec_vencimiento,'MM/YYYY'),'DD/MM/YYYY')
        WHERE c.nro_cuenta = p_nro_cuenta
          AND c.periodo <> p_per_debito
          AND to_char(c.fec_vencimiento, 'yyyymm') > to_char(pag_cal.fu_obt_fec_actual(3), 'yyyymm');
    END IF;

  END;

  FUNCTION fu_val_mto_refuerzo(p_nro_cuenta IN ah_cta_plazos.nro_cuenta%TYPE,
                               p_monto      IN NUMBER) RETURN VARCHAR2 IS

    v_mto_maximo   NUMBER(18,2);
    v_sal_refuerzo NUMBER(18,2);
    v_dis_refuerzo NUMBER(18,2);
  BEGIN
     IF nvl(p_monto, 0) <= 0 THEN
        RETURN 'N';
     END IF;

     BEGIN
       SELECT SUM(CASE WHEN a.tipo = 'C' THEN a.mto_cuota ELSE 0 END), -- Max refuerzo
              SUM(CASE WHEN a.tipo = 'R' THEN a.mto_cuota ELSE 0 END)  -- Sum refuerzo
         INTO v_mto_maximo, v_sal_refuerzo
         FROM ah_pro_cuotas a
        WHERE a.nro_cuenta = p_nro_cuenta;
     EXCEPTION
       WHEN no_data_found THEN
         RETURN 'N';
     END;

     v_dis_refuerzo := v_mto_maximo - v_sal_refuerzo;
     IF (v_dis_refuerzo - p_monto) < 0 THEN
       RETURN 'N';
     END IF;

     RETURN 'S';
  END;

  FUNCTION fu_obt_fec_vencimiento(p_fec_apertura IN ah_cta_plazos.fec_apertura%TYPE,
                                  p_plazo        IN NUMBER,
                                  p_cod_oficina  IN ge_clientes.cod_oficina%TYPE) RETURN DATE IS

    v_fec_vencimiento ah_cta_plazos.fec_vencimiento%TYPE;
    v_can_dias        NUMBER(5);
    v_vto_dia_habil   VARCHAR2(1):= 'N';
    v_dia             VARCHAR2(15);

  BEGIN
    v_can_dias        := p_plazo * 30;
    v_fec_vencimiento := p_fec_apertura + v_can_dias;
    v_vto_dia_habil   := FUG_OBT_PARDINAMICO('VTO_HAB_CUPON', 3, 38, null);

    IF v_vto_dia_habil = 'S' THEN
     v_dia := RTRIM(UPPER(TO_CHAR(v_fec_vencimiento, 'day')));
     IF (v_dia) IN ('SABADO','SATURDAY','SÁBADO') or (v_dia) IN ('SUNDAY','DOMINGO') THEN
        v_fec_vencimiento := PAG_CAL.FU_OBT_FEC_SIG_HAB(v_fec_vencimiento, p_cod_oficina);
     END IF;
     --Verificar si es feriado
     IF fue_ctr_fec_feriado(v_fec_vencimiento, p_cod_oficina) THEN
        v_fec_vencimiento := PAG_CAL.FU_OBT_FEC_SIG_HAB(v_fec_vencimiento, p_cod_oficina);
     END IF;
    END IF;
    RETURN v_fec_vencimiento;
  END;

  FUNCTION fu_obt_cuota(p_nro_cuenta IN ah_pro_cuotas.nro_cuenta%TYPE, p_fecha IN DATE) RETURN NUMBER IS
    v_nro_cuota       ah_pro_cuotas.nro_cuota%TYPE;
    v_fec_apertura    ah_cta_plazos.fec_apertura%TYPE;
    v_fec_vencimiento ah_cta_plazos.fec_apertura%TYPE;
    v_fecha           DATE;

  BEGIN
    SELECT a.fec_apertura, a.fec_vencimiento
      INTO v_fec_apertura, v_fec_vencimiento
      FROM ah_cta_plazos a
     WHERE a.nro_cuenta = p_nro_cuenta;

    IF p_fecha BETWEEN v_fec_apertura AND v_fec_apertura+30 THEN
      v_fecha := add_months(v_fec_apertura,1);
    ELSIF p_fecha BETWEEN v_fec_vencimiento-30 AND v_fec_vencimiento THEN
      v_fecha := add_months(v_fec_vencimiento,-1);
    ELSE
      v_fecha := p_fecha;
    END IF;

    -- Cuotas
    SELECT MIN(a.nro_cuota)
      INTO v_nro_cuota
      FROM AH_PRO_CUOTAS a
     WHERE a.nro_cuenta = p_nro_cuenta
       AND to_char(a.fec_vencimiento, 'mmyyyy') = to_char(v_fecha, 'mmyyyy');
    RETURN v_nro_cuota;
  EXCEPTION
    WHEN no_data_found THEN
      raise_application_error(-20016, 'Error al obtener cuota.');
  END;
  --
  PROCEDURE pr_ins_ref_ahorro(p_nro_cuenta     IN ah_pro_cuotas.nro_cuenta%TYPE,
                              p_nro_cta_debito IN ge_cuentas.nro_cuenta%TYPE,
                              p_monto          IN ah_pro_cuotas.mto_cuota%TYPE) IS

    v_cod_mod_padre  ge_movimientos.cod_modulo%TYPE := 3;
    v_cod_mad_padre  ge_movimientos.cod_modalidad%TYPE := 38;
    v_cod_tra_padre  ge_movimientos.cod_transaccion%TYPE := 2204;
    v_cod_usuario    ge_movimientos.cod_usuario%TYPE := USER;
    v_cod_ofi_origen ge_movimientos.cod_oficina%TYPE;
    v_fec_valor      ge_movimientos.fec_valor%TYPE := trunc(sysdate);
    v_fec_proceso    ge_movimientos.fecha%TYPE := pag_cal.fu_obt_fec_actual(v_cod_mod_padre);
    v_hor_actual     ge_movimientos.hora%TYPE := to_char(SYSDATE, 'HH24:MI:SS');
    v_nro_secuencia  ge_movimientos.nro_secuencia%TYPE;
    v_act_operacion  VARCHAR2(1) := 'N';
    v_can_intentos   NUMBER := 1;
    v_err_code       NUMBER := 0;
    v_err_movimiento VARCHAR2(1000);
    v_savepoint      VARCHAR2(50);
    v_nvo_estado     VARCHAR2(1) := NULL; -- cambio de estado de cuenta
    v_procesa        VARCHAR2(1) := 'N';
    v_sal_disponible NUMBER(18, 2);
    v_max_cuota      NUMBER(3);
    v_mto_interes    NUMBER(18, 2);
    v_sal_acumulado  ah_cta_plazos.sal_total%TYPE;
    r_gcta           ah_cta_plazos%ROWTYPE;

  BEGIN
    IF fu_val_mto_refuerzo(p_nro_cuenta, p_monto) = 'N' THEN
      raise_application_error(-20017, 'Ha exedido el monto de refuerzo.');
    END IF;

    pr_obt_dat_ahorro(p_nro_cuenta, r_gcta);
    IF r_gcta.estado = 'A' THEN
      raise_application_error(-20018, 'Realizar refuerzo luego del 1ra Debito');
    END IF;

    v_cod_ofi_origen := fug_obt_ofi_usuario(v_cod_usuario);
    -- Verificar debito
    pag_cta.pr_ver_operacion(p_nro_cta_debito, v_cod_tra_padre, v_cod_mod_padre, v_cod_mad_padre, 'D',r_gcta.cod_moneda, p_monto, v_cod_ofi_origen, r_gcta.cod_modulo, r_gcta.cod_modalidad, v_nvo_estado, v_sal_disponible, v_procesa, 503);
    IF v_procesa = 'N' THEN
       raise_application_error(-20019, 'No se puede debitar '||p_monto||' de '||p_nro_cta_debito||'. '||pag_cta.g_msj_error);
    END IF;

    -- seteo de variables para movimiento
    v_savepoint := 'sp_'||p_nro_cuenta||'_refuerzo';
    pag_cta.pr_set_variables(v_cod_usuario, v_fec_valor, v_cod_tra_padre, 'N', 'N', v_nro_secuencia, NULL, v_cod_ofi_origen, v_cod_mod_padre, v_cod_mad_padre);
    -- buscamos segundo disponible para movimientos
    v_hor_actual := fug_obt_hor_disponible(v_fec_proceso, v_hor_actual, v_cod_usuario, 'N');
    --
    WHILE v_act_operacion = 'N' AND v_can_intentos <= 5 LOOP
       -- para safe rollback
       prg_cre_savepoint(v_savepoint);
       BEGIN
        v_nro_secuencia  := 0;
        -- procesar debito
        pag_cta.pr_act_operacion(p_nro_cta_debito, v_hor_actual, 'D', r_gcta.cod_moneda, p_monto, v_cod_tra_padre, 503, p_nro_cuenta, NULL, v_cod_ofi_origen, v_cod_mod_padre, v_cod_mad_padre, NULL, NULL, 'Debito Refuerzo ahorro programado', 'N', v_nro_secuencia, v_fec_valor);
        v_err_code       := pag_cta.g_cod_error;
        v_err_movimiento := substr(pag_cta.g_msj_error, 1, 1000);

        -- si no hubo error procesamos el credito
        IF nvl(v_err_code, 0) = 0 THEN
           pag_cta.pr_act_operacion(p_nro_cuenta, v_hor_actual, 'C', r_gcta.cod_moneda, p_monto, v_cod_tra_padre, 602, p_nro_cuenta, NULL, v_cod_ofi_origen, v_cod_mod_padre, v_cod_mad_padre, NULL, NULL, 'Credito Refuerzo ahorro programado', 'N', v_nro_secuencia, v_fec_valor);
           v_err_code       := pag_cta.g_cod_error;
           v_err_movimiento := substr(pag_cta.g_msj_error, 1, 1000);
           -- NO pag_cta.PR_ACT_SALDOS(v_nro_cta_credito,v_cod_mad_padre,v_cod_mod_padre,'C',v_mto_interes,'S',v_nro_cta_credito,0,'interes');
        ELSIF v_err_code IN (25, 29, 31, 36) THEN
           -- sin saldo suficiente, no se necesita reintentar
           v_can_intentos := 5;
        END IF;
       EXCEPTION
        WHEN OTHERS THEN
           v_err_code       := sqlcode;
           v_err_movimiento := substr(sqlerrm, 1, 1000);
       END;

     -- verificamos si se pudo procesar
       IF nvl(v_err_code, 0) <> 0 THEN
        -- deshacemos cualquier transaccion previa
        prg_rol_savepoint(v_savepoint);
        -- reintento con nueva hora
        v_hor_actual   := fug_obt_hor_disponible(v_fec_proceso, v_hor_actual, v_cod_usuario, 'N');
        v_can_intentos := v_can_intentos + 1;
       ELSE
          v_act_operacion := 'S';
          BEGIN
           SELECT MAX(a.nro_cuota)
             INTO v_max_cuota
             FROM ah_pro_cuotas a
            WHERE a.nro_cuenta = p_nro_cuenta;
          EXCEPTION
           WHEN no_data_found THEN
             raise_application_error(-20020, 'Error al obtener CUOTA. Cuenta: '||r_gcta.nro_cuenta||SQLERRM);
          END;

          -- actualizacion capital de ahorro
          UPDATE ah_cta_plazos c
             SET c.capital = c.capital + p_monto
           WHERE c.nro_cuenta = p_nro_cuenta;

          -- actualizacion estado cuota
          BEGIN
           SELECT a.sal_total
             INTO v_sal_acumulado
             FROM ah_cta_plazos a
            WHERE a.nro_cuenta = p_nro_cuenta;
          EXCEPTION
           WHEN no_data_found THEN
            raise_application_error(-20021,'Error al obtener saldo acumulado');
          END;

          BEGIN
           INSERT INTO ah_pro_cuotas
              (nro_cuenta, nro_cuota, mto_cuota,
               fec_vencimiento, mto_interes, estado,
               fec_ult_pago, periodo, tipo, sal_acumulado)
           VALUES
              (p_nro_cuenta, v_max_cuota+1, p_monto,
               v_fec_proceso, nvl(v_mto_interes,0), 'P',
               v_fec_proceso, r_gcta.per_debito, 'R', v_sal_acumulado);
          EXCEPTION
           WHEN OTHERS THEN
            raise_application_error(-20022, 'Error al insertar datos en AH_PRO_CUOTAS. Cuenta: '||r_gcta.nro_cuenta||SQLERRM);
          END;
       END IF;
    END LOOP;

    IF v_act_operacion = 'N' THEN
       raise_application_error(-20023, v_err_movimiento);
    END IF;
  END;

  /** Proceso que calcula el cargo de la cancelacion anticipada del Ahorro programado **/
  PROCEDURE pr_can_cal_mto_aho_pro(p_nro_cuenta   cc_cta_corrientes.nro_cuenta%TYPE,
                                   p_mto_car_fij  OUT ge_movimientos.monto%TYPE,
                                   p_imp_car_fij  OUT ge_movimientos.monto%TYPE,
                                   p_mto_car_por  OUT ge_movimientos.monto%TYPE,
                                   p_imp_car_por  OUT ge_movimientos.monto%TYPE,
                                   p_tot_cre_neto OUT ge_movimientos.monto%TYPE) IS

    v_mto_plazo              ah_cta_plazos.capital%TYPE;
    v_sal_total              ah_cta_plazos.sal_total%TYPE;
    v_ini_plazo              ah_cta_plazos.fec_apertura%TYPE;
    v_vto_plazo              ah_cta_plazos.fec_vencimiento%TYPE;
    v_can_dia_plazo          NUMBER;
    v_tasa                   NUMBER;
    v_val_mto_tasa           ge_tas_fechas.val_tasa%TYPE;
    v_mto_com_var            ge_movimientos.monto%TYPE;
    v_val_por_tasa           ge_tas_fechas.val_tasa%TYPE;
    v_fec_cancelacion        ah_cta_plazos.fec_vencimiento%TYPE;
    v_dia_transcurrido       NUMBER;
    v_dia_vencer             NUMBER;
    v_est_cuenta             ah_cta_plazos.estado%TYPE;
    v_cod_modulo             ah_cta_plazos.cod_modulo%TYPE;
    v_cod_modalidad          ah_cta_plazos.cod_modalidad%TYPE;
    v_cod_moneda             ah_cta_plazos.cod_moneda%TYPE;
    v_cod_tas_car_fijo       ge_transacciones.cod_transaccion%TYPE := fug_obt_pardinamico('COD_TAS_CAR_FIJ_APR');
    v_cod_tas_car_porcentaje ge_transacciones.cod_transaccion%TYPE := fug_obt_pardinamico('COD_TAS_CAR_POR_APR');
    v_nro_cta_origen         ah_cta_plazos.nro_cta_capitalizacion%TYPE;
    v_tot_acreditar          ge_movimientos.monto%TYPE;
    v_redondeo               NUMBER;
    v_por_impuesto           NUMBER;
    v_programa               varchar2(60) := 'PAA_PRO.PR_CAN_CAL_MTO_AHO_PRO';
    v_meses                  number(3);
    v_mto_car_fijo           ge_movimientos.monto%TYPE;
    v_mto_car_porcentaje     ge_movimientos.monto%TYPE;

  Begin
   --Obtener modulo Y modalidad de la cuenta
   Begin
     select g.cod_modulo, g.cod_modalidad, g.estado, g.cod_moneda
       into v_cod_modulo, v_cod_modalidad, v_est_cuenta, v_cod_moneda
       from ge_cuentas g
      where g.nro_cuenta = p_nro_cuenta;
   Exception
     When NO_DATA_FOUND Then
       raise_application_error(-20024, 'Error: Cuenta Inexistente!!!'||' - '||v_programa);
     WHEN OTHERS THEN
       raise_application_error(-20025, 'Error Obt.Cuenta'||' - '||v_programa||' # ' || SQLERRM);
   End;

    --Valida que los estados no sean Totalmente pagados o Cancelado
    If v_est_cuenta in ('T', 'C') then
       raise_application_error(-20026, 'CTA: '||p_nro_cuenta||' ESTADO INVALIDO!!!'||' - '||v_programa);
    End If;

    --Fecha de Cancelacion
    v_fec_cancelacion := pag_cal.FU_OBT_FEC_ACTUAL(v_cod_modulo);

    --Porcentaje IVA
    v_por_impuesto := fug_obt_val_tasa(null, null, null, null, v_cod_moneda, null, 'N', 323, null, v_fec_cancelacion);

    If v_cod_modulo = 3 and v_cod_modalidad = 38 then
        --Obtener datos del ahorro programado.
         Begin
           Select c.capital, c.sal_total,c.fec_apertura,
                  c.fec_vencimiento,c.estado,
                  c.cod_moneda,c.val_tasa,
                  (c.fec_vencimiento - c.fec_apertura),
                  (v_fec_cancelacion - c.fec_apertura),
                  (c.fec_vencimiento - v_fec_cancelacion),
                  c.nro_cta_capitalizacion
             Into v_mto_plazo, v_sal_total, v_ini_plazo,
                  v_vto_plazo,v_est_cuenta,
                  v_cod_moneda,v_tasa,
                  v_can_dia_plazo,v_dia_transcurrido,v_dia_vencer,
                  v_nro_cta_origen
             From ah_cta_plazos c
            Where c.nro_cuenta = p_nro_cuenta;
         Exception
          When no_data_found then
           RAISE_APPLICATION_ERROR(-20027,'Cuenta inexistente'||' - '||v_programa);
          When others then
           RAISE_APPLICATION_ERROR(-20028,'Cuenta invalida'||' - '||v_programa);
         End;
     else
      raise_application_error(-20029, 'La cuenta no corresponde a un ahorro programado'||' - '||v_programa);
     End If;

    v_tot_acreditar := v_mto_plazo;

    --Redondeo
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad, v_cod_moneda);

    -- Se obtiene el monto de la tasa fija
    v_val_mto_tasa := fug_obt_val_tasa(v_cod_modulo, v_cod_modalidad, null, null, v_cod_moneda, null, 'N', v_cod_tas_car_fijo, null, v_fec_cancelacion);

    --Valida Monto no sea negativo
    If v_val_mto_tasa >= 0 then
      p_mto_car_fij := v_val_mto_tasa;
      p_imp_car_fij := Round(((v_val_mto_tasa * v_por_impuesto) / 100), v_redondeo);
    Else
      raise_application_error(-20030,'Error Calculo de Monto Fijo de Cancelacion, monto no puede ser negativo'||' - '||v_programa||' # '|| sqlerrm);
    End If;

    v_val_por_tasa := fug_obt_val_tasa(v_cod_modulo, v_cod_modalidad, null, null, v_cod_moneda, null, 'N', v_cod_tas_car_porcentaje, null, v_fec_cancelacion);
    v_mto_com_var  := round(v_tot_acreditar * (v_val_por_tasa / 100), v_redondeo);

    /*Se agrega ya que el monto debe de ser IVA incluido*/
    v_mto_com_var := (v_mto_com_var /(1 + (v_por_impuesto/100)));
    v_mto_com_var := round(v_mto_com_var,v_redondeo );

    If v_mto_com_var >= 0 then
       p_mto_car_por := v_mto_com_var;
       p_imp_car_por := Round(((v_mto_com_var * v_por_impuesto)/100),v_redondeo);
    Else
       raise_application_error(-20031,'Error Calculo de Monto Variable de Cancelacion, monto no puede ser negativo'||' - '||v_programa||' # '|| sqlerrm);
    End If;

    v_meses := trunc(months_between(v_fec_cancelacion, v_ini_plazo));
    v_mto_car_fijo := p_mto_car_fij + p_imp_car_fij;
    v_mto_car_porcentaje := p_mto_car_por + p_imp_car_por;
    if v_meses <= 23 then
      /**
        Se aplica el cargo de monto fijo establecido. Tasa 530
      **/
      p_tot_cre_neto := v_tot_acreditar - v_mto_car_fijo;
      p_mto_car_por := 0;
      p_imp_car_por := 0;
    else
      /**
        Se aplica el cargo por porcentaje establecido. Tasa 602
      **/
      if v_mto_car_porcentaje < v_mto_car_fijo then
        /**
            si el monto del calculo del porcentaje es menor al monto cargo fijo
            se aplica el monto del cargo fijo
         **/
        v_mto_car_porcentaje := v_mto_car_fijo;
        p_mto_car_por := p_mto_car_fij;
        p_imp_car_por := p_imp_car_fij;
      end if;

      p_tot_cre_neto := v_tot_acreditar - v_mto_car_porcentaje;
      p_mto_car_fij := 0;
      p_imp_car_fij := 0;
    end if;


    if p_tot_cre_neto < 0 then
      p_tot_cre_neto := 0;
    end if;

  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20032,'Error en '||v_programa||' # '|| sqlerrm);
  End;

  --Movimiento de Cancelacion Anticipada Ahorro Programado
  PROCEDURE pr_can_mov_aho_pro(p_nro_cuenta    cc_cta_corrientes.nro_cuenta%TYPE,
                               p_ind_cob_cargo VARCHAR2 DEFAULT 'S',
                               p_mto_car_total ge_movimientos.monto%TYPE DEFAULT 0) IS

    v_hora             cj_movimientos.hora%type;
    v_hor_actual       ge_movimientos.hora%TYPE;
    v_fec_proceso      date;
    v_fec_valor        date;
    v_cod_modulo       ba_modulos.cod_modulo%type;
    v_cod_modalidad    ge_modalidades.cod_modalidad%type;
    v_cod_usuario      ge_movimientos.cod_usuario%type := user;
    v_es_nocturno      varchar2(1) := 'N';
    v_mto_plazo        ah_cta_plazos.capital%type;
    v_sal_total        ah_cta_plazos.sal_total%type;
    v_ini_plazo        ah_cta_plazos.fec_apertura%type;
    v_vto_plazo        ah_cta_plazos.fec_vencimiento%type;
    v_can_dia_plazo    number;
    v_tasa             number;
    v_est_cuenta       ah_cta_plazos.estado%type;
    v_cod_moneda       ah_cta_plazos.cod_moneda%type;
    v_dia_transcurrido number;
    v_dia_vencer       number;
    v_cod_oficina      ba_oficinas.cod_oficina%type;
    v_ofi_origen       cj_movimientos.cod_oficina%type := fug_obt_ofi_matriz;
    v_cta_origen       ge_cuentas.nro_cuenta%type;
    v_lugar            varchar2(300) :=null;
    v_mod_cta_origen   ba_modulos.cod_modulo%type;
    v_mad_cta_origen   ge_modalidades.cod_modalidad%type;
    v_tra_cta_credito  ge_transacciones.cod_transaccion%type := 602; -- Transaccion Credito a Cta. Origen
    v_cod_tra_car_fijo ge_transacciones.cod_transaccion%type;
    v_cod_tra_car_por  ge_transacciones.cod_transaccion%type;
    v_cod_tra_car_tot  ge_transacciones.cod_transaccion%type;
    v_nvo_estado       ge_cuentas.estado%type;
    v_sal_disp         ge_cuentas.sal_contable%type;
    v_procesa          varchar2(1) := 'N';
    v_mto_car_fijo      ge_movimientos.monto%type;
    v_imp_car_fijo      ge_movimientos.monto%type;
    v_mto_car_por      ge_movimientos.monto%type;
    v_imp_car_por      ge_movimientos.monto%type;
    v_por_impuesto     number;
    v_mto_iva          ge_movimientos.monto%type;
    v_mto_total        ge_movimientos.monto%type;
    v_car_total        ge_movimientos.monto%type;
    v_car_acobrar      ge_movimientos.monto%type;
    v_car_parcial      ge_movimientos.monto%type;
    v_mto_debito       ge_movimientos.monto%type;
    v_interes          ge_movimientos.monto%type := 0;
    v_interes_normal   ge_movimientos.monto%type := 0;
    v_nro_secuencia    ge_movimientos.nro_secuencia%type;
    v_redondeo         number;
    v_mto_credito      ge_movimientos.monto%type;
    v_programa         varchar2(60) := 'PAA_PRO.PR_CAN_MOV_AHO_PRO';
    v_sal_cta_capitalizacion ah_cta_vistas.sal_total%type;
    v_err_sal_insuficiente exception;
    v_err_otros            exception;
    v_cta_err              tm_log_nominas.nro_cuenta%type;
    v_err_mto              tm_log_nominas.monto%type;
    v_err_sal_total        tm_log_nominas.sal_total%type;
    v_err_lugar            tm_log_nominas.lugar%type;
    v_err_observacion      tm_log_nominas.observacion%type;
    v_err_codigo           number(6);
    v_habilitada           varchar2(1);
    v_err_cta_debcre       exception;

    procedure pl_val_cta_habilitada(p_nro_cuenta varchar2,
                                    p_cod_tra_padre varchar2,
                                    p_cod_mod_padre varchar2,
                                    p_cod_mad_padre varchar2,
                                    p_tip_operacion varchar2,
                                    p_cod_moneda varchar2,
                                    p_mto_debcre varchar2,
                                    p_cod_oficina varchar2,
                                    p_cod_modulo varchar2,
                                    p_cod_modalidad varchar2,
                                    p_nvo_estado varchar2,
                                    p_sal_disp varchar2,
                                    p_cod_transaccion varchar2,
                                    p_habilitada out varchar2) is
     v_procesa         varchar2(1);
     v_cod_modulo      ba_modulos.cod_modulo%type;
     v_cod_modalidad   ge_modalidades.cod_modalidad%type;
     v_nvo_estado      ge_est_cuentas.estado%type;
     v_sal_disp        ge_cuentas.sal_contable%type;
     
     begin
       /** Validacion de la cuenta de credito y debito antes de iniciar la operacion **/
        /*-----------------------------------------------------------------------------*/
        v_cod_modulo     := p_cod_modulo;
        v_cod_modalidad  := p_cod_modalidad;
        v_nvo_estado     := p_nvo_estado;
        v_sal_disp       := p_sal_disp;
        
        pag_cta.pr_ver_operacion(p_nro_cuenta,
                                 p_cod_tra_padre,
                                 p_cod_mod_padre,
                                 p_cod_mad_padre,
                                 p_tip_operacion,
                                 p_cod_moneda,
                                 p_mto_debcre,
                                 p_cod_oficina,
                                 v_cod_modulo,
                                 v_cod_modalidad,
                                 v_nvo_estado,
                                 v_sal_disp,
                                 v_procesa,
                                 p_cod_transaccion);
      if v_procesa = 'N' then 
       v_err_codigo      := -20038;
       v_msg_error       := substr(v_err_codigo||' Cta '||v_cta_err||' no puede realizar la operacion  - '||to_char(pag_cta.g_cod_error,'000')||' - '||pag_cta.g_msj_error,1,300);
       v_cta_err         := p_nro_cuenta;
       v_err_mto         := p_mto_debcre;
       v_err_sal_total   := p_sal_disp;
       v_err_lugar       := v_programa;
       v_err_observacion := v_msg_error;
      end if;
      p_habilitada := v_procesa;
     end;
    
    procedure pr_reg_movimiento(p_cod_mod_padre      ba_modulos.cod_modulo%type,
                                p_cod_mad_padre      ge_modalidades.cod_modalidad%type,
                                p_cod_tra_padre      ge_transacciones.cod_transaccion%type,
                                p_cod_modulo         ba_modulos.cod_modulo%type,
                                p_cod_modalidad      ge_modalidades.cod_modalidad%type,
                                p_cod_transaccion    ge_transacciones.cod_transaccion%type,
                                p_nro_cta_movimiento ge_cuentas.nro_cuenta%type,
                                p_cod_moneda         ba_monedas.cod_moneda%type,
                                p_monto              ge_movimientos.monto%type,
                                p_concepto           ge_movimientos.concepto%type) is

      R_GMOVI    GE_MOVIMIENTOS%ROWTYPE;
      v_val_tasa ge_movimientos.val_tasa%TYPE;
      v_cod_tasa ge_tasas.cod_tasa%TYPE := 323;
      v_nocturno varchar2(1);

    begin
      v_nro_secuencia         := nvl(v_nro_secuencia, 0) + 1;
      r_gmovi.cod_usuario     := v_cod_usuario;
      r_gmovi.hora            := v_hora;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.cod_mod_padre   := p_cod_mod_padre;
      r_gmovi.cod_mad_padre   := p_cod_mad_padre;
      r_gmovi.cod_oficina     := v_cod_oficina;
      r_gmovi.cod_modulo      := p_cod_modulo;
      r_gmovi.cod_modalidad   := p_cod_modalidad;
      r_gmovi.nro_cuenta      := p_nro_cta_movimiento;
      r_gmovi.cod_moneda      := p_cod_moneda;
      r_gmovi.monto           := p_monto;
      r_gmovi.cod_tra_padre   := p_cod_tra_padre;
      r_gmovi.cod_transaccion := p_cod_transaccion;

      IF p_cod_transaccion = 502 THEN -- Movimiento IVA
        v_val_tasa       := fug_obt_val_tasa(3, NULL, NULL,NULL,p_cod_moneda,NULL,'N',v_cod_tasa,NULL,v_fec_proceso);
        r_gmovi.val_tasa := v_val_tasa;
      END IF;

      r_gmovi.concepto   := p_concepto;

      if p_cod_transaccion = 403 then
         r_gmovi.est_cuenta   := 'C';
      end if;

      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.protegido       := 'N';
      r_gmovi.nro_documento   := p_nro_cuenta;
      r_gmovi.cod_ofi_origen  := v_ofi_origen;
      r_gmovi.fecha           := v_fec_proceso;
      r_gmovi.fec_valor       := v_fec_valor;

      /** AIU-1712 **/
      pr_mov_nocturno(v_nocturno);
      if v_nocturno = 'S' then
        r_gmovi.fecha := pag_cal.fu_obt_fec_sig_hab(v_fec_proceso,61);
      end if;
      pag_gen.pr_ins_ge_movimiento(r_gmovi, v_nocturno);

    end;
  Begin
    /** INICIO PROGRAMA PRINCIPAL **/
    v_lugar:= '1-Obtener Modulo/Modalidad Cta.';
    v_msg_error := null;

    --Obtener modulo y modalidad de la cuenta
    Begin
      select g.cod_modulo, g.cod_modalidad
        into v_cod_modulo, v_cod_modalidad
        from ge_cuentas g
       where g.nro_cuenta = p_nro_cuenta;
    Exception
      When NO_DATA_FOUND Then
        v_msg_error := substr( '-20033 Error: Cuenta Inexistente!!!',1,300);
        v_err_codigo      := -20033;
        v_cta_err         := p_nro_cuenta;
        v_err_mto         := 0;
        v_err_sal_total   := 0;
        v_err_lugar       := v_programa;
        v_err_observacion := v_msg_error;
        raise v_err_otros;
      WHEN OTHERS THEN
        v_msg_error := substr( '-20034 Eror Obt.Cuenta'||' # '|| SQLERRM,1,300);
        v_err_codigo      := -20034;
        v_cta_err         := p_nro_cuenta;
        v_err_mto         := 0;
        v_err_sal_total   := 0;
        v_err_lugar       := v_programa;
        v_err_observacion := v_msg_error;
        raise v_err_otros;
    End;

    v_fec_proceso := pag_cal.FU_OBT_FEC_ACTUAL(v_cod_modulo);
    v_fec_valor   := trunc(sysdate); -- para que sea fecha la fecha real de la transaccion
    v_hor_actual  := to_char(sysdate, 'HH24:MI:SS');
    v_hora        := fug_obt_hor_disponible(v_fec_proceso, v_hor_actual, v_cod_usuario, v_es_nocturno);
    v_lugar       := '2-Obtener datos de la Cta.';

    --Obtener datos de la Ahorro programado
    Begin
      Select c.capital,
             c.sal_total,
             c.fec_apertura,
             c.fec_vencimiento,
             c.estado,
             c.cod_moneda,
             c.val_tasa,
             c.cod_oficina,
             (c.fec_vencimiento - c.fec_apertura),
             (v_fec_proceso - c.fec_apertura),
             (c.fec_vencimiento - v_fec_proceso),
             c.nro_cta_capitalizacion
        Into v_mto_plazo,
             v_sal_total,
             v_ini_plazo,
             v_vto_plazo,
             v_est_cuenta,
             v_cod_moneda,
             v_tasa,
             v_cod_oficina,
             v_can_dia_plazo,
             v_dia_transcurrido,
             v_dia_vencer,
             v_cta_origen
        From ah_cta_plazos c
       Where c.nro_cuenta = p_nro_cuenta;
    Exception
      When no_data_found then
        v_msg_error := substr( '-20035 Cuenta inexistente',1,300);
        v_err_codigo      := -20035;
        v_cta_err         := p_nro_cuenta;
        v_err_mto         := 0;
        v_err_sal_total   := 0;
        v_err_lugar       := v_programa;
        v_err_observacion := v_msg_error;
        RAISE v_err_otros;
      When others then
        v_msg_error := substr( '-20036 Cuenta invalida',1,300);
        v_err_codigo      := -20036;
        v_cta_err         := p_nro_cuenta;
        v_err_mto         := 0;
        v_err_sal_total   := 0;
        v_err_lugar       := v_programa;
        v_err_observacion := v_msg_error;
        RAISE v_err_otros;
    End;

    v_lugar:= '7-Obtener modulo/modalidad Cta. Origen';
      --Obtengo modulo y modalidad de la Cta. Origen
      Begin
        select g.cod_modulo, g.cod_modalidad
          into v_mod_cta_origen, v_mad_cta_origen
          from ge_cuentas g
         where g.nro_cuenta = v_cta_origen;
      Exception
        When NO_DATA_FOUND Then
          v_msg_error := substr( '-20039 Error: Cuenta Origen(cta Capitalizacion) Inexistente!!!',1,300);
          v_err_codigo      := -20039;
          v_cta_err         := v_cta_origen;
          v_err_mto         := 0;
          v_err_sal_total   := 0;
          v_err_lugar       := v_programa;
          v_err_observacion := v_msg_error;
          raise v_err_otros;
        WHEN OTHERS THEN
          v_msg_error := substr( '-20040 Error Obt.Cuenta Origen(cta Capitalizacion)'||' # '|| SQLERRM,1,300);
          v_err_codigo      := -20040;
          v_cta_err         := v_cta_origen;
          v_err_mto         := 0;
          v_err_sal_total   := 0;
          v_err_lugar       := v_programa;
          v_err_observacion := v_msg_error;
          raise v_err_otros;
      End;

   /**********************************************************************************************/
   -- obtiene monto disponible y monto del cargo
   pr_obt_saldo(p_nro_cuenta, v_cta_origen, v_sal_total, v_sal_cta_capitalizacion, v_mto_car_fijo, v_imp_car_fijo, v_mto_car_por, v_imp_car_por);
   v_car_total := nvl(v_mto_car_fijo,0) + nvl(v_imp_car_fijo,0) + nvl(v_mto_car_por,0) + nvl(v_imp_car_por,0);

   if v_sal_cta_capitalizacion > 0 and v_sal_cta_capitalizacion >= v_car_total then
    --solo SI tiene saldo suficiente para cubrir el total del cargo realiza la operacion de cancelacion
    v_mto_credito := v_mto_plazo;
    v_mto_debito  := v_mto_plazo;
    v_car_parcial := 0;
    
    /** Validamos que la cuenta de DEBITO esté habilitada para relizar la operacion **/
    pl_val_cta_habilitada(p_nro_cuenta,
                          301,
                          v_cod_modulo,
                          v_cod_modalidad,
                          'D',
                          v_cod_moneda,
                          v_mto_debito,
                          v_cod_oficina,
                          v_cod_modulo,
                          v_cod_modalidad,
                          v_nvo_estado,
                          v_sal_disp,
                          503,
                          v_habilitada);
                          
   if nvl(v_habilitada,'N') = 'S' then
    /** Validamos que la cuenta de CREDITO esté habilitada para relizar la operacion **/
    pl_val_cta_habilitada(v_cta_origen,
                          301,
                          v_cod_modulo,
                          v_cod_modalidad,
                          'C',
                          v_cod_moneda,
                          v_mto_credito,
                          v_cod_oficina,
                          v_mod_cta_origen,
                          v_mad_cta_origen,
                          v_nvo_estado,
                          v_sal_disp,
                          v_tra_cta_credito,
                          v_habilitada);
    end if;
    if nvl(v_habilitada,'N') = 'S' then
      declare
        v_int ah_sal_mensuales.mto_int_devengado%type;
      begin
       --Primero provisionamos hasta la fecha
       pr_pro_aho_programado(p_nro_cuenta, 'N', null, v_int);
      end;

      begin
         v_interes_normal := fu_obt_dev_acu_ah_sal(p_nro_cuenta,to_number(to_char(add_months(v_fec_proceso,1),'YYYYMM')) );
         v_interes        := paa_pro.fu_rec_int_ap(p_nro_cuenta => p_nro_cuenta);
      end;

      --Valida que el estado no sea Totalmente Pagado o Cancelado
      If v_est_cuenta in ('T','C') then
         v_msg_error := substr( '-20037 ESTADO INVALIDO!!!',1,300);
         v_err_codigo      := -20037;
         v_cta_err         := p_nro_cuenta;
         v_err_mto         := 0;
         v_err_sal_total   := 0;
         v_err_lugar       := v_programa;
         v_err_observacion := v_msg_error;
         raise v_err_otros;
      End If;

      if p_ind_cob_cargo = 'S' then
        if p_mto_car_total > 0 then
           v_car_acobrar := p_mto_car_total;
        else
           v_car_acobrar := v_car_total;
        end if;
      end if;

        --Actualizar Estado/Motivo Cancelacion/Fecha Pago = Fecha Cancelacion de la Cta. Ah. Programado
        --Primero pasa a P (Pendiente de Cancelacion para generar los movimientos)
        v_lugar:= '3-Actualizar estado de la Cta. Ahorro Programado';
        update ah_cta_plazos
             set estado = 'P',fec_cam_estado = v_fec_proceso,
                 fec_pago = v_fec_proceso,
                 cod_cau_cancelacion = 131
           where nro_cuenta = p_nro_cuenta;

        v_lugar:= '4-Insertar movimiento de Cambio estado a vencido de la Cta';
        --- Insertar movimiento de Cambio estado a vencido de la Cta.

        pr_reg_movimiento(v_cod_modulo, v_cod_modalidad, 301, v_cod_modulo, v_cod_modalidad, 403, p_nro_cuenta, v_cod_moneda, null, 'CAMBIO DE ESTADO-AHORRO PROGRAMADO');

        v_lugar:= '5-Inserta Movimiento Debito Ahorro Programado';
       
        --Verificar la operacion
        if v_mto_debito > 0 then
          pr_reg_movimiento(v_cod_modulo, v_cod_modalidad, 301, v_cod_modulo, v_cod_modalidad, 503, p_nro_cuenta, v_cod_moneda, v_mto_debito, 'DEBITO EN CUENTA AHORRO PROGRAMADO');
          v_lugar:= '6-Actualiza saldo Cta. Ahorro Programado';
          -- actualiza saldo cta
          PAG_CTA.PR_ACT_SAL_CTA(p_nro_cuenta, v_cod_modalidad, 'D', v_fec_proceso, v_hora, v_mto_debito, null, null, 'N');
        end if;

        v_cod_tra_car_fijo := fug_obt_pardinamico('COD_TRA_CAR_FIJ_APR', v_mod_cta_origen, v_mad_cta_origen);
        v_cod_tra_car_por  := fug_obt_pardinamico('COD_TRA_CAR_POR_APR', v_mod_cta_origen, v_mad_cta_origen);
        v_cod_tra_car_tot  := fug_obt_pardinamico('COD_TRA_CAR_TOT_APR', v_mod_cta_origen, v_mad_cta_origen);
        v_lugar:= '8-Inserta Movimiento Credito Cta. Origen.';
        
        --Verificar la operacion
        if v_mto_credito > 0 then
          --Movimiento Credito Cta. Origen  v_cta_origen
          v_lugar:= '9- Movimiento de Cta. Origen.';
          pr_reg_movimiento(v_cod_modulo, v_cod_modalidad, 301, v_mod_cta_origen, v_mad_cta_origen, v_tra_cta_credito, v_cta_origen, v_cod_moneda, v_mto_credito, 'CREDITO SALDO CANCELACION CTA. AHORRO PROGRAMADO');
          v_lugar:= '10-Actualiza saldo Cta. Origen.';
          -- actualiza saldo cta
          PAG_CTA.PR_ACT_SAL_CTA(v_cta_origen, v_mad_cta_origen, 'C', v_fec_proceso, v_hora,v_mto_credito, null, null, 'N');
        end if;
        if v_interes > 0 then
          pag_cta.pr_ver_operacion(v_cta_origen,
                                   301,
                                   v_cod_modulo,
                                   v_cod_modalidad,
                                   'C',
                                   v_cod_moneda,
                                   v_interes,
                                   v_cod_oficina,
                                   v_mod_cta_origen,
                                   v_mad_cta_origen,
                                   v_nvo_estado,
                                   v_sal_disp,
                                   v_procesa,
                                   v_tra_cta_credito);
         if v_procesa = 'N' then
           v_msg_error       := substr('-20042 Error en '||v_lugar||' - '||to_char(pag_cta.g_cod_error,'000')||' - '||pag_cta.g_msj_error,1,300);
           v_err_codigo      := -20042;
           v_cta_err         := v_cta_origen;
           v_err_mto         := v_interes;
           v_err_sal_total   := 0;
           v_err_lugar       := v_programa;
           v_err_observacion := v_msg_error;
           RAISE v_err_otros;
         else
             --Movimiento Credito Cta. Origen  v_cta_origen
             v_lugar:= '11- Movimiento de Interes.';
             pr_reg_movimiento(v_cod_modulo, v_cod_modalidad, 301, v_mod_cta_origen, v_mad_cta_origen, 602,
                               v_cta_origen, v_cod_moneda, v_interes, 'CREDITO INTERES CANCELACION CTA. AHORRO PROGRAMADO');

             -- Movimiento de capitalizacion de intereses
             pr_reg_movimiento(v_cod_modulo, v_cod_modalidad, 301, v_cod_modulo, v_cod_modalidad, 609,
                               p_nro_cuenta, v_cod_moneda, v_interes, 'CAPITALIZACION INTERESES CTA. AHORRO PROGRAMADO');

             --AIU-372 -Para machear el interes devengado no pagado
             pr_reg_movimiento(v_cod_modulo, v_cod_modalidad, 301, v_cod_modulo, v_cod_modalidad, 9154,
                               p_nro_cuenta, v_cod_moneda,(v_interes_normal- v_interes), 'CAPITALIZACION INTERESES CTA. AHORRO PROGRAMADO');

             v_lugar:= '12-Actualiza saldo Interes.';
             -- actualiza saldo cta
             PAG_CTA.PR_ACT_SAL_CTA(v_cta_origen, v_mad_cta_origen, 'C',
                                    v_fec_proceso, v_hora,v_interes, null, null, 'N');
         end If;
        end if;
          if nvl(p_ind_cob_cargo, 'S') = 'S' then
            if nvl(p_mto_car_total, 0) = 0 and nvl(v_car_parcial,0) = 0 then
              --Debito del Cargo Fijo
              if v_mto_car_fijo > 0 then
                 v_lugar:= '13-Inserta movimientos por el Cargo.';
                 --Verificar la operacion
                 pag_cta.pr_ver_operacion(v_cta_origen,
                                          301,
                                          v_cod_modulo,
                                          v_cod_modalidad,
                                          'D',
                                          v_cod_moneda,
                                          nvl(v_mto_car_fijo,0),
                                          v_cod_oficina,
                                          v_mod_cta_origen,
                                          v_mad_cta_origen,
                                          v_nvo_estado,
                                          v_sal_disp,
                                          v_procesa,
                                          v_cod_tra_car_fijo);
                 If v_procesa = 'N' then
                    v_msg_error := substr( '-20043 Error en '||v_lugar||' - '||to_char(pag_cta.g_cod_error,'000')||' - '||pag_cta.g_msj_error,1,300);
                    v_err_codigo      := -20043;
                    v_cta_err         := v_cta_origen;
                    v_err_mto         := nvl(v_mto_car_fijo,0);
                    v_err_sal_total   := 0;
                    v_err_lugar       := v_programa;
                    v_err_observacion := v_msg_error;
                    RAISE v_err_otros;
                 else
                    --Inserta movimientos por el Cargo
                    pr_reg_movimiento(v_cod_modulo, v_cod_modalidad, 301, v_mod_cta_origen, v_mad_cta_origen, v_cod_tra_car_fijo,
                                      v_cta_origen, v_cod_moneda, v_mto_car_fijo, 'DB. CARGO CANCELACION DE AH. PROGRAMADO');

                    v_lugar:= '14-Actualiza saldo Cta. Origen Mto. Cargo Fijo';
                    -- actualiza saldo cta
                    PAG_CTA.PR_ACT_SAL_CTA(v_cta_origen, v_mad_cta_origen, 'D', v_fec_proceso, v_hora,v_mto_car_fijo,null, null, 'N');
                 end if;
            end if;
            -- Movimiento de iva del cargo
            If v_imp_car_fijo > 0 then
               v_lugar:= '15-Inserta IVA por el Cargo';
               --Verificar la operacion
               pag_cta.pr_ver_operacion(v_cta_origen,
                                        301,
                                        v_cod_modulo,
                                        v_cod_modalidad,
                                        'D',
                                        v_cod_moneda,
                                        nvl(v_imp_car_fijo,0),
                                        v_cod_oficina,
                                        v_mod_cta_origen,
                                        v_mad_cta_origen,
                                        v_nvo_estado,
                                        v_sal_disp,
                                        v_procesa,
                                        502);
                If v_procesa = 'N' then
                   v_msg_error := substr( '-20044 Error en '||v_lugar||' - '||to_char(pag_cta.g_cod_error,'000')||' - '||pag_cta.g_msj_error,1,300);
                   v_err_codigo      := -20044;
                   v_cta_err         := v_cta_origen;
                   v_err_mto         := nvl(v_imp_car_fijo,0);
                   v_err_sal_total   := 0;
                   v_err_lugar       := v_programa;
                   v_err_observacion := v_msg_error;
                   RAISE v_err_otros;
                Else
                   pr_reg_movimiento(v_cod_modulo, v_cod_modalidad, 301, v_mod_cta_origen, v_mad_cta_origen, 502,
                                     v_cta_origen, v_cod_moneda, v_imp_car_fijo, 'DB. IVA S/CARGO P/CANCELACION CTA.');

                    v_lugar:= '16-Actualiza saldo Cta. Ahorro Programado Mto. Cargo';
                    -- actualiza saldo cta
                    PAG_CTA.PR_ACT_SAL_CTA(v_cta_origen, v_mad_cta_origen, 'D',
                                           v_fec_proceso, v_hora,v_imp_car_fijo,null, null, 'N');
                End If;
            End If;

            --Debito del Cargo con Porcentaje
            if v_mto_car_por > 0 then
               v_lugar:= '17-Inserta movimientos por el Cargo.';
               --Verificar la operacion
               pag_cta.pr_ver_operacion(v_cta_origen,
                                        301,
                                        v_cod_modulo,
                                        v_cod_modalidad,
                                        'D',
                                        v_cod_moneda,
                                        nvl(v_mto_car_por,0),
                                        v_cod_oficina,
                                        v_mod_cta_origen,
                                        v_mad_cta_origen,
                                        v_nvo_estado,
                                        v_sal_disp,
                                        v_procesa,
                                        v_cod_tra_car_por);
                 If v_procesa = 'N' then
                    v_msg_error := substr( '-20045 Error en '||v_lugar||' - '||to_char(pag_cta.g_cod_error,'000')||' - '||pag_cta.g_msj_error,1,300);
                    v_err_codigo      := -20045;
                    v_cta_err         := v_cta_origen;
                    v_err_mto         := nvl(v_mto_car_por,0);
                    v_err_sal_total   := 0;
                    v_err_lugar       := v_programa;
                    v_err_observacion := v_msg_error;
                    RAISE v_err_otros;
                 Else
                    --Inserta movimientos por el Cargo
                    pr_reg_movimiento(v_cod_modulo, v_cod_modalidad, 301, v_mod_cta_origen, v_mad_cta_origen, v_cod_tra_car_por,
                                      v_cta_origen, v_cod_moneda, v_mto_car_por,  'DB. CARGO CANCELACION DE CUENTAS BANCARIAS');

                    v_lugar:= '18-Actualiza saldo Cta. Origen Mto. Cargo Fijo';
                    -- actualiza saldo cta
                    PAG_CTA.PR_ACT_SAL_CTA(v_cta_origen, v_mad_cta_origen, 'D', v_fec_proceso, v_hora,v_mto_car_por,null, null, 'N');
                 End If;
            End if;
            -- Movimiento de iva del cargo
            If v_imp_car_por > 0 then
               v_lugar:= '19-Inserta IVA por el Cargo';
               --Verificar la operacion
               pag_cta.pr_ver_operacion(v_cta_origen,
                                        301,
                                        v_cod_modulo,
                                        v_cod_modalidad,
                                        'D',
                                        v_cod_moneda,
                                        nvl(v_imp_car_por,0),
                                        v_cod_oficina,
                                        v_mod_cta_origen,
                                        v_mad_cta_origen,
                                        v_nvo_estado,
                                        v_sal_disp,
                                        v_procesa,
                                        502);
                If v_procesa = 'N' then
                   v_msg_error := substr( '-20046 Error en '||v_lugar||' - '||to_char(pag_cta.g_cod_error,'000')||' - '||pag_cta.g_msj_error,1,300);
                   v_err_codigo      := -20046;
                   v_cta_err         := v_cta_origen;
                   v_err_mto         := nvl(v_imp_car_por,0);
                   v_err_sal_total   := 0;
                   v_err_lugar       := v_programa;
                   v_err_observacion := v_msg_error;
                   RAISE v_err_otros;
                Else
                  --Inserta IVA por el Cargo
                  pr_reg_movimiento(v_cod_modulo, v_cod_modalidad, 301, v_mod_cta_origen, v_mad_cta_origen, 502,
                                    v_cta_origen, v_cod_moneda, v_imp_car_por,  'DB. IVA S/CARGO P/CANCELACION CTA.');

                  v_lugar:= '20-Actualiza saldo Cta. Ahorro Programado Mto. Cargo';
                  -- actualiza saldo cta
                  PAG_CTA.PR_ACT_SAL_CTA(v_cta_origen, v_mad_cta_origen, 'D', v_fec_proceso, v_hora, v_imp_car_por, null, null, 'N');
                End If;
            End If;
          ELSE
            if v_car_parcial > 0 then
               v_car_acobrar := v_car_parcial;
            else
               v_car_acobrar := p_mto_car_total;
            end if;
            v_por_impuesto := fug_obt_val_tasa(null,null,null,null,v_cod_moneda,null,'N',323,null,v_fec_proceso);
            v_redondeo     := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_mod_cta_origen, v_mad_cta_origen, v_cod_moneda);
            v_mto_iva      := round(v_car_acobrar / ((100 + v_por_impuesto) /10), v_redondeo);
            v_mto_total    := round(v_car_acobrar - v_mto_iva, v_redondeo);

            if nvl(v_mto_total, 0) > 0 then
                 v_lugar:= '21-Inserta movimientos por el Cargo Total.';
                 --Verificar la operacion
                 pag_cta.pr_ver_operacion(v_cta_origen,
                                          301,
                                          v_cod_modulo,
                                          v_cod_modalidad,
                                          'D',
                                          v_cod_moneda,
                                          nvl(v_mto_total,0),
                                          v_cod_oficina,
                                          v_mod_cta_origen,
                                          v_mad_cta_origen,
                                          v_nvo_estado,
                                          v_sal_disp,
                                          v_procesa,
                                          v_cod_tra_car_tot);
                 If v_procesa = 'N' then
                    v_msg_error := substr( '-20047 Error en '||v_lugar||' - '||to_char(pag_cta.g_cod_error,'000')||' - '||pag_cta.g_msj_error,1,300);
                    v_err_codigo      := -20047;
                    v_cta_err         := v_cta_origen;
                    v_err_mto         := nvl(v_mto_total,0);
                    v_err_sal_total   := 0;
                    v_err_lugar       := v_programa;
                    v_err_observacion := v_msg_error;
                    RAISE v_err_otros;
                 Else
                    --Inserta movimientos por el Cargo
                    v_lugar := '22-Inserta movimiento por Cargo Total';
                    pr_reg_movimiento(v_cod_modulo, v_cod_modalidad, 301, v_mod_cta_origen, v_mad_cta_origen, v_cod_tra_car_tot,
                                      v_cta_origen, v_cod_moneda, v_mto_total,  'DB. CARGO CANCELACION DE CUENTAS BANCARIAS');
                    v_lugar:= '23-Actualiza saldo Cta. Origen Mto. Cargo Fijo';
                    -- actualiza saldo cta
                    v_lugar := '24-Actualiza saldo por Cargo Total';
                    PAG_CTA.PR_ACT_SAL_CTA(v_cta_origen, v_mad_cta_origen, 'D',v_fec_proceso, v_hora,v_mto_total,null, null, 'N');
                 End If;
            End if;
            -- Movimiento de iva del cargo
            If v_mto_iva > 0 then
               v_lugar:= '25-Inserta IVA por el Cargo';
               --Verificar la operacion
               pag_cta.pr_ver_operacion(v_cta_origen,
                                        301,
                                        v_cod_modulo,
                                        v_cod_modalidad,
                                        'D',
                                        v_cod_moneda,
                                        nvl(v_mto_iva,0),
                                        v_cod_oficina,
                                        v_mod_cta_origen,
                                        v_mad_cta_origen,
                                        v_nvo_estado,
                                        v_sal_disp,
                                        v_procesa,
                                        502);
                If v_procesa = 'N' then
                   v_msg_error := substr( '-20048 Error en '||v_lugar||' - '||to_char(pag_cta.g_cod_error,'000')||' - '||pag_cta.g_msj_error,1,300);
                   v_err_codigo      := -20048;
                   v_cta_err         := v_cta_origen;
                   v_err_mto         := nvl(v_mto_iva,0);
                   v_err_sal_total   := 0;
                   v_err_lugar       := v_programa;
                   v_err_observacion := v_msg_error;
                   RAISE v_err_otros;
                Else
                    --Inserta IVA por el Cargo
                    v_lugar := '26-Inserta Movimiento iva por Cargo Total';
                    pr_reg_movimiento(v_cod_modulo, v_cod_modalidad, 301, v_mod_cta_origen, v_mad_cta_origen, 502,
                                      v_cta_origen, v_cod_moneda, v_mto_iva,  'DB. IVA S/CARGO P/CANCELACION CTA.');
                    v_lugar:= '27-Actualiza saldo Cta. Ahorro Programado Mto. Cargo';
                    -- actualiza saldo cta
                    PAG_CTA.PR_ACT_SAL_CTA(v_cta_origen, v_mad_cta_origen, 'D', v_fec_proceso, v_hora,v_mto_iva,null, null, 'N');
                End If;
            End If;

          END IF;
        ELSE
          prg_ins_exoneracion(v_cod_tra_car_tot, v_mod_cta_origen, v_mad_cta_origen, v_cod_moneda,
                              v_cta_origen, null, null, v_car_total, v_car_total,
                              user, v_car_total);
        END IF;
        --Actualizar Estado/Motivo Cancelacion/Fecha Pago = Fecha Cancelacion de la Cta. Ahorro Programado
        v_lugar:= '28-Actualizar estado a Cancelado de la Cta. Ahorro Programado';
        update ah_cta_plazos
             set estado = 'C'
           where nro_cuenta = p_nro_cuenta;
        update ah_pro_cuotas c
           set estado = 'C'
         where nro_cuenta = p_nro_cuenta
           and c.estado <> 'P';
    else
      /** si la cuenta no puede operar graba en el log **/
      raise v_err_cta_debcre;
    end if;
   else
      /** si no cubre el monto total del cargo emite un error **/
      v_msg_error       := 'Saldo no cubre la totalidad del cargo.'||chr(10)||chr(13)||
                           'Cargo: '||v_car_total||' '||v_cod_moneda||chr(10)||chr(13)||
                           'Saldo: '||v_sal_cta_capitalizacion||' '||v_cod_moneda;
      v_cta_err         := p_nro_cuenta;
      v_err_mto         := v_car_total;
      v_err_sal_total   := v_sal_cta_capitalizacion;
      v_err_lugar       := v_programa;
      v_err_observacion := v_msg_error;
      raise v_err_sal_insuficiente;
   end if;
  EXCEPTION
    when v_err_sal_insuficiente then
      pr_ins_log_error(v_cta_err, v_err_mto, v_err_sal_total, v_err_lugar, substr('-20065 '||v_err_observacion,1,300));
   
    when v_err_cta_debcre then
      pr_ins_log_error(v_cta_err, nvl(v_err_mto,0), nvl(v_err_sal_total,0), v_err_lugar, substr(v_err_observacion,1,300));
   
    when v_err_otros then
      pr_ins_log_error(v_cta_err, v_err_mto, v_err_sal_total, v_err_lugar, v_err_observacion);
      raise_application_error(v_err_codigo,v_err_observacion);

    WHEN OTHERS THEN
      pr_ins_log_error(p_nro_cuenta,0, 0, v_programa, substr('-20049 Error en: '||v_lugar||' - '||v_programa||' # ' || sqlerrm,1,300));
      raise_application_error(-20049,'Error en: '||v_lugar||' - '||v_programa||' # ' || sqlerrm);
  End;

  PROCEDURE pr_can_aut_cierre IS
    v_fec_proceso ge_movimientos.fecha%TYPE := pag_cal.fu_obt_fec_actual(3);
    v_can_cuotas  number := fug_obt_pardinamico('CAN_CUO_CAN_AHO_PRO');
    v_nro_cuota   ah_pro_cuotas.nro_cuota%type;
    v_can_seguidos number(2);
    v_nro_cuenta   ah_cta_plazos.nro_cuenta%type;
    v_programa     varchar2(60) := 'PAA_PRO.PR_CAN_AUT_CIERRE';

    cursor ah_pro_can is
      select a.nro_cuenta, a.sal_total, a.capital
        from ah_cta_plazos a, (select count(*) can_cuo, c.nro_cuenta
                                 from ah_pro_cuotas c
                                where c.estado <> 'P'
                                  and c.fec_vencimiento < v_fec_proceso
                                  and (   (paa_pro.fu_obt_dia_debito(c.fec_vencimiento) < paa_pro.fu_obt_dia_debito(v_fec_proceso))
                                       OR (     paa_pro.fu_obt_dia_debito(c.fec_vencimiento) = 21
                                           and (   (to_number(to_char(c.fec_vencimiento,'YYYY')) <
                                                    to_number(to_char(v_fec_proceso,'YYYY')))
                                                 or((to_number(to_char(c.fec_vencimiento,'YYYY')) =
                                                     to_number(to_char(v_fec_proceso,'YYYY'))) and
                                                     to_number(to_char(c.fec_vencimiento,'MM')) <
                                                     to_number(to_char(v_fec_proceso,'MM'))
                                                    )
                                                )
                                            )
                                        )
                                group by nro_cuenta
                                ) sc
       where a.cod_modalidad = 38 -- Ahorro programado
         and a.estado not in ('C', 'T')
         and a.nro_cuenta = sc.nro_cuenta
         and a.sal_total > 0
         and sc.can_cuo >= v_can_cuotas; -- a partir de 3 cuotas vencidas no pagadas se cancela el Arhorro Programado

    cursor cur_cuotas is
     select c.nro_cuenta, c.fec_vencimiento, c.nro_cuota
       from ah_pro_cuotas c
      where c.estado <> 'P'
        and c.tipo = 'C'
        and c.fec_vencimiento < v_fec_proceso
        and (   (paa_pro.fu_obt_dia_debito(c.fec_vencimiento) < paa_pro.fu_obt_dia_debito(v_fec_proceso))
             OR (     paa_pro.fu_obt_dia_debito(c.fec_vencimiento) = 21
                 and (   (to_number(to_char(c.fec_vencimiento,'YYYY')) <
                          to_number(to_char(v_fec_proceso,'YYYY')))
                       or((to_number(to_char(c.fec_vencimiento,'YYYY')) =
                           to_number(to_char(v_fec_proceso,'YYYY'))) and
                           to_number(to_char(c.fec_vencimiento,'MM')) <
                           to_number(to_char(v_fec_proceso,'MM'))
                          )
                      )
                  )
              )
        and c.nro_cuenta = v_nro_cuenta
      order by c.nro_cuota;

  BEGIN
    for c in ah_pro_can loop
      begin
        v_nro_cuenta := c.nro_cuenta;
        v_nro_cuota := 0;
        v_can_seguidos := 0;

        for cuo in cur_cuotas loop
          if v_nro_cuota = 0 then
             v_nro_cuota := cuo.nro_cuota;
             v_can_seguidos := 1;
          else
            if cuo.nro_cuota = v_nro_cuota + 1 then
               v_can_seguidos := v_can_seguidos + 1;
               v_nro_cuota := cuo.nro_cuota;
            else
              v_nro_cuota := cuo.nro_cuota;
              v_can_seguidos := 1;
            end if;
            if v_can_seguidos = v_can_cuotas then
               paa_pro.pr_can_mov_aho_pro(c.nro_cuenta, 'S', 0);
              exit;
            end if;
          end if;
        end loop;
      exception
        when others then
          pr_ins_log_error(c.nro_cuenta,
                           c.capital,
                           c.sal_total,
                           v_programa,
                           substr(sqlerrm,1,300));
      end;
    end loop;
  END;
  --
  PROCEDURE pr_ins_log_error(p_nro_cuenta  tm_log_nominas.nro_cuenta%type,
                             p_monto       tm_log_nominas.monto%type,
                             p_sal_total   tm_log_nominas.sal_total%type,
                             p_lugar       tm_log_nominas.lugar%type,
                             p_observacion tm_log_nominas.observacion%type)IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO tm_log_aho_programado
      (nro_cuenta, monto, sal_total, lugar, observacion, fec_insercion)
    VALUES
      (p_nro_cuenta, p_monto, p_sal_total, p_lugar, p_observacion, sysdate);
    COMMIT; -- este commit solo afecta a la transaccion autonoma
  END;
  --
  PROCEDURE pr_act_cuo_vencidas(p_nro_cuenta ah_cta_plazos.nro_cuenta%TYPE DEFAULT NULL) IS
    CURSOR c_cuotas IS
      SELECT b.nro_cuenta, b.nro_cuota
        FROM ah_cta_plazos a, ah_pro_cuotas b
       WHERE a.nro_cuenta = b.nro_cuenta
         AND a.estado != 'C'
         AND b.estado = 'E'
         AND b.tipo = 'C'
         AND (p_nro_cuenta IS NULL OR a.nro_cuenta = p_nro_cuenta)
         AND to_char(b.fec_vencimiento, 'yyyymm') = to_char(pag_cal.FU_OBT_FEC_ACTUAL(3), 'yyyymm')
         AND paa_pro.fu_obt_dia_debito(b.fec_vencimiento) = paa_pro.fu_obt_dia_debito(pag_cal.FU_OBT_FEC_ACTUAL(3));

    v_programa varchar2(60) := 'PAA_PRO.PR_ACT_CUO_VENCIDAS';

  BEGIN
    FOR c IN c_cuotas LOOP
      UPDATE ah_pro_cuotas a
         SET a.estado = 'V'
       WHERE a.nro_cuenta = c.nro_cuenta
         AND a.nro_cuota = c.nro_cuota;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20050, 'Error al actualizar estado de cuota a Vencida'||' - '||v_programa||' # '|| SQLERRM);
  END;
  --
  PROCEDURE pr_pag_aho_programado IS
    v_fec_actual             ge_calendarios.fec_actual%TYPE;
    v_hora                   ge_movimientos.hora%TYPE := TO_CHAR(SYSDATE,'HH24:MI:SS');
    v_nro_secuencia          ge_movimientos.nro_secuencia%TYPE;
    v_est_modulo             ba_modulos.estado%TYPE := pae_cnf.FU_OBT_EST_MODULO(3);
    v_es_nocturno            VARCHAR2(1) := 'N';
    v_cta_error              ge_cuentas.nro_cuenta%type;
    v_procesa                varchar2(1);
    g_ctas                   pag_cta.rg_ctas;
    v_programa               varchar2(60) := 'PAA_PRO.PR_PAG_AHO_PROGRAMADO';
    v_pag_interes            boolean;
    v_per_cta_basica         varchar2(1);
    v_mto_sal_lim_cta_basica number(18,2);
    v_cod_modulo             ge_cuentas.cod_modulo%type;
    v_cod_modalidad          ge_cuentas.cod_modalidad%type;
    v_exc_transaccion        varchar2(1) := 'N';
    v_tipo                   ge_transacciones.tipo%type;
    v_tot_cre_mes            ge_movimientos.monto%type;
    v_mensaje                varchar2(400);

    CURSOR c_cta_vencidas IS
      SELECT *
        FROM ah_cta_plazos a
       WHERE a.cod_modalidad = 38
         AND a.estado = 'V'
         AND a.fec_vencimiento <= pag_cal.FU_OBT_FEC_ACTUAL(3)
         -- EXCLUIR CUENTAS DURANTE EL PROCESO DE CIERRE --
         AND INSTR(nvl(fug_obt_pardinamico('CTA_AHP_EXCLUIR'),'X'), ','||a.nro_cuenta||',') = 0 ;

   function fu_pag_interes (p_fec_vencimiento date) return boolean is
     /** funcion que verifica si puede pagar el interes del
         ahorro programado y solo una vez **/
    v_fec_vencimiento date;
    v_resultado       boolean;
    v_fec_actual      date;
    v_sig_dia_habil   date;
    v_sab_dom_feriado varchar2(1);

   begin
     v_resultado       := FALSE;
     v_fec_vencimiento := p_fec_vencimiento;
     v_fec_actual      := pag_cal.fu_obt_fec_actual(3);
     v_sab_dom_feriado := fug_ver_fec_sabdom(v_fec_vencimiento);
     v_sig_dia_habil   := pag_cal.FU_OBT_FEC_SIG_HAB(v_fec_vencimiento,61);

     if v_fec_vencimiento = v_fec_actual then
      /** Si la fecha vencimiento es igual a la fecha actual
          entonces paga el interes **/
      v_resultado := TRUE;
     elsif v_fec_vencimiento < v_fec_actual then
      if v_sab_dom_feriado = 'S' and v_sig_dia_habil = v_fec_actual   then
       /** En relacion a la fecha de vencimiento si el siguiente dia habil
          es igual a la fecha actual entonces paga el interes **/
       v_resultado := TRUE;
      end if;
     end if;

    return v_resultado;

   exception
    when others then
     return FALSE;
   end;

  BEGIN
    v_fec_actual    := pag_cal.fu_obt_fec_actual(3);

    IF v_est_modulo = 2 THEN
      v_es_nocturno := 'N'; -- N=Abierto,  S=Cerrado
    ELSE
      v_es_nocturno := 'S'; -- N=Abierto,  S=Cerrado
    END IF;
    v_hora          := fug_obt_hor_disponible(v_fec_actual,v_hora,USER,v_es_nocturno);
    v_nro_secuencia := 0;

    -- Pagar Ahorro Programado
    FOR cv IN c_cta_vencidas LOOP
     v_cta_error := cv.nro_cuenta;

     -- Pago de interes en la fecha del dia de vencimiento -- AIU-1014
     v_pag_interes := fu_pag_interes(cv.fec_vencimiento);
     if v_pag_interes = TRUE then
      declare
       v_int ah_sal_mensuales.mto_int_devengado%type;
      begin
        --Primero provisionamos hasta la fecha
        pr_pro_aho_programado(p_nro_cuenta         => cv.nro_cuenta,
                              p_ins_capitalizacion => 'N',
                              p_fec_capitalizacion => null,
                              p_mto_interes        => v_int);
      end;

      declare
       v_int ah_sal_mensuales.mto_int_devengado%type;
      begin
       --ahora capitalizamos
       pr_cap_aho_programado(p_nro_cuenta         => cv.nro_cuenta,
                             p_ins_capitalizacion => 'N',
                             p_fec_capitalizacion => null,
                             p_mto_interes        => v_int);
      end;
     end if;

     /** Verifica si la operacion D/C de pago del ahorro programado se puede realizar **/ -- AIU-1014
     -- verifica si puede DEBITAR de la cta AP --
     pag_cta.pr_ver_operacion(cv.nro_cuenta,
                              314,--tra_padre
                              cv.cod_modulo, --cod_mod_padre
                              cv.cod_modalidad, --cod_mad_padre
                              'D',
                              cv.cod_moneda,
                              cv.sal_total,
                              cv.cod_oficina, --cod_ofi_origen
                              g_ctas.cod_modulo,
                              g_ctas.cod_modalidad,
                              g_ctas.nvo_estado,
                              g_ctas.sal_disponible,
                              v_procesa,
                              503);
     IF nvl(v_procesa,'N') = 'S' THEN
      -- verifica si puede ACREDITAR a la cta capitalizacion de AP --
       pag_cta.pr_ver_operacion(cv.nro_cta_capitalizacion,
                                314,--tra_padre
                                cv.cod_modulo, --cod_mod_padre
                                cv.cod_modalidad, --cod_mad_padre
                                'C',
                                cv.cod_moneda,
                                cv.sal_total,
                                cv.cod_oficina, --cod_ofi_origen
                                g_ctas.cod_modulo,
                                g_ctas.cod_modalidad,
                                g_ctas.nvo_estado,
                                g_ctas.sal_disponible,
                                v_procesa,
                                602);
       if v_procesa = 'S' then
          g_ctas.nro_cuenta := cv.nro_cta_capitalizacion;
          g_movs.fecha      := pag_cal.FU_OBT_FEC_ACTUAL(3);
          g_movs.cod_moneda := cv.cod_moneda;
          g_movs.monto      := cv.sal_total;

          if nvl(fug_obt_pardinamico('ACT_VAL_CTA_BASICA'),'N') = 'S' then --ACTIVA VALIDACIONES DE CUENTA BASICA
           -- Verifica si corresponde a una cuenta basica
           v_per_cta_basica := fua_es_cta_basica(g_ctas.nro_cuenta);
           if v_per_cta_basica = 'S' then
              begin
                select cod_modulo, cod_modalidad
                  into v_cod_modulo, v_cod_modalidad
                  from ge_cuentas
                 where nro_cuenta = g_ctas.nro_cuenta;
              exception
                when others then
                  null;
              end;
               /**
                  Vemos si está configurado por transaccion
                  para excluir el control de limite de cta basica
               **/
              begin
                select 'S'
                    into v_exc_transaccion
                    from ge_gru_transacciones_det t
                   where cod_gru_transaccion = 91
                     and cod_modulo = v_cod_modulo
                     and cod_modalidad = v_cod_modalidad
                     and cod_transaccion = 314;

              exception
                when others then
                  v_exc_transaccion := 'N';
              end;

              if nvl(v_exc_transaccion, 'N') = 'N' then
                begin
                  select 'S'
                    into v_exc_transaccion
                    from ge_gru_transacciones_det t
                   where cod_gru_transaccion = 91
                     and cod_modulo = v_cod_modulo      --cod_modulo
                     and cod_modalidad = v_cod_modalidad   --cod_modalidad
                     and cod_transaccion = 602;
                exception
                  when others then
                    v_exc_transaccion := 'N';
                end;
              end if;

              if nvl(v_exc_transaccion, 'N') = 'N' then
                 --Verificar si es un credito--
                 begin
                   select b.tipo
                     into v_tipo
                     from ge_transacciones b
                    where b.cod_modulo = v_cod_modulo
                      and b.cod_modalidad = v_cod_modalidad --cod_modalidad
                      and b.cod_transaccion = 602;
                 exception
                   when others then
                     v_tipo := 'X';
                 end;
                 if nvl(v_tipo, 'X') = 'C' then
                    --Buscar el saldo de la cuenta--
                    declare
                      v_pri_dia_mes ge_movimientos.fecha%type;
                    begin
                      v_pri_dia_mes := (trunc(pag_cal.FU_OBT_FEC_HABIL(g_movs.fecha, 1, 1), 'mm'));
                      select sum(monto)
                        into v_tot_cre_mes
                        from ge_mov_cre_cta_bas
                       where fecha between v_pri_dia_mes and g_movs.fecha
                         and nro_cuenta = g_ctas.nro_cuenta;
                     exception
                       when others then
                         v_tot_cre_mes := 0;
                     end;
                    --Buscar el limite de la cuenta basica--
                    v_mto_sal_lim_cta_basica := NVL(fug_obt_pardinamico('MTO_MAX_AHO_CTA_BASICA',NULL,NULL,g_movs.COD_MONEDA),0);
                    if ( nvl(v_tot_cre_mes,0) + nvl(g_movs.monto,0)) > nvl(v_mto_sal_lim_cta_basica,0) then
                      v_mensaje := 'La Cuenta Basica '||g_ctas.nro_cuenta||' no puede superar Limite de Credito establecido';
                      v_procesa := 'N';
                    end if;
                 end if;
              end if;
           end if;
         end if;
       else
         v_mensaje := 'Credito Cta '||cv.nro_cta_capitalizacion||' Error: '||pag_cta.fu_obt_cod_error() || ' - ' ||pag_cta.fu_obt_msj_error();
       end if;
     else
       v_mensaje := 'Debito Cta '||cv.nro_cuenta||' Error: '||pag_cta.fu_obt_cod_error() || ' - ' ||pag_cta.fu_obt_msj_error();
     end if;
     IF nvl(v_procesa,'N') = 'S' THEN
       v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,USER,v_es_nocturno);
       IF v_nro_secuencia > 990 THEN
         v_nro_secuencia := -999;
       ELSIF v_nro_secuencia < 0 AND v_nro_secuencia > -10 THEN
         v_hora          := fug_obt_hor_disponible(v_fec_actual,v_hora,USER,v_es_nocturno);
         v_nro_secuencia := 0 ;
       END IF;

       -- Debito a la cuenta --
       pag_cta.pr_act_operacion(cv.nro_cuenta,
                                v_hora, --HORA
                                'D',
                                cv.cod_moneda,
                                cv.sal_total,
                                314,
                                503,
                                cv.nro_cuenta,
                                NULL, --COTIZACION
                                cv.cod_oficina, --cod_ofi_origen
                                cv.cod_modulo, --cod_mod_padre
                                cv.cod_modalidad, --cod_mad_padre
                                NULL, --cod_tasa
                                NULL, --val_tasa
                                'Pago Ahorro Programado a la cta '||cv.nro_cta_capitalizacion,
                                'N', --emi_aviso
                                v_nro_secuencia,
                                v_fec_actual);

       IF pag_cta.fu_obt_cod_error() <> 0 THEN
         --Si hubo error, se inserta en el log
          pr_ins_log_error(cv.nro_cuenta, 0, cv.sal_total, v_programa, 'Debito # '||pag_cta.fu_obt_cod_error() || ' - ' ||pag_cta.fu_obt_msj_error());
       ELSE
         -- Credito a la cuenta --
         pag_cta.pr_act_operacion(cv.nro_cta_capitalizacion,
                                  v_hora, --HORA
                                  'C',
                                  cv.cod_moneda, --Moneda de la Operacion
                                  cv.sal_total,
                                  314,
                                  602, --COD_TRA_HIJO (602)
                                  cv.nro_cuenta,
                                  NULL, --COTIZACION
                                  cv.cod_oficina, --cod_ofi_origen
                                  cv.cod_modulo, --cod_mod_padre
                                  cv.cod_modalidad, --cod_mad_padre
                                  NULL, --cod_tasa
                                  NULL, --val_tasa
                                  'Pago de Ahorro Programado de la Cuenta ' || cv.nro_cuenta,
                                  'S', --emi_aviso
                                  v_nro_secuencia,
                                  v_fec_actual);

         IF pag_cta.fu_obt_cod_error() <> 0 THEN
          --Actualizacion con problemas, se inserta en el log
          pr_ins_log_error(cv.nro_cuenta, 0, cv.sal_total, v_programa, 'Error Credito # '||pag_cta.fu_obt_cod_error() || ' - ' ||pag_cta.fu_obt_msj_error());
         END IF;
       END IF;
     END IF;

     if v_procesa = 'N' then
        pr_ins_log_error(cv.nro_cuenta, 0, cv.sal_total, v_programa, v_mensaje);
     end if;
    END LOOP;

    /** Eliminamos las cuentas configuradas para exclusion en el cierre **/
    if fug_obt_pardinamico('CTA_AHP_EXCLUIR') is not null then
      delete ge_par_dinamicos p where p.parametro = 'CTA_AHP_EXCLUIR';
    end if;

  exception
    when others then
      raise_application_error(-20051, 'Excluir la cuenta con error en el parametro dinamico CTA_AHP_EXCLUIR. Cta: '||v_cta_error||' - '||v_programa||' # '||SQLERRM);
  END;
  --
  PROCEDURE pr_cap_aho_programado(p_nro_cuenta         IN VARCHAR2 := NULL,
                                  p_ins_capitalizacion IN VARCHAR2 := 'S',
                                  p_fec_capitalizacion IN DATE,
                                  p_mto_interes        OUT NUMBER) IS

    v_mto_interes       NUMBER(18, 2) := 0;
    r_acpro             ah_cta_plazos%ROWTYPE;
    v_fec_inicial       DATE;
    v_fec_final         DATE;
    v_fec_actual        DATE;
    v_fec_proxima       ge_calendarios.fec_proxima%TYPE;
    v_hora              ge_movimientos.hora%TYPE;
    v_nro_secuencia     ge_movimientos.nro_secuencia%TYPE;
    v_ult_dia_mes       ge_calendarios.ult_dia_mes%TYPE;
    v_tot_interes       NUMBER(18, 2) := 0;
    v_cta_error         ge_cuentas.nro_cuenta%type;
    v_programa          varchar2(60) := 'PAA_PRO.PR_CAP_AHO_PROGRAMADO';
    v_nocturno          varchar2(1);

    /* Calculo de Capitalizacion */
    PROCEDURE lp_cal_capitalizac(p_mto_interes OUT NUMBER);
    PROCEDURE lp_act_sal_fec_capit;
    PROCEDURE lp_act_sal_mes_diari(p_mto_interes IN NUMBER := 0);

    v_msj varchar2(250);
    ---------------------------------------------
    -- definicion de cursor para ciclo general --
    ---------------------------------------------
    CURSOR c_aho_pro IS
      SELECT nro_cuenta, denominacion,cod_modulo, cod_modalidad,
             cod_oficina, dig_verificador, cod_moneda,
             can_fir_requeridas, can_fir_registradas,  fec_apertura,  tip_capitalizacion,
             nvl(tas_personalizada,'N'), cod_tasa,
             aut_pendiente, cod_usu_promotor, est_batch, estado, fec_cam_estado,
             fec_ult_movimiento, hor_ult_movimiento, fec_ult_capitalizacion, capital,
             sal_ret_batch, sal_retenido, sal_blo_batch, sal_bloqueado,
             sal_tot_batch, sal_total, tra_prohibida, val_tasa, nro_cta_capitalizacion
        FROM ah_cta_plazos a
       WHERE a.cod_modalidad = 38
         AND a.estado NOT IN ('C','T','P','A','X')
         AND ((nro_cuenta = p_nro_cuenta)
          OR (p_nro_cuenta IS NULL AND  a.fec_vencimiento <= v_fec_actual))-- Al vencimiento
         AND (fec_ult_capitalizacion IS NULL OR fec_ult_capitalizacion < v_fec_actual)
         FOR UPDATE OF cod_modalidad;

    /* Calculo de Capitalizacion */
    PROCEDURE lp_cal_capitalizac(p_mto_interes OUT NUMBER) IS

      r_gmovi        ge_movimientos%ROWTYPE;
      v_val_tasa     ge_tas_fechas.val_tasa%TYPE;
      v_mto_interes  NUMBER(18, 2) := 0;

      BEGIN
         --Obtiene Fecha Inicial
         IF r_acpro.fec_ult_capitalizacion IS NULL THEN
            v_fec_inicial:= r_acpro.fec_apertura;
         ELSE
            v_fec_inicial:= r_acpro.fec_ult_capitalizacion + 1;
         END IF;
         --Inicializa fecha final
         v_fec_final   := v_ult_dia_mes;
         v_mto_interes := fu_obt_dev_acu_ah_sal(r_acpro.nro_cuenta,to_number(to_char(add_months(pag_cal.g_fec_actual,1),'YYYYMM')) );

                IF v_mto_interes > 0 THEN
                  v_nro_secuencia := v_nro_secuencia;
                  IF v_nro_secuencia = 999 THEN
                     v_hora          := fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N');
                     v_nro_secuencia := 1;
                  END IF;

                  r_gmovi.cod_usuario     := USER;
                  r_gmovi.hora            := v_hora;
                  r_gmovi.nro_secuencia   := v_nro_secuencia+1;
                  r_gmovi.cod_oficina     := r_acpro.cod_oficina;
                  r_gmovi.nro_cuenta      := r_acpro.nro_cuenta;
                  r_gmovi.cod_moneda      := r_acpro.cod_moneda;
                  r_gmovi.fec_valor       := v_fec_actual;
                  r_gmovi.fecha           := v_fec_actual;
                  r_gmovi.cod_mod_padre   := r_acpro.cod_modulo;
                  r_gmovi.cod_mad_padre   := r_acpro.cod_modalidad;
                  r_gmovi.cod_tra_padre   := 325;
                  r_gmovi.cod_transaccion := 609;
                  r_gmovi.monto           := v_mto_interes;
                  r_gmovi.estado          := 'N';
                  r_gmovi.cod_ofi_origen  := r_acpro.cod_oficina;
                  r_gmovi.cod_tasa        := r_acpro.cod_tasa;
                  r_gmovi.val_tasa        := v_val_tasa;
                  r_gmovi.reversado       := 'N';
                  r_gmovi.emi_aviso       := 'N';
                  r_gmovi.protegido       := 'N';
                  r_gmovi.cod_modulo      := r_acpro.cod_modulo;
                  r_gmovi.cod_modalidad   := r_acpro.cod_modalidad;
                  r_gmovi.concepto        := 'Interes Ah.Programado acreditado a la cta '||r_acpro.nro_cta_capitalizacion;
                  -- Inserta en GE_MOVIMIENTOS
                  /* AIU-1712 */
                  pr_mov_nocturno(v_nocturno);
                  if v_nocturno = 'S' then
                    r_gmovi.fecha := pag_cal.FU_OBT_FEC_SIG_HAB(v_fec_actual,61);
                  end if;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi, v_nocturno);
                  v_nro_secuencia := v_nro_secuencia+1;
                  -- Credito a la cuenta de capitalizacion
                  pag_cta.pr_act_operacion(r_acpro.nro_cta_capitalizacion,
                                           v_hora,
                                           'C',
                                           r_acpro.cod_moneda,
                                           v_mto_interes,
                                           325,
                                           602,
                                           NULL,
                                           NULL,
                                           r_acpro.cod_oficina,
                                           r_acpro.cod_modulo,
                                           r_acpro.cod_modalidad,
                                           r_acpro.cod_tasa,
                                           v_val_tasa,
                                           'Capitalizacion de Interes del Ah.Programado '||r_acpro.nro_cuenta,
                                           'N',
                                           v_nro_secuencia,
                                           v_fec_actual);

                  --Actualiza Saldos y Fecha de Ultima Capitalizacion
                  lp_act_sal_fec_capit;

          END IF;
         p_mto_interes := v_mto_interes;
      END;

    /* Inserta registro en Capitalizaciones */

    /* Actualiza Saldo Ult. y Fec Ultima Capitalizacion en CTA_VISTAS */
    PROCEDURE lp_act_sal_fec_capit IS
    BEGIN
       --Actualiza Saldos y Fecha de Ultima Capitalizacion
       UPDATE ah_cta_plazos-- ah_cta_vistas
          SET fec_ult_capitalizacion = v_fec_actual
        WHERE nro_cuenta = r_acpro.nro_cuenta;
    END;

    /* Actualiza Saldo Acumulado Diario y Saldo Mensual en AH_SAL_MENSUALES */
    PROCEDURE lp_act_sal_mes_diari(p_mto_interes IN NUMBER := 0) IS

      v_sig_fecha DATE;
      v_can_dias  ah_sal_mensuales.can_dia_acumulado%TYPE;
      v_dummy     VARCHAR2(2);
      v_sig_ano   ah_sal_mensuales.ano%TYPE;
      v_sig_mes   ah_sal_mensuales.mes%TYPE;

      --Definicion del Cursor
      CURSOR c_sal_mensuales IS
         SELECT 'X'
           FROM ah_sal_mensuales
          WHERE nro_cuenta = r_acpro.nro_cuenta
            AND ano = v_sig_ano
            AND mes = v_sig_mes
      FOR UPDATE OF can_creditos;

      BEGIN
         v_sig_fecha := add_months(v_fec_actual,1);
         v_sig_ano   := to_char(v_sig_fecha,'YYYY');
         v_sig_mes   := to_char(v_sig_fecha, 'MM');
         IF c_sal_mensuales%ISOPEN THEN
            CLOSE c_sal_mensuales;
         END IF;
         OPEN c_sal_mensuales;
            FETCH c_sal_mensuales INTO v_dummy;
            IF c_sal_mensuales%FOUND THEN
               v_can_dias := TO_NUMBER(TO_CHAR(v_fec_proxima,'DD'))-1;
               UPDATE ah_sal_mensuales
                  SET sal_acu_diario = nvl(sal_acu_diario,0) + p_mto_interes * v_can_dias,
                      sal_ini_mes    = nvl(sal_ini_mes,0) + p_mto_interes
               WHERE CURRENT OF c_sal_mensuales;
              CLOSE c_sal_mensuales;
           ELSE
              CLOSE c_sal_mensuales;
           END IF;
      END;

  BEGIN
     --Obtiene las Fechas necesarias--------------------------
     pag_cal.pr_obt_dat_calendar(3);
     v_fec_actual    := nvl(p_fec_capitalizacion,pag_cal.g_fec_actual);
     v_ult_dia_mes   := pag_cal.g_ult_dia_mes;
     v_fec_proxima   := pag_cal.g_fec_proxima;
     v_nro_secuencia := 0;
     v_hora          := to_char(SYSDATE,'HH24:MI:SS');
     v_hora          := fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N');

     ---------------------------------------------------------
     IF c_aho_pro%ISOPEN THEN
        CLOSE c_aho_pro;
     END IF;
     OPEN c_aho_pro;
     ---------------------------------------------------------
     -- ciclo general, carga de las variables de cuentas------
     ---------------------------------------------------------
     LOOP
       FETCH c_aho_pro
        INTO r_acpro.nro_cuenta, r_acpro.denominacion, r_acpro.cod_modulo, r_acpro.cod_modalidad,
             r_acpro.cod_oficina, r_acpro.dig_verificador, r_acpro.cod_moneda,
             r_acpro.can_fir_requeridas, r_acpro.can_fir_registradas, r_acpro.fec_apertura, r_acpro.tip_capitalizacion,
             r_acpro.tas_personalizada, r_acpro.cod_tasa,
             r_acpro.aut_pendiente, r_acpro.cod_usu_promotor, r_acpro.est_batch, r_acpro.estado,
             r_acpro.fec_cam_estado,
             r_acpro.fec_ult_movimiento, r_acpro.hor_ult_movimiento, r_acpro.fec_ult_capitalizacion,r_acpro.capital,
             r_acpro.sal_ret_batch, r_acpro.sal_retenido, r_acpro.sal_blo_batch, r_acpro.sal_bloqueado,
             r_acpro.sal_tot_batch, r_acpro.sal_total, r_acpro.tra_prohibida, r_acpro.val_tasa,
             r_acpro.nro_cta_capitalizacion;
        EXIT WHEN c_aho_pro%NOTFOUND;
        v_cta_error := r_acpro.nro_cuenta;
        --Calculo de la Capitalizacion de Ahorro a la Vista
        lp_cal_capitalizac(v_mto_interes);
        v_tot_interes := nvl(v_tot_interes,0) + v_mto_interes;
     END LOOP;
     -----------------------------------------------------
     p_mto_interes := v_tot_interes;
     -----------------------------------------------------
     --            fin ciclo general                    --
     -----------------------------------------------------
     IF c_aho_pro%rowcount = 0 and p_nro_cuenta is null THEN
        v_msj := ' No encontre registros en AH_CTA_PLAZOS';
        raise_application_error(-20052,v_msj);
     elsif c_aho_pro%rowcount = 0 and p_nro_cuenta is not null THEN
        p_mto_interes := 0;
     END IF;

  EXCEPTION
     WHEN OTHERS THEN
        pr_ins_log_error(v_cta_error, 0,0, v_programa, substr(sqlerrm,300));
        raise_application_error(-20053,'Excluir la cuenta con error en el parametro dinamico CTA_AHP_EXCLUIR. Cta: '||v_cta_error||' - '||v_programa||' # '||SQLERRM);
  END;
  --
  PROCEDURE pr_act_ven_aho_prog IS
    v_fec_actual    ge_calendarios.fec_actual%TYPE;
    v_cod_mon_local ba_monedas.cod_moneda%TYPE;
    v_hora          ge_movimientos.hora%TYPE := TO_CHAR(SYSDATE,'HH24:MI:SS');
    v_nro_secuencia ge_movimientos.nro_secuencia%TYPE;
    v_est_modulo    ba_modulos.estado%TYPE := pae_cnf.FU_OBT_EST_MODULO(3);
    v_es_nocturno   VARCHAR2(1) := 'N';

    CURSOR c_cuentas IS
      -- Ahorro Programado Vencidos
      SELECT *
        FROM ah_cta_plazos a
       WHERE a.cod_modalidad = 38
         AND a.estado NOT IN ('C','T','P','A','X')
         AND a.fec_vencimiento <= pag_cal.FU_OBT_FEC_ACTUAL(3);

    PROCEDURE lp_act_est_vencido(p_nro_cuenta IN NUMBER) IS
      r_gmovi ge_movimientos%ROWTYPE;
    BEGIN
      v_cod_mon_local := pag_gen.fu_obt_mon_local;
      pag_cta.pr_set_variables(USER, v_fec_actual, 314, 'N','N', v_nro_secuencia,'V',pag_cta.g_ctas.cod_oficina, pag_cta.g_ctas.cod_modulo,pag_cta.g_ctas.cod_modalidad);
      IF pag_cta.g_ctas.estado != 'B' THEN
        pag_cta.pr_act_estado(pag_cta.g_ctas.nro_cuenta,
                              'V',
                              v_fec_actual,
                              v_hora,
                              p_nro_cuenta);
      END IF;
      v_nro_secuencia := v_nro_secuencia + 1;
      -- Insertar movimiento de Cambio estado a vencido del Ahorro Programado
      v_nro_secuencia := v_nro_secuencia + 1;
      IF v_nro_secuencia > 990 THEN
       v_nro_secuencia := 0;
       v_hora          := fug_obt_hor_disponible(v_fec_actual,v_hora,USER,v_es_nocturno);
      END IF;
      r_gmovi.cod_usuario     := USER;
      r_gmovi.hora            := v_hora;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.cod_mod_padre   := pag_cta.g_ctas.cod_modulo;
      r_gmovi.cod_mad_padre   := pag_cta.g_ctas.cod_modalidad;
      r_gmovi.cod_oficina     := pag_cta.g_ctas.cod_oficina;
      r_gmovi.cod_modulo      := pag_cta.g_ctas.cod_modulo;
      r_gmovi.cod_modalidad   := pag_cta.g_ctas.cod_modalidad;
      r_gmovi.nro_cuenta      := pag_cta.g_ctas.nro_cuenta;
      r_gmovi.cod_moneda      := pag_cta.g_ctas.cod_moneda;
      r_gmovi.cod_tra_padre   := 314;
      r_gmovi.cod_transaccion := 403;
      r_gmovi.concepto        := 'Cambio de Estado - Vencimiento Ahorro Programado';
      r_gmovi.est_cuenta      := 'V';
      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.protegido       := 'N';
      r_gmovi.nro_documento   := p_nro_cuenta;
      r_gmovi.cod_ofi_origen  := pag_cta.g_ctas.cod_oficina;
      r_gmovi.fecha           := v_fec_actual;
      r_gmovi.fec_valor       := v_fec_actual;
      pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
    END;

  BEGIN
    v_fec_actual    := pag_cal.fu_obt_fec_actual(3);
    v_cod_mon_local := pag_gen.fu_obt_mon_local;

    IF v_est_modulo = 2 THEN
      v_es_nocturno := 'N'; -- N=Abierto,  S=Cerrado
    ELSE
      v_es_nocturno := 'S'; -- N=Abierto,  S=Cerrado
    END IF;

    v_hora          := fug_obt_hor_disponible(v_fec_actual,v_hora,USER,v_es_nocturno);
    v_nro_secuencia := 0;
    FOR c IN c_cuentas LOOP
      -- Recuperar datos de la cuenta en el registro global g_ctas
      pag_cta.pr_obt_cuenta(c.nro_cuenta);
      -- Cambio de estado
      lp_act_est_vencido(c.nro_cuenta);
    END LOOP;
  END;

  FUNCTION fu_obt_can_cuo_pag(p_nro_cuenta IN ah_pro_cuotas.nro_cuenta%TYPE) RETURN NUMBER is
    v_cantidad number(3);
  begin
    select count(1)
      into v_cantidad
      from ah_pro_cuotas c
     where c.nro_cuenta = p_nro_cuenta
       and c.estado = 'P';
   return v_cantidad;
  exception
   when others then
    return 0;
  end;

  function fu_obt_dev_acu(p_nro_cuenta IN ah_pro_cuotas.nro_cuenta%TYPE)
    return ah_devengados.mto_dev_acumulado%type is
    v_dev_acumulado ah_devengados.mto_dev_acumulado%type;
  begin
   select sum(a.mto_dev_acumulado)
     into v_dev_acumulado
     from ah_devengados a
    where a.nro_cuenta = p_nro_cuenta;
   return v_dev_acumulado;
  exception
   when others then
    raise_application_error(-20054,'Error al buscar dev. Acumulado. Nro. Cuenta: '|| p_nro_cuenta ||'  - ' ||sqlerrm  );
  end;

  function fu_obt_dev_acu_ah_sal(p_nro_cuenta in ah_pro_cuotas.nro_cuenta%TYPE, anio_mes in number)
    return ah_sal_mensuales.mto_int_devengado%type is
    v_dev_acumulado ah_devengados.mto_dev_acumulado%type;

  begin
   select sum(a.mto_int_devengado)
     into v_dev_acumulado
     from ah_sal_mensuales a
    where a.nro_cuenta = p_nro_cuenta
      and to_number(a.ano|| lpad(a.mes, 2 ,'0') ) < anio_mes;
   return nvl(v_dev_acumulado,0);
   exception
     when others then
       raise_application_error(-20055,'Error al buscar dev. Acumulado. Nro. Cuenta: '|| p_nro_cuenta ||'  - ' ||sqlerrm  );
  end;

  PROCEDURE pr_pro_aho_programado(p_nro_cuenta         IN VARCHAR2 default NULL,
                                  p_ins_capitalizacion IN VARCHAR2 default 'S',
                                  p_fec_capitalizacion IN DATE,
                                  p_mto_interes        OUT NUMBER) IS

    v_mto_interes       NUMBER(18, 2) := 0;
    r_acpro             ah_cta_plazos%ROWTYPE;
    v_ano_actual        ah_sal_mensuales.ano%TYPE;
    v_mes_actual        ah_sal_mensuales.mes%TYPE;
    v_fec_inicial       DATE;
    v_fec_final         DATE;
    v_fec_actual        DATE;
    v_sal_acu_diario    ah_sal_mensuales.sal_acu_diario%TYPE;
    v_can_dia_acumulado ah_sal_mensuales.can_dia_acumulado%TYPE;
    v_ult_dia_mes       ge_calendarios.ult_dia_mes%TYPE;
    v_tot_interes       NUMBER(18, 2) := 0;
    v_redondeo          NUMBER(5);
    v_cta_error         ge_cuentas.nro_cuenta%type;

    /* Calculo de Capitalizacion */
    PROCEDURE lp_cal_capitalizac(p_mto_interes OUT NUMBER);

    /* Calcula Saldo promedio de Ahorro */
    PROCEDURE lp_cal_sal_promedio(p_nro_cuenta        IN ah_cta_vistas.nro_cuenta%TYPE,
                                  p_fec_inicial       IN DATE,
                                  p_fec_fin           IN DATE,
                                  p_sal_minimo        IN NUMBER := 0,
                                  p_sal_promedio      IN OUT NUMBER,
                                  p_cal_interes       IN OUT VARCHAR2,
                                  p_sal_acu_diario    OUT ah_sal_mensuales.sal_acu_diario%TYPE,
                                  p_can_dia_acumulado OUT ah_sal_mensuales.can_dia_acumulado%TYPE);

    /* Calcula el Saldo Acumulado */
    PROCEDURE lp_cal_sal_acumulado(p_cod_modulo        IN ge_transacciones.cod_modulo%TYPE,
                                   p_cod_modalidad     IN ge_transacciones.cod_modalidad%TYPE,
                                   p_cod_oficina       IN ah_cta_vistas.cod_oficina%TYPE,
                                   p_nro_cuenta        IN ah_cta_vistas.nro_cuenta%TYPE,
                                   p_fec_inicial       IN DATE,
                                   p_fec_final         IN DATE,
                                   p_cod_moneda        IN ba_monedas.cod_moneda%TYPE,
                                   p_saldo             IN OUT NUMBER,
                                   p_sal_promedio      IN OUT ah_capitalizaciones.sal_promedio%TYPE,
                                   p_sal_acumulado     IN OUT NUMBER,
                                   p_can_dia_acumulado IN OUT ah_sal_mensuales.can_dia_acumulado%TYPE);

    /* Calcula Interes de Ahorro a la Vista */
    PROCEDURE lp_cal_int_aho_pro(rp_acpro            IN OUT ah_cta_plazos%ROWTYPE,
                                 p_cod_transaccion   IN ge_transacciones.cod_transaccion%TYPE,
                                 p_fec_inicial       IN DATE,
                                 p_fec_final         IN DATE,
                                 p_saldo             IN OUT ah_cta_vistas.sal_ult_capitalizacion%TYPE,
                                 p_sal_promedio      IN NUMBER := 0,
                                 p_sal_acu_diario    IN ah_sal_mensuales.sal_acu_diario%TYPE,
                                 p_can_dia_acumulado IN ah_sal_mensuales.can_dia_acumulado%TYPE,
                                 p_mto_interes       OUT NUMBER);

    /* Actualiza Saldo Ult. y Fec Ultima Capitalizacion en CTA_VISTAS */
    PROCEDURE lp_act_sal_fec_capit(p_fec date);

    /* Actualiza Saldo Acumulado Diario y Saldo Mensual en AH_SAL_MENSUALES */
    PROCEDURE lp_act_mto_int_acumulado(p_mto_interes IN NUMBER := 0, fec_pro date );

    v_msj varchar2(250);
    ---------------------------------------------
    -- definicion de cursor para ciclo general --
    ---------------------------------------------
    CURSOR c_aho_pro IS
      SELECT nro_cuenta, denominacion,cod_modulo, cod_modalidad,
             cod_oficina, dig_verificador, cod_moneda,
             can_fir_requeridas, can_fir_registradas,  fec_apertura,  tip_capitalizacion,
             nvl(tas_personalizada,'N'), cod_tasa,
             aut_pendiente, cod_usu_promotor, est_batch, estado, fec_cam_estado,
             fec_ult_movimiento, hor_ult_movimiento, fec_ult_provision, capital,
             sal_ret_batch, sal_retenido, sal_blo_batch, sal_bloqueado,
             sal_tot_batch, sal_total, tra_prohibida, val_tasa, nro_cta_capitalizacion
        FROM ah_cta_plazos a
       WHERE a.cod_modalidad = 38
         AND a.estado NOT IN ('C','T','P','A','X')
         AND ((nro_cuenta = p_nro_cuenta)
          OR (p_nro_cuenta IS NULL AND  MOD(v_mes_actual,TIP_CAPITALIZACION) = 0))-- Al vencimiento
         AND (fec_ult_provision IS NULL OR fec_ult_provision < v_fec_actual)
         --------------------------------------------------
         FOR UPDATE OF cod_modalidad;

    /* Calculo de Capitalizacion */
    PROCEDURE lp_cal_capitalizac(p_mto_interes OUT NUMBER) IS

      v_sal_inicial  ah_cta_vistas.sal_ult_capitalizacion%TYPE;
      v_mto_interes  NUMBER(18, 2) := 0;
      v_sal_promedio NUMBER(18, 2) := 0;

      /* Indica si calcula interes (S/N) ah_cta_plazos */
      v_cal_interes       VARCHAR2(1) := 'N';
      v_fec_ult_provision date;

      BEGIN
         --Obtiene Fecha Inicial
         IF r_acpro.fec_ult_provision IS NULL THEN
            v_fec_inicial:= r_acpro.fec_apertura;
         ELSE
            v_fec_inicial:= r_acpro.fec_ult_provision + 1;
         END IF;

         --Inicializa el Saldo Inicial  y fecha final
         v_sal_inicial := r_acpro.capital;--r_acvis.sal_ult_capitalizacion;
         v_fec_final   := v_ult_dia_mes;

         --Obtiene el Saldo Promedio, Saldo Acumulado, Cant. Dias Acumulado
         lp_cal_sal_promedio(r_acpro.nro_cuenta,
                             v_fec_inicial,
                             v_fec_final,
                             0,
                             --- OUT
                             v_sal_promedio,
                             v_cal_interes,
                             v_sal_acu_diario,
                             v_can_dia_acumulado);

            lp_cal_int_aho_pro(r_acpro,
                               609,--cod_transaccion
                               v_fec_inicial,
                               v_fec_final,
                               v_sal_inicial,
                               v_sal_promedio,
                               v_sal_acu_diario,
                               v_can_dia_acumulado,
                               -- OUT
                               v_mto_interes);

                   if p_nro_cuenta is not null then
                     v_fec_ult_provision := v_fec_actual;
                   else
                     v_fec_ult_provision := v_ult_dia_mes;
                   end if;

                  lp_act_sal_fec_capit(v_fec_ult_provision);
                  lp_act_mto_int_acumulado(v_mto_interes, v_fec_ult_provision);

         p_mto_interes := v_mto_interes;
      END;

    /* Calcula Saldo promedio de Ahorro */
    PROCEDURE lp_cal_sal_promedio(p_nro_cuenta        IN ah_cta_vistas.nro_cuenta%TYPE,
                                  p_fec_inicial       IN DATE,
                                  p_fec_fin           IN DATE,
                                  p_sal_minimo        IN NUMBER := 0,
                                  p_sal_promedio      IN OUT NUMBER,
                                  p_cal_interes       IN OUT VARCHAR2,
                                  p_sal_acu_diario    OUT ah_sal_mensuales.sal_acu_diario%TYPE,
                                  p_can_dia_acumulado OUT ah_sal_mensuales.can_dia_acumulado%TYPE) IS

      v_mes_actual        ah_sal_mensuales.mes%TYPE;
      v_ano_actual        ah_sal_mensuales.ano%TYPE;
      v_fec_actual        DATE;
      v_can_dia_acumulado ah_sal_mensuales.can_dia_acumulado%TYPE;
      v_sal_acu_diario    ah_sal_mensuales.sal_acu_diario%TYPE;
      v_tot_dia_acumulado ah_sal_mensuales.can_dia_acumulado%TYPE;
      v_tot_acumulado     NUMBER(18, 2) := 0;

      --Declaracion del Cursor
      CURSOR c_sal_mensuales IS
       SELECT nvl(sal_acu_diario,0), nvl(can_dia_acumulado,0)
         FROM ah_sal_mensuales
        WHERE nro_cuenta = p_nro_cuenta --v_nro_cuenta se toma en el proc. padre pra_capitalizaciones
          AND ano = v_ano_actual
          AND mes = v_mes_actual;
      BEGIN

         p_sal_promedio      := 0;
         v_tot_acumulado     := 0;
         v_tot_dia_acumulado := 0;
         p_cal_interes       := 'N';
         v_fec_actual        := p_fec_inicial; --p_fec_inicial se inicializa en lp_cal_capitalizac.
         v_ano_actual        := to_number(to_char(v_fec_actual,'YYYY'));
         v_mes_actual        := to_number(to_char(v_fec_actual,'MM'));

         ----------------------------------------------------------------------------
         -- La fecha  actual se va incrementando en 1 mes.               --
         -- Mientras que sea menor que la fecha final recibida como parametros     --
         -- calcula el acumulado de saldo, y al salir calcula el saldo promedio    --
         ----------------------------------------------------------------------------
         --p_fec_fin, se inicializa en el padre, pra_capitalizacion
         WHILE to_number(to_char(v_fec_actual, 'YYYYMM')) <=
               to_number(to_char(p_fec_fin, 'YYYYMM')) LOOP
            IF c_sal_mensuales%ISOPEN THEN
               CLOSE c_sal_mensuales;
            END IF;
            OPEN c_sal_mensuales;
            FETCH c_sal_mensuales INTO v_sal_acu_diario, v_can_dia_acumulado;

            -- acumula saldo acumulado y cantidad de dias --
            ------------------------------------------------
               v_tot_acumulado     := v_tot_acumulado + nvl(v_sal_acu_diario,0);
               v_tot_dia_acumulado := v_tot_dia_acumulado + nvl(v_can_dia_acumulado,0);
               v_fec_actual        := ADD_MONTHS(v_fec_actual, 1);
               v_ano_actual        := TO_NUMBER(TO_CHAR(v_fec_actual,'YYYY'));
               v_mes_actual        := TO_NUMBER(TO_CHAR(v_fec_actual,'MM'));

              -- ve si el saldo promedio calculado es mayor o igual
              -- al saldo minimo pactado
              -----------------------------------------------------
              if v_can_dia_acumulado > 0 then
                p_sal_promedio := v_sal_acu_diario / v_can_dia_acumulado;
                IF p_sal_promedio >= p_sal_minimo THEN
                   p_cal_interes := 'S';
                END IF;
              end if;
         END LOOP;

         -- calcula saldo promedio --
         ----------------------------
         p_sal_acu_diario    := v_tot_acumulado;
         p_can_dia_acumulado := v_tot_dia_acumulado;

         IF v_tot_dia_acumulado = 0 THEN
            p_cal_interes  := 'N';
            p_sal_promedio := 0;
         ELSE
            p_sal_promedio := v_tot_acumulado / v_tot_dia_acumulado;
         END IF;
         IF c_sal_mensuales%ISOPEN THEN
            CLOSE c_sal_mensuales;
         END IF;
      END;

    /* Calcula el Saldo Acumulado */
    PROCEDURE lp_cal_sal_acumulado(p_cod_modulo        IN ge_transacciones.cod_modulo%TYPE,
                                   p_cod_modalidad     IN ge_transacciones.cod_modalidad%TYPE,
                                   p_cod_oficina       IN ah_cta_vistas.cod_oficina%TYPE,
                                   p_nro_cuenta        IN ah_cta_vistas.nro_cuenta%TYPE,
                                   p_fec_inicial       IN DATE,
                                   p_fec_final         IN DATE,
                                   p_cod_moneda        IN ba_monedas.cod_moneda%TYPE,
                                   p_saldo             IN OUT NUMBER,
                                   p_sal_promedio      IN OUT ah_capitalizaciones.sal_promedio%TYPE,
                                   p_sal_acumulado     IN OUT NUMBER,
                                   p_can_dia_acumulado IN OUT ah_sal_mensuales.can_dia_acumulado%TYPE) IS

      BEGIN
       --- Busca el saldo promedio ---
       pag_cta.pr_obt_sal_promedio (p_cod_modulo,
                                    p_cod_modalidad,
                                    p_cod_oficina,
                                    p_nro_cuenta,
                                    p_fec_inicial,
                                    p_fec_final,
                                    p_sal_acumulado,
                                    p_sal_promedio,
                                    p_can_dia_acumulado);
       -- Obtiene el Saldo Final por si tenga que utilizar para el proximo sub-periodo
       BEGIN
        SELECT sal_ini_mes
          INTO p_saldo
          FROM ah_sal_mensuales
         WHERE nro_cuenta = p_nro_cuenta
           AND mes = to_number(to_char(add_months(p_fec_final,1), 'MM'))
           AND ano = to_number(to_char(add_months(p_fec_final,1), 'YYYY'));
       EXCEPTION
        WHEN no_data_found THEN
         p_saldo := 0;
       END;
      END;

    /* Calcula Interes de Ahorro a la Vista */
    PROCEDURE lp_cal_int_aho_pro(rp_acpro            IN OUT ah_cta_plazos%ROWTYPE,
                                 p_cod_transaccion   IN ge_transacciones.cod_transaccion%TYPE,
                                 p_fec_inicial       IN DATE,
                                 p_fec_final         IN DATE,
                                 p_saldo             IN OUT ah_cta_vistas.sal_ult_capitalizacion%TYPE,
                                 p_sal_promedio      IN NUMBER := 0,
                                 p_sal_acu_diario    IN ah_sal_mensuales.sal_acu_diario%TYPE,
                                 p_can_dia_acumulado IN ah_sal_mensuales.can_dia_acumulado%TYPE,
                                 p_mto_interes       OUT NUMBER) IS

      v_mto_interes       NUMBER(18, 2) := 0;
      v_mto_int_acumulado NUMBER(18, 2) := 0;
      v_fin_tasa          VARCHAR2(1)   := 'N';
      v_sig_fec_vigencia  DATE;
      v_fec_inicial       DATE;
      v_fec_final         DATE;
      v_can_dia_acumulado ah_sal_mensuales.can_dia_acumulado%TYPE;
      v_sal_acumulado     NUMBER(18, 2) := 0;
      v_sal_promedio      NUMBER(18, 2) := 0;
      --Para caso Vision
      v_sal_cap           NUMBER(18, 2) := 0;

      BEGIN
         --Obtiene la moneda local
         v_sal_acumulado     := 0;
         v_mto_int_acumulado := 0;
         v_fec_inicial       := p_fec_inicial;
         v_fec_final         := p_fec_final;
         v_fin_tasa          := 'N';
         ---
         LOOP
          EXIT WHEN v_fin_tasa = 'S';
          v_sig_fec_vigencia := p_fec_final + 1;
          v_fec_final        := v_sig_fec_vigencia - 1;
          v_fin_tasa         := 'S';
          -- modificacion para Banco Regional
          IF to_char(v_fec_final,'yyyymm') <> to_char(v_fec_inicial,'yyyymm') THEN
             v_fec_final        := last_day(v_fec_inicial); -- ultimo dia del mes
             v_sig_fec_vigencia := v_fec_final + 1;
             v_fin_tasa         := 'N';
          END IF;
          -- calculo el promedio del sub-periodo
           lp_cal_sal_acumulado(3, --modulo
                                rp_acpro.cod_modalidad,
                                rp_acpro.cod_oficina,
                                rp_acpro.nro_cuenta,
                                v_fec_inicial,
                                v_fec_final,
                                rp_acpro.cod_moneda,
                                --- OUT
                                p_saldo,
                                v_sal_promedio,
                                v_sal_acumulado,
                                v_can_dia_acumulado);

          IF v_can_dia_acumulado > 0 AND (nvl(v_sal_acumulado,0)/nvl(v_can_dia_acumulado,0)) >= 0 THEN
           -- le sumamos el interes acumulado para que replique la formula del calculo de vision
           v_sal_cap     :=  (v_sal_acumulado /v_can_dia_acumulado) + paa_pro.fu_obt_dev_acu_ah_sal(r_acpro.nro_cuenta, to_number(to_char(v_fec_inicial,'YYYYMM')) );
           v_mto_interes :=  pag_gen.fu_cal_int_simple( v_sal_cap ,
                                                        v_can_dia_acumulado,
                                                        r_acpro.val_tasa);
            ELSE
               v_mto_interes := 0;
            END IF;

            ----
            -- Redondeo del Interes.
            ---------------------------------------------------
            -- Si la Moneda de la Cuenta es igual a la Moneda Local
            v_redondeo    := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',rp_acpro.cod_modulo, rp_acpro.cod_modalidad,rp_acpro.cod_moneda);
            v_mto_interes := round(v_mto_interes,v_redondeo);

            --Interes Acumulado
            v_mto_int_acumulado := v_mto_int_acumulado + v_mto_interes;

            -- v_tas_vigente := v_sig_val_tasa;
            v_fec_inicial := v_sig_fec_vigencia;
         END LOOP;
         --- Devolver monto para generar movimiento
         p_mto_interes := v_mto_int_acumulado;
      END;

    /* Inserta registro en Capitalizaciones */
    /* Actualiza Saldo Ult. y Fec Ultima Capitalizacion en CTA_VISTAS */
    PROCEDURE lp_act_sal_fec_capit(p_fec date) IS
    BEGIN
       --Actualiza Saldos y Fecha de Ultima Capitalizacion
       UPDATE ah_cta_plazos-- ah_cta_vistas
          SET fec_ult_provision = p_fec
        WHERE nro_cuenta = r_acpro.nro_cuenta;
    END;

    /* Actualiza Saldo Acumulado Diario y Saldo Mensual en AH_SAL_MENSUALES */
    PROCEDURE lp_act_mto_int_acumulado(p_mto_interes IN NUMBER := 0, fec_pro date) IS

      v_dummy    VARCHAR2(2);
      v_ano      ah_sal_mensuales.ano%TYPE;
      v_mes      ah_sal_mensuales.mes%TYPE;

      --Definicion del Cursor
      CURSOR c_sal_mensuales IS
       SELECT 'X'
         FROM ah_sal_mensuales
        WHERE nro_cuenta = r_acpro.nro_cuenta
          AND ano = v_ano
          AND mes = v_mes
      FOR UPDATE OF can_creditos;
      BEGIN
         v_ano := to_char(fec_pro,'YYYY');
         v_mes := to_char(fec_pro, 'MM');

         IF c_sal_mensuales%ISOPEN THEN
            CLOSE c_sal_mensuales;
         END IF;
         OPEN c_sal_mensuales;
            FETCH c_sal_mensuales INTO v_dummy;
            IF c_sal_mensuales%FOUND THEN
               UPDATE ah_sal_mensuales a
                  SET a.mto_int_devengado = p_mto_interes
               WHERE CURRENT OF c_sal_mensuales;
              CLOSE c_sal_mensuales;
           ELSE
              CLOSE c_sal_mensuales;
           END IF;
      END;

  BEGIN
     --Obtiene las Fechas necesarias--------------------------
     pag_cal.pr_obt_dat_calendar(3);
     v_fec_actual    := nvl(p_fec_capitalizacion,pag_cal.g_fec_actual);
     v_ult_dia_mes   := pag_cal.g_ult_dia_mes;
     v_mes_actual    := to_number(to_char(v_fec_actual,'MM'));
     v_ano_actual    := to_number(to_char(v_fec_actual,'YYYY'));
     ---------------------------------------------------------
     IF c_aho_pro%ISOPEN THEN
        CLOSE c_aho_pro;
     END IF;
     OPEN c_aho_pro;
     ---------------------------------------------------------
     -- ciclo general, carga de las variables de cuentas------
     ---------------------------------------------------------
     LOOP
       FETCH c_aho_pro
        INTO r_acpro.nro_cuenta, r_acpro.denominacion, r_acpro.cod_modulo, r_acpro.cod_modalidad,
             r_acpro.cod_oficina, r_acpro.dig_verificador, r_acpro.cod_moneda,
             r_acpro.can_fir_requeridas, r_acpro.can_fir_registradas, r_acpro.fec_apertura, r_acpro.tip_capitalizacion,
             r_acpro.tas_personalizada, r_acpro.cod_tasa,
             r_acpro.aut_pendiente, r_acpro.cod_usu_promotor, r_acpro.est_batch, r_acpro.estado,
             r_acpro.fec_cam_estado,
             r_acpro.fec_ult_movimiento, r_acpro.hor_ult_movimiento, r_acpro.fec_ult_provision,r_acpro.capital,
             r_acpro.sal_ret_batch, r_acpro.sal_retenido, r_acpro.sal_blo_batch, r_acpro.sal_bloqueado,
             r_acpro.sal_tot_batch, r_acpro.sal_total, r_acpro.tra_prohibida, r_acpro.val_tasa,
             r_acpro.nro_cta_capitalizacion;
        EXIT WHEN c_aho_pro%NOTFOUND;
        --Calculo de la Capitalizacion de Ahorro a la Vista
        v_cta_error   := r_acpro.nro_cuenta;
        lp_cal_capitalizac(v_mto_interes);
        v_tot_interes := nvl(v_tot_interes,0) + v_mto_interes;
     END LOOP;
     -----------------------------------------------------
     p_mto_interes := v_tot_interes;
     -----------------------------------------------------
     --            fin ciclo general                    --
     -----------------------------------------------------
     IF c_aho_pro%rowcount = 0 and p_nro_cuenta is null THEN
        v_msj := ' No encontre registros en AH_CTA_PLAZOS';
        raise_application_error(-20056,v_msj);
     elsif c_aho_pro%rowcount = 0 and p_nro_cuenta is not null THEN
        p_mto_interes := 0;
     END IF;

  EXCEPTION
     WHEN OTHERS THEN
        raise_application_error(-20057, 'Excluir la cuenta con error en el parametro dinamico CTA_AHP_EXCLUIR. Cta: '||v_cta_error||' - '||SQLERRM);
  END;
  function fu_rec_int_ap(p_nro_cuenta  ah_cta_plazos.nro_cuenta%type) RETURN ah_cta_plazos.sal_total%type is

  V_VAL_TASA       AH_CTA_PLAZOS.VAL_TASA%TYPE;
  V_MTO_INTERES    NUMBER(18,2):=0;
  R_CTA            AH_CTA_PLAZOS%ROWTYPE;
  V_CAN_CUO_PAGADA NUMBER(8):=0;
  V_TOT_DIAS       NUMBER(8):=0;
  V_ACU_PROMEDIO   NUMBER(20,2):=0;
  V_REDONDEO       GE_PAR_DINAMICOS.VAL_PARAMETRO%TYPE;

  BEGIN
   SELECT PA.*
     INTO R_CTA
     FROM AH_CTA_PLAZOS PA
    WHERE PA.NRO_CUENTA = P_NRO_CUENTA;

   --IAW - AIU-1700 - 1/4/2025 SE AGREGA EL DECODE
   SELECT AVG((SM.SAL_ACU_DIARIO/DECODE(SM.CAN_DIA_ACUMULADO,0,1,SM.CAN_DIA_ACUMULADO)) + PAA_PRO.FU_OBT_DEV_ACU_AH_SAL(P_NRO_CUENTA,to_number(SM.ANO||lpad(SM.MES, 2, '0')))), SUM(SM.CAN_DIA_ACUMULADO)
     INTO V_ACU_PROMEDIO, V_TOT_DIAS
     FROM AH_SAL_MENSUALES SM
    WHERE SM.NRO_CUENTA=P_NRO_CUENTA;

   V_REDONDEO       := FUG_OBT_PARDINAMICO('VAL_RED_MON_EXTRANJERA', 3, 38, R_CTA.COD_MONEDA);
   V_CAN_CUO_PAGADA := IT.PAA_PRO.FU_OBT_CAN_CUO_PAG(P_NRO_CUENTA);
   V_VAL_TASA       := PAW_BAS.FU_OBT_TAS_PIZARRA(P_PLAZO              => V_CAN_CUO_PAGADA,
                                                  P_MONTO              => R_CTA.SAL_TOTAL,
                                                  P_COD_MONEDA         => R_CTA.COD_MONEDA,
                                                  P_COD_MODULO         => 3, --AHORRO
                                                  P_COD_MODALIDAD      => 31,--AHORRO A LA VISTA
                                                  P_COD_SUB_MODALIDAD  => 1, --GENERAL
                                                  P_TIP_CAPITALIZACION => 1);--MENSUAL

        V_MTO_INTERES := ROUND(( PAG_GEN.FU_CAL_INT_SIMPLE( ROUND(V_ACU_PROMEDIO, V_REDONDEO), V_TOT_DIAS, V_VAL_TASA)), V_REDONDEO);
        RETURN V_MTO_INTERES;
  EXCEPTION
       WHEN OTHERS THEN
          RAISE_APPLICATION_ERROR(-20058,'Error en calculo de interes: '||sqlerrm);
  END;

BEGIN
  pre_cam_for_numerico('.,');
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 3; --Modulo Ahorro
end PAA_PRO;
/
