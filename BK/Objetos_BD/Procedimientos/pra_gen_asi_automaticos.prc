create or replace PROCEDURE IT.pra_gen_asi_automaticos IS
   v_cod_oficina       ba_oficinas.cod_oficina%TYPE;
   v_cod_mon_local     ba_monedas.cod_moneda%TYPE;
   v_fec_actual        ge_calendarios.fec_actual%TYPE;
   v_ult_dia_mes_habil ge_calendarios.fec_actual%TYPE;
   v_error             VARCHAR2(250);
   v_lugar             VARCHAR2(250);
   r_baade             cb_asi_automaticos_det_tmp%ROWTYPE;
   v_hor_inicio        varchar2(8);
   v_hor_fin           varchar2(8);
   v_tra_asientos      varchar2(1);
   v_gen_asi_aju_re4   varchar2(1);


   /* Intereses Devengado de Mesa de Dinero */
   PROCEDURE lp_int_dev_mesadinero;
   /* Cabecera Asiento */
   PROCEDURE lp_cab_asiento;
   /* Procedimiento Equivalente Moneda Local */
   PROCEDURE lp_equ_mon_local;
   /* Estadistico */
   PROCEDURE lp_estadistico;
   /* Movimientos Diarios */
   PROCEDURE lp_mov_diarios;
   /* Intereses Devengados */
   PROCEDURE lp_int_devengados;
   /* Intereses Devengados Cuenta Basica*/
   PROCEDURE lp_int_dev_cta_basica;
   /* Intereses Devengado de Prestamos */
   PROCEDURE lp_int_dev_prestamos;
  /* Intereses Devengado de Prestamos Cancelados RE4 */
   PROCEDURE lp_int_dev_prestamos_can_re4;
    /* Intereses Devengado de Prestamos RE4 */
   PROCEDURE lp_int_dev_prestamos_re4;
   /*Intereses Devengados Resolucion 4*/
   PROCEDURE lp_int_dev_pre_aju_re4;
   /* Intereses Devengado de Comisiones Diferidas */
   PROCEDURE lp_int_dev_comisiones;
   -- Intereses Devengado Operaciones Futuras
   PROCEDURE lp_dev_ope_futuras;
   /* Insertar asientos automaticos detalles. */
   PROCEDURE lp_ins_asi_aut_det(rp_baade IN cb_asi_automaticos_det_tmp%ROWTYPE);
   /* Obtener la moneda del rubro del parametro. */
   PROCEDURE lp_obt_mon_rubro
   (
      p_cod_rubro  IN cb_rubros.cod_moneda%TYPE,
      p_cod_moneda IN OUT cb_rubros.cod_moneda%TYPE,
      p_encontro   IN OUT VARCHAR2
   );

   /* Cabecera Asiento */
  PROCEDURE lp_cab_asiento IS
    v_nro_linea             NUMBER(10);
    v_nro_asiento           NUMBER(10);    
    v_cod_oficina           ba_oficinas.cod_oficina%TYPE;
    v_cod_modalidad         ge_modalidades.cod_modalidad%TYPE;
    v_cod_modulo            ba_modulos.cod_modulo%TYPE;
    v_fec_valor             DATE;
    wk_imtotct              NUMBER;
    v_tot_debito            NUMBER;
    v_tot_credito           NUMBER;
    v_asi_redondear         VARCHAR2(1)  := fug_obt_pardinamico('ASI_REDONDEAR');
    v_asi_mto_redondeo      NUMBER       := fug_obt_pardinamico('ASI_MTO_REDONDEO');
    v_asi_rub_red_gan       VARCHAR2(15) := fug_obt_pardinamico('ASI_RUB_RED_GAN');
    v_asi_rub_red_per       VARCHAR2(15) := fug_obt_pardinamico('ASI_RUB_RED_PER');
    
    v_msj                   VARCHAR2(1000);
    r_baade                 cb_asi_automaticos_det_tmp%ROWTYPE;

    -- 1. DEFINICIÓN DE TIPOS PARA BULK COLLECT
    TYPE t_lectura_rec IS RECORD (
        registro_rowid  ROWID,
        mto_mon_local   NUMBER,
        tip_movimiento  VARCHAR2(1)
    );
    TYPE t_lectura_tab IS TABLE OF t_lectura_rec;
    v_lote_lectura t_lectura_tab;

    -- Colecciones para el UPDATE masivo
    TYPE t_rowid_tab IS TABLE OF ROWID;
    TYPE t_num_tab   IS TABLE OF NUMBER;
    
    v_upd_rowids    t_rowid_tab;
    v_upd_asientos  t_num_tab;
    v_upd_lineas    t_num_tab;

    -- Cursor de Grupos
    CURSOR cur_grupos IS
        SELECT DISTINCT cod_modulo, cod_modalidad, cod_oficina, nvl(fec_valor, fecha) fec_valor
          FROM cb_asi_automaticos_det_tmp
         WHERE fecha = v_fec_actual;

    -- Cursor de Detalle 
    CURSOR cur_detalles (p_mod NUMBER, p_modal NUMBER, p_ofi NUMBER, p_fecval DATE) IS
        SELECT rowid, mto_mon_local, tip_movimiento
          FROM cb_asi_automaticos_det_tmp
         WHERE cod_modulo = p_mod
           AND cod_modalidad = p_modal
           AND cod_oficina = p_ofi
           AND fecha = v_fec_actual
           AND (fec_valor = p_fecval OR fec_valor IS NULL)
         ORDER BY rowid;

BEGIN
    -- Actualizar estadísticas
    BEGIN
        dbms_stats.gather_table_stats('IT','CB_ASI_AUTOMATICOS_DET_TMP');
    EXCEPTION WHEN OTHERS THEN NULL; END;

    v_msj := 'Generando cabecera de asientos';
    v_nro_asiento := to_number(fug_obt_pardinamico('SIG_NRO_ASI_AUTOM_TMP'));

    -- Bucle principal por Grupo
    FOR r_grupo IN cur_grupos LOOP
        
        v_cod_modulo    := r_grupo.cod_modulo;
        v_cod_modalidad := r_grupo.cod_modalidad;
        v_cod_oficina   := r_grupo.cod_oficina;
        v_fec_valor     := r_grupo.fec_valor;
        
        v_msj := 'Generando cabecera asiento ' || to_char(v_cod_oficina) || '-' || to_char(v_nro_asiento);
        
        -- Reiniciar acumuladores
        v_nro_linea   := 0;
        wk_imtotct    := 0;
        v_tot_debito  := 0;
        v_tot_credito := 0;

        -- Limpiar colecciones
        v_upd_rowids   := t_rowid_tab();
        v_upd_asientos := t_num_tab();
        v_upd_lineas   := t_num_tab();

        -- 1. BULK COLLECT: Traer datos a memoria
        OPEN cur_detalles(v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_fec_valor);
        FETCH cur_detalles BULK COLLECT INTO v_lote_lectura;
        CLOSE cur_detalles;

        -- 2. PROCESAMIENTO EN MEMORIA
        IF v_lote_lectura.COUNT > 0 THEN
            v_upd_rowids.EXTEND(v_lote_lectura.COUNT);
            v_upd_asientos.EXTEND(v_lote_lectura.COUNT);
            v_upd_lineas.EXTEND(v_lote_lectura.COUNT);

            FOR i IN 1 .. v_lote_lectura.COUNT LOOP
                v_nro_linea := v_nro_linea + 1;
                
                -- Acumular Totales
                wk_imtotct := wk_imtotct + nvl(v_lote_lectura(i).mto_mon_local, 0);
                
                IF v_lote_lectura(i).tip_movimiento = 'D' THEN
                    v_tot_debito := v_tot_debito + nvl(v_lote_lectura(i).mto_mon_local, 0);
                ELSE
                    v_tot_credito := v_tot_credito + nvl(v_lote_lectura(i).mto_mon_local, 0);
                END IF;

                -- Preparar datos para el UPDATE masivo
                v_upd_rowids(i)   := v_lote_lectura(i).registro_rowid;
                v_upd_asientos(i) := v_nro_asiento;
                v_upd_lineas(i)   := v_nro_linea;
            END LOOP;

            -- 3. UPDATE MASIVO (FORALL)
            FORALL i IN 1 .. v_lote_lectura.COUNT
                UPDATE cb_asi_automaticos_det_tmp
                   SET nro_asiento = v_upd_asientos(i),
                       nro_linea   = v_upd_lineas(i)
                 WHERE ROWID       = v_upd_rowids(i);
        END IF;

        -- 4. Lógica de Redondeo
        IF v_tot_debito <> v_tot_credito THEN
            IF v_asi_redondear = 'S' AND abs(v_tot_credito - v_tot_debito) <= v_asi_mto_redondeo THEN
                
                v_nro_linea := v_nro_linea + 1;
                
                r_baade.fecha           := v_fec_actual;
                r_baade.cod_oficina     := v_cod_oficina;
                r_baade.nro_asiento     := v_nro_asiento;
                r_baade.nro_linea       := v_nro_linea;
                r_baade.mto_mon_rubro   := 0;
                r_baade.mto_mon_local   := abs(v_tot_credito - v_tot_debito);
                r_baade.descripcion     := 'DIFERENCIA DE CAMBIO';
                r_baade.protegido       := 'N';
                r_baade.actualizado     := 'N';
                r_baade.distribuido     := 'N';
                r_baade.cod_modulo      := v_cod_modulo;
                r_baade.cod_modalidad   := v_cod_modalidad;
                r_baade.cod_ofi_origen  := v_cod_oficina;
                r_baade.fec_valor       := v_fec_valor;
                
                IF v_tot_debito > v_tot_credito THEN
                    r_baade.tip_movimiento := 'C';
                    r_baade.cod_rubro      := v_asi_rub_red_gan;
                ELSE
                    r_baade.tip_movimiento := 'D';
                    r_baade.cod_rubro      := v_asi_rub_red_per;
                END IF;

                lp_ins_asi_aut_det(r_baade);
                wk_imtotct := wk_imtotct + abs(v_tot_credito - v_tot_debito);
            END IF;
        END IF;

        -- 5. Insertar Cabecera
        INSERT INTO cb_asi_automaticos_tmp
            (cod_oficina, nro_asiento, cod_usuario, fecha, cod_modulo, cod_modalidad, tot_control,
             actualizado, reversado, cod_ofi_origen, ofi_integrada, confirmado, fec_valor)
        VALUES
            (nvl(v_cod_oficina, 0), v_nro_asiento, USER, v_fec_actual, v_cod_modulo, v_cod_modalidad, 
             wk_imtotct, 'N', 'N', v_cod_oficina, 'N', 'S', v_fec_valor);

        v_nro_asiento := v_nro_asiento + 1;

    END LOOP;

    prg_act_par_dinamico('SIG_NRO_ASI_AUTOM_TMP', NULL, NULL, NULL, NULL, v_nro_asiento);
    
    BEGIN
        dbms_stats.gather_table_stats('IT','CB_ASI_AUTOMATICOS_TMP');
    EXCEPTION WHEN OTHERS THEN NULL; END;

EXCEPTION
    WHEN OTHERS THEN
        raise_application_error(-20000, v_msj || ' ' || SQLERRM);
END lp_cab_asiento;

   /* Procedimiento Equivalente Moneda Local */
   PROCEDURE lp_equ_mon_local IS

      v_mto_cotizacion ge_cotizaciones.val_conversion%TYPE;
      v_cod_moneda     ba_monedas.cod_moneda%TYPE;
      v_cod_modulo     ba_modulos.cod_modulo%TYPE;
      v_cod_modalidad  ge_modalidades.cod_modalidad%TYPE;
      v_redondeo       NUMBER(5);
      v_msj            VARCHAR2(200);
      CURSOR c_movimientos IS
         SELECT DISTINCT cod_moneda, cod_modulo, cod_modalidad
           FROM ge_movimientos
          WHERE cod_rubro IS NOT NULL
            AND cod_moneda <> v_cod_mon_local
               --and usu_insercion <> 'IT' -- para evitar interface
            AND mto_equ_local IS NULL;
   BEGIN
      v_msj := ' Equivalente en moneda local ';

      OPEN c_movimientos;
      LOOP
         FETCH c_movimientos
            INTO v_cod_moneda, v_cod_modulo, v_cod_modalidad;
         EXIT WHEN c_movimientos%NOTFOUND;
         v_msj := ' MONEDA : ' || v_cod_moneda;

         ---------------------------------------------------------
         -----      LEER COTIZACION
         ---------------------------------------------------------
         v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
         ----------------------------------------------------------
         -------- ACTUALIZA ge_movimientos CON EL IMPORTE EQUIVALENTE GS.
         ----------------------------------------------------------
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad,
                                           v_cod_mon_local);
         UPDATE ge_movimientos
            SET mto_equ_local = round(nvl(monto, 0) * v_mto_cotizacion, v_redondeo)
          WHERE cod_moneda = v_cod_moneda
            AND mto_equ_local IS NULL;
      END LOOP;
      IF c_movimientos%ISOPEN THEN
         CLOSE c_movimientos;
      END IF;
   END;
   /* Estadistico */
    PROCEDURE lp_estadistico IS
        c_limit CONSTANT PLS_INTEGER := 65000;
        v_cod_mon_local      varchar2(50) := pag_gen.FU_OBT_MON_LOCAL;
        v_redondeo           NUMBER(5);
        v_mto_cotizacion     NUMBER;
        v_msj                VARCHAR2(250);
        vh_cod_oficina    ge_con_transacciones.cod_oficina%TYPE;
        v_nro_linea          NUMBER;
        v_sigue              CHAR(1);
        v_encontro           CHAR(1);
        wk_lgofici           CHAR(1);
        v_tip_movimiento     ge_tip_asientos.tip_movimiento%TYPE;
        x_tip_movimiento     ge_tip_asientos.tip_movimiento%TYPE;
        ww_nrcuent           CHAR(15);
        vh_cod_rubro         cb_rubros.cod_rubro%TYPE;
        v_cod_mon_rubro      cb_rubros.cod_moneda%TYPE;
        xx_immovml           NUMBER(18, 2);
        xx_immovex           NUMBER(18, 2);
        xx_vltasci           NUMBER(16, 2);
        wh_immovml           NUMBER;
        wh_immovex           NUMBER;
        wh_vltasci           NUMBER;
        wh_dcrefer           CHAR(11);
        wh_dcdescr           CHAR(60);    
        v_cont_errores       NUMBER := 0;
        v_max_errores        NUMBER := 10;     
        -- Tipo para el cursor principal
        CURSOR c_transacciones IS
            SELECT ct.cod_moneda, ct.total, t.cod_tip_asiento, t.descripcion,
                   ct.cod_oficina, ct.cod_ofi_origen, ct.cod_modulo, ct.cod_modalidad,
                   ct.cod_transaccion, ct.cod_mod_padre, ct.cod_mad_padre, ct.residente,
                   ct.cod_sector, ct.cod_tip_deudor, ct.cod_plazo, ct.tot_mon_local,
                   ct.est_cuenta, ct.tip_cuenta, ct.tip_interes, ct.tip_renovacion,
                   ct.cat_automatica, ct.nro_referencia, mo.cod_pro_contable,
                   t.cod_tip_asiento2, ct.fecha AS fec_valor, ct.cod_sit_contable,
                   ct.nro_cuenta, ct.concepto, ct.cod_sec_rubro, ct.cod_tra_padre,
                   ct.rowid AS registro_rowid
              FROM ge_con_transacciones ct
              JOIN ge_transacciones t 
                ON ct.cod_modulo = t.cod_modulo 
               AND ct.cod_modalidad = t.cod_modalidad 
               AND ct.cod_transaccion = t.cod_transaccion
              JOIN ge_modalidades mo 
                ON ct.cod_modulo = mo.cod_modulo 
               AND ct.cod_modalidad = mo.cod_modalidad
             WHERE ct.fecha = v_fec_actual
               AND t.tipo IN ('D', 'C')
               AND t.cod_tip_asiento IS NOT NULL
               AND t.batch = 'B'
               AND t.cod_modulo = mo.cod_modulo
               AND t.cod_modalidad = mo.cod_modalidad
               AND NOT EXISTS (SELECT 1
                                 FROM ge_par_dinamicos x
                                WHERE x.parametro = 'REG_EXC_GEN_ASIENTOS'
                                  AND INSTR(x.val_parametro, ',' || ct.rowid || ',') > 0);

        TYPE t_trans_tab IS TABLE OF c_transacciones%ROWTYPE;
        v_trans_batch t_trans_tab;

        -- Cursor Secundario
        CURSOR c_tip_asientos (p_cod_tip_asiento NUMBER, p_cod_tip_asiento2 NUMBER, 
                               p_cod_moneda VARCHAR2, p_cod_sector VARCHAR2, 
                               p_residente VARCHAR2, p_est_cuenta VARCHAR2, 
                               p_tip_cuenta VARCHAR2, p_tip_interes VARCHAR2, 
                               p_tip_renovacion VARCHAR2, p_cat_automatica NUMBER, 
                               p_cod_sit_contable NUMBER) IS
            SELECT *
              FROM ge_tip_asientos
             WHERE cod_tip_asiento IN (p_cod_tip_asiento, p_cod_tip_asiento2)
               AND cod_moneda = p_cod_moneda
               AND (cod_sec_contable = p_cod_sector OR cod_sec_contable IS NULL)
               AND (ind_residente = p_residente OR ind_residente = 'X')
               AND (est_cuenta = p_est_cuenta OR NVL(est_cuenta, 'X') = 'X')
               AND ((NVL(p_tip_cuenta, 'N') <> 'B' AND (tip_cuenta IS NULL OR tip_cuenta = p_tip_cuenta)) OR
                    (NVL(p_tip_cuenta, 'N') = 'B' AND tip_cuenta = p_tip_cuenta))
               AND (tip_interes = p_tip_interes OR NVL(tip_interes, 'X') = 'X')
               AND (tip_renovacion = p_tip_renovacion OR NVL(tip_renovacion, 'X') = 'X')
               AND (cat_automatica = p_cat_automatica OR NVL(cat_automatica, -1) = -1)
               AND (cod_sit_contable IS NULL OR cod_sit_contable = p_cod_sit_contable)
             ORDER BY nro_linea;

        -- Colección para acumular los detalles a insertar (Bulk Insert)
        TYPE t_detalles_tab IS TABLE OF CB_ASI_AUTOMATICOS_DET_TMP%ROWTYPE; 
        v_detalles_batch t_detalles_tab := t_detalles_tab();
        
        rec_detalle CB_ASI_AUTOMATICOS_DET_TMP%ROWTYPE;

    BEGIN
        -- Obtener redondeo una sola vez al inicio
        v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', null, null, v_cod_mon_local);
        v_msj := '--- Estadistico ---';

        pag_cie.PR_SET_PARAMETROS(11, 370, 'PRA_GEN_ASI_AUTOMATICOS', null, pag_cie.c_log_TRACE);
        OPEN c_transacciones;
        LOOP
            -- 1. Recuperar lote de transacciones en memoria
            FETCH c_transacciones BULK COLLECT INTO v_trans_batch LIMIT c_limit;
            EXIT WHEN v_trans_batch.COUNT = 0;

            -- 2. Iterar sobre el lote en memoria
            FOR i IN 1 .. v_trans_batch.COUNT LOOP
                
                -- Cálculos de moneda (Lógica original)
                IF v_trans_batch(i).cod_moneda = v_cod_mon_local THEN
                    xx_immovml := round(v_trans_batch(i).total, v_redondeo);
                    xx_immovex := 0;
                    xx_vltasci := 0;
                ELSE
                    IF v_trans_batch(i).tot_mon_local IS NULL THEN
                        v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_trans_batch(i).cod_moneda, v_fec_actual);
                        xx_immovml := round(v_trans_batch(i).total * v_mto_cotizacion, v_redondeo);
                        xx_vltasci := v_mto_cotizacion;
                    ELSE
                        xx_immovml := v_trans_batch(i).tot_mon_local;
                        xx_vltasci := NULL;
                    END IF;
                    xx_immovex := v_trans_batch(i).total;
                END IF;

                -- Lógica Interoficina
                wk_lgofici := 'N';
                IF v_trans_batch(i).cod_oficina <> v_trans_batch(i).cod_ofi_origen THEN
                    wk_lgofici := 'S';
                END IF;

                v_nro_linea := 0;
                v_sigue := 'N';

                -- 3. Iterar sobre Tipos de Asientos (Cursor Secundario)
                FOR r_tp IN c_tip_asientos(
                    v_trans_batch(i).cod_tip_asiento, v_trans_batch(i).cod_tip_asiento2,
                    v_trans_batch(i).cod_moneda, v_trans_batch(i).cod_sector,
                    v_trans_batch(i).residente, v_trans_batch(i).est_cuenta,
                    v_trans_batch(i).tip_cuenta, v_trans_batch(i).tip_interes,
                    v_trans_batch(i).tip_renovacion, v_trans_batch(i).cat_automatica,
                    v_trans_batch(i).cod_sit_contable
                ) LOOP
                    
                    -- Lógica de control de flujo (Interoficina)
                    IF v_sigue = 'S' THEN
                        IF (v_tip_movimiento <> r_tp.tip_movimiento AND r_tp.nro_linea = 1 AND xx_immovml > 0) OR 
                           (v_tip_movimiento = r_tp.tip_movimiento AND r_tp.nro_linea = 1 AND xx_immovml <= 0) THEN
                            v_sigue := 'N';
                        END IF;
                    ELSE
                        IF wk_lgofici = 'S' AND r_tp.nro_linea = 1 THEN
                            v_tip_movimiento := r_tp.tip_movimiento;
                            x_tip_movimiento := r_tp.tip_movimiento;
                            v_sigue := 'S';
                        END IF;
                    END IF;

                    -- Construcción del número de cuenta (Rubro)
                    IF r_tp.ind_deudor = 'S' THEN
                        ww_nrcuent := substr(r_tp.cod_rubro, 1, 8) || ltrim(to_char(v_trans_batch(i).cod_tip_deudor, '00')) || substr(r_tp.cod_rubro, 11, 5);
                    ELSE
                        ww_nrcuent := r_tp.cod_rubro;
                    END IF;

                    IF r_tp.ind_plazo = 'S' THEN
                        ww_nrcuent := substr(ww_nrcuent, 1, 2) || ltrim(to_char(v_trans_batch(i).cod_plazo)) || substr(ww_nrcuent, 4, 12);
                    END IF;

                    IF r_tp.ind_producto = 'S' THEN
                        ww_nrcuent := substr(ww_nrcuent, 1, 10) || ltrim(to_char(v_trans_batch(i).cod_pro_contable, '000')) || substr(r_tp.cod_rubro, 14, 2);
                    END IF;

                    IF substr(r_tp.cod_rubro, 11, 3) = 'SEC' THEN
                        ww_nrcuent := substr(ww_nrcuent, 1, 10) || ltrim(to_char(v_trans_batch(i).cod_sec_rubro, '000')) || substr(r_tp.cod_rubro, 14, 2);
                    END IF;

                    -- Validar Rubro y Moneda
                    v_encontro := 'S';
                    lp_obt_mon_rubro(ww_nrcuent, v_cod_mon_rubro, v_encontro);

                    IF v_encontro = 'N' THEN
                         -- Logica de error o default
                         IF substr(ww_nrcuent, 14, 2) IN ('99', '98') THEN
                            v_cod_mon_rubro := v_cod_mon_local;
                         END IF;
                    END IF;

                    -- Asignación de montos según moneda del rubro
                    IF v_cod_mon_rubro = v_cod_mon_local THEN
                        wh_immovex := 0;
                        wh_vltasci := 0;
                    ELSE
                        wh_immovex := xx_immovex;
                        wh_vltasci := xx_vltasci;
                    END IF;

                    vh_cod_rubro := ww_nrcuent;
                    
                    -- Asignación oficina
                    IF r_tp.nro_linea = 1 THEN
                        rec_detalle.cod_oficina := v_trans_batch(i).cod_oficina; -- vh_cod_oficina
                    ELSE
                        rec_detalle.cod_oficina := v_trans_batch(i).cod_ofi_origen;
                    END IF;

                    -- Lógica de signo y movimiento
                    IF xx_immovml > 0 THEN
                        wh_immovml := xx_immovml;
                        v_tip_movimiento := r_tp.tip_movimiento;
                    ELSE
                        wh_immovml := xx_immovml * -1;
                        wh_immovex := wh_immovex * -1;
                        IF r_tp.tip_movimiento = 'D' THEN v_tip_movimiento := 'C'; ELSE v_tip_movimiento := 'D'; END IF;
                    END IF;

                    -- Descripción
                    wh_dcrefer := NULL;
                    IF v_trans_batch(i).cod_transaccion BETWEEN 150 AND 171 THEN
                        wh_dcrefer := 'VALUAC';
                    END IF;

                    IF substr(v_trans_batch(i).concepto, 1, 1) = '/' THEN
                        wh_dcdescr := substr(v_trans_batch(i).concepto, 1, 60);
                    ELSIF v_trans_batch(i).nro_cuenta IS NOT NULL THEN
                        wh_dcdescr := substr('Cli:' || fug_obt_cli_principal(v_trans_batch(i).nro_cuenta) || ' Cta:' || v_trans_batch(i).nro_cuenta || ' ' || v_trans_batch(i).concepto, 1, 60);
                    ELSIF v_trans_batch(i).concepto IS NOT NULL THEN
                        wh_dcdescr := substr(v_trans_batch(i).concepto, 1, 60);
                    ELSE
                        wh_dcdescr := substr(to_char(v_trans_batch(i).cod_modulo) || ' ' || to_char(v_trans_batch(i).cod_modalidad) || ' ' || to_char(v_trans_batch(i).cod_transaccion) || ' ' || v_trans_batch(i).descripcion, 1, 60);
                    END IF;

                    -- 4. Acumulación para inserción
                    IF wh_immovml <> 0 THEN
                        v_nro_linea := v_nro_linea + 1;

                        -- Llenar el registro temporal
                        rec_detalle.fecha           := v_fec_actual;
                        rec_detalle.nro_asiento     := 0;
                        rec_detalle.nro_linea       := v_nro_linea;
                        rec_detalle.cod_rubro       := vh_cod_rubro;
                        rec_detalle.tip_movimiento  := v_tip_movimiento;
                        rec_detalle.mto_mon_rubro   := wh_immovex;
                        rec_detalle.mto_mon_local   := wh_immovml;
                        rec_detalle.descripcion     := wh_dcdescr;
                        rec_detalle.referencia      := wh_dcrefer;
                        rec_detalle.protegido       := 'N';
                        rec_detalle.actualizado     := 'N';
                        rec_detalle.val_cotizacion  := wh_vltasci;
                        rec_detalle.distribuido     := 'N';
                        rec_detalle.ref_movimiento  := v_trans_batch(i).nro_referencia;
                        rec_detalle.cod_modulo      := v_trans_batch(i).cod_mod_padre;
                        rec_detalle.cod_modalidad   := v_trans_batch(i).cod_mad_padre;
                        rec_detalle.cod_ofi_origen  := v_trans_batch(i).cod_ofi_origen;
                        rec_detalle.cod_tra_padre   := v_trans_batch(i).cod_tra_padre;
                        rec_detalle.fec_valor       := v_trans_batch(i).fec_valor;
                        rec_detalle.usu_insercion   := SUBSTR(USER,1,10);
                        rec_detalle.fec_insercion   := sysdate;
                        rec_detalle.usu_modificacion:= SUBSTR(USER,1,10);
                        rec_detalle.fec_modificacion:= sysdate;
                        

                        -- Agregar a la colección
                        v_detalles_batch.EXTEND;
                        v_detalles_batch(v_detalles_batch.LAST) := rec_detalle;
                    END IF;
                END LOOP; 

              IF wk_lgofici = 'S' AND v_sigue = 'S' THEN
                -- Tomo el tipo de movimiento de la linea 1
                v_tip_movimiento := x_tip_movimiento;

                -- Recuperar cuenta contable interoficina (usando datos del lote actual)
                vh_cod_rubro := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL, 
                                                    v_trans_batch(i).cod_moneda, 
                                                    v_trans_batch(i).cod_oficina);
                
                vh_cod_oficina := v_trans_batch(i).cod_oficina; 
                
                -- Construcción del Rubro Interoficina usando la Oficina Origen
                vh_cod_rubro := substr(vh_cod_rubro, 1, 10) || 
                                ltrim(to_char(v_trans_batch(i).cod_ofi_origen, '000')) || 
                                substr(vh_cod_rubro, 14, 2);

                -- Verificar moneda de la cuenta interoficina
                v_encontro := 'S';
                lp_obt_mon_rubro(vh_cod_rubro, v_cod_mon_rubro, v_encontro);
                
                IF v_encontro = 'N' THEN
                    -- Lógica de fallback si no encuentra el rubro
                    IF substr(vh_cod_rubro, 14, 2) IN ('99', '98') THEN
                        v_cod_mon_rubro := v_cod_mon_local;
                    END IF;
                END IF;

                -- Calcular montos según la moneda del rubro interoficina
                IF v_cod_mon_rubro = v_cod_mon_local THEN
                    wh_immovex := 0;
                    wh_vltasci := 0;
                ELSE
                    wh_immovex := xx_immovex;
                    wh_vltasci := xx_vltasci;
                END IF;

                -- Invertir el tipo de movimiento (Débito <-> Crédito) para Interoficina
                IF v_tip_movimiento = 'D' THEN
                    v_tip_movimiento := 'C';
                ELSE
                    v_tip_movimiento := 'D';
                END IF;

                -- Ajustar descripción
                wh_dcdescr := substr(TRIM(wh_dcdescr) || '(Inter of)', 1, 60);
                -- Lógica de montos negativos
                IF xx_immovml > 0 THEN
                    wh_immovml := xx_immovml;
                ELSE
                    wh_immovml := xx_immovml * -1;
                    wh_immovex := wh_immovex * -1;                
                    -- Si era negativo, volvemos a invertir el movimiento
                    IF v_tip_movimiento = 'D' THEN
                        v_tip_movimiento := 'C';
                    ELSE
                        v_tip_movimiento := 'D';
                    END IF;
                END IF;

                -- Agregar a la colección de inserción masiva
                IF wh_immovml <> 0 THEN
                    v_nro_linea := v_nro_linea + 1;

                    rec_detalle.fecha           := v_fec_actual;
                    rec_detalle.cod_oficina     := vh_cod_oficina;
                    rec_detalle.nro_asiento     := 0;
                    rec_detalle.nro_linea       := v_nro_linea;
                    rec_detalle.cod_rubro       := vh_cod_rubro;
                    rec_detalle.tip_movimiento  := v_tip_movimiento;
                    rec_detalle.mto_mon_rubro   := wh_immovex;
                    rec_detalle.mto_mon_local   := wh_immovml;
                    rec_detalle.descripcion     := wh_dcdescr;
                    rec_detalle.referencia      := wh_dcrefer;
                    rec_detalle.protegido       := 'N';
                    rec_detalle.actualizado     := 'N';
                    rec_detalle.val_cotizacion  := wh_vltasci;
                    rec_detalle.distribuido     := 'N';
                    rec_detalle.ref_movimiento  := v_trans_batch(i).nro_referencia;
                    rec_detalle.cod_modulo      := v_trans_batch(i).cod_mod_padre;
                    rec_detalle.cod_modalidad   := v_trans_batch(i).cod_mad_padre;
                    rec_detalle.cod_ofi_origen  := v_trans_batch(i).cod_ofi_origen;
                    rec_detalle.cod_tra_padre   := v_trans_batch(i).cod_tra_padre;
                    rec_detalle.fec_valor       := v_trans_batch(i).fec_valor;
                    rec_detalle.usu_insercion   := SUBSTR(USER,1,10);
                    rec_detalle.fec_insercion   := sysdate;
                    rec_detalle.usu_modificacion:= SUBSTR(USER,1,10);
                    rec_detalle.fec_modificacion:= sysdate;

                    -- EXTEND y asignar a la colección
                    v_detalles_batch.EXTEND;
                    v_detalles_batch(v_detalles_batch.LAST) := rec_detalle;
                END IF;
                -- Recuperar cuenta contable interoficina
                vh_cod_rubro   := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL, v_trans_batch(i).cod_moneda,
                                                      v_trans_batch(i).cod_oficina);
                vh_cod_oficina :=v_trans_batch(i).cod_ofi_origen; -- oficina origen
                vh_cod_rubro   := substr(vh_cod_rubro, 1, 10) || ltrim(to_char(v_trans_batch(i).cod_oficina, '000')) ||
                                  substr(vh_cod_rubro, 14, 2);

                --- ve moneda de la cuenta --
                v_encontro := 'S';
                lp_obt_mon_rubro(vh_cod_rubro, v_trans_batch(i).cod_moneda, v_encontro);
                IF v_encontro = 'N' THEN
                   v_msj := 'RUBRO INEXISTENTE EN PLAN DE CUENTAS ' || vh_cod_rubro;
                   IF substr(vh_cod_rubro, 14, 2) IN ('99', '98') THEN
                      v_cod_mon_rubro := v_cod_mon_local;
                   END IF;
                   --vh_cod_rubro := '999999999999999';
                   --v_cod_mon_rubro := v_cod_mon_local;
                END IF;
                IF v_cod_mon_rubro = v_cod_mon_local THEN
                   -- moneda local
                   wh_immovex := 0;
                   wh_vltasci := 0;
                ELSE
                   wh_immovex := xx_immovex;
                   wh_vltasci := xx_vltasci;
                END IF;
                v_tip_movimiento := x_tip_movimiento;
                IF xx_immovml > 0 THEN
                   wh_immovml := xx_immovml;
                ELSE
                   wh_immovml := xx_immovml * -1;
                   wh_immovex := wh_immovex * -1;
                   IF v_tip_movimiento = 'D' THEN
                      v_tip_movimiento := 'C';
                   ELSE
                      v_tip_movimiento := 'D';
                   END IF;
                END IF;
                /*         wh_dcdescr := substr(to_char(v_cod_modulo) || ' ' ||
                to_char(v_cod_modalidad) || ' ' ||
                to_char(v_cod_transaccion) || ' ' ||
                '(Inter of)'        || ' ' ||
                v_des_transaccion,1,60);*/
                IF v_encontro = 'N' THEN
                   wh_dcdescr := 'RUBRO INEXISTENTE ' || vh_cod_rubro;
                   --vh_cod_rubro := '999999999999999';
                END IF;
                IF wh_immovml <> 0 THEN
                   v_nro_linea := v_nro_linea + 1;
                   --- Cargar registro de asientos detalles
                   r_baade.fecha           := v_fec_actual;
                   r_baade.cod_oficina     := vh_cod_oficina;
                   r_baade.nro_asiento     := 0;
                   r_baade.nro_linea       := v_nro_linea;
                   r_baade.cod_rubro       := vh_cod_rubro;
                   r_baade.tip_movimiento  := v_tip_movimiento;
                   r_baade.mto_mon_rubro   := wh_immovex;
                   r_baade.mto_mon_local   := wh_immovml;
                   r_baade.descripcion     := wh_dcdescr;
                   r_baade.referencia      := wh_dcrefer;
                   r_baade.protegido       := 'N';
                   r_baade.actualizado     := 'N';
                   r_baade.val_cotizacion  := wh_vltasci;
                   r_baade.distribuido     := 'N'; 
                   r_baade.ref_movimiento  := v_trans_batch(i).nro_referencia;
                   r_baade.cod_modulo      := v_trans_batch(i).cod_mod_padre;
                   r_baade.cod_modalidad   := v_trans_batch(i).cod_mad_padre;
                   r_baade.cod_ofi_origen  := v_trans_batch(i).cod_ofi_origen;
                   r_baade.cod_tra_padre   := v_trans_batch(i).cod_tra_padre;
                   r_baade.fec_valor       := v_trans_batch(i).fec_valor;
                   r_baade.usu_insercion   := SUBSTR(USER,1,10);
                   r_baade.fec_insercion   := sysdate;
                   r_baade.usu_modificacion:= SUBSTR(USER,1,10);
                   r_baade.fec_modificacion:= sysdate;

                   -- EXTEND y asignar a la colección
                   v_detalles_batch.EXTEND;
                   v_detalles_batch(v_detalles_batch.LAST) := r_baade;
                END IF;
            END IF;
         
            END LOOP;
            ---------------- FIN INTEROFICINA -----------------
            -- 6. INSERCIÓN MASIVA (Bulk Insert)
        BEGIN
            FORALL j IN 1 .. v_detalles_batch.COUNT SAVE EXCEPTIONS
                INSERT INTO CB_ASI_AUTOMATICOS_DET_TMP VALUES v_detalles_batch(j);

        EXCEPTION
            WHEN OTHERS THEN
             FOR idx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
                    v_cont_errores := v_cont_errores + 1;
                DECLARE
                    v_indice    NUMBER := SQL%BULK_EXCEPTIONS(idx).ERROR_INDEX;
                    -- Referencia al registro fallido en la memoria --
                    r_fallido   CB_ASI_AUTOMATICOS_DET_TMP%ROWTYPE := v_detalles_batch(v_indice);
                    v_msj  VARCHAR2(4000);
                BEGIN
                    -- Mensaje con todos los datos posibles del registro --
                    v_msj := 'Error Masivo Detallado | ' ||
                                  'Rubro: '      || r_fallido.cod_rubro || ' | ' ||
                                  'Oficina: '    || r_fallido.cod_oficina || ' | ' ||
                                  'Tipo Mov: '   || r_fallido.tip_movimiento || ' | ' ||
                                  'Monto: '      || r_fallido.mto_mon_local || ' | ' ||
                                  'Referencia: ' || r_fallido.referencia || ' | ' ||
                                  'Desc: '       || r_fallido.descripcion || ' | ' ||
                                  'Motivo: '     || SQLERRM(-SQL%BULK_EXCEPTIONS(idx).ERROR_CODE);

                    -- Logueo detallado
                    pag_cie.pr_ins_log(
                        v_msj,
                        pag_cie.c_log_INFO,
                        'AUTONOMOUS_TRANSACTION'
                    );
                END;
             END LOOP;

                -- Control de cantidad maxima de errores
                IF v_cont_errores > v_max_errores THEN
                    RAISE_APPLICATION_ERROR(-20000, 'Abortado: Se alcanzó el límite de '||v_max_errores||' errores.');
                END IF;
        END;
                
            -- Limpiar colección para el siguiente lote
            v_detalles_batch.DELETE;

        END LOOP;
        CLOSE c_transacciones;

        -- Limpiar parámetro dinámico si existe
        DELETE FROM ge_par_dinamicos WHERE parametro = 'REG_EXC_GEN_ASIENTOS';
                                
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20002, 'Error en proceso masivo: ' || SQLERRM);
    END lp_estadistico;
   /* Movimientos Diarios */
PROCEDURE lp_mov_diarios IS
    c_limit CONSTANT PLS_INTEGER := 100000;

    -- Cursor Original tal cual (solo agregando rowid para el update)
    CURSOR c_movimientos IS
        SELECT cod_modulo, cod_modalidad, cod_oficina, cod_rubro, fecha,
               tip_mov_rubro, nvl(monto, 0) as monto, nvl(mto_equ_local, 0) as mto_equ_local,
               cod_ofi_origen, cod_mod_padre, cod_mad_padre, substr(concepto, 1, 35) as concepto,
               cod_usuario, cod_ref_cambio, nro_documento2, nro_documento3, nro_documento4,
               hora, nro_secuencia, ROWID as registro_rowid, cotizacion, cod_tra_padre,
               fecha as fec_valor, referencia, nro_documento
          FROM ge_movimientos
         WHERE cod_rubro IS NOT NULL
           AND estado IN ('N', 'H')
         ORDER BY cod_modulo, cod_modalidad, cod_oficina, cod_rubro, tip_mov_rubro,
                  cod_ofi_origen, cod_mod_padre, cod_mad_padre;

    TYPE t_mov_tab IS TABLE OF c_movimientos%ROWTYPE;
    v_mov_batch t_mov_tab;

    -- Colecciones para Insert Masivo (Asumiendo estructura cb_asi_automaticos_det_tmp)
    TYPE t_detalles_tab IS TABLE OF cb_asi_automaticos_det_tmp%ROWTYPE;
    v_detalles_batch t_detalles_tab := t_detalles_tab();
    rec_detalle cb_asi_automaticos_det_tmp%ROWTYPE;

    -- Colecciones para Update Masivo (GE_MOVIMIENTOS)
    TYPE t_rowid_tab IS TABLE OF ROWID;
    TYPE t_num_tab IS TABLE OF NUMBER;
    v_upd_rowids t_rowid_tab := t_rowid_tab();
    v_upd_values t_num_tab := t_num_tab();

    v_cod_mon_local      VARCHAR2(50) := pag_gen.FU_OBT_MON_LOCAL;
    v_msj                VARCHAR2(250);
    v_encontro           CHAR(1) := 'N';
    v_nro_linea          NUMBER := 0;
    wk_sgnrref           NUMBER(10);
    wk_lgofici           CHAR(1);
    
    v_cod_mon_rubro      cb_rubros.cod_moneda%TYPE;
    vh_tip_mov_rubro     ge_movimientos.tip_mov_rubro%TYPE;
    vh_cod_rubro         cb_rubros.cod_rubro%TYPE;
    wk_cdctaco           cb_rubros.cod_rubro%TYPE;
    vh_cod_oficina       ge_movimientos.cod_oficina%TYPE;
    
    xx_immovml           NUMBER;
    xx_immovex           NUMBER;
    xx_vltasci           NUMBER;
    wh_immovml           NUMBER;
    wh_immovex           NUMBER;
    wh_vltasci           NUMBER;
    
    wh_dcrefer           CHAR(11);
    wh_dcdescr           CHAR(60);
    wh_lgprote           CHAR(1);
    wh_lgdeact           CHAR(1);
    wh_lgctadi           CHAR(1);
    vh_nro_asiento   NUMBER;

BEGIN
    -- Inicialización Original
    wk_sgnrref := to_number(fug_obt_pardinamico('SIG_NRO_REFERENCIA'));
    v_msj := ' Movimientos c_movimientos ';

    IF c_movimientos%ISOPEN THEN CLOSE c_movimientos; END IF;
    OPEN c_movimientos;
    LOOP
        -- 1. Lectura Masiva (BULK COLLECT)
        FETCH c_movimientos BULK COLLECT INTO v_mov_batch LIMIT c_limit;
        EXIT WHEN v_mov_batch.COUNT = 0;

        -- Limpiar buffers de escritura
        v_detalles_batch.DELETE;
        v_upd_rowids.DELETE;
        v_upd_values.DELETE;

        -- 2. Procesamiento en Memoria
        FOR i IN 1 .. v_mov_batch.COUNT LOOP
            
            v_encontro := 'S';
            
            lp_obt_mon_rubro(v_mov_batch(i).cod_rubro, v_cod_mon_rubro, v_encontro);
            
            IF v_encontro = 'N' THEN
                -- vh_cod_rubro := '999999999999';
                v_cod_mon_rubro := v_cod_mon_local;
            END IF;

            IF v_cod_mon_rubro = v_cod_mon_local THEN
                xx_immovml := v_mov_batch(i).monto;
                xx_immovex := 0;
                xx_vltasci := NULL;
                wh_immovml := v_mov_batch(i).monto;
                wh_immovex := 0;
                wh_vltasci := 0;
            ELSE
                xx_immovml := v_mov_batch(i).mto_equ_local;
                xx_immovex := v_mov_batch(i).monto;
                xx_vltasci := v_mov_batch(i).cotizacion;
                wh_immovml := v_mov_batch(i).mto_equ_local;
                wh_immovex := v_mov_batch(i).monto;
                wh_vltasci := v_mov_batch(i).cotizacion;
            END IF;

            wk_lgofici := 'N';
            IF v_mov_batch(i).cod_oficina <> v_mov_batch(i).cod_ofi_origen THEN
                wk_lgofici := 'S';
            END IF;

            IF xx_immovml > 0 THEN
                wh_immovml := xx_immovml;
                vh_tip_mov_rubro := v_mov_batch(i).tip_mov_rubro;
            ELSE
                wh_immovml := xx_immovml * -1;
                wh_immovex := wh_immovex * -1;
                IF v_mov_batch(i).tip_mov_rubro = 'D' THEN
                    vh_tip_mov_rubro := 'C';
                ELSE
                    vh_tip_mov_rubro := 'D';
                END IF;
            END IF;

            vh_cod_oficina := v_mov_batch(i).cod_oficina;
            vh_cod_rubro := v_mov_batch(i).cod_rubro;

            IF v_mov_batch(i).concepto IS NULL THEN
                 wh_dcdescr := substr(fub_obt_referencia(v_mov_batch(i).registro_rowid), 1, 60);
            ELSE
                 wh_dcdescr := substr(nvl(fub_obt_referencia(v_mov_batch(i).registro_rowid), v_mov_batch(i).concepto), 1, 60);
            END IF;

            IF v_mov_batch(i).cod_mod_padre = 7 THEN
                wh_dcrefer := substr(rtrim(v_mov_batch(i).cod_ref_cambio) || '/' || ltrim(to_char(v_mov_batch(i).nro_documento2)), 1, 11);
            ELSE
                wh_dcrefer := v_mov_batch(i).cod_usuario;
            END IF;
            
            ---DYDMR-6535 - Seguro Mapfre
            If vh_cod_rubro in ('240402600206999', '240402600206905') then
                 wh_dcrefer := substr(nvl(v_mov_batch(i).referencia, v_mov_batch(i).nro_documento), 1, 11);
            end if;

            IF v_mov_batch(i).cod_mod_padre IN (7, 9) THEN
                 IF v_mov_batch(i).nro_documento3 IS NOT NULL THEN
                    wh_dcdescr := substr(ltrim(to_char(v_mov_batch(i).nro_documento3, '999999999999999')) || ' ' || wh_dcdescr, 1, 60);
                 ELSE
                    wh_dcdescr := substr(wh_dcdescr, 1, 60);
                 END IF;
            END IF;

            wh_lgprote := 'N';
            wh_lgdeact := 'N';
            wh_lgctadi := 'N';

            -- ACUMULACIÓN DE REGISTRO PRINCIPAL
            IF wh_immovml <> 0 THEN
                v_nro_linea := v_nro_linea + 1;

                -- Llenamos el registro de trabajo
                r_baade.fecha          := v_mov_batch(i).fecha;
                r_baade.cod_oficina    := vh_cod_oficina;
                r_baade.nro_asiento    := 0;
                r_baade.nro_linea      := v_nro_linea;
                r_baade.cod_rubro      := vh_cod_rubro;
                r_baade.tip_movimiento := vh_tip_mov_rubro;
                r_baade.mto_mon_rubro  := wh_immovex;
                r_baade.mto_mon_local  := wh_immovml;
                r_baade.descripcion    := wh_dcdescr;
                r_baade.referencia     := wh_dcrefer;
                r_baade.protegido      := 'N'; -- wh_lgprote
                r_baade.actualizado    := 'N'; -- wh_lgdeact
                r_baade.val_cotizacion := wh_vltasci;
                r_baade.distribuido    := 'N'; -- wh_lgctadi
                r_baade.ref_movimiento := nvl(v_mov_batch(i).nro_documento4, wk_sgnrref);
                r_baade.cod_modulo     := v_mov_batch(i).cod_mod_padre;
                r_baade.cod_modalidad  := v_mov_batch(i).cod_mad_padre;
                r_baade.cod_ofi_origen := v_mov_batch(i).cod_ofi_origen;
                r_baade.cod_tra_padre  := v_mov_batch(i).cod_tra_padre;
                r_baade.fec_valor      := v_mov_batch(i).fec_valor;
                
                -- Auditoría
                r_baade.usu_insercion    := SUBSTR(USER,1,10);
                r_baade.fec_insercion    := sysdate;
                r_baade.usu_modificacion := SUBSTR(USER,1,10);
                r_baade.fec_modificacion := sysdate;

                -- Añadir al lote de inserción
                v_detalles_batch.EXTEND;
                v_detalles_batch(v_detalles_batch.LAST) := r_baade;
            END IF;

            -- LÓGICA INTEROFICINA INTACTA -------------------------------------
            IF wk_lgofici = 'S' THEN
                -- Recuperar cuenta contable interoficina
                wk_cdctaco := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL, v_cod_mon_rubro, v_mov_batch(i).cod_oficina);
                
                vh_cod_oficina := v_mov_batch(i).cod_oficina;
                wk_cdctaco     := substr(wk_cdctaco, 1, 10) || ltrim(to_char(v_mov_batch(i).cod_ofi_origen, '000')) || substr(wk_cdctaco, 14, 2);
                
                vh_nro_asiento := 0;
                vh_cod_rubro   := wk_cdctaco;
                
                v_encontro := 'S';
                -- Llamada original
                lp_obt_mon_rubro(vh_cod_rubro, v_cod_mon_rubro, v_encontro);
                
                IF v_encontro = 'N' THEN
                    v_msj := 'RUBRO INEXISTENTE EN PLAN DE CUENTAS ' || vh_cod_rubro;
                    IF substr(vh_cod_rubro, 14, 2) IN ('99', '98') THEN
                        v_cod_mon_rubro := v_cod_mon_local;
                    END IF;
                END IF;

                IF v_cod_mon_rubro = v_cod_mon_local THEN
                    wh_immovex := 0;
                    wh_vltasci := 0;
                ELSE
                    wh_immovex := xx_immovex;
                    wh_vltasci := xx_vltasci;
                END IF;

                IF v_mov_batch(i).tip_mov_rubro = 'D' THEN
                    vh_tip_mov_rubro := 'C';
                ELSE
                    vh_tip_mov_rubro := 'D';
                END IF;

                wh_dcdescr := substr(TRIM(wh_dcdescr) || '(Inter of)', 1, 60);
                wh_lgprote := 'N';
                wh_lgdeact := 'N';
                wh_lgctadi := 'N';

                IF xx_immovml > 0 THEN
                    wh_immovml := xx_immovml;
                    -- vh_tip_mov_rubro := v_tip_mov_rubro; -- Already set above based on D/C swap
                ELSE
                    wh_immovml := xx_immovml * -1;
                    wh_immovex := wh_immovex * -1;
                    IF vh_tip_mov_rubro = 'D' THEN
                        vh_tip_mov_rubro := 'C';
                    ELSE
                        vh_tip_mov_rubro := 'D';
                    END IF;
                END IF;

                -- ACUMULACIÓN DE REGISTRO INTEROFICINA
                IF wh_immovml <> 0 THEN
                    v_nro_linea := v_nro_linea + 1;
                    --- Cargar registro de asientos detalles
                    rec_detalle.fecha           := v_mov_batch(i).fecha;
                    rec_detalle.cod_oficina     := vh_cod_oficina;
                    rec_detalle.nro_asiento     := 0;
                    rec_detalle.nro_linea       := v_nro_linea;
                    rec_detalle.cod_rubro       := vh_cod_rubro;
                    rec_detalle.tip_movimiento  := vh_tip_mov_rubro;
                    rec_detalle.mto_mon_rubro   := wh_immovex;
                    rec_detalle.mto_mon_local   := wh_immovml;
                    rec_detalle.descripcion     := wh_dcdescr;
                    rec_detalle.referencia      := wh_dcrefer;
                    rec_detalle.protegido       := 'N';
                    rec_detalle.actualizado     := 'N';
                    rec_detalle.val_cotizacion  := wh_vltasci;
                    rec_detalle.distribuido     := 'N';
                    rec_detalle.ref_movimiento  := nvl(v_mov_batch(i).nro_documento4, wk_sgnrref);
                    rec_detalle.cod_modulo      := v_mov_batch(i).cod_mod_padre;
                    rec_detalle.cod_modalidad   := v_mov_batch(i).cod_mad_padre;
                    rec_detalle.cod_ofi_origen  := v_mov_batch(i).cod_ofi_origen;
                    rec_detalle.cod_tra_padre   := v_mov_batch(i).cod_tra_padre;
                    rec_detalle.fec_valor       := v_mov_batch(i).fec_valor;
                    
                    -- Auditoria
                    rec_detalle.usu_insercion   := SUBSTR(USER,1,10);
                    rec_detalle.fec_insercion   := sysdate;
                    rec_detalle.usu_modificacion:= SUBSTR(USER,1,10);
                    rec_detalle.fec_modificacion:= sysdate;
                    
                    v_detalles_batch.EXTEND;
                    v_detalles_batch(v_detalles_batch.LAST) := rec_detalle;
                END IF;
                 -----------------------
              -- Recuperar cuenta contable interoficina para oficina origen
              wk_cdctaco     := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL,
                                                    v_cod_mon_rubro, v_mov_batch(i).cod_ofi_origen);
              vh_cod_oficina := v_mov_batch(i).cod_ofi_origen;
              vh_cod_rubro   := substr(wk_cdctaco, 1, 10) || ltrim(to_char(v_cod_oficina, '000')) ||
                                substr(wk_cdctaco, 14, 2);

              --- ve moneda de la cuenta --
              v_encontro := 'S';
              lp_obt_mon_rubro(vh_cod_rubro, v_cod_mon_rubro, v_encontro);
              IF v_encontro = 'N' THEN
                 v_msj := 'RUBRO INEXISTENTE EN PLAN DE CUENTAS ' || vh_cod_rubro;
                 --vh_cod_rubro := '999999999999';
                 IF substr(vh_cod_rubro, 14, 2) IN ('99', '98') THEN
                    v_cod_mon_rubro := v_cod_mon_local;
                 END IF;
              END IF;
              
              IF v_cod_mon_rubro = v_cod_mon_local THEN
                 -- moneda local
                 wh_immovex := 0;
                 wh_vltasci := 0;
              ELSE
                 wh_immovex := xx_immovex;
                 wh_vltasci := xx_vltasci;
              END IF;
              IF v_encontro = 'N' THEN
                 wh_dcdescr := 'RUBRO INEXISTENTE ' || vh_cod_rubro;
                 --vh_cod_rubro := '999999999999';
              END IF;
              wh_lgprote := 'N';
              wh_lgdeact := 'N';
              IF xx_immovml > 0 THEN
                 wh_immovml       := xx_immovml;
                 vh_tip_mov_rubro := v_mov_batch(i).tip_mov_rubro;
              ELSE
                 wh_immovml := xx_immovml * -1;
                 wh_immovex := wh_immovex * -1;
                 IF v_mov_batch(i).tip_mov_rubro = 'D' THEN
                    vh_tip_mov_rubro := 'C';
                 ELSE
                    vh_tip_mov_rubro := 'D';
                 END IF;
              END IF;
              IF wh_immovml <> 0 THEN
                 BEGIN
                    v_nro_linea := v_nro_linea + 1;
                    --- Cargar registro de asientos detalles
                    r_baade.fecha          := v_mov_batch(i).fecha;
                    r_baade.cod_oficina    := vh_cod_oficina;
                    r_baade.nro_asiento    := 0;
                    r_baade.nro_linea      := v_nro_linea;
                    r_baade.cod_rubro      := vh_cod_rubro;
                    r_baade.tip_movimiento := vh_tip_mov_rubro;
                    r_baade.mto_mon_rubro  := wh_immovex;
                    r_baade.mto_mon_local  := wh_immovml;
                    r_baade.descripcion    := wh_dcdescr;
                    r_baade.referencia     := wh_dcrefer;
                    r_baade.protegido      := 'N';
                    r_baade.actualizado    := wh_lgctadi;
                    r_baade.val_cotizacion := wh_vltasci;
                    r_baade.distribuido    := 'N';
                    r_baade.ref_movimiento := nvl(v_mov_batch(i).nro_documento4, wk_sgnrref);
                    r_baade.cod_modulo     := v_mov_batch(i).cod_mod_padre;
                    r_baade.cod_modalidad  := v_mov_batch(i).cod_mad_padre;
                    r_baade.cod_ofi_origen := v_mov_batch(i).cod_ofi_origen;
                    r_baade.cod_tra_padre  := v_mov_batch(i).cod_tra_padre;
                    r_baade.fec_valor      := v_mov_batch(i).fec_valor;
                    -- Auditoría
                    r_baade.usu_insercion    := SUBSTR(USER,1,10);
                    r_baade.fec_insercion    := sysdate;
                    r_baade.usu_modificacion := SUBSTR(USER,1,10);
                    r_baade.fec_modificacion := sysdate;
                    -- Añadir al lote de inserción
                    v_detalles_batch.EXTEND;
                    v_detalles_batch(v_detalles_batch.LAST) := r_baade;
                 EXCEPTION
                    WHEN OTHERS THEN
                       raise_application_error(-20001,
                                               'Error LP_MOV_DIARIOS, Nro.Linea ' || v_nro_linea || ' ' ||
                                                SQLERRM);
                 END;
              END IF;
            
            END IF;
            --------------------------------------------------------------------
            ---------------- FIN INTEROFICINA ------------------
            -- ACUMULACIÓN PARA UPDATE DE CABECERA
            -- if nvl(v_tra_asientos, 'N') = 'S' then (Si usas esa logica, descomenta)
            IF v_mov_batch(i).nro_documento4 IS NULL THEN
                -- Agregamos a las colecciones de UPDATE
                v_upd_rowids.EXTEND;
                v_upd_rowids(v_upd_rowids.LAST) := v_mov_batch(i).registro_rowid;
                
                v_upd_values.EXTEND;
                v_upd_values(v_upd_values.LAST) := wk_sgnrref;

                wk_sgnrref := nvl(wk_sgnrref, 0) + 1;
            END IF;
            -- end if;

        END LOOP; 

        
        -- A. Insertar Detalles
        IF v_detalles_batch.COUNT > 0 THEN
            FORALL j IN 1 .. v_detalles_batch.COUNT
                INSERT INTO cb_asi_automaticos_det_tmp VALUES v_detalles_batch(j);
        END IF;

        -- B. Actualizar Movimientos
        IF v_upd_rowids.COUNT > 0 THEN
            FORALL j IN 1 .. v_upd_rowids.COUNT
                UPDATE ge_movimientos
                   SET nro_documento4 = v_upd_values(j)
                 WHERE ROWID = v_upd_rowids(j);
        END IF;

        COMMIT;

    END LOOP;
    CLOSE c_movimientos;

    -- Actualización final del parámetro
    prg_act_par_dinamico('SIG_NRO_REFERENCIA', NULL, NULL, NULL, NULL, wk_sgnrref);

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, 'Error LP_MOV_DIARIOS: ' || SQLERRM);
END lp_mov_diarios;
   /* Intereses Devengados */
   PROCEDURE lp_int_devengados IS

      v_cod_mad_padre    ge_modalidades.cod_modalidad%TYPE;
      v_cod_mod_padre    ba_modulos.cod_modulo%TYPE;
      v_tip_movimiento   ge_tip_asientos.tip_movimiento%TYPE;
      v_mon_rubro        cb_rubros.cod_moneda%TYPE;
      v_mto_cotizacion   ge_cotizaciones.val_conversion%TYPE;
      v_des_transaccion  ge_transacciones.descripcion%TYPE;
      v_cod_sec_contable ge_sec_contables.cod_sec_contable%TYPE;
      v_cod_ofi_origen   ba_oficinas.cod_oficina%TYPE;
      v_cod_plazo        ge_plz_contables.cod_plazo%TYPE;
      v_tip_deudor       ge_clientes.cod_tip_deudor%TYPE;
      v_residente        ge_clientes.residente%TYPE;
      v_mto_interes      ah_devengados.mto_interes%TYPE;
      v_cod_moneda       ah_cta_vistas.cod_moneda%TYPE;
      v_cod_oficina      ah_cta_vistas.cod_oficina%TYPE;
      v_cod_modalidad    ah_cta_vistas.cod_modalidad%TYPE;
      v_cod_modulo       ah_cta_vistas.cod_modulo%TYPE;
      v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
      xx_immovml         NUMBER;
      xx_immovex         NUMBER;
      xx_vltasci         NUMBER;
      --
      vh_nro_asiento    NUMBER;
      wh_immovex        NUMBER;
      wh_vltasci        NUMBER;
      vh_cod_oficina    ah_cta_vistas.cod_oficina%TYPE;
      vh_cod_ofi_origen ah_cta_vistas.cod_oficina%TYPE;
      vh_cod_modulo     ah_cta_vistas.cod_modulo%TYPE;
      vh_cod_modalidad  ah_cta_vistas.cod_modalidad%TYPE;

      wh_immovml NUMBER;
      wh_dcrefer CHAR(11);
      wh_lgprote CHAR(1);
      wh_lgdeact CHAR(1);
      wh_lgctadi CHAR(1);
      wh_dcdescr CHAR(60);
      --
      v_nro_linea ge_tip_asientos.nro_linea%TYPE;
      v_cod_rubro cb_rubros.cod_rubro%TYPE; --wh_cdcuent
      v_encontro  CHAR(1);
      v_msj       VARCHAR2(250);
      --
      wk_plazoav NUMBER(02) := 1; -- esto se definio solo p/select de A.V.
      --
      CURSOR cur3 IS
         SELECT cv.cod_modulo,
                cv.cod_modalidad,
                cv.cod_oficina,
                cv.cod_moneda,
                SUM(nvl(d.mto_interes, 0)),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                wk_plazoav,
                nvl(mo.cod_pro_contable, 0) cod_pro_contable
           FROM ah_cta_vistas   cv,
                ge_clientes     c,
                ah_devengados   d,
                ge_cta_clientes cc,
                ge_modalidades  mo
          WHERE fecha = v_fec_actual
            AND d.nro_cuenta = cv.nro_cuenta
            AND d.nro_cuenta = cc.nro_cuenta
            AND cv.cod_sub_modalidad <> 26 --cuenta basica
            AND relacion = 'P'
            AND c.cod_persona = cc.cod_persona
            AND cv.cod_modulo = mo.cod_modulo
            AND cv.cod_modalidad = mo.cod_modalidad
          GROUP BY cv.cod_modulo,
                   cv.cod_modalidad,
                   cv.cod_oficina,
                   cv.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   9,
                   nvl(mo.cod_pro_contable, 0)
         UNION
         SELECT cp.cod_modulo,
                cp.cod_modalidad,
                cp.cod_oficina,
                cp.cod_moneda,
                SUM(nvl(d.mto_interes, 0)),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                nvl(mo.cod_pro_contable, 0)
           FROM ge_plz_contables pc,
                ah_devengados    d,
                ah_cta_plazos    cp,
                ge_clientes      c,
                ge_cta_clientes  cc,
                ge_modalidades   mo
          WHERE fecha = v_fec_actual
            AND d.nro_cuenta = cp.nro_cuenta
            AND d.nro_cuenta = cc.nro_cuenta
            AND cc.relacion = 'P'
            AND c.cod_persona = cc.cod_persona
            AND cp.cod_modulo = mo.cod_modulo
            AND cp.cod_modalidad = mo.cod_modalidad
            AND pc.can_dias =
                (SELECT MIN(can_dias)
                   FROM ge_plz_contables
                  WHERE can_dias >= (cp.fec_vencimiento - cp.fec_apertura))
          GROUP BY cp.cod_modulo,
                   cp.cod_modalidad,
                   cp.cod_oficina,
                   cp.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   nvl(mo.cod_pro_contable, 0)
         UNION
         SELECT ct.cod_modulo,
                ct.cod_modalidad,
                ct.cod_oficina,
                ct.cod_moneda,
                SUM(nvl(d.mto_interes, 0)),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                nvl(mo.cod_pro_contable, 0)
           FROM ge_plz_contables    pc,
                ah_devengados       d,
                ah_cta_certificados ct,
                ge_clientes         c,
                ge_cta_clientes     cc,
                ge_modalidades      mo
          WHERE d.fecha = v_fec_actual
            AND d.nro_cuenta = ct.nro_cuenta
            AND d.nro_cuenta = cc.nro_cuenta
            AND relacion = 'P'
            AND c.cod_persona = cc.cod_persona
            AND mo.cod_modulo = ct.cod_modulo
            AND mo.cod_modalidad = ct.cod_modalidad
            AND pc.can_dias =
                (SELECT MIN(can_dias)
                   FROM ge_plz_contables
                  WHERE can_dias >= (ct.fec_vencimiento - ct.fec_apertura))
          GROUP BY ct.cod_modulo,
                   ct.cod_modalidad,
                   ct.cod_oficina,
                   ct.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   nvl(mo.cod_pro_contable, 0);
      --
      v_cod_tip_asiento  ge_tip_asientos.cod_tip_asiento%TYPE;
      v_cod_tip_asiento2 ge_tip_asientos.cod_tip_asiento%TYPE;
      r_gtasi            ge_tip_asientos%ROWTYPE;
      v_redondeo         NUMBER(5);
      --
      CURSOR c_tip_asientos IS
         SELECT *
           FROM ge_tip_asientos
          WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
            AND cod_moneda = v_cod_moneda
            AND (cod_sec_contable = v_cod_sec_contable OR cod_sec_contable IS NULL)
            AND (ind_residente = v_residente OR ind_residente = 'X')
            AND nvl(tip_cuenta, 'x') <> 'B';
   BEGIN
      v_msj := ' Intereses devengados ';
      OPEN cur3;
      LOOP
         FETCH cur3
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_moneda,
                 v_mto_interes,
                 v_cod_sec_contable,
                 v_residente,
                 v_tip_deudor,
                 v_cod_plazo,
                 v_cod_pro_contable;
         EXIT WHEN cur3%NOTFOUND;
         --- ve el tipo de asiento
         BEGIN
            SELECT cod_tip_asiento, descripcion, cod_tip_asiento2
              INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = 901
               AND cod_tip_asiento IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'NO TIENE ASIENTO RELAC.P/DEVENG ' || to_char(v_cod_modulo) || '-' ||
                                        to_char(v_cod_modalidad));
            WHEN OTHERS THEN
               /*EXHIBIR_ERROR;
               RAISE FORM_TRIGGER_FAILURE;*/
               raise_application_error(-20001, 'Error lp_int_devengados ' || SQLERRM);

         END;
         ------------------
         -- ve la moneda --
         ------------------
         /*--v_cod_mon_local y v_fec_actual, son inicializados en pra_gen_asientos*/
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad,
                                           v_cod_mon_local);
         IF v_cod_moneda = v_cod_mon_local THEN
            -- es moneda nacional --
            ------------------------
            xx_immovml := v_mto_interes;
            xx_immovex := 0;
            xx_vltasci := 0;
         ELSE
            /*if fug_obt_tip_implementacion = 1 then
               -- se obtiene la cotizacion de venta
               v_mto_cotizacion := pag_gen.fu_obt_cot_venta(v_cod_moneda, v_fec_actual);
            else*/
            -- se obtiene la cotizacion de cierre
            v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            --end if;
            xx_immovml := round(v_mto_interes * v_mto_cotizacion, v_redondeo);
            xx_immovex := v_mto_interes;
            xx_vltasci := v_mto_cotizacion;
         END IF;
         ----- ciclo para GE_TIP_ASIENTOS ------
         -------------------------------
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos;
         v_nro_linea := 0;
         LOOP
            FETCH c_tip_asientos
               INTO r_gtasi;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            ---Reemplaza el valor del tipo de deudor, si importa-
            IF r_gtasi.ind_deudor = 'S' THEN
               v_cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                              substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               v_cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---Reemplaza el codigo del plazo si es necesario -----
            IF r_gtasi.ind_plazo = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                              substr(v_cod_rubro, 4, 12);
            END IF;
            ---Reemplaza el codigo del producto -----------------------
            IF r_gtasi.ind_producto = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                              ltrim(to_char(v_cod_pro_contable, '000')) ||
                              substr(v_cod_rubro, 14, 2);
            END IF;
            ------------------------------------------------------
            v_encontro := 'S';
            lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
               --v_cod_rubro  := '999999999999999';
               v_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_mon_rubro = v_cod_mon_local THEN
               -- moneda local --
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            v_tip_movimiento := r_gtasi.tip_movimiento;
            IF xx_immovml > 0 THEN
               v_tip_movimiento := r_gtasi.tip_movimiento;
               wh_immovml       := xx_immovml;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            ------------------------------------------------------
            wh_dcrefer        := 'DEVENG.';
            wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                        to_char(901) || ' ' || v_des_transaccion, 1, 60);
            vh_cod_oficina    := v_cod_oficina;
            vh_cod_modulo     := v_cod_modulo;
            vh_cod_modalidad  := v_cod_modalidad;
            vh_cod_ofi_origen := v_cod_oficina;
            wh_lgprote        := 'N';
            wh_lgdeact        := 'N';
            wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
            vh_nro_asiento    := 0;
            v_cod_mod_padre   := v_cod_modulo;
            v_cod_mad_padre   := v_cod_modalidad;
            -----
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := v_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := wh_lgprote;
               r_baade.actualizado    := wh_lgdeact;
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.ref_movimiento := NULL;
               r_baade.cod_modulo     := v_cod_mod_padre;
               r_baade.cod_modalidad  := v_cod_mad_padre;
               r_baade.cod_ofi_origen := v_cod_ofi_origen;
               lp_ins_asi_aut_det(r_baade);
            END IF;
         END LOOP; -- fin de tipo de asientos --
         close c_tip_asientos; --FIELDESK-61066
      END LOOP; -- fin del ciclo de intereses devengados --
      close cur3; --FIELDESK-61066
   END;

   PROCEDURE lp_int_dev_cta_basica IS

      v_cod_mad_padre    ge_modalidades.cod_modalidad%TYPE;
      v_cod_mod_padre    ba_modulos.cod_modulo%TYPE;
      v_tip_movimiento   ge_tip_asientos.tip_movimiento%TYPE;
      v_mon_rubro        cb_rubros.cod_moneda%TYPE;
      v_mto_cotizacion   ge_cotizaciones.val_conversion%TYPE;
      v_des_transaccion  ge_transacciones.descripcion%TYPE;
      v_cod_sec_contable ge_sec_contables.cod_sec_contable%TYPE;
      v_cod_ofi_origen   ba_oficinas.cod_oficina%TYPE;
      v_cod_plazo        ge_plz_contables.cod_plazo%TYPE;
      v_tip_deudor       ge_clientes.cod_tip_deudor%TYPE;
      v_residente        ge_clientes.residente%TYPE;
      v_mto_interes      ah_devengados.mto_interes%TYPE;
      v_cod_moneda       ah_cta_vistas.cod_moneda%TYPE;
      v_cod_oficina      ah_cta_vistas.cod_oficina%TYPE;
      v_cod_modalidad    ah_cta_vistas.cod_modalidad%TYPE;
      v_cod_modulo       ah_cta_vistas.cod_modulo%TYPE;
      v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
      xx_immovml         NUMBER;
      xx_immovex         NUMBER;
      xx_vltasci         NUMBER;
      --
      vh_nro_asiento    NUMBER;
      wh_immovex        NUMBER;
      wh_vltasci        NUMBER;
      vh_cod_oficina    ah_cta_vistas.cod_oficina%TYPE;
      vh_cod_ofi_origen ah_cta_vistas.cod_oficina%TYPE;
      vh_cod_modulo     ah_cta_vistas.cod_modulo%TYPE;
      vh_cod_modalidad  ah_cta_vistas.cod_modalidad%TYPE;

      wh_immovml NUMBER;
      wh_dcrefer CHAR(11);
      wh_lgprote CHAR(1);
      wh_lgdeact CHAR(1);
      wh_lgctadi CHAR(1);
      wh_dcdescr CHAR(60);
      --
      v_nro_linea ge_tip_asientos.nro_linea%TYPE;
      v_cod_rubro cb_rubros.cod_rubro%TYPE; --wh_cdcuent
      v_encontro  CHAR(1);
      v_msj       VARCHAR2(250);
      --
      wk_plazoav NUMBER(02) := 1; -- esto se definio solo p/select de A.V.
      --
      CURSOR cur3 IS
         SELECT cv.cod_modulo,
                cv.cod_modalidad,
                cv.cod_oficina,
                cv.cod_moneda,
                SUM(nvl(d.mto_interes, 0)),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                wk_plazoav,
                nvl(mo.cod_pro_contable, 0) cod_pro_contable
           FROM ah_cta_vistas   cv,
                ge_clientes     c,
                ah_devengados   d,
                ge_cta_clientes cc,
                ge_modalidades  mo
          WHERE fecha = v_fec_actual
            AND d.nro_cuenta = cv.nro_cuenta
            AND d.nro_cuenta = cc.nro_cuenta
            AND cv.cod_sub_modalidad = 26
            AND relacion = 'P'
            AND c.cod_persona = cc.cod_persona
            AND cv.cod_modulo = mo.cod_modulo
            AND cv.cod_modalidad = mo.cod_modalidad
          GROUP BY cv.cod_modulo,
                   cv.cod_modalidad,
                   cv.cod_oficina,
                   cv.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   9,
                   nvl(mo.cod_pro_contable, 0);
      --
      v_cod_tip_asiento  ge_tip_asientos.cod_tip_asiento%TYPE;
      v_cod_tip_asiento2 ge_tip_asientos.cod_tip_asiento%TYPE;
      r_gtasi            ge_tip_asientos%ROWTYPE;
      v_redondeo         NUMBER(5);
      --
      CURSOR c_tip_asientos IS
         SELECT *
           FROM ge_tip_asientos
          WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
            AND cod_moneda = v_cod_moneda
            AND (cod_sec_contable = v_cod_sec_contable OR cod_sec_contable IS NULL)
            AND (ind_residente = v_residente OR ind_residente = 'X')
            AND tip_cuenta = 'B';
   BEGIN
      v_msj := ' Intereses devengados ';
      OPEN cur3;
      LOOP
         FETCH cur3
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_moneda,
                 v_mto_interes,
                 v_cod_sec_contable,
                 v_residente,
                 v_tip_deudor,
                 v_cod_plazo,
                 v_cod_pro_contable;
         EXIT WHEN cur3%NOTFOUND;
         --- ve el tipo de asiento
         BEGIN
            SELECT cod_tip_asiento, descripcion, cod_tip_asiento2
              INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = 901
               AND cod_tip_asiento IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'NO TIENE ASIENTO RELAC.P/DEVENG ' || to_char(v_cod_modulo) || '-' ||
                                        to_char(v_cod_modalidad));
            WHEN OTHERS THEN
               /*EXHIBIR_ERROR;
               RAISE FORM_TRIGGER_FAILURE;*/
               raise_application_error(-20001, 'Error lp_int_dev_cta_basica ' || SQLERRM);

         END;
         ------------------
         -- ve la moneda --
         ------------------
         /*--v_cod_mon_local y v_fec_actual, son inicializados en pra_gen_asientos*/
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad,
                                           v_cod_mon_local);
         IF v_cod_moneda = v_cod_mon_local THEN
            -- es moneda nacional --
            ------------------------
            xx_immovml := v_mto_interes;
            xx_immovex := 0;
            xx_vltasci := 0;
         ELSE
            /*if fug_obt_tip_implementacion = 1 then
               -- se obtiene la cotizacion de venta
               v_mto_cotizacion := pag_gen.fu_obt_cot_venta(v_cod_moneda, v_fec_actual);
            else*/
            -- se obtiene la cotizacion de cierre
            v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            --end if;
            xx_immovml := round(v_mto_interes * v_mto_cotizacion, v_redondeo);
            xx_immovex := v_mto_interes;
            xx_vltasci := v_mto_cotizacion;
         END IF;
         ----- ciclo para GE_TIP_ASIENTOS ------
         -------------------------------
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos;
         v_nro_linea := 0;
         LOOP
            FETCH c_tip_asientos
               INTO r_gtasi;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            ---Reemplaza el valor del tipo de deudor, si importa-
            IF r_gtasi.ind_deudor = 'S' THEN
               v_cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                              substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               v_cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---Reemplaza el codigo del plazo si es necesario -----
            IF r_gtasi.ind_plazo = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                              substr(v_cod_rubro, 4, 12);
            END IF;
            ---Reemplaza el codigo del producto -----------------------
            IF r_gtasi.ind_producto = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                              ltrim(to_char(v_cod_pro_contable, '000')) ||
                              substr(v_cod_rubro, 14, 2);
            END IF;
            ------------------------------------------------------
            v_encontro := 'S';
            lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
               --v_cod_rubro  := '999999999999999';
               v_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_mon_rubro = v_cod_mon_local THEN
               -- moneda local --
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            v_tip_movimiento := r_gtasi.tip_movimiento;
            IF xx_immovml > 0 THEN
               v_tip_movimiento := r_gtasi.tip_movimiento;
               wh_immovml       := xx_immovml;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            ------------------------------------------------------
            wh_dcrefer        := 'DEVENG.';
            wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                        to_char(901) || ' ' || v_des_transaccion, 1, 60);
            vh_cod_oficina    := v_cod_oficina;
            vh_cod_modulo     := v_cod_modulo;
            vh_cod_modalidad  := v_cod_modalidad;
            vh_cod_ofi_origen := v_cod_oficina;
            wh_lgprote        := 'N';
            wh_lgdeact        := 'N';
            wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
            vh_nro_asiento    := 0;
            v_cod_mod_padre   := v_cod_modulo;
            v_cod_mad_padre   := v_cod_modalidad;
            -----
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := v_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := wh_lgprote;
               r_baade.actualizado    := wh_lgdeact;
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.ref_movimiento := NULL;
               r_baade.cod_modulo     := v_cod_mod_padre;
               r_baade.cod_modalidad  := v_cod_mad_padre;
               r_baade.cod_ofi_origen := v_cod_ofi_origen;
               lp_ins_asi_aut_det(r_baade);
            END IF;
         END LOOP; -- fin de tipo de asientos --
         close c_tip_asientos; --FIELDESK-61066
      END LOOP; -- fin del ciclo de intereses devengados --
      close cur3; --FIELDESK-61066
   END;

   -- Insteres Devengado de Prestamos
   PROCEDURE lp_int_dev_prestamos IS
      v_cod_mad_padre    ge_modalidades.cod_modalidad%TYPE;
      v_cod_mod_padre    ba_modulos.cod_modulo%TYPE;
      v_tip_movimiento   ge_tip_asientos.tip_movimiento%TYPE;
      v_mon_rubro        cb_rubros.cod_moneda%TYPE;
      v_mto_cotizacion   ge_cotizaciones.val_conversion%TYPE;
      v_des_transaccion  ge_transacciones.descripcion%TYPE;
      v_cod_sec_contable ge_sec_contables.cod_sec_contable%TYPE;
      v_cod_ofi_origen   ba_oficinas.cod_oficina%TYPE;
      v_cod_plazo        ge_plz_contables.cod_plazo%TYPE;
      v_tip_deudor       ge_clientes.cod_tip_deudor%TYPE;
      v_residente        ge_clientes.residente%TYPE;
      v_mto_interes      ah_devengados.mto_interes%TYPE;
      v_cod_moneda       ah_cta_vistas.cod_moneda%TYPE;
      v_cod_oficina      ah_cta_vistas.cod_oficina%TYPE;
      v_cod_modalidad    ah_cta_vistas.cod_modalidad%TYPE;
      v_cod_modulo       ah_cta_vistas.cod_modulo%TYPE;
      v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
      v_est_cuenta       ge_tip_asientos.est_cuenta%TYPE;
      v_tip_cuenta       ge_tip_asientos.tip_cuenta%TYPE;
      v_tip_interes      ge_tip_asientos.tip_interes%TYPE;
      v_tip_renovacion   ge_tip_asientos.tip_renovacion%TYPE;
      v_cat_automatica   ge_tip_asientos.cat_automatica%TYPE;
      xx_immovml         NUMBER;
      xx_immovex         NUMBER;
      xx_vltasci         NUMBER;
      --
      vh_nro_asiento    NUMBER;
      wh_immovex        NUMBER;
      wh_vltasci        NUMBER;
      vh_cod_oficina    pr_cta_prestamos.cod_oficina%TYPE;
      vh_cod_ofi_origen pr_cta_prestamos.cod_oficina%TYPE;
      vh_cod_modulo     pr_cta_prestamos.cod_modulo%TYPE;
      vh_cod_modalidad  pr_cta_prestamos.cod_modalidad%TYPE;

      wh_immovml NUMBER;
      wh_dcrefer VARCHAR2(11);
      wh_lgprote VARCHAR2(1);
      wh_lgdeact VARCHAR2(1);
      wh_lgctadi VARCHAR2(1);
      wh_dcdescr VARCHAR2(60);
      --
      v_nro_linea ge_tip_asientos.nro_linea%TYPE;
      v_cod_rubro cb_rubros.cod_rubro%TYPE; --wh_cdcuent
      v_encontro  VARCHAR2(1);
      v_msj       VARCHAR2(250);
      --
      v_cod_sec_rubro ge_con_transacciones.cod_sec_rubro%TYPE;
      -- DYDMR-15460 NAF 2021/06
      xx_afd_immovml     NUMBER;
      xx_afd_immovex     NUMBER;
      xx_afd_vltasci     NUMBER;
      v_cod_ori_fondo pr_cta_prestamos.cod_ori_fondo%TYPE;
      v_por_ori_fondo pr_cta_prestamos.por_ori_fondo%TYPE;
      v_par_afd_cod_ori_fondo varchar2(500) := trim(fug_obt_pardinamico('COD_ORI_FON_AFD_ASIENTOS'));
      
      CURSOR cur3 IS
         SELECT ct.cod_modulo,
                ct.cod_modalidad,
                ct.cod_oficina,
                ct.cod_moneda,
                SUM(nvl(d.mto_dev_actual, 0)),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                nvl(mo.cod_pro_contable, 0),
                d.categoria,
                ct.tipo,
                ct.tip_interes,
                nvl(ct.tip_renovacion, 'A') tip_renovacion,
                d.estado,
                fup_obt_sec_rubro(ct.cod_sec_credito),
                ct.cod_ori_fondo,
                ct.por_ori_fondo
           FROM ge_plz_contables pc,
                pr_devengados    d,
                pr_cta_prestamos ct,
                ge_clientes      c,
                ge_cta_clientes  cc,
                ge_modalidades   mo
          WHERE d.fecha = v_fec_actual
            AND d.nro_cuenta = ct.nro_cuenta
            AND d.nro_cuenta = cc.nro_cuenta
            AND relacion = 'P'
            AND c.cod_persona = cc.cod_persona
            AND mo.cod_modulo = ct.cod_modulo
            AND mo.cod_modalidad = ct.cod_modalidad

            AND pc.can_dias =
                (SELECT MIN(can_dias)
                   FROM ge_plz_contables
                  WHERE can_dias >= (ct.fec_vencimiento - ct.fec_inicio))
          GROUP BY ct.cod_modulo,
                   ct.cod_modalidad,
                   ct.cod_oficina,
                   ct.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   nvl(mo.cod_pro_contable, 0),
                   d.categoria,
                   ct.tipo,
                   ct.tip_interes,
                   nvl(ct.tip_renovacion, 'A'),
                   d.estado,
                   fup_obt_sec_rubro(ct.cod_sec_credito),
                   ct.cod_ori_fondo,
                   ct.por_ori_fondo;
      --
      v_cod_tip_asiento  ge_tip_asientos.cod_tip_asiento%TYPE;
      v_cod_tip_asiento2 ge_tip_asientos.cod_tip_asiento%TYPE;
      r_gtasi            ge_tip_asientos%ROWTYPE;
      v_redondeo         NUMBER(5);
      --
      CURSOR c_tip_asientos IS
         SELECT *
           FROM ge_tip_asientos
          WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
            AND cod_moneda = v_cod_moneda
            AND (cod_sec_contable = v_cod_sec_contable OR cod_sec_contable IS NULL)
            AND (ind_residente = v_residente OR ind_residente = 'X')
            AND (est_cuenta = v_est_cuenta OR nvl(est_cuenta, 'X') = 'X')
            AND (tip_cuenta = v_tip_cuenta OR nvl(tip_cuenta, 'X') = 'X')
            AND (tip_interes = v_tip_interes OR nvl(tip_interes, 'X') = 'X')
            AND (tip_renovacion = v_tip_renovacion OR nvl(tip_renovacion, 'X') = 'X')
            AND (cat_automatica = v_cat_automatica OR nvl(cat_automatica, -1) = -1);
   BEGIN
      v_msj := ' Intereses devengados ';
      OPEN cur3;
      LOOP
         FETCH cur3
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_moneda,
                 v_mto_interes,
                 v_cod_sec_contable,
                 v_residente,
                 v_tip_deudor,
                 v_cod_plazo,
                 v_cod_pro_contable,
                 v_cat_automatica,
                 v_tip_cuenta,
                 v_tip_interes,
                 v_tip_renovacion,
                 v_est_cuenta,
                 v_cod_sec_rubro,
                 v_cod_ori_fondo,
                 v_por_ori_fondo;
         EXIT WHEN cur3%NOTFOUND;
         --- ve el tipo de asiento por el CREDITO
         BEGIN
            SELECT cod_tip_asiento, descripcion, cod_tip_asiento2
              INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = 901
               AND cod_tip_asiento IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'Transaccion ' || to_char(v_cod_modulo) || '-' ||
                                        to_char(v_cod_modalidad) ||
                                        '-901 no tiene asiento de Credito definido.');
            WHEN OTHERS THEN
               IF SQLCODE <= -20000 THEN
                  RAISE;
               ELSE
                  raise_application_error(-20001, 'Error lp_int_devengados ' || SQLERRM);
               END IF;
         END;
         ------------------
         -- ve la moneda --
         ------------------
         /*--v_cod_mon_local y v_fec_actual, son inicializados en pra_gen_asientos*/
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad,
                                           v_cod_mon_local);
         IF v_cod_moneda = v_cod_mon_local THEN
            -- es moneda nacional --
            ------------------------
            xx_immovml := v_mto_interes;
            xx_immovex := 0;
            xx_vltasci := 0;
         ELSE
            /*if fug_obt_tip_implementacion = 1 then
               -- se obtiene la cotizacion de venta
               v_mto_cotizacion := pag_gen.fu_obt_cot_venta(v_cod_moneda, v_fec_actual);
            else*/
            -- se obtiene la cotizacion de cierre
            v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            --end if;
            xx_immovml := round(v_mto_interes * v_mto_cotizacion, v_redondeo);
            xx_immovex := v_mto_interes;
            xx_vltasci := v_mto_cotizacion;
         END IF;
         --- si es AFD calcula el % de Interes correspondiente
         IF instr(',' || v_par_afd_cod_ori_fondo || ',', ',' || v_cod_ori_fondo || ',') > 0 THEN
            --el % de v_por_ori_fondo corresponde a AFD
            xx_afd_immovml := round(xx_immovml * v_por_ori_fondo / 100, 0);
            xx_immovml := xx_immovml - xx_afd_immovml;
            if xx_immovex > 0 then
               xx_afd_immovex := round(xx_immovml * v_por_ori_fondo / 100, v_redondeo);
               xx_immovex := xx_immovex - xx_afd_immovex;
            else
               xx_afd_immovex := 0;
            end if;
            xx_afd_vltasci := xx_vltasci;
         ELSE
           xx_afd_immovml := 0;
           xx_afd_immovex := 0;
           xx_afd_vltasci := 0;
         END IF;
         ----- ciclo para GE_TIP_ASIENTOS ------
         -------------------------------
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos;
         v_nro_linea := 0;
         LOOP
            FETCH c_tip_asientos
               INTO r_gtasi;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            ---Reemplaza el valor del tipo de deudor, si importa-
            IF r_gtasi.ind_deudor = 'S' THEN
               v_cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                              substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               v_cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---Reemplaza el codigo del plazo si es necesario -----
            IF r_gtasi.ind_plazo = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                              substr(v_cod_rubro, 4, 12);
            END IF;
            ---Reemplaza el codigo del producto -----------------------
            IF r_gtasi.ind_producto = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                              ltrim(to_char(v_cod_pro_contable, '000')) ||
                              substr(v_cod_rubro, 14, 2);
            END IF;
            --Reemplaza el código del sector de crédito
            IF substr(r_gtasi.cod_rubro, 11, 3) = 'SEC' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_sec_rubro, '000')) ||
                              substr(r_gtasi.cod_rubro, 14, 2);
            END IF;
            ------------------------------------------------------
            v_encontro := 'S';
            lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
               --v_cod_rubro  := '999999999999999';
               v_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_mon_rubro = v_cod_mon_local THEN
               -- moneda local --
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            v_tip_movimiento := r_gtasi.tip_movimiento;
            IF xx_immovml > 0 THEN
               v_tip_movimiento := r_gtasi.tip_movimiento;
               wh_immovml       := xx_immovml;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            ------------------------------------------------------
            wh_dcrefer        := 'DEVENG.';
            wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                        to_char(901) || ' ' || v_des_transaccion, 1, 60);
            vh_cod_oficina    := v_cod_oficina;
            vh_cod_modulo     := v_cod_modulo;
            vh_cod_modalidad  := v_cod_modalidad;
            vh_cod_ofi_origen := v_cod_oficina;
            wh_lgprote        := 'N';
            wh_lgdeact        := 'N';
            wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
            vh_nro_asiento    := 0;
            v_cod_mod_padre   := v_cod_modulo;
            v_cod_mad_padre   := v_cod_modalidad;
            -----
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := v_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := wh_lgprote;
               r_baade.actualizado    := wh_lgdeact;
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.ref_movimiento := NULL;
               r_baade.cod_modulo     := v_cod_mod_padre;
               r_baade.cod_modalidad  := v_cod_mad_padre;
               r_baade.cod_ofi_origen := v_cod_ofi_origen;
               lp_ins_asi_aut_det(r_baade);
            END IF;
         END LOOP; -- fin de tipo de asientos --
         --- si es AFD ve el tipo de asiento por el CREDITO
         IF instr(',' || v_par_afd_cod_ori_fondo || ',', ',' || v_cod_ori_fondo || ',') > 0 THEN
           BEGIN
              SELECT cod_tip_asiento, descripcion, cod_tip_asiento2
                INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
                FROM ge_transacciones
               WHERE cod_modulo = v_cod_modulo
                 AND cod_modalidad = v_cod_modalidad
                 AND cod_transaccion = 991
                 AND cod_tip_asiento IS NOT NULL;
           EXCEPTION
              WHEN no_data_found THEN
                 raise_application_error(-20000,
                                         'Transaccion AFD ' || to_char(v_cod_modulo) || '-' ||
                                          to_char(v_cod_modalidad) ||
                                          '-991 no tiene asiento de Credito definido.');
              WHEN OTHERS THEN
                 IF SQLCODE <= -20000 THEN
                    RAISE;
                 ELSE
                    raise_application_error(-20001, 'Error lp_int_devengados ' || SQLERRM);
                 END IF;
           END;
           ------------------
           ----- ciclo para GE_TIP_ASIENTOS AFD------
           -------------------------------
           IF c_tip_asientos%ISOPEN THEN
              CLOSE c_tip_asientos;
           END IF;
           OPEN c_tip_asientos;
           v_nro_linea := 0;
           LOOP
              FETCH c_tip_asientos
                 INTO r_gtasi;
              EXIT WHEN c_tip_asientos%NOTFOUND;
              ---Reemplaza el valor del tipo de deudor, si importa-
              IF r_gtasi.ind_deudor = 'S' THEN
                 v_cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                                substr(r_gtasi.cod_rubro, 11, 5);
              ELSE
                 v_cod_rubro := r_gtasi.cod_rubro;
              END IF;
              ---Reemplaza el codigo del plazo si es necesario -----
              IF r_gtasi.ind_plazo = 'S' THEN
                 v_cod_rubro := substr(v_cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                                substr(v_cod_rubro, 4, 12);
              END IF;
              ---Reemplaza el codigo del producto -----------------------
              IF r_gtasi.ind_producto = 'S' THEN
                 v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                                ltrim(to_char(v_cod_pro_contable, '000')) ||
                                substr(v_cod_rubro, 14, 2);
              END IF;
              --Reemplaza el código del sector de crédito
              IF substr(r_gtasi.cod_rubro, 11, 3) = 'SEC' THEN
                 v_cod_rubro := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_sec_rubro, '000')) ||
                                substr(r_gtasi.cod_rubro, 14, 2);
              END IF;
              ------------------------------------------------------
              v_encontro := 'S';
              lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
              IF v_encontro = 'N' THEN
                 v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
                 --v_cod_rubro  := '999999999999999';
                 v_mon_rubro := v_cod_mon_local;
              END IF;
              IF v_mon_rubro = v_cod_mon_local THEN
                 -- moneda local --
                 wh_immovex := 0;
                 wh_vltasci := 0;
              ELSE
                 wh_immovex := xx_afd_immovex;
                 wh_vltasci := xx_afd_vltasci;
              END IF;
              -- ve el tipo de movimiento --
              ------------------------------
              v_tip_movimiento := r_gtasi.tip_movimiento;
              IF xx_afd_immovml > 0 THEN
                 v_tip_movimiento := r_gtasi.tip_movimiento;
                 wh_immovml       := xx_afd_immovml;
              ELSE
                 wh_immovml := xx_afd_immovml * -1;
                 wh_immovex := wh_immovex * -1;
                 IF r_gtasi.tip_movimiento = 'C' THEN
                    v_tip_movimiento := 'D';
                 ELSE
                    v_tip_movimiento := 'C';
                 END IF;
              END IF;
              ------------------------------------------------------
              wh_dcrefer        := 'DEVENG.';
              wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                          to_char(991) || ' ' || v_des_transaccion, 1, 60);
              vh_cod_oficina    := v_cod_oficina;
              vh_cod_modulo     := v_cod_modulo;
              vh_cod_modalidad  := v_cod_modalidad;
              vh_cod_ofi_origen := v_cod_oficina;
              wh_lgprote        := 'N';
              wh_lgdeact        := 'N';
              wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
              vh_nro_asiento    := 0;
              v_cod_mod_padre   := v_cod_modulo;
              v_cod_mad_padre   := v_cod_modalidad;
              -----
              IF wh_immovml <> 0 THEN
                 v_nro_linea := v_nro_linea + 1;
                 --- Cargar registro de asientos detalles
                 r_baade.fecha          := v_fec_actual;
                 r_baade.cod_oficina    := vh_cod_oficina;
                 r_baade.nro_asiento    := 0;
                 r_baade.nro_linea      := v_nro_linea;
                 r_baade.cod_rubro      := v_cod_rubro;
                 r_baade.tip_movimiento := v_tip_movimiento;
                 r_baade.mto_mon_rubro  := wh_immovex;
                 r_baade.mto_mon_local  := wh_immovml;
                 r_baade.descripcion    := wh_dcdescr;
                 r_baade.referencia     := wh_dcrefer;
                 r_baade.protegido      := wh_lgprote;
                 r_baade.actualizado    := wh_lgdeact;
                 r_baade.val_cotizacion := wh_vltasci;
                 r_baade.distribuido    := wh_lgctadi;
                 r_baade.ref_movimiento := NULL;
                 r_baade.cod_modulo     := v_cod_mod_padre;
                 r_baade.cod_modalidad  := v_cod_mad_padre;
                 r_baade.cod_ofi_origen := v_cod_ofi_origen;
                 lp_ins_asi_aut_det(r_baade);
              END IF;
           END LOOP; -- fin de tipo de asientos AFD--
         END IF;
         --- ve el tipo de asiento por el DEBITO
         BEGIN
            SELECT cod_tip_asiento, descripcion, cod_tip_asiento
              INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = 903
               AND cod_tip_asiento IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'Transaccion ' || to_char(v_cod_modulo) || '-' ||
                                        to_char(v_cod_modalidad) ||
                                        '-903 no tiene asiento de Debito definido.');
            WHEN OTHERS THEN
               IF SQLCODE <= -20000 THEN
                  RAISE;
               ELSE
                  raise_application_error(-20002, 'Error lp_int_devengados ' || SQLERRM);
               END IF;
         END;
         ------------------
         -- ve la moneda --
         ------------------
         /*--v_cod_mon_local y v_fec_actual, son inicializados en pra_gen_asientos*/
         IF v_cod_moneda = v_cod_mon_local THEN
            -- es moneda nacional --
            ------------------------
            xx_immovml := v_mto_interes;
            xx_immovex := 0;
            xx_vltasci := 0;
         ELSE
            /*if fug_obt_tip_implementacion = 1 then
               -- se obtiene la cotizacion de venta
               v_mto_cotizacion := pag_gen.fu_obt_cot_venta(v_cod_moneda, v_fec_actual);
            else*/
            -- se obtiene la cotizacion de cierre
            v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            --end if;
            xx_immovml := round(v_mto_interes * v_mto_cotizacion, v_redondeo);
            xx_immovex := v_mto_interes;
            xx_vltasci := v_mto_cotizacion;
         END IF;
         ----- ciclo para GE_TIP_ASIENTOS ------
         -------------------------------
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos;
         v_nro_linea := 0;
         LOOP
            FETCH c_tip_asientos
               INTO r_gtasi;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            ---Reemplaza el valor del tipo de deudor, si importa-
            IF r_gtasi.ind_deudor = 'S' THEN
               v_cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                              substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               v_cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---Reemplaza el codigo del plazo si es necesario -----
            IF r_gtasi.ind_plazo = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                              substr(v_cod_rubro, 4, 12);
            END IF;
            ---Reemplaza el codigo del producto -----------------------
            IF r_gtasi.ind_producto = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                              ltrim(to_char(v_cod_pro_contable, '000')) ||
                              substr(v_cod_rubro, 14, 2);
            END IF;
            --Reemplaza el código del sector de crédito
            IF substr(r_gtasi.cod_rubro, 11, 3) = 'SEC' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_sec_rubro, '000')) ||
                              substr(r_gtasi.cod_rubro, 14, 2);
            END IF;
            ------------------------------------------------------
            v_encontro := 'S';
            lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
               --v_cod_rubro  := '999999999999999';
               v_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_mon_rubro = v_cod_mon_local THEN
               -- moneda local --
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            v_tip_movimiento := r_gtasi.tip_movimiento;
            IF xx_immovml > 0 THEN
               v_tip_movimiento := r_gtasi.tip_movimiento;
               wh_immovml       := xx_immovml;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            ------------------------------------------------------
            wh_dcrefer        := 'DEVENG.';
            wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                        to_char(903) || ' ' || v_des_transaccion, 1, 60);
            vh_cod_oficina    := v_cod_oficina;
            vh_cod_modulo     := v_cod_modulo;
            vh_cod_modalidad  := v_cod_modalidad;
            vh_cod_ofi_origen := v_cod_oficina;
            wh_lgprote        := 'N';
            wh_lgdeact        := 'N';
            wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
            vh_nro_asiento    := 0;
            v_cod_mod_padre   := v_cod_modulo;
            v_cod_mad_padre   := v_cod_modalidad;
            -----
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := v_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := wh_lgprote;
               r_baade.ref_movimiento := NULL;
               r_baade.actualizado    := wh_lgdeact;
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.cod_modulo     := v_cod_mod_padre;
               r_baade.cod_modalidad  := v_cod_mad_padre;
               r_baade.cod_ofi_origen := v_cod_ofi_origen;
               lp_ins_asi_aut_det(r_baade);
            END IF;
         END LOOP; -- fin de tipo de asientos --
         close c_tip_asientos; --FIELDESK-61066
      END LOOP; -- fin del ciclo de intereses devengados --
      close cur3; --FIELDESK-61066
   END;

   --Diferencia de Intereses Devengados Resolucion 4--
    PROCEDURE lp_int_dev_pre_aju_re4 IS
    v_cod_mad_padre    ge_modalidades.cod_modalidad%TYPE;
    v_cod_mod_padre    ba_modulos.cod_modulo%TYPE;
    v_tip_movimiento   ge_tip_asientos.tip_movimiento%TYPE;
    v_mon_rubro        cb_rubros.cod_moneda%TYPE;
    v_mto_cotizacion   ge_cotizaciones.val_conversion%TYPE;
    v_des_transaccion  ge_transacciones.descripcion%TYPE;
    v_cod_sec_contable ge_sec_contables.cod_sec_contable%TYPE;
    v_cod_ofi_origen   ba_oficinas.cod_oficina%TYPE;
    v_cod_plazo        ge_plz_contables.cod_plazo%TYPE;
    v_tip_deudor       ge_clientes.cod_tip_deudor%TYPE;
    v_residente        ge_clientes.residente%TYPE;
    v_mto_interes      ah_devengados.mto_interes%TYPE;
    v_cod_moneda       ah_cta_vistas.cod_moneda%TYPE;
    v_cod_oficina      ah_cta_vistas.cod_oficina%TYPE;
    v_cod_modalidad    ah_cta_vistas.cod_modalidad%TYPE;
    v_cod_modulo       ah_cta_vistas.cod_modulo%TYPE;
    v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
    v_est_cuenta       ge_tip_asientos.est_cuenta%TYPE;
    v_tip_cuenta       ge_tip_asientos.tip_cuenta%TYPE;
    v_tip_interes      ge_tip_asientos.tip_interes%TYPE;
    v_tip_renovacion   ge_tip_asientos.tip_renovacion%TYPE;
    v_cat_automatica   ge_tip_asientos.cat_automatica%TYPE;
    xx_immovml         NUMBER;
    xx_immovex         NUMBER;
    xx_vltasci         NUMBER;
    --
    vh_nro_asiento    NUMBER;
    wh_immovex        NUMBER;
    wh_vltasci        NUMBER;
    vh_cod_oficina    pr_cta_prestamos.cod_oficina%TYPE;
    vh_cod_ofi_origen pr_cta_prestamos.cod_oficina%TYPE;
    vh_cod_modulo     pr_cta_prestamos.cod_modulo%TYPE;
    vh_cod_modalidad  pr_cta_prestamos.cod_modalidad%TYPE;

    wh_immovml NUMBER;
    wh_dcrefer VARCHAR2(11);
    wh_lgprote VARCHAR2(1);
    wh_lgdeact VARCHAR2(1);
    wh_lgctadi VARCHAR2(1);
    wh_dcdescr VARCHAR2(60);
    --
    v_nro_linea ge_tip_asientos.nro_linea%TYPE;
    v_cod_rubro cb_rubros.cod_rubro%TYPE; --wh_cdcuent
    v_encontro  VARCHAR2(1);
    v_msj       VARCHAR2(250);
    --
    v_cod_sec_rubro ge_con_transacciones.cod_sec_rubro%TYPE;

    CURSOR cur3 IS
       --Cuentas que existen ambos dias--
       SELECT ct.cod_modulo,
              ct.cod_modalidad,
              ct.cod_oficina,
              ct.cod_moneda,
              SUM(nvl(nvl(d.mto_dev_acumulado,0) - nvl(x.mto_dev_acumulado,0),0))*-1,
              c.cod_sec_contable,
              c.residente,
              c.cod_tip_deudor,
              nvl(pc.cod_plazo, 0),
              nvl(mo.cod_pro_contable, 0),
              d.categoria,
              ct.tipo,
              ct.tip_interes,
              nvl(ct.tip_renovacion, 'A') tip_renovacion,
              d.estado,
              fup_obt_sec_rubro(ct.cod_sec_credito)
         FROM ge_plz_contables pc,
              pr_devengados    d,
              pr_cta_prestamos ct,
              ge_clientes      c,
              ge_cta_clientes  cc,
              ge_modalidades   mo,
              PR_DEVENGADOS_RE4_2003 x
        WHERE d.fecha = pag_cal.FU_OBT_FEC_ACTUAL(1)
          AND d.nro_cuenta = ct.nro_cuenta
          AND d.nro_cuenta = cc.nro_cuenta
          AND relacion = 'P'
          AND c.cod_persona = cc.cod_persona
          AND mo.cod_modulo = ct.cod_modulo
          AND mo.cod_modalidad = ct.cod_modalidad
          -----
          and d.nro_cuenta = x.nro_cuenta
          and d.nro_cuota = x.nro_cuota
          and (nvl(d.mto_dev_acumulado,0) - nvl(x.mto_dev_acumulado,0)) <> 0
          and exists (select 1
                        from PR_CTA_PRE_CAN_RES4 k
                       where k.nro_cuenta = ct.nro_cuenta)
          -----
          AND pc.can_dias =
              (SELECT MIN(can_dias)
                 FROM ge_plz_contables
                WHERE can_dias >= (ct.fec_vencimiento - ct.fec_inicio))
        GROUP BY ct.cod_modulo,
                 ct.cod_modalidad,
                 ct.cod_oficina,
                 ct.cod_moneda,
                 c.cod_sec_contable,
                 c.residente,
                 c.cod_tip_deudor,
                 pc.cod_plazo,
                 nvl(mo.cod_pro_contable, 0),
                 d.categoria,
                 ct.tipo,
                 ct.tip_interes,
                 nvl(ct.tip_renovacion, 'A'),
                 d.estado,
                 fup_obt_sec_rubro(ct.cod_sec_credito)
         UNION ALL
         --Cuentas que no existen corte anterior--
         SELECT ct.cod_modulo,
              ct.cod_modalidad,
              ct.cod_oficina,
              ct.cod_moneda,
              SUM(nvl(d.mto_dev_acumulado,0))*-1,
              c.cod_sec_contable,
              c.residente,
              c.cod_tip_deudor,
              nvl(pc.cod_plazo, 0),
              nvl(mo.cod_pro_contable, 0),
              d.categoria,
              ct.tipo,
              ct.tip_interes,
              nvl(ct.tip_renovacion, 'A') tip_renovacion,
              d.estado,
              fup_obt_sec_rubro(ct.cod_sec_credito)
         FROM ge_plz_contables pc,
              pr_devengados    d,
              pr_cta_prestamos ct,
              ge_clientes      c,
              ge_cta_clientes  cc,
              ge_modalidades   mo
        WHERE d.fecha = pag_cal.FU_OBT_FEC_ACTUAL(1)
          AND d.nro_cuenta = ct.nro_cuenta
          AND d.nro_cuenta = cc.nro_cuenta
          AND relacion = 'P'
          AND c.cod_persona = cc.cod_persona
          AND mo.cod_modulo = ct.cod_modulo
          AND mo.cod_modalidad = ct.cod_modalidad
          -----
          AND NOT EXISTS (SELECT 1
                            FROM PR_DEVENGADOS_RE4_2003 X
                           WHERE X.NRO_CUENTA = d.NRO_CUENTA
                             AND X.NRO_CUOTA = d.NRO_CUOTA)
          and exists (select 1
                        from PR_CTA_PRE_CAN_RES4 k
                       where k.nro_cuenta = ct.nro_cuenta)
          -----
          AND pc.can_dias =
              (SELECT MIN(can_dias)
                 FROM ge_plz_contables
                WHERE can_dias >= (ct.fec_vencimiento - ct.fec_inicio))
        GROUP BY ct.cod_modulo,
                 ct.cod_modalidad,
                 ct.cod_oficina,
                 ct.cod_moneda,
                 c.cod_sec_contable,
                 c.residente,
                 c.cod_tip_deudor,
                 pc.cod_plazo,
                 nvl(mo.cod_pro_contable, 0),
                 d.categoria,
                 ct.tipo,
                 ct.tip_interes,
                 nvl(ct.tip_renovacion, 'A'),
                 d.estado,
                 fup_obt_sec_rubro(ct.cod_sec_credito)
         UNION ALL
         --Cuentas que existen corte anterior y no hoy--
         SELECT ct.cod_modulo,
              ct.cod_modalidad,
              ct.cod_oficina,
              ct.cod_moneda,
              SUM(nvl(d.mto_dev_acumulado,0)),
              c.cod_sec_contable,
              c.residente,
              c.cod_tip_deudor,
              nvl(pc.cod_plazo, 0),
              nvl(mo.cod_pro_contable, 0),
              d.categoria,
              ct.tipo,
              ct.tip_interes,
              nvl(ct.tip_renovacion, 'A') tip_renovacion,
              d.estado,
              fup_obt_sec_rubro(ct.cod_sec_credito)
         FROM ge_plz_contables pc,
              PR_DEVENGADOS_RE4_2003 d,
              pr_cta_prestamos ct,
              ge_clientes      c,
              ge_cta_clientes  cc,
              ge_modalidades   mo
        WHERE d.nro_cuenta = ct.nro_cuenta
          AND d.nro_cuenta = cc.nro_cuenta
          AND relacion = 'P'
          AND c.cod_persona = cc.cod_persona
          AND mo.cod_modulo = ct.cod_modulo
          AND mo.cod_modalidad = ct.cod_modalidad
          -----
          AND NOT EXISTS (SELECT 1
                            FROM PR_DEVENGADOS X
                           WHERE X.FECHA = PAG_CAL.FU_OBT_FEC_ACTUAL(1)
                             AND X.NRO_CUENTA = d.NRO_CUENTA
                             AND X.NRO_CUOTA = d.NRO_CUOTA)
          and exists (select 1
                        from PR_CTA_PRE_CAN_RES4 k
                       where k.nro_cuenta = ct.nro_cuenta)
          -----
          AND pc.can_dias =
              (SELECT MIN(can_dias)
                 FROM ge_plz_contables
                WHERE can_dias >= (ct.fec_vencimiento - ct.fec_inicio))
        GROUP BY ct.cod_modulo,
                 ct.cod_modalidad,
                 ct.cod_oficina,
                 ct.cod_moneda,
                 c.cod_sec_contable,
                 c.residente,
                 c.cod_tip_deudor,
                 pc.cod_plazo,
                 nvl(mo.cod_pro_contable, 0),
                 d.categoria,
                 ct.tipo,
                 ct.tip_interes,
                 nvl(ct.tip_renovacion, 'A'),
                 d.estado,
                 fup_obt_sec_rubro(ct.cod_sec_credito);
    --
    v_cod_tip_asiento  ge_tip_asientos.cod_tip_asiento%TYPE;
    v_cod_tip_asiento2 ge_tip_asientos.cod_tip_asiento%TYPE;
    r_gtasi            ge_tip_asientos%ROWTYPE;
    v_redondeo         NUMBER(5);
    --
    CURSOR c_tip_asientos IS
       SELECT *
         FROM ge_tip_asientos
        WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
          AND cod_moneda = v_cod_moneda
          AND (cod_sec_contable = v_cod_sec_contable OR cod_sec_contable IS NULL)
          AND (ind_residente = v_residente OR ind_residente = 'X')
          AND (est_cuenta = v_est_cuenta OR nvl(est_cuenta, 'X') = 'X')
          AND (tip_cuenta = v_tip_cuenta OR nvl(tip_cuenta, 'X') = 'X')
          AND (tip_interes = v_tip_interes OR nvl(tip_interes, 'X') = 'X')
          AND (tip_renovacion = v_tip_renovacion OR nvl(tip_renovacion, 'X') = 'X')
          AND (cat_automatica = v_cat_automatica OR nvl(cat_automatica, -1) = -1);
  BEGIN
    v_msj := ' Intereses devengados ';
    OPEN cur3;
    LOOP
       FETCH cur3
          INTO v_cod_modulo,
               v_cod_modalidad,
               v_cod_oficina,
               v_cod_moneda,
               v_mto_interes,
               v_cod_sec_contable,
               v_residente,
               v_tip_deudor,
               v_cod_plazo,
               v_cod_pro_contable,
               v_cat_automatica,
               v_tip_cuenta,
               v_tip_interes,
               v_tip_renovacion,
               v_est_cuenta,
               v_cod_sec_rubro;
       EXIT WHEN cur3%NOTFOUND;
       --- ve el tipo de asiento por el CREDITO
       BEGIN
          SELECT cod_tip_asiento, descripcion, cod_tip_asiento2
            INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
            FROM ge_transacciones
           WHERE cod_modulo = v_cod_modulo
             AND cod_modalidad = v_cod_modalidad
             AND cod_transaccion = 901
             AND cod_tip_asiento IS NOT NULL;
       EXCEPTION
          WHEN no_data_found THEN
             raise_application_error(-20000,
                                     'Transaccion ' || to_char(v_cod_modulo) || '-' ||
                                      to_char(v_cod_modalidad) ||
                                      '-901 no tiene asiento de Credito definido.');
          WHEN OTHERS THEN
             IF SQLCODE <= -20000 THEN
                RAISE;
             ELSE
                raise_application_error(-20001, 'Error lp_int_devengados ' || SQLERRM);
             END IF;
       END;
       ------------------
       -- ve la moneda --
       ------------------
       /*--v_cod_mon_local y v_fec_actual, son inicializados en pra_gen_asientos*/
       v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad,
                                         v_cod_mon_local);
       IF v_cod_moneda = v_cod_mon_local THEN
          -- es moneda nacional --
          ------------------------
          xx_immovml := v_mto_interes;
          xx_immovex := 0;
          xx_vltasci := 0;
       ELSE
          /*if fug_obt_tip_implementacion = 1 then
             -- se obtiene la cotizacion de venta
             v_mto_cotizacion := pag_gen.fu_obt_cot_venta(v_cod_moneda, v_fec_actual);
          else*/
          -- se obtiene la cotizacion de cierre
          v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
          --end if;
          xx_immovml := round(v_mto_interes * v_mto_cotizacion, v_redondeo);
          xx_immovex := v_mto_interes;
          xx_vltasci := v_mto_cotizacion;
       END IF;
       ----- ciclo para GE_TIP_ASIENTOS ------
       -------------------------------
       IF c_tip_asientos%ISOPEN THEN
          CLOSE c_tip_asientos;
       END IF;
       OPEN c_tip_asientos;
       v_nro_linea := 0;
       LOOP
          FETCH c_tip_asientos
             INTO r_gtasi;
          EXIT WHEN c_tip_asientos%NOTFOUND;
          ---Reemplaza el valor del tipo de deudor, si importa-
          IF r_gtasi.ind_deudor = 'S' THEN
             v_cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                            substr(r_gtasi.cod_rubro, 11, 5);
          ELSE
             v_cod_rubro := r_gtasi.cod_rubro;
          END IF;
          ---Reemplaza el codigo del plazo si es necesario -----
          IF r_gtasi.ind_plazo = 'S' THEN
             v_cod_rubro := substr(v_cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                            substr(v_cod_rubro, 4, 12);
          END IF;
          ---Reemplaza el codigo del producto -----------------------
          IF r_gtasi.ind_producto = 'S' THEN
             v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                            ltrim(to_char(v_cod_pro_contable, '000')) ||
                            substr(v_cod_rubro, 14, 2);
          END IF;
          --Reemplaza el código del sector de crédito
          IF substr(r_gtasi.cod_rubro, 11, 3) = 'SEC' THEN
             v_cod_rubro := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_sec_rubro, '000')) ||
                            substr(r_gtasi.cod_rubro, 14, 2);
          END IF;
          ------------------------------------------------------
          v_encontro := 'S';
          lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
          IF v_encontro = 'N' THEN
             v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
             --v_cod_rubro  := '999999999999999';
             v_mon_rubro := v_cod_mon_local;
          END IF;
          IF v_mon_rubro = v_cod_mon_local THEN
             -- moneda local --
             wh_immovex := 0;
             wh_vltasci := 0;
          ELSE
             wh_immovex := xx_immovex;
             wh_vltasci := xx_vltasci;
          END IF;
          -- ve el tipo de movimiento --
          ------------------------------
          v_tip_movimiento := r_gtasi.tip_movimiento;
          IF xx_immovml > 0 THEN
             v_tip_movimiento := r_gtasi.tip_movimiento;
             wh_immovml       := xx_immovml;
          ELSE
             wh_immovml := xx_immovml * -1;
             wh_immovex := wh_immovex * -1;
             IF r_gtasi.tip_movimiento = 'C' THEN
                v_tip_movimiento := 'D';
             ELSE
                v_tip_movimiento := 'C';
             END IF;
          END IF;
          ------------------------------------------------------
          wh_dcrefer        := 'REVRE4.';
          wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                      to_char(901) || ' ' || v_des_transaccion, 1, 60);
          vh_cod_oficina    := v_cod_oficina;
          vh_cod_modulo     := v_cod_modulo;
          vh_cod_modalidad  := v_cod_modalidad;
          vh_cod_ofi_origen := v_cod_oficina;
          wh_lgprote        := 'N';
          wh_lgdeact        := 'N';
          wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
          vh_nro_asiento    := 0;
          v_cod_mod_padre   := v_cod_modulo;
          v_cod_mad_padre   := v_cod_modalidad;
          -----
          IF wh_immovml <> 0 THEN
             v_nro_linea := v_nro_linea + 1;
             --- Cargar registro de asientos detalles
             r_baade.fecha          := v_fec_actual;
             r_baade.cod_oficina    := vh_cod_oficina;
             r_baade.nro_asiento    := 0;
             r_baade.nro_linea      := v_nro_linea;
             r_baade.cod_rubro      := v_cod_rubro;
             r_baade.tip_movimiento := v_tip_movimiento;
             r_baade.mto_mon_rubro  := wh_immovex;
             r_baade.mto_mon_local  := wh_immovml;
             r_baade.descripcion    := wh_dcdescr;
             r_baade.referencia     := wh_dcrefer;
             r_baade.protegido      := wh_lgprote;
             r_baade.actualizado    := wh_lgdeact;
             r_baade.val_cotizacion := wh_vltasci;
             r_baade.distribuido    := wh_lgctadi;
             r_baade.ref_movimiento := NULL;
             r_baade.cod_modulo     := v_cod_mod_padre;
             r_baade.cod_modalidad  := v_cod_mad_padre;
             r_baade.cod_ofi_origen := v_cod_ofi_origen;
             lp_ins_asi_aut_det(r_baade);
          END IF;
       END LOOP; -- fin de tipo de asientos --
       --- ve el tipo de asiento por el DEBITO
       BEGIN
          SELECT cod_tip_asiento, descripcion, cod_tip_asiento
            INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
            FROM ge_transacciones
           WHERE cod_modulo = v_cod_modulo
             AND cod_modalidad = v_cod_modalidad
             AND cod_transaccion = 903
             AND cod_tip_asiento IS NOT NULL;
       EXCEPTION
          WHEN no_data_found THEN
             raise_application_error(-20000,
                                     'Transaccion ' || to_char(v_cod_modulo) || '-' ||
                                      to_char(v_cod_modalidad) ||
                                      '-903 no tiene asiento de Debito definido.');
          WHEN OTHERS THEN
             IF SQLCODE <= -20000 THEN
                RAISE;
             ELSE
                raise_application_error(-20002, 'Error lp_int_devengados ' || SQLERRM);
             END IF;
       END;
       ------------------
       -- ve la moneda --
       ------------------
       /*--v_cod_mon_local y v_fec_actual, son inicializados en pra_gen_asientos*/
       IF v_cod_moneda = v_cod_mon_local THEN
          -- es moneda nacional --
          ------------------------
          xx_immovml := v_mto_interes;
          xx_immovex := 0;
          xx_vltasci := 0;
       ELSE
          /*if fug_obt_tip_implementacion = 1 then
             -- se obtiene la cotizacion de venta
             v_mto_cotizacion := pag_gen.fu_obt_cot_venta(v_cod_moneda, v_fec_actual);
          else*/
          -- se obtiene la cotizacion de cierre
          v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
          --end if;
          xx_immovml := round(v_mto_interes * v_mto_cotizacion, v_redondeo);
          xx_immovex := v_mto_interes;
          xx_vltasci := v_mto_cotizacion;
       END IF;
       ----- ciclo para GE_TIP_ASIENTOS ------
       -------------------------------
       IF c_tip_asientos%ISOPEN THEN
          CLOSE c_tip_asientos;
       END IF;
       OPEN c_tip_asientos;
       v_nro_linea := 0;
       LOOP
          FETCH c_tip_asientos
             INTO r_gtasi;
          EXIT WHEN c_tip_asientos%NOTFOUND;
          ---Reemplaza el valor del tipo de deudor, si importa-
          IF r_gtasi.ind_deudor = 'S' THEN
             v_cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                            substr(r_gtasi.cod_rubro, 11, 5);
          ELSE
             v_cod_rubro := r_gtasi.cod_rubro;
          END IF;
          ---Reemplaza el codigo del plazo si es necesario -----
          IF r_gtasi.ind_plazo = 'S' THEN
             v_cod_rubro := substr(v_cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                            substr(v_cod_rubro, 4, 12);
          END IF;
          ---Reemplaza el codigo del producto -----------------------
          IF r_gtasi.ind_producto = 'S' THEN
             v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                            ltrim(to_char(v_cod_pro_contable, '000')) ||
                            substr(v_cod_rubro, 14, 2);
          END IF;
          --Reemplaza el código del sector de crédito
          IF substr(r_gtasi.cod_rubro, 11, 3) = 'SEC' THEN
             v_cod_rubro := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_sec_rubro, '000')) ||
                            substr(r_gtasi.cod_rubro, 14, 2);
          END IF;
          ------------------------------------------------------
          v_encontro := 'S';
          lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
          IF v_encontro = 'N' THEN
             v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
             --v_cod_rubro  := '999999999999999';
             v_mon_rubro := v_cod_mon_local;
          END IF;
          IF v_mon_rubro = v_cod_mon_local THEN
             -- moneda local --
             wh_immovex := 0;
             wh_vltasci := 0;
          ELSE
             wh_immovex := xx_immovex;
             wh_vltasci := xx_vltasci;
          END IF;
          -- ve el tipo de movimiento --
          ------------------------------
          v_tip_movimiento := r_gtasi.tip_movimiento;
          IF xx_immovml > 0 THEN
             v_tip_movimiento := r_gtasi.tip_movimiento;
             wh_immovml       := xx_immovml;
          ELSE
             wh_immovml := xx_immovml * -1;
             wh_immovex := wh_immovex * -1;
             IF r_gtasi.tip_movimiento = 'C' THEN
                v_tip_movimiento := 'D';
             ELSE
                v_tip_movimiento := 'C';
             END IF;
          END IF;
          ------------------------------------------------------
          wh_dcrefer        := 'DEVENG.';
          wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                      to_char(903) || ' ' || v_des_transaccion, 1, 60);
          vh_cod_oficina    := v_cod_oficina;
          vh_cod_modulo     := v_cod_modulo;
          vh_cod_modalidad  := v_cod_modalidad;
          vh_cod_ofi_origen := v_cod_oficina;
          wh_lgprote        := 'N';
          wh_lgdeact        := 'N';
          wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
          vh_nro_asiento    := 0;
          v_cod_mod_padre   := v_cod_modulo;
          v_cod_mad_padre   := v_cod_modalidad;
          -----
          IF wh_immovml <> 0 THEN
             v_nro_linea := v_nro_linea + 1;
             --- Cargar registro de asientos detalles
             r_baade.fecha          := v_fec_actual;
             r_baade.cod_oficina    := vh_cod_oficina;
             r_baade.nro_asiento    := 0;
             r_baade.nro_linea      := v_nro_linea;
             r_baade.cod_rubro      := v_cod_rubro;
             r_baade.tip_movimiento := v_tip_movimiento;
             r_baade.mto_mon_rubro  := wh_immovex;
             r_baade.mto_mon_local  := wh_immovml;
             r_baade.descripcion    := wh_dcdescr;
             r_baade.referencia     := wh_dcrefer;
             r_baade.protegido      := wh_lgprote;
             r_baade.ref_movimiento := NULL;
             r_baade.actualizado    := wh_lgdeact;
             r_baade.val_cotizacion := wh_vltasci;
             r_baade.distribuido    := wh_lgctadi;
             r_baade.cod_modulo     := v_cod_mod_padre;
             r_baade.cod_modalidad  := v_cod_mad_padre;
             r_baade.cod_ofi_origen := v_cod_ofi_origen;
             lp_ins_asi_aut_det(r_baade);
          END IF;
       END LOOP; -- fin de tipo de asientos --
       close c_tip_asientos; --FIELDESK-61066
    END LOOP; -- fin del ciclo de intereses devengados --
    close cur3;--FIELDESK-61066
    prg_act_par_dinamico('IND_GEN_ASI_AJU_RE4', NULL, NULL, NULL, NULL, 'N');
   END;


   -- Insteres Devengado de Prestamos Cancelados re4
   PROCEDURE lp_int_dev_prestamos_can_re4 IS
      v_cod_mad_padre    ge_modalidades.cod_modalidad%TYPE;
      v_cod_mod_padre    ba_modulos.cod_modulo%TYPE;
      v_tip_movimiento   ge_tip_asientos.tip_movimiento%TYPE;
      v_mon_rubro        cb_rubros.cod_moneda%TYPE;
      v_mto_cotizacion   ge_cotizaciones.val_conversion%TYPE;
      v_des_transaccion  ge_transacciones.descripcion%TYPE;
      v_cod_sec_contable ge_sec_contables.cod_sec_contable%TYPE;
      v_cod_ofi_origen   ba_oficinas.cod_oficina%TYPE;
      v_cod_plazo        ge_plz_contables.cod_plazo%TYPE;
      v_tip_deudor       ge_clientes.cod_tip_deudor%TYPE;
      v_residente        ge_clientes.residente%TYPE;
      v_mto_interes      ah_devengados.mto_interes%TYPE;
      v_cod_moneda       ah_cta_vistas.cod_moneda%TYPE;
      v_cod_oficina      ah_cta_vistas.cod_oficina%TYPE;
      v_cod_modalidad    ah_cta_vistas.cod_modalidad%TYPE;
      v_cod_modulo       ah_cta_vistas.cod_modulo%TYPE;
      v_nro_cuenta       pr_cta_prestamos.nro_cuenta%type;
      v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
      v_est_cuenta       ge_tip_asientos.est_cuenta%TYPE;
      v_tip_cuenta       ge_tip_asientos.tip_cuenta%TYPE;
      v_tip_interes      ge_tip_asientos.tip_interes%TYPE;
      v_tip_renovacion   ge_tip_asientos.tip_renovacion%TYPE;
      v_cat_automatica   ge_tip_asientos.cat_automatica%TYPE;
      v_nro_orden        number;
      xx_immovml         NUMBER;
      xx_immovex         NUMBER;
      xx_vltasci         NUMBER;
      --
      vh_nro_asiento    NUMBER;
      wh_immovex        NUMBER;
      wh_vltasci        NUMBER;
      vh_cod_oficina    pr_cta_prestamos.cod_oficina%TYPE;
      vh_cod_ofi_origen pr_cta_prestamos.cod_oficina%TYPE;
      vh_cod_modulo     pr_cta_prestamos.cod_modulo%TYPE;
      vh_cod_modalidad  pr_cta_prestamos.cod_modalidad%TYPE;

      wh_immovml NUMBER;
      wh_dcrefer VARCHAR2(11);
      wh_lgprote VARCHAR2(1);
      wh_lgdeact VARCHAR2(1);
      wh_lgctadi VARCHAR2(1);
      wh_dcdescr VARCHAR2(60);
      --
      v_nro_linea ge_tip_asientos.nro_linea%TYPE;
      v_cod_rubro cb_rubros.cod_rubro%TYPE; --wh_cdcuent
      v_encontro  VARCHAR2(1);
      v_msj       VARCHAR2(250);
      --
      v_cod_sec_rubro ge_con_transacciones.cod_sec_rubro%TYPE;
      --
      v_cod_rubro_gs  varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_INT_DEV_RE4',null,null,'GS', null,null);
      v_cod_rubro_usd varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_INT_DEV_RE4',null,null,'USD', null,null);

      CURSOR cur3 IS
         SELECT ct.cod_modulo,
                ct.cod_modalidad,
                ct.cod_oficina,
                ct.cod_moneda,
                SUM(nvl(d.mto_dev_actual, 0)),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                nvl(mo.cod_pro_contable, 0),
                d.categoria,
                ct.tipo,
                ct.tip_interes,
                nvl(ct.tip_renovacion, 'A') tip_renovacion,
                d.estado,
                fup_obt_sec_rubro(ct.cod_sec_credito),
                ct.nro_cuenta
           FROM ge_plz_contables pc,
                pr_devengados    d,
                pr_cta_prestamos ct,
                ge_clientes      c,
                ge_cta_clientes  cc,
                ge_modalidades   mo
          WHERE d.fecha = v_fec_actual
            AND d.nro_cuenta = ct.nro_cuenta
            AND d.nro_cuenta = cc.nro_cuenta
            AND relacion = 'P'
            AND c.cod_persona = cc.cod_persona
            AND mo.cod_modulo = ct.cod_modulo
            AND mo.cod_modalidad = ct.cod_modalidad
           --
            AND pc.can_dias =
                (SELECT MIN(can_dias)
                   FROM ge_plz_contables
                  WHERE can_dias >= (ct.fec_vencimiento - ct.fec_inicio))
            --Solo el dia que se cancela el contra asiento
            and exists (select 1
                 from GE_DEV_RES4 w
                  where w.nro_cuenta= ct.nro_cuenta
                    and trunc(w.fec_cancelacion)= trunc(v_fec_actual))
          GROUP BY ct.cod_modulo,
                   ct.cod_modalidad,
                   ct.cod_oficina,
                   ct.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   nvl(mo.cod_pro_contable, 0),
                   d.categoria,
                   ct.tipo,
                   ct.tip_interes,
                   nvl(ct.tip_renovacion, 'A'),
                   d.estado,
                   fup_obt_sec_rubro(ct.cod_sec_credito),
                   ct.nro_cuenta
         UNION
             SELECT ct.cod_modulo,
                ct.cod_modalidad,
                ct.cod_oficina,
                ct.cod_moneda,
                SUM(nvl(d.mto_dev_actual, 0)),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                nvl(mo.cod_pro_contable, 0),
                d.categoria,
                ct.tipo,
                ct.tip_interes,
                nvl(ct.tip_renovacion, 'A') tip_renovacion,
                d.estado,
                fup_obt_sec_rubro(ct.cod_sec_credito),
                ct.nro_cuenta
           FROM ge_plz_contables pc,
                pr_devengados    d,
                pr_cta_prestamos ct,
                ge_clientes      c,
                ge_cta_clientes  cc,
                ge_modalidades   mo,
                PR_CTA_PRE_REF_RES4 w
          WHERE d.fecha = nvl(w.fec_proceso,w.fec_mov_can) /* v_fec_actual */
            AND d.nro_cuenta = ct.nro_cuenta
            AND d.nro_cuenta = cc.nro_cuenta
            AND relacion = 'P'
            AND c.cod_persona = cc.cod_persona
            AND mo.cod_modulo = ct.cod_modulo
            AND mo.cod_modalidad = ct.cod_modalidad
            and (d.nro_cuenta= w.nro_cuenta
            and w.tip_carga='O'
            and trunc(w.fec_insercion)= trunc(sysdate)
	    and w.fec_mov_can is not null)
           --
            AND pc.can_dias =
                (SELECT MIN(can_dias)
                   FROM ge_plz_contables
                  WHERE can_dias >= (ct.fec_vencimiento - ct.fec_inicio))
            --Solo el dia que se cancela el contra asiento
            and exists (select 1
                 from GE_DEV_RES4 w
                  where w.nro_cuenta= ct.nro_cuenta
                    and trunc(w.fec_cancelacion)= trunc(nvl(w.fec_proceso,w.fec_mov_can)/*v_fec_actual*/))
          GROUP BY ct.cod_modulo,
                   ct.cod_modalidad,
                   ct.cod_oficina,
                   ct.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   nvl(mo.cod_pro_contable, 0),
                   d.categoria,
                   ct.tipo,
                   ct.tip_interes,
                   nvl(ct.tip_renovacion, 'A'),
                   d.estado,
                   fup_obt_sec_rubro(ct.cod_sec_credito),
                   ct.nro_cuenta;
      --
      v_cod_tip_asiento  ge_tip_asientos.cod_tip_asiento%TYPE;
      v_cod_tip_asiento2 ge_tip_asientos.cod_tip_asiento%TYPE;
      r_gtasi            ge_tip_asientos%ROWTYPE;
      v_redondeo         NUMBER(5);
      --
      CURSOR c_tip_asientos IS
         SELECT *
           FROM ge_tip_asientos
          WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
            AND cod_moneda = v_cod_moneda
            AND (cod_sec_contable = v_cod_sec_contable OR cod_sec_contable IS NULL)
            AND (ind_residente = v_residente OR ind_residente = 'X')
            AND (est_cuenta = v_est_cuenta OR nvl(est_cuenta, 'X') = 'X')
            AND (tip_cuenta = v_tip_cuenta OR nvl(tip_cuenta, 'X') = 'X')
            AND (tip_interes = v_tip_interes OR nvl(tip_interes, 'X') = 'X')
            AND (tip_renovacion = v_tip_renovacion OR nvl(tip_renovacion, 'X') = 'X')
            AND (cat_automatica = v_cat_automatica OR nvl(cat_automatica, -1) = -1);
   BEGIN
      v_msj := ' Intereses devengados ';
      OPEN cur3;
      LOOP
         FETCH cur3
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_moneda,
                 v_mto_interes,
                 v_cod_sec_contable,
                 v_residente,
                 v_tip_deudor,
                 v_cod_plazo,
                 v_cod_pro_contable,
                 v_cat_automatica,
                 v_tip_cuenta,
                 v_tip_interes,
                 v_tip_renovacion,
                 v_est_cuenta,
                 v_cod_sec_rubro,
                 v_nro_cuenta;
         EXIT WHEN cur3%NOTFOUND;
         --Obtenemos el orden de Insercion del dia,ultimo
         v_nro_orden:=0;
         begin
           select nvl(max(a.nro_orden),0)
             into v_nro_orden
             from GE_DEV_RES4 a
               where a.nro_cuenta=v_nro_cuenta;
         exception
            when others then    
             v_nro_orden:=0;
         end;
         if nvl(v_nro_orden,0) > 0 then
             --Actualizamos Cabecera con total devengado
             update GE_DEV_RES4 a
                   set a.mto_dev_cancelacion= v_mto_interes
                    where a.nro_cuenta=v_nro_cuenta
                      and a.nro_orden= v_nro_orden;
         end if;
         --- ve el tipo de asiento por el CREDITO
         BEGIN
            SELECT cod_tip_asiento, descripcion, cod_tip_asiento2
              INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = 901
               AND cod_tip_asiento IS NOT NULL;

         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'Transaccion ' || to_char(v_cod_modulo) || '-' ||
                                        to_char(v_cod_modalidad) ||
                                        '-901 no tiene asiento de Credito definido.');
            WHEN OTHERS THEN
               IF SQLCODE <= -20000 THEN
                  RAISE;
               ELSE
                  raise_application_error(-20001, 'Error lp_int_devengados ' || SQLERRM);
               END IF;
         END;
         ------------------
         -- ve la moneda --
         ------------------
         /*--v_cod_mon_local y v_fec_actual, son inicializados en pra_gen_asientos*/
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad,
                                           v_cod_mon_local);
         IF v_cod_moneda = v_cod_mon_local THEN
            -- es moneda nacional --
            ------------------------
            xx_immovml := v_mto_interes;
            xx_immovex := 0;
            xx_vltasci := 0;
         ELSE
            /*if fug_obt_tip_implementacion = 1 then
               -- se obtiene la cotizacion de venta
               v_mto_cotizacion := pag_gen.fu_obt_cot_venta(v_cod_moneda, v_fec_actual);
            else*/
            -- se obtiene la cotizacion de cierre
            v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            --end if;
            xx_immovml := round(v_mto_interes * v_mto_cotizacion, v_redondeo);
            xx_immovex := v_mto_interes;
            xx_vltasci := v_mto_cotizacion;
         END IF;
         ----- ciclo para GE_TIP_ASIENTOS ------
         -------------------------------
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos;
         v_nro_linea := 0;
         LOOP
            FETCH c_tip_asientos
               INTO r_gtasi;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            ---Reemplaza el valor del tipo de deudor, si importa-
            IF r_gtasi.ind_deudor = 'S' THEN
               v_cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                              substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               v_cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---Reemplaza el codigo del plazo si es necesario -----
            IF r_gtasi.ind_plazo = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                              substr(v_cod_rubro, 4, 12);
            END IF;
            ---Reemplaza el codigo del producto -----------------------
            IF r_gtasi.ind_producto = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                              ltrim(to_char(v_cod_pro_contable, '000')) ||
                              substr(v_cod_rubro, 14, 2);
            END IF;
            --Reemplaza el código del sector de crédito
            IF substr(r_gtasi.cod_rubro, 11, 3) = 'SEC' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_sec_rubro, '000')) ||
                              substr(r_gtasi.cod_rubro, 14, 2);
            END IF;
            ------------------------------------------------------
            v_encontro := 'S';
            lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
               --v_cod_rubro  := '999999999999999';
               v_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_mon_rubro = v_cod_mon_local THEN
               -- moneda local --
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            v_tip_movimiento := r_gtasi.tip_movimiento;
            IF xx_immovml > 0 THEN
               v_tip_movimiento := r_gtasi.tip_movimiento;
               wh_immovml       := xx_immovml;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            ------------------------------------------------------
            wh_dcrefer        := 'CAINTNOD.';
            wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                        to_char(901) || ' ' || v_des_transaccion, 1, 60);
            vh_cod_oficina    := v_cod_oficina;
            vh_cod_modulo     := v_cod_modulo;
            vh_cod_modalidad  := v_cod_modalidad;
            vh_cod_ofi_origen := v_cod_oficina;
            wh_lgprote        := 'N';
            wh_lgdeact        := 'N';
            wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
            vh_nro_asiento    := 0;
            v_cod_mod_padre   := v_cod_modulo;
            v_cod_mad_padre   := v_cod_modalidad;
            -----
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               --reemplazamos por rubros correspondientes(par_dinamicos)
               if v_mon_rubro = v_cod_mon_local then
                 --r_baade.cod_rubro      := v_cod_rubro;
                 r_baade.cod_rubro := v_cod_rubro_gs;
               else
                 r_baade.cod_rubro := v_cod_rubro_usd;
               end if;
                r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := wh_lgprote;
               r_baade.actualizado    := wh_lgdeact;
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.ref_movimiento := NULL;
               r_baade.cod_modulo     := v_cod_mod_padre;
               r_baade.cod_modalidad  := v_cod_mad_padre;
               r_baade.cod_ofi_origen := v_cod_ofi_origen;
               lp_ins_asi_aut_det(r_baade);
            END IF;
         END LOOP; -- fin de tipo de asientos --
         --- ve el tipo de asiento por el DEBITO
         BEGIN
            SELECT cod_tip_asiento, descripcion, cod_tip_asiento2
              INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = 901
               AND cod_tip_asiento IS NOT NULL;

         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'Transaccion ' || to_char(v_cod_modulo) || '-' ||
                                        to_char(v_cod_modalidad) ||
                                        '-903 no tiene asiento de Debito definido.');
            WHEN OTHERS THEN
               IF SQLCODE <= -20000 THEN
                  RAISE;
               ELSE
                  raise_application_error(-20002, 'Error lp_int_devengados ' || SQLERRM);
               END IF;
         END;
         ------------------
         -- ve la moneda --
         ------------------
         /*--v_cod_mon_local y v_fec_actual, son inicializados en pra_gen_asientos*/
         IF v_cod_moneda = v_cod_mon_local THEN
            -- es moneda nacional --
            ------------------------
            xx_immovml := v_mto_interes;
            xx_immovex := 0;
            xx_vltasci := 0;
         ELSE
            /*if fug_obt_tip_implementacion = 1 then
               -- se obtiene la cotizacion de venta
               v_mto_cotizacion := pag_gen.fu_obt_cot_venta(v_cod_moneda, v_fec_actual);
            else*/
            -- se obtiene la cotizacion de cierre
            v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            --end if;
            xx_immovml := round(v_mto_interes * v_mto_cotizacion, v_redondeo);
            xx_immovex := v_mto_interes;
            xx_vltasci := v_mto_cotizacion;
         END IF;
         ----- ciclo para GE_TIP_ASIENTOS ------
         -------------------------------
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos;
         v_nro_linea := 0;
         LOOP
            FETCH c_tip_asientos
               INTO r_gtasi;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            ---Reemplaza el valor del tipo de deudor, si importa-
            IF r_gtasi.ind_deudor = 'S' THEN
               v_cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                              substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               v_cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---Reemplaza el codigo del plazo si es necesario -----
            IF r_gtasi.ind_plazo = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                              substr(v_cod_rubro, 4, 12);
            END IF;
            ---Reemplaza el codigo del producto -----------------------
            IF r_gtasi.ind_producto = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                              ltrim(to_char(v_cod_pro_contable, '000')) ||
                              substr(v_cod_rubro, 14, 2);
            END IF;
            --Reemplaza el código del sector de crédito
            IF substr(r_gtasi.cod_rubro, 11, 3) = 'SEC' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_sec_rubro, '000')) ||
                              substr(r_gtasi.cod_rubro, 14, 2);
            END IF;
            ------------------------------------------------------
            v_encontro := 'S';
            lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
               --v_cod_rubro  := '999999999999999';
               v_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_mon_rubro = v_cod_mon_local THEN
               -- moneda local --
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            v_tip_movimiento :=r_gtasi.tip_movimiento;
            IF xx_immovml > 0 THEN
               v_tip_movimiento := r_gtasi.tip_movimiento;
               wh_immovml       := xx_immovml;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            --Siempre Débito
            v_tip_movimiento := 'D';
            ------------------------------------------------------
            wh_dcrefer        := 'CAINTNOD.';
            wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                        to_char(903) || ' ' || v_des_transaccion, 1, 60);
            vh_cod_oficina    := v_cod_oficina;
            vh_cod_modulo     := v_cod_modulo;
            vh_cod_modalidad  := v_cod_modalidad;
            vh_cod_ofi_origen := v_cod_oficina;
            wh_lgprote        := 'N';
            wh_lgdeact        := 'N';
            wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
            vh_nro_asiento    := 0;
            v_cod_mod_padre   := v_cod_modulo;
            v_cod_mad_padre   := v_cod_modalidad;
            -----
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := v_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := wh_lgprote;
               r_baade.ref_movimiento := NULL;
               r_baade.actualizado    := wh_lgdeact;
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.cod_modulo     := v_cod_mod_padre;
               r_baade.cod_modalidad  := v_cod_mad_padre;
               r_baade.cod_ofi_origen := v_cod_ofi_origen;
               lp_ins_asi_aut_det(r_baade);
               
               
               
               
               
               
               
               
            END IF;
         END LOOP; -- fin de tipo de asientos --
         close c_tip_asientos; --FIELDESK-61066
      END LOOP; -- fin del ciclo de intereses devengados --
      close cur3; --FIELDESK-61066
   END;

   -- Insteres Devengado de Prestamos RE4
   PROCEDURE lp_int_dev_prestamos_RE4 IS
      v_cod_mad_padre    ge_modalidades.cod_modalidad%TYPE;
      v_cod_mod_padre    ba_modulos.cod_modulo%TYPE;
      v_tip_movimiento   ge_tip_asientos.tip_movimiento%TYPE;
      v_mon_rubro        cb_rubros.cod_moneda%TYPE;
      v_mto_cotizacion   ge_cotizaciones.val_conversion%TYPE;
      v_des_transaccion  ge_transacciones.descripcion%TYPE;
      v_cod_sec_contable ge_sec_contables.cod_sec_contable%TYPE;
      v_cod_ofi_origen   ba_oficinas.cod_oficina%TYPE;
      v_cod_plazo        ge_plz_contables.cod_plazo%TYPE;
      v_tip_deudor       ge_clientes.cod_tip_deudor%TYPE;
      v_residente        ge_clientes.residente%TYPE;
      v_mto_interes      ah_devengados.mto_interes%TYPE;
      v_cod_moneda       ah_cta_vistas.cod_moneda%TYPE;
      v_cod_oficina      ah_cta_vistas.cod_oficina%TYPE;
      v_cod_modalidad    ah_cta_vistas.cod_modalidad%TYPE;
      v_cod_modulo       ah_cta_vistas.cod_modulo%TYPE;
      v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
      v_est_cuenta       ge_tip_asientos.est_cuenta%TYPE;
      v_tip_cuenta       ge_tip_asientos.tip_cuenta%TYPE;
      v_tip_interes      ge_tip_asientos.tip_interes%TYPE;
      v_tip_renovacion   ge_tip_asientos.tip_renovacion%TYPE;
      v_cat_automatica   ge_tip_asientos.cat_automatica%TYPE;
      xx_immovml         NUMBER;
      xx_immovex         NUMBER;
      xx_vltasci         NUMBER;
      --
      vh_nro_asiento    NUMBER;
      wh_immovex        NUMBER;
      wh_vltasci        NUMBER;
      vh_cod_oficina    pr_cta_prestamos.cod_oficina%TYPE;
      vh_cod_ofi_origen pr_cta_prestamos.cod_oficina%TYPE;
      vh_cod_modulo     pr_cta_prestamos.cod_modulo%TYPE;
      vh_cod_modalidad  pr_cta_prestamos.cod_modalidad%TYPE;

      wh_immovml NUMBER;
      wh_dcrefer VARCHAR2(11);
      wh_lgprote VARCHAR2(1);
      wh_lgdeact VARCHAR2(1);
      wh_lgctadi VARCHAR2(1);
      wh_dcdescr VARCHAR2(60);
      --
      v_nro_linea ge_tip_asientos.nro_linea%TYPE;
      v_cod_rubro cb_rubros.cod_rubro%TYPE; --wh_cdcuent
      v_encontro  VARCHAR2(1);
      v_msj       VARCHAR2(250);
      --
      v_cod_sec_rubro ge_con_transacciones.cod_sec_rubro%TYPE;
    v_cod_rubro_gs  varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_INT_DEV_RE4',null,null,'GS', null,null);
      v_cod_rubro_usd varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_INT_DEV_RE4',null,null,'USD', null,null);

      CURSOR cur3 IS
         SELECT d.cod_modulo,
                d.cod_modalidad,
                d.cod_oficina,
                d.cod_moneda,
                sum(nvl(d.mto_dev_actual, 0)),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                nvl(mo.cod_pro_contable, 0),
                d.categoria,
                d.tipo,
                d.tip_interes,
                nvl(d.tip_renovacion, 'A') tip_renovacion,
                d.estado,
                fup_obt_sec_rubro(d.cod_sec_credito)
           FROM ge_plz_contables pc,
                GE_DEV_RES4/*pr_devengados_re4*/    d,
                --pr_cta_prestamos_re4 ct,
                ge_clientes      c,
                ge_cta_clientes  cc,
                ge_modalidades   mo
          WHERE d.fec_ult_devengado = v_fec_actual
            --AND d.nro_cuenta = ct.nro_cuenta
            --AND d.nro_cuenta = cc.nro_cuenta
            and cc.nro_cuenta=d.nro_cuenta
            AND relacion = 'P'
            AND c.cod_persona = cc.cod_persona
            AND mo.cod_modulo = d.cod_modulo
            AND mo.cod_modalidad = d.cod_modalidad
            AND pc.can_dias =
                (SELECT MIN(can_dias)
                   FROM ge_plz_contables
                  WHERE can_dias >= (d.fec_dev_fin- d.fec_dev_inicio/*ct.fec_vencimiento - ct.fec_inicio*/))
          GROUP BY d.cod_modulo,
                   d.cod_modalidad,
                   d.cod_oficina,
                   d.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   nvl(mo.cod_pro_contable, 0),
                   d.categoria,
                   d.tipo,
                   d.tip_interes,
                   nvl(d.tip_renovacion, 'A'),
                   d.estado,
                   fup_obt_sec_rubro(d.cod_sec_credito);
      --
      v_cod_tip_asiento  ge_tip_asientos.cod_tip_asiento%TYPE;
      v_cod_tip_asiento2 ge_tip_asientos.cod_tip_asiento%TYPE;
      r_gtasi            ge_tip_asientos%ROWTYPE;
      v_redondeo         NUMBER(5);
      --
      CURSOR c_tip_asientos IS
         SELECT *
           FROM ge_tip_asientos
          WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
            AND cod_moneda = v_cod_moneda
            AND (cod_sec_contable = v_cod_sec_contable OR cod_sec_contable IS NULL)
            AND (ind_residente = v_residente OR ind_residente = 'X')
            AND (est_cuenta = v_est_cuenta OR nvl(est_cuenta, 'X') = 'X')
            AND (tip_cuenta = v_tip_cuenta OR nvl(tip_cuenta, 'X') = 'X')
            AND (tip_interes = v_tip_interes OR nvl(tip_interes, 'X') = 'X')
            AND (tip_renovacion = v_tip_renovacion OR nvl(tip_renovacion, 'X') = 'X')
            AND (cat_automatica = v_cat_automatica OR nvl(cat_automatica, -1) = -1);
   BEGIN
      v_msj := ' Intereses devengados ';
      OPEN cur3;
      LOOP
         FETCH cur3
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_moneda,
                 v_mto_interes,
                 v_cod_sec_contable,
                 v_residente,
                 v_tip_deudor,
                 v_cod_plazo,
                 v_cod_pro_contable,
                 v_cat_automatica,
                 v_tip_cuenta,
                 v_tip_interes,
                 v_tip_renovacion,
                 v_est_cuenta,
                 v_cod_sec_rubro;
         EXIT WHEN cur3%NOTFOUND;
         --- ve el tipo de asiento por el CREDITO
         BEGIN
            SELECT cod_tip_asiento, descripcion, cod_tip_asiento2
              INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = 901
               AND cod_tip_asiento IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'Transaccion ' || to_char(v_cod_modulo) || '-' ||
                                        to_char(v_cod_modalidad) ||
                                        '-901 no tiene asiento de Credito definido.');
            WHEN OTHERS THEN
               IF SQLCODE <= -20000 THEN
                  RAISE;
               ELSE
                  raise_application_error(-20001, 'Error lp_int_devengados ' || SQLERRM);
               END IF;
         END;
         ------------------
         -- ve la moneda --
         ------------------
         /*--v_cod_mon_local y v_fec_actual, son inicializados en pra_gen_asientos*/
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad,
                                           v_cod_mon_local);
         IF v_cod_moneda = v_cod_mon_local THEN
            -- es moneda nacional --
            ------------------------
            xx_immovml := v_mto_interes;
            xx_immovex := 0;
            xx_vltasci := 0;
         ELSE
            /*if fug_obt_tip_implementacion = 1 then
               -- se obtiene la cotizacion de venta
               v_mto_cotizacion := pag_gen.fu_obt_cot_venta(v_cod_moneda, v_fec_actual);
            else*/
            -- se obtiene la cotizacion de cierre
            v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            --end if;
            xx_immovml := round(v_mto_interes * v_mto_cotizacion, v_redondeo);
            xx_immovex := v_mto_interes;
            xx_vltasci := v_mto_cotizacion;
         END IF;
         ----- ciclo para GE_TIP_ASIENTOS ------
         -------------------------------
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos;
         v_nro_linea := 0;
         LOOP
            FETCH c_tip_asientos
               INTO r_gtasi;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            ---Reemplaza el valor del tipo de deudor, si importa-
            IF r_gtasi.ind_deudor = 'S' THEN
               v_cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                              substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               v_cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---Reemplaza el codigo del plazo si es necesario -----
            IF r_gtasi.ind_plazo = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                              substr(v_cod_rubro, 4, 12);
            END IF;
            ---Reemplaza el codigo del producto -----------------------
            IF r_gtasi.ind_producto = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                              ltrim(to_char(v_cod_pro_contable, '000')) ||
                              substr(v_cod_rubro, 14, 2);
            END IF;
            --Reemplaza el código del sector de crédito
            IF substr(r_gtasi.cod_rubro, 11, 3) = 'SEC' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_sec_rubro, '000')) ||
                              substr(r_gtasi.cod_rubro, 14, 2);
            END IF;
            ------------------------------------------------------
            v_encontro := 'S';
            lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
               --v_cod_rubro  := '999999999999999';
               v_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_mon_rubro = v_cod_mon_local THEN
               -- moneda local --
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            v_tip_movimiento := r_gtasi.tip_movimiento;
            IF xx_immovml > 0 THEN
               v_tip_movimiento := r_gtasi.tip_movimiento;
               wh_immovml       := xx_immovml;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            ------------------------------------------------------
            wh_dcrefer        := 'DEVENG.RE4.';
            wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                        to_char(901) || ' ' || v_des_transaccion, 1, 60);
            vh_cod_oficina    := v_cod_oficina;
            vh_cod_modulo     := v_cod_modulo;
            vh_cod_modalidad  := v_cod_modalidad;
            vh_cod_ofi_origen := v_cod_oficina;
            wh_lgprote        := 'N';
            wh_lgdeact        := 'N';
            wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
            vh_nro_asiento    := 0;
            v_cod_mod_padre   := v_cod_modulo;
            v_cod_mad_padre   := v_cod_modalidad;
            -----
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := v_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := wh_lgprote;
               r_baade.actualizado    := wh_lgdeact;
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.ref_movimiento := NULL;
               r_baade.cod_modulo     := v_cod_mod_padre;
               r_baade.cod_modalidad  := v_cod_mad_padre;
               r_baade.cod_ofi_origen := v_cod_ofi_origen;
               lp_ins_asi_aut_det(r_baade);
            END IF;
         END LOOP; -- fin de tipo de asientos --
         --- ve el tipo de asiento por el DEBITO
         BEGIN
            SELECT cod_tip_asiento, descripcion, cod_tip_asiento
              INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = 903
               AND cod_tip_asiento IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'Transaccion ' || to_char(v_cod_modulo) || '-' ||
                                        to_char(v_cod_modalidad) ||
                                        '-903 no tiene asiento de Debito definido.');
            WHEN OTHERS THEN
               IF SQLCODE <= -20000 THEN
                  RAISE;
               ELSE
                  raise_application_error(-20002, 'Error lp_int_devengados ' || SQLERRM);
               END IF;
         END;
         ------------------
         -- ve la moneda --
         ------------------
         /*--v_cod_mon_local y v_fec_actual, son inicializados en pra_gen_asientos*/
         IF v_cod_moneda = v_cod_mon_local THEN
            -- es moneda nacional --
            ------------------------
            xx_immovml := v_mto_interes;
            xx_immovex := 0;
            xx_vltasci := 0;
         ELSE
            /*if fug_obt_tip_implementacion = 1 then
               -- se obtiene la cotizacion de venta
               v_mto_cotizacion := pag_gen.fu_obt_cot_venta(v_cod_moneda, v_fec_actual);
            else*/
            -- se obtiene la cotizacion de cierre
            v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            --end if;
            xx_immovml := round(v_mto_interes * v_mto_cotizacion, v_redondeo);
            xx_immovex := v_mto_interes;
            xx_vltasci := v_mto_cotizacion;
         END IF;
         ----- ciclo para GE_TIP_ASIENTOS ------
         -------------------------------
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos;
         v_nro_linea := 0;
         LOOP
            FETCH c_tip_asientos
               INTO r_gtasi;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            ---Reemplaza el valor del tipo de deudor, si importa-
            IF r_gtasi.ind_deudor = 'S' THEN
               v_cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                              substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               v_cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---Reemplaza el codigo del plazo si es necesario -----
            IF r_gtasi.ind_plazo = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                              substr(v_cod_rubro, 4, 12);
            END IF;
            ---Reemplaza el codigo del producto -----------------------
            IF r_gtasi.ind_producto = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                              ltrim(to_char(v_cod_pro_contable, '000')) ||
                              substr(v_cod_rubro, 14, 2);
            END IF;
            --Reemplaza el código del sector de crédito
            IF substr(r_gtasi.cod_rubro, 11, 3) = 'SEC' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_sec_rubro, '000')) ||
                              substr(r_gtasi.cod_rubro, 14, 2);
            END IF;
            ------------------------------------------------------
            v_encontro := 'S';
            lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
               --v_cod_rubro  := '999999999999999';
               v_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_mon_rubro = v_cod_mon_local THEN
               -- moneda local --
               wh_immovex := 0;
               wh_vltasci := 0;
         --Rubros del pasivo para re4
               v_cod_rubro:= v_cod_rubro_gs;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
         v_cod_rubro:= v_cod_rubro_usd;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            v_tip_movimiento := r_gtasi.tip_movimiento;
            IF xx_immovml > 0 THEN
               v_tip_movimiento := r_gtasi.tip_movimiento;
               wh_immovml       := xx_immovml;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            ------------------------------------------------------
            wh_dcrefer        := 'DEVENG.RE4.';
            wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                        to_char(903) || ' ' || v_des_transaccion, 1, 60);
            vh_cod_oficina    := v_cod_oficina;
            vh_cod_modulo     := v_cod_modulo;
            vh_cod_modalidad  := v_cod_modalidad;
            vh_cod_ofi_origen := v_cod_oficina;
            wh_lgprote        := 'N';
            wh_lgdeact        := 'N';
            wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
            vh_nro_asiento    := 0;
            v_cod_mod_padre   := v_cod_modulo;
            v_cod_mad_padre   := v_cod_modalidad;
            -----
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := v_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := wh_lgprote;
               r_baade.ref_movimiento := NULL;
               r_baade.actualizado    := wh_lgdeact;
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.cod_modulo     := v_cod_mod_padre;
               r_baade.cod_modalidad  := v_cod_mad_padre;
               r_baade.cod_ofi_origen := v_cod_ofi_origen;
               lp_ins_asi_aut_det(r_baade);
            END IF;
         END LOOP; -- fin de tipo de asientos --
         close c_tip_asientos; --FIELDESK-61066
      END LOOP; -- fin del ciclo de intereses devengados --
      close cur3; --FIELDESK-61066
   END;



   -- Insteres Devengado de Comisiones Diferidas
   PROCEDURE lp_int_dev_comisiones IS
      v_cod_mad_padre    ge_modalidades.cod_modalidad%TYPE;
      v_cod_mod_padre    ba_modulos.cod_modulo%TYPE;
      v_tip_movimiento   ge_tip_asientos.tip_movimiento%TYPE;
      v_mon_rubro        cb_rubros.cod_moneda%TYPE;
      v_mto_cotizacion   ge_cotizaciones.val_conversion%TYPE;
      v_des_transaccion  ge_transacciones.descripcion%TYPE;
      v_cod_sec_contable ge_sec_contables.cod_sec_contable%TYPE;
      v_cod_ofi_origen   ba_oficinas.cod_oficina%TYPE;
      v_cod_plazo        ge_plz_contables.cod_plazo%TYPE;
      v_tip_deudor       ge_clientes.cod_tip_deudor%TYPE;
      v_residente        ge_clientes.residente%TYPE;
      v_mto_interes      ah_devengados.mto_interes%TYPE;
      v_cod_moneda       ah_cta_vistas.cod_moneda%TYPE;
      v_cod_oficina      ah_cta_vistas.cod_oficina%TYPE;
      v_cod_modalidad    ah_cta_vistas.cod_modalidad%TYPE;
      v_cod_modulo       ah_cta_vistas.cod_modulo%TYPE;
      v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
      xx_immovml         NUMBER;
      xx_immovex         NUMBER;
      xx_vltasci         NUMBER;
      --
      vh_nro_asiento    NUMBER;
      wh_immovex        NUMBER;
      wh_vltasci        NUMBER;
      vh_cod_oficina    ah_cta_vistas.cod_oficina%TYPE;
      vh_cod_ofi_origen ah_cta_vistas.cod_oficina%TYPE;
      vh_cod_modulo     ah_cta_vistas.cod_modulo%TYPE;
      vh_cod_modalidad  ah_cta_vistas.cod_modalidad%TYPE;

      wh_immovml NUMBER;
      wh_dcrefer CHAR(11);
      wh_lgprote CHAR(1);
      wh_lgdeact CHAR(1);
      wh_lgctadi CHAR(1);
      wh_dcdescr CHAR(60);
      --
      v_nro_linea ge_tip_asientos.nro_linea%TYPE;
      v_cod_rubro cb_rubros.cod_rubro%TYPE; --wh_cdcuent
      v_encontro  CHAR(1);
      v_msj       VARCHAR2(250);
      --
      CURSOR cur3 IS
         SELECT md.cod_modulo,
                md.cod_modalidad,
                md.cod_oficina,
                md.cod_moneda, --v_cod_mon_local,
                SUM(md.mto_dev_actual),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                nvl(mo.cod_pro_contable, 0) cod_pro_contable,
                md.cod_transaccion
           FROM ge_mov_diferidos md,
                ge_clientes      c,
                ge_cta_clientes  cc,
                ge_modalidades   mo,
                ge_plz_contables pc
          WHERE md.fec_ult_proceso = v_fec_actual
            AND md.nro_cuenta = cc.nro_cuenta
            AND relacion = 'P'
            AND c.cod_persona = cc.cod_persona
            AND md.cod_modulo = mo.cod_modulo
            AND md.cod_modalidad = mo.cod_modalidad
            AND pc.can_dias =
                (SELECT MIN(gp.can_dias)
                   FROM ge_plz_contables gp
                  WHERE can_dias >= (md.fec_vencimiento - md.fec_inicio))
          GROUP BY md.cod_modulo,
                   md.cod_modalidad,
                   md.cod_oficina,
                   md.cod_moneda, --v_cod_mon_local,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   nvl(mo.cod_pro_contable, 0),
                   md.cod_transaccion
         UNION
         SELECT md.cod_modulo,
                md.cod_modalidad,
                md.cod_oficina,
                md.cod_moneda, --v_cod_mon_local,
                (SUM(md.mto_dev_anterior) * -1),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                nvl(mo.cod_pro_contable, 0) cod_pro_contable,
                md.cod_transaccion
           FROM ge_mov_diferidos md,
                ge_clientes      c,
                ge_cta_clientes  cc,
                ge_modalidades   mo,
                ge_plz_contables pc
          WHERE md.fec_ult_proceso = v_fec_actual
            AND md.nro_cuenta = cc.nro_cuenta
            AND relacion = 'P'
            AND md.estado = 'C'
            AND c.cod_persona = cc.cod_persona
            AND md.cod_modulo = mo.cod_modulo
            AND md.cod_modalidad = mo.cod_modalidad
            AND pc.can_dias =
                (SELECT MIN(gp.can_dias)
                   FROM ge_plz_contables gp
                  WHERE can_dias >= (md.fec_vencimiento - md.fec_inicio))
          GROUP BY md.cod_modulo,
                   md.cod_modalidad,
                   md.cod_oficina,
                   md.cod_moneda, --v_cod_mon_local,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   nvl(mo.cod_pro_contable, 0),
                   md.cod_transaccion;
      --
      v_cod_tip_asiento ge_tip_asientos.cod_tip_asiento%TYPE;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      r_gtasi           ge_tip_asientos%ROWTYPE;
      v_redondeo        NUMBER(5);
      --
      CURSOR c_tip_asientos IS
         SELECT *
           FROM ge_tip_asientos
          WHERE cod_tip_asiento = v_cod_tip_asiento
            AND cod_moneda = v_cod_moneda
            AND (cod_sec_contable = v_cod_sec_contable OR cod_sec_contable IS NULL)
            AND (ind_residente = v_residente OR ind_residente = 'X');
   BEGIN
      v_msj := ' Comisiones Diferidas ';
      OPEN cur3;
      LOOP
         FETCH cur3
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_moneda,
                 v_mto_interes,
                 v_cod_sec_contable,
                 v_residente,
                 v_tip_deudor,
                 v_cod_plazo,
                 v_cod_pro_contable,
                 v_cod_transaccion;
         EXIT WHEN cur3%NOTFOUND;
         --- ve el tipo de asiento
         BEGIN
            SELECT cod_tip_asi_resultado, descripcion
              INTO v_cod_tip_asiento, v_des_transaccion
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = v_cod_transaccion
               AND cod_tip_asi_resultado IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'NO TIENE ASIENTO RELAC.P/DEVENG COMISION ' ||
                                        to_char(v_cod_modulo) || '-' || to_char(v_cod_modalidad) || '-' ||
                                        to_char(v_cod_transaccion));
            WHEN OTHERS THEN
               /*EXHIBIR_ERROR;
               RAISE FORM_TRIGGER_FAILURE;*/
               raise_application_error(-20001, 'Error lp_int_devengados ' || SQLERRM);

         END;
         ------------------
         -- ve la moneda --
         ------------------
         /*--v_cod_mon_local y v_fec_actual, son inicializados en pra_gen_asientos*/
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad,
                                           v_cod_mon_local);
         --IF v_cod_moneda =  v_cod_mon_local THEN
         -- Comisiones diferidas siempre --
         -- es moneda nacional --
         ------------------------
         xx_immovml := v_mto_interes;
         xx_immovex := 0;
         xx_vltasci := 0;
         --ELSE
         /*-- se obtiene la cotizacion de cierre
         v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
         xx_immovml := round(v_mto_interes * v_mto_cotizacion,v_redondeo);
         xx_immovex := v_mto_interes;
         xx_vltasci := v_mto_cotizacion;*/
         /*raise_application_error(-20000,'ASIENTOS DEV. COMISONES SOLO DEBEN SER EN MONEDA LOCAL '
                ||TO_CHAR(v_cod_modulo)||'-'||TO_CHAR(v_cod_modalidad)||'-'||TO_CHAR(v_cod_transaccion));
         END IF;*/
         ----- ciclo para GE_TIP_ASIENTOS ------
         -------------------------------
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos;
         v_nro_linea := 0;
         LOOP
            FETCH c_tip_asientos
               INTO r_gtasi;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            ---Reemplaza el valor del tipo de deudor, si importa-
            IF r_gtasi.ind_deudor = 'S' THEN
               v_cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                              substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               v_cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---Reemplaza el codigo del plazo si es necesario -----
            IF r_gtasi.ind_plazo = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                              substr(v_cod_rubro, 4, 12);
            END IF;
            ---Reemplaza el codigo del producto -----------------------
            IF r_gtasi.ind_producto = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                              ltrim(to_char(v_cod_pro_contable, '000')) ||
                              substr(v_cod_rubro, 14, 2);
            END IF;
            ------------------------------------------------------
            v_encontro := 'S';
            lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
               --v_cod_rubro  := '999999999999999';
               v_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_mon_rubro = v_cod_mon_local THEN
               -- moneda local --
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            v_tip_movimiento := r_gtasi.tip_movimiento;
            IF xx_immovml > 0 THEN
               v_tip_movimiento := r_gtasi.tip_movimiento;
               wh_immovml       := xx_immovml;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            ------------------------------------------------------
            wh_dcrefer        := 'DEVENG.';
            wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                        to_char(v_cod_transaccion) || ' ' || v_des_transaccion, 1, 60);
            vh_cod_oficina    := v_cod_oficina;
            vh_cod_modulo     := v_cod_modulo;
            vh_cod_modalidad  := v_cod_modalidad;
            vh_cod_ofi_origen := v_cod_oficina;
            wh_lgprote        := 'N';
            wh_lgdeact        := 'N';
            wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
            vh_nro_asiento    := 0;
            v_cod_mod_padre   := v_cod_modulo;
            v_cod_mad_padre   := v_cod_modalidad;
            -----
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := v_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := wh_lgprote;
               r_baade.actualizado    := wh_lgdeact;
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.ref_movimiento := NULL;
               r_baade.cod_modulo     := v_cod_mod_padre;
               r_baade.cod_modalidad  := v_cod_mad_padre;
               r_baade.cod_ofi_origen := v_cod_ofi_origen;
               lp_ins_asi_aut_det(r_baade);
            END IF;
         END LOOP; -- fin de tipo de asientos --
         close c_tip_asientos;
      END LOOP; -- fin del ciclo de intereses devengados --
      close cur3; --FIELDESK-61066
      -- Actualiza estado de cuentas canceladas reversadas
      UPDATE ge_mov_diferidos
         SET estado = 'N'
       WHERE estado = 'C'
         AND fec_ult_proceso = v_fec_actual;
      ---
   END;
   -- Insteres Devengado de Mesa de Dinero
   PROCEDURE lp_int_dev_mesadinero IS
      v_cod_mad_padre    ge_modalidades.cod_modalidad%TYPE;
      v_cod_mod_padre    ba_modulos.cod_modulo%TYPE;
      v_tip_movimiento   ge_tip_asientos.tip_movimiento%TYPE;
      v_mon_rubro        cb_rubros.cod_moneda%TYPE;
      v_mto_cotizacion   ge_cotizaciones.val_conversion%TYPE;
      v_des_transaccion  ge_transacciones.descripcion%TYPE;
      v_cod_sec_contable ge_sec_contables.cod_sec_contable%TYPE;
      v_cod_ofi_origen   ba_oficinas.cod_oficina%TYPE;
      v_cod_plazo        ge_plz_contables.cod_plazo%TYPE;
      v_tip_deudor       ge_clientes.cod_tip_deudor%TYPE;
      v_residente        ge_clientes.residente%TYPE;
      v_mto_interes      ah_devengados.mto_interes%TYPE;
      v_cod_moneda       ah_cta_vistas.cod_moneda%TYPE;
      v_cod_oficina      ah_cta_vistas.cod_oficina%TYPE;
      v_cod_modalidad    ah_cta_vistas.cod_modalidad%TYPE;
      v_cod_modulo       ah_cta_vistas.cod_modulo%TYPE;
      v_cod_transaccion  ge_transacciones.cod_transaccion%TYPE;
      v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
      v_est_cuenta       ge_tip_asientos.est_cuenta%TYPE;
      v_tip_cuenta       ge_tip_asientos.tip_cuenta%TYPE;
      v_tip_interes      ge_tip_asientos.tip_interes%TYPE;
      v_tip_renovacion   ge_tip_asientos.tip_renovacion%TYPE;
      v_cat_automatica   ge_tip_asientos.cat_automatica%TYPE;
      v_dev_int          VARCHAR2(1);
      xx_immovgs         NUMBER;
      xx_immovex         NUMBER;
      xx_vltasci         NUMBER;
      --
      vh_nro_asiento    NUMBER;
      wh_immovex        NUMBER;
      wh_vltasci        NUMBER;
      vh_cod_oficina    pr_cta_prestamos.cod_oficina%TYPE;
      vh_cod_ofi_origen pr_cta_prestamos.cod_oficina%TYPE;
      vh_cod_modulo     pr_cta_prestamos.cod_modulo%TYPE;
      vh_cod_modalidad  pr_cta_prestamos.cod_modalidad%TYPE;

      wh_immovgs NUMBER;
      wh_dcrefer VARCHAR2(11);
      wh_lgprote VARCHAR2(1);
      wh_lgdeact VARCHAR2(1);
      wh_lgctadi VARCHAR2(1);
      wh_dcdescr VARCHAR2(60);
      --
      v_nro_linea        ge_tip_asientos.nro_linea%TYPE;
      v_cod_rubro        cb_rubros.cod_rubro%TYPE; --wh_cdcuent
      v_cod_sit_contable md_cta_documentos.cod_sit_contable%TYPE;
      v_encontro         VARCHAR2(1);
      v_msj              VARCHAR2(250);
      --
      CURSOR cur3 IS
        SELECT 'I' dev_int,
                ct.cod_modulo,
                ct.cod_modalidad,
                ct.cod_oficina,
                ct.cod_moneda,
                SUM(nvl(d.mto_dev_actual, 0)),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                nvl(mo.cod_pro_contable, 0),
                d.estado,
                ct.cod_sit_contable
           FROM ge_plz_contables  pc,
                md_devengados     d,
                md_cta_documentos ct,
                ge_clientes       c,
                ge_cta_clientes   cc,
                ge_modalidades    mo
          WHERE d.fecha = v_fec_actual
            AND d.nro_cuenta = ct.nro_cuenta
            AND d.nro_cuenta = cc.nro_cuenta
            AND relacion = 'P'
            AND c.cod_persona = cc.cod_persona
            AND mo.cod_modulo = ct.cod_modulo
            AND mo.cod_modalidad = ct.cod_modalidad
            and (instr(fug_obt_pardinamico('COD_MAD_MER_SECUNDARIO'),','||ct.cod_modalidad||',') = 0 or (instr(fug_obt_pardinamico('COD_MAD_MER_SECUNDARIO'),','||ct.cod_modalidad||',') <> 0 and d.val_tasa <> 0) ) 
               -- si estado = RIPEADO, devengar en plazo del REPO
            AND pc.can_dias =
                (SELECT MIN(can_dias)
                   FROM ge_plz_contables
                  WHERE can_dias >= (decode(d.estado, 'E', (ct.fec_ven_repo - ct.fec_ini_repo),
                                            (ct.fec_vencimiento - ct.fec_inicio))))
         --AND CT.ESTADO = 'C' JCLG
          GROUP BY ct.cod_modulo,
                   ct.cod_modalidad,
                   ct.cod_oficina,
                   ct.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   nvl(mo.cod_pro_contable, 0),
                   d.estado,
                   ct.cod_sit_contable
                   
         UNION ALL
         
        SELECT 'C' dev_int,
                ct.cod_modulo,
                ct.cod_modalidad,
                ct.cod_oficina,
                ct.cod_moneda,
                SUM(nvl(d.mto_dev_actual, 0)),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                nvl(mo.cod_pro_contable, 0),
                d.estado,
                ct.cod_sit_contable
           FROM ge_plz_contables  pc,
                md_devengados     d,
                md_cta_documentos ct,
                ge_clientes       c,
                ge_cta_clientes   cc,
                ge_modalidades    mo
          WHERE d.fecha = v_fec_actual
            AND d.nro_cuenta = ct.nro_cuenta
            AND d.nro_cuenta = cc.nro_cuenta
            AND relacion = 'P'
            AND c.cod_persona = cc.cod_persona
            AND mo.cod_modulo = ct.cod_modulo
            AND mo.cod_modalidad = ct.cod_modalidad
            and (instr(fug_obt_pardinamico('COD_MAD_MER_SECUNDARIO'),','||ct.cod_modalidad||',') <> 0 and ct.mer_secundario = 'S' and d.val_tasa = 0) 
            AND pc.can_dias =
                (SELECT MIN(can_dias)
                   FROM ge_plz_contables
                  WHERE can_dias >= (decode(d.estado, 'E', (ct.fec_ven_repo - ct.fec_ini_repo),
                                            (ct.fec_vencimiento - ct.fec_inicio))))
          GROUP BY ct.cod_modulo,
                   ct.cod_modalidad,
                   ct.cod_oficina,
                   ct.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   nvl(mo.cod_pro_contable, 0),
                   d.estado,
                   ct.cod_sit_contable;
      --
      v_cod_tip_asiento  ge_tip_asientos.cod_tip_asiento%TYPE;
      v_cod_tip_asiento2 ge_tip_asientos.cod_tip_asiento%TYPE;
      r_gtasi            ge_tip_asientos%ROWTYPE;
      --
      CURSOR c_tip_asientos IS
         SELECT *
           FROM ge_tip_asientos
          WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
            AND cod_moneda = v_cod_moneda
            AND (cod_sec_contable = v_cod_sec_contable OR cod_sec_contable IS NULL)
            AND (ind_residente = v_residente OR ind_residente = 'X')
            AND (est_cuenta = v_est_cuenta OR nvl(est_cuenta, 'X') = 'X')
            AND (tip_cuenta = v_tip_cuenta OR nvl(tip_cuenta, 'X') = 'X')
            AND (tip_interes = v_tip_interes OR nvl(tip_interes, 'X') = 'X')
            AND (tip_renovacion = v_tip_renovacion OR nvl(tip_renovacion, 'X') = 'X')
            AND (cat_automatica = v_cat_automatica OR nvl(cat_automatica, -1) = -1)
            AND (cod_sit_contable IS NULL OR cod_sit_contable = v_cod_sit_contable);
   BEGIN
      v_msj := ' Intereses devengados ';
      OPEN cur3;
      LOOP
         FETCH cur3
            INTO v_dev_int,
                 v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_moneda,
                 v_mto_interes,
                 v_cod_sec_contable,
                 v_residente,
                 v_tip_deudor,
                 v_cod_plazo,
                 v_cod_pro_contable,
                 v_est_cuenta,
                 v_cod_sit_contable;
         EXIT WHEN cur3%NOTFOUND;
         
         IF v_dev_int = 'I' THEN
         IF v_est_cuenta = 'E' THEN
            -- Si es una cuenta con Estado REPO carga la transacción 902
            v_cod_transaccion := 902;
         ELSE
            v_cod_transaccion := 901;
         END IF;
         ELSE
           v_cod_transaccion := 904;
         END IF;
         
         --- ve el tipo de asiento por el CREDITO
         BEGIN
            SELECT cod_tip_asiento, descripcion, cod_tip_asiento2
              INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = v_cod_transaccion
               AND cod_tip_asiento IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'Transaccion ' || to_char(v_cod_modulo) || '-' ||
                                        to_char(v_cod_modalidad) || '-' || v_est_cuenta ||
                                        ' no tiene asiento de Credito definido.');
            WHEN OTHERS THEN
               IF SQLCODE <= -20000 THEN
                  RAISE;
               ELSE
                  raise_application_error(-20001, 'Error lp_int_devengados ' || SQLERRM);
               END IF;
         END;
         ------------------
         -- ve la moneda --
         ------------------
         /*--v_cod_mon_local y v_fec_actual, son inicializados en pra_gen_asientos*/
         IF v_cod_moneda = v_cod_mon_local THEN
            -- es moneda nacional --
            ------------------------
            xx_immovgs := v_mto_interes;
            xx_immovex := 0;
            xx_vltasci := 0;
         ELSE
            IF fug_obt_tip_implementacion = 1 THEN
               -- se obtiene la cotizacion de venta
               v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            ELSE
               -- se obtiene la cotizacion de cierre
               v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            END IF;
            xx_immovgs := round(v_mto_interes * v_mto_cotizacion, 0);
            xx_immovex := v_mto_interes;
            xx_vltasci := v_mto_cotizacion;
         END IF;

         -- REPO-CNF-12/2015: Para documentos Ripeados se cambia para tomar los rubros correctos
         If v_est_cuenta = 'R' Then
           v_cod_sit_contable := '10000003';
         End If;

         ----- ciclo para GE_TIP_ASIENTOS ------
         -------------------------------
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos;
         v_nro_linea := 0;
         LOOP
            FETCH c_tip_asientos
               INTO r_gtasi;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            ---Reemplaza el valor del tipo de deudor, si importa-
            IF r_gtasi.ind_deudor = 'S' THEN
               v_cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                              substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               v_cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---Reemplaza el codigo del plazo si es necesario -----
            IF r_gtasi.ind_plazo = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                              substr(v_cod_rubro, 4, 12);
            END IF;
            ---Reemplaza el codigo del producto -----------------------
            IF r_gtasi.ind_producto = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                              ltrim(to_char(v_cod_pro_contable, '000')) ||
                              substr(v_cod_rubro, 14, 2);
            END IF;
            ------------------------------------------------------
            v_encontro := 'S';
            lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
               --v_cod_rubro  := '999999999999999';
               v_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_mon_rubro = v_cod_mon_local THEN
               -- moneda local --
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            v_tip_movimiento := r_gtasi.tip_movimiento;
            IF xx_immovgs > 0 THEN
               v_tip_movimiento := r_gtasi.tip_movimiento;
               wh_immovgs       := xx_immovgs;
            ELSE
               wh_immovgs := xx_immovgs * -1;
               wh_immovex := wh_immovex * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            ------------------------------------------------------
            wh_dcrefer        := 'DEVENG.';
            wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                        to_char(v_est_cuenta) || ' ' || v_des_transaccion, 1, 60);
            vh_cod_oficina    := v_cod_oficina;
            vh_cod_modulo     := v_cod_modulo;
            vh_cod_modalidad  := v_cod_modalidad;
            vh_cod_ofi_origen := v_cod_oficina;
            wh_lgprote        := 'N';
            wh_lgdeact        := 'N';
            wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
            vh_nro_asiento    := 0;
            v_cod_mod_padre   := v_cod_modulo;
            v_cod_mad_padre   := v_cod_modalidad;
            -----
            IF wh_immovgs <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := v_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovgs;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := wh_lgprote;
               r_baade.actualizado    := wh_lgdeact;
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.ref_movimiento := NULL;
               r_baade.cod_modulo     := v_cod_mod_padre;
               r_baade.cod_modalidad  := v_cod_mad_padre;
               r_baade.cod_ofi_origen := v_cod_ofi_origen;
               lp_ins_asi_aut_det(r_baade);
            END IF;
         END LOOP; -- fin de tipo de asientos --
         close c_tip_asientos; --FIELDESK-61066
         --si es call money vista,fideicomiso debe hacer solo la 901 jclg
         /*if v_cod_modalidad not in (109,110,120) then
           --- ve el tipo de asiento por el DEBITO
           BEGIN
             SELECT COD_TIP_ASIENTO, DESCRIPCION, cod_tip_asiento
               INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
               FROM GE_TRANSACCIONES
              WHERE COD_MODULO = v_cod_modulo
               AND COD_MODALIDAD = v_cod_modalidad
               AND COD_TRANSACCION = 903
               AND COD_TIP_ASIENTO IS NOT NULL;
           EXCEPTION
             WHEN NO_DATA_FOUND THEN
               raise_application_error(-20000,
               'Transaccion '||TO_CHAR(v_cod_modulo)||'-'||TO_CHAR(v_cod_modalidad)||'-903 no tiene asiento de Debito definido.');
             WHEN OTHERS THEN
               if sqlcode <= -20000 then
                 raise;
               else
                 raise_application_error(-20002,
                 'Error lp_int_devengados '||sqlerrm);
               end if;
           END;

           ------------------
           -- ve la moneda --
           ------------------
           --v_cod_mon_local y v_fec_actual, son inicializados en pra_gen_asientos
           IF v_cod_moneda =  v_cod_mon_local THEN
             -- es moneda nacional --
             ------------------------
             xx_immovgs := v_mto_interes;
             xx_immovex := 0;
             xx_vltasci := 0;
           ELSE
             -- se obtiene la cotizacion de cierre de bcp--
             if fug_obt_tip_implementacion = 1 then
               -- se obtiene la cotizacion de venta
               v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
             else
               -- se obtiene la cotizacion de cierre
               v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
             end if;
             xx_immovgs := round(v_mto_interes * v_mto_cotizacion,0);
             xx_immovex := v_mto_interes;
             xx_vltasci := v_mto_cotizacion;
           END IF;
           ----- ciclo para GE_TIP_ASIENTOS ------
           -------------------------------
           IF c_tip_asientos%isopen THEN
             CLOSE c_tip_asientos;
           END IF;
           OPEN c_tip_asientos;
           v_nro_linea := 0;
           LOOP
             FETCH c_tip_asientos INTO r_gtasi;
             EXIT WHEN  c_tip_asientos%NOTFOUND;
             ---Reemplaza el valor del tipo de deudor, si importa-
             IF r_gtasi.IND_DEUDOR = 'S' THEN
               v_cod_rubro := SUBSTR(r_gtasi.COD_RUBRO,1,8)||
                           LTRIM(TO_CHAR(v_tip_deudor,'00'))||
                           SUBSTR(r_gtasi.COD_RUBRO,11,5);
             ELSE
               v_cod_rubro := r_gtasi.COD_RUBRO;
             END IF;
             ---Reemplaza el codigo del plazo si es necesario -----
             IF r_gtasi.IND_PLAZO = 'S' THEN
               v_cod_rubro := SUBSTR(v_cod_rubro,1,2)||
                           LTRIM(TO_CHAR(v_cod_plazo))||
                           SUBSTR(v_cod_rubro,4,12);
             END IF;
             ---Reemplaza el codigo del producto -----------------------
             IF r_gtasi.IND_PRODUCTO = 'S' THEN
               v_cod_rubro := SUBSTR(v_cod_rubro,1,10)||
                           LTRIM(TO_CHAR(v_cod_pro_contable,'000'))||
                           SUBSTR(v_cod_rubro,14,2);
             END IF;
             ------------------------------------------------------
             v_encontro:= 'S';
             lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
             if v_encontro = 'N' then
               v_msj := 'Cuenta inexistente en Plan de Cuentas '||v_cod_rubro;
               v_cod_rubro  := '999999999999999';
               v_mon_rubro  := v_cod_mon_local;
             end if;
             IF v_mon_rubro = v_cod_mon_local THEN
               -- moneda local --
                wh_immovex := 0;
                wh_vltasci := 0;
             ELSE
                wh_immovex := xx_immovex;
                wh_vltasci := xx_vltasci;
             END IF;
             -- ve el tipo de movimiento --
             ------------------------------
             v_tip_movimiento := r_gtasi.tip_movimiento;
             IF xx_immovgs > 0 THEN
               v_tip_movimiento:= r_gtasi.TIP_MOVIMIENTO;
               wh_immovgs := xx_immovgs;
             ELSE
               wh_immovgs := xx_immovgs * -1;
               wh_immovex := wh_immovex * -1;
               IF r_gtasi.TIP_MOVIMIENTO = 'C' THEN
                 v_tip_movimiento:= 'D';
               ELSE
                 v_tip_movimiento:= 'C';
               END IF;
             END IF;
             ------------------------------------------------------
             wh_dcrefer := 'DEVENG.';
             wh_dcdescr := substr(to_char(v_cod_modulo) || ' ' ||
                       to_char(v_cod_modalidad) || ' ' ||
                       to_char(903)        || ' ' ||
                       v_des_transaccion,1,60);
             vh_cod_oficina    := v_cod_oficina;
             vh_cod_modulo     := v_cod_modulo;
             vh_cod_modalidad  := v_cod_modalidad;
             vh_cod_ofi_origen := v_cod_oficina;
             wh_lgprote        := 'N';
             wh_lgdeact        := 'N';
             wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
             vh_nro_asiento    := 0;
             v_cod_mod_padre   := v_cod_modulo;
             v_cod_mad_padre   := v_cod_modalidad;
             -----
             IF wh_immovgs <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.FECHA          := v_fec_actual;
               r_baade.COD_OFICINA    := vh_cod_oficina;
               r_baade.NRO_ASIENTO    := 0;
               r_baade.NRO_LINEA      := v_nro_linea;
               r_baade.COD_RUBRO      := v_cod_rubro;
               r_baade.TIP_MOVIMIENTO := v_tip_movimiento;
               r_baade.MTO_MON_RUBRO  := wh_immovex;
               r_baade.MTO_MON_LOCAL  := wh_immovgs;
               r_baade.DESCRIPCION    := wh_dcdescr;
               r_baade.REFERENCIA     := wh_dcrefer;
               r_baade.PROTEGIDO      := wh_lgprote;
               r_baade.REF_MOVIMIENTO := null;
               r_baade.ACTUALIZADO    := wh_lgdeact;
               r_baade.VAL_COTIZACION := wh_vltasci;
               r_baade.DISTRIBUIDO    := wh_lgctadi;
               r_baade.COD_MODULO     := v_cod_mod_padre;
               r_baade.COD_MODALIDAD  := v_cod_mad_padre;
               r_baade.COD_OFI_ORIGEN := v_cod_ofi_origen;
               lp_ins_asi_aut_det(r_baade);
             END IF;
           END LOOP;      -- fin de tipo de asientos --
         end if;*/
      END LOOP; -- fin del ciclo de intereses devengados --
      close cur3; --FIELDESK-61066
   END;
   -- Intereses Devengados Operaciones Futuras.
   PROCEDURE lp_dev_ope_futuras IS
      v_fec_actual      ge_calendarios.fec_actual%TYPE := pae_cnf.fu_obt_fec_actual(7);
      v_cod_mon_local   ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
      v_cod_mon_cta     ba_monedas.cod_moneda%TYPE;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      v_descripcion     ge_transacciones.descripcion%TYPE;
      v_cod_tip_asiento ge_transacciones.cod_tip_asiento%TYPE;
      v_encontro        VARCHAR2(1);
      -- Variables Cursor
      v_cod_modulo          lc_devengados.cod_modulo%TYPE;
      v_cod_mad_transaccion lc_devengados.cod_mad_transaccion%TYPE;
      v_cod_ofi_origen      lc_devengados.cod_oficina%TYPE;
      v_cod_moneda          lc_devengados.cod_moneda%TYPE;
      v_mto_interes         lc_devengados.mto_interes%TYPE;
      v_cod_mad_padre       lc_devengados.cod_mad_padre%TYPE;
      v_descuento           lc_devengados.descuento%TYPE;
      v_residente           ge_clientes.residente%TYPE;
      v_cod_sec_contable    ge_clientes.cod_sec_contable%TYPE;
      v_cod_tip_deudor      ge_clientes.cod_tip_deudor%TYPE;
      v_cod_plazo           ge_plz_contables.cod_plazo%TYPE;
      --
      xx_immovgs NUMBER;
      xx_immovex NUMBER;
      xx_vltasci NUMBER;
      --
      r_baade cb_asi_automaticos_det_tmp%ROWTYPE;
      r_gtasi ge_tip_asientos%ROWTYPE;
      v_ind_dev_val_economico ge_par_dinamicos.val_parametro%type;
      ----------------------------------------------------------------------
      -- Leer todas las operaciones a futuro vigentes -- MODALIDAD = 76   --
      ----------------------------------------------------------------------
      CURSOR cur3 IS
         SELECT d.cod_modulo,
                d.cod_mad_transaccion,
                d.cod_ofi_origen,
                d.cod_moneda,
                SUM(nvl(d.mto_interes, 0)),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                d.cod_mad_padre,
                d.descuento
           FROM lc_devengados  d,
                lc_ope_futuras o,
                ge_clientes    c,
                --ge_cta_clientes cc,
                ge_plz_contables pc
          WHERE d.fecha = v_fec_actual
            AND d.cod_modalidad = o.cod_modalidad
            AND d.cod_oficina = o.cod_oficina
            AND d.nro_cuenta = o.nro_cuenta
            AND d.nro_operacion = o.nro_operacion
            AND d.cod_mad_transaccion = o.cod_mad_transaccion

               --and d.nro_cuenta = cc.nro_cuenta
               --and cc.relacion = 'P'
               --and cc.cod_persona = c.cod_persona
            AND c.cod_persona = o.cod_persona

            AND pc.can_dias =
                (SELECT MIN(gp.can_dias)
                   FROM ge_plz_contables gp
                  WHERE can_dias >= (o.fec_vencimiento - o.fec_operacion))
            --Agregado para Proyecto CNFNORMA-274-AJUSTES FORWARD--
            and ((v_ind_dev_val_economico = 'N') or
                 (v_ind_dev_val_economico = 'S'
                  and exists (select 1
                                from ba_cod_referencias x
                               where x.dominio = 'OPE_FUT_DEV_ANTERIOR'
                                 and x.val_minimo = o.nro_cuenta||'#'||o.nro_operacion)))
            --------------------------------------------------------
          GROUP BY d.cod_modulo,
                   d.cod_mad_transaccion,
                   d.cod_ofi_origen,
                   d.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   d.cod_mad_padre,
                   d.descuento
         HAVING SUM(nvl(d.mto_interes, 0)) > 0;
      --
      CURSOR cur5 IS
         SELECT *
           FROM ge_tip_asientos
          WHERE cod_tip_asiento = v_cod_tip_asiento
            AND cod_moneda = v_cod_moneda
            AND cod_sec_contable = v_cod_sec_contable
            AND (ind_residente = v_residente OR ind_residente = 'X');
   BEGIN
      v_ind_dev_val_economico := nvl(fug_obt_pardinamico('IND_DEV_VAL_ECONOMICO'),'N');
      OPEN cur3;
      LOOP
         FETCH cur3
            INTO v_cod_modulo,
                 v_cod_mad_transaccion,
                 v_cod_ofi_origen,
                 v_cod_moneda,
                 v_mto_interes,
                 v_cod_sec_contable,
                 v_residente,
                 v_cod_tip_deudor,
                 v_cod_plazo,
                 v_cod_mad_padre,
                 v_descuento;
         EXIT WHEN cur3%NOTFOUND;
         --- ve el tipo de asiento ---
         IF v_cod_mad_padre = 76 THEN
            -- operaciones futuras --
            IF v_cod_mad_transaccion = 71 THEN
               -- es una compra --
               IF v_descuento = 'N' THEN
                  -- es un premio --
                  v_cod_transaccion := 1901;
               ELSE
                  v_cod_transaccion := 1902;
               END IF;
            ELSE
               -- es una venta --
               IF v_descuento = 'N' THEN
                  -- es un premio --
                  v_cod_transaccion := 1902;
               ELSE
                  v_cod_transaccion := 1901;
               END IF;
            END IF;
            /*ELSIF v_cod_mad_padre = 77 THEN -- operaciones swap --
            IF v_cod_mad_transaccion = 71 THEN -- es una compra --
               IF v_descuento = 'N' THEN  -- es un premio --
                  v_cod_transaccion := 903;
               ELSE
                  v_cod_transaccion := 904;
               END IF;
            ELSE  -- es una venta --
               IF v_descuento = 'N' THEN -- es un premio --
                  v_cod_transaccion := 904;
               ELSE
                  v_cod_transaccion := 903;
               END IF;
            END IF;*/
         ELSE
            raise_application_error(-20004,
                                    'ERROR. La modalidad ' || to_char(v_cod_mad_padre) ||
                                     ' no esta definida ');
         END IF;
         BEGIN
            SELECT cod_tip_asiento, descripcion
              INTO v_cod_tip_asiento, v_descripcion
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_mad_transaccion
               AND cod_transaccion = v_cod_transaccion
               AND cod_tip_asiento IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'No tiene Asiento Relac. para Deveng.: ' ||
                                        to_char(v_cod_modulo) || '-' ||
                                        to_char(v_cod_mad_transaccion) || '-' ||
                                        to_char(v_cod_transaccion));
            WHEN OTHERS THEN
               raise_application_error(-20001, SQLERRM);
         END;
         ------------------------
         xx_immovgs := v_mto_interes;
         xx_immovex := 0;
         xx_vltasci := 0;
         -------------------------------
         ----- ciclo para GE_TIP_ASIENTOS ------

         IF cur5%ISOPEN THEN
            CLOSE cur5;
         END IF;
         OPEN cur5;
         r_baade.nro_linea := 0;
         r_baade.fecha     := v_fec_actual;
         LOOP
            FETCH cur5
               INTO r_gtasi;
            EXIT WHEN cur5%NOTFOUND;
            ---Agregado por agustin para el nuevo plan de cuentas ---
            IF r_gtasi.ind_deudor = 'S' THEN
               r_baade.cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) ||
                                    ltrim(to_char(v_cod_tip_deudor, '00')) ||
                                    substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               r_baade.cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---------------------------------------------------------
            IF r_gtasi.ind_plazo = 'S' THEN
               r_baade.cod_rubro := substr(r_baade.cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                                    substr(r_baade.cod_rubro, 4, 12);
            END IF;
            --
            v_encontro := 'S';
            --
            lp_obt_mon_rubro(r_baade.cod_rubro, v_cod_mon_cta, v_encontro);
            IF v_encontro = 'N' THEN
               --r_baade.cod_rubro  := '999999999999999';
               v_cod_mon_cta := v_cod_mon_local;
            END IF;
            --
            IF v_cod_mon_cta = v_cod_mon_local THEN
               -- moneda local --
               r_baade.mto_mon_rubro  := 0;
               r_baade.val_cotizacion := 0;
            ELSE
               r_baade.mto_mon_rubro  := xx_immovex;
               r_baade.val_cotizacion := xx_vltasci;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            IF xx_immovgs > 0 THEN
               r_baade.tip_movimiento := r_gtasi.tip_movimiento;
               r_baade.mto_mon_local  := xx_immovgs;
            ELSE
               r_baade.mto_mon_local := xx_immovgs * -1;
               r_baade.mto_mon_rubro := r_baade.mto_mon_rubro * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  r_baade.tip_movimiento := 'D';
               ELSE
                  r_baade.tip_movimiento := 'C';
               END IF;
            END IF;
            IF r_baade.mto_mon_local <> 0 THEN
               --
               r_baade.referencia     := 'DEVENG.';
               r_baade.descripcion    := to_char(v_cod_modulo) || ' ' ||
                                         to_char(v_cod_mad_transaccion) || ' ' ||
                                         to_char(v_cod_transaccion) || ' ' ||
                                         substr(v_descripcion, 1, 20);
               r_baade.cod_ofi_origen := v_cod_ofi_origen;
               r_baade.cod_oficina    := v_cod_ofi_origen;
               r_baade.cod_modulo     := v_cod_modulo;
               r_baade.protegido      := 'N';
               r_baade.actualizado    := 'N';
               r_baade.distribuido    := 'N';
               r_baade.cod_modulo     := v_cod_modulo;
               r_baade.cod_modalidad  := v_cod_mad_transaccion;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := r_baade.nro_linea + 1;
               --
               lp_ins_asi_aut_det(r_baade);
            END IF;
         END LOOP; -- fin de tipo de asientos --
         close cur5; --FIELDESK-61066
      END LOOP; -- fin del ciclo de intereses devengados --
      close cur3; --FIELDESK-61066
   END;

   PROCEDURE lp_dev_ope_fut_valeco IS
      v_fec_actual      ge_calendarios.fec_actual%TYPE := pae_cnf.fu_obt_fec_actual(7);
      v_cod_mon_local   ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
      v_cod_mon_cta     ba_monedas.cod_moneda%TYPE;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      v_descripcion     ge_transacciones.descripcion%TYPE;
      v_cod_tip_asiento ge_transacciones.cod_tip_asiento%TYPE;
      v_encontro        VARCHAR2(1);
      -- Variables Cursor
      v_cod_modulo          lc_devengados.cod_modulo%TYPE;
      v_cod_mad_transaccion lc_devengados.cod_mad_transaccion%TYPE;
      v_cod_ofi_origen      lc_devengados.cod_oficina%TYPE;
      v_cod_moneda          lc_devengados.cod_moneda%TYPE;
      v_mto_interes         lc_devengados.mto_interes%TYPE;
      v_cod_mad_padre       lc_devengados.cod_mad_padre%TYPE;
      v_descuento           lc_devengados.descuento%TYPE;
      v_residente           ge_clientes.residente%TYPE;
      v_cod_sec_contable    ge_clientes.cod_sec_contable%TYPE;
      v_cod_tip_deudor      ge_clientes.cod_tip_deudor%TYPE;
      v_cod_tip_deu_aux     ge_clientes.cod_tip_deudor%TYPE;
      v_cod_plazo           ge_plz_contables.cod_plazo%TYPE;
      --
      xx_immovgs NUMBER;
      xx_immovex NUMBER;
      xx_vltasci NUMBER;
      --
      r_baade cb_asi_automaticos_det_tmp%ROWTYPE;
      r_gtasi ge_tip_asientos%ROWTYPE;
      v_tip_calculo  varchar2(10);
      v_ind_dev_val_economico ge_par_dinamicos.val_parametro%type;
      v_fec_calculo date;
      ----------------------------------------------------------------------
      -- Leer todas las operaciones a futuro vigentes -- MODALIDAD = 76   --
      ----------------------------------------------------------------------
      CURSOR cur3 IS
         SELECT x.fec_calculo, d.cod_modulo,
                d.cod_mad_transaccion,
                d.cod_ofi_origen,
                d.cod_moneda,
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                d.cod_mad_padre,
                d.descuento,
                'VDPE' tip_calculo,
                SUM(nvl(x.mto_deb_perdida, 0))
           FROM lc_devengados d, lc_ope_futuras o, ge_clientes c,
                ge_plz_contables pc, lc_for_dat_val_economico x
          WHERE d.fecha = v_fec_actual
            AND d.cod_modalidad = o.cod_modalidad
            AND d.cod_oficina = o.cod_oficina
            AND d.nro_cuenta = o.nro_cuenta
            AND d.nro_operacion = o.nro_operacion
            AND d.cod_mad_transaccion = o.cod_mad_transaccion
            and x.nro_cuenta = o.nro_cuenta
            and x.nro_operacion = o.nro_operacion
            and x.fecha = d.fecha
            AND c.cod_persona = o.cod_persona
            AND pc.can_dias =
                (SELECT MIN(gp.can_dias)
                   FROM ge_plz_contables gp
                  WHERE can_dias >= (o.fec_vencimiento - o.fec_operacion))
            --Agregado para Proyecto CNFNORMA-274-AJUSTES FORWARD--
            and v_ind_dev_val_economico = 'S'
            and not exists (select 1
                              from ba_cod_referencias x
                             where x.dominio = 'OPE_FUT_DEV_ANTERIOR'
                               and x.val_minimo = o.nro_cuenta||'#'||o.nro_operacion)
            --------------------------------------------------------
          GROUP BY x.fec_calculo, d.cod_modulo,
                   d.cod_mad_transaccion,
                   d.cod_ofi_origen,
                   d.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   d.cod_mad_padre,
                   d.descuento
         HAVING SUM(nvl(x.mto_gan_per_ml, 0)) <> 0
         UNION ALL
         SELECT x.fec_calculo, d.cod_modulo,
                d.cod_mad_transaccion,
                d.cod_ofi_origen,
                d.cod_moneda,
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                d.cod_mad_padre,
                d.descuento,
                'VDAC' tip_calculo,
                SUM(nvl(x.mto_deb_activo, 0))
           FROM lc_devengados d, lc_ope_futuras o, ge_clientes c,
                ge_plz_contables pc, lc_for_dat_val_economico x
          WHERE d.fecha = v_fec_actual
            AND d.cod_modalidad = o.cod_modalidad
            AND d.cod_oficina = o.cod_oficina
            AND d.nro_cuenta = o.nro_cuenta
            AND d.nro_operacion = o.nro_operacion
            AND d.cod_mad_transaccion = o.cod_mad_transaccion
            and x.nro_cuenta = o.nro_cuenta
            and x.nro_operacion = o.nro_operacion
            and x.fecha = d.fecha
            AND c.cod_persona = o.cod_persona
            AND pc.can_dias =
                (SELECT MIN(gp.can_dias)
                   FROM ge_plz_contables gp
                  WHERE can_dias >= (o.fec_vencimiento - o.fec_operacion))
            --Agregado para Proyecto CNFNORMA-274-AJUSTES FORWARD--
            and v_ind_dev_val_economico = 'S'
            and not exists (select 1
                              from ba_cod_referencias x
                             where x.dominio = 'OPE_FUT_DEV_ANTERIOR'
                               and x.val_minimo = o.nro_cuenta||'#'||o.nro_operacion)
            -------------------------------------------------------
          GROUP BY x.fec_calculo, d.cod_modulo,
                   d.cod_mad_transaccion,
                   d.cod_ofi_origen,
                   d.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   d.cod_mad_padre,
                   d.descuento
         HAVING SUM(nvl(x.mto_gan_per_ml, 0)) <> 0
         UNION ALL
         SELECT x.fec_calculo, d.cod_modulo,
                d.cod_mad_transaccion,
                d.cod_ofi_origen,
                d.cod_moneda,
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                d.cod_mad_padre,
                d.descuento,
                'VDPA' tip_calculo,
                SUM(nvl(x.mto_deb_pasivo, 0))
           FROM lc_devengados d, lc_ope_futuras o, ge_clientes c,
                ge_plz_contables pc, lc_for_dat_val_economico x
          WHERE d.fecha = v_fec_actual
            AND d.cod_modalidad = o.cod_modalidad
            AND d.cod_oficina = o.cod_oficina
            AND d.nro_cuenta = o.nro_cuenta
            AND d.nro_operacion = o.nro_operacion
            AND d.cod_mad_transaccion = o.cod_mad_transaccion
            and x.nro_cuenta = o.nro_cuenta
            and x.nro_operacion = o.nro_operacion
            and x.fecha = d.fecha
            AND c.cod_persona = o.cod_persona
            AND pc.can_dias =
                (SELECT MIN(gp.can_dias)
                   FROM ge_plz_contables gp
                  WHERE can_dias >= (o.fec_vencimiento - o.fec_operacion))
            --Agregado para Proyecto CNFNORMA-274-AJUSTES FORWARD--
            and v_ind_dev_val_economico = 'S'
            and not exists (select 1
                              from ba_cod_referencias x
                             where x.dominio = 'OPE_FUT_DEV_ANTERIOR'
                               and x.val_minimo = o.nro_cuenta||'#'||o.nro_operacion)
            -------------------------------------------------------
          GROUP BY x.fec_calculo, d.cod_modulo,
                   d.cod_mad_transaccion,
                   d.cod_ofi_origen,
                   d.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   d.cod_mad_padre,
                   d.descuento
         HAVING SUM(nvl(x.mto_gan_per_ml, 0)) <> 0
         UNION ALL
         SELECT x.fec_calculo, d.cod_modulo,
                d.cod_mad_transaccion,
                d.cod_ofi_origen,
                d.cod_moneda,
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                d.cod_mad_padre,
                d.descuento,
                'VCGA' tip_calculo,
                SUM(nvl(x.mto_cre_ganancia, 0))
           FROM lc_devengados d, lc_ope_futuras o, ge_clientes c,
                ge_plz_contables pc, lc_for_dat_val_economico x
          WHERE d.fecha = v_fec_actual
            AND d.cod_modalidad = o.cod_modalidad
            AND d.cod_oficina = o.cod_oficina
            AND d.nro_cuenta = o.nro_cuenta
            AND d.nro_operacion = o.nro_operacion
            AND d.cod_mad_transaccion = o.cod_mad_transaccion
            and x.nro_cuenta = o.nro_cuenta
            and x.nro_operacion = o.nro_operacion
            and x.fecha = d.fecha
            AND c.cod_persona = o.cod_persona
            AND pc.can_dias =
                (SELECT MIN(gp.can_dias)
                   FROM ge_plz_contables gp
                  WHERE can_dias >= (o.fec_vencimiento - o.fec_operacion))
            --Agregado para Proyecto CNFNORMA-274-AJUSTES FORWARD--
            and v_ind_dev_val_economico = 'S'
            and not exists (select 1
                              from ba_cod_referencias x
                             where x.dominio = 'OPE_FUT_DEV_ANTERIOR'
                               and x.val_minimo = o.nro_cuenta||'#'||o.nro_operacion)
            -------------------------------------------------------
          GROUP BY x.fec_calculo, d.cod_modulo,
                   d.cod_mad_transaccion,
                   d.cod_ofi_origen,
                   d.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   d.cod_mad_padre,
                   d.descuento
         HAVING SUM(nvl(x.mto_gan_per_ml, 0)) <> 0
         UNION ALL
         SELECT x.fec_calculo, d.cod_modulo,
                d.cod_mad_transaccion,
                d.cod_ofi_origen,
                d.cod_moneda,
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                d.cod_mad_padre,
                d.descuento,
                'VCAC' tip_calculo,
                SUM(nvl(x.mto_cre_activo, 0))
           FROM lc_devengados d, lc_ope_futuras o, ge_clientes c,
                ge_plz_contables pc, lc_for_dat_val_economico x
          WHERE d.fecha = v_fec_actual
            AND d.cod_modalidad = o.cod_modalidad
            AND d.cod_oficina = o.cod_oficina
            AND d.nro_cuenta = o.nro_cuenta
            AND d.nro_operacion = o.nro_operacion
            AND d.cod_mad_transaccion = o.cod_mad_transaccion
            and x.nro_cuenta = o.nro_cuenta
            and x.nro_operacion = o.nro_operacion
            and x.fecha = d.fecha
            AND c.cod_persona = o.cod_persona
            AND pc.can_dias =
                (SELECT MIN(gp.can_dias)
                   FROM ge_plz_contables gp
                  WHERE can_dias >= (o.fec_vencimiento - o.fec_operacion))
            --Agregado para Proyecto CNFNORMA-274-AJUSTES FORWARD--
            and v_ind_dev_val_economico = 'S'
            and not exists (select 1
                              from ba_cod_referencias x
                             where x.dominio = 'OPE_FUT_DEV_ANTERIOR'
                               and x.val_minimo = o.nro_cuenta||'#'||o.nro_operacion)
            -------------------------------------------------------
          GROUP BY x.fec_calculo, d.cod_modulo,
                   d.cod_mad_transaccion,
                   d.cod_ofi_origen,
                   d.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   d.cod_mad_padre,
                   d.descuento
         HAVING SUM(nvl(x.mto_gan_per_ml, 0)) <> 0
         UNION ALL
         SELECT x.fec_calculo, d.cod_modulo,
                d.cod_mad_transaccion,
                d.cod_ofi_origen,
                d.cod_moneda,
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                d.cod_mad_padre,
                d.descuento,
                'VCPA' tip_calculo,
                SUM(nvl(x.mto_cre_pasivo, 0))
           FROM lc_devengados d, lc_ope_futuras o, ge_clientes c,
                ge_plz_contables pc, lc_for_dat_val_economico x
          WHERE d.fecha = v_fec_actual
            AND d.cod_modalidad = o.cod_modalidad
            AND d.cod_oficina = o.cod_oficina
            AND d.nro_cuenta = o.nro_cuenta
            AND d.nro_operacion = o.nro_operacion
            AND d.cod_mad_transaccion = o.cod_mad_transaccion
            and x.nro_cuenta = o.nro_cuenta
            and x.nro_operacion = o.nro_operacion
            and x.fecha = d.fecha
            AND c.cod_persona = o.cod_persona
            AND pc.can_dias =
                (SELECT MIN(gp.can_dias)
                   FROM ge_plz_contables gp
                  WHERE can_dias >= (o.fec_vencimiento - o.fec_operacion))
            --Agregado para Proyecto CNFNORMA-274-AJUSTES FORWARD--
            and v_ind_dev_val_economico = 'S'
            and not exists (select 1
                              from ba_cod_referencias x
                             where x.dominio = 'OPE_FUT_DEV_ANTERIOR'
                               and x.val_minimo = o.nro_cuenta||'#'||o.nro_operacion)
            -------------------------------------------------------
          GROUP BY x.fec_calculo, d.cod_modulo,
                   d.cod_mad_transaccion,
                   d.cod_ofi_origen,
                   d.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   d.cod_mad_padre,
                   d.descuento
         HAVING SUM(nvl(x.mto_gan_per_ml, 0)) <> 0;
      --
      CURSOR cur5 IS
         SELECT *
           FROM ge_tip_asientos
          WHERE cod_tip_asiento = v_cod_tip_asiento
            AND cod_moneda = v_cod_moneda
            AND cod_sec_contable = v_cod_sec_contable
            AND (ind_residente = v_residente OR ind_residente = 'X');
   BEGIN
      v_ind_dev_val_economico := nvl(fug_obt_pardinamico('IND_DEV_VAL_ECONOMICO'),'N');
      OPEN cur3;
      LOOP
         FETCH cur3
            INTO v_fec_calculo, v_cod_modulo,
                 v_cod_mad_transaccion,
                 v_cod_ofi_origen,
                 v_cod_moneda,
                 v_cod_sec_contable,
                 v_residente,
                 v_cod_tip_deudor,
                 v_cod_plazo,
                 v_cod_mad_padre,
                 v_descuento,
                 v_tip_calculo,
                 v_mto_interes;
         EXIT WHEN cur3%NOTFOUND;
         --- ve el tipo de asiento ---
         IF v_cod_mad_padre = 76 THEN
            -- operaciones futuras --
            v_cod_transaccion := fue_obt_des_refcodes('TIP_TRA_FORWARD',v_tip_calculo);
         ELSE
            raise_application_error(-20004,
                                    'ERROR. La modalidad ' || to_char(v_cod_mad_padre) ||
                                     ' no esta definida ');
         END IF;
         BEGIN
            SELECT cod_tip_asiento, descripcion
              INTO v_cod_tip_asiento, v_descripcion
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_mad_transaccion
               AND cod_transaccion = v_cod_transaccion
               AND cod_tip_asiento IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'No tiene Asiento Relac. para Deveng.: ' ||
                                        to_char(v_cod_modulo) || '-' ||
                                        to_char(v_cod_mad_transaccion) || '-' ||
                                        to_char(v_cod_transaccion));
            WHEN OTHERS THEN
               raise_application_error(-20001, SQLERRM);
         END;
         ------------------------
         xx_immovgs := v_mto_interes;
         xx_immovex := 0;
         xx_vltasci := 0;
         -------------------------------
         ----- ciclo para GE_TIP_ASIENTOS ------

         IF cur5%ISOPEN THEN
            CLOSE cur5;
         END IF;
         OPEN cur5;
         r_baade.nro_linea := 0;
         r_baade.fecha     := v_fec_actual;
         LOOP
            FETCH cur5
               INTO r_gtasi;
            EXIT WHEN cur5%NOTFOUND;
            ---Agregado por agustin para el nuevo plan de cuentas ---
            IF r_gtasi.ind_deudor = 'S' THEN
               r_baade.cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) ||
                                    ltrim(to_char(v_cod_tip_deudor, '00')) ||
                                    substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               r_baade.cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---------------------------------------------------------
            IF r_gtasi.ind_plazo = 'S' THEN
               r_baade.cod_rubro := substr(r_baade.cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                                    substr(r_baade.cod_rubro, 4, 12);
            END IF;
            --
            v_encontro := 'S';
            --
            lp_obt_mon_rubro(r_baade.cod_rubro, v_cod_mon_cta, v_encontro);
            IF v_encontro = 'N' THEN
               --r_baade.cod_rubro  := '999999999999999';
               v_cod_mon_cta := v_cod_mon_local;
            END IF;
            --
            IF v_cod_mon_cta = v_cod_mon_local THEN
               -- moneda local --
               r_baade.mto_mon_rubro  := 0;
               r_baade.val_cotizacion := 0;
            ELSE
               r_baade.mto_mon_rubro  := xx_immovex;
               r_baade.val_cotizacion := xx_vltasci;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            IF xx_immovgs > 0 THEN
               r_baade.tip_movimiento := r_gtasi.tip_movimiento;
               r_baade.mto_mon_local  := xx_immovgs;
            ELSE
               r_baade.mto_mon_local := xx_immovgs * -1;
               r_baade.mto_mon_rubro := r_baade.mto_mon_rubro * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  r_baade.tip_movimiento := 'D';
               ELSE
                  r_baade.tip_movimiento := 'C';
               END IF;
            END IF;
            IF r_baade.mto_mon_local <> 0 THEN
               --
               --r_baade.referencia     := 'DEVENG.';
               r_baade.referencia     := to_char(v_fec_calculo,'dd/mm/yyyy');
               r_baade.descripcion    := to_char(v_cod_modulo) || ' ' ||
                                         to_char(v_cod_mad_transaccion) || ' ' ||
                                         to_char(v_cod_transaccion) || ' ' ||
                                         substr(v_descripcion, 1, 20);
               r_baade.cod_ofi_origen := v_cod_ofi_origen;
               r_baade.cod_oficina    := v_cod_ofi_origen;
               r_baade.cod_modulo     := v_cod_modulo;
               r_baade.protegido      := 'N';
               r_baade.actualizado    := 'N';
               r_baade.distribuido    := 'N';
               r_baade.cod_modulo     := v_cod_modulo;
               r_baade.cod_modalidad  := v_cod_mad_transaccion;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := r_baade.nro_linea + 1;
               --
               lp_ins_asi_aut_det(r_baade);
            END IF;
         END LOOP; -- fin de tipo de asientos --
         close cur5; --FIELDESK-61066
      END LOOP; -- fin del ciclo de intereses devengados --
      close cur3;--FIELDESK-61066
   END;

   PROCEDURE lp_dev_ope_fut_val_can IS
      v_fec_actual      ge_calendarios.fec_actual%TYPE := pae_cnf.fu_obt_fec_actual(7);
      v_cod_mon_local   ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
      v_cod_mon_cta     ba_monedas.cod_moneda%TYPE;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      v_descripcion     ge_transacciones.descripcion%TYPE;
      v_cod_tip_asiento ge_transacciones.cod_tip_asiento%TYPE;
      v_encontro        VARCHAR2(1);
      -- Variables Cursor
      v_cod_modulo          lc_devengados.cod_modulo%TYPE;
      v_cod_mad_transaccion lc_devengados.cod_mad_transaccion%TYPE;
      v_cod_ofi_origen      lc_devengados.cod_oficina%TYPE;
      v_cod_moneda          lc_devengados.cod_moneda%TYPE;
      v_mto_interes         lc_devengados.mto_interes%TYPE;
      v_cod_mad_padre       lc_devengados.cod_mad_padre%TYPE;
      v_descuento           lc_devengados.descuento%TYPE;
      v_residente           ge_clientes.residente%TYPE;
      v_cod_sec_contable    ge_clientes.cod_sec_contable%TYPE;
      v_cod_tip_deudor      ge_clientes.cod_tip_deudor%TYPE;
      v_cod_tip_deu_aux     ge_clientes.cod_tip_deudor%TYPE;
      v_cod_plazo           ge_plz_contables.cod_plazo%TYPE;
      --
      xx_immovgs NUMBER;
      xx_immovex NUMBER;
      xx_vltasci NUMBER;
      --
      r_baade cb_asi_automaticos_det_tmp%ROWTYPE;
      r_gtasi ge_tip_asientos%ROWTYPE;
      v_tip_calculo  varchar2(10);
      v_ind_dev_val_economico ge_par_dinamicos.val_parametro%type;
      v_fec_calculo date;
      ----------------------------------------------------------------------
      -- Leer todas las operaciones a futuro vigentes -- MODALIDAD = 76   --
      ----------------------------------------------------------------------
      CURSOR cur3 IS
         SELECT x.fec_calculo, o.cod_modulo,
                o.cod_mad_transaccion,
                o.cod_ofi_origen,
                v_cod_mon_local,
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                o.cod_mad_padre,
                'N' descuento,
                'CDPE' tip_calculo,
                sum(nvl(x.moc_deb_perdida, 0))
           FROM lc_ope_futuras o, ge_clientes c,
                ge_plz_contables pc, lc_for_dat_val_economico x
          WHERE o.estado = 'L'
            and o.fec_liquidacion = v_fec_actual
            and x.nro_cuenta = o.nro_cuenta
            and x.nro_operacion = o.nro_operacion
            and x.fec_calculo = o.fec_vencimiento
            AND c.cod_persona = o.cod_persona
            AND pc.can_dias =
                (SELECT MIN(gp.can_dias)
                   FROM ge_plz_contables gp
                  WHERE can_dias >= (o.fec_vencimiento - o.fec_operacion))
            --Agregado para Proyecto CNFNORMA-274-AJUSTES FORWARD--
            and v_ind_dev_val_economico = 'S'
            and not exists (select 1
                              from ba_cod_referencias x
                             where x.dominio = 'OPE_FUT_DEV_ANTERIOR'
                               and x.val_minimo = o.nro_cuenta||'#'||o.nro_operacion)
            --------------------------------------------------------
          GROUP BY x.fec_calculo, o.cod_modulo,
                   o.cod_mad_transaccion,
                   o.cod_ofi_origen,
                   v_cod_mon_local,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   o.cod_mad_padre,
                   'N'
         HAVING SUM(nvl(x.val_economico, 0)) <> 0
         UNION ALL
         SELECT x.fec_calculo, o.cod_modulo,
                o.cod_mad_transaccion,
                o.cod_ofi_origen,
                v_cod_mon_local,
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                o.cod_mad_padre,
                'N' descuento,
                'CCAC' tip_calculo,
                sum(nvl(x.moc_cre_activo, 0))
           FROM lc_ope_futuras o, ge_clientes c,
                ge_plz_contables pc, lc_for_dat_val_economico x
          WHERE o.estado = 'L'
            and o.fec_liquidacion = v_fec_actual
            and x.nro_cuenta = o.nro_cuenta
            and x.nro_operacion = o.nro_operacion
            and x.fec_calculo = o.fec_vencimiento
            AND c.cod_persona = o.cod_persona
            AND pc.can_dias =
                (SELECT MIN(gp.can_dias)
                   FROM ge_plz_contables gp
                  WHERE can_dias >= (o.fec_vencimiento - o.fec_operacion))
            --Agregado para Proyecto CNFNORMA-274-AJUSTES FORWARD--
            and v_ind_dev_val_economico = 'S'
            and not exists (select 1
                              from ba_cod_referencias x
                             where x.dominio = 'OPE_FUT_DEV_ANTERIOR'
                               and x.val_minimo = o.nro_cuenta||'#'||o.nro_operacion)
            --------------------------------------------------------
          GROUP BY x.fec_calculo, o.cod_modulo,
                   o.cod_mad_transaccion,
                   o.cod_ofi_origen,
                   v_cod_mon_local,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   o.cod_mad_padre,
                   'N'
         HAVING SUM(nvl(x.val_economico, 0)) <> 0
         UNION ALL
         SELECT x.fec_calculo, o.cod_modulo,
                o.cod_mad_transaccion,
                o.cod_ofi_origen,
                v_cod_mon_local,
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                o.cod_mad_padre,
                'N' descuento,
                'CCGA' tip_calculo,
                sum(nvl(x.moc_cre_ganancia, 0))
           FROM lc_ope_futuras o, ge_clientes c,
                ge_plz_contables pc, lc_for_dat_val_economico x
          WHERE o.estado = 'L'
            and o.fec_liquidacion = v_fec_actual
            and x.nro_cuenta = o.nro_cuenta
            and x.nro_operacion = o.nro_operacion
            and x.fec_calculo = o.fec_vencimiento
            AND c.cod_persona = o.cod_persona
            AND pc.can_dias =
                (SELECT MIN(gp.can_dias)
                   FROM ge_plz_contables gp
                  WHERE can_dias >= (o.fec_vencimiento - o.fec_operacion))
            --Agregado para Proyecto CNFNORMA-274-AJUSTES FORWARD--
            and v_ind_dev_val_economico = 'S'
            and not exists (select 1
                              from ba_cod_referencias x
                             where x.dominio = 'OPE_FUT_DEV_ANTERIOR'
                               and x.val_minimo = o.nro_cuenta||'#'||o.nro_operacion)
            --------------------------------------------------------
          GROUP BY x.fec_calculo, o.cod_modulo,
                   o.cod_mad_transaccion,
                   o.cod_ofi_origen,
                   v_cod_mon_local,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   o.cod_mad_padre,
                   'N'
         HAVING SUM(nvl(x.val_economico, 0)) <> 0
         UNION ALL
         SELECT x.fec_calculo, o.cod_modulo,
                o.cod_mad_transaccion,
                o.cod_ofi_origen,
                v_cod_mon_local,
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                o.cod_mad_padre,
                'N' descuento,
                'CDPA' tip_calculo,
                sum(nvl(x.moc_deb_pasivo, 0))
           FROM lc_ope_futuras o, ge_clientes c,
                ge_plz_contables pc, lc_for_dat_val_economico x
          WHERE o.estado = 'L'
            and o.fec_liquidacion = v_fec_actual
            and x.nro_cuenta = o.nro_cuenta
            and x.nro_operacion = o.nro_operacion
            and x.fec_calculo = o.fec_vencimiento
            AND c.cod_persona = o.cod_persona
            AND pc.can_dias =
                (SELECT MIN(gp.can_dias)
                   FROM ge_plz_contables gp
                  WHERE can_dias >= (o.fec_vencimiento - o.fec_operacion))
            --Agregado para Proyecto CNFNORMA-274-AJUSTES FORWARD--
            and v_ind_dev_val_economico = 'S'
            and not exists (select 1
                              from ba_cod_referencias x
                             where x.dominio = 'OPE_FUT_DEV_ANTERIOR'
                               and x.val_minimo = o.nro_cuenta||'#'||o.nro_operacion)
            --------------------------------------------------------
          GROUP BY x.fec_calculo, o.cod_modulo,
                   o.cod_mad_transaccion,
                   o.cod_ofi_origen,
                   v_cod_mon_local,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   o.cod_mad_padre,
                   'N'
         HAVING SUM(nvl(x.val_economico, 0)) <> 0;
      --
      CURSOR cur5 IS
         SELECT *
           FROM ge_tip_asientos
          WHERE cod_tip_asiento = v_cod_tip_asiento
            AND cod_moneda = v_cod_moneda
            AND cod_sec_contable = v_cod_sec_contable
            AND (ind_residente = v_residente OR ind_residente = 'X');
   BEGIN
      v_ind_dev_val_economico := nvl(fug_obt_pardinamico('IND_DEV_VAL_ECONOMICO'),'N');
      OPEN cur3;
      LOOP
         FETCH cur3
            INTO v_fec_calculo, v_cod_modulo,
                 v_cod_mad_transaccion,
                 v_cod_ofi_origen,
                 v_cod_moneda,
                 v_cod_sec_contable,
                 v_residente,
                 v_cod_tip_deudor,
                 v_cod_plazo,
                 v_cod_mad_padre,
                 v_descuento,
                 v_tip_calculo,
                 v_mto_interes;
         EXIT WHEN cur3%NOTFOUND;
         --- ve el tipo de asiento ---
         IF v_cod_mad_padre = 76 THEN
            -- operaciones futuras --
            v_cod_transaccion := fue_obt_des_refcodes('TIP_TRA_FORWARD',v_tip_calculo);
         ELSE
            raise_application_error(-20004,
                                    'ERROR. La modalidad ' || to_char(v_cod_mad_padre) ||
                                     ' no esta definida ');
         END IF;
         BEGIN
            SELECT cod_tip_asiento, descripcion
              INTO v_cod_tip_asiento, v_descripcion
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_mad_transaccion
               AND cod_transaccion = v_cod_transaccion
               AND cod_tip_asiento IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'No tiene Asiento Relac. para Deveng.: ' ||
                                        to_char(v_cod_modulo) || '-' ||
                                        to_char(v_cod_mad_transaccion) || '-' ||
                                        to_char(v_cod_transaccion));
            WHEN OTHERS THEN
               raise_application_error(-20001, SQLERRM);
         END;
         ------------------------
         xx_immovgs := v_mto_interes;
         xx_immovex := 0;
         xx_vltasci := 0;
         -------------------------------
         ----- ciclo para GE_TIP_ASIENTOS ------

         IF cur5%ISOPEN THEN
            CLOSE cur5;
         END IF;
         OPEN cur5;
         r_baade.nro_linea := 0;
         r_baade.fecha     := v_fec_actual;
         LOOP
            FETCH cur5
               INTO r_gtasi;
            EXIT WHEN cur5%NOTFOUND;
            ---Agregado por agustin para el nuevo plan de cuentas ---
            IF r_gtasi.ind_deudor = 'S' THEN
               r_baade.cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) ||
                                    ltrim(to_char(v_cod_tip_deudor, '00')) ||
                                    substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               r_baade.cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---------------------------------------------------------
            IF r_gtasi.ind_plazo = 'S' THEN
               r_baade.cod_rubro := substr(r_baade.cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                                    substr(r_baade.cod_rubro, 4, 12);
            END IF;
            --
            v_encontro := 'S';
            --
            lp_obt_mon_rubro(r_baade.cod_rubro, v_cod_mon_cta, v_encontro);
            IF v_encontro = 'N' THEN
               --r_baade.cod_rubro  := '999999999999999';
               v_cod_mon_cta := v_cod_mon_local;
            END IF;
            --
            IF v_cod_mon_cta = v_cod_mon_local THEN
               -- moneda local --
               r_baade.mto_mon_rubro  := 0;
               r_baade.val_cotizacion := 0;
            ELSE
               r_baade.mto_mon_rubro  := xx_immovex;
               r_baade.val_cotizacion := xx_vltasci;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            IF xx_immovgs > 0 THEN
               r_baade.tip_movimiento := r_gtasi.tip_movimiento;
               r_baade.mto_mon_local  := xx_immovgs;
            ELSE
               r_baade.mto_mon_local := xx_immovgs * -1;
               r_baade.mto_mon_rubro := r_baade.mto_mon_rubro * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  r_baade.tip_movimiento := 'D';
               ELSE
                  r_baade.tip_movimiento := 'C';
               END IF;
            END IF;
            IF r_baade.mto_mon_local <> 0 THEN
               --
               --r_baade.referencia     := 'DEVENG.';
               r_baade.referencia     := to_char(v_fec_calculo,'dd/mm/yyyy');
               r_baade.descripcion    := to_char(v_cod_modulo) || ' ' ||
                                         to_char(v_cod_mad_transaccion) || ' ' ||
                                         to_char(v_cod_transaccion) || ' ' ||
                                         substr(v_descripcion, 1, 20);
               r_baade.cod_ofi_origen := v_cod_ofi_origen;
               r_baade.cod_oficina    := v_cod_ofi_origen;
               r_baade.cod_modulo     := v_cod_modulo;
               r_baade.protegido      := 'N';
               r_baade.actualizado    := 'N';
               r_baade.distribuido    := 'N';
               r_baade.cod_modulo     := v_cod_modulo;
               r_baade.cod_modalidad  := v_cod_mad_transaccion;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := r_baade.nro_linea + 1;
               --
               lp_ins_asi_aut_det(r_baade);
            END IF;
         END LOOP; -- fin de tipo de asientos --
         close cur5;--FIELDESK-61066
      END LOOP; -- fin del ciclo de intereses devengados --
      close cur3; --FIELDESK-61066
   END;

   /* Insertar asientos automaticos detalles. */
   PROCEDURE lp_ins_asi_aut_det(rp_baade IN cb_asi_automaticos_det_tmp%ROWTYPE) IS
   BEGIN
      INSERT INTO cb_asi_automaticos_det_tmp
         (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_rubro,
          mto_mon_local, descripcion, referencia, protegido, actualizado, val_cotizacion,
          distribuido, ref_movimiento, cod_modulo, cod_modalidad, cod_ofi_origen, cod_tra_padre, fec_valor)
      VALUES
         (rp_baade.fecha, rp_baade.cod_oficina, rp_baade.nro_asiento, rp_baade.nro_linea,
          rp_baade.cod_rubro, rp_baade.tip_movimiento, rp_baade.mto_mon_rubro,
          rp_baade.mto_mon_local, rp_baade.descripcion, rp_baade.referencia, rp_baade.protegido,
          rp_baade.actualizado, rp_baade.val_cotizacion, rp_baade.distribuido,
          rp_baade.ref_movimiento, rp_baade.cod_modulo, rp_baade.cod_modalidad,
          rp_baade.cod_ofi_origen, rp_baade.cod_tra_padre, rp_baade.fec_valor);
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 'Ins.cb_asi_automaticos_det_tmp ' || rp_baade.nro_asiento || '-' ||
                                  rp_baade.referencia || '-' || SQLERRM);
   END;
   /* Obtener la moneda del rubro del parametro. */
   PROCEDURE lp_obt_mon_rubro
   (
      p_cod_rubro  IN cb_rubros.cod_moneda%TYPE,
      p_cod_moneda IN OUT cb_rubros.cod_moneda%TYPE,
      p_encontro   IN OUT VARCHAR2
   ) IS
   BEGIN
      SELECT cod_moneda INTO p_cod_moneda FROM cb_rubros WHERE cod_rubro = p_cod_rubro;
   EXCEPTION
      WHEN no_data_found THEN
         -- OJO!!! solucion temporal desde aqui ---------------
         IF substr(p_cod_rubro, 14, 2) IN ('99', '00') THEN
            p_cod_moneda := pag_gen.fu_obt_mon_local;
            p_encontro   := 'S';
         ELSIF substr(p_cod_rubro, 14, 2) IN ('01', '98') THEN
            p_cod_moneda := pag_gen.fu_obt_mon_fuerte;
            p_encontro   := 'S';
         ELSE
            -- OJO!! temporal hasta aqui -------------------------
            p_encontro := 'N';
         END IF;
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Rec. Rubro ' || p_cod_rubro || '-' || SQLERRM);
   END;

  --Proposito: buscar y actualizar parámetro temporal de Nro. Asiento
  procedure lp_act_par_dinamico (p_tip_actualizacion varchar2)is

  v_nro_actual ge_par_dinamicos.val_parametro%type;

  begin
  if p_tip_actualizacion = 'T' then
     --Tipo de Procesamiento Temporal
    begin
      select g.val_parametro
        into v_nro_actual
        from ge_par_dinamicos g
       where g.parametro = 'SIG_NRO_ASI_AUTOM';
    exception
      when no_data_found then
        v_nro_actual := 0;
      when others then
        v_nro_actual := 0;
    end;


    if nvl(v_nro_actual,0) <> 0 then
       prg_act_par_dinamico('SIG_NRO_ASI_AUTOM_TMP', NULL, NULL, NULL, NULL, v_nro_actual);
    end if;
  Elsif p_tip_actualizacion = 'P' then
    --Tipo de Procesamiento Permanente
      begin
        select g.val_parametro
          into v_nro_actual
          from ge_par_dinamicos g
         where g.parametro = 'SIG_NRO_ASI_AUTOM_TMP';
      exception
        when no_data_found then
          v_nro_actual := 0;
        when others then
          v_nro_actual := 0;
      end;


      if nvl(v_nro_actual,0) <> 0 then
         prg_act_par_dinamico('SIG_NRO_ASI_AUTOM', NULL, NULL, NULL, NULL, v_nro_actual);
      end if;
    end if;


  end;

  --Proposito: transferir a tablas reales cabecera de asientos generados
  procedure lp_act_cab_asi_generado is
  begin
    insert into cb_asi_automaticos
    (select * from cb_asi_automaticos_tmp);
  end;


  --Proposito: transferir a tablas reales detalle de asientos generados
  procedure lp_act_det_asi_generado is

    TYPE array_tabla_cb IS TABLE OF cb_asi_automaticos_det%ROWTYPE INDEX BY BINARY_INTEGER;
      CURSOR c IS
         SELECT *
           FROM cb_asi_automaticos_det_tmp m;

   v_cb_asi_automaticos_det array_tabla_cb;
   v_tra_asi_modo    ge_par_dinamicos.val_parametro%TYPE:= NVL(fug_obt_pardinamico('PRA_GEN_ASI_PARALLEL'), 'NORMAL');
   v_tam_fragmento  ge_par_dinamicos.val_parametro%TYPE:= NVL(fug_obt_pardinamico('PRA_GEN_ASI_TAM_FRAG'), '25000');
   v_job_cant       ge_par_dinamicos.val_parametro%TYPE:= NVL(fug_obt_pardinamico('PRA_GEN_ASI_JOB_CANT'), '6');
   v_tarea          VARCHAR2(128) := 'pra_gen_asi_CB_PARALELO';

  begin
    delete from cb_asi_automaticos_det_tmp
    where nro_asiento = 0;
   BEGIN
     IF 'PARALLEL_EXECUTE' = v_tra_asi_modo THEN
        BEGIN
          -- Eliminar la tarea y los fragmentos relacionados
          DBMS_PARALLEL_EXECUTE.DROP_TASK(v_tarea);
       EXCEPTION
          WHEN DBMS_PARALLEL_EXECUTE.TASK_NOT_FOUND THEN
             NULL;
       END;
       -- Crear la tarea
       DBMS_PARALLEL_EXECUTE.create_task(v_tarea);
       -- Dividir la tabla por ROWID en intervalos
       DBMS_PARALLEL_EXECUTE.CREATE_CHUNKS_BY_ROWID(v_tarea, 'IT', 'CB_ASI_AUTOMATICOS_DET_TMP', true, TO_NUMBER(v_tam_fragmento));
       -- Ejecutar el DML en paralelo
       DBMS_PARALLEL_EXECUTE.run_task(task_name      => v_tarea,
                                      sql_stmt       =>
'DECLARE
   v_info  VARCHAR2(512);
   v_cant  PLS_INTEGER;
BEGIN
   pre_ini_aplicacion;
   pae_cnf.g_cod_modulo := 1;

   pag_cie.PR_SET_PARAMETROS(11, 370, ''PRA_GEN_ASI_AUTOMATICOS'', ''CHUNK'', pag_cie.c_log_TRACE);

   SELECT ''{job:''||job_name||'' chid:''||chunk_id||''}''
   INTO v_info
   FROM user_parallel_execute_chunks
   WHERE task_name = ''pra_gen_asi_CB_PARALELO''
     AND start_rowid = :start_id
     AND end_rowid = :end_id;

   pag_cie.PR_INS_LOG(v_info||'' [ ''||:start_id||'' ; ''||:end_id||'' ] '', pag_cie.c_log_TRACE, ''AUTONOMOUS_TRANSACTION'');

   SELECT COUNT(1)
   INTO v_cant
   FROM user_parallel_execute_chunks
   WHERE task_name = ''pra_gen_asi_CB_PARALELO''
     AND status = ''PROCESSED_WITH_ERROR''
     AND rownum = 1;

   IF v_cant > 0 THEN
      raise_application_error(-20015, ''Falló un Fragmento de la Tarea. Fin por Interrupción temparana.'');
   END IF;

   INSERT INTO CB_ASI_AUTOMATICOS_DET
   SELECT * FROM CB_ASI_AUTOMATICOS_DET_TMP
   WHERE rowid BETWEEN :start_id AND :end_id;

   COMMIT;
EXCEPTION
   WHEN OTHERS THEN
      pag_cie.PR_INS_LOG(v_info||'' [ ''||:start_id||'' ; ''||:end_id||'' ] EXCEPTION: ''||SQLERRM, pag_cie.c_log_TRACE, ''AUTONOMOUS_TRANSACTION'');
      RAISE;
END;',
                                     language_flag  => DBMS_SQL.NATIVE,
                                     parallel_level => TO_NUMBER(v_job_cant));
    
       --Verificar el estatus de la ejecucion
       IF DBMS_PARALLEL_EXECUTE.FINISHED != DBMS_PARALLEL_EXECUTE.TASK_STATUS(v_tarea) THEN
          raise_application_error(-20000, 'ERROR DBMS_PARALLEL_EXECUTE. Revisar Tarea: ' || v_tarea);
       END IF;
     ELSE 
         OPEN c;
          LOOP
             FETCH c BULK COLLECT
                INTO v_cb_asi_automaticos_det LIMIT 80000;
             BEGIN
                FORALL i IN 1 .. v_cb_asi_automaticos_det.count
                   INSERT INTO cb_asi_automaticos_det VALUES v_cb_asi_automaticos_det (i);
             EXCEPTION
                WHEN OTHERS THEN
                   raise_application_error(-20000, 'ERROR. En cb_asi_automaticos_det.'||sqlerrm);
             END;
             EXIT WHEN c%NOTFOUND;
          END LOOP;
          CLOSE c;
       END IF;
       COMMIT;     
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR. En lp_act_det_asi_generado.'||sqlerrm);
   END;
  end;
  procedure lp_act_tab_temporales is

  begin
     Execute Immediate 'truncate table cb_asi_automaticos_tmp';
     Execute Immediate 'truncate table cb_asi_automaticos_det_tmp';
  end;

  ---El próposito de la función es verificar si exiten asientos generados de la fecha
  function lf_exi_asi_generado return number is

  v_exi_asi_cabecera       number;
  v_exi_asi_detalle        number;
  v_exi_asiento            number;
  begin
    begin
      select nvl(count(*),0)
        into v_exi_asi_cabecera
        from cb_asi_automaticos
       where fecha = v_fec_actual;
    exception
      when no_data_found then
        v_exi_asi_cabecera := 0;
      when others then
        v_exi_asi_cabecera := 99;
    end;
    begin
      select nvl(count(*), 0)
        into v_exi_asi_detalle
        from cb_asi_automaticos_det
       where fecha = v_fec_actual;
    exception
      when no_data_found then
        v_exi_asi_detalle := 0;
      when others then
        v_exi_asi_detalle := 99;
    end;
    v_exi_asiento := v_exi_asi_cabecera + v_exi_asi_detalle;
    return v_exi_asiento;

  exception
    when others then
      return nvl(v_exi_asiento,99);
  end;

  procedure lp_eli_asi_generado is

  begin
     -----------------------------------
     -- limpia las tablas de asientos --
     -----------------------------------
     DELETE cb_asi_automaticos_det WHERE fecha = v_fec_actual;
     DELETE cb_asi_automaticos WHERE fecha = v_fec_actual;
  end;



BEGIN

   v_lugar := 'INICIO';

   --Obtiene las Fechas necesarias----------------------
   pag_cal.pr_obt_dat_calendar(pae_cnf.g_cod_modulo);
   v_fec_actual        := pag_cal.g_fec_actual;
   v_ult_dia_mes_habil := pag_cal.g_ult_dia_mes_habil;
   -----------------------------------------------------
   --Obtiene la Moneda Local
   v_cod_mon_local := pag_gen.fu_obt_mon_local;
   -----------------------------------------------------
   v_cod_oficina := 0;

   ---llama a procedimientos --
   ----------------------------
   --

   --Obtener valor configurado que indica transferir a asientos los datos tmp generados
   v_tra_asientos := fug_obt_pardinamico('IND_ACT_ASI_GENERADOS');
   v_gen_asi_aju_re4 := fug_obt_pardinamico('IND_GEN_ASI_AJU_RE4');

   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   V_LUGAR := 'lp_act_tab_temporales';
   lp_act_tab_temporales;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('pra_gen_asi_automaticos',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);


   V_LUGAR :='LP_ACT_PAR_DINAMICO_T';
   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   lp_act_par_dinamico('T');
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('pra_gen_asi_automaticos',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);


   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   v_lugar := 'LP_EQU_MON_LOCAL';
   lp_equ_mon_local;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('pra_gen_asi_automaticos',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);

   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   v_lugar := 'LP_ESTADISTICO';
   lp_estadistico;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('pra_gen_asi_automaticos',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);

   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   v_lugar := 'LP_MOV_DIARIOS';
   lp_mov_diarios;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('pra_gen_asi_automaticos',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);

   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   v_lugar := 'LP_INT_DEVENGADOS';
   lp_int_devengados;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('pra_gen_asi_automaticos',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);


   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   v_lugar := 'LP_INT_DEV_CTA_BASICA';
   lp_int_dev_cta_basica;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('pra_gen_asi_automaticos',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);


   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   v_lugar := 'LP_INT_DEV_PRESTAMOS';
   lp_int_dev_prestamos;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('pra_gen_asi_automaticos',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);
   --04/05 Devengado paralelo Cancelaciones Res 4 BCP
   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   v_lugar := 'LP_INT_DEV_PRESTAMOS_CAN_RE4';
   lp_int_dev_prestamos_can_re4;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('pra_gen_asi_automaticos',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);
   ------
   --04/05 Devengado paralelo Res 4 BCP
   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   v_lugar := 'LP_INT_DEV_PRESTAMOS_RE4';
   lp_int_dev_prestamos_re4;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('pra_gen_asi_automaticos',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);

   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   v_lugar := 'LP_INT_DEV_COMISIONES';
   lp_int_dev_comisiones;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('pra_gen_asi_automaticos',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);

   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   v_lugar := 'LP_INT_DEV_MESADINERO';
   lp_int_dev_mesadinero;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('pra_gen_asi_automaticos',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);

   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   v_lugar := 'PRC_AJU_SOBREGIROS';


   /**********************************************************/
   --CONTABILIZACION DE CONTINGENCIA DE LINEAS DE SOBREGIROS BBVA
   prc_gen_asi_aut_sobregiros;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('pra_gen_asi_automaticos',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);
   /*************************************************/

   --------------------------------------------------
   -- solo si es fin de mes
   --------------------------------------------------
   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   v_lugar := 'LP_DEV_OPE_FUTURAS';
   IF v_ult_dia_mes_habil = v_fec_actual THEN
      -- Devenga Operaciones Futuras.
      lp_dev_ope_futuras;
   END IF;
   --Valor Economico - Contab. diaria - Forward Oper.Futuras--
   lp_dev_ope_fut_valeco;
   --Valor Economico - Cancel. Resul. - Forward Oper.Futuras--
   lp_dev_ope_fut_val_can;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('pra_gen_asi_automaticos',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);

   --Asientos de Ajuste Resolucion 4--
   if nvl(v_gen_asi_aju_re4, 'N') = 'S' then
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      v_lugar := 'LP_INT_DEV_PRE_AJU_RE4';
      lp_int_dev_pre_aju_re4;
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('pra_gen_asi_automaticos',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);
   end if;

   -----------------------------------------------------------
   -- genera la cabecera a partir de los detalles generados --
   -----------------------------------------------------------
   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   v_lugar := 'LP_CAB_ASIENTO';
   lp_cab_asiento;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('pra_gen_asi_automaticos',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);

   BEGIN
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
   END;

   commit;
   if nvl(v_tra_asientos, 'N') = 'S' then
      if lf_exi_asi_generado > 0 Then
         v_lugar := 'LP_ELI_ASI_GENERADO';
         v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
         lp_eli_asi_generado;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');
         prg_act_log_procesos('pra_gen_asi_automaticos',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);
      end if;

      v_lugar := 'LP_ACT_CAB_ASI_GENERADO';
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      lp_act_cab_asi_generado;
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('pra_gen_asi_automaticos',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);
      v_lugar := 'LP_ACT_DET_ASI_GENERADO';
      lp_act_det_asi_generado;
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('pra_gen_asi_automaticos',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);

     ---ACTIVAR RECIEN CUANDO SE PASE A PRODUCCION
      V_LUGAR := 'LP_ACT_PAR_DINAMICO_P';
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      lp_act_par_dinamico('P');
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('pra_gen_asi_automaticos',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);
   end if;

   v_lugar := 'FIN LP_CAB_ASIENTO';

exception
  when others then
      raise_application_error(-20001, 'Error en proc. ' ||'- Linea: '||dbms_utility.format_error_backtrace ||'-'|| sqlerrm); --FIELDESK-61066
END;