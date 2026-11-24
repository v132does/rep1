CREATE OR REPLACE PROCEDURE IT.PRP_DEB_AUTOMATICO_24x7
(
   p_cod_persona    IN VARCHAR2 DEFAULT NULL,
   --p_nro_cuenta     IN VARCHAR2 DEFAULT NULL,
   p_cta_debito     IN VARCHAR2 DEFAULT NULL
   --p_cod_usu_origen IN VARCHAR2 DEFAULT NULL
) IS
--PRAGMA AUTONOMOUS_TRANSACTION;
   -- variables para rollback
   v_rol_referencia varchar2(15) := 'inicio';
   v_rol_ejecuta    varchar2(1) := 'N';
   v_commitea       varchar2(1) := 'N';
   v_sig_prestamo   varchar2(1) := 'N';
   v_existe         varchar2(1) := 'N';
   /* Inserta movimiento con error. */
   PROCEDURE lp_ins_mov_error;
   v_fecha         ge_calendarios.fec_actual%TYPE;
   v_hora          ge_movimientos.hora%TYPE;
   v_cod_modulo    ba_modulos.cod_modulo%TYPE;
   v_cod_tra_padre ge_transacciones.cod_transaccion%TYPE;
   v_cod_mon_local ba_monedas.cod_moneda%TYPE;
   v_nro_secuencia ge_movimientos.nro_secuencia%TYPE;
   r_gmovi         ge_movimientos%ROWTYPE;
   --- Datos para recuperar deuda del prestamo
   v_pag_parcial  VARCHAR2(01) := 'S';
   v_sal_cobrado  pr_cuotas.sal_capital%TYPE;
   v_sal_capital  pr_cuotas.sal_capital%TYPE;
   v_sal_interes  pr_cuotas.sal_interes%TYPE;
   v_sal_int_ade  pr_cuotas.sal_int_documentado%TYPE;
   v_mora         pr_cuotas.sal_interes%TYPE;
   v_mora_interes pr_cuotas.sal_interes%TYPE;
   v_mora_int_ade pr_cuotas.sal_interes%TYPE;
   v_impuesto     pr_cuotas.sal_interes%TYPE;
   v_cargo        pr_cuotas.sal_interes%TYPE;
   v_cargo_iva    pr_cuotas.sal_interes%TYPE;
   --v_seguro         pr_cuotas.sal_interes%type;
   v_punitorio      pr_cuotas.sal_interes%TYPE;
   v_int_descontado pr_cuotas.sal_interes%TYPE;
   v_mto_deuda      pr_cuotas.sal_capital%TYPE;
   v_nro_cuenta_ant pr_cta_prestamos.nro_cuenta%TYPE;
   v_dias_mora      NUMBER(05);
   --- Datos para utilizar la cuenta de débito
   v_mto_deu_deb    ge_cuentas.sal_contable%TYPE;
   v_cot_mon_pre    ge_cotizaciones.val_conversion%TYPE;
   v_cot_mon_deb    ge_cotizaciones.val_conversion%TYPE;
   v_nvo_estado     ge_cuentas.estado%TYPE;
   v_sal_disponible ge_cuentas.sal_contable%TYPE;
   v_procesa        VARCHAR2(01);
   v_error          VARCHAR2(10);
   v_mensaje        VARCHAR2(1000);
   v_imp_cuenta     pr_cuotas.sal_interes%TYPE;
   v_lin_sobregiro  NUMBER(18, 2) := 0;
   v_con_debito     ge_movimientos.concepto%type;
   v_nro_cta_atraso ge_cuentas.nro_cuenta%type;
   v_cod_usu_origen ge_movimientos.cod_usuario%type;
   v_con_credito    ge_movimientos.concepto%type;
   v_nro_cuota_atraso pr_cuotas.nro_cuota%type;
   v_cod_tra_aguinaldo  ge_transacciones.cod_transaccion%type;
   v_mto_aguinaldo      number := 0;
   v_tot_aguinaldo      number := 0;
   v_fec_ini_mes        date;
   v_cod_ente           ah_cta_vistas.cod_ente%type := null;
   v_dia_aguinaldo      ge_par_dinamicos.val_parametro%type;
   v_fec_aguinaldo      date;
   v_blo_sal_agui       varchar2(1) := nvl(fug_obt_pardinamico('BLO_DEB_SAL_AGUINALDO'),'N');  

   CURSOR c_cta_atrasos IS
      select t.cod_persona, t.nro_cuenta, t.nro_cta_credito,t.cod_modulo,t.cod_usu_origen,cu.nro_cuota
        from ge_cli_cta_atrasos t,ge_cta_dat_adicionales a,ge_cuentas c,ge_par_dinamicos d,pr_cuotas cu
       where t.tie_deposito = 'S'
         and t.cod_modulo = 6
         and t.nro_cta_credito = p_cta_debito
         and t.cod_persona = p_cod_persona
         and t.nro_cuenta = a.nro_cuenta(+)
         and a.parametro(+) = 'EXC_COB_24X7'
         and nvl(a.val_parametro,'N') = 'N'
         and t.nro_cta_credito = c.nro_cuenta
         --and nvl(c.cod_sub_modalidad,999) <> 6--Excluye Ctas. Aguinaldo -- NVB-2176 se comenta la sub modalidad
         and t.cod_modulo = d.cod_modulo
         and d.parametro = 'MOD_COB_24X7'
         and d.val_parametro = 'S'
         and t.mto_mora > nvl(t.tot_cobrado,0) -- No cobrar doble
         --and t.procesado = 'N' --Procesar solo una vez
         and t.nro_cuenta = cu.nro_cuenta
         and cu.fec_vencimiento <= v_fecha
         and cu.nro_cuota > 0
         and cu.estado <> 'N'
       order by cu.fec_vencimiento asc;

   --- Toma todas las cuotas atrasadas de todos los préstamos hasta la fecha actual, y además ordena por
   --- la fecha de vencimiento y el saldo de la cuota para el débito
   --- Procedimiento Modificado para Optimización AP 3006
   CURSOR c_debitos IS
      SELECT pr.nro_cuenta,
             cl.cod_persona,
             pr.nro_cta_debito,
             pr.cod_oficina,
             cu.nro_cuota,
             pr.cod_moneda,
             pr.cod_modulo,
             pr.cod_modalidad,
             cu.nro_documento,
                    (SELECT  MAX(nro_cuota) cuo_hasta
                FROM pr_cuotas
               WHERE fec_vencimiento <= v_fecha
                 AND estado <> 'N'
                 AND nro_cuenta = pr.nro_cuenta
                 AND NVL(sal_capital, 0) + NVL(sal_interes, 0) + NVL(sal_int_documentado, 0) > 0) max_cuota,
            (NVL(cu.sal_capital, 0) + NVL(cu.sal_interes, 0) + NVL(cu.sal_int_documentado, 0)) sal_tot_cuota,
             cu.fec_vencimiento
        FROM ge_cta_clientes cl,
             pr_cta_prestamos pr,
             pr_cuotas cu
       WHERE pr.nro_cuenta = cu.nro_cuenta
         AND pr.nro_cuenta = cl.nro_cuenta
         AND pr.cod_modalidad NOT IN (608) --- no incluir asociaciones ni descuentos documentos
         AND NVL(fug_obt_pardinamico('MAD_ANTICIPOS', pr.cod_modulo,pr.cod_modalidad),'N') = 'N' --No debe incluir Anticipos al Personal
         AND cl.relacion = 'P' --- Cliente principal
         AND pr.estado <> 'N' --- Préstamos no cancelados
         /*AND pr.nro_cta_debito is not null
         AND pr.cob_automatico = 'S'*/
         AND cu.fec_vencimiento <= v_fecha
         AND cu.nro_cuota > 0
         AND cu.estado <> 'N'
         AND (v_nro_cta_atraso/*p_nro_cuenta*/  IS NULL OR pr.nro_cuenta = v_nro_cta_atraso/*p_nro_cuenta*/)
         AND (p_cod_persona IS NULL OR cl.cod_persona = p_cod_persona)
         AND cu.nro_cuota = v_nro_cuota_atraso;
      --   AND (p_cta_debito IS NULL OR pr.nro_cta_debito = p_cta_debito)
      --   and pr.nro_cta_debito not in ('0102148779')
   /* Inserta movimiento con error. */
   PROCEDURE lp_ins_mov_error IS
   BEGIN
      v_nro_secuencia := v_nro_secuencia + 1;
      --- Cargar registro de movimientos
      r_gmovi.fecha         := v_fecha;
      r_gmovi.fec_valor     := v_fecha;
      r_gmovi.cod_usuario   := v_cod_usu_origen;--USER;
      r_gmovi.hora          := v_hora;
      r_gmovi.nro_secuencia := v_nro_secuencia;
      r_gmovi.cod_tra_padre := v_cod_tra_padre;
      r_gmovi.reversado     := 'N';
      r_gmovi.emi_aviso     := 'N';
      r_gmovi.protegido     := 'N';
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
   END;
   FUNCTION lf_obt_mto_aguinaldo(p_nro_cta varchar2) return number IS
    BEGIN
      select sum(a.MONTO)
        into v_mto_aguinaldo
        from gv_movimientos a
       where a.FECHA >= v_fec_ini_mes
         and a.fecha <= v_fecha
         and a.COD_TRA_PADRE = v_cod_tra_aguinaldo
         and a.COD_TRANSACCION = 602
         and a.NRO_CUENTA = p_nro_cta
         and a.REVERSADO = 'N';
      return nvl(v_mto_aguinaldo,0);
    exception
      when no_data_found then
        return 0;
      when others then
        return 0;
    END;

    FUNCTION lf_obt_fec_aguinaldo(p_nro_cta varchar2) return date IS
      v_fec_aguinaldo date;
    BEGIN
      select max(a.fecha)
        into v_fec_aguinaldo
        from gv_movimientos a
       where a.FECHA >= v_fec_ini_mes
         and a.fecha <= v_fecha
         and a.COD_TRA_PADRE = v_cod_tra_aguinaldo
         and a.COD_TRANSACCION = 602
         and a.NRO_CUENTA = p_nro_cta
         and a.REVERSADO = 'N';
      return v_fec_aguinaldo;
    exception
      when no_data_found then
        return null;
      when others then
        return null;
    END;

   /* 24/12/2013 PN DI: Se creó el procedimiento interno con el fin de unificar
                        lo usuarios de los movimientos, debido que en el pag_cta
                        está mal seteado y genera movimientos con usuarios distintos,
                        esto hace que exista un problema al querer reversar (SPI 2883)*/
   PROCEDURE  pr_ver_mov_debito IS

     v_cod_usuario ge_movimientos.cod_usuario%type;
     cursor c_mov_debito is
            select x.rowid registro, cod_usuario
             from ge_movimientos x
            where x.fecha = v_fecha
              and x.hora = v_hora
              and x.cod_usuario <> v_cod_usu_origen
              and cod_tra_padre = v_cod_tra_padre
              and x.cod_transaccion <> 503
              and concepto = v_con_credito
              Union all
            select x.rowid registro, cod_usuario
             from ge_movimientos x
            where x.fecha = v_fecha
              and x.hora = v_hora
              and x.cod_usuario <> v_cod_usu_origen
              and cod_tra_padre = 900
              and x.cod_transaccion is null
              and concepto = 'DEVENGADO EN SUSPENSO';

    cursor c_mov_transfer is
         select x.rowid reg_tran
           from ge_movimientos x
          where fecha = v_fecha
            and hora = v_hora
            and cod_usuario = v_cod_usuario
            and cod_tra_padre = 309;

   BEGIN
     for mov in c_mov_debito loop
       v_cod_usuario := mov.cod_usuario;

       update ge_movimientos x
          set cod_usuario = v_cod_usu_origen--user
        where x.rowid = mov.registro;

       for tra in c_mov_transfer loop

         update ge_movimientos
            set cod_usuario = v_cod_usu_origen--user --
          where rowid = tra.reg_tran;
       end loop;
     end loop;
  END;

   /* 22/04/2016 GC : Se creó el procedimiento interno autonomo, con el fin de registrar
                      los errores en el proceso de debito automatico de prestamos*/
   PROCEDURE pr_ins_log_error(p_nro_cuenta   tm_log_nominas.nro_cuenta%type,
                              p_monto        tm_log_nominas.monto%type,
                              p_sal_total    tm_log_nominas.sal_total%type,
                              p_lugar        tm_log_nominas.lugar%type,
                              p_observacion  tm_log_nominas.observacion%type)
    is
    pragma autonomous_transaction;
    begin
      insert into tm_log_nominas
      (nro_cuenta, monto, sal_total, lugar, observacion, fec_insercion)
      values
      (p_nro_cuenta, p_monto, p_sal_total, p_lugar, p_observacion, sysdate);
       Begin
         update ge_cli_cta_atrasos a
           set a.procesado = 'E'
           where a.cod_persona = p_cod_persona
             and a.nro_cuenta = v_nro_cta_atraso
             and a.nro_cta_credito = p_cta_debito
             and a.procesado <> 'S'
             and a.fec_mov_deb24x7 is null
             and a.hor_mov_deb24x7 is null
             and a.cod_usu_deb24x7 is null
             and a.cod_tra_pad_deb24x7 is null;
       EXCEPTION
       WHEN OTHERS THEN
         null;
       End;
      commit; -- este commit solo afecta a la transaccion autonoma
    end ;

BEGIN
   --- Recuperar datos de fecha calendario
   v_cod_modulo := 6;
   v_fecha      := pag_cal.fu_obt_fec_actual(v_cod_modulo);
   v_nro_secuencia  := 0;
   v_dia_aguinaldo  := nvl(fug_obt_pardinamico('CAN_DIA_DEB_AGUINALDO'),0);
   FOR cta IN c_cta_atrasos LOOP
        v_nro_cta_atraso := cta.nro_cuenta;
        v_nro_cuota_atraso := cta.nro_cuota;
        v_cod_usu_origen := cta.cod_usu_origen;

         v_cod_tra_padre  := 364;
         v_cod_mon_local  := pag_gen.fu_obt_mon_local;
         v_nro_cuenta_ant := 'x';
         v_sig_prestamo   := 'N';
         FOR pre IN c_debitos LOOP
            -- Control de rollback
            v_rol_referencia := pre.nro_cuenta||pre.nro_cuota;
            prg_cre_savepoint(v_rol_referencia);
            v_rol_ejecuta    := 'N';
            v_commitea       := 'N';

            --- Inicializar variables auxiliares
            r_gmovi          := NULL;
            v_sal_cobrado    := NULL;
            v_error          := NULL;
            v_mensaje        := NULL;
            v_sal_capital    := NULL;
            v_sal_interes    := NULL;
            v_sal_int_ade    := NULL;
            v_mora           := NULL;
            v_mora_interes   := NULL;
            v_mora_int_ade   := NULL;
            v_punitorio      := NULL;
            v_impuesto       := NULL;
            v_cargo          := NULL;
            v_cargo_iva      := NULL;
            v_int_descontado := NULL;
            --cotización
            v_cot_mon_pre := NULL;
            v_cot_mon_deb := NULL;
            v_cod_ente    := null;
            begin
              select a.cod_ente
                into v_cod_ente
                from ah_cta_vistas a
               where a.nro_cuenta = pre.nro_cta_debito;
            exception
              when no_data_found then
                v_cod_ente := null;
              when others then
                v_cod_ente := null;
            end;
            if v_cod_ente is not null and nvl(v_blo_sal_agui,'N') = 'S' then
              v_cod_tra_aguinaldo := fug_obt_parentes(v_cod_ente, 'COD_TRA_PAD_AGUINALDO');
              pag_cal.PR_OBT_DAT_CALENDAR(1);
              v_fec_ini_mes := pag_cal.G_PRI_DIA_MES;
              v_tot_aguinaldo := lf_obt_mto_aguinaldo(pre.nro_cta_debito);
              v_fec_aguinaldo := lf_obt_fec_aguinaldo(pre.nro_cta_debito);
            end if;

          /*  IF pre.nro_cuenta <> v_nro_cuenta_ant THEN
               --- Para grabar por cada registro procesado y sus movimientos la misma hora
               --v_hora           := pag_gen.fu_obt_sig_segundo(v_hora);
               v_hora := fug_obt_hor_disponible(v_fecha,v_hora,v_cod_usu_origen\*user*\,'N');
               v_nro_secuencia  := 0;
               v_nro_cuenta_ant := pre.nro_cuenta;
               v_sig_prestamo := 'N';
            ELSE
               -- Prestamo es igual al anterior, continua solo si hubo commit(sino esta prendido v_sig_prestamo)
               IF v_sig_prestamo = 'S' then
                  GOTO siguiente_registro;
               END IF;
            END IF;*/

            --- Inicializar registro de movimiento por si da error
            r_gmovi.cod_ofi_origen := pre.cod_oficina;
            r_gmovi.cod_mod_padre  := pre.cod_modulo;
            r_gmovi.cod_mad_padre  := pre.cod_modalidad;
            r_gmovi.nro_documento  := pre.nro_documento;
            r_gmovi.concepto       := 'Prest.' || pre.nro_cuenta;

            -- movido esta seccion mas arriba, ya que hay muchas cuentas de debito sin saldo de tal forma a
            -- optimizar el tiempo de procesamiento de prestamos que no tienen saldo minimo para el cobro

            --- Recuperar datos de la cuenta de ahorro
            --pag_cta.pr_obt_cuenta(pre.nro_cta_debito);
            pag_cta.pr_obt_cuenta(p_cta_debito);
            r_gmovi.cod_modulo      := pag_cta.g_ctas.cod_modulo;
            r_gmovi.cod_modalidad   := pag_cta.g_ctas.cod_modalidad;
            r_gmovi.nro_cuenta      := p_cta_debito;--pre.nro_cta_debito;
            r_gmovi.cod_moneda      := pag_cta.g_ctas.cod_moneda;
            r_gmovi.cod_transaccion := 503;
            IF pag_cta.g_cod_error <> 0 THEN
               pr_ins_log_error(pre.nro_cuenta,
                                pre.sal_tot_cuota,
                                0,
                                'PRP_DEB_AUTOMATICO_24x7 1',
                                substr(pag_cta.FU_OBT_MSJ_ERROR, 1, 299)); -- 22/04/2016 GC
               GOTO siguiente_registro;
            END IF;
            IF  nvl(fup_obt_tip_descuento(pre.COD_MODALIDAD), 'x') NOT IN('C', 'D') THEN
               begin
                select 'S'
                  into v_existe
                  from pr_cuotas a
                 where a.nro_cuenta = pre.nro_cuenta
                   and a.nro_cuota < pre.nro_cuota
                   and a.nro_cuota > 0
                   and a.estado <> 'N';
               exception
                 when too_many_rows then
                   v_existe := 'S';
                 when others then
                   v_existe := 'N';
               end;
               IF v_existe = 'S' THEN
                  pr_ins_log_error(pre.nro_cuenta,
                                   pre.sal_tot_cuota,
                                   0,
                                   'PRP_DEB_AUTOMATICO_24x7 1.1',
                                   'Existen cuotas anteriores a la cuota ' || pre.nro_cuota || ' que aun estan pendientes'); -- 22/04/2016 GC

                  GOTO siguiente_registro;
               END IF;
            END IF;
            --- Verificar monedas ----
            IF pag_cta.g_ctas.cod_moneda <> pre.cod_moneda AND -- Cta. Débito Vs Préstamo
               pag_cta.g_ctas.cod_moneda <> v_cod_mon_local AND -- Cta. Débito Vs Local
               pre.cod_moneda <> v_cod_mon_local THEN
               GOTO siguiente_registro;
            END IF;
            --- Calculo el total a debitar en la moneda de la cuenta de debito
            pag_gen.pr_con_mon_a_moneda(pre.cod_moneda, pag_cta.g_ctas.cod_moneda, pre.sal_tot_cuota,
                                        v_mto_deu_deb, v_cot_mon_pre, v_cot_mon_deb);
            --- Verificar parámetro de pago para identificar el monto de la deuda
               v_pag_parcial := fug_obt_pardinamico('PAG_COB_AUT', pre.cod_modulo, pre.cod_modalidad,
                                                    pre.cod_moneda, pre.cod_oficina);
            -- se tiene en cuenta la linea de sobregiro
             /* v_lin_sobregiro := 0;
            IF pag_cta.g_ctas.cod_modalidad = 41 THEN
               v_lin_sobregiro := nvl(pag_cta.fu_obt_lin_sobregiro(pre.nro_cta_debito, v_fecha), 0);
            END IF;
          IF (v_pag_parcial = 'N' AND
               nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0) +
               v_lin_sobregiro < nvl(v_mto_deu_deb, 0)) OR
               (v_pag_parcial = 'S' AND
               (nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0) +
               v_lin_sobregiro <= 0 OR
               nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0) +
               v_lin_sobregiro <
               fug_obt_pardinamico('MIN_COB_AUT', pre.cod_modulo, pre.cod_modalidad, pre.cod_moneda,
                                     pre.cod_oficina))) THEN
               pr_ins_log_error(pre.nro_cuenta,
                                pre.sal_tot_cuota,
                                nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0),
                                'PRP_DEB_AUTOMATICO 2',
                                'Saldo no cubre totalidad de la deuda'); -- 22/04/2016 GC
               --- Solo se cobra si el saldo de la cuenta cubre toda la deuda
               GOTO siguiente_registro;
            END IF;*/
            -- agregado hasta aqui para un control previo...

            --- Recuperar deuda a la fecha del proceso
            --- Recuperar deuda de la cuota
            pap_pre.pr_obt_deu_prestamo(pre.nro_cuenta, v_fecha, pre.nro_cuota, pre.nro_cuota,
                                        -- pre.cuo_hasta, F.Q. debe traer solo la deuda de la cuota que trae el cursor
                                        pre.cod_oficina, v_sal_cobrado, v_error, v_mensaje, v_sal_capital,
                                        v_sal_interes, v_sal_int_ade, v_mora, v_mora_interes,
                                        v_mora_int_ade, v_punitorio, v_impuesto, v_cargo, v_cargo_iva,
                                        v_int_descontado, v_dias_mora, v_cod_tra_padre);
            IF v_error <> 0 THEN
               --NO GENERAR MOV CON ERROR XQ DA PROBLEMAS EN ASIENTOS
               ---raise_application_error(-20000, v_mensaje); OJO por ahora error ver + adelante
               /*         r_gmovi.estado    := 'E';
                        r_gmovi.cod_error := fug_obt_err_sueldos(pag_cta.g_cod_error, 'A');
                        --- Grabar movimiento con error
                        lp_ins_mov_error;
               */ --- Ir al Siguiente
               v_rol_ejecuta := 'S';
               pr_ins_log_error(pre.nro_cuenta,
                                pre.sal_tot_cuota,
                                0,
                                'PRP_DEB_AUTOMATICO_24x7 3',
                                substr('Error al recuperar deuda del prestamo '||v_mensaje, 1, 299)); -- 22/04/2016 GC
               GOTO siguiente_registro;
            END IF;
            v_mto_deuda := nvl(v_sal_capital, 0) + nvl(v_sal_interes, 0) + nvl(v_sal_int_ade, 0) +
                           nvl(v_mora, 0) + nvl(v_mora_interes, 0) + nvl(v_mora_int_ade, 0) +
                           nvl(v_punitorio, 0) + nvl(v_impuesto, 0) + nvl(v_cargo, 0);
            --- Calculo el total a debitar en la moneda de la cuenta de debito
            pag_gen.pr_con_mon_a_moneda(pre.cod_moneda, pag_cta.g_ctas.cod_moneda, v_mto_deuda,
                                        v_mto_deu_deb, v_cot_mon_pre, v_cot_mon_deb);
            IF (v_pag_parcial = 'N' AND
               nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0) +
               v_lin_sobregiro < nvl(v_mto_deu_deb, 0)) OR
               (v_pag_parcial = 'S' AND
               (nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0) +
               v_lin_sobregiro <= 0 OR
               nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0) +
               v_lin_sobregiro <
               fug_obt_pardinamico('MIN_COB_AUT', pre.cod_modulo, pre.cod_modalidad, pre.cod_moneda,
                                     pre.cod_oficina))) THEN

              pr_ins_log_error(pre.nro_cuenta,
                      pre.sal_tot_cuota,
                      nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0),
                      'PRP_DEB_AUTOMATICO_24x7 4',
                      'Saldo no cubre totalidad de la deuda Nro. Cuota: '||pre.nro_cuota); -- 22/04/2016 GC
               --- Solo se cobra si el saldo de la cuenta cubre toda la deuda
               GOTO siguiente_registro;
            END IF;
           --calcula impuesto si corresponde y genera movimiento, en moneda de cta débito
            BEGIN
               v_hora := to_char(SYSDATE, 'HH24:MI:SS');
               v_hora := fug_obt_hor_disponible(v_fecha,v_hora,v_cod_usu_origen/*user*/,'N');
               prg_ver_cob_cargos(/*pre.nro_cta_debito*/p_cta_debito, pre.nro_cuenta, pre.cod_modulo, pre.cod_modalidad,
                                  pre.cod_oficina,
                                  --oficina del préstamo, oficina origen
                                  pag_cta.g_ctas.cod_moneda, v_mto_deu_deb,
                                  'Cobro aut. Préstamo ' || pre.nro_cuenta, NULL,
                                  --v_nro_documento,
                                  v_fecha, v_hora, v_imp_cuenta, v_nro_secuencia, 'N'); -- no procesa
            EXCEPTION
               WHEN OTHERS THEN
                  v_imp_cuenta := 0; --para que no caiga
            END;

            IF v_pag_parcial = 'S' AND
               (nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0) +
               v_lin_sobregiro) < nvl(v_mto_deu_deb, 0) + nvl(v_imp_cuenta, 0) THEN
               v_imp_cuenta := (nvl(pag_cta.g_ctas.sal_disponible, 0) +
                               nvl(pag_cta.g_ctas.sal_dis_combinada, 0) + v_lin_sobregiro) /
                               nvl(v_mto_deu_deb, 0) * nvl(v_imp_cuenta, 0);
               IF pre.cod_moneda = pag_gen.fu_obt_mon_local THEN
                  v_imp_cuenta := ceil(v_imp_cuenta);
               END IF;
               v_mto_deu_deb := (nvl(pag_cta.g_ctas.sal_disponible, 0) +
                                nvl(pag_cta.g_ctas.sal_dis_combinada, 0) + v_lin_sobregiro) -
                                nvl(v_imp_cuenta, 0);

            ELSE
               v_mto_deu_deb := nvl(v_mto_deu_deb, 0);
            END IF;
            
            --
            IF nvl(v_blo_sal_agui,'N') = 'S' THEN 
              IF v_cod_ente is not null and ((v_fecha - v_fec_aguinaldo) <= v_dia_aguinaldo) THEN
                IF nvl(pag_cta.g_ctas.sal_disponible,0) - nvl(v_tot_aguinaldo,0) > 0 THEN
                  IF nvl(pag_cta.g_ctas.sal_disponible,0) - nvl(v_tot_aguinaldo,0) < (nvl(v_mto_deu_deb,0)+nvl(v_imp_cuenta,0)) THEN
                    v_mto_deu_deb := nvl(pag_cta.g_ctas.sal_disponible,0) - nvl(v_tot_aguinaldo,0);
                  END IF;
                ELSE
                  GOTO siguiente_registro;
                END IF;
              END IF;
            END IF;
            --- Verificar si puede realizarse la operación sobre la cuenta de débito
            pag_cta.pr_ver_operacion(/*pre.nro_cta_debito*/p_cta_debito, v_cod_tra_padre, r_gmovi.cod_mod_padre,
                                     r_gmovi.cod_mad_padre, 'D', pag_cta.g_ctas.cod_moneda,
                                     nvl(v_mto_deu_deb, 0) + nvl(v_imp_cuenta, 0), pre.cod_oficina,
                                     -- out
                                     pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad, v_nvo_estado,
                                     v_sal_disponible, v_procesa, 503);
            IF pag_cta.g_cod_error <> 0 OR v_procesa = 'N' THEN
               /*         r_gmovi.estado    := 'E';
                        r_gmovi.cod_error := fug_obt_err_sueldos(pag_cta.g_cod_error, 'A');
                        --- Grabar movimiento con error
                        lp_ins_mov_error;
               */ --- Ir al Siguiente
              pr_ins_log_error(pre.nro_cuenta,
                      pre.sal_tot_cuota,
                      nvl(v_sal_disponible,0),
                      'PRP_DEB_AUTOMATICO_24x7 5',
                      substr(pag_cta.FU_OBT_MSJ_ERROR, 1, 299)); -- 22/04/2016 GC
               GOTO siguiente_registro;
            END IF;
            --- COBRAR prestamos
            --- Convertir monto de la deuda a la del prestamo por si varió segun saldo disponible
            --- de la cuenta
            pag_gen.pr_con_mon_a_moneda(pag_cta.g_ctas.cod_moneda, pre.cod_moneda, nvl(v_mto_deu_deb, 0),
                                        v_mto_deuda, v_cot_mon_deb, v_cot_mon_pre);
            -- RI: 30/07/2010: Volver a obtener deuda para controlar que el monto a cobrar
            -- cubra por lo menos los cargos y manejar el error emergente
            pap_pre.pr_obt_deu_prestamo(pre.nro_cuenta, v_fecha, pre.nro_cuota, pre.nro_cuota,
                                        -- pre.cuo_hasta,--F.Q. debe traer solo la deuda de la cuota que trae el cursor
                                        pre.cod_oficina, v_mto_deuda, v_error, v_mensaje, v_sal_capital,
                                        v_sal_interes, v_sal_int_ade, v_mora, v_mora_interes,
                                        v_mora_int_ade, v_punitorio, v_impuesto, v_cargo, v_cargo_iva,
                                        v_int_descontado, v_dias_mora, v_cod_tra_padre);
            IF v_error <> 0 THEN
               v_rol_ejecuta := 'S';
               pr_ins_log_error(pre.nro_cuenta,
                      pre.sal_tot_cuota,
                      nvl(v_sal_disponible,0),
                      'PRP_DEB_AUTOMATICO_24x7 6',
                      substr('Error al obtener monto a cobrar '||v_mensaje, 1, 299)); -- 22/04/2016 GC
               GOTO siguiente_registro;
            END IF;
            --
            v_nro_secuencia := v_nro_secuencia + 1;
            begin
                v_con_credito := 'COB. AUT. C/CTA ' || p_cta_debito;
                pap_pre.pr_cob_prestamo(pre.nro_cuenta, v_mto_deuda, 'N', pre.cod_oficina, pre.nro_cuota,
                                        pre.nro_cuota,
                                        -- pre.cuo_hasta, F.Q. debe cobrar solo la cuota que trae el cursor
                                        v_con_credito, v_fecha,
                                        -- in/out
                                        v_hora, v_nro_secuencia, v_cod_tra_padre, pre.cod_modulo,
                                        pre.cod_modalidad,'N',null,'N','N','N',v_cod_usu_origen);
            exception
               when others then
                  v_rol_ejecuta := 'S';
                  pr_ins_log_error(pre.nro_cuenta,
                                  pre.sal_tot_cuota,
                                  nvl(v_sal_disponible,0),  -- OMM 26/12/2016 DYDMR-5707
                                  'PRP_DEB_AUTOMATICO_24x7 7',
                                  substr('Error al cobro del prestamo'||sqlerrm, 1, 299)); -- 22/04/2016 GC
                  GOTO siguiente_registro;
            end;
            -- se vuelve a obtener los datos de la cuenta de debito, porque pudo haber cambiado en el pap_pre (x garantias cash)
            pag_cta.pr_obt_cuenta(/*pre.nro_cta_debito*/p_cta_debito);
            --calcula impuesto si corresponde y genera movimiento, en moneda de cta débito
            BEGIN
               prg_ver_cob_cargos(/*pre.nro_cta_debito*/p_cta_debito, pre.nro_cuenta, pre.cod_modulo, pre.cod_modalidad,
                                  pre.cod_oficina,
                                  --oficina del préstamo, oficina origen
                                  pag_cta.g_ctas.cod_moneda, v_mto_deu_deb,
                                  'Cobro aut. Préstamo ' || pre.nro_cuenta, NULL,
                                  --v_nro_documento,
                                  v_fecha, v_hora, v_imp_cuenta, v_nro_secuencia, 'S');
            EXCEPTION
               WHEN OTHERS THEN
                  v_imp_cuenta := 0; --para que no caiga
            END;
            --- DEBITAR de la cuenta
            v_nro_secuencia := v_nro_secuencia + 1;
            --**--
             pag_cta.pr_set_variables(v_cod_usu_origen, v_fecha,
                                v_cod_tra_padre,
                                'N',--estado mvto
                                'N',--reversado
                                v_nro_secuencia,
                                'N', -- estado pasa a N
                                pre.cod_oficina,
                                pre.cod_modulo,
                                pre.cod_modalidad);
            --**--
            v_con_debito := 'COBRO AUT. PRESTAMO 24X7 ' || pre.nro_cuenta;
            pag_cta.pr_act_operacion(/*pre.nro_cta_debito*/p_cta_debito, v_hora, 'D', pag_cta.g_ctas.cod_moneda,
                                     nvl(v_mto_deu_deb, 0) + nvl(v_imp_cuenta, 0), v_cod_tra_padre, 503,
                                     pre.nro_documento, NULL, pre.cod_oficina, pre.cod_modulo,
                                     pre.cod_modalidad, NULL, NULL,
                                     v_con_debito, 'S', v_nro_secuencia
                                     , v_fecha);
            if pag_cta.fu_obt_cod_error <> 0 then
                v_rol_ejecuta := 'S';
                pr_ins_log_error(pre.nro_cuenta,
                      pre.sal_tot_cuota,
                      nvl(v_sal_disponible,0),
                      'PRP_DEB_AUTOMATICO_24x7 8',
                      substr(pag_cta.FU_OBT_MSJ_ERROR, 1, 299)); -- 22/04/2016 GC
                GOTO siguiente_registro;
            end if;

            BEGIN
               pr_ver_mov_debito;
             EXCEPTION
               WHEN OTHERS THEN
                  v_rol_ejecuta := 'S';
                  pr_ins_log_error(pre.nro_cuenta,
                                  pre.sal_tot_cuota,
                                  0,
                                  'PRP_DEB_AUTOMATICO_24x7 9',
                                  substr('Error en pr_ver_mov_debito'||sqlerrm,1,299)); -- 22/04/2016 GC
                  GOTO siguiente_registro;
            END;
            v_commitea := 'S';
            --- Siguiente registro
            <<siguiente_registro>>
            -- se controla si se realizará rollback y se prende control para evitar intentos de otras cuotas
            -- del mismo prestamo si este no fue cobrado.
            IF v_rol_ejecuta = 'S' then
               prg_rol_savepoint(v_rol_referencia);
               v_sig_prestamo := 'S';
            ELSIF v_commitea = 'S' THEN
               commit;
            END IF;
            --Actualiza Registro tabla
            IF v_commitea = 'S' THEN
               Begin
                 update ge_cli_cta_atrasos a
                   set a.procesado = 'S',
                       a.tot_cobrado = nvl(a.tot_cobrado,0) + nvl(v_mto_deu_deb, 0) + nvl(v_imp_cuenta, 0),
                       a.fec_mov_deb24x7 = v_fecha,
                       a.hor_mov_deb24x7 = v_hora,
                       a.cod_usu_deb24x7 = v_cod_usu_origen,--user,
                       a.cod_tra_pad_deb24x7 = v_cod_tra_padre
                   where a.cod_persona = p_cod_persona
                     and a.nro_cuenta = v_nro_cta_atraso--p_nro_cuenta
                     and a.nro_cta_credito = p_cta_debito;
               EXCEPTION
               WHEN OTHERS THEN
                 null;
               End;
            END IF;
            v_existe := 'N';
         END LOOP;
   END LOOP;
--COMMIT;
 EXCEPTION
     WHEN OTHERS THEN
        pr_ins_log_error(v_nro_cta_atraso,
                         0,
                         0,
                        'PRP_DEB_AUTOMATICO_24x7 10',
                         substr('Error en PRP_DEB_AUTOMATICO_24x7'||sqlerrm,1,299)); -- 22/04/2016 GC
END;
/

