CREATE OR REPLACE PACKAGE BODY IT.PAG_RIE is
   -- Iniciar automáticamente el circuito cuando la operación Excede el Monto Máximo
   PROCEDURE PR_OPE_RIESGO
   (  p_fecha         IN ge_mov_autorizaciones.fecha%TYPE,
      p_hora          IN ge_mov_autorizaciones.hora%TYPE,
      p_cod_usuario   IN ge_mov_autorizaciones.cod_usuario%TYPE,
      p_cod_tra_padre IN ge_mov_autorizaciones.cod_tra_padre%TYPE,
      p_cod_mod_padre IN ge_mov_autorizaciones.cod_mod_padre%TYPE,
      p_cod_mad_padre IN ge_mov_autorizaciones.cod_mad_padre%TYPE,
      p_nro_cuenta    IN ge_cuentas.nro_cuenta%TYPE,
      p_cod_persona   IN ba_personas.cod_persona%TYPE,
      p_tip_operacion IN ge_mov_autorizaciones.tip_operacion%TYPE,
      p_monto         IN ge_movimientos.monto%TYPE,
      p_nro_documento IN ge_movimientos.nro_documento%TYPE DEFAULT NULL,
      p_cod_moneda    IN ba_monedas.cod_moneda%type,
      p_cotizacion    IN ge_movimientos.cotizacion%TYPE ,
      p_nro_pedido    IN OUT NUMBER

    ) IS
      v_cod_error        NUMBER;
      v_sig_valor        NUMBER;
      v_cod_persona      ba_usuarios.cod_persona%TYPE;
      v_es_rie_operativo VARCHAR2(1) := 'N';
      v_mto_maximo       NUMBER;
      v_cantidad         NUMBER;
      v_tip_operacion    NUMBER;
      v_mto              NUMBER(18, 2);
      v_cod_mon_fuerte   ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_FUERTE;
      v_mto_mon_fuerte   ge_movimientos.monto%type;
      v_monto            ge_movimientos.monto%type;
      v_cod_ofi_usuario  ba_oficinas.cod_oficina%type;
      v_cod_modulo       ba_modulos.cod_modulo%type;
      v_cod_modalidad    ge_modalidades.cod_modalidad%type;
      v_cod_oficina      ba_oficinas.cod_oficina%type;
           -- C.D Fase III---
      v_mto_maximo_2       NUMBER;
      v_mto_maximo_3       NUMBER;
      v_grupo             number;



   BEGIN
    --Para que se pueda habilitar o deshabilitar la generación del workflow de control dual por módulo, modalidad y moneda.
    IF nvl(fug_obt_pardinamico('IND_REA_CON_DUAL',p_cod_mod_padre,p_cod_mad_padre,p_cod_moneda,null,null),'N') = 'S' THEN
      /*
      || Parámetro P_TIP_OPERACION
      || =========================
      || O = Operaciones de Riesgo Operativo.
      || R = Pago o Cancelación contra cuentas contables.
      */
      v_mto_mon_fuerte := pag_gen.fu_con_mon_a_moneda(p_cod_moneda, v_cod_mon_fuerte,p_monto,NULL,NULL, p_cotizacion);
      v_monto := v_mto_mon_fuerte;
      -- C.D.Fase III--
      v_grupo := pag_rie.fu_obt_grupo(p_cod_mod_padre, p_cod_mad_padre, p_cod_tra_padre);
      v_mto_maximo_3 := fug_obt_pardinamico('PRE_MTO_RIE_OPERATIVO_3', NULL,NULL, 'USD',null);-- USD 100000
      v_mto_maximo_2 := fug_obt_pardinamico('PRE_MTO_RIE_OPERATIVO_2', NULL,NULL, 'USD',null);-- USD 50000
      v_mto_maximo := fug_obt_pardinamico('PRE_MTO_RIE_OPERATIVO', NULl,NULL, 'USD', null);-- USD 25000

       if v_grupo = 3 then
         if v_mto_mon_fuerte >= v_mto_maximo_3 then
            v_es_rie_operativo := 'S';
         end if;

       elsif v_grupo = 2 then
         if v_mto_mon_fuerte >= v_mto_maximo_2 then
             v_es_rie_operativo := 'S';
         end if;
       elsif  v_grupo = 1 then
         if v_mto_mon_fuerte >= v_mto_maximo then
              v_es_rie_operativo := 'S';
         end if;
        else
           if v_mto_mon_fuerte >= v_mto_maximo then
              v_es_rie_operativo := 'S';
         end if; -- Si no está definido, debe hacer referencia al Monto Maximo -25000

       end if;


          IF v_mto_maximo IS NULL and v_mto_maximo_2 is null and v_mto_maximo_3 is null THEN
            raise_application_error(-20000,
                                    'Parámetros de Montos Máximos de Riesgos Operativos' ||
                                    'no seteado para Modalidad ' ||
                                     fug_obt_des_modal(p_cod_mod_padre,
                                                       p_cod_mad_padre));

         END IF;

      /* Se comenta esta parte, C.D.Fase III, hay Transacciones de Caja en la cual no intervienen Nro. Cuenta*/
      /*  IF p_nro_cuenta IS NULL \*AND p_cod_persona IS NULL*\ THEN
        raise_application_error(-20000, 'Cuenta no puede ser nula '
                                                ||'Nro.Cuenta'|| p_nro_cuenta);
      END IF;*/

      IF p_nro_cuenta IS NOT NULL AND nvl(p_tip_operacion, 'N') = 'O' THEN
         -- Trae la modalidad y el modulo de la cuenta
         Begin
            select g.cod_modulo, g.cod_modalidad, g.cod_oficina
              into v_cod_modulo, v_cod_modalidad, v_cod_oficina
              from ge_cuentas g
             where g.nro_cuenta = p_nro_cuenta;
         Exception
            When NO_DATA_FOUND Then
               raise_application_error(-20000, 'Error: Cuenta Inexistente!!!');
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Error Obt.Cuenta ' || SQLERRM);
         End;
         if ((v_cod_modulo in ('5','7'))
         or (v_cod_modalidad in (31,41,42,43,44,45,46,47,48,442,455,32,33,34,35,36)))  THEN
            pag_cta.pr_obt_cuenta(p_nro_cuenta);
            IF pag_cta.g_cod_error <> 0 then
               raise_application_error(-20000, pag_cta.fu_obt_msj_error);
            end if;
         end if;
        /* Comentado esta parte, por cambio de funcionalidad -- C.D.Fase III
         v_mto_maximo := fug_obt_pardinamico('PRE_MTO_RIE_OPERATIVO', NULL,
                                              NULL, 'USD',--POR EL MOMENTO FIJO
                                              v_cod_oficina);
         IF v_mto_maximo IS NULL THEN
            raise_application_error(-20000,
                                    'Parámetro de Monto Máximo Riesgo Operativo' ||
                                    'no seteado para Modalidad ' ||
                                     fug_obt_des_modal(pag_cta.g_ctas.cod_modulo,
                                                       pag_cta.g_ctas.cod_modalidad) ||
                                     ' - Oficina ' ||
                                     fue_obt_des_oficina(pag_cta.g_ctas.cod_oficina));
         END IF;
         IF nvl(v_monto, 0) >= nvl(v_mto_maximo, 0) THEN
            v_es_rie_operativo := 'S';
         END IF;
         */
     END IF;
      IF nvl(p_tip_operacion, 'N') = 'R' OR nvl(v_es_rie_operativo, 'N') = 'S' THEN
        SELECT COUNT(1)
           INTO v_cantidad
           FROM ge_mov_autorizaciones
          WHERE fecha = p_fecha
            AND cod_tra_padre = p_cod_tra_padre
            AND cod_mod_padre = p_cod_mod_padre
            AND cod_mad_padre = p_cod_mad_padre
            AND nvl(nro_cuenta, 'x') = nvl(p_nro_cuenta, 'x')
            AND monto = p_monto -- Monto Original -- C.D.Fase II
            AND cod_moneda  = p_cod_moneda -- Moneda Original
            AND nvl(nro_documento,p_nro_documento) = p_nro_documento -- C.D.Fase III /*Se agrega nvl para evitar duplicación del pedido de autorización, no todas las veces se guarda el nro documento*/
            AND estado = 'S';
         ---
         IF nvl(v_cantidad, 0) > 0 THEN
            raise_application_error(-20000, 'ERROR. Ya existe solicitud similar'||p_cod_tra_padre||'-'||p_cod_mod_padre
           ||'-'|| p_cod_mad_padre||'-'||p_nro_cuenta);
         ELSE
           -- DYDMR-10041 IEC 06
           SELECT s_cod_autorizacion.nextval INTO v_sig_valor FROM dual;
           IF p_cod_persona IS NULL THEN
               IF p_nro_cuenta IS NOT NULL THEN
                  v_cod_persona := fug_obt_cli_principal(p_nro_cuenta);
               ELSE
                  BEGIN
                     SELECT cod_persona INTO v_cod_persona
                       FROM ba_usuarios WHERE cod_usuario = USER;
                  EXCEPTION
                     WHEN no_data_found THEN
                        raise_application_error(-20000,
                                                'Persona no registrada para usuario '
                                                || USER);
                     WHEN OTHERS THEN
                        raise_application_error(-20000,
                                                'Error Obt.Persona p/usuario '
                                                || SQLERRM);
                  END;
               END IF;
             ELSE
               v_cod_persona := p_cod_persona;
            END IF;
            v_tip_operacion := fug_obt_pardinamico('COD_TIP_CIR_CON_OPE'); -- Circuito de WK
            v_mto           := nvl(v_monto, 0);
            v_cod_ofi_usuario := fug_obt_ofi_usuario(user); -- Oficina del Usuario

            BEGIN
               INSERT INTO ge_mov_autorizaciones
                  (nro_pedido, fecha, hora, cod_usuario, cod_tra_padre, cod_mod_padre,
                   cod_mad_padre, nro_cuenta, cod_persona, mto_mon_fuerte,
                   tip_operacion, nro_documento, estado, est_movimiento, est_cuenta,
                   cod_oficina, monto, cod_moneda)
               VALUES
                  (v_sig_valor, p_fecha, p_hora, p_cod_usuario,p_cod_tra_padre,p_cod_mod_padre,
                   p_cod_mad_padre, p_nro_cuenta, v_cod_persona, v_mto,
                   p_tip_operacion, p_nro_documento, 'S',null, null,
                   v_cod_ofi_usuario,p_monto,p_cod_moneda);-- C.D.Fase II
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20000, 'ERROR.insert ge_mov_autorizaciones:'
                                                  || SQLERRM);
            END;
            -- inicia el circuito
            v_cod_error := paw_cir.fu_ini_circuito(v_tip_operacion, v_sig_valor, v_cod_persona);
            IF v_cod_error <> 0 THEN
               raise_application_error(-20067, 'Error al generar Circuito. ' || SQLERRM);
            END IF;
         END IF;
      END IF;
      p_nro_pedido := nvl(v_sig_valor, 0);
    END IF;
   END;

   -- Obtiene el usuario que solicitó el pedido
   FUNCTION FU_OBT_USU_AUTORIZACION (p_referencia wf_circuitos.referencia%TYPE,
                                     p_cod_tip_circuito wf_circuitos.cod_tip_circuito%TYPE )
     RETURN VARCHAR2 IS
      v_cod_usuario ba_usuarios.cod_usuario%TYPE;
  BEGIN
       IF p_cod_tip_circuito = fug_obt_pardinamico('COD_TIP_CIR_CON_OPE') THEN -- Pedidos de Autorizaciones
         BEGIN
           SELECT cod_usuario
             INTO v_cod_usuario
             FROM ge_mov_autorizaciones
            WHERE nro_pedido = p_referencia;
           RETURN v_cod_usuario;
         EXCEPTION
            WHEN OTHERS THEN
            RETURN null;
         END;
        elsif p_cod_tip_circuito = fug_obt_pardinamico('COD_TIP_CIR_REV_OPE') then  -- Pedidos de Recepciones
          BEGIN
            SELECT usu_insercion
              INTO v_cod_usuario
              FROM ge_aut_reversiones
             WHERE nro_pedido = p_referencia;
            RETURN v_cod_usuario;
          EXCEPTION
             WHEN OTHERS THEN
             RETURN null;
          END;
        end if;
        RETURN null;
 EXCEPTION
   WHEN OTHERS THEN
    RETURN null;
 END;

   /**
    || Procedimiento para aprobar los pedidos de Riesgo operativo
    || Se ejecuta desde el trigger de la tabla GE_MOV_AUTORIZACIONES
    || Se pasan todos los campos como parámetro, de lo contrario da error de Mutating
   **/
PROCEDURE PR_APR_PEDIDO(p_nro_pedido          IN ge_mov_autorizaciones.nro_pedido%TYPE,
                        p_fecha               IN ge_mov_autorizaciones.fecha%TYPE,
                        p_hora                IN ge_mov_autorizaciones.hora%TYPE,
                        p_cod_usuario         IN ge_mov_autorizaciones.cod_usuario%TYPE,
                        p_cod_tra_padre       IN ge_mov_autorizaciones.cod_tra_padre%TYPE,
                        p_cod_mod_padre       IN ge_mov_autorizaciones.cod_mod_padre%TYPE,
                        p_cod_mad_padre       IN ge_mov_autorizaciones.cod_mad_padre%TYPE,
                        p_nro_cuenta          IN ge_mov_autorizaciones.nro_cuenta%TYPE,
                        p_cod_persona         IN ge_mov_autorizaciones.cod_persona%TYPE,
                        p_mto_mon_fuerte      IN ge_mov_autorizaciones.mto_mon_fuerte%TYPE,
                        p_tip_operacion       IN ge_mov_autorizaciones.tip_operacion%TYPE,
                        p_nro_documento       IN ge_mov_autorizaciones.nro_documento%TYPE DEFAULT NULL,
                        p_cod_usu_autorizador IN ge_mov_autorizaciones.cod_usu_autorizador%TYPE,
                        p_concepto            IN ge_mov_autorizaciones.concepto%TYPE,
                        p_estado              IN ge_mov_autorizaciones.estado%TYPE,
                        p_est_movimiento      IN ge_mov_autorizaciones.est_movimiento%TYPE,
                        p_est_cuenta          IN ge_mov_autorizaciones.est_cuenta%TYPE, -- solo se carga cuando es Venta/Cobro de Documentos
                        p_observacion         IN ge_mov_autorizaciones.observacion%TYPE) IS

  v_existe          varchar2(1) := 'N';
  v_nro_secuencia   ge_movimientos.nro_secuencia%type;
  v_cod_mod_padre   ge_movimientos.cod_mod_padre%type;
  v_nro_cuenta      ge_movimientos.nro_cuenta%type;
  v_cod_rubro       ge_movimientos.cod_rubro%type;
  v_monto           ge_movimientos.monto%type;
  v_cod_mad_padre   ge_movimientos.cod_mod_padre%type;-- C.D Fase III
  v_cod_tra_padre   ge_movimientos.cod_tra_padre%type;-- C.D Fase III
  v_nro_caja        ge_movimientos.nro_caja%type;-- C.D Fase III
  v_caja            ge_movimientos.nro_caja%type;-- C.D Fase III
  v_cod_tra_pad_caja ge_movimientos.cod_tra_padre%type;-- C.D Fase III -- Transacción padre caja
  v_nro_documento3   ge_movimientos.nro_documento3%type;-- C.D Fase III
  v_nro_documento    ge_movimientos.nro_documento%type;-- C.D Fase III
  v_cod_moneda       ge_movimientos.cod_moneda%type;-- C.D Fase III
  v_cod_modulo       ge_movimientos.cod_mod_padre%type;-- C.D Fase III
  v_cod_modalidad    ge_movimientos.cod_mod_padre%type;-- C.D Fase III
  v_afecta          varchar2(1):= (fug_obt_pardinamico('COD_MOD_EST_AFECTA',p_cod_mod_padre));-- C.D Fase II
  v_can_pedido      number;
  v_result          varchar2(1000);
  v_saldo           pr_cuotas.sal_capital%type;
  v_can_cuo_pagada  pr_cta_prestamos.can_cuo_pagadas%type;
  v_cancela         varchar2(1):= 'N';
  v_est_cuota       pr_cuotas.estado%type;
  v_est_movimiento  ge_movimientos.estado%type;



    cursor cu_movimientos  is
    --obtiene los datos del movimiento principal
    Select nro_secuencia, cod_mod_padre, nro_cuenta,
           cod_rubro, monto, cod_mad_padre,cod_tra_padre,
           nro_caja, m.nro_documento3,cod_moneda,
           nro_documento, m.cod_modulo, m.cod_modalidad, estado -- C.D.Fase 4
      from ge_movimientos m
     where reversado = 'N'
       and fecha = p_fecha
       and hora = p_hora
       and cod_usuario = p_cod_usuario
     order by nro_secuencia;


    --obtiene el numero de caja del movimiento principal
   FUNCTION lf_obt_nro_caja
   (
      p_fecha       IN DATE,
      p_hora        IN VARCHAR2,
      p_cod_usuario IN VARCHAR2

   ) RETURN NUMBER IS
      v_nro_caja NUMBER;
   BEGIN
      SELECT nro_caja
        INTO v_nro_caja
        FROM cj_movimientos c
       WHERE estado = 'P'
         AND fecha = p_fecha
         AND hora = p_hora
         AND cod_usuario = p_cod_usuario
         AND nro_secuencia = 1;
      IF v_nro_caja IS NULL THEN
         raise_application_error(-20000,
                                 'ERROR: No Existe Nro. Caja en movimiento con Fecha: ' || p_fecha ||
                                  ', hora:' || p_hora || ', usuario:' || p_cod_usuario);
      ELSE
         RETURN v_nro_caja;
      END IF;
   EXCEPTION
      WHEN no_data_found THEN
       BEGIN
       SELECT nro_caja
        INTO v_nro_caja
        FROM cj_movimientos c
       WHERE estado = 'P'
         AND fecha = p_fecha
         AND hora = p_hora
         AND cod_usuario = p_cod_usuario
         AND nro_secuencia = (select min (nro_secuencia)
                    from cj_movimientos cj
                   where cj.estado = 'P'
                     and cj.fecha = c.fecha
                     and cj.hora = c.hora
                     and cj.cod_usuario = c.cod_usuario);
        IF v_nro_caja IS NULL THEN
         raise_application_error(-20000,
                     'ERROR: No Existe Nro. Caja en movimiento con Fecha: ' || p_fecha ||
                      ', hora:' || p_hora || ', usuario:' || p_cod_usuario);
        ELSE
         RETURN v_nro_caja;
        END IF;

      EXCEPTION -- Para cancelación Automática de circuitos -- C.D.Fase III
         WHEN no_data_found THEN
           BEGIN
             SELECT nro_caja
               INTO v_nro_caja
               FROM cj_movimientos c
              WHERE estado = 'R'
                AND fecha = p_fecha
                AND hora = p_hora
                AND cod_usuario = p_cod_usuario
                AND nro_secuencia = 1;
            IF v_nro_caja IS NULL THEN
              raise_application_error(-20000,
                                     'ERROR: No Existe Nro. Caja en movimiento con Fecha: ' || p_fecha ||
                                      ', hora:' || p_hora || ', usuario:' || p_cod_usuario);
            ELSE
              RETURN v_nro_caja;
            END IF;

        EXCEPTION
          WHEN NO_DATA_FOUND THEN
           raise_application_error(-20000,
                       'ERROR: No existe movimiento. Fecha: ' || p_fecha || ', hora:' ||
                        p_hora || ', usuario:' || p_cod_usuario || ', Caja:' || v_caja);
          WHEN OTHERS THEN
             raise_application_error(-20000,
                         'ERROR: Al buscar movimientos con Fecha: ' || p_fecha ||
                        ', hora:' || p_hora || ', usuario:' || p_cod_usuario || ', Caja:' ||
                        v_nro_caja);
          END;
        WHEN OTHERS THEN
           raise_application_error(-20000,
                       'ERROR: Al buscar movimientos con Fecha: ' || p_fecha ||
                      ', hora:' || p_hora || ', usuario:' || p_cod_usuario || ', Caja:' ||
                      v_nro_caja);
        END;
      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 'ERROR: Al buscar movimientos con Fecha: ' || p_fecha ||
                                  ', hora:' || p_hora || ', usuario:' || p_cod_usuario || ', Caja:' ||
                                  v_nro_caja);
   END lf_obt_nro_caja;
  -- C.D.Fase III--
  procedure lp_gen_transaccion is

    v_mto_efectivo number := 0; -- importe en efectivo
    v_mto_chq_nbco number := 0; -- importe en cheques
    v_mto_chq_obco number := 0; -- importe en otros cheques
    v_total        number := 0; -- importe en efectivo - Transacción 251
    v_nro_caja     varchar2(3);
    v_mon_detallado cj_movimientos.tot_detallado%type;

    v_cod_banco  cc_che_enviados.cod_banco%type;
    v_existe     number;
    v_fec_actual date := pag_cal.fu_obt_fec_actual(1);
    v_cod_mon_local    ba_monedas.cod_moneda%type :=  pag_gen.FU_OBT_MON_LOCAL;
    v_cod_mon_fuerte   ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_fuerte;

   cursor c_act_caja is
      Select a.nro_caja,
             a.tipo,
             a.tip_monto,
             a.monto,
             a.cod_moneda,
             a.nro_cuenta,
             a.tot_detallado,
             a.cod_tra_padre,
             a.nro_documento,
             a.nro_doc_referencia
        From cj_movimientos a
       Where a.fecha = p_fecha
         and a.hora = p_hora
         and a.cod_usuario = p_cod_usuario;
 begin
  for c in c_act_caja loop
    IF c.tip_monto in ('O', 'T','S') Then
     v_mto_chq_obco := c.monto;
     ---DYDMR-8533 - Incidencia SAU - ITGF - Error al Cerrar Caja USD
     IF c.cod_moneda = v_cod_mon_fuerte and c.cod_tra_padre <> 361 Then
       v_mon_detallado := c.tot_detallado;
     End IF;
    ElsIf c.tip_monto = 'C' Then
      v_mto_chq_nbco := c.monto;
    elsif c.tip_monto = 'E' then
      v_mto_efectivo := c.monto;
    End IF;

     if c.cod_tra_padre in (251,353,354,207) then
        begin
          update cj_controles
             set sal_che_otr_bco = nvl(sal_che_otr_bco,0) - nvl( v_mto_chq_obco,0),
                 sal_actual   = nvl(sal_actual, 0) - nvl(v_mto_efectivo, 0),
                 tot_creditos = nvl(tot_creditos, 0) + nvl(v_mto_efectivo, 0),
                 can_creditos = nvl(can_creditos, 0) + 1,
                 estado       = 1 -- abierto
           where nro_caja = to_number(c.nro_caja)
             and cod_moneda = c.cod_moneda
             and fecha = p_fecha;
        Exception
          When Others Then
            raise_application_error(-20000,
                                    'PAG_RIE.Error Al Actualizar Saldo de Caja ' ||
                                    sqlerrm);
        End;

        --
      else
        if c.cod_tra_padre not in (223,224,355)then
           begin
              update cj_controles
                 set tot_che_otr_bco = nvl(tot_che_otr_bco, 0) + nvl(v_mto_chq_obco, 0),
                     sal_che_otr_bco = nvl(sal_che_otr_bco, 0) + nvl(v_mto_chq_obco, 0),
                     tot_che_nue_bco = nvl(tot_che_nue_bco, 0) + nvl(v_mto_chq_nbco, 0),
                     sal_actual      = nvl(sal_actual, 0) + nvl(v_mto_efectivo, 0),
                     tot_debitos     = nvl(tot_debitos, 0) + nvl(v_mto_efectivo, 0),
                     can_debitos     = nvl(can_debitos, 0) + decode(v_mto_efectivo, 0, 0, 1),
                     det_che_otr_bco = nvl(det_che_otr_bco, 0) + nvl(v_mon_detallado, 0), -- detalle del cheque
                     estado          = 1 -- abierto
               where nro_caja = to_number(c.nro_caja)
                 and cod_moneda = c.cod_moneda
                 and fecha = p_fecha;
            Exception
               When Others Then
                  raise_application_error(-20000,
                                       'PAG_RIE.Error Al Actualizar Saldo de Caja ' ||
                                       sqlerrm);

             end;
         end if;
       end if;
        if c.cod_tra_padre  in (223,224)then -- Faltante de Cajas, Sobrante de Cajas
          if c.tipo = 'C' then ----Se resta el saldo--
             begin
               update cj_controles
                  set sal_actual   = nvl(sal_actual, 0) - nvl(v_mto_efectivo, 0),
                      tot_creditos = nvl(tot_creditos, 0) + nvl(v_mto_efectivo, 0),
                      can_creditos = nvl(can_creditos, 0) + 1,
                      estado       = 1 -- abierto
                where nro_caja = to_number(c.nro_caja)
                  and cod_moneda = c.cod_moneda
                  and fecha = p_fecha;
             exception
               When Others Then
                 raise_application_error(-20000,
                                         'PAG_RIE.Error Al Actualizar Saldo de Caja ' ||
                                         sqlerrm);

             end;
            else --D-Se suma al saldo--
               begin
                  update cj_controles
                     set sal_actual  = nvl(sal_actual, 0) + nvl(v_mto_efectivo, 0),
                         tot_debitos = nvl(tot_debitos, 0) + nvl(v_mto_efectivo, 0),
                         can_debitos = nvl(can_debitos, 0) + 1,
                         estado      = 1 -- abierto
                   where nro_caja = to_number(c.nro_caja)
                     and cod_moneda = c.cod_moneda
                     and fecha = p_fecha;
                exception
                  When Others Then
                    raise_application_error(-20000,
                                          'PAG_RIE.Error Al Actualizar Saldo de Caja ' ||
                                          sqlerrm);
                end;
             end if;
           end if;--Faltante de Cajas

      --actualizar retenciones tipo 1 q no se detallan (Trigger cj_movimientos)
      if c.cod_moneda = v_cod_mon_local then
         if c.tip_monto in ('O','T','S') and c.monto > 0 and c.tipo = 'D'
           and c.cod_tra_padre not in (359,360,362,361) then --Los Cobros de Préstamos se deben detallar
            if (c.cod_tra_padre not in (246,245,241,242) and c.tip_monto  in ('T','S','O')) then
              v_mon_detallado := c.monto;
              --si es operación normal
              --actualizar cj_controles
              update cj_controles
                 set det_che_otr_bco = nvl(det_che_otr_bco,0) + nvl(v_mon_detallado,0)
               where fecha      = p_fecha
                 and nro_caja   = to_number(c.nro_caja)
                 and cod_moneda = c.cod_moneda;
            end if;
         end if;
      end if;
      -- Transacción 361, se detalla automáticamente --
      if c.cod_tra_padre = 361 and c.nro_documento is not null  then
         update cj_controles
             set det_che_otr_bco = nvl(det_che_otr_bco,0) + nvl(c.monto,0),
                 estado = 1 -- abierto
           where nro_caja = to_number(c.nro_caja)
             and cod_moneda = c.cod_moneda
             and fecha = p_fecha;
       end if;
       -- Transacción 355 - Detalle de Cheques
       if c.cod_tra_padre = 355 /*and c.nro_documento is not null*/  then
         update cj_controles
             set det_che_nue_bco = nvl(det_che_nue_bco,0) + nvl(c.monto,0),
                 estado = 1 -- abierto
           where nro_caja = to_number(c.nro_caja)
             and cod_moneda = c.cod_moneda
             and fecha = p_fecha;

       end if;

       v_mto_chq_obco:=0;
       v_mto_chq_nbco:=0;
       v_mto_efectivo:=0;
       v_mon_detallado:= 0;

 end loop;
   -- Actualizar cj_sobrantes--
   begin
       update cj_sobrantes s
          set s.estado = 'A'
        where s.fecha = p_fecha
          and s.hora = p_hora
          and s.cod_usuario = p_cod_usuario
          and s.estado = 'P';
    exception
      when others then
         raise_application_error(-20000,
                                          'PAG_RIE.Error Al Actualizar Estado - Caja Sobrantes ' ||
                                          sqlerrm);
    end ;

end;

    procedure lp_act_cheque(p_nro_documento number,
                            p_nro_caja number ) is

      v_nro_cheque     cj_movimientos.nro_documento%type;
      v_nro_referencia cj_movimientos.nro_doc_referencia%type;
      v_cod_banco      number(3);
      v_moneda         ge_movimientos.cod_moneda%type;
      v_cod_oficina    ge_movimientos.cod_oficina%type;
      v_msj varchar2(1);
      v_estado         number(1);         -- estado de la caja
      v_fec_caja       date;              -- fecha de la caja
      v_sal_actual     number(18,2);      -- saldo actual de la caja en efectivo
      v_sal_cheques    number(18,2);     -- saldo actual de la caja en cheques
      v_existe         varchar2(1);

    begin
      begin
        Select a.nro_documento, a.nro_doc_referencia, cod_oficina, cod_moneda
          into v_nro_cheque, v_nro_referencia,v_cod_oficina,v_moneda
          From cj_movimientos a
         Where a.fecha = p_fecha
           and a.hora = p_hora
           and (a.nro_doc_referencia = p_nro_documento or a.nro_documento = p_nro_documento) -- v_nro_documento
           and a.cod_tra_padre in (131, 134, 217, 355) -- para actualizar cheque
           and a.estado = 'N';
      exception
        when no_data_found then
          v_msj:= 'S';
          v_nro_cheque     := null;
          v_nro_referencia := null;
      end;

      if v_msj is null then
          begin
            update ah_retenciones
               set detallado = 'S'
             where cod_ofi_origen = v_cod_oficina
               and nro_documento = to_number(v_nro_referencia)
               and cod_retencion in (0, 8)
               and cod_moneda = v_moneda;
             EXCEPTION
          When Others Then
              raise_application_error(-20000,
                                'PAG_RIE.Error Al Actualizar - AH_RETENCIONES ' ||
                                sqlerrm);
          end;
       end if;

      -- Se detalló automáticamente por la 133
      if p_nro_documento is not null then
         begin
            Select distinct 'S'--,a.nro_documento, a.nro_doc_referencia
              into v_existe--,v_nro_cheque, v_nro_referencia
              From cj_movimientos a
             Where a.fecha = p_fecha
               and a.nro_doc_referencia = p_nro_documento
               and a.estado = 'N'
               and a.cod_tra_padre = 133; --Det. Cheque USD/O/BCOS.DEP. Plaza Local
         exception
            when no_data_found then
              v_existe         := 'N';
              v_nro_cheque     := null;
              v_nro_referencia := null;
         end;
       end if;

       if v_existe = 'S' then
          begin
             update cc_che_enviados e
                set estado = 'I'
              where nvl(e.nro_cuenta, '0') = nvl(p_nro_cuenta, '0')
                and e.nro_boleta = p_nro_documento
                and e.estado = 'P'
                and fecha = p_fecha;
          Exception
            When Others Then
              raise_application_error(-20000,
                                'PAG_RIE.Error Al Actualizar Estado del Cheque - CC_CHE_ENVIADOS ' ||
                                sqlerrm);
           end;
        end if;
    End;
  -------------------------------------------------------------------------------
  -- Función para  Actualizar CC_CHEQUERAS
  FUNCTION LF_ACT_CAM_EST_CHE(p_nro_cuenta varchar2,
                              p_nro_cheque number
                              )  RETURN VARCHAR2 is
  v_estado_ant varchar2(1);
  v_result varchar2(1000);
  v_cuenta_cert varchar2(15);

   Begin
    --- Actualizar el estado del Cheque
        v_estado_ant := pac_che.FU_ACT_CAM_EST_CHE(p_nro_cuenta,p_nro_cheque,'G',v_result,v_cuenta_cert);
        return v_result;
   exception
    when others then
       v_result := 'Error en inserta_cheque_gerencia '||sqlerrm;
       raise_application_error(-20004,v_result);
    End;
   --------------------------------------------------------------------------------------
    /* C.D.Fase 4 - CRODUCUA-2- 01/10/2014*/
     -- Operaciones Vencidas --
    PROCEDURE LP_INS_PR_COBROS(P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE,
                               P_FECHA      IN GE_MOVIMIENTOS.FECHA%TYPE,
                               P_HORA       IN GE_MOVIMIENTOS.HORA%TYPE) IS

    BEGIN
     insert into ov_cobros
       (nro_cuenta,fecha, hora, estado,sal_total,fec_ult_pago, dia_mora,
        mto_total, mto_int_moratorio,mto_int_punitorio,mto_cargo,
        mto_cargo_iva, mto_impuesto,nro_documento,mto_int_mor_cal,mto_int_pun_cal,
        mto_cargo_cal,mto_car_iva_cal, mto_impuesto_cal,
        mto_int_mor_des, mto_int_pun_des, mto_car_des
       )
     select nro_cuenta, p_fecha, p_hora, estado, sal_total, fec_ult_pago, dia_mora,
        mto_total,mto_int_moratorio,mto_int_punitorio,mto_cargo, mto_cargo_iva,
        mto_impuesto,nro_documento, mto_int_mor_cal,mto_int_pun_cal, mto_cargo_cal,
        mto_car_iva_cal, mto_impuesto_cal,
        mto_int_mor_des, mto_int_pun_des, mto_car_des
       from ov_cobros_tmp
      where nro_cuenta = p_nro_cuenta;
     END;

   procedure lp_act_ope_vencidas(p_fecha          ge_movimientos.fecha%type,
                                 p_hora           ge_movimientos.hora%type,
                                 p_cod_usuario    ge_movimientos.cod_usuario%type,
                                 p_nro_secuencia  ge_movimientos.nro_secuencia%type ) is

   r_opeven        ov_cta_vencidas%rowtype;
   v_tot_pag_cap   ov_cta_vencidas.sal_total%type;
   v_pre_sal_cap   ov_cta_vencidas.sal_total%type;
   v_sal_cobrado   pr_cuotas.sal_capital%type;
   v_sal_capital   pr_cuotas.sal_capital%type;
   v_can_prestamo  varchar2(1);
   v_mto_pagado    ge_movimientos.monto%type;
   v_nro_cuenta    ge_movimientos.nro_cuenta%type;
   v_fecha         ge_movimientos.fecha%type;
   v_hora          ge_movimientos.hora%type;
   v_cod_tra_padre ge_movimientos.cod_tra_padre%type;

   begin
     begin
      Select monto, nro_cuenta, fecha, hora, cod_tra_padre
        into v_mto_pagado, v_nro_cuenta, v_fecha, v_hora, v_cod_tra_padre
        from ge_movimientos m
       where reversado = 'N'
         and fecha = p_fecha
         and hora = p_hora
         and cod_usuario = p_cod_usuario
         and p_nro_secuencia = 1
         and rownum = 1 ;
       exception
         when no_data_found then
            v_mto_pagado:= 0;
            v_nro_cuenta:= null;
            v_fecha:= null;
            v_hora := null;
            v_cod_tra_padre:= null;

     end;

   --- Recuperar datos de la cuenta de prestamos
  if v_nro_cuenta is not null then
    pav_ove.pr_obt_dat_ope_vencida(v_nro_cuenta, r_opeven);
    v_tot_pag_cap := 0;
    v_sal_cobrado := v_mto_pagado;

   -- Inserta el Cobro de la Operación Vencida
    lp_ins_pr_cobros(v_nro_cuenta, v_fecha, v_hora);

   --- Hallar el saldo de la operación vencida
    v_pre_sal_cap := nvl(r_opeven.sal_total,0) - nvl(v_tot_pag_cap,0);
    v_tot_pag_cap := nvl(v_tot_pag_cap,0) + nvl(v_sal_cobrado,0);
   --- Verifica si el pago es Parcial o Total
      IF v_pre_sal_cap - nvl(v_sal_cobrado,0) > 0 THEN
        v_can_prestamo := 'N';
      else
        v_can_prestamo := 'S';
      end if;
      --- Actualizar maestro de Operación Vencida
      update ov_cta_vencidas
         set sal_total = nvl(sal_total,0) - nvl(v_sal_cobrado,0),
             estado             = decode(v_can_prestamo,'S','C',estado),
             fec_ult_movimiento = v_fecha,
             hor_ult_movimiento = v_hora,
             fec_cam_estado     = v_fecha
       where nro_cuenta = v_nro_cuenta;

   end if;
  END;-- Fin del agregado

BEGIN
  --Para que se pueda habilitar o deshabilitar la generación del workflow de control dual por módulo, modalidad y moneda.
  IF nvl(fug_obt_pardinamico('IND_REA_CON_DUAL',p_cod_mod_padre,p_cod_mad_padre,null,null,null),'N') = 'S' THEN
  --  Procedimiento Principal--
   Begin -- Debe controlar que no exista pedidos Pendientes
      select count(*)
        into v_can_pedido
        from ge_aut_pedidos a
        where a.cod_usuario = p_cod_usuario
          and a.fecha       = p_fecha
          and a.hora        = p_hora
          and a.estado      = 'S';
     exception
       when no_data_found then
         v_can_pedido := 0;
     End;
     if v_can_pedido > 0 then
        raise_application_error(-20000, 'Operación pendiente de Aprobación. Solicite rechazo del pedido de autorización.'||sqlerrm);
     end if;
     
        -- C.D.Fase III
   if p_cod_mod_padre = 9 and p_cod_mad_padre = 91 then
      v_caja := lf_obt_nro_caja(p_fecha, p_hora, p_cod_usuario); --  ver si corresponde
        SELECT DISTINCT cod_tra_padre
          INTO v_cod_tra_pad_caja
          FROM cj_movimientos a
         WHERE fecha = p_fecha
           AND hora = p_hora
           AND cod_usuario = p_cod_usuario
           AND nro_caja = v_caja;
    end if;



   IF cu_movimientos%ISOPEN THEN
      CLOSE cu_movimientos;
   END IF;
   OPEN cu_movimientos;
   LOOP
      FETCH cu_movimientos INTO v_nro_secuencia, v_cod_mod_padre,v_nro_cuenta,
                                v_cod_rubro, v_monto,v_cod_mad_padre,
                                v_cod_tra_padre, v_nro_caja,v_nro_documento3,
                                v_cod_moneda,v_nro_documento,v_cod_modulo,v_cod_modalidad, v_est_movimiento ;
      EXIT WHEN cu_movimientos%NOTFOUND;


         -- Cobranzas Extranjeras
         if v_cod_mod_padre = 8  and v_monto is not null then
           update ge_movimientos
              set estado = p_est_movimiento,
                  cod_usu_autorizador = user
            where reversado = 'N'
              and estado <> 'N'
              and fecha = p_fecha
              and hora = p_hora
              and cod_usuario = p_cod_usuario
              and nro_secuencia = v_nro_secuencia
              and monto is not null;

          elsif v_cod_mod_padre = 8  and v_monto is null then
             update ge_movimientos
                set estado = 'N',
                    cod_usu_autorizador = user
              where reversado = 'N'
                and estado <> 'N'
                and fecha = p_fecha
                and hora = p_hora
                and cod_usuario = p_cod_usuario
                and nro_secuencia = v_nro_secuencia
                and monto is null;
           end if;
          -- Cobros de Cargos - Comercio Exterior -- C.D.Fase 4
           if v_cod_mod_padre = 8 and v_cod_tra_padre = 150 then
             pal_cam.pr_act_movimientos(p_cod_usuario,
                                        p_fecha,
                                        p_hora,
                                        p_est_movimiento,--'N',
                                        null);
            end if;

           if v_cod_mod_padre = 9 then
             update ge_movimientos
                set estado = 'J',
                    cod_usu_autorizador = user
              where reversado = 'N'
                and estado <> 'N'
                and fecha = p_fecha
                and hora = p_hora
                and cod_usuario = p_cod_usuario
                and nro_secuencia = v_nro_secuencia
                and not exists( Select cod_mod_padre, cod_mad_padre, cod_tra_padre -- C.D Fase III
                                  from cj_movimientos
                                 where cod_usuario = p_cod_usuario
                                   and hora = p_hora
                                   and cod_tra_padre = v_cod_tra_pad_caja
                                   and fecha  = p_fecha
                                   and estado in ('P','N')); -- pendiente
            end if;
            -- C.D.Fase III-- Transacciones originadas en caja
            if v_cod_mod_padre = 9  then --
               -- Para débitos de cuentas originados en caja
                if v_nro_cuenta is not null and v_cod_modulo <> 5 /*and v_cod_modalidad <> 43*/ then --> CRO-MB-17102014: Se excluye para evitar inconsistencias de saldos en cuentas Bancarias.-
                   if v_afecta = 'S'then
                      pal_cam.pr_act_movimientos(p_cod_usuario,
                                   p_fecha,
                                   p_hora,
                                   'N',  -- pasa a 'N-normal el movimiento
                                   to_number(v_caja));-- C.D.Fase III -- Se agrega el nro de Caja, para que no actualice a null, cuando se actualiza el saldo
                   end if;
                 end if;

             update ge_movimientos
                set estado = 'N',--p_est_movimiento
                    cod_usu_autorizador = user
              where reversado = 'N'
                and estado <> 'N'
                and fecha = p_fecha
                and hora = p_hora
                and cod_usuario = p_cod_usuario
                and nro_secuencia = v_nro_secuencia
                and exists( Select cod_mod_padre, cod_mad_padre, cod_tra_padre -- C.D Fase III
                                  from cj_movimientos
                                 where cod_usuario = p_cod_usuario
                                   and hora = p_hora
                                   and cod_tra_padre = v_cod_tra_pad_caja
                                   and fecha  = p_fecha
                                   and estado in ('P','N')); -- pendiente

             /*   UPDATE pr_cuotas -- verificar
                  SET estado     = 'N' -- Cancelado
                WHERE nro_cuenta = v_nro_cuenta
                  AND nro_cuota = v_nro_documento3;*/
      --> Agregado 01/09/2014 P.S -- C.D.Fase III
        if v_nro_cuenta is not null and v_nro_documento3 is not null then
          begin
            select estado
              into v_est_cuota
              from pr_cta_prestamos t
             where t.nro_cuenta = v_nro_cuenta;
          exception
            when no_data_found then
              v_est_cuota := null;
          end;

           begin
           select 'S',(nvl(c.sal_capital, 0) + nvl(c.sal_interes, 0))
             into  v_cancela,v_saldo
             from pr_cuotas c
            WHERE nro_cuenta = v_nro_cuenta
              and nro_cuota = v_nro_documento3
              and estado <> 'N';
             exception
               when no_data_found then
                 v_cancela := 'N';
                 v_saldo := 0;
            end;

              if nvl(v_saldo,0) > 0  then -- Si el pago fue parcial, debe mantenerse el estado de pr_cta_prestamos
                UPDATE pr_cuotas
                   SET estado     = v_est_cuota
                 WHERE nro_cuenta = v_nro_cuenta
                  AND nro_cuota = v_nro_documento3;
                  v_can_cuo_pagada:= 0;
               else
                 UPDATE pr_cuotas
                   SET estado     = 'N' -- Cancelado
                 WHERE nro_cuenta = v_nro_cuenta
                  AND nro_cuota = v_nro_documento3
                  AND estado <> 'N';
              end if;
              -- Debe actualizar la cantidad de Cuotas Pagadas, una vez aprobado el circuito.
                if v_cancela = 'S' and nvl(v_saldo,0) = 0 then
                  v_can_cuo_pagada:= 1;
                else
                  v_can_cuo_pagada:= 0;
                end if;

              update pr_cta_prestamos
                 set can_cuo_pagadas = nvl(can_cuo_pagadas, 0) + v_can_cuo_pagada
               where nro_cuenta = p_nro_cuenta;

           end if;

             -- Se actualiza cj_movimientos
               if v_cod_mod_padre = 9 and v_nro_caja is not null and v_nro_documento is not null then
                  -- Actualiza CJ_MOVIMIENTOS --
                 update cj_movimientos
                    set estado = 'N'
                  where estado = 'P'
                    and fecha = p_fecha
                    and hora = p_hora
                    and cod_usuario = p_cod_usuario;
                  -- CJ_MOVIMIENTOS (Detalle del Cheque)
                  if p_cod_tra_padre != 371 then
                     update cj_movimientos
                        set estado = 'N'
                      where estado = 'P'
                        and fecha = p_fecha
                        and nro_doc_referencia = v_nro_documento
                        and cod_usuario = p_cod_usuario;
                  end if;
               end if;


                if v_cod_mod_padre = 9 and v_nro_caja is not null  and v_nro_documento is not null then
                  --> Actualiza Cheque Enviados --
                  lp_act_cheque(v_nro_documento,v_nro_caja);
                end if;
                      -- Actualizar Estado TA_COBROS -- TRANSACCION 250
                 begin
                   update ta_cobros s
                      set s.estado = 'C'
                    where s.fec_valor = p_fecha
                      and s.hora = p_hora
                      and s.cod_usuario = p_cod_usuario
                      and s.nro_cuenta = v_nro_cuenta
                      and s.estado = 'S';
                 exception
                   when others then
                     raise_application_error(-20000,
                                             'PAG_RIE.Error Al Actualizar Estado - TA_COBROS ' ||
                                             sqlerrm);
                 end;
              end if;-- C.D.Fase III
        /*-- C.D.Fase 4 - Operaciones Vencidas - retomadas en Caja-- */
          if v_cod_mod_padre = 15 and v_caja is not null then
             -- Actualiza CJ_MOVIMIENTOS --
             update cj_movimientos
                set estado = 'N'
              where estado = 'P'
                and fecha = p_fecha
                and hora = p_hora
                and cod_usuario = p_cod_usuario
                and nro_secuencia = v_nro_secuencia;
           end if;

            if v_nro_cuenta is not null and  v_cod_mod_padre not in ('8','9') then
               if v_afecta = 'S'then
                  pal_cam.pr_act_movimientos(p_cod_usuario,
                                   p_fecha,
                                   p_hora,
                                   'N',  -- pasa a 'N-normal el movimiento
                                   to_number(v_caja)/*(v_nro_caja)*/);-- C.D.Fase III -- Se agrega el nro de Caja, para que no actualice a null, cuando se actualiza el saldo
               end if;
               update ge_movimientos
                  set estado = 'N',
                      cod_usu_autorizador = user
                where reversado = 'N'
                  and estado <> 'N'
                  and fecha = p_fecha
                  and hora = p_hora
                  and cod_usuario = p_cod_usuario --> Ajuste 09/09/2014
                  and nro_secuencia = v_nro_secuencia ;

             else
               if v_nro_cuenta is null and  v_cod_mod_padre not in ('8','9') and p_est_movimiento = 'N' then
                 update ge_movimientos
                    set estado = 'N',
                        cod_usu_autorizador = user
                  where reversado = 'N'
                    and estado <> 'N'
                    and fecha = p_fecha
                    and hora = p_hora
                    and cod_usuario = p_cod_usuario --> Ajuste 09/09/2014
                    and nro_secuencia = v_nro_secuencia;
               end if;
               -- C.D.Fase 4- Operaciones Vencidas - Efectivo - Cheque c/o/Bancos - Cheque c/n/Banco
                if v_nro_cuenta is null and  v_cod_mod_padre = 15 and p_est_movimiento = 'J' then
                  update ge_movimientos
                    set estado = p_est_movimiento,
                        cod_usu_autorizador = user
                  where reversado = 'N'
                    and fecha = p_fecha
                    and hora = p_hora
                    and cod_usuario = p_cod_usuario
                    and nro_secuencia = v_nro_secuencia;
                end if;
                ----
             end if;
           if p_est_movimiento = 'J' and v_cod_mod_padre not in ('8','9') and v_cod_rubro is null then
             update ge_movimientos
                set estado = p_est_movimiento,
                    cod_usu_autorizador = user
              where reversado = 'N'
                and estado <> 'N'
                and fecha = p_fecha
                and hora = p_hora
                and cod_usuario = p_cod_usuario --> Ajuste 09/09/2014
                and nro_secuencia = v_nro_secuencia
                and nro_cuenta is null
                and cod_rubro is  null ;
            elsif p_est_movimiento = 'J' and v_cod_mod_padre not in ('8','9') and v_cod_rubro is not null then
               update ge_movimientos
                  set estado = 'N',
                      cod_usu_autorizador = user
                where reversado = 'N'
                  and estado <> 'N'
                  and fecha = p_fecha
                  and hora = p_hora
                  and cod_usuario = p_cod_usuario --> Ajuste 09/09/2014
                  and nro_secuencia = v_nro_secuencia
                  and nro_cuenta is null
                  and cod_rubro is not null ;

            end if;
            -- C.D.Fase III--
            -- Cheques de Gerencia/ Corresponsales- Actualiza estado en CC_CHEQUERAS --
            if v_cod_modalidad in (43,45) and v_nro_cuenta is not null then
              begin
                v_result := LF_ACT_CAM_EST_CHE(v_nro_cuenta, v_nro_documento);

              exception
                when others then
                  v_result := 'Error en inserta_cheque_gerencia ' || sqlerrm;
                  raise_application_error(-20004, v_result);
              end;
            end if;

         -- Operaciones Vencidas - C.D.Fase 4- 01/10/2014
         if v_cod_tra_padre = 139 and v_est_movimiento = 'P' then -- Solo las pendientes- las que no se retoman desde caja
           lp_act_ope_vencidas(p_fecha, p_hora, p_cod_usuario,v_nro_secuencia );
         end if;
end loop;
    -- C.D.Fase III
    --> Actualizar Saldo de Caja
     lp_gen_transaccion();
  END IF;




EXCEPTION
  WHEN no_data_found THEN
    raise_application_error(-20000,
                            'Pedido cargado por el usuario ' ||
                            p_cod_usuario || ' en fecha ' || trunc(p_fecha) ||
                            ' hora ' || p_hora ||
                            ' no se encuentra registrado.');
  WHEN too_many_rows THEN
    raise_application_error(-20000,
                            ' Se encontró mas de un registro con el Pedido Nro. ' ||
                            p_nro_pedido);
  WHEN OTHERS THEN
    raise_application_error(-20000, 'Error Al obtener Pedido ' || SQLERRM);
END; -- fin pr_apr_pedidos

   -- Bloquea el registro para reservarlo para la operacion
   FUNCTION FU_VER_MOV_PENDIENTE
   (  p_cod_usuario ge_mov_autorizaciones.cod_usuario%TYPE,
      p_hora        ge_mov_autorizaciones.hora%TYPE,
      p_fecha       ge_mov_autorizaciones.fecha%TYPE
   ) RETURN BOOLEAN IS
      v_existe NUMBER := 0;
      --  bloquear para q nadie más actualice
      CURSOR mov IS
         SELECT *
           FROM ge_movimientos
          WHERE cod_usuario = p_cod_usuario
            AND hora = p_hora
            AND fecha = p_fecha
            AND reversado = 'N'
            AND estado = 'P'
            FOR UPDATE NOWAIT;
   BEGIN
      FOR reg IN mov LOOP
         v_existe := 1;
      END LOOP;
      IF v_existe = 1 THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE = -54 THEN
            -- registro bloqueado por otro usuario
            raise_application_error(-20000,
                                    'Registro bloqueado por otro usuario. Intente nuevamente.');
         ELSE
            raise_application_error(-20000, 'Recup.Est.Mov. ' || SQLERRM);
         END IF;
   END;

   /**
    || Procedimiento para rechazar los pedidos de autorización de Riesgo Operativo
    || Se ejecuta desde el trigger de la tabla GE_MOV_AUTORIZACIONES
    || Se pasan todos los campos como parámetro, de lo contrario da error de Mutating
   **/
   PROCEDURE PR_RCH_PEDIDO
   (  p_nro_pedido          IN ge_mov_autorizaciones.nro_pedido%TYPE,
      p_fecha               IN ge_mov_autorizaciones.fecha%TYPE,
      p_hora                IN ge_mov_autorizaciones.hora%TYPE,
      p_cod_usuario         IN ge_mov_autorizaciones.cod_usuario%TYPE,
      p_cod_tra_padre       IN ge_mov_autorizaciones.cod_tra_padre%TYPE,
      p_cod_mod_padre       IN ge_mov_autorizaciones.cod_mod_padre%TYPE,
      p_cod_mad_padre       IN ge_mov_autorizaciones.cod_mad_padre%TYPE,
      p_nro_cuenta          IN ge_mov_autorizaciones.nro_cuenta%TYPE,
      p_cod_persona         IN ge_mov_autorizaciones.cod_persona%TYPE,
      p_mto_mon_fuerte      IN ge_mov_autorizaciones.mto_mon_fuerte%TYPE,
      p_tip_operacion       IN ge_mov_autorizaciones.tip_operacion%TYPE,
      p_nro_documento       IN ge_mov_autorizaciones.nro_documento%TYPE DEFAULT NULL,
      p_cod_usu_autorizador IN ge_mov_autorizaciones.cod_usu_autorizador%TYPE,
      p_concepto            IN ge_mov_autorizaciones.concepto%TYPE,
      p_estado              IN ge_mov_autorizaciones.estado%TYPE,
      p_observacion         IN ge_mov_autorizaciones.observacion%TYPE
   ) IS
      v_descripcion        ge_transacciones.descripcion%TYPE;
      v_hora               ge_movimientos.hora%TYPE := to_char(SYSDATE, 'hh24:mi:ss');
      v_cod_error          NUMBER;
      v_cantidad           number;
   -- C.D Fase III
   v_cod_circuito wf_circuitos.cod_circuito%TYPE;
   v_cod_tarea    wf_cir_tareas.cod_tarea%TYPE;
   v_fec_actual   DATE := pag_cal.fu_obt_fec_actual(9);
   v_nro_caja     cj_cajas.nro_caja%TYPE;
   v_afecta          varchar2(1):= (fug_obt_pardinamico('COD_MOD_EST_AFECTA',p_cod_mod_padre));
   v_nro_cuenta ge_movimientos.nro_cuenta%type;
   v_nro_documento ge_movimientos.nro_documento%type;
   v_msj_cheque varchar2(1000);
   v_nro_doc_referencia cj_movimientos.nro_doc_referencia%type;
   v_existe varchar2(1) := 'N';



   --Obtiene el n¿mero de caja del movimiento principal
   FUNCTION lf_obt_nro_caja
   (
      p_fecha       IN DATE,
      p_hora        IN VARCHAR2,
      p_cod_usuario IN VARCHAR2

   ) RETURN NUMBER IS
      v_nro_caja NUMBER;
   BEGIN
      SELECT nro_caja
        INTO v_nro_caja
        FROM cj_movimientos c
       WHERE estado = 'N'
         AND fecha = p_fecha
         AND hora = p_hora
         AND cod_usuario = p_cod_usuario
         AND nro_secuencia = 1;
      IF v_nro_caja IS NULL THEN
         raise_application_error(-20000,
                                 'ERROR: No Existe Nro. Caja en movimiento con Fecha: ' || p_fecha ||
                                  ', hora:' || p_hora || ', usuario:' || p_cod_usuario);
      ELSE
         RETURN v_nro_caja;
      END IF;
   EXCEPTION
      WHEN no_data_found THEN
     BEGIN
       SELECT nro_caja
        INTO v_nro_caja
        FROM cj_movimientos c
       WHERE estado = 'N'
         AND fecha = p_fecha
         AND hora = p_hora
         AND cod_usuario = p_cod_usuario
         AND nro_secuencia = (select min (nro_secuencia)
                    from cj_movimientos cj
                   where cj.estado = 'N'
                     and cj.fecha = c.fecha
                     and cj.hora = c.hora
                     and cj.cod_usuario = c.cod_usuario);
        IF v_nro_caja IS NULL THEN
         raise_application_error(-20000,
                     'ERROR: No Existe Nro. Caja en movimiento con Fecha: ' || p_fecha ||
                      ', hora:' || p_hora || ', usuario:' || p_cod_usuario);
        ELSE
         RETURN v_nro_caja;
        END IF;

     EXCEPTION
       WHEN NO_DATA_FOUND THEN
         BEGIN -- Para cancelación Automática de Circuitos. C.D.Fase III
            SELECT nro_caja
            INTO v_nro_caja
            FROM cj_movimientos c
           WHERE estado = 'R'
             AND fecha = p_fecha
             AND hora = p_hora
             AND cod_usuario = p_cod_usuario
             AND nro_secuencia = 1;
          IF v_nro_caja IS NULL THEN
             raise_application_error(-20000,
                                     'ERROR: No Existe Nro. Caja en movimiento con Fecha: ' || p_fecha ||
                                      ', hora:' || p_hora || ', usuario:' || p_cod_usuario);
          ELSE
             RETURN v_nro_caja;
          END IF;

        EXCEPTION
          WHEN NO_DATA_FOUND THEN
           raise_application_error(-20000,
                       'ERROR: No existe movimiento. Fecha: ' || p_fecha || ', hora:' ||
                        p_hora || ', usuario:' || p_cod_usuario || ', Caja:' || v_nro_caja);
          WHEN OTHERS THEN
             raise_application_error(-20000,
                         'ERROR: Al buscar movimientos: ' || p_fecha ||
                        ', hora:' || p_hora || ', usuario:' || p_cod_usuario || ', Caja:' ||
                        v_nro_caja);
          END;
        WHEN OTHERS THEN
           raise_application_error(-20000,
                       'ERROR: Al buscar movimientos: ' || p_fecha ||
                      ', hora:' || p_hora || ', usuario:' || p_cod_usuario || ', Caja:' ||
                      v_nro_caja);
        END;
      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 'ERROR: Al buscar movimientos con Fecha: ' || p_fecha ||
                                  ', hora:' || p_hora || ', usuario:' || p_cod_usuario || ', Caja:' ||
                                  v_nro_caja);
   END lf_obt_nro_caja;

procedure lp_rev_det_cheque(p_fecha date, p_nro_documento number) is

  v_cantidad       NUMBER := 0;
  v_cod_tra_padre  cj_movimientos.cod_tra_padre%type;
  v_nro_referencia cj_movimientos.nro_doc_referencia%type;
  v_documento      cj_movimientos.nro_documento%type;
  v_cod_mon_local  cj_movimientos.cod_moneda%type;
  v_nro_caja       cj_movimientos.nro_caja%type;
  v_hora           cj_movimientos.hora%type;
  v_msj_salida     VARCHAR2(8000); -- mensaje final retornado
  v_existe         varchar2(1) := 'N';
  v_rev_cobro      varchar2(2000);


  cursor c_caja is
     Select cod_tra_padre,
             a.nro_documento,
             a.nro_doc_referencia,
             a.nro_caja,
             a.hora
        From cj_movimientos a
       Where a.fecha = p_fecha
         and a.nro_doc_referencia = p_nro_documento -- v_nro_documento
         and a.cod_tra_padre in (131, 133, 134, 217, 355); -- para actualizar cheque*/
BEGIN

 -- Actualizo el estado del Cheque para poder reversar --
 for c in c_caja loop
    begin
      update cc_che_enviados e
         set estado = 'I'
       where nro_cheque = to_number(c.nro_documento) -- nro_documento
         and e.nro_boleta = c.nro_doc_referencia
         and e.estado = 'P'
         and fecha = p_fecha;
    end;
    -- Se reversa el detalle --
    v_msj_salida := fuj_pro_transaccion_200(null,
                                            -- Nro de referencia de la operacion
                                            c.nro_caja,
                                            -- Nro de Caja
                                            c.cod_tra_padre,
                                            -- Codigo de transaccion
                                            c.nro_documento,
                                            -- Nro. de Boleta
                                            c.hora,
                                            -- hora de la transaccion a reversar
                                            'Reversión de la Operación' /* p_concepto*/,
                                            'R');
    IF instr(v_msj_salida, '~999~') > 0 THEN
      raise_application_error(-20000, 'Pedido:' || v_msj_salida);
    END IF;
    -- Los cobros de Pr¿stamos con cheques otros Bancos se detallan autom¿ticamente, y ya al reversar el detalle
    -- tambi¿n deben reversar la operaci¿n por completo.-
      if v_cod_tra_padre in (133) /*and cj.tip_monto = 'C'*/then
        Begin
          Select 'S', a.nro_caja, a.nro_documento, a.hora
            into v_existe, v_nro_caja, v_documento, v_hora
            from cj_movimientos a
           where a.nro_documento = c.nro_doc_referencia
             and a.cod_tra_padre in (361) --> Solo debe buscar la 361 por el momento
             and a.tipo = 'D'
             and a.estado != 'R';
        Exception
          When no_data_found Then
            v_existe := 'N';
          When others then
            raise_application_error(-20000,
                                    'Error Buscando Datos del Cobro de Préstamos con Cheques otros Bancos ' ||
                                    sqlerrm);
        End;

      End If;
   end loop;

 -- Luego se reversa el Movimiento Principal--
  if v_existe = 'S' then
    v_rev_cobro := fuj_pro_transaccion_200(p_nro_pedido,
                                           -- Nro de referencia de la operacion
                                           v_nro_caja,
                                           -- Nro de Caja
                                           361,
                                           -- Codigo de transaccion
                                           v_documento,
                                           -- Nro. de Boleta
                                           v_hora,
                                           -- hora de la transaccion a reversar
                                           'Prueba' /*p_concepto*/,
                                           'R');
    IF instr(v_rev_cobro, '~999~') > 0 THEN
      raise_application_error(-20000, 'Pedido:' || v_msj_salida);
    END IF;
  end if;

Exception
  When Others Then
    raise_application_error(-20000,
                            'PAG_RIE.Error Al Actualizar Estado del Cheque detallado' ||
                            sqlerrm);
End;
  -- Procedimiento interno para reversar el movimiento si es de caja -- de reversiones
   PROCEDURE lp_ver_operacion

   (
      p_fecha       IN DATE,
      p_hora        IN VARCHAR2,
      p_cod_usuario IN VARCHAR2
   ) IS
      v_cod_tra_padre ge_movimientos.cod_transaccion%TYPE;
      v_cod_oficina   cj_movimientos.cod_oficina%TYPE; -- oficina de la caja
      v_estado        NUMBER(1); -- estado de la caja
      v_fec_caja      cj_controles.fecha%TYPE; -- fecha de la caja
      v_sal_actual    NUMBER(18, 2); -- saldo actual de la caja en efectivo
      v_sal_cheques   NUMBER(18, 2); -- saldo actual de la caja en cheques
      v_msj_salida    VARCHAR2(8000); -- mensaje final retornado
      v_contador      number:= 0;
      v_cod_mon_local cj_movimientos.cod_moneda%type    := pag_gen.fu_obt_mon_local;

      CURSOR cj_movs IS
         SELECT cod_moneda, monto, tipo, tip_monto, tot_detallado, nro_doc_referencia, ROWID,
                nro_documento, cod_mod_padre, cod_mad_padre, cod_tra_padre, fecha, hora, cod_usuario,
                nro_caja
           FROM cj_movimientos
          WHERE cod_usuario = p_cod_usuario
            AND hora = p_hora
            AND cod_tra_padre = v_cod_tra_padre
            AND estado = 'N'; -- normal
   BEGIN
      v_nro_caja := lf_obt_nro_caja(p_fecha, p_hora, p_cod_usuario);
      BEGIN
         SELECT DISTINCT cod_tra_padre
           INTO v_cod_tra_padre
           FROM cj_movimientos a
          WHERE fecha = p_fecha
            AND hora = p_hora
            AND cod_usuario = p_cod_usuario
            AND nro_caja = v_nro_caja;
      EXCEPTION
         WHEN no_data_found THEN
            raise_application_error(-20000, 'No se encontró transacción padre de Caja. Verifique!!');
         WHEN dup_val_on_index THEN
            raise_application_error(-20000, 'Más de una transacción padre de Caja. Verifique!!');
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Error al buscar transacción padre de Caja:' || SQLERRM);
      END;

      FOR cj IN cj_movs LOOP

         -- Obtengo los datos de la caja x moneda local------------------
         prj_obt_datos_caja(cj.nro_caja, cj.cod_moneda, v_cod_oficina, v_fec_caja, v_estado,
                            v_sal_actual, v_sal_cheques, 'N');

         IF v_estado = -1 THEN
            raise_application_error(-20000, 'Caja ' || cj.nro_caja || ' inexistente!!');
         ELSIF v_estado IN (0, 2) THEN
            raise_application_error(-20000,
                                    'Caja ' || cj.nro_caja || ' no esta habilitada para esta Operación en ' ||
                                     cj.cod_moneda);
         ELSIF v_fec_caja <> v_fec_actual THEN
            raise_application_error(-20000, 'Caja ' || cj.nro_caja || ' no fue habilitada el día de hoy');
         END IF;
         --------------------------------------------------
         -- C.D.Fase III--
         -- Reversa el detalle del Cheque, si existe --
          begin
            select count(*)
              into v_contador
              from cj_movimientos
             where nro_caja = cj.nro_caja
               and hora = cj.hora
               and cod_tra_padre = to_number(v_cod_tra_padre)
               and estado = 'N' -- Normal
               and (tot_detallado) > 0
               and ((cod_moneda = v_cod_mon_local and tip_monto = 'C' and
                   cod_tra_padre not in (242,371)) --> 242 Venta Divisas cuando se paga con cheques C/N/B solo es Guaranies.-
                   or
                   (cod_moneda <> v_cod_mon_local and cod_tra_padre not in (241)) --> 241 Compras Divisas cuando se compra un cheques C/N/B solo es Moneda Ext.-
                   or (cod_tra_padre in (359, 361, 362) and
                   tip_monto in ('O', 'S', 'T', 'X')) or
                   (cod_tra_padre in (352,372) and tip_monto in ('O', 'S', 'T', 'X') ));
          end;
         if v_contador > 0 then
           lp_rev_det_cheque(p_fecha,cj.nro_documento );
         end if;
         ---------------------------------------------------
         v_msj_salida := fuj_pro_transaccion_200( p_nro_pedido,
                                                 -- Nro de referencia de la operacion
                                                 cj.nro_caja,
                                                 -- Nro de Caja
                                                 v_cod_tra_padre,
                                                 -- Codigo de transaccion
                                                  cj.nro_documento,
                                                 -- Nro. de Boleta
                                                 cj.hora,
                                                 -- hora de la transaccion a reversar
                                                'Reversión Nro Pedido'||p_nro_pedido/* p_concepto*/,
                                                 'R');
         IF instr(v_msj_salida, '~999~') > 0 THEN
            raise_application_error(-20000, 'Pedido:' || v_msj_salida);
         END IF;
      END LOOP;
   END lp_ver_operacion;
     -- Funci¿n para eliminar Cheques de Gerencia--
    FUNCTION LF_ELI_CHE_GER_EMI(P_CUENTA IN CC_CHE_GER_EMITIDOS.NRO_CUENTA%TYPE,
                                P_CHEQUE IN CC_CHE_GER_EMITIDOS.NRO_CHEQUE%TYPE)
        RETURN VARCHAR2 IS

        V_ESTADO_ANT      VARCHAR2(1);
        V_RESULT          VARCHAR2(1000);
        V_CUENTA_CERT     VARCHAR2(15);
        v_nro_che_inicial cc_chequeras.nro_che_inicial%type;
        v_ult_che_emitido cc_chequeras.ult_che_emitido%type;
      begin

        --- Cambio de estado al cheque gerencia

        v_estado_ant := pac_che.fu_act_cam_est_che(p_cuenta,
                                                   p_cheque,
                                                   'E',
                                                    v_result,
                                                    v_cuenta_cert);
        --- Actualizo ultimo cheque emitido
        if v_estado_ant in ('G', 'E') then
          --- Elimino el cheque gerencia
          delete cc_che_ger_emitidos
           where nro_cheque = p_cheque
             and nro_cuenta = p_cuenta;
        end if;
        -- Recupero la chequera
        BEGIN
          select nro_che_inicial, ult_che_emitido
            into v_nro_che_inicial, v_ult_che_emitido
            from cc_chequeras
           WHERE nro_cuenta = p_cuenta
             AND p_cheque >= nro_che_inicial
             AND p_cheque < nro_che_inicial + can_cheques
             AND p_cheque between nro_che_inicial and nro_che_final;
        exception
          when no_data_found then
            raise_application_error(-20015, 'Chequera no registrada');
        END;
        -- Verifico si el cheque corresponde al ultimo emitido actualizo chequera
        if p_cheque = v_ult_che_emitido then
          update cc_chequeras
             set ult_che_emitido = decode((nvl(ult_che_emitido, 0) - 1),
                                          (nro_che_inicial - 1),
                                          null,
                                          ult_che_emitido - 1)
           where nro_cuenta = p_cuenta
             and nro_che_inicial = v_nro_che_inicial;
        end if;
        return v_result;
      exception
        when others then
          v_result := 'Elim.cheq.ger.' || sqlerrm;
          raise_application_error(-20014, v_result);
      end;

   -- Procedimiento para Reversar Cheques de Gerencia-- C.D.Fase III
     procedure lp_rev_che_gerencia(p_fecha in date,
                                   p_hora in varchar2,
                                   p_cod_usuario in varchar2,
                                   p_msj_cheque IN OUT VARCHAR2) is

       v_nro_cuenta      ge_movimientos.nro_cuenta%type;
       v_cod_modalidad   ge_movimientos.cod_modalidad%type;
       v_cod_transaccion ge_movimientos.cod_transaccion%type;
       v_nro_documento   ge_movimientos.nro_documento%type;


   begin
      begin
         Select nro_cuenta, cod_modalidad, cod_transaccion, nro_documento
           into v_nro_cuenta,
                v_cod_modalidad,
                v_cod_transaccion,
                v_nro_documento
           from ge_movimientos m
          where fecha = p_fecha
            and hora = p_hora
            and cod_usuario = p_cod_usuario
            and cod_modalidad = '43'
            and cod_transaccion = '603';
       exception
         when no_data_found then
           v_nro_cuenta      := null;
           v_cod_modalidad   := null;
           v_cod_transaccion := null;
           v_nro_documento   := null;
       end;
         IF (v_cod_modalidad = 43) OR --- Reversar cheque emitido
            (v_cod_transaccion = 603) THEN

           p_msj_cheque := lf_eli_che_ger_emi(v_nro_cuenta, v_nro_documento);
           IF p_msj_cheque IS NOT NULL THEN
             raise_application_error(-20000,
                                     'Reversión del Cheq. Gerencia ' ||
                                     p_msj_cheque);
           END IF;
         END IF;
    END;

BEGIN
  --Para que se pueda habilitar o deshabilitar la generaci¿n del workflow de control dual por m¿dulo, modalidad y moneda.
  IF nvl(fug_obt_pardinamico('IND_REA_CON_DUAL',p_cod_mod_padre,p_cod_mad_padre,null ,null,null),'N') = 'S' THEN
  --- Procedimiento Principal ---
 --  v_hora := pag_gen.fu_obt_sig_segundo(v_hora);

 -- Obtiene datos para actualizar CJ_MOVIMIENTOS - Detalle de Cheques (C.D.Fase III)
   begin
     Select nro_cuenta, nro_caja, nro_documento
       into v_nro_cuenta, v_nro_caja, v_nro_documento
       from ge_movimientos m
      where reversado = 'N'
        and fecha = p_fecha
        and hora = p_hora
        and cod_usuario = p_cod_usuario
        and nro_caja is not null
        and rownum = 1
      order by nro_secuencia;
    exception
      when no_data_found then
        v_nro_cuenta := null;
        v_nro_caja:= null;
        v_nro_documento := null;
    end ;


    -- Verifica que no tenga Pedidos pendientes en GE_AUT_PEDIDOS
     Begin
      select count(*)
        into v_cantidad
        from ge_aut_pedidos a
        where a.cod_usuario = p_cod_usuario
          and a.fecha       = p_fecha
          and a.hora        = p_hora
          and a.estado      = 'S';
     exception
       when no_data_found then
         v_cantidad := 0;
     End;

   IF  v_cantidad = 0 then
     -- C.D Fase III--
    -----------------------------------------------------------------------------------------------
     if p_cod_mod_padre = 9 and p_cod_mad_padre = 91 then -- C.D Fase III
      -- Actualizo los Movimientos
        update ge_movimientos
           set estado = 'N'
         where reversado = 'N'
           and estado <> 'N'
           and fecha = p_fecha
           and hora = p_hora
           and cod_usuario = p_cod_usuario;
       -- Actualizo el registro con misma fecha y hora del Movimiento
        update cj_movimientos
           set estado = 'N'
         where estado = 'P'
           and fecha = p_fecha
           and hora = p_hora
           and cod_usuario = p_cod_usuario;
        -- Actualizo el registro generado del detalle del Cheque -- Hora diferente del Movimiento
          If v_nro_caja is not null and v_nro_documento is not null and p_cod_tra_padre != 371 then
               update cj_movimientos
                 set estado = 'N'
               where estado = 'P'
                 and fecha = p_fecha
                -- and nro_documento = v_nro_documento
                 and nro_doc_referencia = v_nro_documento
                 and cod_usuario = p_cod_usuario;
             if p_cod_tra_padre = 355 then
               begin
                 select m.nro_doc_referencia
                   into v_nro_doc_referencia
                   from cj_movimientos m
                  where m.fecha = p_fecha
                    and m.hora = p_hora
                    and m.cod_usuario = p_cod_usuario
                    and m.cod_tra_padre = p_cod_tra_padre
                    and m.nro_documento = v_nro_documento;
               exception
                 when no_data_found then
                   v_nro_doc_referencia := null;
                 when others then
                   v_nro_doc_referencia := null;
               end;
               if v_nro_doc_referencia is not null then
                 update cj_movimientos a
                    set a.estado = 'N'
                  where a.cod_tra_padre = 371
                    and a.nro_documento = v_nro_doc_referencia
                    and a.estado = 'P'
                    and a.nro_caja = v_nro_caja
                    and a.tip_monto = 'C'
                    and a.tot_detallado > 0;
               end if;
             end if;
          elsif p_cod_tra_padre = 371 then
            -- Se verifica si el depósito tiene mov. pend. de autorización.
            begin
              select distinct 'S'
                into v_existe
                from cj_movimientos a
               where a.cod_usuario = p_cod_usuario
                 and a.cod_tra_padre = p_cod_tra_padre
                 and a.nro_documento = v_nro_documento
                 and a.estado = 'N'
                 and exists (select 1
                        from cj_movimientos b
                       where b.fecha = a.fecha
                         and b.cod_usuario = a.cod_usuario
                         and b.cod_tra_padre = 355
                         and b.nro_doc_referencia = v_nro_documento
                         and b.estado != 'R');
            exception
              when no_data_found then
                v_existe := 'N';
              when others then
                v_existe := 'N';
            end;
            if nvl(v_existe,'N') = 'S' then
              raise_application_error(-20000, 'Operacion con detalles Pendientes de Autorización / Rechazo.');
            end if;
          end if;


       if  p_cod_mod_padre = 9 then
         lp_ver_operacion(p_fecha,p_hora, p_cod_usuario);
       end if;
       if v_nro_doc_referencia is not null then
         update cj_movimientos a
            set a.estado = 'P'
          where a.cod_tra_padre = 371
            and a.nro_documento = v_nro_doc_referencia
            and a.estado = 'N'
            and a.nro_caja = v_nro_caja
            and a.tip_monto = 'C';
       end if;
       -----------------------------------------------------------------------------------------------
      else
        /* Actualiza el estado para Reversar*/
     if nvl(v_afecta,'N') <> 'S' and p_cod_mod_padre <> 8 then -- C.D.Fase 4
        update ge_movimientos
           set estado = 'N'
         where reversado = 'N'
           and estado <> 'N'
           and fecha = p_fecha
           and hora = p_hora
           and cod_usuario = p_cod_usuario;
      end if;
      v_hora := fug_obt_hor_disponible(pag_cal.FU_OBT_FEC_ACTUAL(1),v_hora,user,'N');
      prg_rev_operacion(p_fecha,
                        p_hora,
                        p_cod_usuario,
                        p_cod_mod_padre,
                        p_cod_mad_padre,
                        p_cod_tra_padre, --indica la operaci¿n
                        USER, ---cod_usu_reversion
                        v_hora,
                        'N',
                        p_observacion);

       lp_rev_che_gerencia(p_fecha, p_hora, p_cod_usuario,v_msj_cheque);-- Reversi¿n Cheques de Gerencia
      end if;


      --Obtengo la descripcion de la transacci¿n
      v_descripcion := fug_obt_des_transaccion(p_cod_mod_padre,
                                                p_cod_mad_padre, p_cod_tra_padre);
   else
     raise_application_error(-20000, 'Operacion pendiente de Aprobación. Solicite rechazo del pedido de autorización.');

  END IF;

  END IF;
   EXCEPTION
      WHEN no_data_found THEN
         raise_application_error(-20000,
                                 'Pedido cargado por el usuario ' || p_cod_usuario ||
                                 ' en fecha ' ||
                                  p_fecha || ' hora ' || p_hora ||
                                 ' no se encuentra registrado.');
      WHEN too_many_rows THEN
         raise_application_error(-20000,
                                 ' Se encontr¿ mas de un registro con el Pedido Nro. ' ||
                                  p_nro_pedido);
      WHEN OTHERS THEN
         raise_application_error(-20000,'Error Al obtener Pedido '||  SQLERRM);
   END; --FIN PR_RCH_PEDIDOS

   -- Iniciar automáticamente el circuito cuando la operación Excede el Monto Máximo
   PROCEDURE PR_REV_OPERACION
   (
      p_nro_cuenta    IN ge_cuentas.nro_cuenta%TYPE,
      p_fecha         IN ge_aut_reversiones.fecha%TYPE,
      p_hora          IN ge_aut_reversiones.hora%TYPE,
      p_cod_usuario   IN ge_aut_reversiones.cod_usuario%TYPE,
      p_cod_tra_padre IN ge_aut_reversiones.cod_tra_padre%TYPE,
      p_cod_mod_padre IN ge_aut_reversiones.cod_mod_padre%TYPE,
      p_cod_mad_padre IN ge_aut_reversiones.cod_mad_padre%TYPE,
      p_cod_moneda    IN ba_monedas.cod_moneda%type,
      p_monto         IN ge_movimientos.monto%TYPE,
      p_concepto      IN ge_aut_reversiones.concepto%type,
      p_nro_solicitud IN OUT NUMBER
   ) IS
      v_cod_error        NUMBER;
      v_sig_valor        NUMBER;
      v_cod_persona      ba_usuarios.cod_persona%TYPE;
      v_mto_max          NUMBER;
      v_cant             NUMBER;
      v_tip_oper         NUMBER;
      v_cod_mon_fuerte   ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_FUERTE;
      v_monto            NUMBER(18, 2);
      v_cotizacion       ge_movimientos.cotizacion%type;
      v_nro_documento    cj_movimientos.nro_documento%type;
      v_cod_moneda       ba_monedas.cod_moneda%type;
      v_cod_modulo       ba_modulos.cod_modulo%type;
      v_cod_modalidad    ge_modalidades.cod_modalidad%type;
      v_cod_oficina      ba_oficinas.cod_oficina%type;
      v_cod_ofi_usuario  ba_oficinas.cod_oficina%type;
      v_cod_per_mov      ba_personas.cod_persona%type; -- DYDMR-45. CB. 26/03/2014. Variable creada por Milton (para reversar cargos cargados por persona, no por cuenta).
      v_nro_cta_transferencia  ge_movimientos.nro_cuenta%type; -- C.D.Fase III

   BEGIN

      IF p_cod_mod_padre = 9 THEN
         BEGIN
            SELECT DISTINCT
                   case
                      when p_cod_tra_padre in (131,133,134) then a.nro_doc_referencia
                      else a.nro_documento
                   end
              INTO v_nro_documento
              FROM cj_movimientos a
             WHERE a.fecha = p_fecha
               AND a.hora = p_hora
               AND a.cod_usuario = p_cod_usuario;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000, 'No existe N¿mero de Documento');
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Error Obt.Nro.Documento ' || SQLERRM);
         END;

         BEGIN
            SELECT b.monto, b.cotizacion, b.cod_moneda, b.cod_persona
              INTO v_monto, v_cotizacion, v_cod_moneda, v_cod_per_mov
              FROM ge_movimientos b
             WHERE b.fecha = p_fecha
               AND b.hora = p_hora
               AND b.cod_usuario = p_cod_usuario
               AND b.nro_documento = v_nro_documento
               AND b.reversado = 'N'
               AND nro_secuencia = (select min(c.nro_secuencia)
                                      from ge_movimientos c
                                     where c.fecha = b.fecha
                                       and c.hora = b.hora
                                       and c.cod_usuario = b.cod_usuario
                                       and c.nro_documento = b.nro_documento
                                       and c.monto is not null);

         EXCEPTION
            WHEN no_data_found THEN
               -- Puede que no coincida la hora de cj_movimientos con ge_movimientos
               BEGIN
                  SELECT b.monto, b.cotizacion, b.cod_moneda, b.cod_persona
                    INTO v_monto, v_cotizacion, v_cod_moneda, v_cod_per_mov
                    FROM ge_movimientos b
                   WHERE b.fecha = p_fecha
                     AND b.cod_usuario = p_cod_usuario
                     AND b.monto = p_monto
                     AND b.cod_moneda = p_cod_moneda
                     AND b.nro_documento = v_nro_documento
                     AND b.reversado = 'N'
                     AND nro_secuencia = (select min(c.nro_secuencia)
                                            from ge_movimientos c
                                           where c.fecha = b.fecha
                                             and c.hora = b.hora
                                             and c.cod_usuario = b.cod_usuario
                                             and c.nro_documento = b.nro_documento
                                             and c.monto is not null);

               EXCEPTION
                  WHEN no_data_found THEN
                     if v_nro_documento is null then -- 31/oct/2013 RABF
                        -- Puede que no tenga número de documento
                        BEGIN
                           SELECT b.monto, b.cotizacion, b.cod_moneda, b.nro_documento, b.cod_persona
                             INTO v_monto, v_cotizacion, v_cod_moneda, v_nro_documento, v_cod_per_mov
                             FROM ge_movimientos b
                            WHERE b.fecha = p_fecha
                              AND b.cod_usuario = p_cod_usuario
                              AND b.monto = p_monto
                              AND b.cod_moneda = p_cod_moneda
                              AND b.reversado = 'N'
                              AND nro_secuencia = (select min(c.nro_secuencia)
                                                     from ge_movimientos c
                                                    where c.fecha = b.fecha
                                                      and c.hora = b.hora
                                                      and c.cod_usuario = b.cod_usuario
                                                      and c.monto is not null);
                        EXCEPTION
                           WHEN no_data_found THEN
                              raise_application_error(-20102, 'No existe movimiento asociado');
                           -->
                           WHEN TOO_MANY_ROWS THEN
                               BEGIN
                                  SELECT b.monto, b.cotizacion, b.cod_moneda, b.nro_documento, b.cod_persona
                                    INTO v_monto, v_cotizacion, v_cod_moneda, v_nro_documento, v_cod_per_mov
                                    FROM ge_movimientos b
                                   WHERE b.fecha = p_fecha
                                     AND b.cod_usuario = p_cod_usuario
                                     AND b.monto = p_monto
                                     AND b.cod_moneda = p_cod_moneda
                                     AND b.reversado = 'N'
                                     AND B.COD_TRA_PADRE = P_COD_TRA_PADRE
                                     AND B.COD_MOD_PADRE = P_COD_MOD_PADRE
                                     AND B.COD_MAD_PADRE = P_COD_MAD_PADRE
                                     AND nro_secuencia = (select min(c.nro_secuencia)
                                                            from ge_movimientos c
                                                           where c.fecha = b.fecha
                                                             and c.hora = b.hora
                                                             and c.cod_usuario = b.cod_usuario
                                                             and c.monto is not null);
                               EXCEPTION
                                    WHEN OTHERS THEN
                                         raise_application_error(-20202, 'Error Obt.Movimiento ' || SQLERRM);
                               END;
                        END;
                     else
                        IF p_cod_tra_padre IN (131,133,134, 242) THEN /*fm dydmr 1345 se agrega 242*/
                           BEGIN
                              SELECT P_monto, b.cotizacion, b.cod_moneda, b.cod_persona
                                INTO v_monto, v_cotizacion, v_cod_moneda, v_cod_per_mov
                                FROM ge_movimientos b
                               WHERE b.fecha = p_fecha
                                 AND b.cod_usuario = p_cod_usuario
                                 AND b.cod_moneda = p_cod_moneda
                                 AND b.nro_documento = v_nro_documento
                                 AND b.reversado = 'N'
                                 AND nro_secuencia = (select min(c.nro_secuencia)
                                                        from ge_movimientos c
                                                       where c.fecha = b.fecha
                                                         and c.hora = b.hora
                                                         and c.cod_usuario = b.cod_usuario
                                                         and c.nro_documento = b.nro_documento
                                                           and c.monto is not null);
                           EXCEPTION
                               WHEN NO_DATA_FOUND THEN
                                   BEGIN
                                     --14/11/2013 RB/WA Se busca sin condicion de Moneda
                                     --Para Casos de Cambios
                                     SELECT P_monto, b.cotizacion, b.cod_moneda, b.cod_persona
                                      INTO v_monto, v_cotizacion, v_cod_moneda, v_cod_per_mov
                                      FROM ge_movimientos b
                                     WHERE b.fecha = p_fecha
                                       AND b.cod_usuario = p_cod_usuario
                                       AND b.nro_documento = v_nro_documento
                                       AND b.reversado = 'N'
                                       AND nro_secuencia = (select min(c.nro_secuencia)
                                                              from ge_movimientos c
                                                             where c.fecha = b.fecha
                                                               and c.hora = b.hora
                                                               and c.cod_usuario = b.cod_usuario
                                                               and c.nro_documento = b.nro_documento
                                                                 and c.monto is not null);
                                      EXCEPTION
                                         WHEN NO_DATA_FOUND THEN
                                            BEGIN
                                                 --18/11/2013 WA Se busca sin condicion de Usuario
                                                 --Para Casos de Cambios
                                                 SELECT P_monto, b.cotizacion, b.cod_moneda, b.cod_persona
                                                  INTO v_monto, v_cotizacion, v_cod_moneda, v_cod_per_mov
                                                  FROM ge_movimientos b
                                                 WHERE b.fecha = p_fecha
                                                   AND b.nro_documento = v_nro_documento
                                                   AND b.reversado = 'N'
                                                   AND nro_secuencia = (select min(c.nro_secuencia)
                                                                          from ge_movimientos c
                                                                         where c.fecha = b.fecha
                                                                           and c.hora = b.hora
                                                                           and c.cod_usuario = b.cod_usuario
                                                                           and c.nro_documento = b.nro_documento
                                                                             and c.monto is not null);
                                             EXCEPTION
                                                WHEN NO_DATA_FOUND THEN
                                                   raise_application_error(-20305, 'No se encuentra Mov.: '|| v_nro_documento);
                                                WHEN OTHERS THEN
                                                   raise_application_error(-20304, 'Error Obt.Movimiento de Detalle '|| v_nro_documento);
                                             END;

                                        WHEN OTHERS THEN
                                          raise_application_error(-20303, 'Error Obt.Movimiento de Detalle '|| v_nro_documento);
                                    END;
                                WHEN OTHERS THEN
                                  raise_application_error(-20302, 'Error Obt.Movimiento de Detalle '|| v_nro_documento);
                           END;
                        ELSIF p_cod_tra_padre = 247 THEN -- DYDMR-45. CB. 26/03/2014
                            BEGIN
                             SELECT b.monto, b.cotizacion, b.cod_moneda, b.cod_persona
                               INTO v_monto, v_cotizacion, v_cod_moneda, v_cod_per_mov
                                  FROM ge_movimientos b
                                 WHERE b.fecha = p_fecha
                                   AND b.monto = p_monto
                                   AND b.cod_moneda = p_cod_moneda
                                   AND b.nro_documento = v_nro_documento
                                AND b.reversado = 'N';

                             EXCEPTION
                                 WHEN no_data_found then
                                 raise_application_error(-20306, 'No se encuentra Mov.: '|| v_nro_documento);
                              WHEN OTHERS THEN
                                 raise_application_error(-20307, 'Error Obt. Movimiento de Detalle '|| v_nro_documento);
                             END;
                        ELSE
                           raise_application_error(-20402, 'No existe movimiento asociado');
                        End IF;
                     end if;
                  /*
                  ||rabf - 12/nov/2013
                  ||se agrega excepcion por si el cajero ingrese mas de una transaccion
                  */
                  WHEN TOO_MANY_ROWS THEN
                     BEGIN
                        SELECT b.monto, b.cotizacion, b.cod_moneda, b.cod_persona
                          INTO v_monto, v_cotizacion, v_cod_moneda, v_cod_per_mov
                          FROM ge_movimientos b
                         WHERE b.fecha = p_fecha
                           AND b.cod_usuario = p_cod_usuario
                           AND b.monto = p_monto
                           AND b.cod_moneda = p_cod_moneda
                           AND b.nro_documento = v_nro_documento
                           AND b.reversado = 'N'
                           AND B.COD_TRA_PADRE = decode(P_COD_TRA_PADRE,133,352,134,136,P_COD_TRA_PADRE) --DYDMR-5238
                           AND B.COD_MOD_PADRE = P_COD_MOD_PADRE
                           AND B.COD_MAD_PADRE = P_COD_MAD_PADRE
                           AND nro_secuencia = (select min(c.nro_secuencia)
                                                  from ge_movimientos c
                                                 where c.fecha = b.fecha
                                                   and c.hora = b.hora
                                                   and c.cod_usuario = b.cod_usuario
                                                   and c.nro_documento = b.nro_documento
                                                   and c.monto is not null);
                     EXCEPTION
                         WHEN OTHERS THEN
                            raise_application_error(-20702, 'Error Obt.Movimiento ' || SQLERRM);
                     END;
                  WHEN OTHERS THEN
                     raise_application_error(-20502, 'Error Obt.Movimiento ' || SQLERRM);
               END;
            WHEN OTHERS THEN
               raise_application_error(-20602, 'Error Obt.Movimiento ' || SQLERRM);
         END;
         IF v_cod_moneda <> v_cod_mon_fuerte THEN
            v_monto := pag_gen.fu_con_mon_a_moneda(v_cod_moneda, v_cod_mon_fuerte,p_monto,NULL,NULL, v_cotizacion);
         END IF;
      ELSE
         v_monto := pag_gen.fu_con_mon_a_moneda(p_cod_moneda, v_cod_mon_fuerte,p_monto);
      END IF;

      /*IF p_cod_usuario = USER and p_cod_mod_padre <> 9 THEN
            raise_application_error(-20000,
                                    'Usuario no puede ser el mismo que solicita la Reversi¿n');
      END IF;*/ -- Solicitado por Edgar Vergara 17/10/2013
      IF p_cod_mod_padre in (7,9) and p_fecha <> pag_cal.fu_obt_fec_actual(1) THEN
            raise_application_error(-20000,
                                     'Para operaciones de Caja o Cambios,'||
                                     ' solo pueden reversar operaciones del día ');
      END IF;
      IF p_nro_cuenta IS NOT NULL THEN
         -- Trae la modalidad y el modulo de la cuenta
         Begin
            select g.cod_modulo, g.cod_modalidad, g.cod_oficina
              into v_cod_modulo, v_cod_modalidad, v_cod_oficina
              from ge_cuentas g
             where g.nro_cuenta = p_nro_cuenta;
         Exception
            When NO_DATA_FOUND Then
               raise_application_error(-20000, 'Error: Cuenta Inexistente!!!');
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Error Obt.Cuenta ' || SQLERRM);
         End;
         if ((v_cod_modulo in ('5','7'))
         or (v_cod_modalidad in (31,41,42,43,44,45,46,47,48,442,455,32,33,34,35,36)))  THEN
            pag_cta.pr_obt_cuenta(p_nro_cuenta);
            IF pag_cta.g_cod_error <> 0 then
               raise_application_error(-20000, pag_cta.fu_obt_msj_error);
            end if;
         end if;
      end if;
      v_cod_ofi_usuario := fug_obt_ofi_usuario(user);
      /*v_mto_max := fug_obt_pardinamico('PRE_MTO_RIE_REVERSION', p_cod_mod_padre,
                                        p_cod_mad_padre, NULL,
                                        v_cod_ofi_usuario);*/
      v_mto_max := fug_obt_pardinamico('PRE_MTO_RIE_REVERSION', NULL, NULL, 'USD', NULL);
                                       
      IF v_mto_max IS NULL THEN
         raise_application_error(-20000,
                                  'Parámetro de Monto Máximo Riesgo de Reversión ' ||
                                  'no seteado para Modalidad ' ||
                                   fug_obt_des_modal(p_cod_mod_padre,
                                                     p_cod_mad_padre) ||
                                   ' - Oficina ' ||
                                   fue_obt_des_oficina(v_cod_ofi_usuario));
      END IF;

      -- Verifica si existe Pedido Pendiente en GE_MOV_AUTORIZACIONES
       SELECT COUNT(1)
          INTO v_cant
          FROM ge_mov_autorizaciones
         WHERE fecha = p_fecha
           AND hora = p_hora
           AND cod_tra_padre = p_cod_tra_padre
           AND cod_mod_padre = p_cod_mod_padre
           AND cod_mad_padre = p_cod_mad_padre
           AND nvl(nro_cuenta, 'x') = nvl(p_nro_cuenta, 'x')
           AND cod_moneda = p_cod_moneda
           AND estado = 'S';
         IF nvl(v_cant, 0) > 0 THEN
           raise_application_error(-20000, 'ERROR. Existe solicitud pendiente de Autorización. Rechace para reversar la Operación  ');
         Elsif p_cod_tra_padre = 309 Then -- Transferencia entre Cuentas -- C.D.Fase III
               -- Traer la otra cuenta en cuestion del movimiento
             Begin
                 Select a.nro_cuenta
                   into v_nro_cta_transferencia
                   from ge_movimientos a
                  Where a.fecha         = p_fecha
                    and a.hora          = p_hora
                    and a.cod_tra_padre = p_cod_tra_padre
                    and a.cod_mod_padre = p_cod_mod_padre
                    and a.cod_mad_padre = p_cod_mad_padre
                    and a.cod_moneda    = p_cod_moneda
                    and nvl(a.nro_cuenta,'x') != nvl(p_nro_cuenta, 'x');
             Exception
               when no_data_found then
                  v_nro_cta_transferencia:= null;
             End;
               -- Vuelve a buscar con la otra cuenta
               SELECT COUNT(1)
                INTO v_cant
                FROM ge_mov_autorizaciones
               WHERE fecha = p_fecha
                 AND hora = p_hora
                 AND cod_tra_padre = p_cod_tra_padre
                 AND cod_mod_padre = p_cod_mod_padre
                 AND cod_mad_padre = p_cod_mad_padre
                 AND nvl(nro_cuenta, 'x') = nvl(v_nro_cta_transferencia, 'x')
                 AND cod_moneda = p_cod_moneda
                 AND estado = 'S';
               IF nvl(v_cant, 0) > 0 THEN
                 raise_application_error(-20000, 'ERROR. Existe solicitud pendiente de Autorización. Rechace para reversar la Operación  ');
               End If;
         end if;

      IF (nvl(v_monto, 0) >= nvl(v_mto_max, 0)) /*OR (nvl(v_monto, 0) >= 0 and p_cod_mod_padre = 9)*/ THEN -- Riesgo Operativo
        --> 18/08/2013-MB-CRO: Las Operaciones de Caja ya debe generar Autorización desde 1Gs
        SELECT COUNT(1)
          INTO v_cant
          FROM ge_aut_reversiones
         WHERE fecha = p_fecha
           AND hora = p_hora
           AND cod_tra_padre = p_cod_tra_padre
           AND cod_mod_padre = p_cod_mod_padre
           AND cod_mad_padre = p_cod_mad_padre
           AND nvl(nro_cuenta, 'x') = nvl(p_nro_cuenta, 'x')
           AND monto = p_monto
           AND cod_moneda = p_cod_moneda
           AND estado = 'S';

        IF nvl(v_cant, 0) > 0 THEN
           raise_application_error(-20000, 'ERROR. Ya existe solicitud similar');
        ELSE
           -- DYDMR-10041 IEC 06
           SELECT s_cod_autorizacion.nextval INTO v_sig_valor FROM dual;

           IF p_nro_cuenta IS NOT NULL THEN
              v_cod_persona := fug_obt_cli_principal(p_nro_cuenta);
           ELSif v_cod_per_mov is null Then
              BEGIN
                 SELECT cod_persona INTO v_cod_persona
                   FROM ba_usuarios WHERE cod_usuario = USER;
              EXCEPTION
                 WHEN no_data_found THEN
                    raise_application_error(-20000, 'Persona no registrada para usuario '
                                                    || USER);
                 WHEN OTHERS THEN
                    raise_application_error(-20000, 'Error Obt.Persona p/usuario ' || SQLERRM);
              END;
           Else
              v_cod_persona := v_cod_per_mov;
           END IF;

           v_tip_oper        := fug_obt_pardinamico('COD_TIP_CIR_REV_OPE');

           BEGIN
              INSERT INTO ge_aut_reversiones
                 (nro_pedido, fecha, hora, cod_usuario, cod_tra_padre, cod_mod_padre,
                  cod_mad_padre, nro_cuenta, cod_persona, mto_mon_fuerte,cod_usu_autorizador,
                  concepto, nro_documento, estado, cod_oficina, monto, cod_moneda
                  )
              VALUES
                 (v_sig_valor, p_fecha, p_hora, p_cod_usuario,p_cod_tra_padre,p_cod_mod_padre,
                  p_cod_mad_padre, p_nro_cuenta, v_cod_persona, v_monto, user,
                  p_concepto, v_nro_documento, 'S', v_cod_ofi_usuario, p_monto, p_cod_moneda);
           EXCEPTION
              WHEN OTHERS THEN
                 raise_application_error(-20000, 'ERROR.Insert ge_aut_reversiones:'
                                                 || SQLERRM);
           END;

           -- inicia el circuito
           v_cod_error := paw_cir.fu_ini_circuito(v_tip_oper, v_sig_valor, v_cod_persona);
           IF v_cod_error <> 0 THEN
              raise_application_error(-20067, 'Error al generar Circuito. ' || SQLERRM);
           END IF;

        END IF;
    END IF;
    p_nro_solicitud := nvl(v_sig_valor, 0);
   END;
FUNCTION FU_OBT_GRUPO(p_cod_modulo    ge_mov_autorizaciones.cod_mod_padre%TYPE,
                      p_cod_modalidad ge_mov_autorizaciones.cod_mad_padre%TYPE,
                      p_cod_tra_padre ge_mov_autorizaciones.cod_tra_padre%TYPE)
  RETURN number is
  v_grupo number;
BEGIN
  begin
    Select cod_grupo
      into v_grupo
      from ge_par_ope_riesgos r
     where r.cod_modulo = p_cod_modulo
       and r.cod_modalidad = p_cod_modalidad
       and r.cod_transaccion = p_cod_tra_padre;
  exception
    when no_data_found then
      v_grupo := null;
  end;
 return v_grupo;
end;

end pag_rie;
/

