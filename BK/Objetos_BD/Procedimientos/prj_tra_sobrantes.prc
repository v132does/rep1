CREATE OR REPLACE PROCEDURE IT.prj_tra_sobrantes IS

   v_fec_actual         ge_movimientos.fecha%type;

   CURSOR c_monedas IS
      SELECT s.cod_moneda, sum(s.saldo) saldo
      FROM cj_sobrantes s
      WHERE s.estado = 'A'
        and (trunc(v_fec_actual)-s.fecha) >= 365
        group by s.cod_moneda ;

   CURSOR c_oficinas (p_moneda varchar2) IS
      SELECT a.cod_oficina, a.cod_moneda, sum(a.saldo) saldo
      FROM cj_sobrantes a
      WHERE a.estado = 'A'
        and a.cod_moneda = p_moneda
        and (trunc(v_fec_actual)-a.fecha) >= 365
        group by a.cod_oficina, a.cod_moneda ;

   CURSOR c_sobrantes (p_moneda varchar2, p_oficina number) IS
      SELECT c.nro_sobrante, c.saldo, c.cod_moneda, c.cod_oficina
      FROM cj_sobrantes c
      WHERE c.estado = 'A'
        and c.cod_moneda = p_moneda
        and c.cod_oficina = p_oficina
        and (trunc(v_fec_actual)-c.fecha) >= 365 ;
   /* 17/08/2011 - OMM
   Nuevo procedimiento almacenado a ejecutarse mensualmente para transferir los ¿Sobrantes de Caja¿
   con antigüedad superior a un año a la Caja de Jubilaciones y Pensiones de Empleados de Bancos y Afines.
   El procedimiento debe debitar el saldo a la cuenta operativa donde se depositan los
   sobrantes de caja (se obtiene a través del parámetro dinámico NRO_CTA_SOB_CAJA) y se debe acreditar
   en la cuenta operativa de la Caja de Jubilaciones y Pensiones de Empleados de Bancos y Afines
   (se obtiene a través del parámetro dinámico NRO_CTA_TRA_CAJA).
   El sobrante se debe actualizar a estado Transferido y el saldo debe quedar en cero.
   */
   v_sal_total         cj_sobrantes.saldo%TYPE;
   v_hora              ge_movimientos.hora%type;
   v_hora_cam          ge_movimientos.hora%type;   
   v_cta_sobrante      ge_cuentas.nro_cuenta%type;
   v_cta_credito       ge_cuentas.nro_cuenta%type;
   v_error             varchar2(10);
   v_tra_padre         ge_transacciones.cod_transaccion%type;
   v_mod_padre         ba_modulos.cod_modulo%type;
   v_mad_padre         ge_modalidades.cod_modalidad%type;
   v_tra_pad_cam       ge_transacciones.cod_transaccion%type;
   v_mod_pad_cam       ba_modulos.cod_modulo%type;
   v_mad_pad_cam       ge_modalidades.cod_modalidad%type;
   v_transaccion       ge_transacciones.cod_transaccion%type;
   v_nro_secuencia     number(3) := 0;
   v_cod_mon_local     ba_monedas.cod_moneda%type;
   v_cotizacion        ge_cotizaciones.val_conversion%type;
   v_cod_ofi_ori       ge_cuentas.cod_oficina%type;
   v_nro_documento     ge_movimientos.nro_documento%type;
   v_cod_tip_operacion lc_tip_operaciones.cod_tip_operacion%type;
   v_cod_tip_ref       lc_tip_ope_oficinas.cod_tip_referencia%type;
   v_cod_ope_bcp       lc_tip_operaciones.cod_tip_ope_bcp%type;
   v_nro_operacion     ge_movimientos.nro_documento%type;
   v_tot_mon_local     ge_movimientos.monto%type;
   r_gmovi             ge_movimientos%rowtype;


BEGIN
   v_fec_actual     := pag_cal.fu_obt_fec_actual(1) ;
   v_hora          := to_char(sysdate,'hh24:mi:ss');
   v_tra_padre     := 224;
   v_sal_total     := 0 ;
   v_mod_padre     := 4;
   v_mad_padre     := 47; -- cta. suspenso
   v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;
   v_tra_pad_cam   := 255;
   v_mod_pad_cam   := 7;
   v_mad_pad_cam   := 71;
   v_cod_ofi_ori   := 31; -- Oficina Central
   v_nro_documento := to_number(to_char(sysdate, 'YYYYMMDD')||'000') ;

   FOR r_mon IN c_monedas LOOP
      v_sal_total     := 0 ;
      if r_mon.cod_moneda <> v_cod_mon_local then
          Begin
            Select distinct a.cod_tip_operacion, a.cod_tip_referencia, b.cod_tip_ope_bcp
              into v_cod_tip_operacion, v_cod_tip_ref, v_cod_ope_bcp
            from lc_tip_ope_oficinas a, lc_tip_operaciones b
            where a.cod_tip_operacion = b.cod_tip_operacion
              and a.cod_tip_operacion = 16 -- Compra de ME
              and a.cod_oficina = v_cod_ofi_ori
              and a.cod_moneda = r_mon.cod_moneda ;
           exception
              when others then
                 raise_application_error(-20000, 'Error al buscar Operacion Cambios');
          end ;
      end if;

      FOR r_ofi IN c_oficinas(r_mon.cod_moneda) LOOP
           -- Genera el movimiento de Debito por el total de cada oficina y moneda.
           v_cta_sobrante  := fug_obt_pardinamico('NRO_CTA_SOB_CAJA', NULL, NULL, r_ofi.cod_moneda, r_ofi.cod_oficina);
           v_sal_total := v_sal_total + r_ofi.saldo ;
           v_transaccion := 503 ;
           if nvl(v_cta_sobrante,0) = 0 then
               raise_application_error(-20000, 'Error al obtener parámetro de Cuenta Sobrante');
           end if ;

           if r_mon.cod_moneda = v_cod_mon_local then
               pag_cta.pr_act_operacion(v_cta_sobrante,
                            v_hora,--HORA
                            'D',
                            r_ofi.cod_moneda,      --Moneda de la Operación
                            r_ofi.saldo,           -- Monto
                            v_tra_padre,           --COD_TRA_PADRE (224)
                            v_transaccion,         -- COD_TRA_HIJO (503)
                            null,                  -- NRO_DOCUMENTO
                            null,                  --COTIZACION
                            v_cod_ofi_ori,     --cod_ofi_origen
                            v_mod_padre,           --cod_mod_padre
                            v_mad_padre,           --cod_mad_padre
                            null,                  --cod_tasa
                            null,                  --val_tasa
                            'Deb. Cta. Sobrante x Caja Jubil.',
                            'N',                    --emi_aviso
                            v_nro_secuencia,        -- Nro Secuencia
                            v_fec_actual) ;          -- Fecha Valor
            else
                v_cotizacion := pag_gen.FU_OBT_COTIZACION(r_mon.cod_moneda,v_fec_actual);

                pag_cta.pr_act_operacion(v_cta_sobrante,
                                v_hora,              --HORA
                                'D',                 -- Tipo Operacion
                                r_ofi.cod_moneda,    --Moneda de la Operación
                                r_ofi.saldo,         -- Monto
                                v_tra_pad_cam,       --COD_TRA_PADRE (255)
                                v_transaccion,       -- COD_TRA_HIJO (503)
                                v_nro_documento,     -- NRO_DOCUMENTO
                                v_cotizacion ,       --COTIZACION
                                v_cod_ofi_ori,       --cod_ofi_origen
                                v_mod_pad_cam,       --cod_mod_padre
                                v_mad_pad_cam,       --cod_mad_padre
                               null,                 --cod_tasa
                               null,                 --val_tasa
                               'Deb y Ope. Cambios P/ Caja Jub',
                               'N',                    --emi_aviso
                               v_nro_secuencia,        -- Nro Secuencia
                               v_fec_actual) ;
              end if ;
             if pag_cta.fu_obt_cod_error() <> 0 then
                raise_application_error(-20002, 'Error al generar débito a Cta. Sobrante. ' || pag_cta.FU_OBT_MSJ_ERROR);
             else
               if r_mon.cod_moneda <> v_cod_mon_local then
                  -- Se actualiza para operaciones de cambios
                  update ge_movimientos m
                  set m.cod_ref_cambio = v_cod_tip_ref,
                      m.cod_bco_central = v_cod_ope_bcp,
                      m.cod_tip_ope_cambio = v_cod_tip_operacion
                  where m.fecha = v_fec_actual
                    and m.hora = v_hora
                    and m.monto = r_ofi.saldo
                    and m.cod_tra_padre = v_tra_pad_cam
                    and m.cod_mod_padre = v_mod_pad_cam
                    and m.cod_mad_padre = v_mad_pad_cam
                    and m.cod_transaccion = v_transaccion;
                 end if ;
             end if;
             --v_nro_secuencia := v_nro_secuencia + 1;

              FOR r_sob IN c_sobrantes(r_ofi.cod_moneda, r_ofi.cod_oficina) LOOP
                 -- Se detalla los registros de sobrantes para actualizar los saldos y el estado de los registros afectados.
                  v_error := fuj_act_sal_cajas (r_sob.nro_sobrante, r_sob.saldo, v_cta_sobrante,
                                                r_sob.cod_moneda, r_sob.cod_oficina, 'T');
                  if v_error <> 'N' then
                      raise_application_error(-20000, 'Error al tratar de actualizar Sobrante. ' || SQLERRM);
                  end if ;
              END LOOP;
       END LOOP;
       -- Se genera un Crédito total por moneda a la Caja de Jubilaciones
       v_cta_credito := fug_obt_pardinamico('NRO_CTA_TRA_CAJA', NULL, NULL, v_cod_mon_local, null);
       if nvl(v_cta_credito,0) = 0 then
          raise_application_error(-20000, 'Error al obtener parámetro de Cuenta Caja Jubilaciones.');
       end if ;

       v_transaccion := 602 ;
       if r_mon.cod_moneda = v_cod_mon_local then
           PAG_CTA.PR_OBT_CUENTA(v_cta_credito);
           if v_sal_total = r_mon.saldo  then

               pag_cta.pr_act_operacion(v_cta_credito,
                            v_hora,--HORA
                            'C',
                            r_mon.cod_moneda,      --Moneda de la Operación
                            r_mon.saldo,           -- Monto
                            v_tra_padre,           --COD_TRA_PADRE (224)
                            v_transaccion,         -- COD_TRA_HIJO (602)
                            null,                  -- NRO_DOCUMENTO
                            null,                  --COTIZACION
                            v_cod_ofi_ori,     --cod_ofi_origen
                            v_mod_padre,           --cod_mod_padre
                           v_mad_padre,           --cod_mad_padre
                           null,                  --cod_tasa
                           null,                  --val_tasa
                           'Cre. Caja Jubil. x Sobrant Caja',
                           'N',                    --emi_aviso
                           v_nro_secuencia,        -- Nro Secuencia
                           v_fec_actual) ;          -- Fecha Valor

               if pag_cta.fu_obt_cod_error() <> 0 then
                  raise_application_error(-20003, 'Error al generar Crédito a Cta. Caja Jubilaciones. ' || pag_cta.FU_OBT_MSJ_ERROR);
               end if;
            else
                raise_application_error(-20003, 'Error en el total a acreditar. Favor verificar.');
            end if ;
       else
     -----------------------------------------------------------
     -- Se genera el boleteo de Cambio
     -----------------------------------------------------------
            v_nro_operacion := fug_obt_lla_pardinamico('NRO_RECIBO', 7, 71, r_mon.cod_moneda, v_cod_ofi_ori)+1;
            prg_act_par_dinamico('NRO_RECIBO',7, 71, r_mon.cod_moneda, v_cod_ofi_ori, v_nro_operacion);
      
            -- v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,v_cod_modalidad,v_mon_local);
            v_tot_mon_local := ROUND(NVL(v_cotizacion,0) * r_mon.saldo,0);
            v_hora_cam      := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
            --- genera movimiento ---
            r_gmovi.cod_usuario   := user;
            r_gmovi.hora          := v_hora_cam ;
            r_gmovi.nro_secuencia := 1; -- FIJO 1 para que tome los reportes de cambios
            r_gmovi.cod_modulo    := 7;
            r_gmovi.cod_modalidad := 71;
            r_gmovi.cod_oficina   := v_cod_ofi_ori;
            r_gmovi.nro_cuenta    := null;
            r_gmovi.cod_moneda    :=r_mon.cod_moneda;
            r_gmovi.fec_valor     := v_fec_actual;
            r_gmovi.fecha         := v_fec_actual;
            r_gmovi.cod_tra_padre   := 942;
            r_gmovi.cod_transaccion := 942;
            r_gmovi.nro_documento := v_nro_operacion;
            r_gmovi.nro_documento2 := null;
            r_gmovi.monto         := r_mon.saldo;
            r_gmovi.estado        := 'N';
            r_gmovi.cod_ofi_origen := v_cod_ofi_ori;
            r_gmovi.reversado     := 'N';
            r_gmovi.emi_aviso     := 'N';
            r_gmovi.protegido     := 'N';
            r_gmovi.cod_mod_padre := 7;
            r_gmovi.cod_mad_padre := 71;
            r_gmovi.concepto      := 'Compra Div. p/Oper.Caja Jub. '||r_mon.cod_moneda;
            r_gmovi.cotizacion    := v_cotizacion;
            r_gmovi.mto_equ_local := v_tot_mon_local;
            r_gmovi.cod_tip_ope_cambio := v_cod_tip_operacion;
            r_gmovi.COD_BCO_CENTRAL    := v_cod_ope_bcp;
            pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
      
            --- genera movimiento x persona, para listados ---
            r_gmovi.cod_usuario   := user;
            r_gmovi.hora          := v_hora_cam;
            r_gmovi.nro_secuencia := 2; -- FIJO para que tome los reportes de cambios
            r_gmovi.cod_modulo    := 7;
            r_gmovi.cod_modalidad := 70;
            r_gmovi.cod_oficina   := v_cod_ofi_ori;
            r_gmovi.nro_cuenta    := null;
            r_gmovi.cod_moneda    := r_mon.cod_moneda;
            r_gmovi.fec_valor     := v_fec_actual;
            r_gmovi.fecha         := v_fec_actual;
            r_gmovi.cod_tra_padre   := 942;
            r_gmovi.cod_transaccion := 760;
            r_gmovi.nro_documento := v_nro_operacion;
            r_gmovi.nro_documento2 := fug_obt_cli_principal(v_cta_credito);
            r_gmovi.monto         := 0;
            r_gmovi.estado        := 'N';
            r_gmovi.cod_ofi_origen := v_cod_ofi_ori;
            r_gmovi.reversado     := 'N';
            r_gmovi.emi_aviso     := 'N';
            r_gmovi.protegido     := 'N';
            r_gmovi.cod_mod_padre := 7;
            r_gmovi.cod_mad_padre := 71;
            r_gmovi.concepto      := 'Compra Div. p/Oper.Caja Jub. '||r_mon.cod_moneda;
            r_gmovi.cotizacion    := null;
            r_gmovi.mto_equ_local := null;
            r_gmovi.cod_tip_ope_cambio := null;
            r_gmovi.COD_BCO_CENTRAL    := v_cod_ope_bcp;
            pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
      
            --actualiza la posicion
            UPDATE LC_POSICIONES SET
                   MTO_COM_NEF_ACT = NVL(MTO_COM_NEF_ACT,0) + r_mon.saldo,
                   MTO_COM_NEF_LOC = NVL(MTO_COM_NEF_LOC,0) + v_tot_mon_local
             WHERE COD_TIP_OPE_BCP = v_cod_ope_bcp
               AND COD_MONEDA = r_mon.cod_moneda
               AND COD_OFI_CAMBIO = pal_cam.FU_OBT_OFI_CAMBIO(v_cod_ofi_ori);
            --inserta posicion si no existe
            IF SQL%NOTFOUND THEN
                 INSERT INTO LC_POSICIONES
                     (COD_MONEDA, COD_TIP_OPE_BCP, COD_OFI_CAMBIO,
                      MTO_COM_NEF_ACT, MTO_COM_NEF_LOC)
                 VALUES
                     (r_mon.cod_moneda, v_cod_ope_bcp,
                      pal_cam.FU_OBT_OFI_CAMBIO(v_cod_ofi_ori), ABS(r_mon.saldo), ABS(v_tot_mon_local));
            END IF;
           
           -- Realiza el Crédito a la Cuenta de la Caja de Jub.
            pag_cta.pr_act_operacion(v_cta_credito,
                       v_hora,--HORA
                       'C',
                       v_cod_mon_local,        --Moneda de la Operación
                       ROUND((r_mon.saldo * v_cotizacion),0),           -- Monto
                       v_tra_pad_cam,          --v_tra_padre,
                       v_transaccion,          -- COD_TRA_HIJO (602)
                       v_nro_documento,        -- NRO_DOCUMENTO
                       null,                  --COTIZACION
                       v_cod_ofi_ori,         --cod_ofi_origen
                       v_mod_pad_cam,         --cod_mod_padre
                       v_mad_pad_cam,         --cod_mad_padre
                       null,                  --cod_tasa
                       null,                  --val_tasa
                       'Cre. Caja Jubil. x Sobrant-ME',
                       'N',                    --emi_aviso
                       v_nro_secuencia,        -- Nro Secuencia
                       v_fec_actual) ;          -- Fecha Valor

           if pag_cta.fu_obt_cod_error() <> 0 then
              raise_application_error(-20003, 'Error al generar Crédito a Cta. Caja Jubilaciones' || SQLERRM);
           else
               -- Se actualiza para operaciones de cambios
                update ge_movimientos m
                set m.cod_ref_cambio = v_cod_tip_ref,
                    m.cod_bco_central = v_cod_ope_bcp,
                    m.cod_tip_ope_cambio = 3 -- PAGO CREDITO EN CUENTA
                where m.fecha = v_fec_actual
                  and m.hora = v_hora
                  and m.monto = ROUND((r_mon.saldo * v_cotizacion),0)
                  and m.cod_tra_padre = v_tra_pad_cam
                  and m.cod_mod_padre = v_mod_pad_cam
                  and m.cod_mad_padre = v_mad_pad_cam
                  and m.cod_transaccion = v_transaccion;
           end if;
        end if ;
        v_nro_documento := v_nro_documento + 1 ;
   END LOOP;
END;
/

