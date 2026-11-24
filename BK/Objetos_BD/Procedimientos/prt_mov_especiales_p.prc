CREATE OR REPLACE PROCEDURE IT.prt_mov_especiales_p(p_ref_archivo IN VARCHAR2) IS

   v_hora             ge_movimientos.hora%TYPE;
   v_nro_secuencia    ge_movimientos.nro_secuencia%TYPE;
   v_cod_mon_local    ba_monedas.cod_moneda%TYPE;
   v_cod_modulo       ge_transacciones.cod_modulo%TYPE;
   v_cod_mod_ente     ge_modalidades.cod_modulo%TYPE;
   v_cod_mad_ente     ge_modalidades.cod_modalidad%TYPE;
   v_cod_modalidad    ge_transacciones.cod_modalidad%TYPE;
   v_cod_transaccion  ge_transacciones.cod_transaccion%TYPE;
   v_cod_transaccion2 ge_transacciones.cod_transaccion%TYPE;
   v_cod_transaccion3 ge_transacciones.cod_transaccion%TYPE;
   v_cod_transaccion4 ge_transacciones.cod_transaccion%TYPE;
   v_cod_tra_padre    ge_transacciones.cod_transaccion%TYPE;
   v_por_seg_fraude   pr_parametros.por_riesgo_2%TYPE;
   v_tip_mov_original ge_transacciones.tipo%TYPE;
   v_cod_oficina      ta_cta_tarjetas.cod_oficina%TYPE;
   v_cod_ofi_ente     ba_oficinas.cod_oficina%TYPE;
   v_cod_ofi_matriz   ba_oficinas.cod_oficina%TYPE;
   v_cod_ofi_movimiento ba_oficinas.cod_oficina%TYPE;
   v_est_cuenta       ta_cta_tarjetas.estado%TYPE;
   v_afecta           ge_transacciones.afecta%TYPE;
   v_cod_tra_impuesto ge_transacciones.cod_transaccion%TYPE;
   v_cod_tas_impuesto ge_movimientos.cod_tasa%TYPE;
   v_tip_valor        ge_tasas.tip_valor%TYPE;
   v_tipo             ge_tasas.tipo%TYPE;
   v_val_impuesto     ge_movimientos.monto%TYPE;
   v_oficina          ba_oficinas.cod_oficina%TYPE;
   v_cod_ent_comercio ge_entes.cod_ente%TYPE;
   v_cod_ent_bancard  ge_entes.cod_ente%TYPE;
   v_cod_per_bancard  ge_entes.cod_persona%TYPE;
   v_cod_tip_cargo    VARCHAR2(5);--ta_mov_especiales.cod_tip_cargo%TYPE;
   v_cod_tip_movimiento VARCHAR2(2);-- ta_mov_especiales.cod_tip_movimiento%TYPE;
   v_cod_ori_pago     VARCHAR2(1);--ta_mov_especiales.cod_ori_pago%TYPE;
   v_cod_plan         VARCHAR2(2);--ta_mov_especiales.cod_plan%TYPE;
   v_descripcion      ta_mov_especiales.DES_MOVIMIENTO%TYPE;
   v_fecha            ta_mov_especiales.fecha%TYPE;
   v_procesa          ta_ref_movimientos.procesa%TYPE;
   v_error            ta_mov_especiales.error%TYPE;
   v_acu_mto_seguro   ge_movimientos.monto%type:=0;
   v_acu_mto_entidad  ge_movimientos.monto%type:=0;
   v_nro_cta_comision ge_movimientos.nro_cuenta%TYPE;
   v_acu_com_bancard  ge_movimientos.monto%type:=0;
   v_acu_imp_bancard  ge_movimientos.monto%type:=0;
   v_cta_deb_efectivo ta_mov_especiales.nro_cuenta%TYPE;
   v_mto_deb_pronet   ge_movimientos.monto%type;
   v_mto_deb_web_post ge_movimientos.monto%type;
   v_cod_persona      ge_cta_clientes.cod_persona%type;
   v_cod_per_deb_efe  ge_cta_clientes.cod_persona%type;
   v_cod_mod_cta_ban  ge_transacciones.cod_modulo%TYPE;
   v_cod_mad_cta_ban  ge_transacciones.cod_modalidad%TYPE;
   v_cob_cargo        number(2);
   v_cta_banco        cc_cta_bancarias.nro_cuenta%type;

   --Variables de corte
   v_cor_cuenta   ta_mov_especiales.nro_cuenta%TYPE;
   v_cor_tip_mov  ta_mov_especiales.tip_movimiento%TYPE;
   v_cor_tip_afec ta_mov_especiales.TIP_AFECTACION%TYPE;--ta_mov_especiales.tip_saldo%TYPE;
   v_cor_clase    ta_mov_especiales.clase%TYPE;
   v_afinidad     ta_mov_especiales.afinidad%TYPE;

   -- Variables de registro
   rg_movs ge_movimientos%ROWTYPE;
   --
   v_fcdehoy           DATE;
   v_fec_vigencia      DATE;
   v_cor_movimiento    VARCHAR2(40);
   v_tas_personalizada VARCHAR2(1);
   v_tas_impuesto      ge_movimientos.monto%type:=0;
   v_val_tas_impuesto  ge_movimientos.monto%type:=0;
   v_mto_base          ge_movimientos.monto%type:=0;
   v_mto_impuesto      ge_movimientos.monto%type:=0;
   --Acumulados
   v_acu_monto     ge_movimientos.monto%type:=0;
   v_mto_seg_contable ge_movimientos.monto%type:=0;
   v_acu_iva       ge_movimientos.monto%type:=0;
   v_acu_iva_ent   ge_movimientos.monto%type:=0;
   v_acu_iva_fra   ge_movimientos.monto%type:=0;
   v_acu_iva_seg   ge_movimientos.monto%type:=0;
   v_mon_seg_ent   ge_movimientos.monto%type:=0;
   v_mto_total     ge_movimientos.monto%type:=0;
   v_mto_imponible ge_movimientos.monto%type:=0;
   v_mto_comision  ge_movimientos.monto%type:=0;
   v_mto_interes   ge_movimientos.monto%type:=0;
   v_existe        NUMBER := 0;
   v_fila          ROWID;
   v_redondeo      NUMBER;

   -- Cursor de los movimientos
   CURSOR c1 IS
      SELECT p.fecha,
             p.des_movimiento,--p.descripcion,
             p.mto_operacion,
             p.mto_impuesto,
             p.mto_int_corriente,
             p.mto_int_mora,
             p.mto_int_punitorio,
             p.MTO_IVA_AFE_CIE_5 mto_cie_iva5,--p.mto_cie_iva5,
             p.nro_cuenta,
             ROWID fila,
             nvl (p.tip_movimiento , 'D') cod_tip_movimiento,
             fec_movimiento
        FROM ta_mov_especiales p
       WHERE ref_archivo = p_ref_archivo
         AND cod_usu_proceso = USER
         AND fecha = v_fcdehoy
         AND nvl(procesado, 'N') = 'N'
         AND error IS NULL
         AND cod_rubro IS NULL
        ORDER BY nro_cuenta, des_movimiento, cod_tip_movimiento;

   CURSOR c2 IS --Cursor para los mov.del Informe Financiero
      SELECT p.nro_cuenta,
             p.tip_movimiento,
             decode(tip_movimiento, 'V', clase, NULL) clase,
             decode(tip_movimiento, 'D', p.tip_afectacion, 'C', p.tip_afectacion, NULL) tip_afectacion,
             p.mto_operacion,
             p.mto_impuesto,
             p.fecha,
             ROWID fila
        FROM ta_mov_especiales p
       WHERE ref_archivo = p_ref_archivo
         AND cod_usu_proceso = USER
         AND fecha = v_fcdehoy
         AND nvl(procesado, 'N') = 'N'
         AND error IS NULL
         AND cod_rubro IS NULL
       ORDER BY nro_cuenta,
                tip_movimiento,
                decode(tip_movimiento, 'V', clase, NULL),
                decode(tip_movimiento, 'D', p.tip_afectacion, 'C', p.tip_afectacion, NULL);

   CURSOR c3 IS --Cursor que trae los rubros y los monto ingresados por pantalla (Informe Financiero)
      SELECT p.cod_rubro, p.mto_operacion
        FROM ta_mov_especiales p
       WHERE ref_archivo = p_ref_archivo
         AND cod_usu_proceso = USER
         AND fecha = v_fcdehoy
         AND nvl(procesado, 'N') = 'N'
         AND cod_rubro IS NOT NULL;

   CURSOR c4 IS -- Cursor de Movimientos Diarios
      SELECT p.nro_cuenta,
             p.tip_movimiento,
             p.tip_afectacion,
             p.mto_operacion,
             p.mto_impuesto,
             p.mto_int_cuota,
             p.fecha,
             p.des_movimiento,
             p.fec_movimiento,
             p.cod_tip_cargo,
             p.cod_plan,
             p.mto_comision,
             p.can_cuotas,
             p.cod_ori_pago,
             p.fec_proceso,
             p.est_cuota,
             p.cod_ofi_origen,
             ROWID fila
        FROM ta_mov_especiales p
       WHERE p.ref_archivo = p_ref_archivo
         AND p.cod_usu_proceso = USER
         AND p.fecha = v_fcdehoy
         AND nvl(p.procesado, 'N') = 'N'
         AND error IS NULL
         AND (est_cuota is null
         or (p.cod_plan='03' and p.cod_tip_cargo='38' and p.est_cuota is not null))
         AND (NVL(FUE_OBT_VAL_MAX_REFERENCIA ('TAR_MOV_ESPECIAL', p.des_movimiento),'N') <> 'S'
         AND instr (upper (p.des_movimiento),  ('AJUSTE'), 1) <> '1')
        /*  Las cuotas con estado Forzado corresponden a compras y adelantos en cuotas donde no corresponde
          contabilizar el resto de las cuotas que vienen en el archivo solo la primera vez, donde viene
          sin estado de cuotas */
       ORDER BY nro_cuenta, tip_movimiento, p.tip_afectacion, p.cod_tip_cargo, cod_plan;

   CURSOR c5 IS -- Cursor de Seguro de Vida
      SELECT p.nro_cuenta,
             p.mto_impuesto,
             p.fecha,
             p.des_movimiento,
             p.fec_movimiento,
             ROWID fila,
             p.mto_seg_usuario,
             p.afinidad,
             p.mto_seg_entidad,
             nvl(p.tip_movimiento, 'D') cod_tip_movimiento
        FROM ta_mov_especiales p
       WHERE p.ref_archivo = p_ref_archivo
         AND p.cod_usu_proceso = USER
         AND p.fecha = v_fcdehoy
         AND nvl(p.procesado, 'N') = 'N'
         and nro_cuenta in('636904142','635002171')
         AND error IS NULL
       ORDER BY afinidad;

   -----
   -- Procedimientos Internos
   ----
   PROCEDURE lp_act_err_mov_especiales
   (
      p_nro_cuenta IN ta_mov_especiales.nro_cuenta%TYPE,
      p_error      IN ta_mov_especiales.error%TYPE
   ) IS
   BEGIN
      v_error := p_error;
      IF p_error IS NOT NULL AND p_nro_cuenta IS NOT NULL THEN
         UPDATE ta_mov_especiales
            SET error     = p_error,
                procesado = 'N'
          WHERE nro_cuenta = p_nro_cuenta
            AND ROWID = v_fila;
      END IF;
   END;

 PROCEDURE pr_env_mai_inf_log IS
   v_cant_error number;
   v_dir_correo ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('MAI_REG_ERR_BANCARD');
   --v_fec_actual date:= pag_cal.fu_obt_fec_actual(5);
 BEGIN
     begin
       select count(*)
       into v_cant_error
       from ta_logs s
       where s.nom_proceso='prt_mov_especiales'
       and comentario not like '%***%'
       and trunc(fec_hor_ini)=trunc(sysdate);
       exception
         when no_Data_found then
           v_cant_error:=0;
           when others then
             v_cant_error:=0;
           null;
        end;
       if v_cant_error>0 then
          it_mail.mail(fug_obt_dir_correo,
                       v_dir_correo,
                       'Proceso movimientos diarios de Bancard - '||to_char(sysdate, 'dd/mm/yyyy'),
                       'Proceso concluido con errores en fecha '||to_char(sysdate, 'dd/mm/yyyy') ||',favor verificar.'
                       ||chr(10)|| 'Atentamente.');
       else
        if fug_obt_pardinamico('ENV_MAI_EXI_BANCARD')='S' then
          it_mail.mail(fug_obt_dir_correo,
                       v_dir_correo,
                       'Proceso movimientos diarios de Bancard - '||to_char(sysdate, 'dd/mm/yyyy'),
                       'Proceso concluido con éxito.'||
                       'Fecha:'|| to_char(sysdate, 'dd/mm/yyyy') ||'.'||
                       chr(10) || 'Atentamente.');
         end if;
       end if;
 END;

   PROCEDURE pr_act_movimientos IS
   BEGIN
      --Limpiar variables
      v_cod_transaccion   := NULL;
      v_cod_transaccion2  := NULL;
      v_cod_transaccion3  := NULL;
      v_tip_mov_original  := NULL;
      v_cod_tra_impuesto  := NULL;
      v_tas_personalizada := NULL;
      v_cod_tas_impuesto  := NULL;
      v_val_tas_impuesto  := NULL;
      v_fec_vigencia      := NULL;
      v_tip_valor         := NULL;
      v_tipo              := NULL;
      v_val_impuesto      := NULL;
      v_cod_modulo        := NULL;
      v_cod_modalidad     := NULL;
      v_cod_oficina       := NULL;
      v_est_cuenta        := NULL;
      --Traer datos de la cuenta
      BEGIN
         SELECT cod_modulo, cod_modalidad, cod_oficina, decode(cat_automatica,'1','C','2','V','3','G','4','M','M') estado
           INTO v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_est_cuenta
           FROM ta_cta_tarjetas
          WHERE nro_cuenta = v_cor_cuenta;
      EXCEPTION
         WHEN no_data_found THEN
            lp_act_err_mov_especiales(v_cor_cuenta, 'No existen datos de la Cuenta.' || SQLERRM);
         WHEN OTHERS THEN
            lp_act_err_mov_especiales(v_cor_cuenta, 'Error al obtener datos de la Cuenta.' || SQLERRM);
      END;
      v_cod_persona := fug_obt_cli_principal(v_cor_cuenta);
      ---------------------------------------------------------------------------------------
      IF p_ref_archivo = 'TAR_MOV_ESPECIALES' THEN
         ---------------------------------------------------------------------------------------
         --Traer Transaccion asociada al movimiento
         BEGIN
            SELECT cod_transaccion
              INTO v_cod_transaccion
              FROM ta_ref_movimientos
             WHERE ref_archivo = p_ref_archivo
               AND descripcion = v_cor_movimiento;
            BEGIN
               SELECT tipo
                 INTO v_tip_mov_original
                 FROM ge_transacciones
                WHERE cod_modulo = v_cod_modulo
                  AND cod_modalidad = v_cod_modalidad
                  AND cod_transaccion = v_cod_transaccion;
            EXCEPTION
               WHEN OTHERS THEN
                  lp_act_err_mov_especiales(v_cor_cuenta,
                                            'TAR_MOV_ESPECIALES: Error al obtener datos de la Transacción :' ||
                                             v_cod_transaccion || 'Referencia de Movimientos: ' ||
                                             v_cor_movimiento);
            END;
         EXCEPTION
            WHEN OTHERS THEN
               lp_act_err_mov_especiales(v_cor_cuenta,'Error al obtener datos de Referencia de Movimientos ' ||
                                          v_cor_movimiento);
         END;
         --Si el tipo de movimiento recibio es distinto al tipo de movimiento natural de la transaccion
         --de la referencia del movimiento se debe grabar movimiento con signo negativo.
         IF v_cor_tip_mov = v_tip_mov_original THEN
            rg_movs.monto := v_acu_monto;
         ELSE
            rg_movs.monto := v_acu_monto * -1;
         END IF;
         v_procesa         := 'S';
         --------------------------------------------------------------------------------------
      ELSIF p_ref_archivo = 'TAR_INF_GAS_FINANCIEROS' THEN
         --(GF050)
         --------------------------------------------------------------------------------------
         v_cod_transaccion := 1505;
         rg_movs.monto     := v_acu_monto;
         v_procesa         := 'S';
         -- Para las gastos financieros, se debe tomar la categoría anterior por el orden de ejecución de los procesos
         --Traer datos de la cuenta
         BEGIN
            SELECT decode(cat_automatica,'1','C','2','V','3','G','4','M','C') estado
              INTO v_est_cuenta
              FROM ta_cta_tarjetas
             WHERE nro_cuenta = v_cor_cuenta;
         EXCEPTION
            WHEN no_data_found THEN
               lp_act_err_mov_especiales(v_cor_cuenta, 'No existen datos de la Cuenta.' || SQLERRM);
            WHEN OTHERS THEN
               lp_act_err_mov_especiales(v_cor_cuenta, 'Error al obtener datos de la Cuenta.' || SQLERRM);
         END;

         --------------------------------------------------------------------------------------
      ELSIF p_ref_archivo = 'TAR_INF_FINANCIERO' THEN
         --------------------------------------------------------------------------------------
         --Traer Transaccion asociada al movimiento
         BEGIN
            SELECT cod_transaccion, cod_transaccion2
              INTO v_cod_transaccion, v_cod_transaccion2
              FROM ta_ref_movimientos
             WHERE ref_archivo = p_ref_archivo
               AND ((descripcion = v_cor_tip_mov AND length(descripcion) = 1 AND
                   v_cor_tip_mov <> 'V')
                   --
                   OR (v_cor_tip_mov = 'V' AND substr(descripcion, 1, 1) = v_cor_tip_mov AND
                   ((substr(descripcion, 2) = v_cor_clase AND v_cor_clase = '17') OR
                   (substr(descripcion, 2) IS NULL AND v_cor_clase <> '17')))
                   --
                   OR (v_cor_tip_mov <> 'V' AND substr(descripcion, 1, 1) = v_cor_tip_mov AND
                   length(descripcion) > 1 AND substr(descripcion, 2) = v_cor_tip_afec));
            --
            BEGIN
               SELECT tipo
                 INTO v_tip_mov_original
                 FROM ge_transacciones
                WHERE cod_modulo = v_cod_modulo
                  AND cod_modalidad = v_cod_modalidad
                  AND cod_transaccion = v_cod_transaccion;
            EXCEPTION
               WHEN OTHERS THEN
                  lp_act_err_mov_especiales( v_cor_cuenta,'TAR_INF_FINANCIERO: Error al obtener datos de la Transacción :' || v_cod_transaccion ||'Referencia de Movimientos: '||v_cor_movimiento );
            END;
         EXCEPTION
            WHEN OTHERS THEN
               lp_act_err_mov_especiales( v_cor_cuenta,'Error al obtener datos de Referencia de Movimientos ' || v_cor_movimiento||'Tipo de Movimiento:'||v_cor_tip_mov||'Tipo débito:'||v_cor_tip_afec);
         END;
         --
         rg_movs.monto := v_acu_monto;
         v_procesa         := 'S';
         --------------------------------------------------------------------------------------
      ELSIF p_ref_archivo = 'TAR_INF_FIN_CIERRE' THEN
         --------------------------------------------------------------------------------------
         --Traer Transaccion asociada al movimiento
         BEGIN
            SELECT cod_transaccion, cod_transaccion2
              INTO v_cod_transaccion, v_cod_transaccion2
              FROM ta_ref_movimientos
             WHERE ref_archivo = p_ref_archivo
               AND ((descripcion = v_cor_tip_mov AND length(descripcion) = 1) OR
                   (substr(descripcion, 1, 1) = v_cor_tip_mov AND length(descripcion) > 1 AND
                   substr(descripcion, 2) = v_cor_tip_afec));
            --
            BEGIN
               SELECT tipo
                 INTO v_tip_mov_original
                 FROM ge_transacciones
                WHERE cod_modulo = v_cod_modulo
                  AND cod_modalidad = v_cod_modalidad
                  AND cod_transaccion = v_cod_transaccion;
            EXCEPTION
               WHEN OTHERS THEN
                  lp_act_err_mov_especiales( v_cor_cuenta,'Error al obtener datos de la transaccion : '||v_cod_transaccion||' Referencia de Movimientos : '||v_cor_movimiento||' Error : '||sqlerrm);
            END;
         EXCEPTION
            WHEN OTHERS THEN
               lp_act_err_mov_especiales( v_cor_cuenta,'Error al obtener datos de Referencia del Tipo de Movimiento : '||v_cor_tip_mov||' Tip_deb : '||v_cor_tip_afec||' Error : '||sqlerrm);
         END;
         --
         rg_movs.monto := v_acu_monto;
         v_procesa         := 'S';
         --------------------------------------------------------------------------------------
      ELSIF p_ref_archivo = 'TAR_MOV_DIARIO' THEN
         -- (PBMOVDIARIO)
         ---------------------------------------------------------------------------------------
         --Traer Transaccion asociada al movimiento
         
         BEGIN
            SELECT cod_transaccion, cod_transaccion2, cod_transaccion3, procesa , cod_transaccion4
              INTO v_cod_transaccion, v_cod_transaccion2, v_cod_transaccion3, v_procesa, v_cod_transaccion4
              FROM ta_ref_movimientos
             WHERE ref_archivo = p_ref_archivo
               AND cod_referencia = v_cod_tip_cargo;
            --
            BEGIN
               SELECT tipo
                 INTO v_tip_mov_original
                 FROM ge_transacciones
                WHERE cod_modulo = v_cod_modulo
                  AND cod_modalidad = v_cod_modalidad
                  AND cod_transaccion = v_cod_transaccion;
            EXCEPTION
               WHEN OTHERS THEN
                  lp_act_err_mov_especiales(v_cor_cuenta,
                                            'TAR_MOV_DIARIO: Error al obtener datos de la Transacción :' ||
                                             v_cod_transaccion || 'Referencia de Movimientos: ' ||
                                             v_cor_movimiento);
            END;
         EXCEPTION
            WHEN OTHERS THEN
               lp_act_err_mov_especiales(v_cor_cuenta, 'Error al obtener datos de Referencia de Movimientos ' ||
                                          v_cor_movimiento);
         END;


        /*Identificar pagos desde atm*/

        IF v_cod_tip_cargo = '25' and  v_cod_ori_pago = 'A' THEN

         v_cod_transaccion :='1507';

        END IF;
         /*Para Adelanto Efectivo ATM -- PBMOVDIARIO*/
         IF v_cod_tip_cargo = '39' THEN
            IF v_cod_tip_cargo = '39' AND v_cod_plan = 20 THEN
               v_cod_transaccion := '1657';
            ELSIF (v_cod_plan = 21 and NVL(FUE_OBT_VAL_MAX_REFERENCIA ('TAR_ATM_CONCEPTO', v_descripcion),'N') <> 'S' ) THEN
               v_cod_transaccion := 1657;
            ELSIF v_cod_plan = 21 THEN
               v_cod_transaccion  := 1643;
            END IF;
         END IF;


         /*Para Reversion de adelantos atm exterior*/
         IF v_cod_tip_cargo = '42' and v_cod_tip_movimiento = 'C' THEN
          v_acu_monto := v_acu_monto * -1;
         END IF;


         /*Para Tipo de Movimiento 33*/
         IF v_cod_tip_cargo = '33' and NVL(FUE_OBT_VAL_MAX_REFERENCIA ('TAR_MOV_ESPECIAL', v_descripcion),'N') <> 'S' THEN

            If v_cod_tip_movimiento = 'C' AND UPPER(v_descripcion) <> UPPER('Gestión Recupero por') then
               v_cod_transaccion  := v_cod_transaccion3;
               v_cod_transaccion2 := v_cod_transaccion4;
               v_cod_transaccion3 := null;
               v_cod_transaccion4 := null;
            else
              if UPPER(v_descripcion) = UPPER('Gestión Recupero por') then
               v_cod_transaccion  := 1539; --- GESTION DE RECUPERO POR MORA.
               v_cod_transaccion2 := 1636; --- GESTION DE RECUPERO POR MORA.
              else
               v_cod_transaccion2 := 1634; --- para pagos por Mora
              end if;
               v_cod_transaccion3 := null;
               v_cod_transaccion4 := null;
            End if;
            BEGIN
               SELECT tipo
                 INTO v_tip_mov_original
                 FROM ge_transacciones
                WHERE cod_modulo = v_cod_modulo
                  AND cod_modalidad = v_cod_modalidad
                  AND cod_transaccion = v_cod_transaccion;
            EXCEPTION
               WHEN OTHERS THEN
                  lp_act_err_mov_especiales(v_cor_cuenta,
                                            'TAR_MOV_DIARIO: Error al obtener datos de la Transacción :' ||
                                             v_cod_transaccion || 'Referencia de Movimientos: ' ||
                                             v_cor_movimiento);
            END;
            rg_movs.monto := nvl(v_mto_total, 0);
            v_acu_monto   := nvl(v_acu_monto, 0);
            v_mto_base    := v_acu_monto;
            if v_cod_tip_movimiento <> v_tip_mov_original then
               v_acu_iva     := nvl(v_acu_iva, 0)*-1;
              if UPPER(v_descripcion) = UPPER('Gestión Recupero por') then
               v_acu_monto   := nvl(v_acu_monto, 0)*-1;
               v_mto_base    := v_acu_monto*-1;
              end if;
            else
               v_acu_iva     := nvl(v_acu_iva, 0);
            end if;

         END IF;

         /*Para Seguro contra Fraude*/
         --Si son reversiones de compras no debe cambiar el simbolo del movimiento en este punto.
         IF v_cod_tip_cargo NOT IN ('6','33') THEN
           if NVL(v_tip_mov_original,'D') = nvl(v_cod_tip_movimiento,'D') or v_cod_tip_cargo in('41','44','38')   then
              rg_movs.monto := v_acu_monto;
              v_mto_base    := rg_movs.monto;
           else
              rg_movs.monto := v_acu_monto * -1;
              v_mto_base    := rg_movs.monto * -1;
           end if;

            if v_cod_tip_movimiento <> v_tip_mov_original AND v_cod_tip_cargo = '28' then
               v_acu_iva     := nvl(v_acu_iva, 0)*-1;
               v_mto_base    := rg_movs.monto;
               v_cod_transaccion2 := 1602 ; ---
            end if;


         END IF;

         /* Para Cobros en Efectivo: Pronet, post y/o web */
         IF v_mto_deb_pronet > 0 THEN -- Pronet
            v_cod_transaccion  := 1509;
         ELSIF v_mto_deb_web_post > 0 THEN -- Post y Web
            v_cod_transaccion  := 1510;
         END IF;
      END IF;
      --------------------------------------------------------------------------------------
       /*Monto imponible para Gastos Financieros*/
      --------------------------------------------------------------------------------------
      /*-- Monto Imponible--*/
      IF nvl(v_mto_imponible, 0) <> 0 AND v_error IS NULL THEN
         v_cod_transaccion := 1645; --CARGO DE MOV. DE INTERESES
         IF v_nro_secuencia > 990 THEN
            v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
            v_nro_secuencia := 0;
         END IF;
         v_nro_secuencia         := v_nro_secuencia + 1;
         rg_movs.nro_secuencia   := v_nro_secuencia;
         rg_movs.hora            := v_hora;
         rg_movs.cod_mod_padre   := 5;
         rg_movs.cod_mad_padre   := 505;
         rg_movs.cod_tra_padre   := v_cod_tra_padre;
         rg_movs.cod_modulo      := v_cod_modulo;
         rg_movs.cod_modalidad   := v_cod_modalidad;
         rg_movs.cod_transaccion := v_cod_transaccion;
         rg_movs.cod_moneda      := v_cod_mon_local;
         rg_movs.nro_cuenta      := v_cor_cuenta;
         rg_movs.cod_oficina     := v_cod_oficina;
         rg_movs.nro_documento   := NULL;
         rg_movs.nro_documento2  := NULL;
         rg_movs.cod_tasa        := NULL;
         rg_movs.val_tasa        := NULL;
         rg_movs.cotizacion      := NULL;
         rg_movs.emi_aviso       := 'N';
         rg_movs.cod_ofi_origen  := v_cod_oficina;
         rg_movs.concepto        := v_cor_movimiento;
         rg_movs.estado          := 'N';
         rg_movs.est_cuenta      := v_est_cuenta;
         rg_movs.reversado       := 'N';
         rg_movs.emi_aviso       := 'N';
         rg_movs.nro_caja        := NULL;
         rg_movs.cod_rubro       := NULL;
         rg_movs.tip_mov_rubro   := NULL;
         ---
         v_mto_base              := v_mto_imponible;
         rg_movs.monto           := v_mto_imponible;
         ---

         rg_movs.cod_persona     := v_cod_persona;
         --
         pag_gen.pr_ins_ge_movimiento(rg_movs, 'N');

          --Verificar si tiene Impuesto y Generar el movimiento por el mismo
         --Busco el impuesto asociado a este cargo
         BEGIN
            SELECT cod_tra_hijo
              INTO v_cod_tra_impuesto
              FROM ge_transacciones_det
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = v_cod_transaccion
               AND cod_mod_hijo = v_cod_modulo
               AND cod_mad_hijo = v_cod_modalidad
               AND cod_tra_hijo <> v_cod_transaccion -- Que la transacción hijo sea diferente de la padre PV 02/11/09
               AND rownum = 1;

            -- Traer tasa del impuesto
            pag_gen.pr_obt_val_tasa(v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cor_cuenta,
                                    v_cod_mon_local, 0, nvl(v_tas_personalizada, 'N'),
                                    v_cod_tas_impuesto, v_cod_tra_impuesto, trunc(SYSDATE),
                                    v_val_tas_impuesto, v_fec_vigencia, v_tip_valor, v_tipo);

            v_val_impuesto := v_acu_iva;

         EXCEPTION
            WHEN no_data_found THEN
               IF v_acu_iva > 0 THEN
                  lp_act_err_mov_especiales(v_cor_cuenta,
                                            'No se ha definido transacción de Iva para : ' ||
                                             v_cod_modalidad || '-' || v_cod_transaccion);
               ELSE
                  NULL;
               END IF;
            WHEN OTHERS THEN
               lp_act_err_mov_especiales(v_cor_cuenta, 'Al procesar impuesto - ' || SQLERRM);
         END;
         --
         IF nvl(v_val_impuesto, 0) <> 0 THEN
            /* Grabar el movimiento con la transaccion definida para la referencia recibida */
            IF v_nro_secuencia > 990 THEN
               v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
               v_nro_secuencia := 0;
            END IF;
            rg_movs.monto := v_val_impuesto;

            v_nro_secuencia         := v_nro_secuencia + 1;
            rg_movs.hora            := v_hora;
            rg_movs.nro_secuencia   := v_nro_secuencia;
            rg_movs.cod_mod_padre   := 5;
            rg_movs.cod_mad_padre   := 505;
            rg_movs.cod_tra_padre   := v_cod_tra_padre;
            rg_movs.cod_modulo      := v_cod_modulo;
            rg_movs.cod_modalidad   := v_cod_modalidad;
            rg_movs.cod_transaccion := v_cod_tra_impuesto;
            rg_movs.cod_moneda      := v_cod_mon_local;
            rg_movs.nro_cuenta      := v_cor_cuenta;
            rg_movs.cod_oficina     := v_cod_oficina;
            rg_movs.nro_documento   := NULL;
            rg_movs.nro_documento2  := NULL;
            rg_movs.cod_tasa        := v_cod_tas_impuesto;
            rg_movs.val_tasa        := v_val_tas_impuesto;
            rg_movs.cotizacion      := NULL;
            rg_movs.emi_aviso       := 'N';
            rg_movs.cod_ofi_origen  := v_cod_oficina;
            rg_movs.concepto        := v_cor_movimiento;
            rg_movs.estado          := 'N';
            rg_movs.est_cuenta      := v_est_cuenta;
            rg_movs.reversado       := 'N';
            rg_movs.emi_aviso       := 'N';
            rg_movs.nro_caja        := NULL;
            rg_movs.cod_rubro       := NULL;
            rg_movs.tip_mov_rubro   := NULL;
            v_mto_impuesto          := rg_movs.monto;
            rg_movs.cod_persona     := v_cod_persona;
            --
            pag_gen.pr_ins_ge_movimiento(rg_movs, 'N'); -- inserta datos en ge_movimientos
            --
         END IF;
            --- Debe inicializar
            v_cod_transaccion := 1505;
            rg_movs.monto     := v_acu_monto;
            v_procesa         := 'S';
            v_acu_iva         := 0;
            v_val_impuesto    := 0;
            v_cod_tra_impuesto := null;
      END IF;

      --------------------------------------------------------------------------------------
        /*Seguro de vida*/
      --------------------------------------------------------------------------------------
        /*Ganancia = Seguro de Vida (Seguro Usuario - Seguro Entidad)*/
      --------------------------------------------------------------------------------------
      IF v_cod_tra_padre = 20 THEN
          /*-- Cargo Seguro Entidad Monto Total --*/
         /*IF nvl(v_mon_seg_ent, 0) <> 0 AND v_error IS NULL THEN
            v_cod_transaccion3 := 1033; -- Transacción Cargo Seguro Entidad
            IF v_nro_secuencia > 990 THEN
               v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
               v_nro_secuencia := 0;
            END IF;
            v_nro_secuencia         := v_nro_secuencia + 1;
            rg_movs.nro_secuencia   := v_nro_secuencia;
            rg_movs.hora            := v_hora;
            rg_movs.cod_mod_padre   := 5;
            rg_movs.cod_mad_padre   := 505;
            rg_movs.cod_tra_padre   := v_cod_tra_padre;
            rg_movs.cod_modulo      := v_cod_modulo;
            rg_movs.cod_modalidad   := v_cod_modalidad;
            rg_movs.cod_transaccion := v_cod_transaccion3;
            rg_movs.cod_moneda      := v_cod_mon_local;
            rg_movs.nro_cuenta      := v_cor_cuenta;
            rg_movs.cod_oficina     := v_cod_oficina;
            rg_movs.nro_documento   := NULL;
            rg_movs.nro_documento2  := NULL;
            rg_movs.cod_tasa        := NULL;
            rg_movs.val_tasa        := NULL;
            rg_movs.cotizacion      := NULL;
            rg_movs.emi_aviso       := 'N';
            rg_movs.cod_ofi_origen  := v_cod_oficina;
            rg_movs.concepto        := v_cor_movimiento;
            rg_movs.estado          := 'N';
            rg_movs.est_cuenta      := v_est_cuenta;
            rg_movs.reversado       := 'N';
            rg_movs.emi_aviso       := 'N';
            rg_movs.nro_caja        := NULL;
            rg_movs.cod_rubro       := NULL;
            rg_movs.tip_mov_rubro   := NULL;
            v_mto_base              := v_mon_seg_ent;
            rg_movs.monto           := v_mon_seg_ent;
            rg_movs.cod_persona     := v_cod_persona;
            --
            pag_gen.pr_ins_ge_movimiento(rg_movs, 'N'); -- inserta datos en ge_movimientos
         END IF;*/

         IF (nvl(v_acu_monto, 0) - nvl(v_mto_seg_contable/*v_mon_seg_ent*/, 0)) <> 0 AND v_error IS NULL THEN
            /*IF v_nro_secuencia > 990 THEN
               v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
               v_nro_secuencia := 0;
            END IF;
            v_nro_secuencia         := v_nro_secuencia + 1;
            rg_movs.nro_secuencia   := v_nro_secuencia;
            rg_movs.hora            := v_hora;
            rg_movs.cod_mod_padre   := 5;
            rg_movs.cod_mad_padre   := 505;
            rg_movs.cod_tra_padre   := v_cod_tra_padre;
            rg_movs.cod_modulo      := v_cod_modulo;
            rg_movs.cod_modalidad   := v_cod_modalidad;
            rg_movs.cod_transaccion := 1081;
            rg_movs.cod_moneda      := v_cod_mon_local;
            rg_movs.nro_cuenta      := v_cor_cuenta;
            rg_movs.cod_oficina     := v_cod_oficina;
            rg_movs.nro_documento   := NULL;
            rg_movs.nro_documento2  := NULL;
            rg_movs.cod_tasa        := NULL;
            rg_movs.val_tasa        := NULL;
            rg_movs.cotizacion      := NULL;
            rg_movs.emi_aviso       := 'N';
            rg_movs.cod_ofi_origen  := v_cod_oficina;
            rg_movs.concepto        := v_cor_movimiento;
            rg_movs.estado          := 'N';
            rg_movs.est_cuenta      := v_est_cuenta;
            rg_movs.reversado       := 'N';
            rg_movs.emi_aviso       := 'N';
            rg_movs.nro_caja        := NULL;
            rg_movs.cod_rubro       := NULL;
            rg_movs.tip_mov_rubro   := NULL;

            v_mto_base              := (nvl(v_acu_monto, 0) -
                                       (nvl(v_mon_seg_ent, 0) + nvl(v_acu_iva_ent, 0)));
            rg_movs.monto           := (nvl(v_acu_monto, 0) -
                                       (nvl(v_mon_seg_ent, 0) + nvl(v_acu_iva_ent, 0)));

            rg_movs.cod_persona     := v_cod_persona;
            --
            pag_gen.pr_ins_ge_movimiento(rg_movs, 'N'); -- inserta datos en ge_movimientos*/

            --- Total de Suma de ambos montos ---
             IF nvl (v_mto_seg_contable , 0) <> 0 THEN
                IF v_nro_secuencia > 990 THEN
                   v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
                   v_nro_secuencia := 0;
                END IF;
                rg_movs.monto           := v_mto_seg_contable;

                v_nro_secuencia         := v_nro_secuencia + 1;
                rg_movs.hora            := v_hora;
                rg_movs.nro_secuencia   := v_nro_secuencia;
                rg_movs.cod_mod_padre   := 5;
                rg_movs.cod_mad_padre   := 505;
                rg_movs.cod_tra_padre   := v_cod_tra_padre;
                rg_movs.cod_modulo      := v_cod_modulo;
                rg_movs.cod_modalidad   := v_cod_modalidad;
                rg_movs.cod_transaccion := 1085;
                rg_movs.cod_moneda      := v_cod_mon_local;
                rg_movs.nro_cuenta      := v_cor_cuenta;
                rg_movs.cod_oficina     := v_cod_oficina;
                rg_movs.nro_documento   := NULL;
                rg_movs.nro_documento2  := NULL;
                rg_movs.cod_tasa        := NULL;
                rg_movs.val_tasa        := NULL;
                rg_movs.cotizacion      := NULL;
                rg_movs.emi_aviso       := 'N';
                rg_movs.cod_ofi_origen  := v_cod_oficina;
                rg_movs.concepto        := v_cor_movimiento;
                rg_movs.estado          := 'N';
                rg_movs.est_cuenta      := v_est_cuenta;
                rg_movs.reversado       := 'N';
                rg_movs.emi_aviso       := 'N';
                rg_movs.nro_caja        := NULL;
                rg_movs.cod_rubro       := NULL;
                rg_movs.tip_mov_rubro   := NULL;
                v_mto_impuesto          := rg_movs.monto;

                rg_movs.cod_persona     := v_cod_persona;
                --
                pag_gen.pr_ins_ge_movimiento(rg_movs, 'N'); -- inserta datos en ge_movimientos
             END IF;

            --- Busca IVA
            --Verificar si tiene Impuesto y Generar el movimiento por el mismo
            --Busco el impuesto asociado a este cargo
            BEGIN
               SELECT cod_tra_hijo
                 INTO v_cod_tra_impuesto
                FROM ge_transacciones_det
                WHERE cod_modulo = v_cod_modulo
                  AND cod_modalidad = v_cod_modalidad
                  AND cod_transaccion = 1081
                  AND cod_mod_hijo = v_cod_modulo
                  AND cod_mad_hijo = v_cod_modalidad
                  AND cod_tra_hijo <> 1081 -- Que la transacción hijo sea diferente de la padre PV 02/11/09
                  AND rownum = 1;

               -- Traer tasa del impuesto
               pag_gen.pr_obt_val_tasa(v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cor_cuenta,
                                       v_cod_mon_local, 0, nvl(v_tas_personalizada, 'N'),
                                       v_cod_tas_impuesto, v_cod_tra_impuesto, trunc(SYSDATE),
                                       v_val_tas_impuesto, v_fec_vigencia, v_tip_valor, v_tipo);
               --- Asignar al impuesto
               v_val_impuesto := v_acu_iva_ent;
            EXCEPTION
               WHEN no_data_found THEN
                  IF v_acu_iva_ent > 0 THEN
                     lp_act_err_mov_especiales(v_cor_cuenta,
                                            'No se ha definido transacción de Iva para : ' ||
                                             v_cod_modalidad || '-' || v_cod_transaccion);
                  ELSE
                     NULL;
                  END IF;
               WHEN OTHERS THEN
                  lp_act_err_mov_especiales(v_cor_cuenta, 'Al procesar impuesto - ' || SQLERRM);
            END;
               IF nvl(v_val_impuesto, 0) <> 0 THEN
                  IF v_nro_secuencia > 990 THEN
                     v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
                     v_nro_secuencia := 0;
                  END IF;
                  rg_movs.monto := v_val_impuesto;

                  v_nro_secuencia         := v_nro_secuencia + 1;
                  rg_movs.hora            := v_hora;
                  rg_movs.nro_secuencia   := v_nro_secuencia;
                  rg_movs.cod_mod_padre   := 5;
                  rg_movs.cod_mad_padre   := 505;
                  rg_movs.cod_tra_padre   := v_cod_tra_padre;
                  rg_movs.cod_modulo      := v_cod_modulo;
                  rg_movs.cod_modalidad   := v_cod_modalidad;
                  rg_movs.cod_transaccion := v_cod_tra_impuesto;
                  rg_movs.cod_moneda      := v_cod_mon_local;
                  rg_movs.nro_cuenta      := v_cor_cuenta;
                  rg_movs.cod_oficina     := v_cod_oficina;
                  rg_movs.nro_documento   := NULL;
                  rg_movs.nro_documento2  := NULL;
                  rg_movs.cod_tasa        := v_cod_tas_impuesto;
                  rg_movs.val_tasa        := v_val_tas_impuesto;
                  rg_movs.cotizacion      := NULL;
                  rg_movs.emi_aviso       := 'N';
                  rg_movs.cod_ofi_origen  := v_cod_oficina;
                  rg_movs.concepto        := v_cor_movimiento;
                  rg_movs.estado          := 'N';
                  rg_movs.est_cuenta      := v_est_cuenta;
                  rg_movs.reversado       := 'N';
                  rg_movs.emi_aviso       := 'N';
                  rg_movs.nro_caja        := NULL;
                  rg_movs.cod_rubro       := NULL;
                  rg_movs.tip_mov_rubro   := NULL;
                  v_mto_impuesto          := rg_movs.monto;

                  rg_movs.cod_persona     := v_cod_persona;
                  --
                  pag_gen.pr_ins_ge_movimiento(rg_movs, 'N'); -- inserta datos en ge_movimientos
                  --
               END IF;
         END IF;
      END IF;
      IF p_ref_archivo = 'TAR_SEG_VIDA' THEN
         -- Cargo Seguro Vida(Cierre).
         v_cod_transaccion  := 25;
         rg_movs.monto      := v_acu_monto;
         v_procesa          := 'S';
         v_val_impuesto     := 0;
         v_cod_tra_impuesto := 0;

      ELSIF p_ref_archivo = 'TAR_MOV_INTERESES' THEN
         --(PBRESUPLANCUENTA)
         --------------------------------------------------------------------------------------
         v_cod_transaccion  := 1504;
         v_tip_mov_original := 'D';
         IF v_cor_tip_mov = 'R' THEN
            --Se reversa el movimiento
            rg_movs.monto := (v_acu_monto * -1 ) + v_acu_iva;
         ELSE
            rg_movs.monto := v_acu_monto + v_acu_iva;
         END IF;
         v_procesa         := 'S';
      END IF;
         /*Movimiento Diario monto de Seguro c/Fraude*/
        /*Movimiento de Monto de Seguro contra Fraude Entidad aseguradora*/
      IF nvl(v_acu_mto_entidad, 0) <> 0 AND v_error IS NULL THEN
         IF v_nro_secuencia > 990 THEN
            v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
            v_nro_secuencia := 0;
         END IF;
         v_nro_secuencia         := v_nro_secuencia + 1;
         rg_movs.nro_secuencia   := v_nro_secuencia;
         rg_movs.hora            := v_hora;
         rg_movs.cod_mod_padre   := 5;
         rg_movs.cod_mad_padre   := 505;
         rg_movs.cod_tra_padre   := v_cod_tra_padre;
         rg_movs.cod_modulo      := v_cod_modulo;
         rg_movs.cod_modalidad   := v_cod_modalidad;
         rg_movs.cod_transaccion := v_cod_transaccion2;
         rg_movs.cod_moneda      := v_cod_mon_local;
         rg_movs.nro_cuenta      := v_cor_cuenta;
         rg_movs.cod_oficina     := v_cod_oficina;
         rg_movs.nro_documento   := NULL;
         rg_movs.nro_documento2  := NULL;
         rg_movs.cod_tasa        := NULL;
         rg_movs.val_tasa        := NULL;
         rg_movs.cotizacion      := NULL;
         rg_movs.emi_aviso       := 'N';
         rg_movs.cod_ofi_origen  := v_cod_oficina;
         rg_movs.concepto        := v_cor_movimiento;
         rg_movs.estado          := 'N';
         rg_movs.est_cuenta      := v_est_cuenta;
         rg_movs.reversado       := 'N';
         rg_movs.emi_aviso       := 'N';
         rg_movs.nro_caja        := NULL;
         rg_movs.cod_rubro       := NULL;
         rg_movs.tip_mov_rubro   := NULL;
         rg_movs.monto           := v_acu_mto_seguro;
         if v_tip_mov_original <> v_cod_tip_movimiento then
            rg_movs.monto           := v_acu_mto_seguro*-1;
         end if;
         rg_movs.cod_persona     := v_cod_persona;
         --
         pag_gen.pr_ins_ge_movimiento(rg_movs, 'N'); -- inserta datos en ge_movimientos

         -- Se agrega el IVA para el monto del seguro
          --Verificar si tiene Impuesto y Generar el movimiento por el mismo
         --Busco el impuesto asociado a este cargo
        BEGIN
            SELECT cod_tra_hijo
              INTO v_cod_tra_impuesto
              FROM ge_transacciones_det
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = v_cod_transaccion2
               AND cod_mod_hijo = v_cod_modulo
               AND cod_mad_hijo = v_cod_modalidad
               AND cod_tra_hijo <> v_cod_transaccion2 -- Que la transacción hijo sea diferente de la padre PV 02/11/09
               AND rownum = 1;

            -- Traer tasa del impuesto
            pag_gen.pr_obt_val_tasa(v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cor_cuenta,
                                    v_cod_mon_local, 0, nvl(v_tas_personalizada, 'N'),
                                    v_cod_tas_impuesto, v_cod_tra_impuesto, trunc(SYSDATE),
                                    v_val_tas_impuesto, v_fec_vigencia, v_tip_valor, v_tipo);


             v_acu_iva_seg := round((v_acu_mto_seguro/v_val_tas_impuesto),2);
             v_val_impuesto := v_acu_iva_seg;

         EXCEPTION
            WHEN no_data_found THEN
               IF v_acu_iva > 0 THEN
                  lp_act_err_mov_especiales(v_cor_cuenta,
                                            'No se ha definido transacción de Iva para : ' ||
                                             v_cod_modalidad || '-' || v_cod_transaccion);
               ELSE
                  NULL;
               END IF;
            WHEN OTHERS THEN
               lp_act_err_mov_especiales(v_cor_cuenta, 'Al procesar impuesto - ' || SQLERRM);
         END;
         --
         IF nvl(v_val_impuesto, 0) <> 0 THEN
            /* Grabar el movimiento con la transaccion definida para la referencia recibida */
            IF v_tip_mov_original <> v_cod_tip_movimiento THEN
               --Se reversa el movimiento
               rg_movs.monto := v_val_impuesto * -1;
            ELSE
               rg_movs.monto := v_val_impuesto;
            END IF;
            IF v_nro_secuencia > 990 THEN
               v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
               v_nro_secuencia := 0;
            END IF;
            v_nro_secuencia         := v_nro_secuencia + 1;
            rg_movs.hora            := v_hora;
            rg_movs.nro_secuencia   := v_nro_secuencia;
            rg_movs.cod_mod_padre   := 5;
            rg_movs.cod_mad_padre   := 505;
            rg_movs.cod_tra_padre   := v_cod_tra_padre;
            rg_movs.cod_modulo      := v_cod_modulo;
            rg_movs.cod_modalidad   := v_cod_modalidad;
            rg_movs.cod_transaccion := v_cod_tra_impuesto;
            rg_movs.cod_moneda      := v_cod_mon_local;
            rg_movs.nro_cuenta      := v_cor_cuenta;
            rg_movs.cod_oficina     := v_cod_oficina;
            rg_movs.nro_documento   := NULL;
            rg_movs.nro_documento2  := NULL;
            rg_movs.cod_tasa        := v_cod_tas_impuesto;
            rg_movs.val_tasa        := v_val_tas_impuesto;
            rg_movs.cotizacion      := NULL;
            rg_movs.emi_aviso       := 'N';
            rg_movs.cod_ofi_origen  := v_cod_oficina;
            rg_movs.concepto        := v_cor_movimiento;
            rg_movs.estado          := 'N';
            rg_movs.est_cuenta      := v_est_cuenta;
            rg_movs.reversado       := 'N';
            rg_movs.emi_aviso       := 'N';
            rg_movs.nro_caja        := NULL;
            rg_movs.cod_rubro       := NULL;
            rg_movs.tip_mov_rubro   := NULL;
            v_mto_impuesto          := rg_movs.monto;
            rg_movs.cod_persona     := v_cod_persona;
            --
            pag_gen.pr_ins_ge_movimiento(rg_movs, 'N'); -- inserta datos en ge_movimientos
            --
         END IF;
      END IF;

       /*Monto de Seguro contra Fraude Entidad*/
      IF nvl(v_acu_mto_entidad, 0) <> 0 AND v_error IS NULL THEN
         IF v_nro_secuencia > 990 THEN
            v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
            v_nro_secuencia := 0;
         END IF;
         v_nro_secuencia         := v_nro_secuencia + 1;
         rg_movs.nro_secuencia   := v_nro_secuencia;
         rg_movs.hora            := v_hora;
         rg_movs.cod_mod_padre   := 5;
         rg_movs.cod_mad_padre   := 505;
         rg_movs.cod_tra_padre   := v_cod_tra_padre;
         rg_movs.cod_modulo      := v_cod_modulo;
         rg_movs.cod_modalidad   := v_cod_modalidad;
         rg_movs.cod_transaccion := v_cod_transaccion3;
         rg_movs.cod_moneda      := v_cod_mon_local;
         rg_movs.nro_cuenta      := v_cor_cuenta;
         rg_movs.cod_oficina     := v_cod_oficina;
         rg_movs.nro_documento   := NULL;
         rg_movs.nro_documento2  := NULL;
         rg_movs.cod_tasa        := NULL;
         rg_movs.val_tasa        := NULL;
         rg_movs.cotizacion      := NULL;
         rg_movs.emi_aviso       := 'N';
         rg_movs.cod_ofi_origen  := v_cod_oficina;
         rg_movs.concepto        := v_cor_movimiento;
         rg_movs.estado          := 'N';
         rg_movs.est_cuenta      := v_est_cuenta;
         rg_movs.reversado       := 'N';
         rg_movs.emi_aviso       := 'N';
         rg_movs.nro_caja        := NULL;
         rg_movs.cod_rubro       := NULL;
         rg_movs.tip_mov_rubro   := NULL;
         rg_movs.monto           := v_acu_mto_entidad;
         if  v_tip_mov_original <> v_cod_tip_movimiento then
            rg_movs.monto           := v_acu_mto_entidad*-1;
         end if;
         rg_movs.cod_persona     := v_cod_persona;
         --
         pag_gen.pr_ins_ge_movimiento(rg_movs, 'N'); -- inserta datos en ge_movimientos

         -- Iva Seguro contra Fraude--
          --Verificar si tiene Impuesto y Generar el movimiento por el mismo
         --Busco el impuesto asociado a este cargo
         BEGIN
            SELECT cod_tra_hijo
              INTO v_cod_tra_impuesto
              FROM ge_transacciones_det
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = v_cod_transaccion3
               AND cod_mod_hijo = v_cod_modulo
               AND cod_mad_hijo = v_cod_modalidad
               AND cod_tra_hijo <> v_cod_transaccion3 -- Que la transacción hijo sea diferente de la padre PV 02/11/09
               AND rownum = 1;

            -- Traer tasa del impuesto
            pag_gen.pr_obt_val_tasa(v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cor_cuenta,
                                    v_cod_mon_local, 0, nvl(v_tas_personalizada, 'N'),
                                    v_cod_tas_impuesto, v_cod_tra_impuesto, trunc(SYSDATE),
                                    v_val_tas_impuesto, v_fec_vigencia, v_tip_valor, v_tipo);


            v_acu_iva_fra := round((v_acu_mto_entidad/v_val_tas_impuesto),2);
            v_val_impuesto := v_acu_iva_fra;

         EXCEPTION
            WHEN no_data_found THEN
               IF v_acu_iva > 0 THEN
                  lp_act_err_mov_especiales(v_cor_cuenta,
                                            'No se ha definido transacción de Iva para : ' ||
                                             v_cod_modalidad || '-' || v_cod_transaccion);
               ELSE
                  NULL;
               END IF;
            WHEN OTHERS THEN
               lp_act_err_mov_especiales(v_cor_cuenta, 'Al procesar impuesto - ' || SQLERRM);
         END;
         --
         IF nvl(v_val_impuesto, 0) <> 0 THEN
            /* Grabar el movimiento con la transaccion definida para la referencia recibida */
            IF v_tip_mov_original <> v_cod_tip_movimiento THEN
               --Se reversa el movimiento
               rg_movs.monto := v_val_impuesto * -1;
            ELSE
               rg_movs.monto := v_val_impuesto;
            END IF;
            IF v_nro_secuencia > 990 THEN
               v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
               v_nro_secuencia := 0;
            END IF;
            v_nro_secuencia         := v_nro_secuencia + 1;
            rg_movs.hora            := v_hora;
            rg_movs.nro_secuencia   := v_nro_secuencia;
            rg_movs.cod_mod_padre   := 5;
            rg_movs.cod_mad_padre   := 505;
            rg_movs.cod_tra_padre   := v_cod_tra_padre;
            rg_movs.cod_modulo      := v_cod_modulo;
            rg_movs.cod_modalidad   := v_cod_modalidad;
            rg_movs.cod_transaccion := v_cod_tra_impuesto;
            rg_movs.cod_moneda      := v_cod_mon_local;
            rg_movs.nro_cuenta      := v_cor_cuenta;
            rg_movs.cod_oficina     := v_cod_oficina;
            rg_movs.nro_documento   := NULL;
            rg_movs.nro_documento2  := NULL;
            rg_movs.cod_tasa        := v_cod_tas_impuesto;
            rg_movs.val_tasa        := v_val_tas_impuesto;
            rg_movs.cotizacion      := NULL;
            rg_movs.emi_aviso       := 'N';
            rg_movs.cod_ofi_origen  := v_cod_oficina;
            rg_movs.concepto        := v_cor_movimiento;
            rg_movs.estado          := 'N';
            rg_movs.est_cuenta      := v_est_cuenta;
            rg_movs.reversado       := 'N';
            rg_movs.emi_aviso       := 'N';
            rg_movs.nro_caja        := NULL;
            rg_movs.cod_rubro       := NULL;
            rg_movs.tip_mov_rubro   := NULL;
            v_mto_impuesto          := rg_movs.monto;
            rg_movs.cod_persona     := v_cod_persona;
            --
            pag_gen.pr_ins_ge_movimiento(rg_movs, 'N'); -- inserta datos en ge_movimientos
            --
         END IF;
         v_val_impuesto:=0;
         --- Setear el monto del Movimimento con el Monto total
         rg_movs.monto           := v_mto_total;
      END IF;

      --------------------------------------------------------------------------------------
      /* Grabar el movimiento con la transaccion definida*/
      --------------------------------------------------------------------------------------
      IF nvl(rg_movs.monto, 0) <> 0 AND v_error IS NULL and nvl(v_procesa,'N') = 'S' THEN
         IF v_nro_secuencia > 990 THEN
            v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
            v_nro_secuencia := 0;
         END IF;
         IF NVL(v_cod_tip_movimiento,'D') = NVL(v_tip_mov_original,'D') then
            rg_movs.monto := nvl(rg_movs.monto, 0);
         ELSIF v_cod_tip_cargo <> '28' THEN
            rg_movs.monto := nvl(rg_movs.monto, 0) *-1;
         END IF;
         IF v_cod_tip_cargo in ('27', '28','7','29','30') THEN
            v_cta_banco := fug_obt_parentes(fug_obt_pardinamico('COD_PRO_BANCARD'), 'NRO_CTA_BCO_SPONSOR');
            BEGIN
               SELECT cod_oficina
                 INTO v_cod_ofi_ente
                 FROM ge_cuentas
                WHERE nro_cuenta = v_cta_banco;
            EXCEPTION
               WHEN no_data_found THEN
                  lp_act_err_mov_especiales(v_cta_banco, 'No exise cuenta. Parametro del Ente: NRO_CTA_BCO_SPONSOR. ');

               WHEN OTHERS THEN
                  lp_act_err_mov_especiales(v_cta_banco, 'Error al recuperar cuenta. Parametro del Ente: NRO_CTA_BCO_SPONSOR.' || SQLERRM);
            END;
         ELSE
            v_cod_ofi_ente := v_cod_oficina;
         END IF;
         v_nro_secuencia         := v_nro_secuencia + 1;
         rg_movs.nro_secuencia   := v_nro_secuencia;
         rg_movs.hora            := v_hora;
         rg_movs.cod_mod_padre   := 5;
         rg_movs.cod_mad_padre   := 505;
         rg_movs.cod_tra_padre   := v_cod_tra_padre;
         rg_movs.cod_modulo      := v_cod_modulo;
         rg_movs.cod_modalidad   := v_cod_modalidad;
         rg_movs.cod_transaccion := v_cod_transaccion;
         rg_movs.cod_moneda      := v_cod_mon_local;
         rg_movs.nro_cuenta      := v_cor_cuenta;
         rg_movs.cod_oficina     := v_cod_oficina;
         rg_movs.nro_documento   := NULL;
         rg_movs.nro_documento2  := NULL;
         rg_movs.cod_tasa        := NULL;
         rg_movs.val_tasa        := NULL;
         rg_movs.cotizacion      := NULL;
         rg_movs.emi_aviso       := 'N';
         rg_movs.cod_ofi_origen  := v_cod_oficina;
         rg_movs.concepto        := v_cor_movimiento;
         rg_movs.estado          := 'N';
         rg_movs.est_cuenta      := v_est_cuenta;
         rg_movs.reversado       := 'N';
         rg_movs.emi_aviso       := 'N';
         rg_movs.nro_caja        := NULL;
         rg_movs.cod_rubro       := NULL;
         rg_movs.tip_mov_rubro   := NULL;
         rg_movs.cod_persona     := v_cod_persona;
         --- aca estaba el mto. base
         --
         pag_gen.pr_ins_ge_movimiento(rg_movs, 'N'); -- inserta datos en ge_movimientos
         --
         --Verificar si tiene Impuesto y Generar el movimiento por el mismo
         --Busco el impuesto asociado a este cargo
         BEGIN
            SELECT cod_tra_hijo
              INTO v_cod_tra_impuesto
              FROM ge_transacciones_det
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = v_cod_transaccion
               AND cod_mod_hijo = v_cod_modulo
               AND cod_mad_hijo = v_cod_modalidad
               AND cod_tra_hijo <> v_cod_transaccion -- Que la transacción hijo sea diferente de la padre PV 02/11/09
               AND rownum = 1;

            -- Traer tasa del impuesto
            pag_gen.pr_obt_val_tasa(v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cor_cuenta,
                                    v_cod_mon_local, 0, nvl(v_tas_personalizada, 'N'),
                                    v_cod_tas_impuesto, v_cod_tra_impuesto, trunc(SYSDATE),
                                    v_val_tas_impuesto, v_fec_vigencia, v_tip_valor, v_tipo);

             IF v_cod_tip_cargo = '32' and v_cod_transaccion = 1544 then
              v_acu_iva:= round(nvl( rg_movs.monto,0)* nvl(v_val_tas_impuesto,0)/(100+v_val_tas_impuesto),v_redondeo);
             END IF;
            --Si el iva ya viene calculado en el archivo, verificar que se la misma tasa,
            --si no se debe calcular el iva sobre el monto recibido
            /*Excluir de este control a Gastos Financieros y Seguro de Vida ya que vienen montos
             muy pequeños que superan las unidades de control */
            IF p_ref_archivo IN
                  ('TAR_MOV_ESPECIALES', 'TAR_MOV_INTERESES',
                   'TAR_INF_FIN_CIERRE', 'TAR_MOV_DIARIO') THEN
               IF nvl(v_acu_iva, 0) <> 0 THEN
                  v_tas_impuesto := (v_acu_iva * 100) / rg_movs.monto;
                  IF v_val_tas_impuesto = trunc(v_tas_impuesto) OR
                     v_val_tas_impuesto = round(v_tas_impuesto) OR
                     v_val_tas_impuesto BETWEEN round(v_tas_impuesto) - 3 AND
                     round(v_tas_impuesto) + 3 OR length(rg_movs.monto) = 1 THEN
                     --Si es del Informe Fin.al cierre no se controla la tasa del iva
                     v_val_impuesto := v_acu_iva;
                  ELSE
                     lp_act_err_mov_especiales(v_cor_cuenta,
                                            'No coinciden la tasa asociada al cargo con la tasa calculada. Transaccion :  ' ||
                                             v_cod_transaccion || ' Base: ' || rg_movs.monto ||
                                             ' Iva: ' || v_acu_iva);
                  END IF;
               END IF;
            ELSE
               v_val_impuesto := v_acu_iva;
            END IF;
         EXCEPTION
            WHEN no_data_found THEN
               IF v_acu_iva > 0 THEN
                  lp_act_err_mov_especiales(v_cor_cuenta,
                                            'No se ha definido transacción de Iva para : ' ||
                                             v_cod_modalidad || '-' || v_cod_transaccion);
               ELSE
                  NULL;
               END IF;
            WHEN OTHERS THEN
               lp_act_err_mov_especiales(v_cor_cuenta, 'Al procesar impuesto - ' || SQLERRM);
         END;
         --
         IF nvl(v_val_impuesto, 0) <> 0 THEN
            IF v_cod_tip_cargo = '33' AND v_cod_tip_movimiento= 'C'  AND UPPER(v_descripcion) LIKE '%CUOTA ANUAL%' then -- reverso cuota anual
              v_cod_tra_impuesto:= '1709';
            END IF;
            /* Grabar el movimiento con la transaccion definida para la referencia recibida */
            IF  NVL(v_tip_mov_original,'D') <> v_cod_tip_movimiento and v_cod_tip_cargo NOT IN('33','28') THEN
               --Se reversa el movimiento
               rg_movs.monto := v_val_impuesto * -1;
            ELSE
              IF v_cod_tip_cargo = '32' THEN
                rg_movs.monto := v_val_impuesto * -1;
              ELSE
               rg_movs.monto := v_val_impuesto;
              END IF;
            END IF;
            IF v_nro_secuencia > 990 THEN
               v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
               v_nro_secuencia := 0;
            END IF;
            v_nro_secuencia         := v_nro_secuencia + 1;
            rg_movs.hora            := v_hora;
            rg_movs.nro_secuencia   := v_nro_secuencia;
            rg_movs.cod_mod_padre   := 5;
            rg_movs.cod_mad_padre   := 505;
            rg_movs.cod_tra_padre   := v_cod_tra_padre;
            rg_movs.cod_modulo      := v_cod_modulo;
            rg_movs.cod_modalidad   := v_cod_modalidad;
            rg_movs.cod_transaccion := v_cod_tra_impuesto;
            rg_movs.cod_moneda      := v_cod_mon_local;
            rg_movs.nro_cuenta      := v_cor_cuenta;
            rg_movs.cod_oficina     := v_cod_oficina;
            rg_movs.nro_documento   := NULL;
            rg_movs.nro_documento2  := NULL;
            rg_movs.cod_tasa        := v_cod_tas_impuesto;
            rg_movs.val_tasa        := v_val_tas_impuesto;
            rg_movs.cotizacion      := NULL;
            rg_movs.emi_aviso       := 'N';
            rg_movs.cod_ofi_origen  := v_cod_oficina;
            rg_movs.concepto        := v_cor_movimiento;
            rg_movs.estado          := 'N';
            rg_movs.est_cuenta      := v_est_cuenta;
            rg_movs.reversado       := 'N';
            rg_movs.emi_aviso       := 'N';
            rg_movs.nro_caja        := NULL;
            rg_movs.cod_rubro       := NULL;
            rg_movs.tip_mov_rubro   := NULL;
            v_mto_impuesto          := rg_movs.monto;
            rg_movs.cod_persona     := v_cod_persona;
            --
            pag_gen.pr_ins_ge_movimiento(rg_movs, 'N'); -- inserta datos en ge_movimientos
            --
         END IF;
         --*
         --*  Para algunos movimientos recibidos se debe generar dos transacciones, una de debito y
         --*  otra de credito, o si no afecta cuenta de tarjeta debe grabar con la transaccion sin cuenta
         --*  y solo por el movimiento sin iva.
         --*
         IF v_cod_transaccion2 IS NOT NULL and v_mto_comision = 0 and v_cod_tip_cargo not in ('6', '38', '44') /*Seguro contra Fraude - Compra Cliente*/ THEN
            v_afecta           := NULL;
            v_oficina          := NULL;
            v_cod_ent_comercio := NULL;
            v_cod_ent_bancard  := NULL;
            v_cod_ofi_ente     := NULL;
            v_cod_tra_impuesto := NULL;
            v_val_impuesto     := 0;
            v_acu_iva          := 0;

            --Verificar  si la transaccion adicional afecta cta. de tarjeta
            BEGIN
               SELECT afecta
                 INTO v_afecta
                 FROM ge_transacciones
                WHERE cod_modulo = v_cod_modulo
                  AND cod_modalidad = v_cod_modalidad
                  AND cod_transaccion = v_cod_transaccion2;
               --16/12/2010: Si la transaccion no afecta tarjeta entonces tomar la oficina que toma el proceso
               --de Pago a comercios (Crecom)
               IF nvl(v_afecta, 'X') <> 'J' and p_ref_archivo = 'TA_MOV_ESPECIALES' THEN
                  --Determinar codigo de ente para Pago a comercios de Bancard
                  BEGIN
                     SELECT cod_ente
                       INTO v_cod_ent_comercio
                       FROM ge_entes
                      WHERE tipo = 'PC'
                        AND descripcion LIKE '%BANCARD%';
                  EXCEPTION
                     WHEN OTHERS THEN
                        v_cod_ent_comercio := null;
                  END;

                  IF v_cod_ent_comercio is not null then
                     BEGIN
                        SELECT cod_oficina
                          INTO v_cod_ofi_ente
                          FROM ge_cuentas
                         WHERE nro_cuenta = fug_obt_parentes(v_cod_ent_comercio, 'NRO_CTA_DEB_COMERCIO');
                     EXCEPTION
                        WHEN OTHERS THEN
                          lp_act_err_mov_especiales( v_cor_cuenta,'Error al oficina de Pago a Comercios Bancard.'||' - '||sqlerrm);
                     END;
                  END IF;
                  BEGIN
                     SELECT cod_oficina
                        INTO v_oficina
                        FROM ta_cta_tarjetas
                       WHERE nro_cuenta = v_cor_cuenta;
                  EXCEPTION
                     WHEN no_data_found THEN
                        lp_act_err_mov_especiales( v_cor_cuenta,'Sin Oficina Cta.' );
                     WHEN OTHERS THEN
                        lp_act_err_mov_especiales( v_cor_cuenta,'Error Obt.Oficina Cta.'||SQLERRM );
                  END;
               END IF;
            EXCEPTION
               WHEN OTHERS THEN
                  lp_act_err_mov_especiales( v_cor_cuenta,'Error al traer datos de la transaccion :  '||v_cod_transaccion2||' - '||sqlerrm);

            END;
            --
            IF v_nro_secuencia > 990 THEN
               v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
               v_nro_secuencia := 0;
            END IF;
            v_nro_secuencia         := v_nro_secuencia + 1;
            rg_movs.nro_secuencia   := v_nro_secuencia;
            rg_movs.hora            := v_hora;
            rg_movs.cod_mod_padre   := 5;
            rg_movs.cod_mad_padre   := 505;
            rg_movs.cod_tra_padre   := v_cod_tra_padre;
            rg_movs.cod_modulo      := v_cod_modulo;
            rg_movs.cod_modalidad   := v_cod_modalidad;
            rg_movs.cod_transaccion := v_cod_transaccion2;
            rg_movs.cod_moneda      := v_cod_mon_local;
            IF v_afecta = 'J' THEN
               --Si afecta saldo de tarjeta se graba la cuenta
               rg_movs.nro_cuenta     := v_cor_cuenta;
               rg_movs.cod_oficina    := v_cod_oficina;
               rg_movs.cod_ofi_origen := v_cod_oficina;
            ELSE
               rg_movs.nro_cuenta     := v_cor_cuenta;
               rg_movs.cod_oficina    := nvl(v_oficina, v_cod_oficina);
               rg_movs.cod_ofi_origen := nvl(v_cod_ofi_ente, v_cod_oficina);
            END IF;
            rg_movs.nro_documento  := NULL;
            rg_movs.nro_documento2 := NULL;
            rg_movs.cod_tasa       := NULL;
            rg_movs.val_tasa       := NULL;
            rg_movs.cotizacion     := NULL;
            rg_movs.emi_aviso      := 'N';
            rg_movs.concepto       := v_cor_movimiento;
            rg_movs.estado         := 'N';
            rg_movs.est_cuenta     := v_est_cuenta;
            rg_movs.reversado      := 'N';
            rg_movs.emi_aviso      := 'N';
            rg_movs.nro_caja       := NULL;
            rg_movs.cod_rubro      := NULL;
            rg_movs.tip_mov_rubro  := NULL;
            IF v_cod_tip_cargo <> '33' THEN
               rg_movs.monto          := v_mto_base + v_mto_impuesto;
            ELSE
               rg_movs.monto          := v_mto_base;
            END IF;
            IF NVL(v_tip_mov_original,'D') <> v_cod_tip_movimiento and v_cod_tip_cargo <> '28'/*and v_cod_tip_cargo <> 33 */THEN
               rg_movs.monto        := rg_movs.monto *-1;
            END IF;
            rg_movs.cod_persona     := v_cod_persona;
            --
            pag_gen.pr_ins_ge_movimiento(rg_movs, 'N'); -- inserta datos en ge_movimientos
            --
            --Busco el impuesto asociado a este cargo
               --Solo si afecta cta. de tarjeta
               BEGIN
                  SELECT cod_tra_hijo
                    INTO v_cod_tra_impuesto
                    FROM ge_transacciones_det
                   WHERE cod_modulo = v_cod_modulo
                     AND cod_modalidad = v_cod_modalidad
                     AND cod_transaccion = v_cod_transaccion2
                     AND cod_mod_hijo = v_cod_modulo
                     AND cod_mad_hijo = v_cod_modalidad
                     AND cod_tra_hijo <> v_cod_transaccion -- Que la transacción hijo sea diferente de la padre PV 02/11/09
                     AND rownum = 1;

                  -- Traer tasa del impuesto
                  v_cod_tas_impuesto := NULL;
                  v_val_tas_impuesto := NULL;
                  v_fec_vigencia     := NULL;
                  v_tip_valor        := NULL;
                  v_tipo             := NULL;

                  pag_gen.pr_obt_val_tasa(v_cod_modulo, v_cod_modalidad, v_cod_oficina,
                                          v_cor_cuenta, v_cod_mon_local, 0,
                                          nvl(v_tas_personalizada, 'N'), v_cod_tas_impuesto,
                                          v_cod_tra_impuesto, trunc(SYSDATE), v_val_tas_impuesto,
                                          v_fec_vigencia, v_tip_valor, v_tipo);

                  --Si el iva ya viene calculado en el archivo, verificar que se la misma tasa,
                  --si no se debe calcular el iva sobre el monto recibido
                  /*Excluir de este control a Gastos Financieros y Seguro de Vida ya que vienen montos
                   muy pequeños que superan las unidades de control */
              IF p_ref_archivo IN
                        ('TAR_MOV_ESPECIALES', 'TAR_MOV_INTERESES',
                         'TAR_INF_FIN_CIERRE') THEN
                  IF nvl(v_acu_iva, 0) <> 0 THEN
                     v_tas_impuesto := (v_acu_iva * 100) / rg_movs.monto;
                     IF v_val_tas_impuesto = trunc(v_tas_impuesto) OR
                        v_val_tas_impuesto = round(v_tas_impuesto) OR
                        v_val_tas_impuesto BETWEEN round(v_tas_impuesto) - 3 AND
                        round(v_tas_impuesto) + 3 OR length(rg_movs.monto) = 1  THEN
                        --Si es del Informe Fin.al cierre no se controla la tasa del iva
                        v_val_impuesto := v_acu_iva;
                     ELSE
                        lp_act_err_mov_especiales(v_cor_cuenta,
                                                  'No coinciden la tasa asociada al cargo con la tasa calculada. Transaccion :  ' ||
                                                   v_cod_transaccion2 || ' Base: ' || rg_movs.monto ||
                                                   ' Iva: ' || v_acu_iva);
                     END IF;
                  END IF;
               ELSE --- Para seguro de vida no controlar
                  v_val_impuesto := v_acu_iva;
               END IF;
               EXCEPTION
                  WHEN no_data_found THEN
                     IF v_acu_iva > 0 THEN
                        lp_act_err_mov_especiales(v_cor_cuenta,
                                                  'No se ha definido transacción de Iva para : ' ||
                                                   v_cod_modalidad || '-' || v_cod_transaccion2);
                     ELSE
                        NULL;
                     END IF;
                  WHEN OTHERS THEN
                     lp_act_err_mov_especiales(v_cor_cuenta,
                                               'Al leer Impuesto. Transaccion : ' ||
                                                v_cod_transaccion2 || ' - ' || SQLERRM);
               END;
               --
               IF nvl(v_val_impuesto, 0) <> 0 THEN
                  -- Grabar el movimiento con la transaccion definida para la referencia recibida
                  --
                  IF v_tip_mov_original <> v_cod_tip_movimiento THEN
                     --Se reversa el movimiento
                     rg_movs.monto := v_val_impuesto * -1;

                  ELSE
                     rg_movs.monto := v_val_impuesto;
                  END IF;

                  IF v_nro_secuencia > 990 THEN
                     v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
                     v_nro_secuencia := 0;
                  END IF;
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  rg_movs.hora            := v_hora;
                  rg_movs.nro_secuencia   := v_nro_secuencia;
                  rg_movs.cod_mod_padre   := 5;
                  rg_movs.cod_mad_padre   := 505;
                  rg_movs.cod_tra_padre   := v_cod_tra_padre;
                  rg_movs.cod_modulo      := v_cod_modulo;
                  rg_movs.cod_modalidad   := v_cod_modalidad;
                  rg_movs.cod_transaccion := v_cod_tra_impuesto;
                  rg_movs.cod_moneda      := v_cod_mon_local;
                  rg_movs.nro_cuenta      := v_cor_cuenta;
                  rg_movs.cod_oficina     := v_cod_oficina;
                  rg_movs.nro_documento   := NULL;
                  rg_movs.nro_documento2  := NULL;
                  rg_movs.cod_tasa        := v_cod_tas_impuesto;
                  rg_movs.val_tasa        := v_val_tas_impuesto;
                  rg_movs.cotizacion      := NULL;
                  rg_movs.emi_aviso       := 'N';
                  rg_movs.cod_ofi_origen  := v_cod_oficina;
                  rg_movs.concepto        := v_cor_movimiento;
                  rg_movs.estado          := 'N';
                  rg_movs.est_cuenta      := v_est_cuenta;
                  rg_movs.reversado       := 'N';
                  rg_movs.emi_aviso       := 'N';
                  rg_movs.nro_caja        := NULL;
                  rg_movs.cod_rubro       := NULL;
                  rg_movs.tip_mov_rubro   := NULL;
                  rg_movs.cod_persona     := v_cod_persona;
                  --
                  pag_gen.pr_ins_ge_movimiento(rg_movs, 'N'); -- inserta datos en ge_movimientos
                  --
               END IF;
         END IF;
      END IF;
      /*-- Acreditación para la cuenta Bancaria - Adelnto POS- Movimientos Diarios--*/
   --   /* Para oficina Central es una cta bancaria,y para las otras oficinas es distinta*/
      IF (v_cod_tra_padre = 37 AND v_cod_plan = 21 and NVL(FUE_OBT_VAL_MAX_REFERENCIA ('TAR_ATM_CONCEPTO', v_descripcion),'N') = 'S') OR v_cod_tip_cargo in('27','28','29','30')  THEN

         v_cod_ofi_matriz:= fug_obt_pardinamico('COD_OFI_POS');
          IF v_cod_tip_cargo not in ('27', '28','7','29','30') THEN
          IF v_cod_ofi_matriz =
                              CASE
                                 WHEN fue_obt_val_max_referencia('TAR_POS_OFICINAS', v_descripcion) =
                                      'Referencia no registrada en el Sistema' THEN
                                    v_cod_ofi_movimiento
                                 ELSE
                                    fue_obt_val_max_referencia('TAR_POS_OFICINAS', v_descripcion)
                              END THEN
             v_cor_cuenta := fug_obt_parentes(fug_obt_pardinamico('COD_PRO_BANCARD'), 'NRO_CTA_BCO_SPONSOR');
          ELSE
             v_cor_cuenta := fug_obt_parentes(fug_obt_pardinamico('COD_PRO_BANCARD'), 'NRO_CTA_BCO_SUC_SPONSOR');
          END IF;
          ELSE
             v_cor_cuenta  :=v_cta_banco;
          END IF;
          BEGIN
             SELECT cod_oficina
               INTO v_cod_ofi_ente
               FROM ge_cuentas
              WHERE nro_cuenta = v_cor_cuenta;
          EXCEPTION
             WHEN no_data_found THEN
                lp_act_err_mov_especiales(v_cor_cuenta, 'No exise cuenta. Parametro del Ente: NRO_CTA_BCO_SPONSOR. ');

             WHEN OTHERS THEN
                lp_act_err_mov_especiales(v_cor_cuenta, 'Error al recuperar cuenta. Parametro del Ente: NRO_CTA_BCO_SPONSOR.' || SQLERRM);
          END;

          IF nvl(v_mto_total, 0) <> 0 AND v_error IS NULL THEN
             IF v_nro_secuencia > 990 THEN
                v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
                v_nro_secuencia := 0;
             END IF;
            v_nro_secuencia         := v_nro_secuencia + 1;
            rg_movs.nro_secuencia   := v_nro_secuencia;
            rg_movs.hora            := v_hora;
            rg_movs.cod_mod_padre   := 5;
            rg_movs.cod_mad_padre   := 505;
            rg_movs.cod_tra_padre   := v_cod_tra_padre;
            rg_movs.cod_modulo      := 4;
            rg_movs.cod_modalidad   := 43;
            rg_movs.cod_transaccion := 1503;
            rg_movs.cod_moneda      := v_cod_mon_local;
            rg_movs.nro_cuenta      := v_cor_cuenta;
            rg_movs.cod_oficina     := v_cod_ofi_ente;
            rg_movs.nro_documento   := NULL;
            rg_movs.nro_documento2  := NULL;
            rg_movs.cod_tasa        := NULL;
            rg_movs.val_tasa        := NULL;
            rg_movs.cotizacion      := NULL;
            rg_movs.emi_aviso       := 'N';
            rg_movs.cod_ofi_origen  := v_cod_ofi_movimiento;
            rg_movs.concepto        := v_cor_movimiento;
            rg_movs.estado          := 'N';
            rg_movs.est_cuenta      := v_est_cuenta;
            rg_movs.reversado       := 'N';
            rg_movs.emi_aviso       := 'N';
            rg_movs.nro_caja        := NULL;
            rg_movs.cod_rubro       := NULL;
            rg_movs.tip_mov_rubro   := NULL;
            IF v_cod_tip_cargo not in ('27', '28','7','29','30') THEN
            v_mto_base              := v_mto_total;
            rg_movs.monto           := v_mto_total;
            IF v_tip_mov_original <> v_cod_tip_movimiento THEN
               v_mto_base              := v_mto_total*-1;
               rg_movs.monto           := v_mto_total*-1;
               END IF;
            ELSE
              rg_movs.monto := v_mto_base;
            END IF;
            rg_movs.cod_persona     := v_cod_persona;
            --
            pag_gen.pr_ins_ge_movimiento(rg_movs, 'N'); -- inserta datos en ge_movimientos
            dbms_output.put_line('v_cor_cuenta'||v_cor_cuenta);
            pag_cta.pr_act_sal_cta (v_cor_cuenta,
                                    43,
                                    'D',
                                    v_fecha ,
                                    v_hora,
                                    (nvl(rg_movs.monto,0) * -1),
                                    0,
                                    0,
                                    null, /* autorizacion pendiente */
                                    'N');

         END IF;
      END IF;

      /*-- Monto Comisión Comercio--*/
      IF ((nvl(v_mto_comision, 0) <> 0 AND v_error IS NULL AND v_cod_transaccion2 is not null)
           OR (nvl(v_mto_comision, 0) = 0 AND v_error IS NULL AND v_cod_transaccion2 is not null
           and v_cod_tip_cargo in ('38', '44'))
           )
         THEN
         IF v_nro_secuencia > 990 THEN
            v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
            v_nro_secuencia := 0;
         END IF;

         --Traer codigo de oficina y código de persona parametrizada en Pago Comisión de Bancard
         v_cod_ent_bancard := null;
         v_cod_per_bancard := null;
         BEGIN
            SELECT cod_ente, cod_persona
              INTO v_cod_ent_bancard, v_cod_per_bancard
              FROM ge_entes
             WHERE cod_ente = fug_obt_pardinamico('COD_PRO_BANCARD');
         EXCEPTION
            WHEN no_data_found THEN
               lp_act_err_mov_especiales(v_cor_cuenta,
                                                  'No existe Ente para Procesadora Bancard. ');
            WHEN OTHERS THEN
               lp_act_err_mov_especiales(v_cor_cuenta,'Error al recuperar Ente para Procesadora Bancard.'||sqlerrm);
         END;

         IF v_cod_ent_bancard is not null then
            v_nro_cta_comision := fug_obt_parentes(v_cod_ent_bancard, 'NRO_CTA_COMISION');
            BEGIN
               SELECT cod_oficina, cod_modulo, cod_modalidad
                 INTO v_cod_ofi_ente, v_cod_mod_ente, v_cod_mad_ente
                 FROM ge_cuentas
                WHERE nro_cuenta = v_nro_cta_comision;
            EXCEPTION
               WHEN OTHERS THEN
                   lp_act_err_mov_especiales(v_cor_cuenta,'Error al recuperar Oficina de Comisión de Bancard.'||sqlerrm);
            END;
         END IF;

         BEGIN
             SELECT cod_oficina
               INTO v_oficina
               FROM ta_cta_tarjetas
              WHERE nro_cuenta = v_cor_cuenta;
         EXCEPTION
            WHEN no_data_found THEN
               lp_act_err_mov_especiales(v_cor_cuenta,'Sin Oficina Cta.');

            WHEN OTHERS THEN
              lp_act_err_mov_especiales(v_cor_cuenta,'Error Obt.Oficina Cta.'||sqlerrm);
         END;

         v_nro_secuencia         := v_nro_secuencia + 1;
         rg_movs.nro_secuencia   := v_nro_secuencia;
         rg_movs.hora            := v_hora;
         rg_movs.cod_mod_padre   := 5;
         rg_movs.cod_mad_padre   := 505;
         rg_movs.cod_tra_padre   := v_cod_tra_padre;
         rg_movs.cod_modulo      := v_cod_modulo;
         rg_movs.cod_modalidad   := v_cod_modalidad;
         rg_movs.cod_transaccion := v_cod_transaccion2;
         rg_movs.cod_moneda      := v_cod_mon_local;
         rg_movs.nro_cuenta      := null;
         rg_movs.cod_oficina     := v_cod_oficina;
         rg_movs.nro_documento   := NULL;
         rg_movs.nro_documento2  := NULL;
         rg_movs.cod_tasa        := NULL;
         rg_movs.val_tasa        := NULL;
         rg_movs.cotizacion      := NULL;
         rg_movs.emi_aviso       := 'N';
         rg_movs.cod_ofi_origen  := v_cod_oficina;
         rg_movs.concepto        := v_cor_movimiento;
         rg_movs.estado          := 'N';
         rg_movs.est_cuenta      := v_est_cuenta;
         rg_movs.reversado       := 'N';
         rg_movs.emi_aviso       := 'N';
         rg_movs.nro_caja        := NULL;
         rg_movs.cod_rubro       := NULL;
         rg_movs.tip_mov_rubro   := NULL;

         v_mto_base              := v_mto_comision;
         rg_movs.monto           := v_mto_comision;
         IF v_tip_mov_original <> v_cod_tip_movimiento and  v_cod_tip_cargo not in('41','44','38') THEN
            v_mto_base              := v_mto_comision *-1;
            rg_movs.monto           := v_mto_comision *-1;
         END IF;
         rg_movs.cod_persona     := v_cod_per_bancard;
         --
         pag_gen.pr_ins_ge_movimiento(rg_movs, 'N');

         /*Busco el impuesto asociado a este cargo
         Solo si afecta cta. de tarjeta*/
         BEGIN
            SELECT cod_tra_hijo
              INTO v_cod_tra_impuesto
              FROM ge_transacciones_det
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = v_cod_transaccion2
               AND cod_mod_hijo = v_cod_modulo
               AND cod_mad_hijo = v_cod_modalidad
               AND cod_tra_hijo <> v_cod_transaccion -- Que la transacción hijo sea diferente de la padre PV 02/11/09
               AND rownum = 1;

            -- Traer tasa del impuesto
            v_cod_tas_impuesto := NULL;
            v_val_tas_impuesto := NULL;
            v_fec_vigencia     := NULL;
            v_tip_valor        := NULL;
            v_tipo             := NULL;

            pag_gen.pr_obt_val_tasa(v_cod_modulo, v_cod_modalidad, v_cod_oficina,
                                    v_cor_cuenta, v_cod_mon_local, 0,
                                    nvl(v_tas_personalizada, 'N'), v_cod_tas_impuesto,
                                    v_cod_tra_impuesto, trunc(SYSDATE), v_val_tas_impuesto,
                                    v_fec_vigencia, v_tip_valor, v_tipo);

            --Si el iva ya viene calculado en el archivo, verificar que se la misma tasa,
            --si no se debe calcular el iva sobre el monto recibido
              IF v_acu_iva <> 0 THEN
                 v_tas_impuesto := (v_acu_iva * 100) / rg_movs.monto;
                 IF v_val_tas_impuesto = trunc(v_tas_impuesto) OR
                    v_val_tas_impuesto = round(v_tas_impuesto) OR
                    v_val_tas_impuesto BETWEEN round(v_tas_impuesto) - 3 AND
                    round(v_tas_impuesto) + 3 OR length(rg_movs.monto) = 1 THEN
                   --Si es del Informe Fin.al cierre no se controla la tasa del iva
                       v_val_impuesto := v_acu_iva;
                 ELSE
                    lp_act_err_mov_especiales(v_cor_cuenta,
                                            'No coinciden la tasa asociada al cargo con la tasa calculada. Transaccion :  ' ||
                                             v_cod_transaccion2 || ' Base: ' || rg_movs.monto ||
                                             ' Iva: ' || v_acu_iva);
                 END IF;
              ELSE
                 v_val_impuesto := round(nvl(rg_movs.monto,0) / nvl(v_val_tas_impuesto,1),v_redondeo ) ;
              END IF;

          EXCEPTION
             WHEN no_data_found THEN
                IF v_acu_iva > 0 THEN
                   lp_act_err_mov_especiales(v_cor_cuenta,
                                            'No se ha definido transacción de Iva para : ' ||
                                             v_cod_modalidad || '-' || v_cod_transaccion2);
                ELSE
                   NULL;
                END IF;
             WHEN OTHERS THEN
                lp_act_err_mov_especiales(v_cor_cuenta,
                                         'Al leer Impuesto. Transaccion : ' ||
                                          v_cod_transaccion2 || ' - ' || SQLERRM);
          END;
             --
          IF nvl(v_val_impuesto, 0) <> 0 THEN
            -- Grabar el movimiento con la transaccion definida para la referencia recibida
             IF v_nro_secuencia > 990 THEN
                v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
                v_nro_secuencia := 0;
             END IF;
             v_nro_secuencia         := v_nro_secuencia + 1;
             rg_movs.hora            := v_hora;
             rg_movs.nro_secuencia   := v_nro_secuencia;
             rg_movs.cod_mod_padre   := 5;
             rg_movs.cod_mad_padre   := 505;
             rg_movs.cod_tra_padre   := v_cod_tra_padre;
             rg_movs.cod_modulo      := v_cod_modulo;
             rg_movs.cod_modalidad   := v_cod_modalidad;
             rg_movs.cod_transaccion := v_cod_tra_impuesto;
             rg_movs.cod_moneda      := v_cod_mon_local;
             rg_movs.nro_cuenta      := null;
             rg_movs.cod_oficina     := v_cod_oficina;
             rg_movs.nro_documento   := NULL;
             rg_movs.nro_documento2  := NULL;
             rg_movs.cod_tasa        := v_cod_tas_impuesto;
             rg_movs.val_tasa        := v_val_tas_impuesto;
             rg_movs.cotizacion      := NULL;
             rg_movs.emi_aviso       := 'N';
             rg_movs.cod_ofi_origen  := v_cod_oficina;
             rg_movs.concepto        := v_cor_movimiento;
             rg_movs.estado          := 'N';
             rg_movs.est_cuenta      := v_est_cuenta;
             rg_movs.reversado       := 'N';
             rg_movs.emi_aviso       := 'N';
             rg_movs.nro_caja        := NULL;
             rg_movs.cod_rubro       := NULL;
             rg_movs.tip_mov_rubro   := NULL;
             rg_movs.monto           := v_val_impuesto;
             IF v_tip_mov_original <> v_cod_tip_movimiento and  v_cod_tip_cargo not in('41','44','38') THEN
                rg_movs.monto           := v_val_impuesto*-1;
             END IF;
             rg_movs.cod_persona     := v_cod_per_bancard;
             --
             pag_gen.pr_ins_ge_movimiento(rg_movs, 'N'); -- inserta datos en ge_movimientos
             --
          END IF;

         IF v_cod_transaccion3 is not null THEN
            IF v_nro_secuencia > 990 THEN
               v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
               v_nro_secuencia := 0;
            END IF;
            v_nro_secuencia         := v_nro_secuencia + 1;
            rg_movs.nro_secuencia   := v_nro_secuencia;
            rg_movs.hora            := v_hora;
            rg_movs.cod_mod_padre   := 5;
            rg_movs.cod_mad_padre   := 505;
            rg_movs.cod_tra_padre   := v_cod_tra_padre;
            rg_movs.cod_modulo      := v_cod_modulo;
            rg_movs.cod_modalidad   := v_cod_modalidad;
            rg_movs.cod_transaccion := v_cod_transaccion3;
            rg_movs.cod_moneda      := v_cod_mon_local;
            rg_movs.nro_cuenta      := null;
            rg_movs.cod_oficina     := v_cod_oficina;
            rg_movs.cod_ofi_origen  := v_cod_oficina;
            rg_movs.cod_modulo      := v_cod_modulo;
            rg_movs.nro_documento   := NULL;
            rg_movs.nro_documento2  := NULL;
            rg_movs.cod_tasa        := NULL;
            rg_movs.val_tasa        := NULL;
            rg_movs.cotizacion      := NULL;
            rg_movs.emi_aviso       := 'N';
            rg_movs.concepto        := v_cor_movimiento;
            rg_movs.estado          := 'N';
            rg_movs.est_cuenta      := v_est_cuenta;
            rg_movs.reversado       := 'N';
            rg_movs.emi_aviso       := 'N';
            rg_movs.nro_caja        := NULL;
            rg_movs.cod_rubro       := NULL;
            rg_movs.tip_mov_rubro   := NULL;
            v_mto_base              := NULL;
            rg_movs.monto           := nvl(v_acu_monto,0) - (abs(nvl(v_mto_comision,0)) + abs(nvl(v_val_impuesto,0))); -- ajuste
            IF v_tip_mov_original <> v_cod_tip_movimiento THEN
               rg_movs.monto := rg_movs.monto *-1;
            END IF;
            rg_movs.cod_persona     := v_cod_persona;
            --
            pag_gen.pr_ins_ge_movimiento(rg_movs, 'N');
       END IF;
       -- Acumular total de comisión para Bancard
       IF p_ref_archivo = 'TAR_MOV_DIARIO' THEN
          v_acu_com_bancard := v_acu_com_bancard + nvl(v_mto_comision,0);
          v_acu_imp_bancard := v_acu_imp_bancard + nvl(v_val_impuesto,0);
       END IF;
    END IF;

    /*-- Acreditación para la cuenta Bancaria - Pagos en Efectivo - Movimientos Diarios--*/
    IF v_cod_tra_padre = 37 AND (v_mto_deb_pronet + v_mto_deb_web_post) > 0 THEN

       IF v_mto_deb_pronet > 0 THEN -- Pronet
          v_cta_deb_efectivo := fug_obt_parentes(fug_obt_pardinamico('COD_PRO_BANCARD'), 'NRO_CTA_PAG_PRONET');
          v_cod_per_deb_efe  := fug_obt_cli_principal(v_cta_deb_efectivo);

          BEGIN
             SELECT cod_oficina, cod_modulo, cod_modalidad
               INTO v_cod_ofi_ente, v_cod_mod_cta_ban, v_cod_mad_cta_ban
               FROM ge_cuentas
              WHERE nro_cuenta = v_cta_deb_efectivo;
          EXCEPTION
             WHEN no_data_found THEN
                lp_act_err_mov_especiales(v_cor_cuenta, 'No exise cuenta. Parametro del Ente: NRO_CTA_PAG_PRONET. ');

             WHEN OTHERS THEN
                lp_act_err_mov_especiales(v_cor_cuenta, 'Error al recuperar cuenta. Parametro del Ente: NRO_CTA_PAG_PRONET.' || SQLERRM);
          END;

         /*Busco el impuesto asociado a este cargo
         Solo si afecta cta. de tarjeta*/
         BEGIN
            SELECT cod_tra_hijo
              INTO v_cod_tra_impuesto
              FROM ge_transacciones_det
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = v_cod_transaccion
               AND cod_mod_hijo = v_cod_modulo
               AND cod_mad_hijo = v_cod_modalidad
               AND cod_tra_hijo <> v_cod_transaccion -- Que la transacción hijo sea diferente de la padre PV 02/11/09
               AND rownum = 1;

            -- Traer tasa del impuesto
            v_cod_tas_impuesto := NULL;
            v_val_tas_impuesto := NULL;
            v_fec_vigencia     := NULL;
            v_tip_valor        := NULL;
            v_tipo             := NULL;

            pag_gen.pr_obt_val_tasa(v_cod_modulo, v_cod_modalidad, v_cod_oficina,
                                    v_cor_cuenta, v_cod_mon_local, 0,
                                    nvl(v_tas_personalizada, 'N'), v_cod_tas_impuesto,
                                    v_cod_tra_impuesto, trunc(SYSDATE), v_val_tas_impuesto,
                                    v_fec_vigencia, v_tip_valor, v_tipo);

            --Si el iva ya viene calculado en el archivo, verificar que se la misma tasa,
            --si no se debe calcular el iva sobre el monto recibido
            IF v_acu_iva <> 0 then
               v_tas_impuesto := (v_acu_iva * 100) / rg_movs.monto;
               IF v_val_tas_impuesto = trunc(v_tas_impuesto) OR
                  v_val_tas_impuesto = round(v_tas_impuesto) OR
                  v_val_tas_impuesto BETWEEN round(v_tas_impuesto) - 3 AND
                  round(v_tas_impuesto) + 3 OR length(rg_movs.monto) = 1 OR
                  p_ref_archivo IN
                  ('TAR_MOV_ESPECIALES', 'TAR_MOV_INTERESES', 'TAR_INF_GAS_FINANCIEROS',
                  'TAR_INF_FIN_CIERRE') THEN
                  --Si es del Informe Fin.al cierre no se controla la tasa del iva
                  v_val_impuesto := v_acu_iva;
               ELSE
                  lp_act_err_mov_especiales(v_cor_cuenta,
                                            'No coinciden la tasa asociada al cargo con la tasa calculada. Transaccion :  ' ||
                                             v_cod_transaccion2 || ' Base: ' || rg_movs.monto ||
                                             ' Iva: ' || v_acu_iva);
               END IF;
            ELSE
               IF v_tip_valor = 'P' THEN
                  v_val_impuesto := round(nvl(rg_movs.monto,0) / nvl(v_val_tas_impuesto,1),v_redondeo ) ;
               ELSIF v_tip_valor = 'V' THEN
                  v_val_impuesto := v_val_tas_impuesto * nvl(v_cob_cargo, 1);
               END IF;
            END IF;

         EXCEPTION
             WHEN no_data_found THEN
                IF v_acu_iva > 0 THEN
                   lp_act_err_mov_especiales(v_cor_cuenta,
                                            'No se ha definido transacción de Iva para : ' ||
                                             v_cod_modalidad || '-' || v_cod_transaccion2);
                ELSE
                   NULL;
                END IF;
             WHEN OTHERS THEN
                lp_act_err_mov_especiales(v_cor_cuenta,
                                         'Al leer Impuesto. Transaccion : ' ||
                                          v_cod_transaccion2 || ' - ' || SQLERRM);
         END;
         --
         IF v_nro_secuencia > 990 THEN
            v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
            v_nro_secuencia := 0;
         END IF;
            v_nro_secuencia         := v_nro_secuencia + 1;
            rg_movs.nro_secuencia   := v_nro_secuencia;
            rg_movs.hora            := v_hora;
            rg_movs.cod_mod_padre   := 5;
            rg_movs.cod_mad_padre   := 505;
            rg_movs.cod_tra_padre   := v_cod_tra_padre;
            rg_movs.cod_modulo      := v_cod_mod_cta_ban;
            rg_movs.cod_modalidad   := v_cod_mad_cta_ban;
            rg_movs.cod_transaccion := v_cod_transaccion;
            rg_movs.cod_moneda      := v_cod_mon_local;
            rg_movs.nro_cuenta      := v_cta_deb_efectivo;
            rg_movs.cod_oficina     := v_cod_ofi_ente;
            rg_movs.nro_documento   := NULL;
            rg_movs.nro_documento2  := NULL;
            rg_movs.cod_tasa        := NULL;
            rg_movs.val_tasa        := NULL;
            rg_movs.cotizacion      := NULL;
            rg_movs.emi_aviso       := 'N';
            rg_movs.cod_ofi_origen  := v_cod_oficina;
            rg_movs.concepto        := v_cor_movimiento;
            rg_movs.estado          := 'N';
            rg_movs.est_cuenta      := v_est_cuenta;
            rg_movs.reversado       := 'N';
            rg_movs.emi_aviso       := 'N';
            rg_movs.nro_caja        := NULL;
            rg_movs.cod_rubro       := NULL;
            rg_movs.tip_mov_rubro   := NULL;
            rg_movs.monto           := v_mto_deb_pronet - v_val_impuesto;
            IF v_tip_mov_original <> v_cod_tip_movimiento THEN
               rg_movs.monto := rg_movs.monto *-1;
            END IF;
            rg_movs.cod_persona     := v_cod_per_deb_efe;

            --
           pag_gen.pr_ins_ge_movimiento(rg_movs, 'N'); -- inserta datos en ge_movimientos
           dbms_output.put_line('v_cta_deb_efectivo '||v_cta_deb_efectivo);
           pag_cta.pr_act_sal_cta (v_cta_deb_efectivo,
                                    43,
                                    'C',
                                    v_fecha ,
                                    v_hora,
                                    nvl(v_mto_deb_pronet, 0) - nvl(v_val_impuesto,0),
                                    0,
                                    0,
                                    null, /* autorizacion pendiente */
                                    'N');

          IF nvl(v_val_impuesto, 0) <> 0 THEN
            -- Grabar el movimiento con la transaccion definida para la referencia recibida
             IF v_nro_secuencia > 990 THEN
                v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
                v_nro_secuencia := 0;
             END IF;
             v_nro_secuencia         := v_nro_secuencia + 1;
             rg_movs.hora            := v_hora;
             rg_movs.nro_secuencia   := v_nro_secuencia;
             rg_movs.cod_mod_padre   := 5;
             rg_movs.cod_mad_padre   := 505;
             rg_movs.cod_tra_padre   := v_cod_tra_padre;
             rg_movs.cod_modulo      := v_cod_modulo;
             rg_movs.cod_modalidad   := v_cod_modalidad;
             rg_movs.cod_transaccion := v_cod_tra_impuesto;
             rg_movs.cod_moneda      := v_cod_mon_local;
             rg_movs.nro_cuenta      := null;
             rg_movs.cod_oficina     := v_cod_ofi_ente;
             rg_movs.nro_documento   := NULL;
             rg_movs.nro_documento2  := NULL;
             rg_movs.cod_tasa        := v_cod_tas_impuesto;
             rg_movs.val_tasa        := v_val_tas_impuesto;
             rg_movs.cotizacion      := NULL;
             rg_movs.emi_aviso       := 'N';
             rg_movs.cod_ofi_origen  := v_cod_oficina;
             rg_movs.concepto        := v_cor_movimiento;
             rg_movs.estado          := 'N';
             rg_movs.est_cuenta      := v_est_cuenta;
             rg_movs.reversado       := 'N';
             rg_movs.emi_aviso       := 'N';
             rg_movs.nro_caja        := NULL;
             rg_movs.cod_rubro       := NULL;
             rg_movs.tip_mov_rubro   := NULL;
             rg_movs.monto           := v_val_impuesto;
             IF v_tip_mov_original <> v_cod_tip_movimiento THEN
                rg_movs.monto           := v_val_impuesto*-1;
             END IF;
             rg_movs.cod_persona     := v_cod_per_deb_efe;
             --
             pag_gen.pr_ins_ge_movimiento(rg_movs, 'N'); -- inserta datos en ge_movimientos
             --
           END IF;
       END IF;

       IF v_mto_deb_web_post > 0 THEN -- Post y Web
          v_cta_deb_efectivo := fug_obt_parentes(fug_obt_pardinamico('COD_PRO_BANCARD'), 'NRO_CTA_PAG_WEB');
          v_cod_per_deb_efe  := fug_obt_cli_principal(v_cta_deb_efectivo);

          BEGIN
             SELECT cod_oficina, cod_modulo, cod_modalidad
               INTO v_cod_ofi_ente, v_cod_mod_cta_ban, v_cod_mad_cta_ban
               FROM ge_cuentas
              WHERE nro_cuenta = v_cta_deb_efectivo;
          EXCEPTION
             WHEN no_data_found THEN
                lp_act_err_mov_especiales(v_cor_cuenta,'No exise cuenta. Parametro del Ente: NRO_CTA_PAG_WEB. ');
             WHEN OTHERS THEN
                lp_act_err_mov_especiales(v_cor_cuenta,'No exise cuenta. Parametro del Ente: NRO_CTA_PAG_WEB. ' ||SQLERRM);
          END;

          IF v_nro_secuencia > 990 THEN
             v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
             v_nro_secuencia := 0;
          END IF;
          v_nro_secuencia         := v_nro_secuencia + 1;
          rg_movs.nro_secuencia   := v_nro_secuencia;
          rg_movs.hora            := v_hora;
          rg_movs.cod_mod_padre   := 5;
          rg_movs.cod_mad_padre   := 505;
          rg_movs.cod_tra_padre   := v_cod_tra_padre;
          rg_movs.cod_modulo      := v_cod_mod_cta_ban;
          rg_movs.cod_modalidad   := v_cod_mad_cta_ban;
          rg_movs.cod_transaccion := v_cod_transaccion;
          rg_movs.cod_moneda      := v_cod_mon_local;
          rg_movs.nro_cuenta      := v_cta_deb_efectivo;
          rg_movs.cod_oficina     := v_cod_ofi_ente;
          rg_movs.nro_documento   := NULL;
          rg_movs.nro_documento2  := NULL;
          rg_movs.cod_tasa        := NULL;
          rg_movs.val_tasa        := NULL;
          rg_movs.cotizacion      := NULL;
          rg_movs.emi_aviso       := 'N';
          rg_movs.cod_ofi_origen  := v_cod_oficina;
          rg_movs.concepto        := v_cor_movimiento;
          rg_movs.estado          := 'N';
          rg_movs.est_cuenta      := v_est_cuenta;
          rg_movs.reversado       := 'N';
          rg_movs.emi_aviso       := 'N';
          rg_movs.nro_caja        := NULL;
          rg_movs.cod_rubro       := NULL;
          rg_movs.tip_mov_rubro   := NULL;
          rg_movs.monto           := v_mto_deb_web_post;
          IF v_tip_mov_original <> v_cod_tip_movimiento THEN
             rg_movs.monto           := v_mto_deb_web_post*-1;
          END IF;
          rg_movs.cod_persona     := v_cod_per_deb_efe;
          --
          pag_gen.pr_ins_ge_movimiento(rg_movs, 'N'); -- inserta datos en ge_movimientos

          pag_cta.pr_act_sal_cta (v_cta_deb_efectivo,
                                    43,
                                    'D',
                                    v_fecha ,
                                    v_hora,
                                    (nvl(v_mto_deb_web_post,0) * -1),
                                    0,
                                    0,
                                    null, /* autorizacion pendiente */
                                    'N');

       END IF;
    END IF;

 END;
   /*
   || Fecha: 03/junio/2015
   || Observacion: Validaciones al importar el archivo desde el proceso automatico
   || Se trae del Disparador WHEN-BUTTON-PRESSED del botón PB_ACEPTAR del form TPMOVESP
   */
   PROCEDURE lp_val_imp_archivo IS
      v_fec_proceso DATE;
      v_cantidad    NUMBER;
      r_log         ta_logs%ROWTYPE;
      v_dato        ta_ref_movimientos.cod_referencia%TYPE;
      ---* Cursores de las tablas temporales
      -- Mov. Especiales
      CURSOR c_mov_esp IS
         SELECT *
           FROM ta_mov_especiales_tmp
          WHERE usu_insercion = USER
            AND trunc(fec_insercion) = trunc(SYSDATE);
      -- Mov. de Intereses
      CURSOR c_mov_int IS
         SELECT nro_cuenta,
                tip_movimiento,
                mto_int_cuota,
                mto_imp_int_cuota,
                fec_proceso,
                nro_cta_bancaria,
                mto_amortizacion
           FROM ta_mov_intereses_tmp;

      -- Mov. Diarios
      CURSOR c_mov_diario IS
         SELECT nro_cuenta,
                nro_tarjeta,
                fec_proceso,
                cod_tip_cargo,
                descripcion,
                mto_operacion,
                mto_impuesto,
                mto_interes,
                tip_saldo,
                usu_movimiento,
                for_pago,
                cod_ori_pago,
                fec_valor,
                cod_plan,
                mto_comision,
                can_cuotas,
                est_cuota,
                decode(cod_oficina, 0, 61, cod_oficina)cod_oficina -- oficina 0, no se tiene en la Entidad
           FROM ta_mov_diarios_tmp;
      -- SDRESUM
      CURSOR c_resumenes IS
         SELECT cod_entidad,
                cla_tarjeta,
                afinidad,
                nro_cuenta,
                nro_cta_entidad,
                monto,
                mto_comision,
                mto_iva,
                fec_valor,
                fec_proceso,
                tip_movimiento,
                can_cuotas,
                tip_cargo,
                can_cuotas2,
                tip_debito
           FROM ta_mov_resumenes_tmp
          where tip_debito in ('9', '17');

      -- Mov. Cargos Seguro de Vida (Cierre).
      CURSOR c_seg_vida IS
         SELECT saldo,
                nro_cuenta,
                mto_iva_seg_cliente,
                fec_cierre,
                tip_cierre,
                mto_seg_cliente,
                mto_seg_entidad,
                afinidad,
                afecta,
                motivo
           FROM ta_seg_vida_tmp
           WHERE nro_cuenta in('636904142','635002171');

       CURSOR c_gas_financieros IS
          SELECT a.ref_archivo,
                 a.nro_cuenta,
                 a.mto_int_corriente,
                 a.mto_int_compra,
                 a.mto_int_mora,
                 a.mto_int_punitorio,
                 a.mto_int_cuota,
                 a.mto_iva_afe_per_10,
                 a.mto_iva_afe_per_5,
                 a.mto_iva_afe_cie_10,
                 a.mto_iva_afe_cie_5,
                 a.mto_iva_cuo_5,
                 a.fec_cierre,
                 a.usu_control,
                 a.fec_control,
                 a.mto_int_rev_cuota,
                 b.cod_oficina
            FROM ta_inf_gas_financieros_tmp a, ta_cta_tarjetas b
              WHERE a.nro_cuenta = b.nro_cuenta;
   BEGIN
      --Verificar si ya fue procesado en la fecha
      IF p_ref_archivo = 'TAR_MOV_ESPECIALES' THEN
         BEGIN
            SELECT m.fec_proceso, COUNT(*)
              INTO v_fec_proceso, v_existe
              FROM ta_mov_especiales m, ta_mov_especiales_tmp t
             WHERE t.ref_archivo = p_ref_archivo
               AND m.ref_archivo = t.ref_archivo
               AND m.fec_proceso = t.fec_proceso
               AND m.procesado = 'S'
               AND rownum = 1
             GROUP BY m.fec_proceso;
         EXCEPTION
            WHEN no_data_found THEN
               v_existe := 0;
         END;
      ELSIF p_ref_archivo = 'TAR_MOV_INTERESES' THEN
         BEGIN
            SELECT m.fec_proceso, COUNT(*)
              INTO v_fec_proceso, v_existe
              FROM ta_mov_especiales m, ta_mov_intereses_tmp t
             WHERE t.ref_archivo = p_ref_archivo
               AND m.ref_archivo = t.ref_archivo
               AND m.fec_proceso = t.fec_proceso
               AND m.procesado = 'S'
               AND rownum = 1
             GROUP BY m.fec_proceso;
         EXCEPTION
            WHEN no_data_found THEN
               v_existe := 0;
         END;
      ELSIF p_ref_archivo = 'TAR_MOV_DIARIO' THEN
         -- Movimientos Diarios
         BEGIN
            SELECT m.fec_proceso, COUNT(*)
              INTO v_fec_proceso, v_existe
              FROM ta_mov_especiales m, ta_mov_diarios_tmp t
             WHERE m.ref_archivo = p_ref_archivo
               AND m.fec_proceso = t.fec_proceso
               AND m.procesado = 'S'
               AND rownum = 1
             GROUP BY m.fec_proceso;
         EXCEPTION
            WHEN no_data_found THEN
               v_existe := 0;
         END;
      ELSIF p_ref_archivo = 'TAR_SEG_VIDA' THEN
         -- Cargos Seguros de Vida
         BEGIN
            SELECT m.fec_proceso, COUNT(*)
              INTO v_fec_proceso, v_existe
              FROM ta_mov_especiales m, ta_seg_vida_tmp t
             WHERE m.ref_archivo = p_ref_archivo
               AND m.fec_proceso = t.fec_cierre
               AND m.procesado = 'S'
               AND rownum = 1
             GROUP BY m.fec_proceso;
              v_existe := 0;--ariel
         EXCEPTION
            WHEN no_data_found THEN
               v_existe := 0;
         END;
      END IF;

      --- Verificar que no se han procesado registros para la fecha
      r_log.nom_proceso := 'prt_mov_especiales';
      r_log.fec_hor_ini := SYSDATE;
      r_log.nro_reg     := 0;
      --IF nvl(v_existe, 0) <> 2 THEN --ver quién modificó esto para que no procese!!!!!
      IF nvl(v_existe, 0) <> 0 THEN
         r_log.comentario := 'Ya se han procesado registros para la fecha : ' ||
                             to_char(v_fec_proceso, 'dd/mm/yyyy') ||' - '|| p_ref_archivo;
      ELSE
         --Insertar tabla de movimientos
         --Grabar tabla de Movimientos dependiendo del tipo de Referencia del archivo, si tiene marcado como "procesar"
         IF p_ref_archivo = 'TAR_MOV_ESPECIALES' THEN
            FOR reg IN c_mov_esp LOOP
               v_error := NULL;
               --Si es una promocion, no procesar ya se está procesando en el proceso de Promociones.
               SELECT COUNT(*)
                 INTO v_cantidad
                 FROM ta_con_promociones
                WHERE descripcion = reg.des_movimiento;
               IF v_cantidad = 0 THEN
                 begin
                  SELECT COUNT(*)
                    INTO v_cantidad
                    FROM ta_ref_movimientos
                   WHERE ref_archivo = p_ref_archivo
                     AND descripcion = reg.des_movimiento;
                 exception
                   when others then
                     v_cantidad := 0;
                   end;
                   IF v_cantidad = 0 THEN
                      v_error := 'No se ha cargado en Ref. de Movimientos la descripción  : ' ||
                                 reg.des_movimiento;
                   ELSIF v_cantidad = 1 THEN
                      v_error := NULL;
                   ELSIF v_cantidad > 1 THEN
                      v_error := 'Se ha encontrado mas de un registro en Ref. de Movimientos con la descripción  : ' ||
                                 reg.des_movimiento;
                   ELSE
                      v_error := 'Error al buscar Ref. de Movimientos : ' || SQLERRM;
                   END IF;
               END IF;
               --Verificar si existe la cuenta
               IF v_error IS NULL THEN
                  SELECT COUNT(*), cod_oficina
                    INTO v_cantidad, v_cod_oficina
                    FROM ta_cta_tarjetas
                   WHERE nro_cuenta = reg.nro_cuenta
                   GROUP BY cod_oficina;
                  IF v_cantidad = 0 THEN
                     v_error := 'Cuenta de Tarjeta inexistente';
                  END IF;
               END IF;
               IF v_error IS NULL THEN
                  SELECT COUNT(*)
                    INTO v_cantidad
                    FROM ge_cta_clientes
                   WHERE nro_cuenta = reg.nro_cuenta
                     AND relacion = 'P';
                  IF v_cantidad = 0 THEN
                     v_error := 'Cuenta sin Principal';
                  END IF;
               END IF;

               INSERT INTO ta_mov_especiales
                  (ref_archivo, fecha, cod_usu_proceso, nro_cuenta, nro_tarjeta, dig_verificador,
                   fec_movimiento, des_movimiento, mto_operacion, mto_impuesto, tip_afectacion,
                   tip_movimiento, financia, fec_proceso, cod_usuario, for_pago, procesado,
                   error, cod_ofi_origen)
               VALUES
                  (p_ref_archivo, v_fcdehoy, USER, reg.nro_cuenta, reg.nro_tarjeta,
                   reg.dig_verificador, reg.fec_movimiento, reg.des_movimiento, reg.mto_operacion,
                   reg.mto_impuesto, reg.tip_afectacion, substr(reg.tip_movimiento, 1, 1),
                   reg.financia, reg.fec_proceso, reg.cod_usuario, reg.cod_origen, 'N', v_error, v_cod_oficina);
            END LOOP;

         ELSIF p_ref_archivo = 'TAR_MOV_INTERESES' THEN
            FOR reg IN c_mov_int LOOP
               --Verificar si existe la cuenta
               v_error := NULL;
               begin
                 SELECT COUNT(*), cod_oficina
                   INTO v_cantidad, v_cod_oficina
                   FROM ta_cta_tarjetas
                  WHERE nro_cuenta = reg.nro_cuenta
                  GROUP BY cod_oficina;
                  exception
                    when others then
                      v_cantidad:=0;
                end;
               IF v_cantidad = 0 THEN
                  v_error := 'Cuenta de Tarjeta inexistente';
               END IF;
               IF v_error IS NULL THEN
                  SELECT COUNT(*)
                    INTO v_cantidad
                    FROM ge_cta_clientes
                   WHERE nro_cuenta = reg.nro_cuenta
                     AND relacion = 'P';
                  IF v_cantidad = 0 THEN
                     v_error := 'Cuenta sin Principal';
                  END IF;
               END IF;
               INSERT INTO ta_mov_especiales
                  (ref_archivo, fec_movimiento, fecha, cod_usu_proceso, nro_cuenta,
                   tip_movimiento, mto_operacion, mto_impuesto, fec_proceso, cod_usuario,
                   procesado, error, nro_cta_debito, mto_amortizacion, cod_ofi_origen)
               VALUES
                  (p_ref_archivo, reg.fec_proceso, v_fcdehoy, USER, reg.nro_cuenta,
                   reg.tip_movimiento, reg.mto_int_cuota, reg.mto_imp_int_cuota, reg.fec_proceso,
                   USER, 'N', v_error, reg.nro_cta_bancaria, reg.mto_amortizacion, v_cod_oficina);
            END LOOP;
         ELSIF p_ref_archivo = 'TAR_MOV_DIARIO' THEN
            --Movimientos Diarios
            FOR reg IN c_mov_diario LOOP
               v_error := NULL;
               BEGIN
                  SELECT cod_referencia
                    INTO v_dato
                    FROM ta_ref_movimientos
                   WHERE ref_archivo = p_ref_archivo
                     AND cod_referencia = reg.cod_tip_cargo;
               EXCEPTION
                  WHEN no_data_found THEN
                     v_error := 'No se ha cargado en Ref. de Movimientos la descripción  : ' ||
                                reg.cod_tip_cargo || '-' || reg.descripcion;
                  WHEN too_many_rows THEN
                     v_error := 'Se ha encontrado mas de un registro en Ref. de Movimientos con la descripción  : ' ||
                                reg.cod_tip_cargo || '-' || reg.descripcion;
                  WHEN OTHERS THEN
                     v_error := 'Se ha encontrado mas de un registro en Ref. de Movimientos con la descripción  : ' ||
                                reg.cod_tip_cargo || '-' || reg.descripcion;
               END;
               --Verificar si existe la cuenta
               IF v_error IS NULL THEN
                 begin
                   SELECT COUNT(*), cod_oficina
                     INTO v_cantidad, v_cod_oficina
                     FROM ta_cta_tarjetas
                    WHERE nro_cuenta = reg.nro_cuenta
                    GROUP BY cod_oficina;
                  exception
                    when others then
                      v_cantidad := 0;
                  end;
                  IF v_cantidad = 0 THEN
                     v_error := 'Cuenta de Tarjeta inexistente';
                  END IF;
               END IF;
               IF v_error IS NULL THEN
                  SELECT COUNT(*)
                    INTO v_cantidad
                    FROM ge_cta_clientes
                   WHERE nro_cuenta = reg.nro_cuenta
                     AND relacion = 'P';
                  IF v_cantidad = 0 THEN
                     v_error := 'Cuenta sin Principal';
                  END IF;
               END IF;
               --
               INSERT INTO ta_mov_especiales
                  (ref_archivo, nro_cuenta, nro_tarjeta, dig_verificador, fecha, des_movimiento,
                   mto_operacion, tip_afectacion, tip_movimiento, financia, fec_proceso, cod_usuario,
                   for_pago, fec_movimiento, procesado, cod_usu_proceso, error, mto_impuesto,mto_int_cuota,
                   mto_comision, cod_tip_cargo, cod_ori_pago, cod_plan, can_cuotas, est_cuota, cod_ofi_origen)
               VALUES
                  (p_ref_archivo, to_char(to_number(reg.nro_cuenta)) /*nro_cuenta*/,
                   (reg.nro_tarjeta),
                   substr(TRIM(reg.nro_tarjeta), length(TRIM(reg.nro_tarjeta)), 1)
                   /*dig_verificador*/, v_fcdehoy, substr((TRIM(reg.descripcion)), 1, 20)
                   /*des_movimiento*/, abs(to_number(REPLACE(TRIM(reg.mto_operacion), ',', '.')))
                   /* mto_operacion*/, TRIM(reg.tip_saldo) /*tip_saldo*/,
                   decode(greatest(0, to_number(REPLACE(TRIM(reg.mto_operacion), ',', '.'))), 0, 'C',
                           'D') /*cod_tip_movimiento*/, 'N' /*financia*/, reg.fec_proceso,
                   TRIM(reg.usu_movimiento), /*cod_usuario*/ TRIM(reg.for_pago), reg.fec_valor, 'N',
                   USER, v_error, abs(to_number(REPLACE(TRIM(reg.mto_impuesto), ',', '.'))), reg.mto_interes, reg.mto_comision, reg.cod_tip_cargo,
                   reg.cod_ori_pago, reg.cod_plan, reg.can_cuotas, reg.est_cuota, NVL(v_cod_oficina,reg.cod_oficina));
            END LOOP;
            --- SDRESUM
            --Movimientos Diarios
            FOR reg IN c_resumenes LOOP
               v_error := NULL;
               v_dato  := NULL;
               BEGIN
                  SELECT cod_referencia
                    INTO v_dato
                    FROM ta_ref_movimientos
                   WHERE ref_archivo = p_ref_archivo
                     AND cod_referencia = to_char(reg.tip_movimiento||reg.tip_debito)
                     AND procesa = 'S';
               EXCEPTION
                  WHEN no_data_found THEN
                     v_error := 'No se ha cargado en Ref. de Movimientos la descripción  : ' ||
                                reg.tip_movimiento||reg.tip_debito;
                  WHEN too_many_rows THEN
                     v_error := 'Se ha encontrado mas de un registro en Ref. de Movimientos con la descripción  : ' ||
                                reg.tip_movimiento||reg.tip_debito;
                  WHEN OTHERS THEN
                     v_error := 'Se ha encontrado mas de un registro en Ref. de Movimientos con la descripción  : ' ||
                                reg.tip_movimiento||reg.tip_debito ;

               END;
               --Verificar si existe la cuenta
               IF v_error IS NULL THEN
                  SELECT COUNT(*), cod_oficina
                    INTO v_cantidad, v_cod_oficina
                    FROM ta_cta_tarjetas
                   WHERE nro_cuenta = reg.nro_cuenta
                   GROUP BY cod_oficina;
                  IF v_cantidad = 0 THEN
                     v_error := 'Cuenta de Tarjeta inexistente';
                  END IF;
               END IF;
               IF v_error IS NULL THEN
                  SELECT COUNT(*)
                    INTO v_cantidad
                    FROM ge_cta_clientes
                   WHERE nro_cuenta = reg.nro_cuenta
                     AND relacion = 'P';
                  IF v_cantidad = 0 THEN
                     v_error := 'Cuenta sin Principal';
                  END IF;
               END IF;
               --
               INSERT INTO ta_mov_especiales
                  (ref_archivo, nro_cuenta, nro_tarjeta, dig_verificador, fecha, des_movimiento,
                   mto_operacion, tip_afectacion, tip_movimiento, financia, fec_proceso, cod_usuario,
                   for_pago, fec_movimiento, procesado, cod_usu_proceso, error, mto_impuesto,mto_int_cuota,
                   mto_comision, cod_tip_cargo, cod_ori_pago, cod_plan, can_cuotas, est_cuota, cod_ofi_origen)
               VALUES
                  (p_ref_archivo, to_char(to_number(reg.nro_cuenta)) /*nro_cuenta*/,
                   (reg.nro_cuenta),
                   substr(TRIM(reg.nro_cuenta), length(TRIM(reg.nro_cuenta)), 1)
                   /*dig_verificador*/, v_fcdehoy, reg.tip_movimiento||reg.tip_debito
                   /*des_movimiento*/, abs(to_number(REPLACE(TRIM(reg.monto), ',', '.')))
                   /* mto_operacion*/, null /*tip_saldo*/,
                   decode(greatest(0, to_number(REPLACE(TRIM(reg.monto), ',', '.'))), 0, 'C',
                           'D') /*cod_tip_movimiento*/, 'N' /*financia*/, reg.fec_proceso,
                   null, /*cod_usuario*/ null, reg.fec_valor, 'N',
                   USER, v_error, abs(to_number(REPLACE(TRIM(reg.mto_iva), ',', '.'))), null, reg.mto_comision, reg.tip_movimiento||reg.tip_debito,
                   null, null, reg.can_cuotas, null, v_cod_oficina);
            END LOOP;
         ELSIF p_ref_archivo = 'TAR_SEG_VIDA' THEN
            -- Mov. Cargos Seguros de Vida(Cierre).
            FOR reg IN c_seg_vida LOOP
               --Verificar si existe la cuenta
               v_error := NULL;
               begin
               SELECT COUNT(*), cod_oficina
                 INTO v_cantidad, v_cod_oficina
                 FROM ta_cta_tarjetas
                WHERE nro_cuenta = reg.nro_cuenta
                GROUP BY cod_oficina;
                exception
                  when others then
                    v_cantidad:=0;
                end;
               IF v_cantidad = 0 THEN
                  v_error := 'Cuenta de Tarjeta inexistente';
               END IF;
               IF v_error IS NULL THEN
                  SELECT COUNT(*)
                    INTO v_cantidad
                    FROM ge_cta_clientes
                   WHERE nro_cuenta = reg.nro_cuenta
                     AND relacion = 'P';
                  IF v_cantidad = 0 THEN
                     v_error := 'Cuenta sin Principal';
                  END IF;
               END IF;
               INSERT INTO ta_mov_especiales
                  (ref_archivo, fec_movimiento, fecha, mto_operacion, cod_usu_proceso, nro_cuenta,
                   mto_impuesto, fec_proceso, cod_usuario, procesado, error, tip_cierre,
                   mto_seg_usuario, mto_seg_entidad, afinidad, cod_ofi_origen)
               VALUES
                  (p_ref_archivo, reg.fec_cierre, v_fcdehoy, reg.saldo, USER, reg.nro_cuenta,
                   reg.mto_iva_seg_cliente, reg.fec_cierre, USER, 'N', v_error, reg.tip_cierre,
                   reg.mto_seg_cliente, reg.mto_seg_entidad, reg.afinidad, v_cod_oficina);
            END LOOP;

         ELSIF p_ref_archivo = 'TAR_INF_GAS_FINANCIEROS' THEN
          -- Mov. de Gastos Financieros (Cierre)
            FOR reg IN c_gas_financieros LOOP
               v_error := NULL;
               begin
               SELECT COUNT(*)
                 INTO v_cantidad
                 FROM ta_cta_tarjetas
                WHERE nro_cuenta = reg.nro_cuenta;
               exception
                  when others then
                    v_cantidad:=0;
                end;
               IF v_cantidad = 0 THEN
                  v_error := 'Cuenta de Tarjeta inexistente';
               END IF;
               IF v_error IS NULL THEN
                  SELECT COUNT(*)
                    INTO v_cantidad
                    FROM ge_cta_clientes
                   WHERE nro_cuenta = reg.nro_cuenta
                     AND relacion = 'P';
                  IF v_cantidad = 0 THEN
                     v_error := 'Cuenta sin Principal';
                  END IF;
               END IF;

               INSERT INTO ta_mov_especiales
                  (ref_archivo, fecha, cod_usu_proceso, nro_cuenta, fec_proceso, fec_movimiento,
                   mto_int_corriente, mto_int_mora, mto_int_punitorio, mto_int_cuota, mto_iva_cuo_5,
                   /*mto_per_iva10*/MTO_IVA_AFE_PER_10, /*mto_per_iva5*/MTO_IVA_AFE_PER_5, /*mto_cie_iva10*/MTO_IVA_AFE_CIE_10, /*mto_cie_iva5*/MTO_IVA_AFE_CIE_5, procesado, error, cod_ofi_origen)
               VALUES
                  (p_ref_archivo, v_fcdehoy, USER, reg.nro_cuenta, reg.fec_cierre, reg.fec_cierre,
                   nvl(reg.mto_int_corriente, 0)+nvl(reg.mto_int_compra, 0), reg.mto_int_mora, reg.mto_int_punitorio, reg.mto_int_cuota,
                   reg.mto_iva_cuo_5, reg.mto_iva_afe_per_10, reg.mto_iva_afe_per_5,
                   reg.mto_iva_afe_cie_10, reg.mto_iva_afe_cie_5, 'N', v_error, reg.cod_oficina);
            END LOOP;
         END IF;
         --Verificar si hubo errores
         v_cantidad := 0;
         ---
         SELECT COUNT(*)
           INTO v_cantidad
           FROM ta_mov_especiales
          WHERE ref_archivo = p_ref_archivo
            AND cod_usu_proceso = USER
            AND fecha = v_fcdehoy
            AND nvl(procesado, 'N') = 'N'
            AND error IS NOT NULL;
         IF nvl(v_cantidad, 0) <> 0 THEN
            r_log.comentario := 'Proceso de importación concluido con errores.' || '-' ||
                                p_ref_archivo;
         ELSE
            r_log.comentario := '*** Proceso de importación concluido. ' || p_ref_archivo || ' ***';
         END IF;

      END IF;
      --- Inserta en el log de Tarjetas
      prt_ins_log(r_log, FALSE);
   END;

   --*
   --*   PROCEDIMIENTO PRINCIPAL
   --*
BEGIN
   BEGIN
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
   END;

   v_fcdehoy       := pag_cal.fu_obt_fec_actual(5);
   v_hora          := to_char(SYSDATE, 'HH24:MI:SS');
   v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
   v_nro_secuencia := 0;
   v_cod_mon_local := pag_gen.fu_obt_mon_local;
   v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null, null, v_cod_mon_local);
   --Asignar valores generales para registro de movimientos
   rg_movs.cod_usuario := USER;
   rg_movs.fecha       := v_fcdehoy;
   rg_movs.fec_valor   := v_fcdehoy;

   ---> Proceso A/Automático
   lp_val_imp_archivo;
   --- Verificar que no se han procesado registros para la fecha
   IF nvl(v_existe, 0) > 0 THEN
      GOTO fin_proceso;
   END IF;
   v_error  := NULL;
   v_existe := 0;
   --
   /*
    Procesar Movimientos especiales del archivo PBMOVDIARIO
   */
   IF p_ref_archivo = 'TAR_MOV_ESPECIALES' THEN
      v_cod_tra_padre := 1213;
      FOR reg IN c1 LOOP
         
         v_error := NULL;
         v_fecha := reg.fecha;
         v_fila  := reg.fila;
         --Se debe agrupar x comercio y tipo de promocion
         IF v_cor_cuenta IS NULL AND v_cor_movimiento IS NULL AND v_cor_tip_mov IS NULL THEN
            --Guardar la variables de corte de control e iniciar acumulados
            v_cor_cuenta     := reg.nro_cuenta;
            v_cor_movimiento := reg.des_movimiento;
            v_cor_tip_mov    := reg.cod_tip_movimiento;
            v_acu_monto      := 0;
            v_acu_iva        := 0;
         END IF;
         IF reg.nro_cuenta <> v_cor_cuenta OR reg.des_movimiento <> v_cor_movimiento OR
            reg.cod_tip_movimiento <> v_cor_tip_mov THEN
            --Corte de control
            pr_act_movimientos;
            /*  -- Guardar las variables del corte de control e reiniciar los acumulados */
            v_cor_cuenta     := reg.nro_cuenta;
            v_cor_movimiento := reg.des_movimiento;
            v_cor_tip_mov    := reg.cod_tip_movimiento;
            v_acu_monto      := 0;
            v_acu_iva        := 0;
         END IF;
         --
         v_acu_monto := nvl(v_acu_monto, 0) + nvl(reg.mto_operacion, 0);
         v_acu_iva   := nvl(v_acu_iva, 0) + nvl(reg.mto_impuesto, 0);
      END LOOP;

      --Procesar Corte de control por fin de archivo
      IF v_cor_cuenta IS NOT NULL THEN
         pr_act_movimientos;
      END IF;
   END IF;
   /*
    Procesar Movimientos de Intereses del archivo MDCG60 - (PBRESUPLANCUENTA)
   */
   IF p_ref_archivo = 'TAR_MOV_INTERESES' THEN
      v_cod_tra_padre  := 1214;
      v_cor_movimiento := 'Interes x Compras en cuotas.';
      FOR reg IN c1 LOOP
         v_error := NULL;
         v_fecha := reg.fecha;
         v_fila  := reg.fila;
         --Se debe agrupar x Cuenta y Tipo de Movimiento
         IF v_cor_cuenta IS NULL AND v_cor_tip_mov IS NULL THEN
            --Guardar la variables de corte de control e iniciar acumulados
            v_cor_cuenta    := reg.nro_cuenta;
            v_cor_tip_mov   := reg.cod_tip_movimiento;
            v_cod_tip_movimiento := 'D' ;
            v_acu_monto     := 0;
            v_acu_iva       := 0;
            v_mto_imponible := 0;
            v_nro_secuencia   := 0;
         END IF;
         IF reg.nro_cuenta <> v_cor_cuenta OR reg.cod_tip_movimiento <> v_cor_tip_mov THEN
            --Corte de control
            v_hora := fug_obt_hor_disponible(pag_cal.fu_obt_fec_actual(1), v_hora, USER, 'N');
            rg_movs.fec_valor   := reg.fec_movimiento;
            pr_act_movimientos;
            /* -- Guardar las variables del corte de control e reiniciar los acumulados */
            v_cor_cuenta    := reg.nro_cuenta;
            v_cor_tip_mov   := 'D';
            v_acu_monto     := 0;
            v_acu_iva       := 0;
            v_mto_imponible := 0;
            v_nro_secuencia   := 0;
         END IF;
         --
         v_acu_iva       := nvl(v_acu_iva, 0) + nvl(reg.mto_impuesto,0);
         v_mto_imponible := nvl(v_mto_imponible, 0) + nvl(reg.mto_operacion,0);
         v_acu_monto     := nvl(v_acu_monto, 0) + nvl(reg.mto_operacion,0) + nvl(reg.mto_impuesto,0);
      END LOOP;

      --Procesar Corte de control por fin de archivo
      IF v_cor_cuenta IS NOT NULL THEN
         v_hora := fug_obt_hor_disponible(pag_cal.fu_obt_fec_actual(1), v_hora, USER, 'N');
         pr_act_movimientos;
      END IF;
   END IF;
   /*
    Procesar Movimientos de Gastos Financieros (Mensual) - (GF050)
   */
   IF p_ref_archivo = 'TAR_INF_GAS_FINANCIEROS' THEN
      v_cod_tra_padre  := 1215;
      v_cor_movimiento := 'Gastos Financieros.';
      FOR reg IN c1 LOOP
         v_error := NULL;
         v_fecha := reg.fecha;
         v_fila  := reg.fila;
         --Se debe agrupar x cuenta
         IF v_cor_cuenta IS NULL THEN
            --Guardar la variables de corte de control e iniciar acumulados
            v_cor_cuenta    := reg.nro_cuenta;
            v_acu_monto     := 0;
            v_acu_iva       := 0;
            v_mto_imponible := 0;
            v_nro_secuencia   := 0;
         END IF;
         IF reg.nro_cuenta <> v_cor_cuenta THEN
            -- Corte x cuenta
            v_hora := fug_obt_hor_disponible(pag_cal.fu_obt_fec_actual(1), v_hora, USER, 'N');
            rg_movs.fec_valor   := reg.fec_movimiento;
            pr_act_movimientos;
            /* -- Guardar las variables del corte de control e reiniciar los acumulados */
            v_cor_cuenta    := reg.nro_cuenta;
            v_acu_monto     := 0;
            v_acu_iva       := 0;
            v_mto_imponible := 0;
            v_nro_secuencia   := 0;
         END IF;
         --
         v_acu_iva       := nvl(v_acu_iva, 0) + nvl(reg.mto_cie_iva5, 0); --- 518
         v_acu_monto     := nvl(v_acu_monto, 0) + --- 1505
                            (nvl(reg.mto_int_corriente, 0) + nvl(reg.mto_int_mora, 0) +
                             nvl(reg.mto_int_punitorio, 0)) + nvl(v_acu_iva, 0);--- Sumar el IVA a la acumulacion del monto
         v_mto_imponible := nvl(v_mto_imponible, 0) + (nvl(v_acu_monto, 0) - nvl(v_acu_iva, 0)); ---1645
      END LOOP;

      --Procesar Corte de control por fin de archivo
      IF v_cor_cuenta IS NOT NULL THEN
         v_hora := fug_obt_hor_disponible(pag_cal.fu_obt_fec_actual(1), v_hora, USER, 'N');
         pr_act_movimientos;
      END IF;
   END IF;

   /*
    Procesar Movimientos del Informe Financiero. Archivo SDRESUM (Diario)
   */
   IF p_ref_archivo = 'TAR_INF_FINANCIERO' THEN
      v_cod_tra_padre  := 1216;
      v_cor_movimiento := 'Informe Financiero.';
      FOR reg IN c2 LOOP
         v_error := NULL;
         v_fecha := reg.fecha;
         v_fila  := reg.fila;
         --Se debe agrupar x cuenta y Tipo de Movimiento
         IF v_cor_cuenta IS NULL THEN
            --Guardar la variables de corte de control e iniciar acumulados
            v_cor_cuenta   := reg.nro_cuenta;
            v_cor_tip_mov  := reg.tip_movimiento;
            v_cor_clase    := reg.clase;
            v_cor_tip_afec := reg.tip_afectacion;
            v_acu_monto    := 0;
            v_acu_iva      := 0;
         END IF;
         IF reg.nro_cuenta <> v_cor_cuenta OR reg.tip_movimiento <> v_cor_tip_mov OR
            reg.clase <> v_cor_clase OR reg.tip_afectacion <> v_cor_tip_afec THEN
            -- Corte x cuenta, tip_movimiento y clase, Tip_afectacion(Tip_Debito)
            pr_act_movimientos;
            /* -- Guardar las variables del corte de control e reiniciar los acumulados */
            v_cor_cuenta   := reg.nro_cuenta;
            v_cor_tip_mov  := reg.tip_movimiento;
            v_cor_clase    := reg.clase;
            v_cor_tip_afec := reg.tip_afectacion;
            v_acu_monto    := 0;
            v_acu_iva      := 0;
         END IF;
         --
         v_acu_monto := nvl(v_acu_monto, 0) + nvl(reg.mto_operacion, 0);
         v_acu_iva   := nvl(v_acu_iva, 0) + nvl(reg.mto_impuesto, 0);
      END LOOP;

      --Procesar Corte de control por fin de archivo
      IF v_cor_cuenta IS NOT NULL THEN
         pr_act_movimientos;
      END IF;
      --Acreditar a los Rubros ingresado por pantalla, grabados en Ta_mov_especiales
      FOR reg IN c3 LOOP
         IF v_nro_secuencia > 990 THEN
            v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
            v_nro_secuencia := 0;
         END IF;
         v_nro_secuencia         := v_nro_secuencia + 1;
         rg_movs.nro_secuencia   := v_nro_secuencia;
         rg_movs.hora            := v_hora;
         rg_movs.cod_mod_padre   := 5;
         rg_movs.cod_mad_padre   := 505;
         rg_movs.cod_tra_padre   := v_cod_tra_padre;
         rg_movs.cod_modulo      := NULL;
         rg_movs.cod_modalidad   := NULL;
         rg_movs.cod_transaccion := NULL;
         rg_movs.cod_moneda      := v_cod_mon_local;
         rg_movs.nro_cuenta      := NULL;
         rg_movs.cod_oficina     := v_cod_oficina;
         rg_movs.monto           := reg.mto_operacion;
         rg_movs.nro_documento   := NULL;
         rg_movs.nro_documento2  := NULL;
         rg_movs.cod_tasa        := NULL;
         rg_movs.val_tasa        := NULL;
         rg_movs.cotizacion      := NULL;
         rg_movs.emi_aviso       := 'N';
         rg_movs.cod_ofi_origen  := v_cod_oficina;
         rg_movs.concepto        := v_cor_movimiento;
         rg_movs.estado          := 'N';
         rg_movs.est_cuenta      := null;
         rg_movs.reversado       := 'N';
         rg_movs.emi_aviso       := 'N';
         rg_movs.nro_caja        := NULL;
         rg_movs.cod_rubro       := reg.cod_rubro;
         rg_movs.tip_mov_rubro   := 'C';
         --
         pag_gen.pr_ins_ge_movimiento(rg_movs, 'N'); -- inserta datos en ge_movimientos
      END LOOP;
   END IF;

   /*
    Procesar Movimientos del Informe Financiero. Archivo SDRESUM (Cierre)
   */
   IF p_ref_archivo = 'TAR_INF_FIN_CIERRE' THEN
      v_cod_tra_padre  := 1217;
      v_cor_movimiento := 'Informe Financiero al Cierre.';
      FOR reg IN c2 LOOP
         v_error := NULL;
         v_fecha := reg.fecha;
         v_fila  := reg.fila;
         --Se debe agrupar x cuenta y Tipo de Movimiento
         IF v_cor_cuenta IS NULL THEN
            --Guardar la variables de corte de control e iniciar acumulados
            v_cor_cuenta   := reg.nro_cuenta;
            v_cor_tip_mov  := reg.tip_movimiento;
            v_cor_clase    := reg.clase;
            v_cor_tip_afec := reg.tip_afectacion;
            v_acu_monto    := 0;
            v_acu_iva      := 0;
         END IF;
         IF reg.nro_cuenta <> v_cor_cuenta OR reg.tip_movimiento <> v_cor_tip_mov OR
            reg.clase <> v_cor_clase OR reg.tip_afectacion <> v_cor_tip_afec THEN
            -- Corte x cuenta, tip_movimiento y clase, Tip_afectacion(Tip_Debito)
            pr_act_movimientos;
            /* -- Guardar las variables del corte de control e reiniciar los acumulados */
            v_cor_cuenta   := reg.nro_cuenta;
            v_cor_tip_mov  := reg.tip_movimiento;
            v_cor_clase    := reg.clase;
            v_cor_tip_afec := reg.tip_afectacion;
            v_acu_monto    := 0;
            v_acu_iva      := 0;
         END IF;
         --
         v_acu_monto := nvl(v_acu_monto, 0) + nvl(reg.mto_operacion, 0);
         v_acu_iva   := nvl(v_acu_iva, 0) + nvl(reg.mto_impuesto, 0);
      END LOOP;

      --Procesar Corte de control por fin de archivo
      IF v_cor_cuenta IS NOT NULL THEN
         pr_act_movimientos;
      END IF;

   END IF;
   --
   /*
    Procesar Movimientos Diarios del archivo(PBMOVDIARIO)
   */
   IF p_ref_archivo = 'TAR_MOV_DIARIO' THEN
      v_cod_tra_padre    := 37;
      v_cor_movimiento   := 'Movimientos Especiales Tarjetas.';
      v_acu_com_bancard  := 0;
      v_acu_imp_bancard  := 0;

      FOR reg IN c4 LOOP
        dbms_output.put_line(reg.nro_cuenta||'-'||reg.mto_operacion);
         v_error := NULL;
         v_fecha := reg.fecha;
         v_fila  := reg.fila;

         IF v_cor_cuenta IS NULL THEN
            -- Guardar las variables de corte de control e iniciar acumulados
            v_cor_cuenta      := reg.nro_cuenta;
            v_cor_tip_mov     := reg.tip_movimiento;
            v_cor_tip_afec    := reg.tip_afectacion;
            v_acu_monto       := 0;
            v_acu_iva         := 0;
            v_mto_total       := 0;
            v_mto_comision    := 0;
            v_mto_base        := 0;
            v_mto_impuesto    := 0;
            v_mto_interes     := 0;
            v_acu_mto_seguro  := 0;
            v_acu_mto_entidad := 0;
            v_acu_iva_fra     := 0;
            v_acu_iva_seg     := 0;
            v_cod_tip_cargo   := reg.cod_tip_cargo;
            v_cod_ori_pago    := reg.cod_ori_pago;
            v_cod_plan        := reg.cod_plan;
            v_descripcion     := reg.des_movimiento;
            v_cod_tip_movimiento := reg.tip_movimiento;
            v_nro_secuencia   := 0;
            v_mto_deb_pronet  := 0;
            v_mto_deb_web_post:= 0;
            v_cta_deb_efectivo := null;
            v_cob_cargo        := 0;
            v_cod_ofi_movimiento:= reg.cod_ofi_origen;
         END IF;

         IF reg.nro_cuenta <> v_cor_cuenta OR reg.tip_movimiento <> v_cor_tip_mov OR
            reg.tip_afectacion <> v_cor_tip_afec OR reg.cod_tip_cargo <> v_cod_tip_cargo OR
            reg.cod_ori_pago <> v_cod_ori_pago OR reg.Cod_Plan<>v_cod_plan
            THEN
            -- Corte x cuenta, tip_movimiento y Tipo Cargo, Tip_afectacion(Tip_Debito)
            v_hora := fug_obt_hor_disponible(pag_cal.fu_obt_fec_actual(1), v_hora, USER, 'N');
            rg_movs.fec_valor   := reg.fec_movimiento;
            pr_act_movimientos;
            v_cod_tip_movimiento := reg.tip_movimiento;

            /*-- Guardar las variables del corte de control e reiniciar los acumulados */
            v_cor_cuenta      := reg.nro_cuenta;
            v_cor_tip_mov     := reg.tip_movimiento;
            v_cor_tip_afec    := reg.tip_afectacion;
            v_mto_impuesto    := 0;
            v_acu_monto       := 0;
            v_acu_iva         := 0;
            v_mto_total       := 0;
            v_mto_comision    := 0;
            v_mto_interes     := 0;
            v_acu_mto_seguro  := 0;
            v_acu_mto_entidad := 0;
            v_acu_iva_fra     := 0;
            v_acu_iva_seg     := 0;
            v_cod_tip_cargo   := reg.cod_tip_cargo;
            v_cod_ori_pago    := reg.cod_ori_pago;
            v_cod_plan        := reg.cod_plan;
            v_descripcion     := reg.des_movimiento;
            v_nro_secuencia   := 0;
            v_mto_deb_pronet  := 0;
            v_mto_deb_web_post:= 0;
            v_cta_deb_efectivo := null;
            v_cod_ofi_movimiento:= reg.cod_ofi_origen;
            v_cob_cargo        := 0;
         END IF;
         -- Cuando es una compra en cuotas plan 03 pactado con el Comercio la primera vez
         -- viene el monto total y debe dividirse por la cantidad de cuotas, de lo contrario
         -- debe obtener el monto original
        IF reg.cod_plan ='03' AND reg.cod_tip_cargo = '38' AND reg.fec_movimiento = reg.fec_proceso THEN
          if reg.est_cuota is not null then
            v_acu_monto    := nvl(v_acu_monto, 0) + nvl(reg.mto_operacion, 0);
            /*v_acu_monto    := nvl(v_acu_monto, 0) +
                              round(nvl(reg.mto_operacion, 0) / reg.can_cuotas, v_redondeo);*/
           end if;
         ELSE
            v_acu_monto    := nvl(v_acu_monto, 0) + nvl(reg.mto_operacion, 0);
         END IF;

         --Adelanto en Efectivo - POS en cuotas- la 1era vez viene el monto total - luego viene el interes de la cuota,
         -- sólo debe procesarse en la siguiente vez el Monto interés de la cuota, sin tener en cuenta el monto de la Operación.
         IF reg.cod_tip_cargo = '39' AND reg.cod_plan = '21' and nvl(reg.mto_int_cuota,0) > 0 then
            v_mto_interes    := nvl(v_mto_interes, 0) + nvl(reg.mto_int_cuota, 0);
            v_acu_monto :=  v_mto_interes;
         END IF;

         /*Acumular importe para mov de débito a cta bancarias por cobros en Efectivos*/
         IF v_cod_tip_cargo = '25' THEN
            v_cob_cargo := nvl(v_cob_cargo,0) + 1;
            IF v_cod_ori_pago = 'P' THEN -- Pronet
               v_mto_deb_pronet   := v_mto_deb_pronet + nvl(reg.mto_operacion, 0);
            ELSIF v_cod_ori_pago in ('V', 'W') THEN -- Post y Web
               v_mto_deb_web_post := v_mto_deb_web_post + nvl(reg.mto_operacion, 0);
            END IF;
         END IF;

         v_acu_iva      := nvl(v_acu_iva, 0) + nvl(reg.mto_impuesto, 0);
         v_mto_total    := nvl(v_acu_monto, 0) + nvl(v_acu_iva, 0);
         --- Interes compra Local: Tipo de Cargo 38
         --- Solo si tiene comisión tiene que generar el movimiento sumando el IVA
         --- Cuando es una compra Local, y viene el registro la primera vez,
         --- sólo debe de tomar el monto de la comisión de la cuota

         IF nvl(reg.mto_comision, 0) <> 0 then
           If reg.cod_tip_cargo = '38' then
             IF reg.cod_plan ='03' THEN
               IF reg.est_cuota is not null then -- DEBE PROCESAR LA PRIMERA VEZ, SÓLO LA COMISIÓN DE LA CUOTA
                v_mto_comision := nvl(v_mto_comision, 0) +( nvl(reg.mto_comision, 0) + nvl(v_acu_iva, 0));
               END IF;
              ELSE
                v_mto_comision := nvl(v_mto_comision, 0) +( nvl(reg.mto_comision, 0) + nvl(v_acu_iva, 0));
              END IF;
           ELSE
             v_mto_comision := nvl(v_mto_comision, 0) +( nvl(reg.mto_comision, 0) + nvl(v_acu_iva, 0));
           END IF;
         END IF;

         IF v_cod_tip_cargo = '6' THEN --- Seguro contra Fraude
            v_por_seg_fraude := fug_obt_parentes(fug_obt_pardinamico('COD_PRO_BANCARD'), 'TAR_POR_SEG_FRAUDE');
            v_acu_mto_seguro  := nvl(v_acu_mto_seguro, 0) + (nvl(v_acu_monto,0) * nvl(v_por_seg_fraude,0) /100); --- Porcentaje Seguro
            v_acu_mto_entidad := v_acu_monto - v_acu_mto_seguro; --- Porcentaje Entidad
            v_acu_iva:=0;

         END IF;

      END LOOP;
      --Procesar Corte de control por fin de archivo
      IF v_cor_cuenta IS NOT NULL THEN
         v_hora := fug_obt_hor_disponible(pag_cal.fu_obt_fec_actual(1), v_hora, USER, 'N');
         pr_act_movimientos;
      END IF;
      IF v_acu_com_bancard > 0 AND v_acu_imp_bancard > 0 THEN
         v_cod_transaccion := 1084;
         --- Valores por defecto ya que es un único movimiento para utilizar en la facturación
         v_cod_modulo := 5;
         v_cod_modalidad := 505;
         v_cod_oficina := fug_obt_ofi_matriz;
         ---
         -- Insertar movimientos por la Comisión.
         v_hora                  := fug_obt_hor_disponible(pag_cal.fu_obt_fec_actual(1), v_hora, USER, 'N');
         v_nro_secuencia         := 0;
         v_nro_secuencia         := v_nro_secuencia + 1;
         rg_movs.nro_secuencia   := v_nro_secuencia;
         rg_movs.hora            := v_hora;
         rg_movs.cod_mod_padre   := 5;
         rg_movs.cod_mad_padre   := 505;
         rg_movs.cod_tra_padre   := v_cod_tra_padre;
         rg_movs.cod_modulo      := v_cod_modulo;
         rg_movs.cod_modalidad   := v_cod_modalidad;
         rg_movs.cod_transaccion := v_cod_transaccion;
         rg_movs.cod_moneda      := v_cod_mon_local;
         rg_movs.nro_cuenta      := null;
         rg_movs.cod_oficina     := v_cod_oficina;
         rg_movs.nro_documento   := NULL;
         rg_movs.nro_documento2  := NULL;
         rg_movs.cod_tasa        := NULL;
         rg_movs.val_tasa        := NULL;
         rg_movs.cotizacion      := NULL;
         rg_movs.emi_aviso       := 'N';
         rg_movs.cod_ofi_origen  := v_cod_oficina;
         rg_movs.concepto        := 'COMISION COMERCIO TCR - TOTAL';
         rg_movs.estado          := 'N';
         rg_movs.est_cuenta      := null;
         rg_movs.reversado       := 'N';
         rg_movs.emi_aviso       := 'N';
         rg_movs.nro_caja        := NULL;
         rg_movs.cod_rubro       := NULL;
         rg_movs.tip_mov_rubro   := NULL;
         rg_movs.monto           := v_acu_com_bancard;
         rg_movs.cod_persona     := v_cod_per_bancard;
         --
         pag_gen.pr_ins_ge_movimiento(rg_movs, 'N');

         /*Busco el impuesto asociado a este cargo
         Solo si afecta cta. de tarjeta*/
         BEGIN
            SELECT cod_tra_hijo
              INTO v_cod_tra_impuesto
              FROM ge_transacciones_det
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = v_cod_transaccion
               AND cod_mod_hijo = v_cod_modulo
               AND cod_mad_hijo = v_cod_modalidad
               AND cod_tra_hijo <> v_cod_transaccion -- Que la transacción hijo sea diferente de la padre PV 02/11/09
               AND rownum = 1;

            -- Traer tasa del impuesto
            v_cod_tas_impuesto := NULL;
            v_val_tas_impuesto := NULL;
            v_fec_vigencia     := NULL;
            v_tip_valor        := NULL;
            v_tipo             := NULL;

            pag_gen.pr_obt_val_tasa(v_cod_modulo, v_cod_modalidad, v_cod_oficina,
                                    v_cor_cuenta, v_cod_mon_local, 0,
                                    nvl(v_tas_personalizada, 'N'), v_cod_tas_impuesto,
                                    v_cod_tra_impuesto, trunc(SYSDATE), v_val_tas_impuesto,
                                    v_fec_vigencia, v_tip_valor, v_tipo);

             v_acu_imp_bancard := round (v_acu_com_bancard / v_val_tas_impuesto, 0);
         EXCEPTION
             WHEN no_data_found THEN
                IF v_acu_iva > 0 THEN
                   lp_act_err_mov_especiales(v_cor_cuenta,
                                            'No se ha definido transacción de Iva para : ' ||
                                             v_cod_modalidad || '-' || v_cod_transaccion2);
                ELSE
                   NULL;
                END IF;
             WHEN OTHERS THEN
                lp_act_err_mov_especiales(v_cor_cuenta,
                                         'Al leer Impuesto. Transaccion : ' ||
                                          v_cod_transaccion2 || ' - ' || SQLERRM);
         END;
         --
         -- Insertar movimientos por el IVA de la Comisión.

         IF v_nro_secuencia > 990 THEN
             v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
             v_nro_secuencia := 0;
         END IF;
         v_nro_secuencia         := v_nro_secuencia + 1;
         rg_movs.hora            := v_hora;
         rg_movs.nro_secuencia   := v_nro_secuencia;
         rg_movs.cod_mod_padre   := 5;
         rg_movs.cod_mad_padre   := 505;
         rg_movs.cod_tra_padre   := v_cod_tra_padre;
         rg_movs.cod_modulo      := v_cod_modulo;
         rg_movs.cod_modalidad   := v_cod_modalidad;
         rg_movs.cod_transaccion := v_cod_tra_impuesto;
         rg_movs.cod_moneda      := v_cod_mon_local;
         rg_movs.nro_cuenta      := null;
         rg_movs.cod_oficina     := v_cod_oficina;
         rg_movs.nro_documento   := NULL;
         rg_movs.nro_documento2  := NULL;
         rg_movs.cod_tasa        := v_cod_tas_impuesto;
         rg_movs.val_tasa        := v_val_tas_impuesto;
         rg_movs.cotizacion      := NULL;
         rg_movs.emi_aviso       := 'N';
         rg_movs.cod_ofi_origen  := v_cod_oficina;
         rg_movs.concepto        := 'IMPUESTO POR COMISION COMERCIO TCR - TOTAL';
         rg_movs.estado          := 'N';
         rg_movs.est_cuenta      := null;
         rg_movs.reversado       := 'N';
         rg_movs.emi_aviso       := 'N';
         rg_movs.nro_caja        := NULL;
         rg_movs.cod_rubro       := NULL;
         rg_movs.tip_mov_rubro   := NULL;
         rg_movs.monto           := v_acu_imp_bancard;
         rg_movs.cod_persona     := v_cod_per_bancard;
         --
         pag_gen.pr_ins_ge_movimiento(rg_movs, 'N'); -- inserta datos en ge_movimientos
         --
      END IF;

   END IF;
   IF p_ref_archivo = 'TAR_SEG_VIDA' THEN
      v_cod_tra_padre  := 20;
      v_cor_movimiento := 'Cargos Seguros Tarjetas.';
      FOR reg IN c5 LOOP
         v_error := NULL;
         v_fecha := reg.fecha;
         v_fila  := reg.fila;
         --Se debe agrupar x Afinidad
         IF v_cor_cuenta IS NULL THEN
            --Guardar las variables de corte de control e iniciar acumulados
            v_cor_cuenta   := reg.nro_cuenta;
            v_afinidad     := reg.afinidad;
            v_acu_monto    := 0;
            v_mto_seg_contable := 0;
            v_acu_iva      := 0;
            v_acu_iva_ent  := 0;
            v_mon_seg_ent  := 0;
            v_nro_secuencia:= 0;
            v_cod_tip_movimiento := reg.cod_tip_movimiento;
         END IF;
         --Se debe agrupar x cuenta
         IF reg.nro_cuenta <> v_cor_cuenta OR reg.afinidad <> v_afinidad THEN
            -- Corte x cuenta, afinifad
            v_hora := fug_obt_hor_disponible(pag_cal.fu_obt_fec_actual(1), v_hora, USER, 'N');
            pr_act_movimientos;
            /* -- Guardar las variables del corte de control e reiniciar los acumulados*/
            v_cor_cuenta   := reg.nro_cuenta;
            v_afinidad     := reg.afinidad;
            v_acu_monto    := 0;
            v_mto_seg_contable := 0;
            v_acu_iva      := 0;
            v_acu_iva_ent  := 0;
            v_mon_seg_ent  := 0;
            v_nro_secuencia:= 0;
            v_cod_tip_movimiento := reg.cod_tip_movimiento;
         END IF;
         -- Seguro Usuario --

         v_acu_iva_ent := nvl(v_acu_iva_ent, 0) + nvl(reg.mto_impuesto, 0); ---3
         v_acu_monto   := nvl(v_acu_monto, 0) + nvl(reg.mto_seg_usuario, 0) + nvl(v_acu_iva_ent,0); --- 4
         v_mto_seg_contable := nvl(v_mto_seg_contable, 0) + nvl(reg.mto_seg_usuario, 0);
         IF reg.mto_seg_entidad <> 0 THEN
            v_mon_seg_ent := nvl(v_mon_seg_ent, 0) + round(nvl(reg.mto_seg_entidad, 0),0);
         END IF;
      END LOOP;

      --Procesar Corte de control por fin de archivo
      IF v_cor_cuenta IS NOT NULL THEN
         v_hora := fug_obt_hor_disponible(pag_cal.fu_obt_fec_actual(1), v_hora, USER, 'N');
         pr_act_movimientos;
      END IF;
   END IF;
   --Actualizar como procesados los movimientos
   UPDATE ta_mov_especiales
      SET procesado = 'S'
    WHERE ref_archivo = p_ref_archivo
      AND cod_usu_proceso = USER
      AND procesado = 'N'
      AND fecha = v_fcdehoy
      AND error IS NULL;

   <<fin_proceso>>
   NULL;
 pr_env_mai_inf_log;
END;
/

