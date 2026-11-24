CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRA_ATM_desparcea
 (P_PEDIDO varchar2
 )
 RETURN VARCHAR2
 IS

 --
   v_cod_entidad number(3);
   v_es_banco    varchar2(1) := 'N';
   v_clt_deb_nuestro varchar2(1) := 'N';
   v_clt_cre_nuestro varchar2(1) := 'N';
   v_atm_nuestro varchar2(1)     := 'N';
   v_est_modulo  ba_modulos.estado%type;
   v_est_cuenta  ge_cuentas.estado%type;
   v_est_cta_comb ge_cuentas.estado%type;
   v_est_cta_cre ge_cuentas.estado%type;
   v_hor_limite  varchar2(8) := '999999';
   v_tip_servicio varchar2(3);

   -- Variables de la Cuenta
   v_mod_cta_deb ge_movimientos.cod_modulo%type;
   v_mad_cta_deb ge_movimientos.cod_modalidad%type;
   v_mon_cta_deb ge_movimientos.cod_moneda%type;
   v_ofi_cta_deb ge_movimientos.cod_oficina%type;
   v_cod_rub_caja ge_movimientos.cod_rubro%type;
   v_cod_ent_sueldo cc_cta_corrientes.cod_ente%type;
   --30/07/2014: BBVANOR-1259 - Operaciones con Financieras del País sin Banco Sponsor
   v_cod_ent_financiera cc_cta_corrientes.cod_ente%type;
   ---
   v_mod_cta_cre ge_movimientos.cod_modulo%type;
   v_mad_cta_cre ge_movimientos.cod_modalidad%type;
   v_mon_cta_cre ge_movimientos.cod_moneda%type;
   v_ofi_cta_cre ge_movimientos.cod_oficina%type;
   -- v_est_cta_cre ge_movimientos.est_cuenta%type;
   --
   v_ind_rub_debito   varchar2(1) := 'N';
   v_tra_con_debito   ge_movimientos.cod_transaccion%type;
   v_mod_con_debito   ge_movimientos.cod_modulo%type;
   v_mad_con_debito   ge_movimientos.cod_modalidad%type;
   v_cod_rub_debito   ge_movimientos.cod_rubro%type;
   v_nro_cta_fic_deb varchar2(20);

   v_ind_rub_credito  varchar2(1) := 'N';
   v_tra_con_credito  ge_movimientos.cod_transaccion%type;
   v_mod_con_credito  ge_movimientos.cod_modulo%type;
   v_mad_con_credito  ge_movimientos.cod_modalidad%type;
   v_ofi_con_credito  ge_movimientos.cod_oficina%type;
   v_cod_rub_credito  ge_movimientos.cod_rubro%type;
   v_nro_cta_fic_cre varchar2(20);
   v_nro_cta_tarjeta varchar2(20);
   v_mad_bco_pais     ge_modalidades.cod_modalidad%type;
   v_mad_ent_pais     ge_modalidades.cod_modalidad%type :=49;
   v_tip_cuenta       varchar2(02);
   v_cod_persona      ge_clientes.cod_persona%type;
   v_fec_inicio       date;
   --
   --
 --  v_cod_mod     ge_movimientos.cod_modalidad%type; --Modulo de la cuenta
   --v_cod_mad     ge_movimientos.cod_modalidad%type; --Modalidad de la cuenta
   v_cta_combinada     ah_cta_vistas.cta_combinada%type;  --Indicador si es cta. combinada
   v_nro_cta_combinada varchar2(30) := '';
   v_sal_dis_debito    number(18,2) := 0;
   --- Variables del movimiento...
   v_fec_proceso     date;
   v_fec_valor       date;
   v_cod_moneda      varchar2(3);
   v_acu_sobregiro   cc_cta_corrientes.acu_sobregiro%type;
   v_importe         number(18,2) := 0;
   v_imp_debito      number(18,2);
   v_imp_credito     number(18,2);
   v_imp_comision    number(18,2);
   v_cot_debito      ge_movimientos.cotizacion%type;
   v_cot_credito     ge_movimientos.cotizacion%type;
   v_nro_caja        cj_movimientos.nro_caja%type;
   v_ofi_origen      cj_movimientos.cod_oficina%type;
   v_ofi_cta_com ge_movimientos.cod_usuario%type;
   v_hora            cj_movimientos.hora%type;
   v_cod_tra_padre   cj_movimientos.cod_tra_padre%type;
   v_nro_documento   ge_movimientos.nro_documento%type;
   -- ramg: nuevo dato para grabar el nro_atm en doc 2
   v_nro_documento2  ge_movimientos.nro_documento%type;
   -- ramg. fin de campo
   v_nro_documento3  ge_movimientos.nro_documento3%type;
   v_nro_secuencia   ge_movimientos.nro_secuencia%type;
   v_tipo            cj_movimientos.tipo%type; -- indicador de si entrega o recibe (e=entrega, r=recibe)
   v_tip_monto       cj_movimientos.tip_monto%type; -- tipo de monto (e=efectivo, c=cargo nuestro, o=cargo otros)
   v_concepto        ge_movimientos.concepto%type;
   v_nro_cta_cliente varchar2(20);
   ---
   v_cod_modulo number(3)      := 9;    -- Caja
   v_cod_modalidad number(3)   := 91;   -- Caja
/*   v_cod_tip_ope_cambio ge_movimientos.cod_tip_ope_cambio%type := null;
   v_cod_bco_central    ge_movimientos.cod_bco_central%type;*/
   --v_cod_usuario     ge_movimientos.cod_usuario%type := upper(user); /*Propuesta retornar usuario menos usado para ATM*/
   v_cod_usuario     ge_movimientos.cod_usuario%type := fug_obt_pardinamico('COD_USU_ATM_ACTUAL');
   -- Variables para cobros de cargos por extracción.
   --V_COD_TAS_CARGO     GE_MOVIMIENTOS.COD_TASA%TYPE;
   --V_VAL_TAS_CARGO     GE_MOVIMIENTOS.VAL_TASA%TYPE;
   V_VAL_CARGO         GE_MOVIMIENTOS.VAL_TASA%TYPE;
   --V_COD_TRA_IMPUESTO  GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;
   --V_COD_TAS_IMPUESTO  GE_MOVIMIENTOS.COD_TASA%TYPE;
   --V_VAL_TAS_IMPUESTO  GE_MOVIMIENTOS.VAL_TASA%TYPE;
   V_VAL_IMPUESTO      GE_MOVIMIENTOS.VAL_TASA%TYPE;
   v_cargos            ge_movimientos.monto%type;
   v_con_mov_com_bancard ge_movimientos.concepto%type := fug_obt_pardinamico('CON_MOV_COM_BANCARD');
   --
   -- Posibles Respuestas --
   vr_aprobado         varchar2(2) := '00';
   vr_reintente        varchar2(2) := '19';
   vr_no_aprobado      varchar2(2) := '05';
   vr_cta_inexistente  varchar2(2) := '14';
   vr_ope_invalida     varchar2(2) := '12';
   vr_sal_insuficiente varchar2(2) := '51';
   vr_otr_error        varchar2(2) := '99';
   vr_en_cierre        varchar2(2) := '91';
   vr_ver_error        varchar2(2) := '95';
   vr_exe_mto_limite   varchar2(2) := '61'; -- Para operaciones de vuelto
   vr_exe_can_tra_lim   varchar2(2) := '65'; -- Para operaciones de vuelto
   --DYDMR-6700 - Incidencia SAU - ITGF - Operaciones "CASH BACK" Via Infonet
   vr_ope_no_soportada varchar2(2) := '40'; ---Tipo de Operación NO Soportada -
   --
   g_cod_error pag_cta.G_COD_ERROR%type;
   -- Variables para manejar los parametros --
   vp_cta_debito     varchar2(10);
   vp_bco_debito     varchar2(3);
   vp_cta_credito    varchar2(10);
   vp_bco_credito    varchar2(3);
   vp_operacion      varchar2(2);
   vp_extorno        varchar2(2);
   vp_tra_entidad    varchar2(15);
   vp_transaccion    varchar2(15);
   vp_importe        varchar2(15);
   vp_importe2       varchar2(15);
   vp_importe3       varchar2(15);
   vp_can_cheques    varchar2(4);
   vp_moneda         varchar2(2);
   vp_nro_atm        varchar2(3);
   vp_nro_pos        varchar2(2);
   vp_tra_pos        varchar2(4);
   vp_tip_hora       varchar2(3);
   vp_negocio        varchar2(40);
   vp_tra_extornado  varchar2(15);
   vp_bco_atm        varchar2(3);
   vp_bco_aux        varchar2(3);
   --vp_cod_entidad    number(3) := fug_obt_cod_banco;
   vp_cod_ban_fusion number(3) := fug_obt_cod_ban_fusion; --SDGNBATMPR-1-ATM Propios--
   vp_fecha          varchar2(8);
   vp_hora           varchar2(6);
   vp_nom_tar        varchar2(35);
   vp_nro_tarjeta    varchar2(16) := null;
   -- Billetera Zimple / Operaciones sin tarjetas -- CN: 08/2016 --
   vp_tip_ope        varchar2(13); -- Servicio (3 bytes)||Prestación (4 bytes)||Marca (3 bytes)||Producto (3 bytes)
   vp_med_pago       varchar2(2);  -- Medio de Pago para Cobro de Servicios en ATM/POS
   C_DOM_TIP_OPE     CONSTANT varchar2(30) := 'TIP_OPE_SWITCH'; -- Dominio Tipo de Operacion SWITCH
   C_DOM_MED_PAG     CONSTANT varchar2(30) := 'MED_PAG_COB_SERVICIOS'; -- Dominio Medio de Pago Extracto/Servicios
   v_cal_cargo       varchar2(1); -- 08/2016 -- Para calcular el cargo que solo es necesario para la llamada al lp_car_salida luego de procesar la transaccion --
   --
   -- De salida...
   vp_cod_respuesta varchar2(2);
   vp_sal_disponible varchar2(15);
   vp_sig_disponible varchar2(1);
   vp_sal_contable varchar2(15);
   vp_sig_contable varchar2(1);
   vp_can_extractos varchar2(3);
   --
   vp_extractos varchar2(512);
   vp_respuesta varchar2(4000);

   R_GMOVI GE_MOVIMIENTOS%ROWTYPE;
   v_horario     varchar2(1) := 'D'; -- (D) Dia, (T) Tarde, (N) Nocturno
   v_es_nocturno varchar2(1) := 'N';
   v_es_cta_noc  varchar2(1) := 'N';
   --para la impresión
   vi_sal_disponible ge_cuentas.sal_contable%type;
   vi_sal_contable ge_cuentas.sal_contable%type;
   --mensaje de error
   v_msj_error VARCHAR2(2000);
   v_mensaje   varchar2(2000);
   v_nro_solicitud number;
   -- DYDMR-3395 control de llaveo por segundos
   v_tie_llaveo varchar2(1) := 'N';
   v_rev_can_mov number := 0; -- DYDMR-3914 06/2016
   v_pre_aprobada varchar2(350);
   v_nro_seguro ge_cli_seguros.nro_seguro%type;
   v_err_seguro number;
   --comisión bancard de infonet cobranzas
   v_cod_mod_com_ban ba_modulos.cod_modulo%type;
   v_cod_mad_com_ban ge_modalidades.cod_modalidad%type;
   v_cta_com_bancard varchar2(50);
   v_cod_rub_facturador cb_rubros.cod_rubro%type;

   v_ecp_mto_limite ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('ECP_MTO_LIMITE');
   v_ecp_can_limite ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('ECP_CAN_LIMITE');
   v_ind_obt_comision varchar2(1) := 'N';
   v_ind_acr_batch    varchar2(1) := 'N';
   v_est_cta_com_ban cc_cta_corrientes.estado%type;
   v_ind_gen_mov_rev72 varchar2(1) := 'N';
   --Cuenta transaccional
   v_ind_cta_deb_tra varchar2(1);
   v_ind_cta_cre_tra varchar2(1);
   v_ind_cta_com_tra varchar2(1);
   v_hor_referencia varchar2(8);
   --Cuenta Alias Bin 8
   v_nro_cta_cli_credito ah_tar_cta_ficticias.nro_cuenta%type;
   v_nro_cta_cli_debito ah_tar_cta_ficticias.nro_cuenta%type;
   ---------- Definicion de procesos y funciones locales
  -- Billetera Zimple / Operaciones sin tarjetas -- CN: 08/2016 --
  FUNCTION lf_obt_tra_padre(P_DOMINIO IN VARCHAR2, P_VALOR IN VARCHAR2) RETURN NUMBER IS
    v_ret  NUMBER;
  BEGIN
    -- VAL_MINIMO = Servicio (3 bytes) + Prestación (4 bytes) + Marca (3 bytes) + Producto (3 bytes) + Código de Operación (2 bytes)
    select to_number(trim(val_maximo))
      into v_ret
      from ba_cod_referencias
     where dominio          = p_dominio
       and trim(val_minimo) = trim(p_valor);

    return v_ret;
  EXCEPTION
   when others then
      return null;
  END;
  --
  --se extrae la funcion del pas_bce para que al realizar el pase sel mismo no sea necesario bajar el atm
  function lf_obt_cotizacion(p_cod_moneda in ba_monedas.cod_moneda%type,
                             p_tipo       in varchar2 -- C-COMPRA o V-VENTA
                             ) return number is

    v_cotizacion ge_cotizaciones.val_conversion%type;
  begin
    select decode(p_tipo,
                  'C',
                  val_com_electronica,
                  'V',
                  val_ven_electronica,
                  null)
      into v_cotizacion
      from ge_cotizaciones a
     where fecha = (select max(fecha)
                      from ge_cotizaciones
                     where cod_moneda = a.cod_moneda
                       and fecha <= v_fec_proceso)
       and cod_moneda = p_cod_moneda;
    return v_cotizacion;
  exception
    when no_data_found then
      return null;
    when others then
      raise_application_error(-20000,
                              sqlerrm ||
                              'error. al buscar cotizacion de venta ');
  end;
  function lf_obt_hor_disponible(p_fecha       in date,
                                 p_hora        in varchar2,
                                 p_cod_usuario in varchar2,
                                 p_es_nocturno in varchar2)
  return varchar2 is
    /* funcion para obtener la hora que no esté utilizado en movimientos */
    v_existe varchar2(1);
    v_hora   varchar2(8) := p_hora;
  begin
    if p_es_nocturno = 'N' then
      loop
        begin
          select 'S'
            into v_existe
            from ge_movimientos
           where fecha = p_fecha
             and hora = v_hora
             and cod_usuario = p_cod_usuario
             and rownum <= 1;
        exception
          when no_data_found then
            v_existe := 'N';
        end;
        exit when v_existe = 'N';
        v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      end loop;
    else -- es nocturno
      loop
        begin
          select 'S'
            into v_existe
            from ge_movimientos_noc
           where fecha = p_fecha
             and hora = v_hora
             and cod_usuario = p_cod_usuario
             and rownum <= 1;
        exception
          when no_data_found then
            v_existe := 'N';
        end;
        exit when v_existe = 'N';
        v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      end loop;
    end if;
    --
    return v_hora;
  end;

   /*
   || DYDMR-763 Diferencia de saldo IT y ATM - SC 5612
   */
   procedure lp_ins_ge_movimiento
   is
      v_ins_movimiento varchar2(1) := 'N';
      v_can_intentos   number := 0;
      v_cod_sub_modalidad ge_cuentas.cod_sub_modalidad%type;
      v_liberado varchar2(1);
      v_fec_acreditacion date;
      v_tip_operacion ge_mov_dat_adicionales.tip_operacion%type;
      v_nro_cta_deb_batch ge_mov_dat_adicionales.nro_cta_deb_batch%type;
   begin
      if v_nro_secuencia > 996 then
         v_hora := fug_obt_hor_disponible(v_fec_proceso, v_hora, v_cod_usuario, v_es_nocturno);
         r_gmovi.hora    := v_hora;
         v_nro_secuencia := -999;
      end if;
      while v_ins_movimiento = 'N' and v_can_intentos <= 10 loop
         begin
            v_msj_error      := null; -- CORECTRB-2 ABR/2018
            PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
            v_ins_movimiento := 'S';
         exception
            when others then
               v_hora           := FUG_OBT_HOR_DISPONIBLE(v_fec_proceso,
                                                          v_hora,
                                                          v_cod_usuario,
                                                          v_es_nocturno);
               r_gmovi.hora     := v_hora;
               v_ins_movimiento := 'N';
               v_can_intentos   := v_can_intentos + 1;
               v_msj_error      := sqlerrm;
         end;
      end loop;
      if v_ins_movimiento = 'N' then
         raise_application_error(-20000, v_msj_error);
      else
         if r_gmovi.cod_modalidad in (41, 31) and r_gmovi.cod_tra_padre not in (425, 309) then
            begin
              select cod_sub_modalidad
                into v_cod_sub_modalidad
                from ge_cuentas
               where nro_cuenta = R_GMOVI.Nro_Cuenta;
            exception
              when others then
                v_cod_sub_modalidad := 1;
            end;
            if nvl(v_ind_acr_batch, 'N') = 'S' or v_cod_sub_modalidad = 25 then
               if nvl(v_ind_acr_batch, 'N') = 'S' then
                  v_liberado := 'N';
                  v_tip_operacion := 'BCH';
                  v_nro_cta_deb_batch := nvl(vp_cta_debito,v_nro_cta_fic_deb);

               else
                  v_liberado := 'S';
                  v_tip_operacion := 'TRA';
                  v_fec_acreditacion := r_gmovi.fecha;
                  v_nro_cta_deb_batch := null;
               end if;
               declare
                  v_det_error ge_mov_dat_adicionales_err.det_error%type;
                  v_fec_cobro date;
               begin
                  if vp_extorno = 99 then
                     v_fec_cobro :=  trunc(sysdate);
                     v_hor_referencia := to_char(sysdate,'HH24:MI:SS');
                  else
                    begin
                      v_fec_cobro := to_date(vp_fecha, 'ddmmyyyy');
                    exception
                      when others then
                        v_fec_cobro := trunc(sysdate);
                    end;
                  end if;
                  begin
                    insert into ge_mov_dat_adicionales (fecha, fec_valor, cod_usuario, hora, nro_secuencia, hor_referencia,
                                                cod_modulo, cod_modalidad, nro_cuenta, nro_cta_deb_batch, cod_tra_padre,
                                                cod_moneda, monto, mto_comision, cod_extorno, nro_documento,
                                                nro_transaccion, dat_adicional, liberado, fec_acreditacion, tip_operacion)
                                         values(r_gmovi.fecha, v_fec_cobro, r_gmovi.cod_usuario, R_GMOVI.hora, nvl(r_gmovi.nro_secuencia, 1), v_hor_referencia,
                                                r_gmovi.cod_modulo, r_gmovi.cod_modalidad,nvl(R_GMOVI.Nro_Cuenta,v_nro_cta_fic_cre),
                                                v_nro_cta_deb_batch, r_gmovi.cod_tra_padre,
                                                r_gmovi.cod_moneda, r_gmovi.monto, v_imp_comision, vp_extorno, r_gmovi.nro_documento,
                                                r_gmovi.nro_documento3, vp_nom_tar, v_liberado, v_fec_acreditacion, v_tip_operacion);
                  exception
                    when others then
                      v_det_error := substr(sqlerrm, 1,4000);
                      insert into ge_mov_dat_adicionales_err (fecha, fec_valor, cod_usuario, hora, nro_secuencia, hor_referencia,
                                                      cod_modulo, cod_modalidad, nro_cuenta, nro_cta_deb_batch, cod_tra_padre,
                                                      cod_moneda, monto, mto_comision, cod_extorno, nro_documento,
                                                      nro_transaccion,dat_adicional, liberado, fec_acreditacion,tip_operacion, det_error)
                                               values(r_gmovi.fecha, v_fec_cobro, r_gmovi.cod_usuario, R_GMOVI.hora, nvl(v_nro_secuencia, 1), v_hor_referencia,
                                                      r_gmovi.cod_modulo, r_gmovi.cod_modalidad, nvl(R_GMOVI.Nro_Cuenta,v_nro_cta_fic_cre),
                                                      v_nro_cta_deb_batch, r_gmovi.cod_tra_padre,
                                                      r_gmovi.cod_moneda, r_gmovi.monto, v_imp_comision, vp_extorno, r_gmovi.nro_documento,
                                                      r_gmovi.nro_documento3,  vp_nom_tar,v_liberado, v_fec_acreditacion,v_tip_operacion,v_det_error);
                  end;
                end;
              end if;
          end if;
       end if;
   end;

   /*
   || DYDMR-3914 - Dif Saldo, No se Envía Extracto Vía Mail
   */
   procedure lp_obt_nro_secuencia
   is
      v_ins_movimiento varchar2(1) := 'N';
      v_can_intentos   number := 0;
   begin
      BEGIN
        select nro_secuencia
               into v_nro_secuencia
          from ge_movimientos
          where nro_documento3 = v_nro_documento3
            and nro_documento  = v_nro_documento
            and nvl(monto,0)   = abs(nvl(v_imp_debito,0))
            and cod_moneda     = nvl(v_mon_cta_deb, v_cod_moneda)
            and cod_usuario    = v_cod_usuario
            and cod_tra_padre = r_gmovi.cod_tra_padre
            and cod_transaccion = r_gmovi.cod_transaccion
            and nro_cuenta = r_gmovi.nro_cuenta
            and rownum = 1;
            r_gmovi.nro_secuencia := v_nro_secuencia;
       EXCEPTION
        when no_data_found then
          begin
             select nro_secuencia
               into v_nro_secuencia
               from ge_movimientos_noc
              where nro_documento3 = v_nro_documento3
                and nro_documento  = v_nro_documento
                and nvl(monto,0)   = abs(nvl(v_imp_debito,0))
                and cod_moneda     = nvl(v_mon_cta_deb, v_cod_moneda)
                and cod_usuario    = v_cod_usuario
                and cod_tra_padre = r_gmovi.cod_tra_padre
                and cod_transaccion = r_gmovi.cod_transaccion
                and nro_cuenta = r_gmovi.nro_cuenta
                and rownum = 1;
                r_gmovi.nro_secuencia := v_nro_secuencia;
          exception
            when no_data_found then
               null;
            when others then
               null;
          end;
        when others then
          null;
      END;
   end;

  procedure lp_con_mon_a_moneda(p_cod_mon_debito  in ba_monedas.cod_moneda%type,
                                p_cod_mon_credito in ba_monedas.cod_moneda%type,
                                p_fecha           in date,
                                p_mto_mon_debito  in out number,
                                p_mto_mon_credito in out number,
                                p_cot_mon_debito  out number,
                                p_cot_mon_credito out number) is
    v_lugar         varchar2(100);
    v_cod_mon_local varchar2(3) := pag_gen.fu_obt_mon_local;


  begin
    v_lugar := 'obtener moneda base';
    if p_cod_mon_debito = p_cod_mon_credito then
      if p_mto_mon_debito is null then
        p_mto_mon_debito  := p_mto_mon_credito;
      else
        p_mto_mon_credito := p_mto_mon_debito;
      end if;
      p_cot_mon_credito := null;
      p_cot_mon_debito  := null;
    else
      if p_cod_mon_debito = v_cod_mon_local then -- VENTA
/*        v_cod_modulo := 7;
        v_cod_modalidad := 72;
        v_cod_tip_ope_cambio := 30;
        v_cod_bco_central := 'B27';*/
        p_cot_mon_debito  := null;
        p_cot_mon_credito := lf_obt_cotizacion(p_cod_mon_credito, 'V');
        if p_mto_mon_debito is null then
          p_mto_mon_debito  := round(p_mto_mon_credito * p_cot_mon_credito, 0);
        else
          p_mto_mon_credito := round(p_mto_mon_debito / p_cot_mon_credito, 2);
          p_cot_mon_credito := round(p_mto_mon_debito / p_mto_mon_credito, 4);  -- relacula la cotizacion
        end if;
      elsif p_cod_mon_credito = v_cod_mon_local then -- COMPRA
/*        v_cod_modulo := 7;
        v_cod_modalidad := 71;
        v_cod_tip_ope_cambio := 16;
        v_cod_bco_central := 'A19';*/
        p_cot_mon_debito  :=  lf_obt_cotizacion(p_cod_mon_debito, 'C'); --DYDMR-4929 Se pasa como parametro la moneda de debito para las compras
        p_cot_mon_credito := null;
        if p_mto_mon_debito is null then
          p_mto_mon_debito  := round(p_mto_mon_credito / p_cot_mon_debito, 2);
          p_cot_mon_debito  := round(p_mto_mon_credito / p_mto_mon_debito, 4); -- relacula la cotizacion
        else
          p_mto_mon_credito := round(p_mto_mon_debito * p_cot_mon_debito, 0);
        end if;
      else -- ARBITRAJE
        v_cod_modulo := 7;
        v_cod_modalidad := 73;
        p_cot_mon_debito  := lf_obt_cotizacion(p_cod_mon_debito, 'C');
        if p_mto_mon_debito is null then
          p_mto_mon_debito  := round(round(p_mto_mon_credito *  lf_obt_cotizacion(p_cod_mon_credito, 'V'), 0)/ p_cot_mon_debito, 2);
        else
          p_mto_mon_credito := round(round(p_mto_mon_debito * p_cot_mon_debito, 0) /  lf_obt_cotizacion(p_cod_mon_credito, 'V'), 2);
        end if;
        p_cot_mon_credito := round(round(p_mto_mon_debito * p_cot_mon_debito, 0) / p_mto_mon_credito, 4);
      end if;
    end if;
  exception
    when others then
      raise_application_error(-20000, v_lugar || ' - ' || sqlerrm);
  end;

   procedure lp_pro_operacion_72 is
     v_inserta varchar2(1) := 'S';
     v_cod_sub_modalidad ge_cuentas.cod_sub_modalidad%type;
     v_fec_imp_acr_bat date := to_date(fug_obt_pardinamico('ICB_FEC_IMP_ACR_BAT'), 'dd/mm/Yyyy');
     v_fec_cob_inf ge_mov_inf_cobranzas.fec_referencia%type;
   begin
     if to_number(vp_extorno) = 99 then
        update ge_mov_inf_cobranzas
           set reversado = 'S',
               hor_rev_referencia = v_hor_referencia
         where nro_documento = v_nro_documento3
           and liberado = 'N';
        if sql%found then
           v_inserta := 'N';
        else
          update ge_mov_inf_cobranzas
             set reversado = 'S',
                 hor_rev_referencia = v_hor_referencia
           where nro_documento = v_nro_documento3
             and liberado = 'S'
             and reversado = 'N';
           if sql%found then
              v_inserta := 'N';
              v_ind_gen_mov_rev72 := 'S';
           else
              v_inserta := 'N';
              if nvl(v_ind_acr_batch, 'N') <> 'S' then
                 vp_cod_respuesta := vr_no_aprobado;
              end if;
           end if;
        end if;
    end if;
    if v_inserta = 'S' then
       -- CANOSTDD-2 -- 01/2017 -- Pago Extracto/Servicios --
       v_cod_tra_padre := lf_obt_tra_padre(C_DOM_MED_PAG,vp_med_pago);
       v_cod_tra_padre := nvl(v_cod_tra_padre,227);
       begin
         v_fec_cob_inf := to_date(vp_fecha, 'ddmmyyyy');
       exception
         when others then
            v_fec_cob_inf := trunc(sysdate);
       end;

       if nvl(v_ind_acr_batch, 'N') <> 'S' then
         insert into ge_mov_inf_cobranzas
           (fecha, hora, nro_documento, cod_moneda, monto, mto_comision, nro_cta_debito,
            nro_cta_credito, referencia, reversado, liberado, observacion,
            nro_tarjeta, cod_tra_padre, hor_referencia, fec_referencia)
         values
           (v_fec_proceso, v_hora,v_nro_documento3,v_cod_moneda, v_imp_credito, v_imp_comision, nvl(vp_cta_debito,v_nro_cta_fic_deb),
            nvl(vp_cta_credito,v_nro_cta_fic_cre),vp_negocio, 'N','N',null,
            vp_nro_tarjeta, v_cod_tra_padre, v_hor_referencia, v_fec_cob_inf );
       else
         v_fec_imp_acr_bat := pag_cal.FU_OBT_FEC_SIG_HAB( v_fec_imp_acr_bat, 31, 1);
         -- para que genere los movimientos 48hs. posterior en cierre.
         if (v_fec_proceso < v_fec_imp_acr_bat) or (v_fec_valor = v_fec_imp_acr_bat and v_hor_referencia < '13:00:00') then
           insert into ge_mov_inf_cobranzas
             (fecha, hora, nro_documento, cod_moneda, monto, mto_comision, nro_cta_debito,
              nro_cta_credito, referencia, reversado, liberado, observacion,
              nro_tarjeta, cod_tra_padre, hor_referencia, fec_referencia)
           values
             (v_fec_proceso, v_hora,v_nro_documento3,v_cod_moneda, v_imp_credito, v_imp_comision, nvl(vp_cta_debito,v_nro_cta_fic_deb),
              nvl(vp_cta_credito,v_nro_cta_fic_cre),vp_negocio, 'N','N',null,
              vp_nro_tarjeta, v_cod_tra_padre, v_hor_referencia, v_fec_cob_inf );
         end if;
       end if;
    end if;
    if (v_inserta = 'S') or (v_inserta = 'N' and nvl(v_ind_gen_mov_rev72, 'N') = 'N') then
       if nvl(v_ind_acr_batch, 'N') = 'S' then
          declare
             v_det_error ge_mov_dat_adicionales_err.det_error%type;
             v_fec_cobro ge_mov_dat_adicionales.fec_valor%type;
             begin
               if vp_extorno = 99 then
                  v_fec_cobro :=  trunc(sysdate);
                  v_hor_referencia := to_char(sysdate,'HH24:MI:SS');
               else
                  begin
                     v_fec_cobro := to_date(vp_fecha, 'ddmmyyyy');
                  exception
                     when others then
                       v_fec_cobro := trunc(sysdate);
                  end;
                end if;
                begin
                  insert into  ge_mov_dat_adicionales (fecha, fec_valor, cod_usuario, hora, nro_secuencia, hor_referencia,
                                              cod_modulo, cod_modalidad, nro_cuenta, nro_cta_deb_batch, cod_tra_padre,
                                              cod_moneda, monto, mto_comision, cod_extorno, nro_documento, dat_adicional,
                                              nro_transaccion, liberado, tip_operacion)
                                       values(v_fec_proceso, v_fec_cobro, v_cod_usuario, v_hora, nvl(v_nro_secuencia, 1), v_hor_referencia,
                                              v_mod_cta_cre, v_mad_cta_cre, nvl(vp_cta_credito,v_nro_cta_fic_cre),
                                              nvl(vp_cta_debito,v_nro_cta_fic_deb), nvl(v_cod_tra_padre,227),
                                              v_cod_moneda, v_imp_credito - nvl(v_imp_comision, 0), nvl(v_imp_comision, 0), vp_extorno, v_nro_documento, vp_nom_tar,
                                              vp_transaccion, 'N', 'BCH');
                 exception
                   when others then
                     v_det_error := substr(sqlerrm, 1,4000);
                     insert into ge_mov_dat_adicionales_err (fecha, fec_valor, cod_usuario, hora, nro_secuencia, hor_referencia,
                                                     cod_modulo, cod_modalidad, nro_cuenta, nro_cta_deb_batch, cod_tra_padre,
                                                     cod_moneda, monto,mto_comision, cod_extorno, nro_documento, dat_adicional,
                                                     nro_transaccion, liberado,tip_operacion)
                                              values(v_fec_proceso, v_fec_cobro, v_cod_usuario, v_hora, nvl(v_nro_secuencia, 1), v_hor_referencia,
                                                     v_mod_cta_cre, v_mad_cta_cre, nvl(vp_cta_credito,v_nro_cta_fic_cre),
                                                     nvl(vp_cta_debito, v_nro_cta_fic_deb), nvl(v_cod_tra_padre,227),
                                                     v_cod_moneda,  v_imp_credito - nvl(v_imp_comision, 0), nvl(v_imp_comision, 0), vp_extorno, v_nro_documento, vp_nom_tar,
                                                     vp_transaccion, 'N', 'BCH');
                    end;
                end;
              end if;
          end if;
   end;
   ---
   function lf_hoy_cobro(p_nro_cuenta varchar2, p_cod_ente in number) return varchar2 is
   v_sino varchar2(1) := 'N';
   begin
     return 'N';
     /* se anulo a pedido del BBVA, Porque no se controla si el usuario cobro o no en el dia
     select 'S'
       into v_sino
       from ge_pag_sueldos
      where nro_cuenta = p_nro_cuenta
        and fec_proceso = v_fec_proceso
        and tipo = 'C'
        and cod_ente = p_cod_ente
        and cod_proceso = 0
        and rownum = 1;
      return 'S';
     */
   exception
      when no_data_found then
         return 'N';
      when others then
         return 'N';
   end;

   ---
   function lf_es_sponsor (p_dato varchar2,
                           p_tip_verif varchar2)
   return varchar2 is
     v_es_sponsor varchar2(1) := 'N';
   begin
     -- Verifico por el Nro de Cta
     if p_tip_verif = 'CTA' then
       Select 'S'
         into v_es_sponsor
         from ge_entes e, ge_par_entes p
        where e.tipo = 'SP' -- Sponsor
          and p.cod_ente = e.cod_ente
          and p.parametro = 'NRO_CUENTA'
          and instr(',' || p.val_parametro || ',', ',' || p_dato || ',') > 0;
     end if;
     -- Verifico por el Cod de Entidad Infonet
     if p_tip_verif = 'COD' then
       Select 'S'
         into v_es_sponsor
         from ge_entes e, ge_par_entes p
        where e.tipo = 'SP' -- Sponsor
          and p.cod_ente = e.cod_ente
          and p.parametro = 'COD_ENT_SPONSOR'
          and p.val_parametro = p_dato;
     end if;
     --
     return v_es_sponsor;
   Exception
     When NO_DATA_FOUND then
          return v_es_sponsor;
   end lf_es_sponsor;
   ---
   function lf_exi_banco (p_cod_banco number) return varchar2 is
     v_exi_banco varchar2(1) := 'N';
   begin
     --WA: 06/08/2014 Buscamos inicialmente si es financiera
     begin
       select 'S'
        into v_exi_banco
         from ge_par_entes p, ge_entes e
        where p.parametro = 'COD_ENT_FINANCIERA'
          and p.cod_ente = e.cod_ente
          and p.val_parametro=p_cod_banco
          and e.tipo = 'FI';
     exception
        when no_data_found then
          v_exi_banco:='N';
        when others then
          v_exi_banco:='N';
     end;

     if nvl(v_exi_banco,'N')= 'N' then
       begin
        Select 'S'
           into v_exi_banco
           from ge_bancos
          where cod_banco = p_cod_banco
               and estado = 'A'
               and ubicacion = 'L';
        Exception
          When NO_DATA_FOUND then
             return v_exi_banco;
        end;

     end if;
     --
     return v_exi_banco;

   end lf_exi_banco;
   --
   ---
   function lf_exi_financiera (p_cod_ente number) return varchar2 is
     v_exi_financiera varchar2(1) := 'N';
   begin
     --WA: 06/08/2014 Buscamos si es financiera
     begin
       select 'S'
        into v_exi_financiera
         from ge_par_entes p, ge_entes e
        where p.parametro = 'COD_ENT_FINANCIERA'
          and p.cod_ente = e.cod_ente
          and p.val_parametro=p_cod_ente
          and e.tipo = 'FI';
     exception
        when no_data_found then
          v_exi_financiera:='N';
        when others then
          v_exi_financiera:='N';
     end;
     return v_exi_financiera;

   end lf_exi_financiera;

   ---
   procedure lp_ver_horario is
   begin
      v_horario := 'D'; -- Día
      v_es_nocturno := 'N'; -- Para grabar en las tablas nocturnas
      v_es_cta_noc  := 'N';
      v_fec_proceso := pag_cal.FU_OBT_FEC_ACTUAL(3);
      if v_est_modulo = 2 Then -- El modulo está abierto
         -- Verifica la hora --
         if (vp_hora > v_hor_limite and v_fec_proceso = to_date(vp_fecha, 'ddmmyyyy')) or
             v_fec_proceso < to_date(vp_fecha, 'ddmmyyyy') Then
            v_horario := 'T'; -- Tarde
            v_fec_proceso := pag_cal.FU_OBT_FEC_HABIL(v_fec_proceso+1, 1, v_ofi_origen);
            v_es_nocturno := 'S'; -- Para grabar en las tablas nocturnas
         end if;
      else
         v_horario := 'N'; -- Noche
         v_fec_proceso := pag_cal.FU_OBT_FEC_HABIL(v_fec_proceso+1, 1, v_ofi_origen);
         v_es_nocturno := 'S'; -- Para grabar en las tablas nocturnas
         v_es_cta_noc  := 'S'; -- Solo para que llavee la cuenta nocturna
      end if;
      v_fec_valor   := trunc(sysdate); -- para que sea fecha la fecha real de la transaccion --v_fec_proceso;
   end lp_ver_horario;

   procedure lp_upd_cta_debito(p_mod_cta_deb in number, p_mad_cta_deb in number,
                               p_cta_debito in varchar2, p_imp_debito in number) is
   begin
     If v_ind_rub_debito = 'N' then
        if v_horario = 'D' Then
           -- Horario normal --
           If p_mad_cta_deb = 31 then
             update ah_cta_vistas
                set sal_total = nvl(sal_total,0) - p_imp_debito,
                    fec_ult_movimiento = v_fec_proceso,
                    hor_ult_movimiento = v_hora,
                    estado = decode(estado, 'I', 'N', estado)
              where nro_cuenta = p_cta_debito;
           elsif p_mad_cta_deb = 41 then
             update cc_cta_corrientes
                set sal_total = nvl(sal_total,0) - p_imp_debito,
                    fec_ult_movimiento = v_fec_proceso,
                    hor_ult_movimiento = v_hora,
                    estado = decode(estado, 'I', 'N', estado)
              where nro_cuenta = p_cta_debito;
           elsif p_mod_cta_deb = 4 then
             --Mejoras ATM DE-2209--Punto 5: No Actualizar Saldo de la Cuenta de Debito cuando sea Cuenta Bancaria.
             null;
             /*update cc_cta_bancarias
                set sal_total = nvl(sal_total,0) - p_imp_debito,
                    fec_ult_movimiento = v_fec_proceso,
                    hor_ult_movimiento = v_hora,
                    estado = decode(estado, 'I', 'N', estado)
              where nro_cuenta = p_cta_debito;*/
           End if;
        elsif v_horario = 'T' Then
           -- A la Tarde --
           If p_mad_cta_deb = 31 then
             update ah_cta_vistas
                set mto_deb_pendientes = nvl(mto_deb_pendientes, 0) + p_imp_debito
              where nro_cuenta = p_cta_debito;
           elsif p_mad_cta_deb = 41 then
             update cc_cta_corrientes
                set mto_deb_pendientes = nvl(mto_deb_pendientes, 0) + p_imp_debito
              where nro_cuenta = p_cta_debito;
           elsif p_mod_cta_deb = 4 then
             --Mejoras ATM DE-2209--Punto 5: No Actualizar Saldo de la Cuenta de Debito cuando sea Cuenta Bancaria.
             null;
             /*update cc_cta_bancarias
                set mto_deb_pendientes = nvl(mto_deb_pendientes, 0) + p_imp_debito
              where nro_cuenta = p_cta_debito;*/
           End if;
        else
           -- A la Noche o despues del cierre --
           If p_mad_cta_deb = 31 then
             update ah_cta_vistas_noc
                set mto_deb_pendientes = nvl(mto_deb_pendientes, 0) + p_imp_debito
              where nro_cuenta = p_cta_debito;
           elsif p_mad_cta_deb = 41 then
             update cc_cta_corrientes_noc
                set mto_deb_pendientes = nvl(mto_deb_pendientes, 0) + p_imp_debito
              where nro_cuenta = p_cta_debito;
           elsif p_mod_cta_deb = 4 then
             --Mejoras ATM DE-2209--Punto 5: No Actualizar Saldo de la Cuenta de Debito cuando sea Cuenta Bancaria.
             null;
             /*update cc_cta_bancarias_noc
                set mto_deb_pendientes = nvl(mto_deb_pendientes, 0) + p_imp_debito
              where nro_cuenta = p_cta_debito;*/
           End if;
        end if;
     end if;
   end lp_upd_cta_debito;
--
   procedure lp_upd_cta_credito is
   begin
     If v_ind_rub_credito = 'N' then
      if v_horario = 'D' Then
         -- Horario normal --
         If v_mad_cta_cre = 31 then
           update ah_cta_vistas
              set sal_total = nvl(sal_total, 0) + v_imp_credito,
                  estado = decode(estado, 'I', 'N', estado)
            where nro_cuenta = vp_cta_credito;
         elsif v_mad_cta_cre = 41 then
           update cc_cta_corrientes
              set sal_total = nvl(sal_total, 0) + v_imp_credito,
                  estado = decode(estado, 'I', 'N', estado)
            where nro_cuenta = vp_cta_credito;
         elsif v_mod_cta_cre = 4 then
           --Mejoras ATM DE-2209--Punto 6: No Actualizar Saldo de la Cuenta de Credito cuando sea Cuenta Bancaria.
           null;
           /*update cc_cta_bancarias
              set sal_total = nvl(sal_total, 0) + v_imp_credito,
                  estado = decode(estado, 'I', 'N', estado)
            where nro_cuenta = vp_cta_credito;*/
         End if;
      elsif v_horario = 'T' Then
         -- A la Tarde --
         If v_mad_cta_cre = 31 then
           update ah_cta_vistas
              set mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + v_imp_credito
            where nro_cuenta = vp_cta_credito;
         elsif v_mad_cta_cre = 41 then
           update cc_cta_corrientes
              set mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + v_imp_credito
            where nro_cuenta = vp_cta_credito;
         elsif v_mod_cta_cre = 4 then
           --Mejoras ATM DE-2209--Punto 6: No Actualizar Saldo de la Cuenta de Credito cuando sea Cuenta Bancaria.
           /*update cc_cta_bancarias
              set mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + v_imp_credito
            where nro_cuenta = vp_cta_credito;*/
           null;
         End if;
      else
         -- A la Noche o despues del Cierre --
         If v_mad_cta_cre = 31 then
           update ah_cta_vistas_noc
              set mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + v_imp_credito
            where nro_cuenta = vp_cta_credito;
         elsif v_mad_cta_cre = 41 then
           update cc_cta_corrientes_noc
              set mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + v_imp_credito
            where nro_cuenta = vp_cta_credito;
         elsif v_mod_cta_cre = 4 then
           --Mejoras ATM DE-2209--Punto 6: No Actualizar Saldo de la Cuenta de Credito cuando sea Cuenta Bancaria.
           null;
           /*update cc_cta_bancarias_noc
              set mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + v_imp_credito
            where nro_cuenta = vp_cta_credito;*/
         End if;
      end if;
     end if;
   end lp_upd_cta_credito;
  -- PCCDEEVO-80 Seguimiento de Operaciones Rechazadas
  procedure lp_act_rechazo(v_cod_persona in number, v_nro_cuenta in varchar2,
   v_variable in varchar, v_operacion in varchar2 ) is
   v_tipo varchar2(1);
   v_fecha date;
   v_fec_hora date;
   v_error varchar2(3000);
   begin
    v_fec_hora:=null;
    v_fec_hora:=sysdate;
    if v_variable like '%#F%' then
      v_tipo:='P';
    elsif  v_variable like '%#D%' then
       v_tipo:='T';
    end if;

    if v_operacion = 'I' then
       begin
         insert into ge_rch_pre_aprobados
           (cod_persona,nro_cuenta,tipo,fecha)
         values
           (v_cod_persona,v_nro_cuenta, v_tipo, v_fec_hora);
       exception
         when others then
                v_error:=null;
                v_error := sqlerrm;
                prg_env_mail(fug_obt_pardinamico('CAM_MAR_DIR_MAIL'),
                             fug_obt_pardinamico('CAM_MAR_DIR_EP'),
                             'Insercion de Rechazos de Pre-aprobados en ATM',
                             'Error en rechazo de seguro para la cuenta: '||v_nro_cuenta||chr(13)||
                             'Cliente: '||v_cod_persona||'.'||chr(13)||
                             'Tipo: '||v_tipo||'.'||chr(13)||
                             'Fecha Hora Insercion: '||v_fec_hora||'.'||chr(13)||
                             'Error: '||v_error);
       end;
    elsif  v_operacion = 'E' then
      --Buscamos si solo tiene Uno
         v_fecha:=null;
         begin
            select max(a.fecha)
             into v_fecha
            from ge_rch_pre_aprobados a
              where a.cod_persona= nvl(v_cod_persona,a.nro_cuenta)
                  and a.tipo= v_tipo
                  and a.nro_cuenta=nvl(v_nro_cuenta,a.nro_cuenta);
          exception
            when no_data_found then
               v_fecha:=null;
            when others then
               v_fecha:=null;
          end;
       if v_fecha is not null then
            --Borramos de la tabla
            Begin
             delete from ge_rch_pre_aprobados a
                   where  a.cod_persona= v_cod_persona
                      and a.tipo= v_tipo
                         and a.nro_cuenta=v_nro_cuenta
                         and a.fecha=v_fecha;
            exception
              when others then
                v_error:=null;
                v_error := sqlerrm;
                prg_env_mail(fug_obt_pardinamico('CAM_MAR_DIR_MAIL'),
                             fug_obt_pardinamico('CAM_MAR_DIR_EP'),
                             'Borrado de Rechazos de Pre-aprobados en ATM',
                             'Error en rechazo de seguro para la cuenta: '||v_nro_cuenta||chr(13)||
                             'Cliente: '||v_cod_persona||'.'||chr(13)||
                             'Tipo: '||v_tipo||'.'||chr(13)||
                             'Fecha Hora Insercion: '||v_fecha||'.'||chr(13)||
                             'Fecha Hora Borrado: '||v_fec_hora||'.'||chr(13)||
                             'Error: '||v_error);

            end;
       end if;
    end if;
   end lp_act_rechazo;
--
   -- CANOSTDD-2 -- 06/2017 --
   function lf_nro_tarjeta(p_nro_tarjeta varchar2) return varchar2 is
     v_ret varchar2(25);
   begin
      v_ret := lpad('*',(length(p_nro_tarjeta)-6),'*')||substr(p_nro_tarjeta,-4);
      return v_ret;
   exception
     when others then
       return null;
   end;
--
   procedure lp_car_parametros is
     v_indice number(3) := 1;
     v_can_int_bloqueo number(3);
     v_ope varchar2(15); -- Billetera Zimple / Operaciones sin tarjetas -- CN: 08/2016 --
     v_nro_tarjeta varchar2(25);
     v_nro number;
   begin
     vp_cta_debito := to_char(to_number(substr(p_pedido, v_indice, 10)));
     dbms_output.put_line('vp_cta_debito '||vp_cta_debito);
     v_indice := v_indice + 10;
     vp_bco_debito := substr(p_pedido, v_indice, 3);
     dbms_output.put_line('vp_bco_debito '||vp_bco_debito);
     v_indice := v_indice + 3;
     vp_cta_credito := to_char(to_number(substr(p_pedido, v_indice, 10)));
     dbms_output.put_line('vp_cta_credito '||vp_cta_credito);     
     v_indice := v_indice + 10;
     vp_bco_credito := substr(p_pedido, v_indice, 3);
     dbms_output.put_line('vp_bco_credito '||vp_bco_credito);     
     v_indice := v_indice + 3;
     vp_operacion := substr(p_pedido, v_indice, 2);
     dbms_output.put_line('vp_operacion '||vp_operacion);     
     v_indice := v_indice + 2;
     vp_extorno := substr(p_pedido, v_indice, 2);
     dbms_output.put_line('vp_extorno '||vp_extorno);     
     v_indice := v_indice + 2;
     vp_tra_entidad := substr(p_pedido, v_indice, 15);
     dbms_output.put_line('vp_tra_entidad '||vp_tra_entidad);          
     v_indice := v_indice + 15;
     vp_transaccion := substr(p_pedido, v_indice, 15);
     dbms_output.put_line('vp_transaccion '||vp_transaccion);          
     v_indice := v_indice + 15;
     vp_importe := substr(p_pedido, v_indice, 15);
     dbms_output.put_line('vp_importe '||vp_importe);          
     v_indice := v_indice + 15;
     vp_importe2 := substr(p_pedido, v_indice, 15);
     dbms_output.put_line('vp_importe2 '||vp_importe2);               
     v_indice := v_indice + 15;
     vp_importe3 := substr(p_pedido, v_indice, 15);
          dbms_output.put_line('vp_importe3 '||vp_importe3);          
     v_indice := v_indice + 15;
     vp_can_cheques := substr(p_pedido, v_indice, 4);
     dbms_output.put_line('vp_can_cheques '||vp_can_cheques);          
     v_indice := v_indice + 4;
     vp_moneda := substr(p_pedido, v_indice, 2);
     dbms_output.put_line('vp_moneda '||vp_moneda);          
     v_indice := v_indice + 2;
     vp_nro_atm := substr(p_pedido, v_indice, 3);
     dbms_output.put_line('vp_nro_atm '||vp_nro_atm);          
     v_indice := v_indice + 3;
     vp_nro_pos := substr(p_pedido, v_indice, 2);
     dbms_output.put_line('vp_nro_pos '||vp_nro_pos);          
     v_indice := v_indice + 2;
     vp_tra_pos := substr(p_pedido, v_indice, 4);
     dbms_output.put_line('vp_tra_pos '||vp_tra_pos);          
     v_indice := v_indice + 4;
     vp_tip_hora := substr(p_pedido, v_indice, 3);
     dbms_output.put_line('vp_tip_hora '||vp_tip_hora);               
     v_indice := v_indice + 3;
     vp_negocio := substr(p_pedido, v_indice, 40);
     dbms_output.put_line('vp_negocio '||vp_negocio);               
     v_indice := v_indice + 40;
     vp_tra_extornado := substr(p_pedido, v_indice, 15);
     dbms_output.put_line('vp_tra_extornado '||vp_tra_extornado);               
     v_indice := v_indice + 15;
     vp_bco_atm := substr(p_pedido, v_indice, 3);
     dbms_output.put_line('vp_bco_atm '||vp_bco_atm);                    
     vp_bco_aux := null;
     --SDGNBATMPR-1-ATM Propios--
     --Verifica si es banco de la fusion--
     if vp_bco_atm = trim(to_char(vp_cod_ban_fusion,'000')) then
        vp_bco_aux := trim(to_char(vp_cod_ban_fusion,'000'));
        --vp_bco_atm := trim(to_char(vp_cod_entidad,'000'));
     end if;
     -- Verifica si el ATM es de una entidad que sponsoreamos, debe ser como '007'
     if lf_es_sponsor(vp_bco_atm,'COD') = 'S' then
        vp_bco_atm := to_number(fug_obt_pardinamico('COD_ENT_INFONET',null,null,null,null));--trim(to_char(vp_cod_entidad,'000'));
     end if;
     v_indice := v_indice + 3;
     vp_fecha := substr(p_pedido, v_indice, 8);
     dbms_output.put_line('vp_fecha '||vp_fecha);                    
     v_indice := v_indice + 8;
     vp_hora := substr(p_pedido, v_indice, 6);
     dbms_output.put_line('vp_hora '||vp_hora);                    
     v_indice := v_indice + 6;
     vp_nom_tar := substr(p_pedido, v_indice, 35);
     dbms_output.put_line('vp_nom_tar '||vp_nom_tar);                    
     -- Billetera Zimple / Operaciones sin tarjetas -- CN: 08/2016 --
     if to_number(vp_operacion) in( 0, 2, 5, 6, 41, 72, 85 ) then
       vp_tip_ope := substr(vp_nom_tar,1,13); -- Servicio (3 bytes)||Prestación (4 bytes)||Marca (3 bytes)||Producto (3 bytes)
       v_tip_servicio := substr(nvl(vp_tip_ope, 'XXX'), 1,3);
       vp_med_pago := substr(vp_nom_tar,14,2);
       -- Billetera Zimple / Operaciones sin tarjetas -- 01/2017 -- Pago Extracto/Servicios --
       -- Si es 04 es Debito en Cuenta -- 02 = Tarjeta de Débito
       /*if nvl(vp_med_pago,'02') != '04' then -- Operacion con Tarjeta, por defecto
         vp_tip_ope := null; -- Para utilizar cta bancard --
       end if;*/
       if vp_tip_ope is not null then
         if to_number(vp_operacion) not in( 72, 85 ) then -- Pago Extracto, Pre-Aprobados --
             v_ope := vp_tip_ope||vp_operacion;
             v_cod_tra_padre := lf_obt_tra_padre(C_DOM_TIP_OPE,v_ope);
             if v_cod_tra_padre is null then
               vp_tip_ope := null;
             end if;
         end if;
       end if;
     end if;
     --
     If to_number(vp_operacion) in (72,0) and ( substr(vp_negocio,1,5) in ('90077','00607') or
        substr(vp_negocio,1,3) = '607' ) then
        -- infonet cobranzas de tarjetas del Banco
        if substr(vp_negocio,1,5) in ('90077','00607') then -- JIRA 1675
           vp_nro_tarjeta := substr(vp_negocio,6,16);
           if vp_nro_tarjeta is not null then -- CANOSTDD-2 -- 06/2017 --
             v_nro_tarjeta := lf_nro_tarjeta(vp_nro_tarjeta);
             vp_negocio := replace(vp_negocio,vp_nro_tarjeta,v_nro_tarjeta);
           end if;
        elsif substr(vp_negocio,1,3) = '607' then
           vp_nro_tarjeta := substr(vp_negocio,4,16);
           if vp_nro_tarjeta is not null then -- CANOSTDD-2 -- 06/2017 --
             v_nro_tarjeta := lf_nro_tarjeta(vp_nro_tarjeta);
             vp_negocio := replace(vp_negocio,vp_nro_tarjeta,v_nro_tarjeta);
           end if;
        end if;
     elsif to_number(vp_operacion) in (72) and to_number(vp_nro_atm) > 0 and to_number(vp_bco_credito) in (v_cod_entidad,vp_cod_ban_fusion) then
        -- infonet cobranzas de tarjetas del Banco
        vp_nro_tarjeta := substr(vp_negocio,22,16);
        if vp_nro_tarjeta is not null then -- CANOSTDD-2 -- 06/2017 --
           v_nro_tarjeta := lf_nro_tarjeta(vp_nro_tarjeta);
           vp_negocio := replace(vp_negocio,vp_nro_tarjeta,v_nro_tarjeta);
        end if;
     elsif to_number(vp_operacion) in (72) and to_number(vp_nro_atm) > 0 and to_number(vp_bco_credito) not in (v_cod_entidad,vp_cod_ban_fusion) then -- CANOSTDD-2 -- 06/2017 --
        -- infonet cobranzas de tarjetas de otro Banco
        vp_nro_tarjeta := substr(vp_negocio,22,16);
        begin
          select to_number(vp_nro_tarjeta) into v_nro from dual;
        exception
          when others then
            vp_nro_tarjeta := null;
        end;
        if vp_nro_tarjeta is not null then
           v_nro_tarjeta := lf_nro_tarjeta(vp_nro_tarjeta);
           vp_negocio := replace(vp_negocio,vp_nro_tarjeta,v_nro_tarjeta);
        end if;
     elsif to_number(vp_cta_credito) = 6000002 and to_number(vp_bco_credito) in (v_cod_entidad,vp_cod_ban_fusion) then -- 6000002 = cta ficticia para tarjeta prepaga
        -- pago de tarjeta prepaga
        vp_nro_tarjeta := substr(vp_nom_tar,6,16);
        if vp_nro_tarjeta is not null then -- CANOSTDD-2 -- 06/2017 --
           v_nro_tarjeta := lf_nro_tarjeta(vp_nro_tarjeta);
           vp_negocio := replace(vp_negocio,vp_nro_tarjeta,v_nro_tarjeta);
         end if;
     End if;
   End lp_car_parametros;

   procedure lp_dat_cta (p_nro_cuenta in out varchar2,
                         p_cod_modulo out number,
                         p_cod_modalidad out number,
                         p_cod_oficina   out number,
                         p_cod_moneda out varchar2,
                         p_ind_cta_transaccional out varchar2) is
   v_cod_ent_ahorro number(5);
   begin
     If p_nro_cuenta is null then
        -- Es una cuenta contable...
        p_cod_modulo    := v_mod_con_debito;
        p_cod_modalidad := v_mad_con_debito;
        p_cod_oficina   := v_ofi_origen;
        p_cod_moneda    := v_cod_moneda;
        v_acu_sobregiro := 'N';
        v_cta_combinada := 'N';
     Else
        v_cta_combinada := 'N';
        Select cod_modulo, cod_modalidad, cod_oficina
          into p_cod_modulo, p_cod_modalidad, p_cod_oficina
          from ge_cuentas
         where nro_cuenta = p_nro_cuenta;
        If p_cod_modalidad = 31 then
          select nvl(cta_combinada,'N'), cod_moneda, 'N', cod_ente
            into v_cta_combinada, p_cod_moneda, v_acu_sobregiro, v_cod_ent_ahorro
            from ah_cta_vistas
           where nro_cuenta = p_nro_cuenta;
           p_ind_cta_transaccional := 'N';
        elsif p_cod_modalidad = 41 then
          select cod_moneda, acu_sobregiro, cod_ente, nvl(cta_combinada,'N')
            into p_cod_moneda, v_acu_sobregiro, v_cod_ent_sueldo, v_cta_combinada
            from cc_cta_corrientes
           where nro_cuenta = p_nro_cuenta;
        --30/07/2014: BBVANOR-1259 - Operaciones con Financieras del País sin Banco Sponsor
           p_ind_cta_transaccional := fuc_ver_cta_transaccional(p_nro_cuenta);
        elsif p_cod_modalidad = 49 then
          select cod_moneda, 'N', cod_ente, 'N'
            into p_cod_moneda, v_acu_sobregiro, v_cod_ent_sueldo, v_cta_combinada
            from cc_cta_bancarias
           where nro_cuenta = p_nro_cuenta;
           p_ind_cta_transaccional := 'N';
        End if;
     End if;
   Exception
      When NO_DATA_FOUND Then
           vp_cod_respuesta := vr_cta_inexistente;
   end lp_dat_cta;

   function lf_imp_saldos
    (p_nro_cuenta in varchar2)
   return varchar2 is
    --40 de ancho
    v_resultado     varchar2(4000) := null;
    v_linea         varchar2(100);
    v_fecha         date := pag_cal.FU_OBT_FEC_ACTUAL(3);
    --
    v_deuda         ge_cuentas.sal_contable%type;
    v_lin_sobregiro ge_cuentas.sal_contable%type;
    v_sal_linea     ge_cuentas.sal_contable%type;
    v_tan           ge_tas_fechas.val_tasa%type;
    v_tae           ge_tas_fechas.val_tasa%type;
   begin
   if to_number(vp_operacion) in (2, 52, 93, 5, 55) Then -- Consulta de Saldo  o extraccion
      --recupera datos de la cuenta
      if p_nro_cuenta is not null then
        pag_cta.PR_OBT_CUENTA(p_nro_cuenta);
        IF PAG_CTA.FU_OBT_COD_ERROR() <> 0 THEN
          return null;
        END IF;
        --sólo vistas y ctas. ctes.
        if pag_cta.g_ctas.cod_modalidad not in (41) then
          return null;
        end if;

        --obtiene línea de sobregiro de la cuenta
        v_lin_sobregiro := PAG_CTA.FU_OBT_LIN_SOBREGIRO(p_nro_cuenta, v_fecha);

        --calcular deuda y línea, sólo si tiene ente
        if pag_cta.g_ctas.cod_ente is not null then
          if nvl(pag_cta.FU_SAL_DISPONIBLE,0) > 0 then
            v_deuda := 0;
            v_sal_linea := v_lin_sobregiro;
          else
            v_deuda := nvl(pag_cta.FU_SAL_DISPONIBLE,0) * -1;
            vi_sal_disponible := 0;
            v_sal_linea := v_lin_sobregiro - v_deuda;
          end if;
          if (v_mad_cta_deb = 41 and lf_hoy_cobro(vp_cta_debito, v_cod_ent_sueldo) = 'S') or v_sal_linea < 0 then
            v_sal_linea := 0;
          end if;
          --calcular tan y tae
/*          begin
            v_tan := fug_obt_val_tasa(substr(pag_cta.g_ctas.cod_modalidad,1,1), pag_cta.g_ctas.cod_modalidad, pag_cta.g_ctas.cod_oficina,
                        p_nro_cuenta, pag_cta.g_ctas.cod_moneda, vi_sal_contable, pag_cta.g_ctas.tas_personalizada,
                        fug_obt_parentes(pag_cta.g_ctas.cod_ente,'TAS_ANT_SUELDO'), NULL, v_fecha);

            v_tae := pas_bcp.FU_OBT_TAE(v_tan, 30);
          exception
            when others then
              v_tan := null;
              v_tae := null;
          end;*/

          --armar estructura
          v_linea := 'SALDO PRESTAMO DISPONIBLE';
          v_resultado := v_resultado || rpad(v_linea,40,' ');
          v_linea :=  fue_obt_des_moneda(PAG_CTA.G_ctas.cod_moneda)||': '|| lpad(to_char(v_sal_linea,'999,999,990.99'),22,' ');
          v_resultado := v_resultado || rpad(v_linea,40,' ');
          v_resultado := v_resultado || rpad('*',40,'*');
          -- agrego la cantidad de lineas
          --v_resultado := '03'||v_resultado;
        end if;
/*        --sólo si tiene ente imprimir la línea
        if pag_cta.g_ctas.cod_ente is not null then
          v_linea := 'Adel.Disp.   ' || lpad(to_char(v_sal_linea,'999,999,990.99'),22,' ');
          v_resultado := v_resultado || rpad(v_linea,40,' ');
          v_linea := 'Deuda Adel.  ' || lpad(to_char(v_deuda,'999,999,990.99'),22,' ');
          v_resultado := v_resultado || rpad(v_linea,40,' ');
          --si tiene tan y tae imprimir
          if v_tan is not null and v_tae is not null then
            v_linea := 'TAN: '|| lpad(to_char(v_tan,'999.99')||'%',10,' ')
                       || '     TAE:  ' || lpad(to_char(v_tae,'990.99')||'%',9,' ');
            v_resultado := v_resultado || rpad(v_linea,40,' ');
            --los 2 primeros dígitos indican la cantidad de líneas a imprimir
            v_resultado := '04' || v_resultado;
          else
            v_resultado := '03' || v_resultado;
          end if;
        else
          --los 2 primeros dígitos indican la cantidad de líneas a imprimir
          v_resultado := '01' || v_resultado;
        end if;*/
      else --cuenta null
        return null;
      end if;
   end if;

    return(v_resultado);

   end lf_imp_saldos;
--
  function lf_set_mensaje( p_mensaje in varchar2,
                           p_evento in varchar2
                          ) return varchar2 is
    v_respuesta  varchar2(400):= 'N';
    v_resp       varchar2(2000);
    v_indice     number(4);
    v_char       varchar2(2) := 'N ';
    --v_evento     varchar2(2) := '#F';
  begin
    v_respuesta := p_mensaje;

    if length(v_respuesta) > 318 then
    v_respuesta := substr(v_respuesta,1,318);
    end if;
    v_indice := 1;

    for i in 1..8--v_lineas
    loop
      if i = 8 then
        v_resp := v_resp||v_char||substr(rpad(v_respuesta,318,' '),v_indice,36);
      else
        v_resp := v_resp||v_char||substr(rpad(v_respuesta,318,' '),v_indice,38);
        v_indice := v_indice + 38;
        /*if i = 8 then
          v_resp := v_resp
        end if;*/
      end if;
    end loop;
    v_respuesta := '08'/*||to_char(v_lineas)*/||v_resp||p_evento;

    return(v_respuesta);
  end lf_set_mensaje;

  function lf_imp_texto( v_cta_debito varchar2,
                         v_nro_solicitud number
                        ) return varchar2 is
    v_texto               varchar2(480):= null;
    v_linea               varchar2(100):= null;
    v_cod_modulo          pr_solicitudes.cod_modulo%type;
    v_cod_modalidad       pr_solicitudes.cod_modalidad%type;
    v_cod_moneda          pr_solicitudes.cod_moneda%type;
    v_monto               pr_solicitudes.monto%type;
    v_fec_pri_vencimiento date;
    v_nro_cuenta          pr_cta_prestamos.nro_cuenta%type;
    v_val_tasa            pr_cta_prestamos.val_tasa%type;
    v_redondeo            number;
    v_plazo               number;
    v_cuota               number;
  begin

    select a.cod_modulo, a.cod_modalidad, a.cod_moneda,
           a.monto, fec_pri_vencimiento
      into v_cod_modulo, v_cod_modalidad, v_cod_moneda,
           v_monto, v_fec_pri_vencimiento
      from pr_solicitudes a
     where a.nro_cta_debito = v_cta_debito
       and a.nro_solicitud = v_nro_solicitud;

    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                      v_cod_modulo,
                                      v_cod_modalidad,
                                      v_cod_moneda);

    select nro_cuenta, val_tasa
      into v_nro_cuenta, v_val_tasa
    from pr_cta_prestamos a
    where a.nro_cta_debito = v_cta_debito
       and a.nro_solicitud = v_nro_solicitud;

    select count(*),
           /*round(*/sum(nvl(mto_capital, 0) + nvl(mto_interes, 0)) /*/ count(*),
                 v_redondeo)*/
      into v_plazo, v_cuota
      from pr_cuotas x
     where nro_cuenta = v_nro_cuenta
       and (nvl(mto_capital, 0) > 0 or nvl(mto_interes, 0) > 0)
       and nro_cuota = 1;--> 0;
    select count(*)
      into v_plazo
      from pr_cuotas x
     where nro_cuenta = v_nro_cuenta
       and (nvl(mto_capital, 0) > 0 or nvl(mto_interes, 0) > 0)
       and nro_cuota > 0;

    v_linea := '*INFORMACION ACERCA DEL PRESTAMO*';
    v_texto := v_texto || rpad(v_linea,40,' ');
    v_linea := 'Monto Cuota: '||trim(to_char(v_cuota,'99G999G999G990','NLS_NUMERIC_CHARACTERS = ''.,'''))||' más Seg. Vida '
               ||pag_pre.fu_obt_tas_seg_vida(v_cod_modalidad,v_cod_moneda)||'%';
    v_texto := v_texto || rpad(v_linea,40,' ');
    v_linea := 'mas 10% IVA sobre intereses.            ';
    v_texto := v_texto || rpad(v_linea,40,' ');
    v_linea := 'Cantidad Cuotas: '||v_plazo||'. Tasa: '||v_val_tasa||'%.';
    v_texto := v_texto || rpad(v_linea,40,' ');
    v_linea := 'Primer Vencimiento: '||trim(to_char(v_fec_pri_vencimiento,'dd-mm-yyyy'))||'.';
    v_texto := v_texto || rpad(v_linea,40,' ');
    --v_linea := 'Cargo IVA sobre Intereses del 10%.';
    --v_texto := v_texto || rpad(v_linea,40,' ');

    -- Wording --
    --v_texto := v_texto || rpad('*',40,'*');
    v_linea := 'Se debitara  el Gasto Administrativo    '; -- Max. 40 caracteres por línea
    v_texto := v_texto || rpad(v_linea,40,' ');
    v_linea := 'por desembolso '||fug_obt_pardinamico('COM_DES_PRESTAMO')||'% del importe solicitado'; -- Max. 40 caracteres por línea
    v_texto := v_texto || rpad(v_linea,40,' ');
    /*v_linea := 'Cargo IVA sobre Intereses del 10%.';
    v_texto := v_texto || rpad(v_linea,40,' ');*/
    v_linea := 'ACEPTO LAS CONDICIONES DEL PRÉSTAMO QUE'; -- Max. 40 caracteres por línea
    v_texto := v_texto || rpad(v_linea,40,' ');
    v_linea := 'PAGARÉ MÁS INTERESES Y COSTOS A SU';
    v_texto := v_texto || rpad(v_linea,40,' ');
    v_linea := 'VENCIMIENTO Y CON DÉBITO EN MI CUENTA.';
    v_texto := v_texto || rpad(v_linea,40,' ');

    v_texto := v_texto || rpad('*',40,'*');


    return v_texto;
  end lf_imp_texto;
--
  -- MDPMATNT-1 - Mensajería en ATM sobre comisiones por transacciones -- CN: 02/2016 --
   function lf_cal_cob_cargo(v_operacion number) return boolean is
     v_cod_tra_bancard number;
   begin
    if v_cal_cargo = 'N' then
      return false;
    else
      select distinct(to_number(a.cod_tra_bancard))
        into v_cod_tra_bancard
        from gv_gru_tra_cob_car_atm a,
             ( select val_minimo cod_tra_bancard,
                    nvl(val_maximo,'N') activado
               from ba_cod_referencias
              where dominio = 'COD_TRA_BANCARD' ) b
        where a.cod_tra_bancard = b.cod_tra_bancard
          and b.activado = 'S'
          and to_number(a.cod_tra_bancard) = v_operacion;
      return true;
    end if;
   exception
     when no_data_found then
       return false;
     when others then
       return false;
   end;
  --
   procedure lp_car_salida is
     v_doceli varchar2(480);
     v_scrdta varchar2(322);
     v_bncmsg varchar2(408); -- MDPMATNT-1 - Mensajería en ATM sobre comisiones por transacciones -- CN: 02/2016 --
   begin
       if vp_can_extractos = '000' Then
          v_doceli := lf_imp_saldos(vp_cta_debito);
          v_doceli := rpad(nvl(v_doceli,' '),480,' ');
          vp_respuesta :=              --Segun estructura de Bancard
                   vp_cod_respuesta||  --CODRTN(2)    || cod de retorno
                   vp_sal_disponible|| --SALDOS(15,2) || saldo disponible
                   vp_sig_disponible|| --SIGNO(1)     || signo saldo dispobible
                   vp_sal_contable||   --SACTU(15,2)  || saldo contable
                   vp_sig_contable||   --SIGNO(1)     || signo saldo contable
                   vp_transaccion||    --DOCUM(15)    || nro transaccion infonet
                   vp_tra_entidad||    --LOCAL(15)    || nro de transaccion con la entidad
                   vp_can_extractos;   --CANEXT(3)    || cantidad de paq del extracto
                   --v_doceli;         --DOCELI(480)  || lineas para impresion en el pie del ticket
                   --v_scrdta          --SCRDTA(322)  || Lineas para desplegar en la pantalla del ATM
                   --v_bncmsg          --BNCMSG(408)  || lineas para desplegar en la pantalla del ATM indicando el costo de la transaccion

                   --lf_imp_saldos(vp_cta_debito); --imprimir saldos

                   if vp_cod_respuesta != vr_otr_error THEN -- Si es 99 ya salio por otro error -- 13/02/2015
                     if to_number(vp_operacion) = 85 then
                       if substr(vp_negocio,37,4) = '#DS#' then
                          v_scrdta := fug_obt_pardinamico('TCR_MNJ_CON_ATM');
                          v_scrdta := rpad(nvl(v_scrdta,' '),322,' ');
                          v_bncmsg := rpad(nvl(v_bncmsg,' '),408,' ');
                          --vp_respuesta := vp_respuesta||v_scrdta;
                          vp_respuesta := vp_respuesta||v_doceli||v_scrdta||v_bncmsg;
                       elsif substr(vp_negocio,37,4) = '#FS#' then
                          if v_mensaje is null then
                            --enviar monto cuota evento #G
                            v_scrdta := fug_obt_tex_cuo_atm(v_cod_persona, v_importe);
                            v_scrdta := rpad(nvl(v_scrdta,' '),322,' ');
                            v_bncmsg := rpad(nvl(v_bncmsg,' '),408,' ');
                            --vp_respuesta := vp_respuesta||v_scrdta;
                            vp_respuesta := vp_respuesta||v_doceli||v_scrdta||v_bncmsg;
                          else
                            v_scrdta := lf_set_mensaje(v_mensaje,'#F');
                            v_scrdta := rpad(nvl(v_scrdta,' '),322,' ');
                            v_bncmsg := rpad(nvl(v_bncmsg,' '),408,' ');
                            --vp_respuesta := vp_respuesta||v_scrdta;
                            --vp_respuesta := vr_ver_error||substr(vp_respuesta,3,length(vp_respuesta))||v_scrdta;
                            vp_respuesta := vr_ver_error||substr(vp_respuesta,3,length(vp_respuesta))||v_doceli||v_scrdta||v_bncmsg;
                          end if;
                       elsif substr(vp_negocio,37,4) = '#GS#' then
                          --null;--enviar confirmacion prestamo?
                          v_doceli := lf_imp_texto( vp_cta_debito,
                                                    v_nro_solicitud );
                          v_doceli := rpad(nvl(v_doceli,' '),480,' ');
                          v_scrdta := lf_set_mensaje('Transacción exitosa.                  El importe ha sido acreditado a su    cuenta nro. '||vp_cta_debito,null);
                          v_scrdta := rpad(nvl(v_scrdta,' '),322,' ');
                          v_bncmsg := rpad(nvl(v_bncmsg,' '),408,' ');
                          vp_respuesta := vp_respuesta||v_doceli||v_scrdta||v_bncmsg;
                       elsif substr(vp_negocio,37,4) = '#ES#' then
                          if v_err_seguro != 0 then
                             v_scrdta := lf_set_mensaje('Ha ocurrido un error. El Seguro no ha sido procesado',null);
                             v_scrdta := rpad(nvl(v_scrdta,' '),322,' ');
                             v_bncmsg := rpad(nvl(v_bncmsg,' '),408,' ');
                             vp_respuesta := vp_respuesta||v_doceli||v_scrdta||v_bncmsg;
                          else
                             --confirmacion de seguro
                             v_doceli := fug_obt_tex_seg_atm(v_cod_persona,'T');
                             v_doceli := rpad(nvl(v_doceli,' '),480,' ');
                             v_scrdta := fug_obt_tex_seg_atm(v_cod_persona,'P');
                             v_scrdta := rpad(nvl(v_scrdta,' '),322,' ');
                             v_bncmsg := rpad(nvl(v_bncmsg,' '),408,' ');
                             vp_respuesta := vp_respuesta||v_doceli||v_scrdta||v_bncmsg;
                          end if;
                       end if;
                     else
                       v_est_modulo := pae_cnf.fu_obt_est_modulo(3);
                        if v_est_modulo not in (1, 6) Then -- Se incluye Proceso de cierre.
                         if to_number(vp_operacion) in (13,2,5) and vp_cod_respuesta = vr_aprobado then --Consulta/Extracto ATM
                           if v_cal_cargo = 'S' then
                            if to_number(vp_operacion) = 13 and nvl(trim(substr(vp_negocio,37,4)),0) = 0 then
                               v_scrdta := '08'||fug_obt_pardinamico('MSJ_MENU_ATM');
                            else
                               v_scrdta := fut_tie_pre_aprobada(v_cod_persona,v_cod_moneda,vp_cta_debito,substr(vp_negocio,37,4));--verificar si tiene una tarjeta pre-aprobada
                            end if;
                                      v_pre_aprobada := v_scrdta;
                            --PCCDEEVO-80 para guardar Rechazos
                            --Si es prestamo pre-aprobado
                            if substr(v_pre_aprobada,321,2) = '#F' then
                               lp_act_rechazo(v_cod_persona,vp_cta_debito, substr(v_pre_aprobada,321,2), 'I' );
                            end if;
                           end if;
                         end if;
                         -- MDPMATNT-1 - Mensajería en ATM sobre comisiones por transacciones -- CN: 02/2016
                         --if to_number(vp_operacion) in (2, 52, 5, 55) -- Consulta de Saldo  o Extraccion
                         if lf_cal_cob_cargo(to_number(vp_operacion))  -- Consulta de Saldo  o Extraccion
                           and vp_cod_respuesta = vr_aprobado and to_number(vp_extorno) != 99 Then
                            v_bncmsg := fuj_obt_tex_car_uso_atm(vp_cta_debito,vp_operacion,vp_bco_atm,v_cod_entidad);
                         end if;
                         if v_scrdta <> 'N' then
                            v_scrdta := rpad(v_scrdta,322,' ');--SCRDTA(322) || lineas para desplegar en la pantalla del ATM
                            -- MDPMATNT-1 - Mensajería en ATM sobre comisiones por transacciones -- CN: 02/2016 --
                            v_bncmsg := rpad(nvl(v_bncmsg,' '),408,' '); --BNCMSG(408) || lineas para desplegar en la pantalla del ATM indicando el costo de la transaccion
                            vp_respuesta := vp_respuesta||v_doceli||v_scrdta||v_bncmsg;
                         else
                            v_scrdta := rpad(nvl(v_scrdta,' '),322,' ');--SCRDTA(322)
                            -- MDPMATNT-1 - Mensajería en ATM sobre comisiones por transacciones -- CN: 02/2016 --
                            v_bncmsg := rpad(nvl(v_bncmsg,' '),408,' '); --BNCMSG(408) || lineas para desplegar en la pantalla del ATM indicando el costo de la transaccion
                            vp_respuesta := vp_respuesta||v_doceli||v_scrdta||v_bncmsg;
                         end if;
                       end if;
                     end if;
                   else
                     /*
                     --Mensaje que se envia si salta otro error
                     v_scrdta := substr(v_msj_error,1,322);
                     v_scrdta := rpad(v_scrdta,322,' ');--SCRDTA(322) || lineas para desplegar en la pantalla del ATM
                     */
                     if to_number(vp_operacion) = 85 then
                       if substr(vp_negocio,37,4) = '#GS#' then
                         v_scrdta := 'N';
                         v_scrdta := rpad(v_scrdta,322,' ');
                         v_bncmsg := rpad(nvl(v_bncmsg,' '),408,' ');
                         vp_respuesta := vr_reintente||substr(vp_respuesta,3,length(vp_respuesta))||v_doceli||v_scrdta||v_bncmsg;
                       elsif substr(vp_negocio,37,4) = '#FS#' then
                         v_scrdta := 'N';
                         v_scrdta := rpad(v_scrdta,322,' ');
                         v_bncmsg := rpad(nvl(v_bncmsg,' '),408,' ');
                         vp_respuesta := vr_no_aprobado||substr(vp_respuesta,3,length(vp_respuesta))||v_doceli||v_scrdta||v_bncmsg;
                       else
                         v_scrdta  := 'N';
                         v_scrdta  := rpad(v_scrdta,322,' ');
                          v_bncmsg := rpad(nvl(v_bncmsg,' '),408,' ');
                         vp_respuesta := vp_respuesta||v_doceli||v_scrdta||v_bncmsg;
                       end if;
                     else
                       v_scrdta := 'N';
                       v_scrdta := rpad(v_scrdta,322,' ');
                       v_bncmsg := rpad(nvl(v_bncmsg,' '),408,' ');
                       vp_respuesta := vp_respuesta||v_doceli||v_scrdta||v_bncmsg;
                     end if;
                   end if;

                   -- para el bbva siempre se responde 869 bytes + 1 byte de fin
                   --vp_respuesta := rpad(vp_respuesta,(869 + 1),' ');

                   -- MDPMATNT-1 - Mensajería en ATM sobre comisiones por transacciones -- CN: 02/2016 --
                   vp_respuesta := rpad(vp_respuesta,(1277 + 1),' ');
                   --

                   --vp_respuesta := rpad(vp_respuesta,(869),' ');
       else
          vp_respuesta :=
                   vp_cod_respuesta||
                   vp_sal_disponible||
                   vp_sig_disponible||
                   vp_sal_contable||
                   vp_sig_contable||
                   vp_transaccion||
                   vp_tra_entidad||
                   vp_can_extractos;
                   --v_doceli;         --DOCELI(480)  || lineas para impresion en el pie del ticket
                   --v_scrdta          --SCRDTA(322)  || Lineas para desplegar en la pantalla del ATM
                   --v_bncmsg          --BNCMSG(408)  || lineas para desplegar en la pantalla del ATM indicando el costo de la transaccion

                   -- para el bbva siempre se responde 869 bytes de respuesta + 512 de extractos + 1 byte
                   --vp_respuesta := rpad(vp_respuesta,869,' ');
                   -- MDPMATNT-1 - Mensajería en ATM sobre comisiones por transacciones -- CN: 02/2016
                   -- para el bbva siempre se responde 1277 bytes de respuesta + 512 de extractos + 1 byte

                   if lf_cal_cob_cargo(to_number(vp_operacion))  -- Extracto
                     and vp_cod_respuesta = vr_aprobado and to_number(vp_extorno) != 99 Then
                      v_bncmsg := fuj_obt_tex_car_uso_atm(vp_cta_debito,vp_operacion,vp_bco_atm,v_cod_entidad);
                   end if;

                   v_doceli := rpad(nvl(v_doceli,' '),480,' ');  --DOCELI(480)
                   v_scrdta := rpad(nvl(v_scrdta,' '),322,' ');  --SCRDTA(322)
                   v_bncmsg := rpad(nvl(v_bncmsg,' '),408,' ');  --BNCMSG(408)

                   vp_respuesta := vp_respuesta||v_doceli||v_scrdta||v_bncmsg;


                   vp_respuesta := rpad(vp_respuesta,1277,' ');
                   --

           vp_respuesta := vp_respuesta || rpad(nvl(vp_extractos, ' '), (512 + 1), ' ');

          --vp_respuesta := vp_respuesta || rpad(nvl(vp_extractos, ' '), (512), ' ');
       end if;

   end lp_car_salida;

   function lf_es_banco return varchar2 is
   Begin
     If to_number(substr(pag_gen.fu_obt_cod_entidad,1,2)) = 10 then
        return 'S';
     Else
        return 'N';
     End if;
   End;

   procedure lp_car_val_inicial is
     v_nro_cta_credito ge_cuentas.nro_cuenta%type;
     v_nro_cta_debito ge_cuentas.nro_cuenta%type;
     v_existe varchar2(1); --DYDMR-13485 GC 08/20 Verificación de CTA Billetera ZIMPLE
   Begin
     -- Verifica si la entidad es un banco o una financiera
     v_es_banco := 'S';/*lf_es_banco*/  --Mejoras ATM DE-2209 - Punto 7: Mejora en carga de Variables Fijas y Parametros
     -- Obtiene que entidad le corresponde para poder procesar --
     --Mejoras ATM DE-2209 - Punto 7: Mejora en carga de Variables Fijas y Parametros
     v_cod_entidad    := to_number(fug_obt_pardinamico('COD_ENT_INFONET',null,null,null,null));
     vp_cod_respuesta := vr_aprobado;
     v_concepto       := substr(trim(vp_negocio), 1, 35);
     v_est_modulo     := pae_cnf.FU_OBT_EST_MODULO(3);

     -- Verifica el horario.
     lp_ver_horario;
     -- Obtiene la oficina de Casa Matriz.
     --v_ofi_origen := 7;

     --Mejoras ATM DE-2209 - Punto 7: Mejora en carga de Variables Fijas y Parametros
     Begin
       Select cod_ofi_matriz
         into v_ofi_origen
         from ge_par_generales;
     end;
     -- Si la implementacion es Banco BBVA Formateo las ctas
     --Mejoras ATM DE-2209 - Punto 7: Mejora en carga de Variables Fijas y Parametros
     ---If fug_obt_tip_implementacion = 1 then
        if to_number(vp_bco_credito) = v_cod_entidad Then
          begin
            select val_maximo
              into v_nro_cta_credito
              from ba_cod_referencias r
             where dominio = 'COD_CTA_EQU_BBVA'
               and r.val_minimo = vp_cta_credito;
          exception
            when others then
              v_nro_cta_credito := vp_cta_credito;
          end;

          if v_nro_cta_credito is not null then
             vp_cta_credito := v_nro_cta_credito;
          end if;
--======= Fin Modificacion Temporal
          vp_cta_credito := substr('0000000000'||trim(vp_cta_credito),-10);

          -- Si la cuenta viene prefijo 99 corresponde a una TDD Mastercard con cta alias
          -- obtenemos la cuenta real del cliente en la tabla de relacion
          -- SDBIN8TDD - ABR/2021
          if substr(to_number(vp_cta_credito),1,2) = 99 then
            begin
              select nro_cta_cliente into v_nro_cta_cli_credito
               from ah_tar_cta_ficticias
              where nro_cuenta = to_number(vp_cta_credito);
                 vp_cta_credito := v_nro_cta_cli_credito;
            exception
              when others then null;
            end;
          else
            /*v_tip_cuenta := substr(vp_cta_credito,4,1);
            if v_tip_cuenta in ('1','3') then
               v_tip_cuenta := '01';
               vp_cta_credito := substr(vp_cta_credito,2,2)||v_tip_cuenta||substr(vp_cta_credito, -6);
            elsif v_tip_cuenta in ('2','4') then
               v_tip_cuenta := '02';
               vp_cta_credito := substr(vp_cta_credito,2,2)||v_tip_cuenta||substr(vp_cta_credito, -6);
            end if;
             vp_cta_credito := trim(to_char(to_number(substr('           '||vp_cta_credito, -6))));*/
             vp_cta_credito := vp_cta_credito;
          end if;
        End if;


        if to_number(vp_bco_debito) = v_cod_entidad Then
          -- Billetera Zimple / Operaciones sin tarjetas -- CN: 08/2016 --
          -- Se utiliza directamente la cuenta ITGF --
          --DYDMR-13503--GC Ajuste para Billetera Zimple
            begin
            select val_minimo
              into v_nro_cta_debito
              from ba_cod_referencias r
             where dominio = 'COD_CTA_EQU_ZIMPLE'
               and r.val_maximo = vp_cta_debito;
          exception
            when others then
              v_nro_cta_debito := null;
          end;



          --If vp_tip_ope is null then -- Se reemplaza por el medio de pago
          -- Si es 04 es Debito en Cuenta -- 02 = Tarjeta de Débito
          if (nvl(vp_med_pago,'02') != '04') or (nvl(vp_med_pago,'02') = '04' and v_tip_servicio = 'PIC') then -- Operacion con Tarjeta, por defecto -- utilizar cta bancard
            vp_cta_debito := substr('0000000000'||trim(vp_cta_debito),-10);
            -- vp_cta_debito := trim(to_char(to_number(substr('           '||vp_cta_debito, -6))));

            -- si la cuenta viene con prefijo 99 corresponde a TDD mastecard con cuenta alias
            -- buscamos la cuenta real del cliente en la tabla de relacion.
            -- SDBIN8TDD - ABR/2021
            if substr(to_number(vp_cta_debito), 1,2) = 99 then
              begin
                select nro_cta_cliente into v_nro_cta_cli_debito
                  from ah_tar_cta_ficticias
                where nro_cuenta = to_number(vp_cta_debito);
                  vp_cta_debito := v_nro_cta_cli_debito;
              exception
                when others then null;
              end;
            else
              /*v_tip_cuenta := substr(vp_cta_debito,4,1);
              if v_tip_cuenta in ('1','3') then
                 v_tip_cuenta := '01';
                 vp_cta_debito := substr(vp_cta_debito,2,2)||v_tip_cuenta||substr(vp_cta_debito, -6);
              elsif v_tip_cuenta in ('2','4') then
                 v_tip_cuenta := '02';
                 vp_cta_debito := substr(vp_cta_debito,2,2)||v_tip_cuenta||substr(vp_cta_debito, -6);
              end if;*/
              vp_cta_debito := vp_cta_debito;
            end if;
            -- vp_cta_debito := trim(to_char(to_number(substr('           '||vp_cta_debito, -6))));
          else
            if substr(to_number(vp_cta_debito), 1,2) = 99 then
              begin
                select nro_cta_cliente into v_nro_cta_cli_debito
                  from ah_tar_cta_ficticias
                where nro_cuenta = to_number(vp_cta_debito);
                  vp_cta_debito := v_nro_cta_cli_debito;
              exception
                when others then null;
              end;
            else
              vp_cta_debito  := lpad(vp_cta_debito,10,'0');
            end if;
          End if;  -- Billetera Zimple / Operaciones sin tarjetas -- CN: 08/2016 --
          if v_nro_cta_debito is not null then -- GC CTA TRANSACCIONAL ZIMPLE
               vp_cta_debito := v_nro_cta_debito;
               vp_cta_debito  := lpad(vp_cta_debito,10,'0');
          end if;
        End if;
       -------- Verifica la moneda de la tarjeta...-------
     if vp_moneda = '01' Then
        v_cod_moneda := 'USD';
     else
        v_cod_moneda := 'GS';
     end if;
     --------
     -- tys: codigo de modalidad para cuenta de bancos del pais
     --if v_cod_moneda = 'GS' then
       v_mad_bco_pais := 42;
     --else
     --  v_mad_bco_pais := 48;
     --end if;
     -- fin tys
     --- DYDMR-763 Diferencia de saldo IT y ATM - SC 5612
     v_hora := substr(vp_hora, 1, 2)||':'||substr(vp_hora,3,2)||':'||substr(vp_hora,5,2);
     v_hor_referencia := v_hora;
     -- para evitar la repeticion de la hora en los movimientos
     -- v_hora := lf_obt_hor_disponible(v_fec_proceso, v_hora, v_cod_usuario, v_es_nocturno);
     v_hora := fug_obt_hor_disponible(v_fec_proceso, v_hora, v_cod_usuario, v_es_nocturno);

     ---------------------------------------------------
     -- Al Carga los importes
     -- Dividir entre 100 el importe porque envian con 2 decimales...
     v_importe        := (to_number(vp_importe) /*no hace falta sumar segun TAKEO + to_number(vp_importe2) + to_number(vp_importe3)*/) / 100;
     --Infonet cobranza, banco facturador
     v_imp_comision   := (to_number(vp_importe2))/100;

     -- Asignacion del nro de documento
     v_nro_documento  := substr('          '||vp_transaccion, -7, 7);
     v_nro_documento2 := to_number(vp_nro_atm);
     v_nro_documento3 := vp_transaccion;
     --
     /*
     --- DYDMR-763 Diferencia de saldo IT y ATM - SC 5612
     v_nro_secuencia := to_char(systimestamp,'ff3');
     if v_nro_secuencia > 996 then
        v_nro_secuencia := 996;
     end if;
     */
     v_nro_secuencia := 1;
     v_tip_monto     := 'E'; -- Siempre es efectivo
     --
     if to_number(vp_bco_credito) = v_cod_entidad Then
        v_clt_cre_nuestro := 'S';
     end if;
     -- Verifica si el ATM es de la Entidad --
     v_nro_caja := null;
     if to_number(vp_bco_atm) = v_cod_entidad Then
        v_atm_nuestro := 'S';
        v_nro_caja    := to_number(vp_nro_atm);
     end if;
     -- Si es banco...
     If v_es_banco = 'S' then
        If to_number(vp_operacion) not in (40,41,51,52,54,58) then
          if to_number(vp_bco_atm) = v_cod_entidad Then
            -- Si es banco debe verificar la cuenta corriente
            Begin
             Select cod_oficina, nro_cuenta, cod_rubro, nro_caja
               into v_ofi_origen, vp_cta_credito, v_cod_rub_caja, v_nro_caja
               from cc_cta_cajeros
              where nro_caj_externo = v_nro_caja
                and cod_moneda = v_cod_moneda;
            vp_bco_credito := vp_bco_atm;
            Exception
              When NO_DATA_FOUND then
                  if vp_cta_credito = '0' and to_number(vp_bco_credito) = v_cod_entidad then
                     vp_cod_respuesta := vr_cta_inexistente;
                  end if;
            End;
          End if;
          -- verifica
          If to_number(vp_bco_atm) not in (v_cod_entidad, 0) and
             to_number(vp_operacion) in (5,55) Then
             -- Es el atm de otro banco y es una extracción.
             Begin
               --30/07/2014: BBVANOR-1259 - Operaciones con Financieras del País sin Banco Sponsor
               /*Halla el Cod. de Ente por el Cod. de la Entidad Financiera
                 En la Procesadora Parametrizado.*/
               Select cod_ente
                 into v_cod_ent_financiera
                 from ge_par_entes a
                where a.parametro = 'COD_ENT_FINANCIERA'
                  and to_number(a.val_parametro) = to_number(vp_bco_atm);
             Exception
                 When NO_DATA_FOUND then
                    v_cod_ent_financiera := NULL;
             End;
             Begin
               Select nro_cuenta
                 into vp_cta_credito
                 from cc_cta_bancarias
                where ((cod_banco     = to_number(vp_bco_atm)
                  and cod_modalidad = v_mad_bco_pais) -- Modalidad de ATM'S Bancos.
                   or (cod_ente = to_number(v_cod_ent_financiera)
                  and cod_modalidad = v_mad_ent_pais)) -- Modalidad de ATM'S Financieras. wa:31/07/2014 parentesis por logica
                  and cod_moneda    = v_cod_moneda;
               vp_bco_credito := vp_bco_atm;
             Exception
                When NO_DATA_FOUND then
                   NULL;
                   --raise_application_error(-20000,'no encuentro cuenta del banco '||vp_bco_atm||' '||v_cod_moneda);
             End;
          Elsif to_number(vp_bco_atm) not in (v_cod_entidad) and
             to_number(vp_operacion) in (3,7,31,32) Then
             -- Se considera mensaje al banco.
             vp_operacion := 93;
          End if;
       Elsif to_number(vp_operacion) in (40,41) then
          If vp_bco_credito = v_cod_entidad then
            v_clt_cre_nuestro := 'S';
          Else
            v_clt_cre_nuestro := 'N';
          End if;
          If vp_bco_debito = v_cod_entidad then
            v_clt_deb_nuestro := 'S';
          Else
            v_clt_deb_nuestro := 'N';
          End if;
          If to_number(vp_bco_atm) in (v_cod_entidad) and
             v_clt_deb_nuestro = 'N' and v_clt_cre_nuestro = 'N' then
             -- El ATM es nuestro pero ninguno de los clientes es nuestro.
             -- por lo tanto se considera como un mensaje.
             vp_operacion := 93;
          elsif to_number(vp_bco_atm) not in (v_cod_entidad,0) and
             v_clt_deb_nuestro = 'N' then
              --
              Begin
              /*Halla el Cod. de Ente por el Cod. de la Entidad Financiera
                 En la Procesadora Parametrizado.*/
               Select cod_ente
                 into v_cod_ent_financiera
                 from ge_par_entes a
                where a.parametro = 'COD_ENT_FINANCIERA'
                  and to_number(a.val_parametro) = to_number(vp_bco_debito);--WA:30/07/2014 to_number(vp_bco_atm)
              Exception
                 When NO_DATA_FOUND then
                    v_cod_ent_financiera := NULL;
              End;

              Begin
               Select NRO_CUENTA
                 into vp_cta_debito
                 from cc_cta_bancarias
                where ((cod_banco     = to_number(vp_bco_debito)--WA:30/07/2014 to_number(vp_bco_atm)
                  and cod_modalidad = v_mad_bco_pais) -- Modalidad de ATM'S Bancos.
                   or (cod_ente = to_number(v_cod_ent_financiera)
                  and cod_modalidad = v_mad_ent_pais)) -- Modalidad de ATM'S Financieras.wa:31/07/2014 parentesis por logica
                  and cod_moneda    = v_cod_moneda;
              Exception
                When NO_DATA_FOUND then
                  vp_cod_respuesta := vr_cta_inexistente;
              End;
          elsif to_number(vp_bco_atm) not in (v_cod_entidad,0) and
             v_clt_cre_nuestro = 'N' then
             --wa:30/07/2014 Para igualar a superior
              Begin
              /*Halla el Cod. de Ente por el Cod. de la Entidad Financiera
                 En la Procesadora Parametrizado.*/
               Select cod_ente
                 into v_cod_ent_financiera
                 from ge_par_entes a
                where a.parametro = 'COD_ENT_FINANCIERA'
                  and to_number(a.val_parametro) = to_number(vp_bco_credito);--WA:30/07/2014 to_number(vp_bco_atm)
              Exception
                 When NO_DATA_FOUND then
                    v_cod_ent_financiera := NULL;
              End;

              --
              Begin
               Select nro_cuenta
                 into vp_cta_credito
                 from cc_cta_bancarias
                where ((cod_banco     = to_number(vp_bco_credito)
                  and cod_modalidad = v_mad_bco_pais) -- Modalidad de ATM'S Bancos.
                   or (cod_ente = to_number(v_cod_ent_financiera)
                  and cod_modalidad = v_mad_ent_pais)) -- Modalidad de ATM'S Financieras.wa:31/07/2014 parentesis por logica
                  and cod_moneda    = v_cod_moneda;
              Exception
                When NO_DATA_FOUND then
                  vp_cod_respuesta := vr_cta_inexistente;
              End;
          End if;
       End if;
       -- Si es nuestro ATM o nuestro POST...
       If to_number(vp_bco_atm) in (v_cod_entidad,0) then
          -- Si la Cuenta de credito no es del Banco.
          If to_number(vp_bco_credito) not in (v_cod_entidad, 0) then
            Begin
               /*Halla el Cod. de Ente por el Cod. de la Entidad Financiera
                 En la Procesadora Parametrizado.*/
               Select cod_ente
                 into v_cod_ent_financiera
                 from ge_par_entes a
                where a.parametro = 'COD_ENT_FINANCIERA'
                  and to_number(a.val_parametro) = to_number(vp_bco_credito); --wa:30/07/2014 to_number(vp_bco_atm);
            Exception
                When NO_DATA_FOUND then
                   v_cod_ent_financiera := NULL;
            End;


            Begin
             Select nro_cuenta
               into vp_cta_credito
               from cc_cta_bancarias
              where ((cod_banco     = to_number(vp_bco_credito) --wa:30/07/2014 to_number(vp_bco_atm);
                and cod_modalidad = v_mad_bco_pais) -- Modalidad de ATM'S Bancos.
                 or (cod_ente = to_number(v_cod_ent_financiera)
                and cod_modalidad = v_mad_ent_pais)) -- Modalidad de ATM'S Financieras.wa:31/07/2014 parentesis por logica
                and cod_moneda    = v_cod_moneda;
            Exception
              When NO_DATA_FOUND then
                vp_cod_respuesta := vr_cta_inexistente;
            End;
          End if;
          -- Si la Cuenta de debito no es del Banco.
          If to_number(vp_bco_debito) not in (v_cod_entidad) then
            Begin
               /*Halla el Cod. de Ente por el Cod. de la Entidad Financiera
                 En la Procesadora Parametrizado.*/
               Select cod_ente
                 into v_cod_ent_financiera
                 from ge_par_entes a
                where a.parametro = 'COD_ENT_FINANCIERA'
                  and to_number(a.val_parametro) =to_number(vp_bco_debito); --wa:30/07/2014 to_number(vp_bco_atm);
            Exception
                When NO_DATA_FOUND then
                   v_cod_ent_financiera := NULL;
            End;


            Begin
             Select NRO_CUENTA
               into vp_cta_debito
               from cc_cta_bancarias
              where ((cod_banco     = to_number(vp_bco_debito) --wa:30/07/2014 to_number(vp_bco_atm);
                 and cod_modalidad = v_mad_bco_pais) -- Modalidad de ATM'S Bancos.
                  or (cod_ente = to_number(v_cod_ent_financiera)
                 and cod_modalidad = v_mad_ent_pais)) -- Modalidad de ATM'S Financieras.wa:31/07/2014 parentesis por logica
                 and cod_moneda    = v_cod_moneda;
            Exception
              When NO_DATA_FOUND then
                vp_cod_respuesta := vr_cta_inexistente;
            End;
          End if;
       End If;
     End if;
     -- Verifica de vuelta si es nuestro cliente...
     If vp_bco_credito = v_cod_entidad then
        v_clt_cre_nuestro := 'S';
     Else
        v_clt_cre_nuestro := 'N';
     End if;
     If vp_bco_debito = v_cod_entidad then
        v_clt_deb_nuestro := 'S';
     Else
        v_clt_deb_nuestro := 'N';
     End if;
     -- Verifica si la cuenta es una cuenta ficticia...
     --
     v_ind_rub_debito  := 'N';
     v_tra_con_debito := null;
     v_mod_con_debito     := null;
     v_mad_con_debito     := null;
     v_cod_rub_debito        := null;

     v_ind_rub_credito  := 'N';
     v_tra_con_credito := null;
     v_mod_con_credito     := null;
     v_mad_con_credito     := null;
     v_cod_rub_credito        := null;
     v_nro_cta_cliente   := null;
     --
     if to_number(vp_bco_debito) = v_cod_entidad then
         Begin
           select 'S', cod_transaccion, cod_modulo, cod_modalidad, cod_rubro, nro_cta_cliente
             into v_ind_rub_debito, v_tra_con_debito, v_mod_con_debito, v_mad_con_debito,
                  v_cod_rub_debito, v_nro_cta_cliente
             from cc_cta_ficticias
            where nro_cuenta = vp_cta_debito;
           v_nro_cta_fic_deb := vp_cta_debito;
           vp_cta_debito := null;
           if v_cod_rub_debito is null and v_nro_cta_cliente is not null then
              vp_cta_debito := v_nro_cta_cliente;
              v_ind_rub_debito := 'N';
           end if;
         Exception
           When NO_DATA_FOUND then
             v_ind_rub_debito := 'N';
         End;
     end if;
     v_nro_cta_cliente   := null;
     if to_number(vp_bco_credito) = v_cod_entidad then
         Begin
             select 'S', cod_transaccion, cod_modulo, cod_modalidad, cod_rubro, nro_cta_cliente
               into v_ind_rub_credito, v_tra_con_credito, v_mod_con_credito, v_mad_con_credito,
                    v_cod_rub_credito, v_nro_cta_cliente
               from cc_cta_ficticias
              where nro_cuenta = vp_cta_credito;
             v_nro_cta_fic_cre := vp_cta_credito;
             vp_cta_credito := null;
             if v_cod_rub_credito is null and v_nro_cta_cliente is not null then
                vp_cta_credito := v_nro_cta_cliente;
                v_ind_rub_credito := 'N';
             end if;
             if v_mod_con_credito = 5 then
                -- es pago de tarjetas del Banco
                begin
                    select b.nro_cuenta, b.cod_oficina, b.cod_modalidad
                      into v_nro_cta_tarjeta, v_ofi_con_credito, v_mad_con_credito
                      from ge_cuentas b, ta_tarjetas a
                     where a.nro_tarjeta = vp_nro_tarjeta
                       and b.nro_cuenta = a.nro_cuenta
                       and rownum = 1;
                exception
                  when others then
                     v_nro_cta_tarjeta := null;
                end;
             else
                -- limpio el campo porque no es un cobro de tarjeta
                vp_nro_tarjeta := null;
             end if;
         Exception
             When NO_DATA_FOUND then
                v_ind_rub_credito := 'N';
         End;
     end if;
     -- Verifica si la cuenta de debito es de la Entidad --
     if v_ind_rub_debito = 'N' Then
       if to_number(vp_bco_debito) = v_cod_entidad then
          v_clt_deb_nuestro := 'S';
       end if;
       lp_dat_cta(vp_cta_debito, v_mod_cta_deb, v_mad_cta_deb, v_ofi_cta_deb, v_mon_cta_deb, v_ind_cta_deb_tra);
       If vp_cod_respuesta = vr_aprobado and to_number(vp_operacion) not in (2, 52, 93, 6) then
          --Mejoras ATM DE-2209--Punto 4: No Bloquear la Cuenta de Débito cuando sea Cuenta Bancaria
          if v_mad_cta_deb not in (42,46,49) and nvl(v_ind_cta_deb_tra, 'N') <> 'S' then
            -------------------------------------------------------------------------------------------
            --Mejoras ATM DE-2209--Punto 1: Realizar 3 intentos para bloqueo de la Cuenta de Débito
            --cuando es de modalidad 41-Cuenta Corriente o 31-Caja de Ahorro.
            -------------------------------------------------------------------------------------------
            for v_can_int_bloqueo in 1..3 loop
                IF PAG_CTA.FU_LLAVEAR_CUENTA(v_mad_cta_deb, vp_cta_debito, v_es_cta_noc) = 'N' Then
                   if v_can_int_bloqueo = 3 then
                      vp_cod_respuesta := vr_reintente;
                      exit;
                   end if;
                else
                   exit;
                end if;
            end loop;
          end if;
       End if;
     end if;
     -- DYDMR-1817-ITGF-Error "tarjeta inexistente" al consultar de saldo TDD en el exterior-SC15142-27/05/2015.
     if vp_cta_credito is not null and to_number(vp_cta_credito) != 0 and v_ind_rub_credito = 'N' Then
        if to_number(vp_bco_credito) = v_cod_entidad then
          v_clt_cre_nuestro := 'S';
        end if;
        lp_dat_cta(vp_cta_credito, v_mod_cta_cre, v_mad_cta_cre, v_ofi_cta_cre, v_mon_cta_cre, v_ind_cta_cre_tra);
        If vp_cod_respuesta = vr_aprobado and to_number(vp_operacion) not in (2, 52, 93, 6) then
          --Mejoras ATM DE-2209--Punto 3: No Bloquear la Cuenta de Crédito cuando sea Cuenta Bancaria
          if v_mad_cta_cre not in (42,46,49) and nvl(v_ind_cta_cre_tra, 'N') <> 'S' then
            ------------------------------------------------------------------------------------------
            --Mejoras ATM DE-2209--Punto 2: Realizar 3 intentos para bloqueo de la Cuenta de Credito
            --cuando es de modalidad 41-Cuenta Corriente o 31-Caja de Ahorro.
            --Solo posterior a ello generar el error 19-Reintente
            ------------------------------------------------------------------------------------------
            for v_can_int_bloqueo in 1..3 loop
                IF PAG_CTA.FU_LLAVEAR_CUENTA(v_mad_cta_cre, vp_cta_credito, v_es_cta_noc) = 'N' Then
                   if v_can_int_bloqueo = 3 then
                      vp_cod_respuesta := vr_reintente;
                      exit;
                   end if;
                else
                   exit;
                end if;
            end loop;
          end if;
        End if;
     end if;
     -- tys: realiza la conversion de montos
     if vp_cod_respuesta = vr_aprobado and to_number(vp_operacion) not in (2, 52, 93, 6) then
       if v_cod_moneda <> v_mon_cta_deb then -- si la moneda de la operacion es distinta a la moneda de la cuenta de debito
         -- realiza la conversión de monto credito -> debito. el importe de debito de estar nulo
         v_imp_debito  := null;
         v_imp_credito := v_importe;
         lp_con_mon_a_moneda(v_mon_cta_deb, v_cod_moneda, v_fec_proceso, v_imp_debito, v_imp_credito, v_cot_debito, v_cot_credito);
       end if;
       if v_imp_debito is null then
         v_imp_debito := v_importe;
       end if;
       if v_mon_cta_cre <> v_mon_cta_deb then
         -- realiza la conversion de monto debito -> credito
         lp_con_mon_a_moneda(v_mon_cta_deb, v_mon_cta_cre, v_fec_proceso, v_imp_debito, v_imp_credito, v_cot_debito, v_cot_credito);
       end if;
       if v_imp_credito is null then
         v_imp_credito := v_importe;
       end if;
     end if;

     --Valida Transacciones de Infonet Cobranzas de entidades públicas, donde el Banco facturador es BBVA
     if v_ind_rub_credito = 'S' Then
       begin
          v_cod_rub_facturador := fue_obt_val_max_refcodes('COD_RUB_FACTURADOR', v_nro_cta_fic_cre);
       exception
          when others then
            v_cod_rub_facturador := nulL;
       end;
       if v_cod_rub_facturador is not null then
          v_ind_acr_batch := 'S';
       else
          v_ind_acr_batch := 'N';
       end if;
     else
       v_ind_acr_batch := 'N';
     end if;

     --Ver si la cuenta está configurada para comisión
     begin
       select distinct 'S'
         into v_ind_obt_comision
         from ba_cod_referencias
        where dominio = 'NRO_CTA_COM_BANCARD'
          and val_minimo = nvl(v_nro_cta_fic_cre, vp_cta_credito);
      exception
        when others then
          v_ind_obt_comision := 'N';
      end;


     -- ver si es cuenta facturador
     if vp_operacion in (72, '00' ) and nvl(v_imp_comision,0) <> 0 and nvl(v_ind_obt_comision, 'N') = 'S' then
        --valido que exista la cuenta de bancard de cobro de comisiones por la operacion 72, en la moneda de la operación.
        v_cta_com_bancard := fue_obt_val_max_refcodes('NRO_CTA_COM_BANCARD',nvl(v_nro_cta_fic_cre, vp_cta_credito) );

        if v_cta_com_bancard is null then
           vp_cod_respuesta := vr_no_aprobado;
        end if;

        if v_mon_cta_cre <> 'GS' then
           vp_cod_respuesta := vr_no_aprobado;
        end if;

        begin
           select cod_modulo, cod_modalidad, cod_oficina
             into v_cod_mod_com_ban, v_cod_mad_com_ban, v_ofi_cta_com
             from ge_cuentas
            where nro_cuenta = v_cta_com_bancard;
        exception
          when others then
            vp_cod_respuesta := vr_no_aprobado;
        end;
        if v_cod_mod_com_ban = 4 then
           begin
             select estado
               into v_est_cta_com_ban
               from cc_cta_corrientes
              where nro_cuenta = v_cta_com_bancard;
            exception
               when others then
                 v_est_cta_com_ban := 'N';
            end;
         else
            begin
              select estado
                into v_est_cta_com_ban
                from ah_cta_vistas
               where nro_cuenta = v_cta_com_bancard;
            exception
               when others then
                   v_est_cta_com_ban := 'N';
            end;
          end if;
          if v_importe <= v_imp_comision then
             vp_cod_respuesta := vr_no_aprobado;
          end if;

          If vp_cod_respuesta = vr_aprobado then
          --Mejoras ATM DE-2209--Punto 3: No Bloquear la Cuenta de Crédito cuando sea Cuenta Bancaria
            ------------------------------------------------------------------------------------------
            --Mejoras ATM DE-2209--Punto 2: Realizar 3 intentos para bloqueo de la Cuenta de Credito
            --cuando es de modalidad 41-Cuenta Corriente o 31-Caja de Ahorro.
            --Solo posterior a ello generar el error 19-Reintente
            ------------------------------------------------------------------------------------------
            for v_can_int_bloqueo in 1..3 loop
                IF PAG_CTA.FU_LLAVEAR_CUENTA(v_cod_mad_com_ban, v_cta_com_bancard, v_es_cta_noc) = 'N' Then
                   if v_can_int_bloqueo = 3 then
                      vp_cod_respuesta := vr_reintente;
                      exit;
                   end if;
                else
                   exit;
                end if;
            end loop;
        End if;
     else
       v_ind_obt_comision := 'N';
     end if;

     -- fin tys
     -- Carga respuesta por defecto --
     vp_can_extractos  := '000';
     vp_sig_disponible := '+';
     vp_sig_contable   := '+';
     vp_sal_disponible := lpad('0', 15, '0');
     vp_sal_contable   := lpad('0', 15, '0');
     vi_sal_disponible := 0;
     vi_sal_contable   := 0;
   End lp_car_val_inicial;
   --
   procedure lp_ver_operacion_00 is
      -- Compra en Pos --
      v_sal_disponible ah_cta_vistas.sal_total%type;
      v_sal_contable   ah_cta_vistas.sal_total%type;
      v_mto_acuerdo    cc_lin_sobregiros.monto%type;
      v_cod_persona    ba_personas.cod_persona%type;
      v_tot_mov_dia    ge_movimientos.monto%type;
      v_can_ope_vuelto number;
      v_exi_boc_cobro  varchar2(1) := 'N';
      v_tot_sal_pen    ge_mov_inf_cobranzas.monto%type;
      v_afe_debito     varchar2(1) default 'N';
   Begin
      -- Hace las verificaciones si es clte de debito es nuestro....
      if  nvl(to_number(vp_cta_debito),0) != 0 then
          vp_cod_respuesta := vr_aprobado;
          -- Obtiene los datos principales de la cuenta
          lp_dat_cta(vp_cta_debito, v_mod_cta_deb, v_mad_cta_deb, v_ofi_cta_deb, v_mon_cta_deb, v_ind_cta_deb_tra);
          /* tys: si la moneda es distinta convierte el monto
          If v_mon_cta_deb != v_cod_moneda then
             -- Se responde que la cuenta no existe...
             vp_cod_respuesta := vr_cta_inexistente;
          End if;*/
         -- Verifica si el Cliente está inhibido y la causa es por Demanda Judicial --CROCLIJUD-5
          v_cod_persona := fug_obt_cli_principal(vp_cta_debito);
          if fug_obt_inhibicion(fug_obt_pardinamico('COD_CAU_DEM_JUDICIAL'),v_cod_persona,vp_cta_debito) Then
                vp_cod_respuesta := vr_no_aprobado;
          end If;
          -- Verifica si el Cliente o la Cta. tiene Inhibición que no permita realizar débito BSEVOCORE-147
          v_cod_persona :=fug_obt_cli_principal(vp_cta_debito);
          v_afe_debito  := fug_obt_val_parcausal('AFE_DEB_CUENTA',v_cod_persona, vp_cta_debito);
          if nvl(v_afe_debito,'N') = 'S' then
                vp_cod_respuesta := vr_no_aprobado;
          end If;

          if vp_cod_respuesta = vr_aprobado then
             --WA:31/07/2014 Se ajusta inferior para igualar a funcionamiento anterior
             if v_mad_cta_deb not in (31,41,42,48,46,49) and v_ind_rub_debito = 'N' Then -- Ahorro a la Vista/ Cta. Corrientes
                vp_cod_respuesta := vr_no_aprobado;
             end if;
          End if;

           --Validacion de saldo pendiente por Bocas de Cobro
          begin
            select 'S'
              into v_exi_boc_cobro
              from ge_cta_boc_cobro
             where nro_cuenta = vp_cta_debito
               and nvl(activo, 'N') = 'S';
          exception
            when others then
              v_exi_boc_cobro := 'N';
          end;

          if nvl(v_exi_boc_cobro, 'N') = 'S' then
             begin
               select sum(monto)
                 into v_tot_sal_pen
                 from ge_mov_inf_cobranzas
                where nro_cta_debito = vp_cta_debito
                  and liberado = 'N'
                  and reversado = 'N';
             exception
                when others then
                   v_tot_sal_pen :=0;
             end;
          else
             v_tot_sal_pen := 0;
          end if;

          -- Debe verificar el monto de la operacion
          if v_ind_cta_deb_tra = 'S' then
             v_tot_mov_dia := fuc_obt_sal_act_cta_tra(vp_cta_debito,'N');
             v_sal_disponible := nvl(pag_cta.FU_SAL_DISPONIBLE,0) + nvl(v_tot_mov_dia, 0) - nvl(v_imp_debito,0);
          else
             v_sal_disponible := nvl(pag_cta.FU_SAL_DISPONIBLE,0) - nvl(v_imp_debito,0) - nvl(v_tot_sal_pen, 0);
          end if;
           /*Validacion que rechaza Compra Infonet Cobranzas con monto 0*/
          if nvl(v_imp_debito,0) = 0 and to_number(vp_operacion) = 72 then
             vp_cod_respuesta := vr_no_aprobado;
          end if;

          --Si la Cuenta no tiene Disponible se verifica el Disponible de la Cuenta Combinada
          if v_sal_disponible < 0 and vp_cod_respuesta = vr_aprobado then
             v_sal_disponible := nvl(pag_cta.g_ctas.SAL_DIS_COMBINADA,0) - nvl(v_imp_debito,0) - nvl(v_tot_sal_pen, 0);
          end if;
          --Si aun no tiene disponible se verifica el Disponible de las dos cuentas (CTACTE + AV = FU_SAL_DIS_COMBINADA)
          if v_sal_disponible < 0 and vp_cod_respuesta = vr_aprobado then
             if v_ind_cta_deb_tra = 'S' then
                v_tot_mov_dia := fuc_obt_sal_act_cta_tra(vp_cta_debito,'N');
                v_sal_disponible := nvl(pag_cta.FU_SAL_DIS_COMBINADA,0)+ nvl(v_tot_mov_dia,0) - nvl(v_imp_debito,0);
             else
               ----------------------------------
                v_sal_disponible := nvl(pag_cta.FU_SAL_DIS_COMBINADA,0) - nvl(v_imp_debito,0) - nvl(v_tot_sal_pen, 0);
             end if;
          end if;
          --v_sal_disponible := nvl(pag_cta.FU_SAL_DIS_COMBINADA,0) - nvl(v_imp_debito,0);
          v_sal_contable   := nvl(pag_cta.g_ctas.sal_actual,0) - nvl(v_imp_debito,0);
          if v_sal_disponible < 0 and vp_cod_respuesta = vr_aprobado and
             --WA:31/07/2014 Se ajusta inferior para igualar a funcionamiento anterior
             v_mad_cta_deb not in (42,48, 46,49)  and v_ind_rub_debito = 'N' then
             If v_mad_cta_deb = 41 then
                -- SDPARDEBAU-2-MB: Si es Cuenta Corriente, tiene saldo negativo y la Cta. De Destino tiene Saldo Negativo. No debe continuar.
                If to_number(vp_operacion) = 41      -- Transferenicas
                   and to_number(vp_bco_credito) in (v_cod_entidad,vp_cod_ban_fusion) -- Internas en el BBVA
                   and FUG_OBT_CLI_PRINCIPAL(to_number(vp_bco_credito),'P') = FUG_OBT_CLI_PRINCIPAL(to_number(vp_cta_debito),'P') -- Solo entre cuenta propia
                   and FUC_OBT_SAL_SIN_SOBREGIRO(vp_cta_credito) < 0  -- Que no tenga saldo
                   Then
                    -- No tiene saldo, y va cubrir un sobregiro con una Linea de Sobregiro.
                    vp_cod_respuesta := vr_sal_insuficiente;
                ElsIf to_number(vp_operacion) = 41  -- Transferenicas
                  and to_number(vp_bco_credito) in (v_cod_entidad,vp_cod_ban_fusion) -- Internas en el BBVA
                  and FUG_OBT_CLI_PRINCIPAL(to_number(vp_bco_credito),'P') = FUG_OBT_CLI_PRINCIPAL(to_number(vp_cta_debito),'P') -- Solo entre cuenta propia
                  and FUC_OBT_SAL_SIN_SOBREGIRO(vp_cta_debito) > 0
                  and (FUC_OBT_SAL_SIN_SOBREGIRO(vp_cta_debito) - nvl(v_imp_debito,0)) < 0 -- Que tenga saldo, pero con el Monto de la Ope. va quedar sobregirado
                  Then
                    -- Tiene saldo, pero la operacion le va sobregirar y va cubrir un sobregiro con una Linea de Sobregiro.
                    vp_cod_respuesta := vr_sal_insuficiente;
                Else
          -- Si es Cuenta Corriente debe verificar si no tiene acuerdo de Sobregiro.
          --If  v_acu_sobregiro = 'S' then
             -- Debe buscar el monto del acuerdo para verificar nuevamente
             v_mto_acuerdo := PAG_CTA.FU_OBT_LIN_SOBREGIRO(vp_cta_debito,v_fec_proceso);
             -- Para cuentas de plan sueldo no dar linea de sobregiro en el dia de cobro de sueldo TYS 14-03-08
             if v_cod_ent_sueldo is not null and lf_hoy_cobro(vp_cta_debito, v_cod_ent_sueldo) = 'S' then
             v_mto_acuerdo := 0;
             end if;
             If nvl(v_mto_acuerdo,0) + nvl(v_sal_disponible,0) < 0 then
              -- Sigue siendo insuficiente su acuerdo...
             if nvl(v_exi_boc_cobro, 'N') = 'S' then
              vp_cod_respuesta := vr_exe_mto_limite;
             else
              vp_cod_respuesta := vr_sal_insuficiente; -- No tiene saldo
             end if;
             Else
              if to_number(vp_operacion) = 72 and nvl(v_exi_boc_cobro, 'N') <> 'S' then -- infonet cobranzas
               declare
                v_tot_inf_cobranza number(18,2);
               begin
                 select sum(monto)
                 into v_tot_inf_cobranza
                 from ge_mov_inf_cobranzas
                where nro_cta_debito = vp_cta_debito
                  and liberado = 'N'
                  and reversado = 'N';
                 if nvl(v_mto_acuerdo,0) + nvl(v_sal_disponible,0) - nvl(v_tot_inf_cobranza,0) < 0 then
                  vp_cod_respuesta := vr_sal_insuficiente; -- No tiene saldo
                 else
                  vp_cod_respuesta := vr_aprobado;
                 end if;
               end;
              else
              -- Sino mantiene aprobado.
              vp_cod_respuesta := vr_aprobado;
              end if;
             End if;
        End If;
                --Else
                   -- Si no es Cta Corriente debe responder Saldo Insuficiente...
                 --  vp_cod_respuesta := vr_sal_insuficiente; -- No tiene saldo
                --End if;
             Else
               -- Si no es Cta Corriente debe responder Saldo Insuficiente...
               if nvl(v_exi_boc_cobro, 'N') = 'S' then
                 vp_cod_respuesta := vr_exe_mto_limite;
               else
                 vp_cod_respuesta := vr_sal_insuficiente; -- No tiene saldo
               end if;
             End if;
          end if;
          -- Carga la respuesta --
          --WA:31/07/2014 Se ajusta inferior para igualar a funcionamiento anterior
          If v_mad_cta_deb in (42, 48, 46,49) or v_ind_rub_debito = 'S' then
             v_sal_disponible := 0;
             v_sal_contable   := 0;
          End if;
          vp_sal_disponible := lpad(trim(to_char(abs(v_sal_disponible * 100))), 15, '0');
          vi_sal_disponible := v_sal_disponible;
          if v_sal_disponible < 0 Then
             vp_sig_disponible := '-';
          end if;
          vp_sal_contable := lpad(trim(to_char(abs(v_sal_contable * 100))), 15, '0');
          vi_sal_contable := v_sal_contable;
          if v_sal_contable < 0 Then
             vp_sig_contable := '-';
          end if;
      End if;
      -- Hace las verificaciones si el clte de credito es nuestro....
      If nvl(to_number(vp_cta_credito),0) != 0 and vp_cod_respuesta = vr_aprobado Then
          -- Obtiene los datos de la cuenta de credito...
          If vp_cta_credito is not null then
            lp_dat_cta(vp_cta_credito, v_mod_cta_cre, v_mad_cta_cre, v_ofi_cta_cre, v_mon_cta_cre, v_ind_cta_cre_tra);
            pag_cta.PR_OBT_CUENTA(vp_cta_credito);
            g_cod_error := pag_cta.G_COD_ERROR;
          Else
            v_mon_cta_cre := v_cod_moneda;
            v_mod_cta_cre := v_mod_cta_deb;
            v_mad_cta_cre := v_mad_cta_deb;
            v_ofi_cta_cre := v_ofi_origen;
          End if;
          if g_cod_error = 12 Then -- Cuenta inexistente
             vp_cod_respuesta := vr_cta_inexistente; -- Tarjeta desconocida
          end if;
          If v_mon_cta_cre != v_cod_moneda and vp_cod_respuesta = vr_aprobado then
             -- Se responde que la cuenta no existe...
             vp_cod_respuesta := vr_cta_inexistente;
          End if;
          v_est_cta_cre := pag_cta.FU_OBT_EST_CUENTA;

          --WA:31/07/2014 Se ajusta inferior para igualar a funcionamiento anterior
          if (v_est_cta_cre not in ('N', 'S', 'I') or v_mad_cta_cre not in (31,41,42,48,46,49)) and vp_cod_respuesta = vr_aprobado Then -- No es normal o con bloqueo de saldo
             -- Estado Inactiva tambien debe permitir.
             vp_cod_respuesta := vr_no_aprobado; -- Transaccion no aprobada
          end if;
      End If;
      If to_number(vp_operacion) = 1 and vp_cod_respuesta = vr_aprobado Then
         if v_cod_moneda <> 'GS' then -- el vuelto sólo se puede procesar en Guaraníes
            vp_cod_respuesta := vr_no_aprobado;
         end if;
         if v_mad_cta_deb in (41, 31) then
           if v_imp_debito > nvl(v_ecp_mto_limite, 0) then
              -- No se aprueba porque el monto es superior al límite
              vp_cod_respuesta := vr_exe_mto_limite;
           end if;
           if  vp_cod_respuesta = vr_aprobado then
             begin
               select count(*)
                 into v_can_ope_vuelto
                 from ge_ope_ext_efe_pos
                where fec_valor = v_fec_valor
                  and nro_cta_deb = vp_cta_debito
                  and nvl(extornado, 'N') = 'N';
             exception
               when others then
                 v_can_ope_vuelto := 0;
             end;
             if v_can_ope_vuelto >= v_ecp_can_limite then
               vp_cod_respuesta := vr_exe_can_tra_lim;
             end if;
           end if;
         end if;
      end if;
   End lp_ver_operacion_00;
   --
   procedure lp_ver_operacion_02 is
      -- Consulta de Saldo --
      v_sal_disponible ah_cta_vistas.sal_total%type;
      v_sal_contable   ah_cta_vistas.sal_total%type;
   Begin
      If  v_clt_deb_nuestro = 'S' then
          vp_cod_respuesta := vr_aprobado;
          --v_sal_disponible := nvl(pag_cta.FU_SAL_DIS_COMBINADA,0);
          v_sal_disponible := nvl(pag_cta.FU_SAL_DISPONIBLE,0);
          --Se modifico p/ que no incluya la línea de Sobregiro en el disponible --01/02/2010
          /*
          if pag_cta.g_ctas.cod_modalidad = 41 then
             v_sal_disponible := v_sal_disponible + PAG_CTA.FU_OBT_LIN_SOBREGIRO(vp_cta_debito,v_fec_proceso);
          end if;
          */
          v_sal_contable   := nvl(pag_cta.g_ctas.sal_Actual,0);
          lp_dat_cta(vp_cta_debito, v_mod_cta_deb, v_mad_cta_deb, v_ofi_cta_deb, v_mon_cta_deb, v_ind_cta_cre_tra);
          -- Carga la respuesta --
          vp_sal_disponible := lpad(trim(to_char(abs(v_sal_disponible * 100))), 15, '0');
          vi_sal_disponible := v_sal_disponible;
          if v_sal_disponible < 0 Then
             vp_sig_disponible := '-';
          end if;
          vp_sal_contable := lpad(trim(to_char(abs(v_sal_contable * 100))), 15, '0');
          vi_sal_contable := v_sal_contable;
          if v_sal_contable < 0 Then
             vp_sig_contable := '-';
          end if;
       Else
          vp_cod_respuesta  := vr_aprobado;
          vp_sal_disponible := lpad('0', 15, '0');
          vp_sal_contable   := lpad('0', 15, '0');
          vi_sal_disponible := 0;
          vi_Sal_contable   := 0;
       End If;
   End lp_ver_operacion_02;
   --
   procedure lp_ver_operacion_05 is
      -- Extraccion de Efectivo --
      v_sal_disponible ah_cta_vistas.sal_total%type;
      v_sal_contable   ah_cta_vistas.sal_total%type;
      v_mto_acuerdo    cc_lin_sobregiros.monto%type := 0;
      v_cod_persona    ba_personas.cod_persona%type;
      v_tot_mov_dia    ge_movimientos.monto%type;
      v_exi_boc_cobro  varchar2(1) := 'N';
      v_tot_sal_pen    ge_mov_inf_cobranzas.monto%type;
      v_afe_debito     varchar2(1) default 'N';
   Begin
      -- Hace las verificaciones si es clte de debito es nuestro....
      if  nvl(to_number(vp_cta_debito),0) != 0 then
          vp_cod_respuesta := vr_aprobado;
        -- Verifica si el Cliente está inhibido y la causa es por Demanda Judicial --CROCLIJUD-5
          v_cod_persona := fug_obt_cli_principal(vp_cta_debito);
         if fug_obt_inhibicion(fug_obt_pardinamico('COD_CAU_DEM_JUDICIAL'),v_cod_persona,vp_cta_debito) Then
           vp_cod_respuesta := vr_no_aprobado;
         end If;
          -- Verifica si el Cliente o la Cta. tiene inhibición que no permita realizar débito BSEVOCORE-147
          v_cod_persona :=fug_obt_cli_principal(vp_cta_debito);
          v_afe_debito  := fug_obt_val_parcausal('AFE_DEB_CUENTA',v_cod_persona, vp_cta_debito);
          if nvl(v_afe_debito,'N') = 'S' then
           vp_cod_respuesta := vr_no_aprobado;
         end If;

          -- Obtiene los datos principales de la cuenta
          lp_dat_cta(vp_cta_debito, v_mod_cta_deb, v_mad_cta_deb, v_ofi_cta_deb, v_mon_cta_deb, v_ind_cta_deb_tra);
          /* tys: si la moneda es distinta convierte el monto
          -- Debe verificar el monto de la operacion
          If v_mon_cta_deb != v_cod_moneda then
             -- Se responde que la cuenta no existe...
             vp_cod_respuesta := vr_cta_inexistente;
          End if;*/
          if vp_cod_respuesta = vr_aprobado then
             --WA:31/07/2014 Se ajusta inferior para igualar a funcionamiento anterior
             if v_mad_cta_deb not in (31,41,42,48,46,49) and v_ind_rub_debito = 'N' Then -- Ahorro a la Vista/ Cta. Corrientes
                vp_cod_respuesta := vr_no_aprobado;
             end if;
          End if;

          begin
              select 'S'
                into v_exi_boc_cobro
                from ge_cta_boc_cobro
               where nro_cuenta = vp_cta_debito
                 and nvl(activo, 'N') = 'S';
            exception
              when others then
                 v_exi_boc_cobro := 'N';
            end;

            if nvl(v_exi_boc_cobro, 'N') = 'S' then
               begin
                 select sum(monto)
                   into v_tot_sal_pen
                   from ge_mov_inf_cobranzas
                  where nro_cta_debito = vp_cta_debito
                    and liberado = 'N'
                    and reversado = 'N';
                exception
                  when others then
                     v_tot_sal_pen :=0;
                end;
             else
               v_tot_sal_pen := 0;
             end if;
          /* ramg: se anulo porque ahora se cobra en batch
          --Se cobra cargos por la operacion si corresponde
          If v_clt_deb_nuestro = 'S' and
             (v_mad_cta_deb = 31 or (v_mad_cta_deb = 41 and v_cod_ent_sueldo is not null)) and
             lf_es_sponsor(vp_cta_debito,'CTA') = 'N' then -- Excluir cuenta de sponsor para optimizar - TYS 26-12-07
            prg_obt_car_extraccion (vp_cta_debito,
                                    V_COD_TAS_CARGO,
                                    V_VAL_TAS_CARGO,
                                    V_VAL_CARGO,
                                    V_COD_TRA_IMPUESTO,
                                    V_COD_TAS_IMPUESTO,
                                    V_VAL_TAS_IMPUESTO,
                                    V_VAL_IMPUESTO);
          --
          End if;
          v_cargos := nvl(v_val_cargo,0) + nvl(v_val_impuesto,0);
          */
          v_val_cargo := 0;
          v_val_impuesto := 0;
          v_cargos := 0;
          -- ramg: las 3 lineas de arriba se agregaron
          ---
          ---
          if v_ind_cta_deb_tra = 'S' then
             v_tot_mov_dia := fuc_obt_sal_act_cta_tra(vp_cta_debito,'N');
             v_sal_disponible := nvl(pag_cta.FU_SAL_DISPONIBLE,0) + nvl(v_tot_mov_dia, 0) - (nvl(v_imp_debito,0) + nvl(v_cargos,0));
          else
            --Validacion de saldo pendiente por Bocas de Cobro
             v_sal_disponible := nvl(pag_cta.FU_SAL_DISPONIBLE,0) - (nvl(v_imp_debito,0) + nvl(v_cargos,0)) - nvl(v_tot_sal_pen, 0);
          end if;
          --Si la Cuenta no tiene Disponible se verifica el Disponible de la Cuenta Combinada
          if v_sal_disponible < 0 and vp_cod_respuesta = vr_aprobado then
            v_sal_disponible := nvl(pag_cta.g_ctas.SAL_DIS_COMBINADA,0) - (nvl(v_imp_debito,0) + nvl(v_cargos,0))- nvl(v_tot_sal_pen, 0);
          end if;
          --Si aun no tiene disponible se verifica el Disponible de las dos cuentas (CTACTE + AV = FU_SAL_DIS_COMBINADA)
          if v_sal_disponible < 0 and vp_cod_respuesta = vr_aprobado then
            if v_ind_cta_deb_tra = 'S' then
              v_tot_mov_dia := fuc_obt_sal_act_cta_tra(vp_cta_debito,'N');
              v_sal_disponible := nvl(pag_cta.FU_SAL_DIS_COMBINADA,0) + nvl(v_tot_mov_dia, 0) - (nvl(v_imp_debito,0) + nvl(v_cargos,0));
            else
              v_sal_disponible := nvl(pag_cta.FU_SAL_DIS_COMBINADA,0) - (nvl(v_imp_debito,0) + nvl(v_cargos,0))- nvl(v_tot_sal_pen, 0);
            end if;
          end if;
          --v_sal_disponible := nvl(pag_cta.FU_SAL_DIS_COMBINADA,0) - (nvl(v_imp_debito,0) + nvl(v_cargos,0));
          v_sal_contable   := nvl(pag_cta.g_ctas.sal_actual,0) - (nvl(v_imp_debito,0) + nvl(v_cargos,0)) - nvl(v_tot_sal_pen, 0);
          if v_sal_disponible < 0 and vp_cod_respuesta = vr_aprobado and
             --WA:31/07/2014 Se ajusta inferior para igualar a funcionamiento anterior
             v_mad_cta_deb not in (42, 48, 46,49)  and v_ind_rub_debito = 'N' then
             If v_mad_cta_deb = 41 then
                -- Si es Cuenta Corriente debe verificar si no tiene acuerdo de Sobregiro.
                --If  v_acu_sobregiro = 'S' then
                   -- Debe buscar el monto del acuerdo para verificar nuevamente
                   v_mto_acuerdo :=  PAG_CTA.FU_OBT_LIN_SOBREGIRO(vp_cta_debito,v_fec_proceso);
                   -- Para cuentas de plan sueldo no dar linea de sobregiro en el dia de cobro de sueldo TYS 14-03-08
                   if v_cod_ent_sueldo is not null and lf_hoy_cobro(vp_cta_debito, v_cod_ent_sueldo) = 'S' then
                     v_mto_acuerdo := 0;
                   end if;
                   If nvl(v_mto_acuerdo,0) + nvl(v_sal_disponible,0) < 0 then
                      -- Sigue siendo insuficiente su acuerdo...
                      if nvl(v_exi_boc_cobro, 'N') = 'S' then
                         vp_cod_respuesta := vr_exe_mto_limite;
                      else
                         vp_cod_respuesta := vr_sal_insuficiente; -- No tiene saldo
                      end if;
                   Else
                     vp_cod_respuesta := vr_aprobado;
                   End if;
                --Else
                   -- Si no es Cta Corriente debe responder Saldo Insuficiente...
                --   vp_cod_respuesta := vr_sal_insuficiente; -- No tiene saldo
                --End if;
             Else
               -- Si no es Cta Corriente debe responder Saldo Insuficiente...
               vp_cod_respuesta := vr_sal_insuficiente; -- No tiene saldo
             End if;
          end if;
          --WA:31/07/2014 Se ajusta inferior para igualar a funcionamiento anterior
          If v_mad_cta_deb in (42,48,46,49) or v_ind_rub_debito = 'S' then
             v_sal_disponible := 0;
             v_sal_contable   := 0;
          End if;
          if vp_cod_respuesta <> vr_aprobado then
             -- extraccion rechazada, debe mostrar el saldo sin el debito
             v_sal_disponible := nvl(pag_cta.FU_SAL_DIS_COMBINADA,0);
             v_sal_contable   := nvl(pag_cta.g_ctas.sal_actual,0);
          end if;
          -- Carga la respuesta --
          vp_sal_disponible := lpad(trim(to_char(abs(v_sal_disponible * 100))), 15, '0');
          vi_sal_disponible := v_sal_disponible;
          if v_sal_disponible < 0 Then
             vp_sig_disponible := '-';
          end if;
          vp_sal_contable := lpad(trim(to_char(abs(v_sal_contable * 100))), 15, '0');
          vi_sal_contable := v_sal_contable;
          if v_sal_contable < 0 Then
             vp_sig_contable := '-';
          end if;
      End if;
      -- Hace las verificaciones si el clte de credito es nuestro....
      If  nvl(to_number(vp_cta_credito),0) != 0 and vp_cod_respuesta = vr_aprobado Then
          -- Obtiene los datos de la cuenta de credito...
          If vp_cta_credito is not null then
            lp_dat_cta(vp_cta_credito, v_mod_cta_cre, v_mad_cta_cre, v_ofi_cta_cre, v_mon_cta_cre, v_ind_cta_cre_tra);
            pag_cta.PR_OBT_CUENTA(vp_cta_credito);
            g_cod_error := pag_cta.G_COD_ERROR;
          Else
            v_mon_cta_cre := v_cod_moneda;
            v_mod_cta_cre := v_mod_cta_deb;
            v_mad_cta_cre := v_mad_cta_deb;
            v_ofi_cta_cre := v_ofi_origen;
          End if;
          If v_mon_cta_cre != v_cod_moneda and vp_cod_respuesta = vr_aprobado then
             -- Se responde que la cuenta no existe...
             vp_cod_respuesta := vr_cta_inexistente;
          End if;
          v_est_cta_cre := pag_cta.FU_OBT_EST_CUENTA;
          --WA:31/07/2014 Se ajusta inferior para igualar a funcionamiento anterior
          if (v_est_cta_cre not in ('N', 'S', 'I') or v_mad_cta_cre not in (31,41,42,48,46,49)) and vp_cod_respuesta = vr_aprobado Then -- No es normal o con bloqueo de saldo
             vp_cod_respuesta := vr_no_aprobado; -- Transaccion no aprobada
          end if;
      End If;
   End lp_ver_operacion_05;
   --
   procedure lp_ver_operacion_06 is
     v_sal_disponible ah_cta_vistas.sal_total%type;
     v_sal_contable   ah_cta_vistas.sal_total%type;
     v_cantidad       number(2) := 0;
     v_monto varchar2(15);
     v_saldo varchar2(15);
     v_sal_act number(18,2);
     -- Extracto --
     Cursor c_movim is
      SELECT m.fecha, m.fec_valor, m.hora, m.nro_cuenta,
             m.nro_documento, m.cod_mod_padre, m.cod_mad_padre, m.cod_tra_padre,
             DECODE(t.cod_transaccion, 515, 'C', 560, 'C', t.tipo) tipo,
             decode(t.cod_transaccion, 515, m.monto, 560, m.monto, decode(t.tipo, 'D', m.monto*-1, m.monto)) monto,
             t.abreviatura,
               (DECODE(t.cod_transaccion, 515, 0, 560, 0,
                    decode(t.TIPO,'D',NVL(m.monto,0),0))) Debito,
               (DECODE(t.cod_transaccion, 515, NVL(m.monto,0), 560, NVL(m.monto,0),
                    decode(t.TIPO,'C',NVL(m.monto,0),0))) Credito
        FROM GE_TRANSACCIONES t,
             gv_movimientos m
       WHERE m.NRO_CUENTA = vp_cta_debito
         AND m.FECHA > v_fec_proceso - 7
         AND m.REVERSADO = 'N'
         AND m.ESTADO = 'N'
         AND m.COD_MODULO      = t.COD_MODULO
         AND m.COD_MODALIDAD   = t.COD_MODALIDAD
         AND m.COD_TRANSACCION = t.COD_TRANSACCION
         AND t.VE_CLIENTE      = 'S'
         AND t.TIPO            IN ('C','D')
     Order by m.fecha desc, m.hora desc;
      --
   Begin
      vp_cod_respuesta := vr_aprobado;
      -- Obtiene los datos principales de la cuenta
      lp_dat_cta(vp_cta_debito, v_mod_cta_deb, v_mad_cta_deb, v_ofi_cta_deb, v_mon_cta_deb, v_ind_cta_deb_tra);
      If lf_es_sponsor(vp_cta_debito,'CTA') = 'S' or to_number(vp_bco_debito) <> v_cod_entidad Then
         v_sal_disponible := 0;
         v_sal_contable   := 0;
         vp_sal_disponible := lpad(trim(to_char(abs(v_sal_disponible * 100))), 15, '0');
         vp_sal_contable   := lpad(trim(to_char(abs(v_sal_contable * 100))), 15, '0');
         vi_sal_disponible := v_sal_disponible;
         vi_sal_contable   := v_sal_contable;
         vp_extractos      := '';
      Else
        -- Debe verificar el monto de la operacion
        v_sal_disponible := nvl(pag_cta.FU_SAL_DIS_COMBINADA,0) - nvl(v_imp_debito,0);
        v_sal_contable   := nvl(pag_cta.g_ctas.sal_actual,0) - nvl(v_imp_debito,0);
        --No debe verificar el monto p/ consultas de Extractos 04/01/2010
        /*
        if v_sal_disponible < 0 and vp_cod_respuesta = vr_aprobado and
           v_mad_cta_deb not in (42,48,46)  and v_ind_rub_debito = 'N' then
           vp_cod_respuesta := vr_sal_insuficiente; -- No tiene saldo
        end if;
        */
        -- Carga la respuesta --
        vp_sal_disponible := lpad(trim(to_char(abs(v_sal_disponible * 100))), 15, '0');
        vi_sal_disponible := v_sal_disponible;
        if v_sal_disponible < 0 Then
           vp_sig_disponible := '-';
           vp_sal_disponible := lpad('0', 15, '0');
        end if;
        vp_sal_contable := lpad(trim(to_char(abs(v_sal_contable * 100))), 15, '0');
        vi_sal_contable := v_sal_contable;
        if v_sal_contable < 0 Then
           vp_sig_contable := '-';
           vp_sal_contable := lpad('0', 15, '0');
        end if;
        vp_extractos := '';
        v_sal_act := v_sal_disponible;
        For r_movim in c_movim loop
            If v_cantidad < 10 Then
               v_cantidad := v_cantidad + 1;
               If r_movim.monto < 0 then
                  v_monto := /*'-'||*/lpad(r_movim.monto*10, 14, '0')||'}';
               else
                  v_monto := /*'+'||*/lpad(r_movim.monto*100, 15, '0');
               end if;
               If v_sal_act < 0 then
                  v_saldo := /*'-'||*/lpad(v_sal_act*10, 14, '0')||'}';
               else
                  v_saldo := /*'+'||*/lpad(v_sal_act*100, 15, '0');
               end if;
               v_sal_act := v_sal_act + r_movim.monto;
               vp_extractos := vp_extractos ||
               ---
                               lpad(NVL(r_movim.nro_documento, '0'), 8, '0')||
                               trim(to_char(r_movim.fecha, 'DDMM'))||
                               v_monto||
                               v_saldo||
                               rpad(NVL(r_movim.abreviatura, ' '), 9,' ')
                               ;
            Else
               exit;
            End If;
        End Loop;
        If v_cantidad > 0 then
        vp_can_extractos := '001';
        End if;
        vp_extractos := rpad(lpad(trim(to_char(v_cantidad)), 2, '0')||
                        vp_extractos, 512, '0');
      End If;
   End lp_ver_operacion_06;
   --
   procedure lp_ver_operacion_99 is
      v_sal_disponible ah_cta_vistas.sal_total%type;
      v_sal_contable   ah_cta_vistas.sal_total%type;
   Begin
      -- Un extorno no se puede desaprobar...
      vp_cod_respuesta := vr_aprobado; -- Aprobado
      -- Cambia el signo del importe...
      v_importe := v_importe * -1;
      -- tys: montos de debitos y creditos
      v_imp_debito  := v_imp_debito * -1;
      v_imp_credito := v_imp_credito * -1;
      v_imp_comision := v_imp_comision * -1;
      -- fin tys

      If v_clt_deb_nuestro = 'S' Then
         -- Obtiene los datos principales de la cuenta
         lp_dat_cta(vp_cta_debito, v_mod_cta_deb, v_mad_cta_deb, v_ofi_cta_deb, v_mon_cta_deb, v_ind_cta_deb_tra);

         v_sal_disponible := nvl(pag_cta.FU_SAL_DIS_COMBINADA,0) - nvl(v_imp_debito,0);
         v_sal_contable   := nvl(pag_cta.g_ctas.sal_actual,0) - nvl(v_imp_debito,0);

          vp_sal_disponible := lpad(trim(to_char(abs(v_sal_disponible * 100))), 15, '0');
          vi_sal_disponible := v_sal_disponible;
          if v_sal_disponible < 0 Then
             vp_sig_disponible := '-';
          end if;
          vp_sal_contable := lpad(trim(to_char(abs(v_sal_contable * 100))), 15, '0');
          vi_sal_contable := v_sal_contable;
          if v_sal_contable < 0 Then
             vp_sig_contable := '-';
          end if;
      Else
          vp_sal_disponible := lpad('0', 15, '0');
          vp_sal_contable   := lpad('0', 15, '0');
          vi_sal_disponible := 0;
          vi_sal_contable   := 0;
      End If;

      --If vp_cta_credito is not null then
      if nvl(to_number(vp_cta_credito),0) != 0 then -- MDPMATNT-1 - Mensajería en ATM sobre comisiones por transacciones -- CN: 03/2016 --
         lp_dat_cta(vp_cta_credito, v_mod_cta_cre, v_mad_cta_cre, v_ofi_cta_cre, v_mon_cta_cre, v_ind_cta_cre_tra);
      end if;
   End lp_ver_operacion_99;
   ------------------
   --- Procesos... --
   ------------------
   procedure lp_pro_operacion_00 is
      -- Compra en Pos --
      v_ope varchar2(15); -- Billetera Zimple / Operaciones sin tarjetas -- CN: 08/2016 --
   Begin
      v_cod_tra_padre := 380;
      if to_number(vp_operacion) = 0 then -- Compra en POS
         -- Billetera Zimple / Operaciones sin tarjetas -- CN: 08/2016 --
         if to_number(vp_bco_debito) = v_cod_entidad and nvl(vp_med_pago,'02') = '04' and v_tip_servicio = 'PIC' then
             v_cod_tra_padre := 488;
         ELSE
           if vp_tip_ope is not null then
             v_ope := vp_tip_ope||vp_operacion;
             v_cod_tra_padre := lf_obt_tra_padre(C_DOM_TIP_OPE,v_ope);
             v_cod_tra_padre := nvl(v_cod_tra_padre,380);
           end if;
         END IF;
         --
      elsif to_number(vp_operacion) = 1 then
         v_cod_tra_padre := 381;
      elsif to_number(vp_operacion) = 72 then -- infonet cobranzas
         -- CANOSTDD-2 -- 01/2017 -- Pago Extracto/Servicios --
         v_cod_tra_padre := lf_obt_tra_padre(C_DOM_MED_PAG,vp_med_pago);
         v_cod_tra_padre := nvl(v_cod_tra_padre,227);
      elsif to_number(vp_operacion) = 41 then -- transf interbancaria
         v_cod_tra_padre := 228;
         -- Billetera Zimple / Operaciones sin tarjetas -- CN: 08/2016 --
         if vp_tip_ope is not null then
           v_ope := vp_tip_ope||vp_operacion;
           v_cod_tra_padre := lf_obt_tra_padre(C_DOM_TIP_OPE,v_ope);
           v_cod_tra_padre := nvl(v_cod_tra_padre,228);
         end if;
         --
      elsif to_number(vp_operacion) = 50 then -- compra en pos extranjero
         v_cod_tra_padre := 374;
      elsif to_number(vp_operacion) = 54 then -- transf saldo extranjero
         v_cod_tra_padre := 377;
      elsif to_number(vp_operacion) = 51 then -- adelanto de efectivo
         v_cod_tra_padre := 387;
      end if;

      if nvl(to_number(vp_cta_debito),0) != 0 or v_ind_rub_debito = 'S' then
          -- Carga los parametros de movimientos de Debito
         r_gmovi.cod_modulo      := v_mod_cta_deb;
         r_gmovi.cod_modalidad   := v_mad_cta_deb;
         r_gmovi.cod_oficina     := nvl(v_ofi_cta_deb,v_ofi_origen);
         r_gmovi.nro_cuenta      := vp_cta_debito;
         r_gmovi.cod_moneda      := nvl(v_mon_cta_deb, v_cod_moneda);
         r_gmovi.cod_usuario     := v_cod_usuario;
         r_gmovi.hora            := v_hora;
         r_gmovi.fecha           := v_fec_proceso;
         r_gmovi.nro_secuencia   := v_nro_secuencia;
         --
         r_gmovi.fec_valor       := v_fec_valor;
         r_gmovi.cod_tra_padre   := v_cod_tra_padre;
         r_gmovi.cod_mod_padre   := v_cod_modulo;
         r_gmovi.cod_mad_padre   := v_cod_modalidad;
         If v_ind_rub_debito = 'S' then
           r_gmovi.cod_transaccion := v_tra_con_debito;
           r_gmovi.tip_mov_rubro   := 'D';
           r_gmovi.cod_rubro       := v_cod_rub_debito;
         Else
           If v_es_banco = 'S' then
             r_gmovi.cod_transaccion := 503;
             If lf_exi_banco(vp_bco_credito) = 'S' then
                --WA:06/08/2014 si es financiera se deja Nulo el Cod_banco
                -- r_gmovi.cod_banco       := vp_bco_credito;
                if lf_exi_financiera(vp_bco_credito) = 'S' then
                   r_gmovi.cod_banco       := null;
                else
                   r_gmovi.cod_banco       := vp_bco_credito;
                end if;
             End if;
           Else
             r_gmovi.cod_transaccion := 577;
           End if;
         End if;
         r_gmovi.monto           := v_imp_debito;
         r_gmovi.nro_documento   := v_nro_documento;
         r_gmovi.nro_documento2  := v_nro_documento2;
         r_gmovi.referencia      := vp_cta_credito;
         r_gmovi.nro_documento3  := v_nro_documento3;

         r_gmovi.cod_tasa        := null;
         r_gmovi.val_tasa        := null;
         -- tys: cotizacion de cambio
         r_gmovi.cotizacion      := v_cot_debito;
         r_gmovi.mto_equ_local   := round(r_gmovi.monto * r_gmovi.cotizacion);
         --
         r_gmovi.cod_ofi_origen  := v_ofi_origen;
         r_gmovi.emi_aviso       := 'N';
         r_gmovi.concepto        := v_concepto;
         r_gmovi.estado          := 'N';
         r_gmovi.reversado       := 'N';
         r_gmovi.cod_persona     := v_cod_persona;
/*         if r_gmovi.cod_modulo = 7 then
            r_gmovi.cod_tip_ope_cambio := v_cod_tip_ope_cambio;
            r_gmovi.cod_bco_central := v_cod_bco_central;
         end if;   */
         --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
         lp_ins_ge_movimiento;
/*         r_gmovi.cod_tip_ope_cambio := null;
         r_gmovi.cod_bco_central := null;     */
         r_gmovi.tip_mov_rubro   := null;
         r_gmovi.cod_rubro       := null;
         -- cuenta combinada ----------------------------------
         if nvl(v_ind_cta_deb_tra, 'N') = 'N' then
           if v_nro_cta_combinada is not null and v_imp_debito > v_sal_dis_debito then
              v_nro_secuencia := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              IF v_sal_dis_debito < 0 then
                 r_gmovi.monto           := v_imp_debito;
              else
                 r_gmovi.monto           := v_imp_debito - v_sal_dis_debito;
              end if;
              r_gmovi.concepto        := 'Transferencia de la Cta '||v_nro_cta_combinada;
              r_gmovi.cod_tra_padre   := 309;
              r_gmovi.cod_transaccion := 602;
              ---
              --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
              lp_ins_ge_movimiento;
              -- acredito el monto que le falta
              lp_upd_cta_debito(v_mod_cta_deb, v_mad_cta_deb, vp_cta_debito, r_gmovi.monto * -1);
           end if;

           lp_upd_cta_debito(v_mod_cta_deb, v_mad_cta_deb, vp_cta_debito, v_imp_debito);
         end if;

         If v_est_cuenta = 'I' Then -- Debo cambiar el estado de la cuenta
            v_nro_secuencia := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto := null;
            r_gmovi.est_cuenta := 'N';
            r_gmovi.cod_tra_padre   := 425;
            r_gmovi.cod_transaccion := 425;
            --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
            lp_ins_ge_movimiento;
         End If;

         if nvl(v_ind_cta_deb_tra, 'N') = 'N' then
           if v_nro_cta_combinada is not null and v_imp_debito > v_sal_dis_debito then
              IF v_sal_dis_debito < 0 then
                 r_gmovi.monto           := v_imp_debito;
              else
                 r_gmovi.monto           := v_imp_debito - v_sal_dis_debito;
              end if;
              pag_cta.PR_OBT_CUENTA(v_nro_cta_combinada);
              v_nro_secuencia := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.concepto        := 'Transferencia a la Cta '||vp_cta_debito;
              r_gmovi.cod_tra_padre   := 309;
              r_gmovi.cod_transaccion := 503;
              r_gmovi.cod_modulo      := pag_cta.g_ctas.cod_modulo;
              r_gmovi.cod_modalidad   := pag_cta.g_ctas.cod_modalidad;
              r_gmovi.cod_oficina     := pag_cta.g_ctas.cod_oficina;
              r_gmovi.nro_cuenta      := pag_cta.g_ctas.nro_cuenta;
              ---
              --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
              lp_ins_ge_movimiento;

              --DYDMR-2055: ITGF - Saldo de Cuenta 0102194039 SC 17595
              lp_upd_cta_debito(pag_cta.g_ctas.cod_modulo,pag_cta.g_ctas.cod_modalidad,
                                pag_cta.g_ctas.nro_cuenta, r_gmovi.monto);

              --FB AP 927 Actualizo el estado de la cta.comb.
              v_est_cta_comb := pag_cta.FU_OBT_EST_CUENTA;
              IF v_est_cta_comb = 'I' AND g_cod_error = 00 then
                  v_nro_secuencia := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.monto := null;
                  r_gmovi.est_cuenta := 'N';
                  r_gmovi.cod_tra_padre   := 425;
                  r_gmovi.cod_transaccion := 425;
                  --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
                  lp_ins_ge_movimiento;
              END IF;
              --
             /* lp_upd_cta_debito(pag_cta.g_ctas.cod_modulo,pag_cta.g_ctas.cod_modalidad,
                                pag_cta.g_ctas.nro_cuenta, r_gmovi.monto);*/
           end if;
         end if;
         ------------------------------------------------------
/*         -- tys: agregado para envio de mensaje
         if v_cod_tra_padre = 380 then
           pag_sms.pr_pro_servicio_013(p_nro_cuenta    => vp_cta_debito,
                                       p_monto         => v_imp_debito,
                                       p_nro_documento => v_nro_documento,
                                       p_concepto      => 'Compras en POS');
         end if;
         -- tys: fin agregado*/
      End if;
      if v_es_banco = 'S' then
         -- Carga los parametros de movimientos de Credito
         v_nro_secuencia := v_nro_secuencia + 1;
         r_gmovi.cod_modulo      := v_mod_cta_cre;
         r_gmovi.cod_modalidad   := v_mad_cta_cre;
         r_gmovi.cod_oficina     := nvl(v_ofi_cta_cre,v_ofi_origen);
         r_gmovi.nro_cuenta      := vp_cta_credito;
         r_gmovi.cod_moneda      := nvl(v_mon_cta_cre, v_cod_moneda);
         r_gmovi.cod_usuario     := v_cod_usuario;
         r_gmovi.hora            := v_hora;
         r_gmovi.fecha           := v_fec_proceso;
         r_gmovi.nro_secuencia   := v_nro_secuencia;
         --
         r_gmovi.fec_valor       := v_fec_valor;
         r_gmovi.cod_tra_padre   := v_cod_tra_padre;
         r_gmovi.cod_mod_padre   := v_cod_modulo;
         r_gmovi.cod_mad_padre   := v_cod_modalidad;
         r_gmovi.cod_transaccion := 602;
         If lf_exi_banco(vp_bco_credito) = 'S' then
            --WA:06/08/2014 si es financiera se deja Nulo el Cod_banco
            --r_gmovi.cod_banco       := vp_bco_credito;
            if lf_exi_financiera(vp_bco_credito) = 'S' then
               r_gmovi.cod_banco       := null;
            else
               r_gmovi.cod_banco       := vp_bco_credito;
            end if;
        End if;
         If v_ind_rub_credito = 'S' then
           r_gmovi.cod_transaccion := v_tra_con_credito;
           if v_cod_rub_credito is not null then
             r_gmovi.tip_mov_rubro   := 'C';
             r_gmovi.cod_rubro       := v_cod_rub_credito;
           end if;
           r_gmovi.cod_modulo      := v_mod_con_credito;
           r_gmovi.cod_modalidad   := v_mad_con_credito;
           if v_nro_cta_tarjeta is not null then
              r_gmovi.cod_oficina     := v_ofi_con_credito;
              r_gmovi.nro_cuenta      := v_nro_cta_tarjeta;
           end if;
         end if;
         if nvl(v_ind_obt_comision, 'N') = 'S' then
           v_imp_credito := v_imp_credito - v_imp_comision;
           r_gmovi.monto := v_imp_credito;
         else
           r_gmovi.monto := v_imp_credito;
         end if;
         r_gmovi.nro_documento   := v_nro_documento;
         r_gmovi.nro_documento2  := v_nro_documento2;
         r_gmovi.nro_documento3  := v_nro_documento3;
         r_gmovi.cod_tasa        := null;
         r_gmovi.val_tasa        := null;
         -- tys: cotizacion de cambio
         r_gmovi.cotizacion      := v_cot_credito;
         r_gmovi.mto_equ_local   := round(r_gmovi.monto * r_gmovi.cotizacion);
         --
         r_gmovi.cod_ofi_origen  := v_ofi_origen;
         r_gmovi.emi_aviso       := 'N';
         r_gmovi.concepto        := v_concepto;
         r_gmovi.estado          := 'N';
         r_gmovi.reversado       := 'N';
         r_gmovi.cod_persona     := v_cod_persona;
/*         if r_gmovi.cod_modulo = 7 then
            r_gmovi.cod_tip_ope_cambio := v_cod_tip_ope_cambio;
            r_gmovi.cod_bco_central := v_cod_bco_central;
         end if;   */
         --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
         lp_ins_ge_movimiento;

         if nvl(v_ind_cta_cre_tra, 'N') = 'N' then
           lp_upd_cta_credito;
         end if;

         If v_est_cta_cre = 'I' Then -- Debo cambiar el estado de la cuenta
            v_nro_secuencia := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto := null;
            r_gmovi.est_cuenta := 'N';
            r_gmovi.cod_tra_padre   := 425;
            r_gmovi.cod_transaccion := 425;
            --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
            lp_ins_ge_movimiento;
         End If;

         -- Se realiza el crédito por la comisión a bancard.
         IF nvl(v_ind_obt_comision, 'N') = 'S' then
            v_nro_secuencia := v_nro_secuencia + 1;
            r_gmovi.cod_modulo      := v_cod_mod_com_ban;
            r_gmovi.cod_modalidad   := v_cod_mad_com_ban;
            r_gmovi.cod_oficina     := nvl(v_ofi_cta_com,v_ofi_origen);
            r_gmovi.nro_cuenta      := v_cta_com_bancard;
            r_gmovi.cod_moneda      := nvl(v_mon_cta_cre, v_cod_moneda);
            r_gmovi.cod_usuario     := v_cod_usuario;
            r_gmovi.hora            := v_hora;
            r_gmovi.fecha           := v_fec_proceso;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            --
            r_gmovi.fec_valor       := v_fec_valor;
            r_gmovi.cod_tra_padre   := v_cod_tra_padre;
            r_gmovi.cod_mod_padre   := v_cod_modulo;
            r_gmovi.cod_mad_padre   := v_cod_modalidad;
            r_gmovi.cod_transaccion := 602;
            r_gmovi.monto           := v_imp_comision;

            r_gmovi.nro_documento   := v_nro_documento;
            r_gmovi.nro_documento2  := v_nro_documento2;
            r_gmovi.nro_documento3  := v_nro_documento3;

            r_gmovi.cod_tasa        := null;
            r_gmovi.val_tasa        := null;
            -- tys: cotizacion de cambio
            r_gmovi.cotizacion      := v_cot_credito;
            --
            r_gmovi.cod_ofi_origen  := v_ofi_origen;
            r_gmovi.emi_aviso       := 'N';
            r_gmovi.concepto        := v_con_mov_com_bancard;
            r_gmovi.estado          := 'N';
            r_gmovi.reversado       := 'N';
            r_gmovi.cod_persona     := 149064;
            r_gmovi.tip_mov_rubro   := null;
            r_gmovi.cod_rubro       := null;

            lp_ins_ge_movimiento;
            --actualización de saldo cuenta bancard.
            if nvl(v_ind_cta_com_tra, 'N') = 'N' then
              if v_horario = 'D' Then
                 -- Horario normal --
                 If v_cod_mad_com_ban = 31 then
                   update ah_cta_vistas
                      set sal_total = nvl(sal_total, 0) + v_imp_comision,
                          estado = decode(estado, 'I', 'N', estado)
                    where nro_cuenta = v_cta_com_bancard;
                 elsif v_cod_mad_com_ban = 41 then
                   update cc_cta_corrientes
                      set sal_total = nvl(sal_total, 0) + v_imp_comision,
                          estado = decode(estado, 'I', 'N', estado)
                    where nro_cuenta = v_cta_com_bancard;
                 End if;
              elsif v_horario = 'T' Then
               -- A la Tarde --
                 If v_cod_mad_com_ban = 31 then
                   update ah_cta_vistas
                      set mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + v_imp_comision
                    where nro_cuenta = v_cta_com_bancard;
                 elsif v_cod_mad_com_ban = 41 then
                   update cc_cta_corrientes
                      set mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + v_imp_comision
                    where nro_cuenta = v_cta_com_bancard;
                 End if;
              else
                 -- A la Noche o despues del Cierre --
                 If v_cod_mad_com_ban = 31 then
                   update ah_cta_vistas_noc
                      set mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + v_imp_comision
                    where nro_cuenta = v_cta_com_bancard;
                 elsif v_cod_mad_com_ban = 41 then
                   update cc_cta_corrientes_noc
                      set mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + v_imp_comision
                    where nro_cuenta = v_cta_com_bancard;
                 end if;
             end if;
           end if;
           If v_est_cta_com_ban = 'I' Then -- Debo cambiar el estado de la cuenta
              v_nro_secuencia := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.monto := null;
              r_gmovi.est_cuenta := 'N';
              r_gmovi.cod_tra_padre   := 425;
              r_gmovi.cod_transaccion := 425;
              --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
              lp_ins_ge_movimiento;
           End If;
         end if;
      End if;

      if to_number(vp_operacion) = 1 then
        if vp_extorno <> 99 then
          declare
            v_nro_tra_compra ge_ope_ext_efe_pos.nro_tra_compra%type;
            v_mto_compra ge_ope_ext_efe_pos.mto_compra%type;
          begin
            if v_es_nocturno = 'N' then
              begin
                select max(nro_documento3)
                  into v_nro_tra_compra
                  from ge_movimientos
                 where nro_cuenta = vp_cta_debito
                   and cod_mod_padre = v_cod_modulo
                   and cod_mad_padre = v_cod_modalidad
                   and cod_tra_padre = 380
                   and cod_usuario like 'ATM%'
                   and reversado <> 'S'; -- operaciones compras en pos
               exception
                 when others then
                    v_nro_tra_compra := null;
               end;
               if v_nro_tra_compra is not null then
                  select monto
                    into v_mto_compra
                     from ge_movimientos
                    where nro_cuenta = vp_cta_debito
                      and cod_mod_padre = v_cod_modulo
                      and cod_mad_padre = v_cod_modalidad
                      and cod_tra_padre = 380
                      and cod_usuario like 'ATM%'
                      and nro_documento3 = v_nro_tra_compra
                      and reversado <> 'S';
                end if;
             else
                begin
                select max(nro_documento3)
                  into v_nro_tra_compra
                  from ge_movimientos_noc
                 where nro_cuenta = vp_cta_debito
                   and cod_mod_padre = v_cod_modulo
                   and cod_mad_padre = v_cod_modalidad
                   and cod_tra_padre = 380
                   and cod_usuario like 'ATM%'
                   and reversado <> 'S'; -- operaciones compras en pos
               exception
                 when others then
                    v_nro_tra_compra := null;
               end;
               if v_nro_tra_compra is not null then
                  select monto
                    into v_mto_compra
                     from ge_movimientos_noc
                    where nro_cuenta = vp_cta_debito
                      and cod_mod_padre = v_cod_modulo
                      and cod_mad_padre = v_cod_modalidad
                      and cod_tra_padre = 380
                      and cod_usuario like 'ATM%'
                      and nro_documento3 = v_nro_tra_compra
                      and reversado <> 'S';
                end if;
            end if;
            insert into GE_OPE_EXT_EFE_POS(fecha,
                                           fec_valor,
                                           hora,
                                           hor_referencia,
                                           nro_transaccion,
                                           cod_mod_padre, cod_mad_padre, cod_tra_padre,
                                           cod_persona,
                                           nro_cta_cre,
                                           nro_cta_deb,
                                           monto,
                                           cod_moneda,
                                           extornado,
                                           nro_tra_compra,
                                           mto_compra,
                                           negocio)
                                   values (v_fec_proceso,
                                           v_fec_valor,
                                           v_hora,
                                           v_hor_referencia,
                                           v_nro_documento3,
                                           v_cod_modulo, v_cod_modalidad, v_cod_tra_padre,
                                           v_cod_persona,
                                           vp_cta_credito,
                                           vp_cta_debito,
                                           v_imp_debito,
                                           v_cod_moneda,
                                           'N',
                                           v_nro_tra_compra,
                                           v_mto_compra,
                                           vp_negocio);
           exception
             when others then
               raise_application_error(-20000, 'No se puede registra el vuelto.');
           end;
        else
          begin
            update GE_OPE_EXT_EFE_POS
               set extornado = 'S'
             where nro_transaccion = v_nro_documento3;
          exception
            when others then
            raise_application_error(-20000, 'No se puede reversar el vuelto.');
          end;
        end if;
      end if;

   End lp_pro_operacion_00;
   --
   procedure lp_pro_operacion_02 is
      -- Consulta de Saldo --
       v_ope varchar2(15); -- Billetera Zimple / Operaciones sin tarjetas -- CN: 08/2016 --
   Begin
      v_cod_tra_padre := 389;
      if to_number(vp_operacion) = 2 then -- Consulta de Saldo
         -- Billetera Zimple / Operaciones sin tarjetas -- CN: 08/2016 --
         if vp_tip_ope is not null then
           v_ope := vp_tip_ope||vp_operacion;
           v_cod_tra_padre := lf_obt_tra_padre(C_DOM_TIP_OPE,v_ope);
           v_cod_tra_padre := nvl(v_cod_tra_padre,389);
         end if;
         --
      elsif to_number(vp_operacion) = 52 then -- consulta de saldo extranjero
         v_cod_tra_padre := 376;
      end if;
      if v_clt_deb_nuestro = 'S' then
         -- Carga los parametros de movimientos de Debito
         r_gmovi.cod_modulo      := v_mod_cta_deb;
         r_gmovi.cod_modalidad   := v_mad_cta_deb;
         r_gmovi.cod_oficina     := nvl(v_ofi_cta_deb,v_ofi_origen);
         r_gmovi.nro_cuenta      := vp_cta_debito;
         r_gmovi.cod_moneda      := nvl(v_mon_cta_deb, v_cod_moneda) ;
         r_gmovi.cod_usuario     := v_cod_usuario;
         r_gmovi.hora            := v_hora;
         r_gmovi.fecha           := v_fec_proceso;
         r_gmovi.nro_secuencia   := v_nro_secuencia;
         --
         r_gmovi.fec_valor       := v_fec_valor;
         r_gmovi.cod_tra_padre   := v_cod_tra_padre;
         r_gmovi.cod_mod_padre   := v_cod_modulo;
         r_gmovi.cod_mad_padre   := v_cod_modalidad;
         r_gmovi.cod_transaccion := v_cod_tra_padre;
         r_gmovi.monto           := null;
         r_gmovi.nro_documento   := v_nro_documento;
         r_gmovi.nro_documento2  := v_nro_documento2;
         r_gmovi.nro_documento3  := v_nro_documento3;
         If v_es_banco = 'S' then
           If lf_exi_banco(vp_bco_atm) = 'S' then
              --r_gmovi.cod_banco := vp_bco_atm;
               --WA:06/08/2014 si es financiera se deja Nulo el Cod_bando
                if lf_exi_financiera(vp_bco_atm) = 'S' then
                   r_gmovi.cod_banco := null;
                else
                   if vp_bco_aux is not null then
                      r_gmovi.cod_banco := vp_bco_aux;
                   else
                      r_gmovi.cod_banco := vp_bco_atm;
                   end if;
                end if;
           End if;
         End if;
         r_gmovi.cod_tasa        := null;
         r_gmovi.val_tasa        := null;
         r_gmovi.cotizacion      := null;
         r_gmovi.cod_ofi_origen  := v_ofi_origen;
         r_gmovi.emi_aviso       := 'N';
         r_gmovi.concepto        := v_concepto;
         r_gmovi.estado          := 'N';
         r_gmovi.reversado       := 'N';
         r_gmovi.cod_persona     := v_cod_persona;
         --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
         lp_ins_ge_movimiento;
       end if;
   End lp_pro_operacion_02;
   --
   procedure lp_pro_operacion_05 is
     -- Extraccion de Efectivo --
     v_ope varchar2(15); -- Billetera Zimple / Operaciones sin tarjetas -- CN: 08/2016 --
     v_exi_mov_dia varchar2(1) := 'N';
     v_exi_mov_dia_noc varchar2(1) := 'N';
     v_hor_reversion ge_movimientos.hora%type;
     v_usu_reversion ge_movimientos.cod_usuario%type;
   Begin
      if to_number(vp_operacion) = 5 Then -- Extraccion ATM
         v_cod_tra_padre := 382;
         -- Billetera Zimple / Operaciones sin tarjetas -- CN: 08/2016 --
         if vp_tip_ope is not null then
           v_ope := vp_tip_ope||vp_operacion;
           v_cod_tra_padre := lf_obt_tra_padre(C_DOM_TIP_OPE,v_ope);
           v_cod_tra_padre := nvl(v_cod_tra_padre,382);
         end if;
         --
      Elsif to_number(vp_operacion) = 27 Then
         v_cod_tra_padre := 990;
      elsif to_number(vp_operacion) = 55 then -- extraccion en atm extranjero
         v_cod_tra_padre := 375;
      End If;
      if nvl(to_number(vp_cta_debito),0) != 0 OR v_ind_rub_debito = 'S' then
          -- Carga los parametros de movimientos de Debito
         r_gmovi.cod_modulo      := v_mod_cta_deb;
         r_gmovi.cod_modalidad   := v_mad_cta_deb;
         r_gmovi.cod_oficina     := nvl(v_ofi_cta_deb,v_ofi_origen);
         r_gmovi.nro_cuenta      := vp_cta_debito;
         r_gmovi.cod_moneda      := nvl(v_mon_cta_deb, v_cod_moneda);
         r_gmovi.cod_usuario     := v_cod_usuario;
         r_gmovi.hora            := v_hora;
         r_gmovi.fecha           := v_fec_proceso;
         r_gmovi.nro_secuencia   := v_nro_secuencia;
         --
         r_gmovi.fec_valor       := v_fec_valor;
         r_gmovi.cod_tra_padre   := v_cod_tra_padre;
         r_gmovi.cod_mod_padre   := v_cod_modulo;
         r_gmovi.cod_mad_padre   := v_cod_modalidad;
         If v_ind_rub_debito = 'S' then
           r_gmovi.cod_transaccion := v_tra_con_debito;
           r_gmovi.tip_mov_rubro   := 'D';
           r_gmovi.cod_rubro       := v_cod_rub_debito;
         Else
           If v_es_banco = 'S' then
             r_gmovi.cod_transaccion := 503;
             If lf_exi_banco(vp_bco_atm) = 'S' then
                --WA:06/08/2014 si es financiera se deja Nulo el Cod_banco
                if lf_exi_financiera(vp_bco_atm) = 'S' then
                   r_gmovi.cod_banco       := null;
                else
                   if vp_bco_aux is not null then
                      r_gmovi.cod_banco := vp_bco_aux;
                   else
                      r_gmovi.cod_banco := vp_bco_atm;
                   end if;
                end if;
                --r_gmovi.cod_banco := vp_bco_atm;
             End if;
             If r_gmovi.cod_banco is null and lf_exi_banco(vp_bco_credito) = 'S' then
                --WA:06/08/2014 si es financiera se deja Nulo el Cod_banco
                if lf_exi_financiera(vp_bco_credito) = 'S' then
                   r_gmovi.cod_banco       := null;
                else
                   r_gmovi.cod_banco       := vp_bco_credito;
                end if;
                --r_gmovi.cod_banco := vp_bco_credito;
             End if;
           Else
             r_gmovi.cod_transaccion := 577;
           End if;
         End if;
         r_gmovi.monto           := v_imp_debito;
         r_gmovi.nro_documento   := v_nro_documento;
         r_gmovi.nro_documento2  := v_nro_documento2;
         r_gmovi.referencia      := vp_cta_credito;
         r_gmovi.nro_documento3  := v_nro_documento3;

         r_gmovi.cod_tasa        := null;
         r_gmovi.val_tasa        := null;
         -- tys: cotizacion de cambio
         r_gmovi.cotizacion      := v_cot_debito;
         r_gmovi.mto_equ_local   := round(r_gmovi.monto * r_gmovi.cotizacion);
         --
         r_gmovi.cod_ofi_origen  := v_ofi_origen;
         r_gmovi.emi_aviso       := 'N';
         r_gmovi.concepto        := v_concepto;
         r_gmovi.estado          := 'N';
         r_gmovi.reversado       := 'N';
         r_gmovi.cod_persona     := v_cod_persona;

         -- MDPMATNT-1 - Mensajería en ATM sobre comisiones por transacciones -- CN: 04/2016 --
         if to_number(vp_extorno) = 99 Then
             -- Se cambia gv_movimientos
            BEGIN
              begin
                select count(1)
                  into v_rev_can_mov
                  from ge_movimientos
                  where nro_documento3 = v_nro_documento3
                    and nro_documento  = v_nro_documento
                    and nvl(monto,0)   = abs(nvl(v_imp_debito,0))
                    and cod_moneda     = nvl(v_mon_cta_deb, v_cod_moneda)
                    and reversado      = 'N'
                    and estado         = 'N'
                    and substr(cod_usuario,1,3)    = substr(v_cod_usuario,1,3);
               exception
                 when others then
                   v_rev_can_mov := 0;
               end;
               if nvl(v_rev_can_mov, 0) > 0 then
                  v_exi_mov_dia := 'S';
               else
                  begin
                    select count(1)
                      into v_rev_can_mov
                      from ge_movimientos_noc
                     where nro_documento3 = v_nro_documento3
                       and nro_documento  = v_nro_documento
                       and nvl(monto,0)   = abs(nvl(v_imp_debito,0))
                       and cod_moneda     = nvl(v_mon_cta_deb, v_cod_moneda)
                       and reversado      = 'N'
                       and estado         = 'N'
                       and substr(cod_usuario,1,3)    = substr(v_cod_usuario,1,3);
                   exception
                     when others then
                       v_rev_can_mov := 0;
                   end;

                   if nvl(v_rev_can_mov, 0) > 0 then
                      v_exi_mov_dia_noc := 'S';
                   end if;
                 end if;
            END;
            --
            if nvl(v_rev_can_mov,0) > 0 then --DYDMR-7679: Valida que exista el movimiento en ge_movimientos para poder marcar la reversion
              IF v_es_nocturno = 'N' THEN
                IF nvl(v_exi_mov_dia, 'N') = 'S' THEN
                  r_gmovi.reversado         := 'S';
                  r_gmovi.fec_valor         := v_fec_proceso;
                  begin
                    select distinct hora, cod_usuario  -- DYDMR-4536 Ago/2016
                      into v_hor_reversion, v_usu_reversion  -- DYDMR-4536 Ago/2016
                      from ge_movimientos
                     where nro_documento3 = v_nro_documento3
                       and nro_documento  = v_nro_documento
                       and nvl(monto,0)   = abs(nvl(v_imp_debito,0))
                       and cod_moneda     = nvl(v_mon_cta_deb, v_cod_moneda)
                       and reversado      = 'N'
                       and estado         = 'N'
                       and cod_tra_padre <> 309
                       and substr(cod_usuario,1,3)    = substr(v_cod_usuario,1,3)
                       and rownum = 1;
                  exception
                    when others then
                      v_hor_reversion := v_hora;
                      v_usu_reversion := v_cod_usuario;
                  end;
                  r_gmovi.cod_usu_reversion := v_usu_reversion;
                  r_gmovi.hor_reversion     := v_hor_reversion;

                  BEGIN
                     update ge_movimientos a
                        set a.reversado         = 'S',
                            a.cod_usu_reversion = v_cod_usuario,
                            a.hor_reversion     = v_hora,
                            a.fec_valor = v_fec_proceso
                      where nro_documento3 = v_nro_documento3
                        and nro_documento  = v_nro_documento
                        --and nvl(monto,0)   = abs(nvl(v_imp_debito,0))
                        --and cod_moneda     = nvl(v_mon_cta_deb, v_cod_moneda)
                        and reversado      = 'N'
                        and estado         = 'N'
                        and cod_tra_padre <> 309 --DYDMR-3914  06/2016 no se reversa registro transf entre ctas
                        and substr(cod_usuario,1,3)    = substr(v_cod_usuario,1,3);
                    EXCEPTION
                      WHEN OTHERS THEN
                        r_gmovi.reversado         := 'N';
                        r_gmovi.cod_usu_reversion := null;
                        r_gmovi.hor_reversion     := null;
                    END;

                  ELSE
                    r_gmovi.reversado         := 'N';
                    r_gmovi.cod_usu_reversion := null;
                    r_gmovi.hor_reversion     := null;
                  END IF;
                ELSE
                  IF nvl(v_exi_mov_dia_noc, 'N') = 'S' THEN
                    BEGIN
                       r_gmovi.reversado         := 'S';
                       r_gmovi.fec_valor       := v_fec_proceso;
                       begin
                        select distinct hora, cod_usuario  -- DYDMR-4536 Ago/2016
                          into v_hor_reversion, v_usu_reversion  -- DYDMR-4536 Ago/2016
                          from ge_movimientos_noc
                         where nro_documento3 = v_nro_documento3
                           and nro_documento  = v_nro_documento
                           and nvl(monto,0)   = abs(nvl(v_imp_debito,0))
                           and cod_moneda     = nvl(v_mon_cta_deb, v_cod_moneda)
                           and reversado      = 'N'
                           and estado         = 'N'
                           and cod_tra_padre <> 309
                           and substr(cod_usuario,1,3)    = substr(v_cod_usuario,1,3)
                           and rownum = 1;
                       exception
                         when others then
                            v_hor_reversion := v_hora;
                            v_usu_reversion := v_cod_usuario;
                       end;

                       r_gmovi.cod_usu_reversion := v_usu_reversion;
                       r_gmovi.hor_reversion     := v_hor_reversion;

                       update ge_movimientos_noc a
                          set a.reversado         = 'S',
                              a.cod_usu_reversion = v_cod_usuario,
                              a.hor_reversion     = v_hora,
                              a.fec_valor = v_fec_proceso
                        where nro_documento3 = v_nro_documento3
                          and nro_documento  = v_nro_documento
                          --and nvl(monto,0)   = abs(nvl(v_imp_debito,0))
                          --and cod_moneda     = nvl(v_mon_cta_deb, v_cod_moneda)
                          and reversado      = 'N'
                          and estado         = 'N'
                          and cod_tra_padre <> 309 --DYDMR-3914  06/2016 no se reversa registro transf entre ctas
                          and substr(cod_usuario,1,3)    = substr(v_cod_usuario,1,3);
                      EXCEPTION
                        WHEN OTHERS THEN
                          r_gmovi.reversado         := 'N';
                          r_gmovi.cod_usu_reversion := null;
                          r_gmovi.hor_reversion     := null;
                      END;
                  ELSE
                    r_gmovi.reversado         := 'N';
                    r_gmovi.cod_usu_reversion := null;
                    r_gmovi.hor_reversion     := null;
                  end if;
               END IF;
             else
               r_gmovi.reversado         := 'N';
               r_gmovi.cod_usu_reversion := null;
               r_gmovi.hor_reversion     := null;
             end if;             --
         end if;

/*         if r_gmovi.cod_modulo = 7 then
            r_gmovi.cod_tip_ope_cambio := v_cod_tip_ope_cambio;
            r_gmovi.cod_bco_central := v_cod_bco_central;
         end if; */
         --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
         --DYDMR-3914  06/2016 si es extorno y el movimiento tiene mas de dos registros
         --se consulta nro_secuencia original del movimiento
         if nvl(v_rev_can_mov,0) > 2 and to_number(vp_extorno) = 99 then
           lp_obt_nro_secuencia;
         end if;

         lp_ins_ge_movimiento;

         r_gmovi.tip_mov_rubro   := null;
         r_gmovi.cod_rubro       := null;
/*         r_gmovi.cod_tip_ope_cambio := null;
         r_gmovi.cod_bco_central := null; */
         if nvl(v_ind_cta_deb_tra, 'N') = 'N' then
           if v_nro_cta_combinada is not null and v_imp_debito > v_sal_dis_debito then
              v_nro_secuencia := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              IF v_sal_dis_debito < 0 then
                 r_gmovi.monto           := v_imp_debito;
              else
                 r_gmovi.monto           := v_imp_debito - v_sal_dis_debito;
              end if;
              r_gmovi.concepto        := 'Transferencia de la Cta '||v_nro_cta_combinada;
              r_gmovi.cod_tra_padre   := 309;
              r_gmovi.cod_transaccion := 602;
              ---
              --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
              --DYDMR-3914  06/2016 si es extorno y el movimiento tiene mas de dos registros
              --se consulta nro_secuencia original del movimiento
              if nvl(v_rev_can_mov,0) > 2 and to_number(vp_extorno) = 99 then
                lp_obt_nro_secuencia;
              end if;
              lp_ins_ge_movimiento;
              lp_upd_cta_debito(v_mod_cta_deb, v_mad_cta_deb,vp_cta_debito, r_gmovi.monto * -1);
           end if;
           lp_upd_cta_debito(v_mod_cta_deb, v_mad_cta_deb,vp_cta_debito, v_imp_debito);
         end if;
         If v_est_cuenta = 'I' Then -- Debo cambiar el estado de la cuenta
            v_nro_secuencia := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto := null;
            r_gmovi.est_cuenta := 'N';
            r_gmovi.cod_tra_padre   := 425;
            r_gmovi.cod_transaccion := 425;
            --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
            --DYDMR-3914  06/2016 si es extorno y el movimiento tiene mas de dos registros
            --se consulta nro_secuencia original del movimiento
            if nvl(v_rev_can_mov,0) > 2 and to_number(vp_extorno) = 99 then
              lp_obt_nro_secuencia;
            end if;
            lp_ins_ge_movimiento;
         End If;
         if nvl(v_ind_cta_deb_tra, 'N') = 'N' then
           if v_nro_cta_combinada is not null and v_imp_debito > v_sal_dis_debito then
              IF v_sal_dis_debito < 0 then
                 r_gmovi.monto           := v_imp_debito;
              else
                 r_gmovi.monto           := v_imp_debito - v_sal_dis_debito;
              end if;
              pag_cta.PR_OBT_CUENTA(v_nro_cta_combinada);
              v_nro_secuencia := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.concepto        := 'Transferencia a la Cta '||vp_cta_debito;
              r_gmovi.cod_tra_padre   := 309;
              r_gmovi.cod_transaccion := 503;
              r_gmovi.cod_modulo      := pag_cta.g_ctas.cod_modulo;
              r_gmovi.cod_modalidad   := pag_cta.g_ctas.cod_modalidad;
              r_gmovi.cod_oficina     := pag_cta.g_ctas.cod_oficina;
              r_gmovi.nro_cuenta      := pag_cta.g_ctas.nro_cuenta;
              ---
              --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
              --DYDMR-3914  06/2016 si es extorno y el movimiento tiene mas de dos registros
              --se consulta nro_secuencia original del movimiento
              if nvl(v_rev_can_mov,0) > 2 and to_number(vp_extorno) = 99 then
                lp_obt_nro_secuencia;
              end if;
              lp_ins_ge_movimiento;
              --
              lp_upd_cta_debito( pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad,
                                 pag_cta.g_ctas.nro_cuenta, r_gmovi.monto);
           end if;
         end if;
         -- fin de la cuenta combinada
/*         -- tys: agregado para envio de mensaje
         if v_cod_tra_padre = 382 then
           pag_sms.pr_pro_servicio_013(p_nro_cuenta    => vp_cta_debito,
                                       p_monto         => v_imp_debito,
                                       p_nro_documento => v_nro_documento,
                                       p_concepto      => 'Extracción en ATM');
         end if;
         -- tys: fin agregado*/
         /* tys: deshabilitado por desuso
         if v_val_cargo > 0 then
         ---
            v_nro_secuencia := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto           := v_val_cargo;
            r_gmovi.cod_tasa        := v_cod_tas_cargo;
            r_gmovi.val_tasa        := v_val_tas_cargo;
            r_gmovi.concepto        := 'Cargo por Extracción';
            r_gmovi.cod_tra_padre   := 137;
            r_gmovi.cod_transaccion := 137;
            ---
            PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
            if v_val_impuesto > 0 then
              v_nro_secuencia         := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.monto           := v_val_impuesto;
              r_gmovi.cod_tasa        := v_cod_tas_impuesto;
              r_gmovi.val_tasa        := v_val_tas_impuesto;
              r_gmovi.concepto        := 'IVA s/Cargo por Extracción';
              r_gmovi.cod_tra_padre   := v_cod_tra_impuesto;
              r_gmovi.cod_transaccion := v_cod_tra_impuesto;
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
            End if;
            v_importe := v_importe + nvl(v_cargos,0);
            lp_upd_cta_debito(vp_cta_debito, v_imp_debito);
            If v_est_cuenta = 'I' Then -- Debo cambiar el estado de la cuenta
              v_nro_secuencia := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.monto := null;
              r_gmovi.est_cuenta := 'N';
              r_gmovi.cod_tra_padre   := 425;
              r_gmovi.cod_transaccion := 425;
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
            End If;
            v_importe := v_importe - nvl(v_cargos,0); -- para el credito debe ser solo por el monto extraido
         Else*/

         --End if;
      End if;
      if v_es_banco = 'S' then
         -- Carga los parametros de movimientos de Credito
         v_nro_secuencia := v_nro_secuencia + 1;
         r_gmovi.cod_modulo      := v_mod_cta_cre;
         r_gmovi.cod_modalidad   := v_mad_cta_cre;
         r_gmovi.cod_oficina     := nvl(v_ofi_cta_cre,v_ofi_origen);
         r_gmovi.nro_cuenta      := vp_cta_credito;
         r_gmovi.cod_moneda      := nvl(v_mon_cta_cre, v_cod_moneda);
         r_gmovi.cod_usuario     := v_cod_usuario;
         r_gmovi.hora            := v_hora;
         r_gmovi.fecha           := v_fec_proceso;
         r_gmovi.nro_secuencia   := v_nro_secuencia;
         if to_number(vp_extorno) != 99 Then
            r_gmovi.fec_valor       := v_fec_valor;
         end if;
         r_gmovi.cod_tra_padre   := v_cod_tra_padre;
         r_gmovi.cod_mod_padre   := v_cod_modulo;
         r_gmovi.cod_mad_padre   := v_cod_modalidad;
         If v_cod_rub_caja is not null then
           r_gmovi.cod_transaccion := null;
           r_gmovi.tip_mov_rubro   := 'C';
           r_gmovi.cod_rubro       := v_cod_rub_caja;
         Else
           r_gmovi.cod_transaccion := 602;
         End if;
         If lf_exi_banco(vp_bco_atm) = 'S' then
            --r_gmovi.cod_banco := vp_bco_atm;
                --WA:06/08/2014 si es financiera se deja Nulo el Cod_banco
                if lf_exi_financiera(vp_bco_atm) = 'S' then
                   r_gmovi.cod_banco       := null;
                else
                   if vp_bco_aux is not null then
                      r_gmovi.cod_banco := vp_bco_aux;
                   else
                      r_gmovi.cod_banco := vp_bco_atm;
                   end if;
                end if;

         End if;
         If r_gmovi.cod_banco is null and lf_exi_banco(vp_bco_credito) = 'S' then
            --r_gmovi.cod_banco := vp_bco_credito;
                --WA:06/08/2014 si es financiera se deja Nulo el Cod_banco
                if lf_exi_financiera(vp_bco_credito) = 'S' then
                   r_gmovi.cod_banco       := null;
                else
                   r_gmovi.cod_banco       := vp_bco_credito;
                end if;

         End if;
         r_gmovi.monto           := v_imp_credito;
         r_gmovi.nro_documento   := v_nro_documento;
         r_gmovi.nro_documento2  := v_nro_documento2;
         r_gmovi.nro_documento3  := v_nro_documento3;

         r_gmovi.cod_tasa        := null;
         r_gmovi.val_tasa        := null;
         -- tys: cotizacion de cambio
         r_gmovi.cotizacion      := v_cot_credito;
         r_gmovi.mto_equ_local   := round(r_gmovi.monto * r_gmovi.cotizacion);
         --
         r_gmovi.cod_ofi_origen  := v_ofi_origen;
         r_gmovi.emi_aviso       := 'N';
         r_gmovi.concepto        := v_concepto;
         r_gmovi.estado          := 'N';
         if to_number(vp_extorno) != 99 Then
            r_gmovi.reversado       := 'N';
         end if;
/*         if r_gmovi.cod_modulo = 7 then
            r_gmovi.cod_tip_ope_cambio := v_cod_tip_ope_cambio;
            r_gmovi.cod_bco_central := v_cod_bco_central;
         end if; */
         --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
         --DYDMR-3914  06/2016 si es extorno y el movimiento tiene mas de dos registros
         --se consulta nro_secuencia original del movimiento
         if nvl(v_rev_can_mov,0) > 2 and to_number(vp_extorno) = 99 then
           lp_obt_nro_secuencia;
         end if;
         lp_ins_ge_movimiento;
         if nvl(v_ind_cta_cre_tra, 'N') = 'N' then
            lp_upd_cta_credito;
         end if;
         If v_est_cta_cre = 'I' Then -- Debo cambiar el estado de la cuenta
            v_nro_secuencia := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto := null;
            r_gmovi.est_cuenta := 'N';
            r_gmovi.cod_tra_padre   := 425;
            r_gmovi.cod_transaccion := 425;
            --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
            --DYDMR-3914  06/2016 si es extorno y el movimiento tiene mas de dos registros
            --se consulta nro_secuencia original del movimiento
            if nvl(v_rev_can_mov,0) > 2 and to_number(vp_extorno) = 99 then
              lp_obt_nro_secuencia;
            end if;
            lp_ins_ge_movimiento;
         End If;
      End if;
   End lp_pro_operacion_05;
   --
   procedure lp_pro_operacion_06 is
      -- Extracto --
      v_ope varchar2(15); -- Billetera Zimple / Operaciones sin tarjetas -- CN: 08/2016 --
   Begin
       v_cod_tra_padre := 390;
       -- Billetera Zimple / Operaciones sin tarjetas -- CN: 08/2016 --
       if vp_tip_ope is not null then
         v_ope := vp_tip_ope||vp_operacion;
         v_cod_tra_padre := lf_obt_tra_padre(C_DOM_TIP_OPE,v_ope);
         v_cod_tra_padre := nvl(v_cod_tra_padre,390);
       end if;
       --

       --WA:31/07/2014 Se ajusta inferior para igualar a funcionamiento anterior
       if nvl(to_number(vp_cta_debito),0) != 0 and v_mad_cta_deb not in (42,48,46,49) then
       -- Carga los parametros de movimientos de Debito
       r_gmovi.cod_modulo      := v_mod_cta_deb;
       r_gmovi.cod_modalidad   := v_mad_cta_deb;
       r_gmovi.cod_oficina     := nvl(v_ofi_cta_deb,v_ofi_origen);
       r_gmovi.nro_cuenta      := vp_cta_debito;
       r_gmovi.cod_moneda      := v_cod_moneda ;
       r_gmovi.cod_usuario     := v_cod_usuario;
       r_gmovi.hora            := v_hora;
       r_gmovi.fecha           := v_fec_proceso;
       r_gmovi.nro_secuencia   := v_nro_secuencia;
       --
       r_gmovi.fec_valor       := v_fec_valor;
       r_gmovi.cod_tra_padre   := v_cod_tra_padre;
       r_gmovi.cod_mod_padre   := v_cod_modulo;
       r_gmovi.cod_mad_padre   := v_cod_modalidad;
       r_gmovi.cod_transaccion := v_cod_tra_padre;
       r_gmovi.monto           := null;
       r_gmovi.nro_documento   := v_nro_documento;
       r_gmovi.nro_documento2  := v_nro_documento2;
       r_gmovi.nro_documento3  := v_nro_documento3;
       If lf_exi_banco(vp_bco_atm) = 'S' then
          --r_gmovi.cod_banco := vp_bco_atm;
            --WA:06/08/2014 si es financiera se deja Nulo el Cod_banco
            if lf_exi_financiera(vp_bco_atm) = 'S' then
               r_gmovi.cod_banco       := null;
            else
               if vp_bco_aux is not null then
                      r_gmovi.cod_banco := vp_bco_aux;
                   else
                      r_gmovi.cod_banco := vp_bco_atm;
                   end if;
            end if;
     End if;
       r_gmovi.cod_tasa        := null;
       r_gmovi.val_tasa        := null;
       r_gmovi.cotizacion      := null;
       r_gmovi.cod_ofi_origen  := v_ofi_origen;
       r_gmovi.emi_aviso       := 'N';
       r_gmovi.concepto        := v_concepto;
       r_gmovi.estado          := 'N';
       r_gmovi.reversado       := 'N';
       r_gmovi.cod_persona     := v_cod_persona;
       --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
       lp_ins_ge_movimiento;
      End if;
   End lp_pro_operacion_06;
   --
   procedure lp_pro_operacion_99 is
   v_continua varchar2(1) := 'S';
   v_exi_mov_dia varchar2(1) := 'N';
   v_exi_mov_dia_noc varchar2(1) := 'N';
   v_hor_reversion ge_movimientos.hora%type;
   v_usu_reversion ge_movimientos.cod_usuario%type;
   --
   procedure lp_ins_log_extornos is  --SC 21242 - EP 2015/10
         PRAGMA AUTONOMOUS_TRANSACTION;
       Begin
        begin
            insert into LOG_ATM_EXTORNOS(NRO_TRANSACCION) values(v_nro_documento3);
            commit;
          exception
            -- si salta error PK es por que ya existe extorno pero fallaron controles iniciales
            -- en se impide que continue el extorno
            when DUP_VAL_ON_INDEX then
              v_continua := 'N';
              vp_cod_respuesta := vr_ope_invalida;
            when others then
              v_continua := 'N';
              vp_cod_respuesta := vr_ope_invalida;
          end;
       End lp_ins_log_extornos;
   --
   Begin
      -- Un extorno no se puede desaprobar...
      -- Se busca el siguiente segundo para no tener problemas...
      --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
      v_hora := substr(vp_hora, 1, 2)||':'||substr(vp_hora,3,2)||':'||substr(vp_hora,5,2);
      -- para evitar la repeticion de la hora en los movimientos
      -- v_hora := lf_obt_hor_disponible(v_fec_proceso, v_hora, v_cod_usuario, v_es_nocturno);
      v_hora := fug_obt_hor_disponible(v_fec_proceso, v_hora, v_cod_usuario, v_es_nocturno);

      vp_cod_respuesta := vr_aprobado; -- Aprobado
      -- veo si ya se realizo el extorno anteriormente
      begin
         select 'N'
           into v_continua
           from gv_movimientos_atm  -- JS:se cambia por nueva vista con filtro de fecha
          where nro_documento3 = v_nro_documento3
            and nro_documento  = v_nro_documento
            and monto          = v_imp_debito
            and cod_moneda     = nvl(v_mon_cta_deb, v_cod_moneda)
            and reversado      = 'N'
            and estado         = 'N'
            and substr(cod_usuario,1,3)    = substr(v_cod_usuario,1,3)
            and hora           = v_hora
            and rownum = 1;

      exception
         when no_data_found then
            --v_continua := 'S';
            -- MDPMATNT-1 - Mensajería en ATM sobre comisiones por transacciones -- CN: 03/2016 --
            if to_number(vp_operacion) in (2, 52, 93, 6, 5, 55) Then -- Consulta de Saldo, Extractos y Extraccion
              begin
                 select 'N'
                   into v_continua
                   from gv_movimientos_atm -- JS:se cambia por nueva vista con filtro de fecha
                  where nro_documento3 = v_nro_documento3
                    and nro_documento  = v_nro_documento
                    and nvl(monto,0)   = nvl(v_imp_debito,0)  -- Extorno de Consulta de Saldo y Extractos -- Importe cero
                    and cod_moneda     = nvl(v_mon_cta_deb, v_cod_moneda)
                    and reversado      = 'S'
                    and estado         = 'N'
                    and substr(cod_usuario,1,3)    = substr(v_cod_usuario,1,3)
                    and rownum = 1;
              exception
                when no_data_found then
                  v_continua := 'S';
                when others then
                  v_continua := 'S';
              end;
            else
              v_continua := 'S';
            end if;
         when others then
            v_continua := 'S';
      end;
      -- veo si se registro el movimiento original
      if nvl(v_continua,'S') = 'S' then
          begin
             select 'S'
               into v_continua
               from gv_movimientos_atm -- JS:se cambia por nueva vista con filtro de fecha
              where nro_documento3 = v_nro_documento3
                and nro_documento  = v_nro_documento
                --and monto          = abs(v_imp_debito)  -- movimiento positivo
                and nvl(monto,0)   = abs(nvl(v_imp_debito,0))  -- movimiento positivo  -- Consulta Saldo y Extractos -- Importe cero -- MDPMATNT-1 - Mensajería en ATM sobre comisiones por transacciones -- CN: 03/2016 --
                and cod_moneda     = nvl(v_mon_cta_deb, v_cod_moneda)
                and reversado      = 'N'
                and estado         = 'N'
                and substr(cod_usuario,1,3) = substr(v_cod_usuario,1,3)
                and rownum = 1;
          exception
             when no_data_found then
               if v_est_modulo = 4 then
                 begin
                   select 'S'
                     into v_continua
                     from ge_movimientos
                    where nro_documento3 = v_nro_documento3
                      and nro_documento  = v_nro_documento
                      --and monto          = abs(v_imp_debito)  -- movimiento positivo
                      and nvl(monto,0)   = abs(nvl(v_imp_debito,0))  -- movimiento positivo  -- Consulta Saldo -- Importe cero -- MDPMATNT-1 - Mensajería en ATM sobre comisiones por transacciones -- CN: 03/2016 --
                      and cod_moneda     = nvl(v_mon_cta_deb, v_cod_moneda)
                      and reversado      = 'N'
                      and estado         = 'N'
                      and substr(cod_usuario,1,3)    = substr(v_cod_usuario,1,3)
                      and rownum = 1;
                 exception
                     when no_data_found then
                          v_continua := 'N';
                     when others then
                          v_continua := 'N';
                 end;
              else
                 v_continua:= 'N';
              end if;
            when others then
              v_continua := 'N';
          end;
      end if;
       ---
      -- SC 21242 - ITGF - Reversiones Duplicadas Operaciones Infonet
      -- para control de extornos duplicados
      -- inserta en log_atm_extorno, la pk de la tabla es NRO_TRANSACCION
      if nvl(v_continua,'S') = 'S' then
        lp_ins_log_extornos;
      end if;
      ---
      if to_number(vp_operacion) = 72 and to_number(vp_nro_atm) = 0 then
         v_continua := 'S';
      end if;
      if nvl(v_continua,'S') = 'S' then
          if ((to_number(vp_operacion) in (0, 1, 23, 24, 41,27,50)) or
              (to_number(vp_operacion) = 72 and to_number(vp_nro_atm) <> 0)) Then -- infonet cobranza en un atm es directo
             if to_number(vp_operacion) in (0, 1, 72) then
                if v_es_nocturno = 'N' then
                   begin
                     select distinct ('S'), hora, cod_usuario
                       into v_exi_mov_dia, v_hor_reversion, v_usu_reversion
                       from ge_movimientos
                      where nro_documento3 = v_nro_documento3
                        and nro_documento  = v_nro_documento
                        and cod_moneda     = nvl(v_mon_cta_deb, v_cod_moneda)
                        and monto > 0
                        and reversado      = 'N'
                        and estado         = 'N'
                        and cod_tra_padre <> 309
                        and substr(cod_usuario,1,3)    = substr(v_cod_usuario,1,3);
                  exception
                     when others then
                       v_exi_mov_dia := 'N';
                   end;
                   if nvl(v_exi_mov_dia, 'N') = 'S' then
                      v_fec_valor := v_fec_proceso;
                   end if;
                 else
                   begin
                      select distinct ('S'), hora, cod_usuario
                        into v_exi_mov_dia_noc, v_hor_reversion, v_usu_reversion
                        from ge_movimientos_noc
                       where nro_documento3 = v_nro_documento3
                         and nro_documento  = v_nro_documento
                         and cod_moneda     = nvl(v_mon_cta_deb, v_cod_moneda)
                         and monto > 0
                         and reversado      = 'N'
                         and estado         = 'N'
                         and substr(cod_usuario,1,3)    = substr(v_cod_usuario,1,3);
                   exception
                     when others then
                        v_exi_mov_dia := 'N';
                   end;
                   if nvl(v_exi_mov_dia_noc, 'N') = 'S' then
                      v_fec_valor := v_fec_proceso;
                   end if;
                 end if;
             end if;

             lp_pro_operacion_00;

             if to_number(vp_operacion) in (0, 1, 72) then
               if v_es_nocturno = 'N' then
                  if nvl(v_exi_mov_dia, 'N') = 'S' then
                     BEGIN
                       update ge_movimientos a
                          set a.reversado         = 'S',
                              a.cod_usu_reversion = (case when (a.monto > 0) then v_cod_usuario else v_usu_reversion end),
                              a.hor_reversion     = (case when (a.monto > 0) then v_hora else v_hor_reversion end),
                              a.fec_valor = v_fec_proceso
                        where nro_documento3 = v_nro_documento3
                          and nro_documento  = v_nro_documento
                          and reversado      = 'N'
                          and estado         = 'N'
                          and cod_tra_padre <> 309 -- transferencia entre cuentas
                          and substr(cod_usuario,1,3)    = substr(v_cod_usuario,1,3);
                     END;
                   END IF;
               else
                if nvl(v_exi_mov_dia_noc, 'N') = 'S' then
                  BEGIN
                    update ge_movimientos_noc a
                       set a.reversado         = 'S',
                           a.cod_usu_reversion = (case when (a.monto > 0) then v_cod_usuario else v_usu_reversion end),
                           a.hor_reversion     = (case when (a.monto > 0) then v_hora else v_hor_reversion end),
                           a.fec_valor = v_fec_proceso
                     where nro_documento3 = v_nro_documento3
                       and nro_documento  = v_nro_documento
                       and reversado      = 'N'
                       and estado         = 'N'
                       and cod_tra_padre <> 309 -- transferencia entre cuentas
                       and substr(cod_usuario,1,3)    = substr(v_cod_usuario,1,3);
                  END;
                END IF;
             end if;
            end if;
          elsif to_number(vp_operacion) IN (05,55) Then
             lp_pro_operacion_05;
          elsif to_number(vp_operacion) = 72 and to_number(vp_nro_atm) = 0 then -- infonet cobranza en negocios
             lp_pro_operacion_72; -- infonet cobranzas
             if nvl(v_ind_gen_mov_rev72, 'N') = 'S' then
                lp_pro_operacion_00;
             end if;
          -- MDPMATNT-1 - Mensajería en ATM sobre comisiones por transacciones -- CN: 03/2016 --
          elsif to_number(vp_operacion) in (2, 52, 93, 6) Then -- Consulta de Saldo y Extractos
             BEGIN
               update ge_movimientos a
                  set a.reversado         = 'S',
                      a.cod_usu_reversion = v_cod_usuario,
                      a.hor_reversion     = v_hora
                where nro_documento3 = v_nro_documento3
                  and nro_documento  = v_nro_documento
                  and nvl(monto,0)   = abs(nvl(v_imp_debito,0))
                  and cod_moneda     = nvl(v_mon_cta_deb, v_cod_moneda)
                  and reversado      = 'N'
                  and estado         = 'N'
                  and substr(cod_usuario,1,3) = substr(v_cod_usuario,1,3);
                if sql%notfound then
                   update ge_movimientos_noc a
                      set a.reversado         = 'S',
                          a.cod_usu_reversion = v_cod_usuario,
                          a.hor_reversion     = v_hora
                    where nro_documento3 = v_nro_documento3
                      and nro_documento  = v_nro_documento
                      and nvl(monto,0)   = abs(nvl(v_imp_debito,0))
                      and cod_moneda     = nvl(v_mon_cta_deb, v_cod_moneda)
                      and reversado      = 'N'
                      and estado         = 'N'
                      and substr(cod_usuario,1,3) = substr(v_cod_usuario,1,3);
                end if;
             END;
          --
          end if;
      else
          -- DYDMR-11096 JUL/2019 NAF
          -- respuesta 12 - operacion invalida, cuando no encuentra operacion original
          vp_cod_respuesta := vr_ope_invalida;
      end if;
   End lp_pro_operacion_99;
   --
   procedure lp_obt_saldos is
      v_sal_disponible ah_cta_vistas.sal_total%type;
      v_sal_contable   ah_cta_vistas.sal_total%type;
   Begin
       ----------
       --WA:31/07/2014 Se ajusta inferior para igualar a funcionamiento anterior
       If v_mad_cta_deb in (42,48,46,49) or v_ind_rub_debito = 'S' then
          v_sal_disponible := 0;
          v_sal_contable   := 0;
       else
          pag_cta.PR_OBT_CUENTA(vp_cta_debito);
          v_sal_disponible := nvl(pag_cta.FU_SAL_DISPONIBLE,0);
          v_cod_persona    := PAG_CTA.G_CTAS.cod_cliente;
          --Se modifico p/ que no incluya la línea de Sobregiro en el disponible --01/02/2010
          /*
          if pag_cta.g_ctas.cod_modalidad = 41 then
             v_sal_disponible := v_sal_disponible + PAG_CTA.FU_OBT_LIN_SOBREGIRO(vp_cta_debito,v_fec_proceso);
          end if;
          */
          v_sal_contable   := nvl(pag_cta.g_ctas.sal_Actual,0);
       End if;
       -- Carga la respuesta --
       vp_sal_disponible := lpad(trim(to_char(abs(v_sal_disponible * 100))), 15, '0');
       vi_sal_disponible := v_sal_disponible;
       if v_sal_disponible < 0 Then
          vp_sig_disponible := '-';
       end if;
       vp_sal_contable := lpad(trim(to_char(abs(v_sal_contable * 100))), 15, '0');
       vi_sal_contable := v_sal_contable;
       if v_sal_contable < 0 Then
          vp_sig_contable := '-';
       end if;
       --------
   End lp_obt_saldos;

   -- MDPMATNT-1 - Mensajería en ATM sobre comisiones por transacciones -- CN: 02/2016 --
   procedure pr_ins_log( p_pedido varchar2, p_respuesta varchar2, p_fec_inicio date, p_error varchar2,
              p_cod_extorno       in varchar2 default null,
              p_fec_valor         in date default null,
              p_nro_transaccion   in number default null,
              p_nro_cta_debito    in varchar2 default null,
              p_hora              in varchar2 default null,
              p_cod_bco_debito    in number default null,
              p_nro_cta_credito   in varchar2 default null,
              p_cod_bco_credito   in number default null,
              p_cod_operacion     in varchar2 default null,
              p_mto_total         in number default null,
              p_cod_moneda        in varchar2 default null,
              p_nro_atm           in number default null,
              p_nro_pos           in number default null,
              p_tra_pos           in number default null,
              p_tip_hora          in varchar2 default null,
              p_nom_comercio      in varchar2 default null,
              p_nro_tra_extornado in varchar2 default null,
              p_cod_bco_atm       in number default null
              ) is
      PRAGMA AUTONOMOUS_TRANSACTION;
   begin
      insert into log_atm (mensaje, respuesta, fec_inicio, error
      ,cod_extorno,
         fecha,
         nro_transaccion,
         nro_cta_debito,
         hora,
         cod_bco_debito,
         nro_cta_credito,
         cod_bco_credito,
         cod_operacion,
         mto_total,
         cod_moneda,
         nro_atm,
         nro_pos,
         tra_pos,
         tip_hora,
         nom_comercio,
         nro_tra_extornado,
         cod_bco_atm)
      values (substr(p_pedido, 1, 4000), substr(p_respuesta, 1, 4000), p_fec_inicio, substr(p_error, 1, 1000),
         p_cod_extorno,
         p_fec_valor,
         p_nro_transaccion,
         p_nro_cta_debito,
         p_hora,
         p_cod_bco_debito,
         p_nro_cta_credito,
         p_cod_bco_credito,
         p_cod_operacion,
         p_mto_total,
         p_cod_moneda,
         p_nro_atm,
         p_nro_pos,
         p_tra_pos,
         p_tip_hora,
         p_nom_comercio,
         p_nro_tra_extornado,
         p_cod_bco_atm
         );
      commit;
   end pr_ins_log;

   procedure pr_del_log_ext( p_nro_transaccion number ) is
      PRAGMA AUTONOMOUS_TRANSACTION;
   begin
      delete from LOG_ATM_EXTORNOS where NRO_TRANSACCION= p_nro_transaccion;
      commit;
    exception
      when others then
       null;
   end pr_del_log_ext;

 --DYDMR-6700 - Incidencia SAU - ITGF - Operaciones "CASH BACK" Via Infonet
 function lf_val_tip_operacion (p_tip_operacion number) return varchar2 is
 ---Objetivo de la función es validar operaciones del catalogo
 v_existe varchar2(1) := 'N';
  Begin
      select distinct 'S'
        into v_existe
        from ba_cod_referencias
       where dominio = 'TIP_OPE_ATM'
         and to_number(val_minimo) = p_tip_operacion;
        return v_existe;
    exception
      when no_data_found then
        v_existe := 'N';
        return v_existe;
      when others then
        v_existe := 'N';
        return v_existe;
    end;
  -----
Begin
   v_fec_inicio := sysdate;  -- solo para control del tiempo de procesamiento

   BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=9; END;
   -- Carga el parametro en variables
   lp_car_parametros;
   -- Carga los valores iniciales
   /*lp_car_val_inicial;
   --DYDMR-6700 - Incidencia SAU - ITGF - Operaciones "CASH BACK" Via Infonet
   --Validar tipo de Operación
   if lf_val_tip_operacion(to_number(vp_operacion)) <> 'S' and vp_cod_respuesta = vr_aprobado then
     vp_cod_respuesta :=  vr_ope_no_soportada;
   end if;
   ---
   if nvl(to_number(vp_cta_debito),0) != 0 and vp_cod_respuesta = vr_aprobado Then
      -- Debo verificar si existe la cuenta
      If v_ind_rub_debito = 'N' then
         pag_cta.PR_OBT_CUENTA(vp_cta_debito);
         v_cod_persona    := PAG_CTA.G_CTAS.cod_cliente;
         v_nro_cta_combinada := pag_cta.G_CTAS.nro_cta_combinada;
         v_sal_dis_debito    := pag_cta.FU_SAL_DISPONIBLE;
         if pag_cta.G_CTAS.cod_modalidad = 41 then
            v_sal_dis_debito := v_sal_dis_debito + PAG_CTA.FU_OBT_LIN_SOBREGIRO(vp_cta_debito,v_fec_proceso);
         end if;
      Else
         pag_cta.g_ctas.sal_disponible := 0;
         pag_cta.g_ctas.sal_actual     := 0;
      End if;
      lp_dat_cta(vp_cta_debito, v_mod_cta_deb, v_mad_cta_deb, v_ofi_cta_deb, v_mon_cta_deb, v_ind_cta_deb_tra);
      g_cod_error := pag_cta.G_COD_ERROR;
      if g_cod_error = 12 Then -- Cuenta inexistente
         vp_cod_respuesta := vr_cta_inexistente; -- Tarjeta desconocida
      end if;
   end if;


   if vp_cod_respuesta = vr_aprobado Then
      -- Verifica el estado de la cuenta
      v_est_cuenta := pag_cta.FU_OBT_EST_CUENTA;
      if v_est_cuenta not in ('N', 'S', 'I') Then -- No es normal o con bloqueo de saldo
         -- Estado Inactivo tambien debe permitir.
         vp_cod_respuesta := vr_no_aprobado; -- Transaccion no aprobada
      else
        --Verifica si es una cta. combinada
        --If v_cta_combinada = 'S' then
        --  vp_cod_respuesta := vr_no_aprobado; -- Transaccion no aprobada
        --else
          if to_number(vp_extorno) != 99 Then
            if to_number(vp_operacion) in (0, 1, 23, 24, 41, 72, 50, 51, 54)
               or (to_number(vp_operacion) = 27 and (v_clt_deb_nuestro='S' or v_clt_cre_nuestro='S')) Then -- Compras
               lp_ver_operacion_00;
            elsif to_number(vp_operacion) in (2, 52, 93) Then -- Consulta de Saldo
               lp_ver_operacion_02;
            elsif to_number(vp_operacion) in (5, 55) Then -- Extraccion
               lp_ver_operacion_05;
            elsif to_number(vp_operacion) = 6 Then -- Extracto
               lp_ver_operacion_06;
            elsif to_number(vp_operacion) = 85 then
               if substr(vp_negocio,37,4) in( '#DS#', '#DN#' ) then
                  prt_act_tar_atm(v_cod_persona,substr(vp_negocio,37,4), 28); --generacion alta de tarjeta
                  --PCCDEEVO-80 Seguimiento de operaciones rechazadas en ATM
                  if substr(vp_negocio,37,4) = '#DN#' then
                     lp_act_rechazo(v_cod_persona,vp_cta_debito, '#D', 'I' );
                  end if;
               elsif substr(vp_negocio,37,4) = '#FS#' then
                  --generar simulacion de prestamo
                  prp_gen_atm_simulacion( v_cod_persona,
                                          68,
                                          v_cod_moneda,
                                          v_importe,--monto
                                          vp_can_cheques,--cuota
                                          'B',--bruto
                                          v_fec_proceso,
                                          null,--primer vencimiento
                                          null,--tasa
                                          28,--canal
                                          null,--877,--campaña
                                          'Prestamo Pre-Aprobado via ATM',
                                          vp_cta_debito,
                                          v_mensaje );
                         --PCCDEEVO-80 Seguimiento de operaciones rechazadas en ATM
                          lp_act_rechazo(v_cod_persona,vp_cta_debito, '#F', 'E');
               elsif substr(vp_negocio,37,4) = '#GS#' then
                  --generar solicitud de prestamo
                  prp_gen_atm_solicitud( v_cod_persona,
                                         68,
                                         v_cod_moneda,
                                         v_importe,--monto
                                         vp_can_cheques,--cuota
                                         'S',--grabar
                                         'B',--bruto
                                         v_fec_proceso,
                                         null,--primer vencimiento
                                         null,--tasa
                                         28,--canal
                                         null,--877,--campaña
                                         'Prestamo Pre-Aprobado via ATM',
                                         null,
                                         null,
                                         null,
                                         null,
                                         vp_cta_debito,
                                         v_nro_solicitud );
                  -- Desembolso de Préstamo
                  prp_des_atm_prestamo(v_cod_persona, v_importe, vp_cta_debito, v_nro_solicitud);--acepta la solicitud, generar la cuenta de prestamo
               elsif substr(vp_negocio,37,4) in( '#ES#', '#EN#' )then
                 prg_ins_seguros(v_cod_persona, vp_cta_debito,substr(vp_negocio,37,4),null,null,null,null,null,v_nro_seguro,v_err_seguro);--seguro
               elsif substr(vp_negocio,37,4) in( '#AS#')then
                 prg_act_con_celular(v_cod_persona,substr(vp_negocio,37,4));--confirmacion modificacion de celular
               else
                 prg_act_dat_atm(v_cod_persona,substr(vp_negocio,26,15));--para el nro de telefono
               end if;
            elsif v_clt_deb_nuestro = 'S' and to_number(vp_operacion) != 13 Then -- 13 mis productos
               vp_cod_respuesta := vr_ope_invalida;
            end if;
          else -- Reversion
            lp_ver_operacion_99;
          end if;
        --end if;
      end if;
   end if;
   -- Verifica el estado del modulo por si se este haciendo el cierre
   v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(3);
   if v_est_modulo in (1, 6) Then
      -- Se esta corriendo el proceso de cierre
      vp_cod_respuesta := vr_en_cierre; -- En cierre
   end if;
   -- Cargar los datos de salida
   v_cal_cargo := 'N'; -- 08/2016 -- Para calcular el cargo que solo es necesario para la llamada al lp_car_salida luego de procesar la transaccion --
   lp_car_salida;
   -- Si la respuesta fue aprobado, Debe procesar la transaccion --
   if vp_cod_respuesta = vr_aprobado Then
      if to_number(vp_extorno) != 99 Then
          if ((to_number(vp_operacion) in (0, 1, 23, 24, 41, 50, 51, 54, 27)) or -- Compras en pos
              (to_number(vp_operacion) = 72 and to_number(vp_nro_atm) <> 0)) Then -- infonet cobranza en un atm es directo
             lp_pro_operacion_00;
          elsif to_number(vp_operacion) in (2, 52, 93) Then -- Consulta de Saldo
             lp_pro_operacion_02;
          elsif to_number(vp_operacion) in (5, 55) Then -- Extraccion
             lp_pro_operacion_05;
          elsif to_number(vp_operacion) = 6 then -- Extracto
             lp_pro_operacion_06;
          elsif to_number(vp_operacion) = 72 and to_number(vp_nro_atm) = 0 then -- inf cobranza en comercio pos
              lp_pro_operacion_72;  -- infonet cobranzas
          end if;
      else
         lp_pro_operacion_99;
      end if;
   end If;

   --Volver a Consultar Saldos y Cargar Salida (Excepto para Consultas/Extractos)
   -- MDPMATNT-1 - Mensajería en ATM sobre comisiones por transacciones -- CN: 02/2016 --
   -- Volver a Consultar Saldos y Cargar Salida
   --if nvl(to_number(vp_cta_debito),0) != 0 and to_number(vp_operacion) not in (/*2, 52,*/ --93,/* 6,*/ 99) then
     --and vp_cod_respuesta = vr_aprobado Then
    /*  lp_obt_saldos;
      -- Cargar los datos de salida
      v_cal_cargo := 'S'; -- 08/2016 -- Para calcular el cargo que solo es necesario para la llamada al lp_car_salida luego de procesar la transaccion --
      lp_car_salida;
      if to_number(vp_operacion) in (2,5,13) and vp_cod_respuesta = vr_aprobado then --Consulta/Extracto ATM
        if v_cod_persona is not null then
          declare
            v_datos  pag_pre.tp_datosSeguro;
              --v_lista  pag_pre.tp_lista_seguros;
              v_fec_confirmacion ba_act_dat_clientes.fec_confirmacion%type := sysdate;
              v_existe varchar2(1);
            v_fec_rechazo ge_rch_seguros.fec_rechazo%type := pae_cnf.FU_OBT_FEC_ACTUAL(1);
            v_error       varchar2(2000);
        BEGIN
          begin
                if pag_pre.fu_tie_seguro(v_cod_persona,v_datos) = 1 and substr(v_pre_aprobada,321,2) = '#E' then
               insert into ge_rch_seguros
                 (cod_persona, cod_tip_seguro, fec_rechazo, cod_ente)
               values
                 (v_cod_persona, v_datos.codigoSeguro, v_fec_rechazo, v_datos.codigoEnte);
            end if;
          exception
            when others then
              v_error := sqlerrm;
              prg_env_mail(fug_obt_pardinamico('CAM_MAR_DIR_MAIL'),
                           fug_obt_pardinamico('CAM_MAR_DIR_EP'),
                           'Rechazo de Seguros en ATM',
                           'Error en rechazo de seguro para la cuenta: '||vp_cta_debito||chr(13)||
                           'Pedido: '||p_pedido||'.'||chr(13)||
                           'Respuesta: '||vp_respuesta||'.'||chr(13)||
                           'Error: '||v_error);
          end;
              if substr(v_pre_aprobada,321,2) = '#I' then
                begin
                  select 'S'
                    into v_existe
                    from ba_act_dat_clientes a
                   where a.estado = 'P'
                     and a.tel_tip_linea = 'C'
                     and a.tip_solicitud = 'C'
                     and a.cod_persona = v_cod_persona
                     and a.fec_confirmacion is null;
                exception
                  when no_data_found then
                    v_existe := 'N';
                  when too_many_rows then
                    v_existe := 'S';
                  when others then
                    v_existe := 'N';
                  end;
                if v_existe = 'S' then
                   update ba_act_dat_clientes a
                      set a.estado = 'R',
                          a.fec_confirmacion = v_fec_confirmacion
                    where a.estado = 'P'
                      and a.tel_tip_linea = 'C'
                      and a.tip_solicitud = 'C'
                      and a.cod_persona = v_cod_persona
                      and a.fec_confirmacion is null;
        end if;
      end if;
        END;
        end if;--cod_persona
      end if;--vp_operacion
   end if;

   -- SC 21242 - ITGF - Reversiones Duplicadas Operaciones Infonet
   -- Si es extorno y Si existio un error en el procesamiento, llaveo, otro error, etc
   -- se vuelve a borrar el registro para que se pueda volver a intentar el extorno
   if vp_extorno=99 and vp_cod_respuesta <> 11 then
      pr_del_log_ext( v_nro_documento3);
   end if;
   -- MDPMATNT-1 - Mensajería en ATM sobre comisiones por transacciones -- CN: 03/2016 --
   pr_ins_log(p_pedido, vp_respuesta, v_fec_inicio, v_msj_error,
              vp_extorno, v_fec_valor, v_nro_documento, vp_cta_debito, v_hora, vp_bco_debito, vp_cta_credito, vp_bco_credito,
              vp_operacion, v_importe, vp_moneda, vp_nro_atm, vp_nro_pos, vp_tra_pos, vp_tip_hora, vp_negocio, vp_tra_extornado,
              vp_bco_atm);
   --
   -- Una vez procesado responde
   */return vp_respuesta;
Exception
   When OTHERS Then
      v_msj_error := SQLERRM;
      rollback;
      --dbms_output.put_line(substr('error '||sqlerrm, 1, 255));
      --raise_application_error(-20000,vp_fecha||' '||sqlerrm);   -- anular esto, es solo para prueba
      vp_cod_respuesta := vr_otr_error;
      -- Carga respuesta por defecto --
      vp_can_extractos  := '000';
      vp_sig_disponible := '+';
      vp_sig_contable   := '+';
      vp_sal_disponible := lpad('0', 15, '0');
      vp_sal_contable   := lpad('0', 15, '0');
      vi_sal_disponible := 0;
      vi_sal_contable   := 0;
      vp_extractos      := '';
      v_cal_cargo := 'N';
      if vp_extorno=99 and vp_cod_respuesta <> 11 then
         pr_del_log_ext( v_nro_documento3);
      end if;
      lp_car_salida; -- 08/2016 -- Para calcular el cargo que solo es necesario para la llamada al lp_car_salida luego de procesar la transaccion --
      -- MDPMATNT-1 - Mensajería en ATM sobre comisiones por transacciones -- CN: 03/2016 --
      pr_ins_log(p_pedido, vp_respuesta, v_fec_inicio, v_msj_error,
              vp_extorno, v_fec_valor, v_nro_documento, vp_cta_debito, v_hora, vp_bco_debito, vp_cta_credito, vp_bco_credito,
              vp_operacion, v_importe, vp_moneda, vp_nro_atm, vp_nro_pos, vp_tra_pos, vp_tip_hora, vp_negocio, vp_tra_extornado,
              vp_bco_atm  );
      --
      return vp_respuesta;

End;
/

