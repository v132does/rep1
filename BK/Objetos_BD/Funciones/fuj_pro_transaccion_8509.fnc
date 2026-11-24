CREATE OR REPLACE FUNCTION IT.fuj_pro_transaccion_8509(p_moneda      in varchar2,
                                                       p_monto_op    in number,
                                                       p_monto_co    in number,
                                                       p_tip_op      in varchar2,
                                                       p_mov_id      in varchar2,
                                                       p_mtcn        in number,
                                                       p_usuario     in varchar2,
                                                       p_cod_persona in VARCHAR2,
                                                       p_cotizacion  in number,
                                                       p_cod_proc    in number,
                                                       p_cod_serv    in number)
  RETURN VARCHAR2 IS
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo       ge_cuentas.cod_modulo%TYPE := 9; -- Caja
  v_cod_modalidad    ge_cuentas.cod_modalidad%TYPE := 91; -- Caja
  v_cod_transaccion  ge_transacciones.cod_transaccion%TYPE := 8509; -- transaccion
  v_cod_tra_padre_wu number(4) := 8506; -- transaccion padre para western union
  v_cod_tra_padre_ps number(4) := 8526; -- transaccion padre para pago de servicios
  v_cod_usuario      ba_usuarios.cod_usuario%TYPE := upper(USER); --usuario
  v_codigo_modulo    NUMBER(3) := 4;
  v_codigo_modalidad NUMBER(3) := 43;
  v_cal_iva          NUMBER;
  v_redondeo         NUMBER := 0;
  v_monto            NUMBER := 0;
  v_cod_mon_local    ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
  v_cod_mon_fuerte   ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_fuerte;
  -- Datos de la caja
  v_fec_actual   cj_movimientos.fecha%type := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_fec_caja     cj_movimientos.fecha%type; -- fecha de la caja
  v_hor_actual   cj_movimientos.hora%type;-- := to_char(SYSDATE, 'HH24:MI:SS'); -- Hora actual
  v_cod_oficina  ge_cuentas.cod_oficina%TYPE; -- Codigo de oficina
  v_estado       NUMBER(3);
  v_sal_actual   ge_cuentas.sal_contable%TYPE; -- saldo actual de la caja en efectivo
  v_sal_cheques  ge_cuentas.sal_contable%TYPE; -- saldo actual de la caja en cheques
  v_nro_cuenta_b ge_movimientos.nro_cuenta%type; --cuenta operativa bancard
  -- Datos de la cuenta
  v_cod_moneda     ge_cuentas.cod_moneda%TYPE; -- moneda de la cuenta
  v_est_cuenta     ge_cuentas.estado%TYPE; -- estado de la cuenta
  v_tip_cuenta     ge_cuentas.cod_modalidad%TYPE; -- tipo de cuenta(modalidad)
  v_cod_mod_cuenta ge_cuentas.cod_modulo%TYPE; -- modulo de la cuenta
  -- Datos de salida
  v_msj_salida       LONG; -- mensaje final retornado
  v_msj_respuesta    LONG := 'Operacion Confirmada'; -- sin errores
  v_cod_respuesta    NUMBER(3) := 0; -- sin errores
  v_tipo             VARCHAR2(01) := 'D'; -- Debito para la caja (ingreso)
  v_tip_monto        VARCHAR2(01) := 'E'; -- Cheq. Otros Bancos
  v_nro_caja         cj_cajas.nro_caja%type;
  v_numero_secuencia NUMBER(3) := 0;
  v_mto_efectivo     ge_cuentas.sal_contable%TYPE := nvl(to_number(p_monto_op),
                                                         0); -- importe del deposito en efectivo
  v_cotizacion       ge_movimientos.cotizacion%TYPE := p_cotizacion;
  v_nro_secuencia    NUMBER(3) := 0; -- secuencia del mov.
  v_nro_boleta       NUMBER := to_number(p_mov_id); --Numbero de boleta
  v_nro_cuenta_ah    ge_movimientos.nro_cuenta%type;
  v_nro_cuenta_w     ge_movimientos.nro_cuenta%type;
  v_nro_cuenta       ge_movimientos.nro_cuenta%type;
  v_cod_persona      ba_personas.cod_persona%type;
  -- datos calculados
  r_gmovi               ge_movimientos%ROWTYPE;
  v_tot_efectivo        ge_movimientos.monto%TYPE := 0; -- deposito en efectivo + cargos
  v_impresion           varchar2(4000);
  v_error               varchar2(500);
  v_result              boolean;
  v_cod_transaccion_cre NUMBER(4);
  v_cod_ente            ge_entes.cod_ente%type;
  v_nro_cuenta_fielcob  ge_movimientos.nro_cuenta%type; --cuenta operativa fielcobranzas
  v_cod_tasa_fielcob    ge_tasas.cod_tasa%type;
  v_comision            ge_movimientos.monto%type;
  v_valor_com           ge_movimientos.monto%type;
  v_fecha_vig           ge_tas_fechas.fec_vigencia%TYPE;
  v_tip_valor           ge_tasas.tip_valor%TYPE;
  v_val_tasa            ge_tas_fechas.val_tasa%type := 10;
  v_mon_cre             ge_movimientos.monto%type;
  v_desc_servicio       ba_cod_referencias.significado%type;
  v_tipo_tasa           ge_tasas.tipo%TYPE;
  v_mto_equ_local       ge_movimientos.mto_equ_local%type := 0;

  /*****************************************************************************************************/
  --
  -- Procedimiento interno para generar movimiento y act. de control de caja
  PROCEDURE lp_gen_transaccion IS
  BEGIN
    -- Actualizo el control de caja
    UPDATE cj_controles
       SET sal_actual  = nvl(sal_actual, 0) + nvl(v_mto_efectivo, 0),
           tot_debitos = nvl(tot_debitos, 0) + nvl(v_mto_efectivo, 0),
           can_debitos = nvl(can_debitos, 0) +
                         decode(v_mto_efectivo, 0, 0, 1),
           estado      = 1 -- abierto
     WHERE nro_caja = to_number(V_nro_caja)
       AND cod_moneda = v_cod_moneda
       AND fecha = v_fec_caja;
    v_nro_secuencia := 0;
    IF v_mto_efectivo > 0 THEN
      -- genero el movimiento por el efectivo
      v_nro_secuencia := v_nro_secuencia + 1;
      INSERT INTO cj_movimientos
        (fecha,
         hora,
         cod_usuario,
         nro_secuencia,
         cod_tra_padre,
         cod_mod_padre,
         cod_mad_padre,
         cod_oficina,
         cod_moneda,
         nro_caja,
         nro_documento,
         nro_cuenta,
         monto,
         tip_monto,
         tipo)
      VALUES
        (v_fec_actual,
         v_hor_actual,
         v_cod_usuario,
         v_nro_secuencia,
         -- secuencia 1
         v_cod_transaccion,
         v_cod_modulo,
         v_cod_modalidad,
         v_cod_oficina,
         v_cod_moneda,
         to_number(v_nro_caja),
         v_nro_boleta,
         v_nro_cuenta,
         v_mto_efectivo,
         'E' /* efectivo */,
         v_tipo); --es debito
    END IF;

  END lp_gen_transaccion;
  --
BEGIN
  -- Inicializacion de la aplicacion y el modulo
  BEGIN
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := v_cod_modulo;
  END;
  if v_cotizacion is null then
    v_cotizacion:= pag_gen.fu_obt_cotizacion(p_moneda, v_fec_actual);
  end if;

  if p_tip_op = 'E' then
    v_cod_transaccion_cre := 8524;
    --busco las cuentas parametrizadas
    IF p_moneda = v_cod_mon_local THEN
      v_cod_moneda := it.pag_gen.fu_obt_mon_local;
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                      3,
                                      NULL,
                                      v_cod_moneda);

      -- Recupera por parametro dinamico la cuenta operativa por moneda
      v_nro_cuenta_w := fug_obt_pardinamico(p_parametro     => 'CTA_OP_WESTERN',
                                            p_cod_modulo    => null,
                                            p_cod_modalidad => null,
                                            p_cod_moneda    => p_moneda,
                                            p_cod_oficina   => null);

    ELSIF p_moneda = v_cod_mon_fuerte THEN
      v_cod_moneda := it.pag_gen.fu_obt_mon_fuerte;
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                      3,
                                      NULL,
                                      v_cod_moneda);
      --Recupera por parametro dinamico la cuenta operativa por moneda
      v_nro_cuenta_w := fug_obt_pardinamico(p_parametro     => 'CTA_OP_WESTERN',
                                            p_cod_modulo    => null,
                                            p_cod_modalidad => null,
                                            p_cod_moneda    => p_moneda,
                                            p_cod_oficina   => null);
    END IF;
    v_nro_cuenta := v_nro_cuenta_w;
  end if;
  if p_tip_op = 'P' then
    IF p_moneda = v_cod_mon_local THEN
      v_cod_moneda := it.pag_gen.fu_obt_mon_local;
    ELSIF p_moneda = v_cod_mon_fuerte THEN
      v_cod_moneda := it.pag_gen.fu_obt_mon_fuerte;
    END IF;
    v_nro_cuenta := v_nro_cuenta_w;
  end if;
  --busco el nro de caja, en base al codigo de usuario que se recibe
  begin
    select nro_caja
      into v_nro_caja
      from cj_cajas
     where cod_usuario = p_usuario
       and estado = 'A'
       and rownum = 1;
  exception
    when no_data_found then
      v_cod_respuesta := 1; -- error
      v_msj_respuesta := 'ERROR: Caja no recuperada';
    when others then
      v_cod_respuesta := 1; -- error
      v_msj_respuesta := 'ERROR: Caja no recuperada';
  end;
  -- Valido el nro de documento recibido
  --se busca persona del cliente
  if p_cod_persona is not null then

    begin
      select cod_persona
        into v_cod_persona
        from ba_personas b
       where b.cod_persona = p_cod_persona;
    exception
      when no_data_found then
        v_cod_respuesta := 2;
        v_msj_respuesta := 'Cliente no  Registrado en el sistema - ' ||
                           p_cod_persona;
      when others then
        v_msj_respuesta := 'Error a buscar cliente';
    end;
  end if;
  -- Valido la moneda
  IF v_nro_boleta IS NULL THEN
    v_cod_respuesta := 3; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta.';
  ELSIF v_mto_efectivo IS NULL OR v_mto_efectivo < 0 THEN
    v_cod_respuesta := 5; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe en Efectivo del pago.';
  ELSE
    BEGIN
      IF v_cod_respuesta = 0 THEN
        -- Verifico la duplicacion del registro
        prj_val_duplicacion(v_nro_caja,
                            v_cod_transaccion,
                            v_cod_moneda,
                            v_nro_boleta,
                            v_cod_respuesta,
                            v_msj_respuesta);
      END IF;
      IF v_cod_respuesta = 0 THEN
        v_msj_respuesta := fuj_ver_impedimentos(v_nro_cuenta,
                                                v_tip_cuenta,
                                                v_cod_transaccion,
                                                v_est_cuenta,
                                                'C'); -- 'C'== CREDITO
        IF v_msj_respuesta IS NOT NULL THEN
          v_cod_respuesta := 6; -- la cuenta tiene impedimentos
        END IF;
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        v_cod_respuesta := 7;
        v_msj_respuesta := 'ERROR: Nro de cuenta no existe!';
      WHEN OTHERS THEN
        v_cod_respuesta := 7;
        v_msj_respuesta := 'ERROR' || SQLERRM;
    END;
    IF v_cod_respuesta = 0 THEN
      -- sino hubo problemas, veo la caja
      -- Obtengo los datos de la caja -
      prj_obt_datos_caja(v_nro_caja,
                         v_cod_moneda,
                         v_cod_oficina,
                         v_fec_caja,
                         v_estado,
                         v_sal_actual,
                         v_sal_cheques);
      IF v_estado = -1 THEN
        v_cod_respuesta := 8; -- error, no existe registro de caja
        v_msj_respuesta := 'Caja inexistente!!';
      ELSIF v_estado IN (0, 2) THEN
        v_cod_respuesta := '004'; -- error
        v_msj_respuesta := 'Caja no esta habilitada';
      ELSIF v_fec_caja <> v_fec_actual THEN
        v_cod_respuesta := 9; -- error
        v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
      END IF;
    END IF;
    IF v_cod_respuesta = 0 THEN
      IF v_msj_respuesta IS NULL THEN
        -- valido el efectivo
        v_msj_respuesta := fuj_val_importe_cnb(v_tipo,
                                               'E',
                                               v_cod_moneda,
                                               v_mto_efectivo,
                                               null,
                                               null,
                                               p_usuario);
      END IF;
      IF v_msj_respuesta IS NOT NULL THEN
        v_cod_respuesta := 10; -- error
      ELSE
        -- Asigno el nro de caja a los movimientos
        pag_cta.pr_nro_caja(to_number(v_nro_caja));
        v_hor_actual := fug_obt_mov_hora;/*it.fug_obt_hor_disponible(v_fec_actual,
                                                  v_hor_actual,
                                                  USER,
                                                  'N');*/
        --inicializo fecha y hora del movimiento poque se usara en el trigger, para que le pueda ver
        pae_cnf.pr_set_variables(v_hor_actual, 0);
        if p_tip_op = 'E' then

          v_nro_secuencia := pae_cnf.g_nro_secuencia;
          IF v_mto_efectivo > 0 THEN
            v_tot_efectivo := v_mto_efectivo;
            --Debito Caja
            --Insertamos en ge movimientos el movimiento correspondiente al debito en caja
            begin
              v_numero_secuencia      := nvl(v_numero_secuencia, 0) + 1;
              r_gmovi.cod_usuario     := user;
              r_gmovi.hora            := v_hor_actual;
              r_gmovi.fecha           := v_fec_actual;
              r_gmovi.nro_secuencia   := v_numero_secuencia;
              r_gmovi.cod_modulo      := 9;
              r_gmovi.cod_modalidad   := 91;
              r_gmovi.cod_oficina     := v_cod_oficina;
              r_gmovi.cod_moneda      := v_cod_moneda;
              r_gmovi.fec_valor       := trunc(sysdate);
              r_gmovi.cod_tra_padre   := v_cod_tra_padre_wu;
              r_gmovi.cod_mod_padre   := v_codigo_modulo;
              r_gmovi.cod_mad_padre   := v_codigo_modalidad;
              r_gmovi.cod_transaccion := 8509;
              r_gmovi.monto           := p_monto_op;
              r_gmovi.nro_documento   := p_mov_id;
              r_gmovi.nro_documento3  := 1;
              r_gmovi.referencia      := p_mtcn;
              r_gmovi.cod_ofi_origen  := v_cod_oficina;
              r_gmovi.emi_aviso       := 'N';
              r_gmovi.concepto        := 'Debito en caja';
              r_gmovi.estado          := 'N';
              r_gmovi.reversado       := 'N';
              r_gmovi.cod_rubro       := null;
              r_gmovi.cod_tasa        := null;
              r_gmovi.val_tasa        := null;
              r_gmovi.tip_mov_rubro   := 'D';
              r_gmovi.nro_caja        := v_nro_caja;
              if v_cod_moneda = v_cod_mon_local then
                r_gmovi.cotizacion    := null; --v_cotizacion;
                r_gmovi.mto_equ_local := null; --v_equivalente;
              else
                r_gmovi.cotizacion    := v_cotizacion; --v_cotizacion;
                r_gmovi.mto_equ_local := round(p_monto_op * v_cotizacion,
                                               0); --v_equivalente;
              end if;
              pag_gen.pr_ins_ge_movimiento(r_gmovi);
            exception
              when others then
                -- hubo error en la insercion de registros ge_movimientos
                v_cod_respuesta := 11;
                v_msj_respuesta := 'ERROR' || SQLERRM;
            end;
            v_cal_iva := round(nvl(p_monto_co, 0) * (v_val_tasa / 100),
                               v_redondeo);
            v_monto   := nvl(p_monto_op, 0) - nvl(p_monto_co, 0) -
                         nvl(v_cal_iva, 0);
            --Credito Envio Western
            if v_cod_moneda = v_cod_mon_fuerte then
              v_mto_equ_local := round(v_monto * v_cotizacion, 0);
            else
              v_mto_equ_local := null;
            end if;
            pag_cta.pr_set_referencia(p_referencia => p_mtcn);
            pag_cta.pr_set_nro_documento3(1);
            pag_cta.pr_act_operacion(p_nro_cuenta      => v_nro_cuenta_w,
                                     p_hora            => v_hor_actual,
                                     p_tip_movimiento  => 'C',
                                     p_cod_moneda      => v_cod_moneda,
                                     p_monto           => v_monto,
                                     p_cod_tra_padre   => v_cod_tra_padre_wu,
                                     p_cod_transaccion => v_cod_transaccion_cre,
                                     p_nro_documento   => p_mov_id,
                                     p_cotizacion      => v_cotizacion,
                                     p_cod_ofi_origen  => v_cod_oficina,
                                     p_cod_mod_padre   => v_codigo_modulo,
                                     p_cod_mad_padre   => v_codigo_modalidad,
                                     p_cod_tasa        => null,
                                     p_val_tasa        => null,
                                     p_concepto        => 'Credito Envio Western',
                                     p_emi_aviso       => 'N',
                                     p_nro_secuencia   => v_numero_secuencia,
                                     p_fec_valor       => trunc(sysdate),
                                     p_cod_banco       => null,
                                     p_cod_causa       => null,
                                     p_mto_equ_local   => v_mto_equ_local);
            if pag_cta.g_cod_error <> 0 then
              -- actualizacion con problemas
              v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error, '000'));
              v_msj_respuesta := pag_cta.g_msj_error;
            else
              -- Insertamos en ge movimientos
              if v_cod_moneda = v_cod_mon_fuerte then
                v_mto_equ_local    := round(p_monto_co * v_cotizacion,
                                            0);
                r_gmovi.cotizacion := v_cotizacion;
              else
                v_mto_equ_local    := null;
                r_gmovi.cotizacion := null;
              end if;
              begin
                v_numero_secuencia      := nvl(v_numero_secuencia, 0) + 1;
                r_gmovi.cod_usuario     := user;
                r_gmovi.hora            := v_hor_actual;
                r_gmovi.fecha           := v_fec_actual;
                r_gmovi.nro_secuencia   := v_numero_secuencia;
                r_gmovi.nro_cuenta      := v_nro_cuenta_ah;
                r_gmovi.cod_persona     := v_cod_persona;
                r_gmovi.cod_modulo      := 9;
                r_gmovi.cod_modalidad   := 91;
                r_gmovi.cod_oficina     := v_cod_oficina;
                r_gmovi.cod_moneda      := v_cod_moneda;
                r_gmovi.fec_valor       := trunc(sysdate);
                r_gmovi.cod_tra_padre   := v_cod_tra_padre_wu;
                r_gmovi.cod_mod_padre   := v_codigo_modulo;
                r_gmovi.cod_mad_padre   := v_codigo_modalidad;
                r_gmovi.cod_transaccion := 8507;
                r_gmovi.monto           := p_monto_co;
                r_gmovi.nro_documento   := p_mov_id;
                r_gmovi.nro_documento3  := 1;
                r_gmovi.referencia      := p_mtcn;
                r_gmovi.cod_ofi_origen  := v_cod_oficina;
                r_gmovi.emi_aviso       := 'N';
                r_gmovi.concepto        := 'Credito comision por envio Western';
                r_gmovi.estado          := 'N';
                r_gmovi.reversado       := 'N';
                r_gmovi.cod_rubro       := null;
                r_gmovi.cod_tasa        := 323;
                r_gmovi.val_tasa        := 10;
                r_gmovi.tip_mov_rubro   := 'C';
                r_gmovi.nro_caja        := null;
                r_gmovi.mto_equ_local   := v_mto_equ_local;

                pag_gen.pr_ins_ge_movimiento(r_gmovi);
              exception
                when others then
                  -- hubo error en la insercion de registros ge_movimientos
                  v_cod_respuesta := 12;
                  v_msj_respuesta := sqlerrm;
              end;
              -- Inserta cargo por la transaccion correspondiente al iva
              -- Aumento la secuencia
              begin
                if v_cod_moneda = v_cod_mon_fuerte then
                  v_mto_equ_local    := round(v_cal_iva * v_cotizacion,
                                              0);
                  r_gmovi.cotizacion := v_cotizacion;
                else
                  v_mto_equ_local    := null;
                  r_gmovi.cotizacion := null;
                end if;

                v_numero_secuencia      := v_numero_secuencia + 1;
                r_gmovi.cod_usuario     := user;
                r_gmovi.hora            := v_hor_actual;
                r_gmovi.fecha           := v_fec_actual;
                r_gmovi.nro_secuencia   := v_numero_secuencia;
                r_gmovi.cod_modulo      := 9;
                r_gmovi.cod_modalidad   := 91;
                r_gmovi.cod_oficina     := v_cod_oficina;
                r_gmovi.cod_moneda      := v_cod_moneda;
                r_gmovi.fec_valor       := trunc(sysdate);
                r_gmovi.cod_tra_padre   := v_cod_tra_padre_wu;
                r_gmovi.cod_mod_padre   := 4;
                r_gmovi.cod_mad_padre   := 43;
                r_gmovi.cod_transaccion := 517;
                r_gmovi.monto           := v_cal_iva;
                r_gmovi.nro_documento   := p_mov_id;
                r_gmovi.nro_documento3  := 1;
                r_gmovi.referencia      := p_mtcn;
                r_gmovi.cod_ofi_origen  := v_cod_oficina;
                r_gmovi.emi_aviso       := 'N';
                r_gmovi.concepto        := 'Credito iva comision';
                r_gmovi.estado          := 'N';
                r_gmovi.reversado       := 'N';
                r_gmovi.cod_rubro       := null;
                r_gmovi.cod_tasa        := 323;
                r_gmovi.val_tasa        := 10;
                r_gmovi.tip_mov_rubro   := 'C';
                r_gmovi.nro_caja        := null;
                r_gmovi.mto_equ_local   := v_mto_equ_local;
                pag_gen.pr_ins_ge_movimiento(r_gmovi);
              exception
                when others then
                  -- hubo error en la insercion de registros ge_movimientos
                  v_cod_respuesta := 13;
                  v_msj_respuesta := sqlerrm;
              end;
              if v_cod_respuesta = 0 then
                lp_gen_transaccion();
              end if;
            end if;
          end if;
        end if;
        if p_tip_op = 'P' then
          v_cod_transaccion_cre := 8016;
          --Recupera la descripcion del servicio
          begin
            select significado
              into v_desc_servicio
              from ba_cod_referencias t
             where t.dominio = 'DES_OPE_COB_SER'
               and t.val_minimo = p_cod_serv;
          exception
            when no_data_found then
              null;
            when others then
              v_cod_respuesta := 2;
              v_msj_respuesta := 'Error al recuperar descripcion del servicio - ' ||
                                 p_cod_serv;

          end;
          IF v_mto_efectivo > 0 THEN
            v_tot_efectivo := v_mto_efectivo;
            if p_cod_proc = 3 then
              --Aqui genera operacion y movimiento cuando es por BANCARD
              --Recupera por parametro dinamico la cuenta operativa de bancard por moneda
              v_nro_cuenta_b := fug_obt_pardinamico(p_parametro     => 'CTA_OP_BANCARD',
                                                    p_cod_modulo    => null,
                                                    p_cod_modalidad => null,
                                                    p_cod_moneda    => p_moneda,
                                                    p_cod_oficina   => null);

              --Credito pago de servicios bancard
              v_numero_secuencia := pae_cnf.g_nro_secuencia;
              pag_cta.pr_set_referencia(p_referencia => p_mov_id);
              pag_cta.pr_set_nro_documento3(1);
              if v_cod_moneda = v_cod_mon_fuerte then
                v_mto_equ_local := round(p_monto_op * v_cotizacion,
                                         0);
              else
                v_mto_equ_local := null;
              end if;
              pag_cta.pr_act_operacion(p_nro_cuenta      => v_nro_cuenta_b,
                                       p_hora            => v_hor_actual,
                                       p_tip_movimiento  => 'C',
                                       p_cod_moneda      => v_cod_moneda,
                                       p_monto           => p_monto_op,
                                       p_cod_tra_padre   => 8526,
                                       p_cod_transaccion => 8016,
                                       p_nro_documento   => p_mov_id,
                                       p_cotizacion      => null,
                                       p_cod_ofi_origen  => v_cod_oficina,
                                       p_cod_mod_padre   => v_codigo_modulo,
                                       p_cod_mad_padre   => v_codigo_modalidad,
                                       p_cod_tasa        => null,
                                       p_val_tasa        => null,
                                       p_concepto        => 'Credito pago servicio Bancard',
                                       p_emi_aviso       => 'N',
                                       p_nro_secuencia   => v_numero_secuencia,
                                       p_fec_valor       => trunc(sysdate),
                                       p_cod_banco       => null,
                                       p_cod_causa       => null,
                                       p_mto_equ_local   => v_mto_equ_local);
              if pag_cta.g_cod_error <> 0 then
                -- actualizacion con problemas
                v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error, '000'));
                v_msj_respuesta := pag_cta.g_msj_error;
              else
                --Debito Caja
                --Insertamos en ge movimientos el movimiento correspondiente al debito en caja
                begin
                  if v_cod_moneda = v_cod_mon_fuerte then
                    v_mto_equ_local    := round(p_monto_op * v_cotizacion,
                                                0);
                    r_gmovi.cotizacion := v_cotizacion;
                  else
                    v_mto_equ_local    := null;
                    r_gmovi.cotizacion := null;
                  end if;

                  v_numero_secuencia      := nvl(v_numero_secuencia, 0) + 1;
                  r_gmovi.cod_usuario     := user;
                  r_gmovi.hora            := v_hor_actual;
                  r_gmovi.fecha           := v_fec_actual;
                  r_gmovi.nro_secuencia   := v_numero_secuencia;
                  r_gmovi.cod_modulo      := 9;
                  r_gmovi.cod_modalidad   := 91;
                  r_gmovi.cod_oficina     := v_cod_oficina;
                  r_gmovi.cod_moneda      := v_cod_moneda;
                  r_gmovi.fec_valor       := trunc(sysdate);
                  r_gmovi.cod_tra_padre   := v_cod_tra_padre_ps;
                  r_gmovi.cod_mod_padre   := v_codigo_modulo;
                  r_gmovi.cod_mad_padre   := v_codigo_modalidad;
                  r_gmovi.cod_transaccion := 8509;
                  r_gmovi.monto           := p_monto_op;
                  r_gmovi.nro_documento   := p_mov_id;
                  r_gmovi.nro_documento3  := 1;
                  r_gmovi.referencia      := p_mov_id;
                  r_gmovi.cod_ofi_origen  := v_cod_oficina;
                  r_gmovi.emi_aviso       := 'N';
                  r_gmovi.concepto        := 'Debito en caja';
                  r_gmovi.estado          := 'N';
                  r_gmovi.reversado       := 'N';
                  r_gmovi.cod_rubro       := null;
                  r_gmovi.cod_tasa        := null;
                  r_gmovi.val_tasa        := null;
                  r_gmovi.tip_mov_rubro   := 'D';
                  r_gmovi.nro_caja        := v_nro_caja;
                  r_gmovi.mto_equ_local   := v_mto_equ_local; --v_equivalente;
                  --r_gmovi.cod_persona     := v_cod_persona;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi);
                exception
                  when others then
                    -- hubo error en la insercion de registros ge_movimientos
                    v_cod_respuesta := 11;
                    v_msj_respuesta := 'ERROR' || SQLERRM;
                end;

                if v_cod_respuesta = 0 then
                  begin
                    insert into bw_pag_servicios
                      (nro_cuenta,
                       cod_servicio,
                       fecha,
                       hora,
                       nro_transaccion,
                       nro_lote,
                       ip_usuario,
                       terminal,
                       cod_moneda,
                       mto_transaccion,
                       mto_comision,
                       mto_mora,
                       mto_interes,
                       reversado,
                       mto_debito,
                       cod_mon_servicio,
                       red_pago,
                       des_servicio,
                       par_enviados)
                    VALUES
                      (v_nro_cuenta_b,
                       p_cod_serv,
                       v_fec_actual,
                       v_hor_actual,
                       p_mov_id,
                       0,
                       null,
                       null,
                       v_cod_moneda,
                       p_monto_op,
                       null,
                       null,
                       null,
                       'N',
                       p_monto_op,
                       null,
                       3,
                       v_desc_servicio,
                       null);
                  exception
                    when others then
                      v_cod_respuesta := 9;
                      v_msj_respuesta := 'Error al procesar transaccion' ||
                                         sqlerrm;
                      rollback;
                  end;
                end if;
                if v_cod_respuesta = 0 then
                  lp_gen_transaccion();
                else
                  rollback;
                end if;
              end if;
            elsif p_cod_proc = 1 then
              --Debito Caja
              --Insertamos en ge movimientos el movimiento correspondiente al debito en caja
              begin
                if v_cod_moneda = v_cod_mon_fuerte then
                  v_mto_equ_local    := round(p_monto_op * v_cotizacion,
                                              0);
                  r_gmovi.cotizacion := v_cotizacion;
                else
                  v_mto_equ_local    := null;
                  r_gmovi.cotizacion := null;
                end if;
                v_numero_secuencia      := nvl(v_numero_secuencia, 0) + 1;
                r_gmovi.cod_usuario     := user;
                r_gmovi.hora            := v_hor_actual;
                r_gmovi.fecha           := v_fec_actual;
                r_gmovi.nro_secuencia   := v_numero_secuencia;
                r_gmovi.cod_modulo      := 9;
                r_gmovi.cod_modalidad   := 91;
                r_gmovi.cod_oficina     := v_cod_oficina;
                r_gmovi.cod_moneda      := v_cod_moneda;
                r_gmovi.fec_valor       := trunc(sysdate);
                r_gmovi.cod_tra_padre   := v_cod_tra_padre_ps;
                r_gmovi.cod_mod_padre   := v_codigo_modulo;
                r_gmovi.cod_mad_padre   := v_codigo_modalidad;
                r_gmovi.cod_transaccion := 8509;
                r_gmovi.monto           := p_monto_op;
                r_gmovi.nro_documento   := p_mov_id;
                r_gmovi.nro_documento3  := 1;
                r_gmovi.referencia      := p_mov_id;
                r_gmovi.cod_ofi_origen  := v_cod_oficina;
                r_gmovi.emi_aviso       := 'N';
                r_gmovi.concepto        := 'Debito en caja';
                r_gmovi.estado          := 'N';
                r_gmovi.reversado       := 'N';
                r_gmovi.cod_rubro       := null;
                r_gmovi.cod_tasa        := null;
                r_gmovi.val_tasa        := null;
                r_gmovi.tip_mov_rubro   := 'D';
                r_gmovi.nro_caja        := v_nro_caja;
                r_gmovi.mto_equ_local   := v_mto_equ_local; --v_equivalente;
                pag_gen.pr_ins_ge_movimiento(r_gmovi);
              exception
                when others then
                  -- hubo error en la insercion de registros ge_movimientos
                  v_cod_respuesta := 11;
                  v_msj_respuesta := 'ERROR' || SQLERRM;
              end;

              --Busca el ente y la cuenta operativa definida en ge_par_entes
              --Primero buscv_nro_cuenta_fielcoba el codigo del servicio en el parametro COD_SER_COBSER
              begin
                select cod_ente
                  into v_cod_ente
                  from ge_par_entes
                 where parametro = 'COD_SER_FIELCO'
                   and val_parametro = p_cod_serv;
              exception
                when no_data_found then
                  v_cod_respuesta := 5;
                  v_msj_respuesta := 'Ente no Registrado para el servicio.' ||
                                     p_cod_serv;
                when others then
                  v_cod_respuesta := 5;
                  v_msj_respuesta := 'Ente no Registrado para el servicio.' ||
                                     p_cod_serv;
              end;
              --Aqui busca la cuenta operativa del servicio ( fielcobranzas)
              v_nro_cuenta_fielcob := it.fug_obt_parentes(v_cod_ente,
                                                          'CTA_OP_FIELCOBRANZAS');

              --Aqui busca la tasa de la comision si corresponde
              v_cod_tasa_fielcob := it.fug_obt_parentes(v_cod_ente,
                                                        'COD_TASA_FIELCOBRANZAS');

              if v_cod_tasa_fielcob is not null then

                -- Si tiene configurado tasa para comision, entonces generar movimiento por comision e IVA

                --Valor de tasa
                pag_gen.pr_obt_val_tasa(null,
                                        null,
                                        1,
                                        null,
                                        v_cod_moneda,
                                        null,
                                        null,
                                        v_cod_tasa_fielcob,
                                        null,
                                        null,
                                        v_valor_com,
                                        v_fecha_vig,
                                        v_tip_valor,
                                        v_tipo_tasa);

                IF v_tip_valor = 'P' THEN
                  -- procentaje
                  v_comision := round(p_monto_op * v_valor_com / 100, 0);
                ELSE
                  -- valor --
                  v_comision := v_valor_com;
                END IF;
                -- Monto IVA
                v_cal_iva := round(nvl(v_comision, 0) * (v_val_tasa / 100),
                                   v_redondeo);
                --calcula el monto del credito
                v_mon_cre := p_monto_op -
                             (nvl(v_comision, 0) + nvl(v_cal_iva, 0));
                begin
                  if v_cod_moneda = v_cod_mon_fuerte then
                    v_mto_equ_local    := round(v_comision * v_cotizacion,
                                                0);
                    r_gmovi.cotizacion := v_cotizacion;
                  else
                    v_mto_equ_local    := null;
                    r_gmovi.cotizacion := null;
                  end if;
                  --- insertamos en ge movimientos
                  v_numero_secuencia      := nvl(v_numero_secuencia, 0) + 1;
                  r_gmovi.cod_usuario     := user;
                  r_gmovi.hora            := v_hor_actual;
                  r_gmovi.fecha           := v_fec_actual;
                  r_gmovi.nro_secuencia   := v_numero_secuencia;
                  r_gmovi.nro_cuenta      := null;
                  r_gmovi.cod_persona     := v_cod_persona;
                  r_gmovi.cod_modulo      := v_codigo_modulo;
                  r_gmovi.cod_modalidad   := v_codigo_modalidad;
                  r_gmovi.cod_oficina     := v_cod_oficina;
                  r_gmovi.cod_moneda      := v_cod_moneda;
                  r_gmovi.fec_valor       := trunc(sysdate);
                  r_gmovi.cod_tra_padre   := 8526;
                  r_gmovi.cod_mod_padre   := v_codigo_modulo;
                  r_gmovi.cod_mad_padre   := v_codigo_modalidad;
                  r_gmovi.cod_transaccion := 8520;
                  r_gmovi.monto           := v_comision;
                  r_gmovi.referencia      := p_mov_id;
                  r_gmovi.nro_documento   := p_mov_id;
                  r_gmovi.nro_documento2  := p_cod_serv;
                  r_gmovi.nro_documento3  := 1;
                  r_gmovi.cod_ofi_origen  := v_cod_oficina;
                  r_gmovi.emi_aviso       := 'N';
                  r_gmovi.concepto        := 'Credito comision ';
                  r_gmovi.estado          := 'N';
                  r_gmovi.reversado       := 'N';
                  r_gmovi.cod_rubro       := null;
                  r_gmovi.cod_tasa        := v_cod_tasa_fielcob;
                  r_gmovi.val_tasa        := v_val_tasa;
                  r_gmovi.tip_mov_rubro   := 'C';
                  r_gmovi.nro_caja        := null;
                  r_gmovi.mto_equ_local   := v_mto_equ_local;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi);
                exception
                  when others then
                    -- hubo error en la insercion de registros ge_movimientos
                    v_cod_respuesta := 6;
                    v_msj_respuesta := sqlerrm;
                end;
                --- inserta credito de la comision
                -- Aumento la secuencia
                begin
                  if v_cod_moneda = v_cod_mon_fuerte then
                    v_mto_equ_local    := round(v_cal_iva * v_cotizacion,
                                                0);
                    r_gmovi.cotizacion := v_cotizacion;
                  else
                    v_mto_equ_local    := null;
                    r_gmovi.cotizacion := null;
                  end if;
                  v_numero_secuencia      := v_numero_secuencia + 1;
                  r_gmovi.cod_usuario     := user;
                  r_gmovi.hora            := v_hor_actual;
                  r_gmovi.fecha           := v_fec_actual;
                  r_gmovi.nro_secuencia   := v_numero_secuencia;
                  r_gmovi.cod_modulo      := v_codigo_modulo;
                  r_gmovi.cod_modalidad   := v_codigo_modalidad;
                  r_gmovi.cod_oficina     := v_cod_oficina;
                  r_gmovi.cod_moneda      := v_cod_moneda;
                  r_gmovi.fec_valor       := trunc(sysdate);
                  r_gmovi.cod_tra_padre   := 8526;
                  r_gmovi.cod_mod_padre   := v_codigo_modulo;
                  r_gmovi.cod_mad_padre   := v_codigo_modalidad;
                  r_gmovi.cod_transaccion := 517;
                  r_gmovi.monto           := v_cal_iva;
                  r_gmovi.referencia      := p_mov_id;
                  r_gmovi.nro_documento   := p_mov_id;
                  r_gmovi.nro_documento2  := p_cod_serv;
                  r_gmovi.nro_documento3  := 1;
                  r_gmovi.cod_ofi_origen  := v_cod_oficina;
                  r_gmovi.emi_aviso       := 'N';
                  r_gmovi.concepto        := 'Credito iva comision';
                  r_gmovi.estado          := 'N';
                  r_gmovi.reversado       := 'N';
                  r_gmovi.cod_rubro       := null;
                  r_gmovi.cod_tasa        := v_cod_tasa_fielcob;
                  r_gmovi.val_tasa        := v_val_tasa;
                  r_gmovi.tip_mov_rubro   := 'C';
                  r_gmovi.nro_caja        := null;
                  r_gmovi.cod_persona     := v_cod_persona;
                  r_gmovi.mto_equ_local   := v_mto_equ_local;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi);
                exception
                  when others then
                    -- hubo error en la insercion de registros ge_movimientos
                    v_cod_respuesta := 7;
                    v_msj_respuesta := sqlerrm;
                end;
              elsif v_cod_tasa_fielcob is null then
                v_mon_cre := p_monto_op;
              end if;
              -- Credito pago servicio Bancard
              pag_cta.pr_set_nro_documento2(p_nro_documento2 => p_cod_serv);
              pag_cta.pr_set_referencia(p_referencia => p_mov_id);
              pag_cta.pr_set_nro_documento3(1);
              if v_cod_moneda = v_cod_mon_fuerte then
                v_mto_equ_local := round(v_cal_iva * v_cotizacion,
                                         0);
              else
                v_mto_equ_local := null;
              end if;
              pag_cta.pr_act_operacion(p_nro_cuenta      => v_nro_cuenta_fielcob,
                                       p_hora            => v_hor_actual,
                                       p_tip_movimiento  => 'C',
                                       p_cod_moneda      => v_cod_moneda,
                                       p_monto           => v_mon_cre,
                                       p_cod_tra_padre   => 8526,
                                       p_cod_transaccion => v_cod_transaccion_cre,
                                       p_nro_documento   => p_mov_id,
                                       p_cotizacion      => null,
                                       p_cod_ofi_origen  => v_cod_oficina,
                                       p_cod_mod_padre   => v_codigo_modulo,
                                       p_cod_mad_padre   => v_codigo_modalidad,
                                       p_cod_tasa        => null,
                                       p_val_tasa        => null,
                                       p_concepto        => 'Credito pago servicio Fielcobranzas',
                                       p_emi_aviso       => 'N',
                                       p_nro_secuencia   => v_numero_secuencia,
                                       p_fec_valor       => trunc(sysdate),
                                       p_cod_banco       => null,
                                       p_cod_causa       => null,
                                       p_mto_equ_local   => v_mto_equ_local);
              if pag_cta.g_cod_error <> 0 then
                -- actualizacion con problemas
                v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error, '000'));
                v_msj_respuesta := pag_cta.g_msj_error;
              else
                begin
                  insert into bw_pag_servicios
                    (nro_cuenta,
                     cod_servicio,
                     fecha,
                     hora,
                     nro_transaccion,
                     nro_lote,
                     ip_usuario,
                     terminal,
                     cod_moneda,
                     mto_transaccion,
                     mto_comision,
                     mto_mora,
                     mto_interes,
                     reversado,
                     mto_debito,
                     cod_mon_servicio,
                     red_pago,
                     des_servicio,
                     par_enviados)
                  VALUES
                    (v_nro_cuenta_fielcob,
                     p_cod_serv,
                     v_fec_actual,
                     v_hor_actual,
                     p_mov_id,
                     0,
                     null,
                     null,
                     v_cod_moneda,
                     p_monto_op,
                     null,
                     null,
                     null,
                     'N',
                     p_monto_op,
                     null,
                     5,
                     v_desc_servicio,
                     null);

                exception
                  when others then
                    v_cod_respuesta := 9;
                    v_msj_respuesta := 'Error al procesar transaccion' ||
                                       sqlerrm;
                    rollback;
                end;
              end if;
              if v_cod_respuesta = 0 then
                lp_gen_transaccion();
              else
                rollback;
              end if;
            end if;
          end if;
        end if; --fin pago de servicio
      end if;
    end if;
  end if;
  -- mensaje final sino hubo errores
  IF v_cod_respuesta = 0 THEN
    -- sino hubo problemas, se carga mensaje por defecto
    v_msj_respuesta := 'OK';
  else
    v_msj_respuesta := nvl(v_msj_respuesta,'NOK');
  END IF;
  /* falta armar el mensaje de respuesta */
  v_msj_salida := v_msj_respuesta;

  RETURN(v_msj_salida);

EXCEPTION
  WHEN OTHERS THEN
    v_cod_respuesta := '999';
    v_msj_salida    := 'NOK';
    RETURN(v_msj_salida);
END FUJ_PRO_TRANSACCION_8509;
/

