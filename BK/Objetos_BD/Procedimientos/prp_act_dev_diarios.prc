create or replace procedure it.prp_act_dev_diarios is
  v_fec_actual       ge_calendarios.fec_actual%TYPE := pag_cal.fu_obt_fec_actual(6);
  v_min_fecha        date;
  v_cod_mon_local    ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;

  v_ind_deudor       ge_tip_asientos.ind_deudor%type;
  v_cod_rubro        ge_tip_asientos.cod_rubro%type;
  v_ind_plazo        ge_tip_asientos.ind_plazo%type;
  v_ind_producto     ge_tip_asientos.ind_producto%type;
  v_tip_mov_asi      ge_tip_asientos.tip_movimiento%type;
  v_tip_movimiento   ge_tip_asientos.tip_movimiento%TYPE;
  v_mon_rubro        cb_rubros.cod_moneda%TYPE;
  v_mto_cotizacion   ge_cotizaciones.val_conversion%TYPE;
  v_cod_sec_contable ge_sec_contables.cod_sec_contable%TYPE;
  v_cod_tip_asi_cre  ge_tip_asientos.cod_tip_asiento%TYPE;
  v_des_tra_cre      ge_transacciones.descripcion%TYPE;
  v_cod_tip_asi2_cre ge_tip_asientos.cod_tip_asiento%TYPE;
  v_cod_tip_asi_deb  ge_tip_asientos.cod_tip_asiento%TYPE;
  v_des_tra_deb      ge_transacciones.descripcion%TYPE;
  v_cod_tip_asi2_deb ge_tip_asientos.cod_tip_asiento%TYPE;
  v_cod_plazo        ge_plz_contables.cod_plazo%TYPE;
  v_tip_deudor       ge_clientes.cod_tip_deudor%TYPE;
  v_residente        ge_clientes.residente%TYPE;
  v_mto_interes      ah_devengados.mto_interes%TYPE;
  v_cod_moneda       ah_cta_vistas.cod_moneda%TYPE;
  v_nro_cuenta       ge_cuentas.nro_cuenta%TYPE;
  v_cod_oficina      ah_cta_vistas.cod_oficina%TYPE;
  v_cod_modalidad    ah_cta_vistas.cod_modalidad%TYPE;
  v_cod_modulo       ah_cta_vistas.cod_modulo%TYPE;
  v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
  v_est_cuenta       ge_tip_asientos.est_cuenta%TYPE;
  v_tip_cuenta       ge_tip_asientos.tip_cuenta%TYPE;
  v_tip_interes      ge_tip_asientos.tip_interes%TYPE;
  v_tip_renovacion   ge_tip_asientos.tip_renovacion%TYPE;
  v_cat_automatica   ge_tip_asientos.cat_automatica%TYPE;
  r_baade            pr_dev_diarios%ROWTYPE;
  xx_immovml         NUMBER;
  xx_immovex         NUMBER;
  xx_vltasci         NUMBER;
  --
  wh_immovex        NUMBER;
  wh_vltasci        NUMBER;
  vh_cod_oficina    pr_cta_prestamos.cod_oficina%TYPE;

  wh_immovml NUMBER;
  wh_dcrefer VARCHAR2(11);
  wh_dcdescr VARCHAR2(200);
  --
  v_nro_linea ge_tip_asientos.nro_linea%TYPE;
  v_cod_rub_cre cb_rubros.cod_rubro%TYPE;
  v_cod_rub_deb cb_rubros.cod_rubro%TYPE;
  v_encontro  VARCHAR2(1);
  v_msj       VARCHAR2(250);
  --
  v_cod_sec_rubro ge_con_transacciones.cod_sec_rubro%TYPE;
  --BSEVOCORE-627 NAF 2021/06
  v_cod_ori_fondo         pr_cta_prestamos.cod_ori_fondo%TYPE;
  v_por_ori_fondo         pr_cta_prestamos.por_ori_fondo%TYPE;
  v_par_afd_cod_ori_fondo varchar2(500) := trim(fug_obt_pardinamico('COD_ORI_FON_AFD_ASIENTOS'));
  v_cod_tip_asi_cre_afd   ge_tip_asientos.cod_tip_asiento%TYPE;
  v_des_tra_cre_afd       ge_transacciones.descripcion%TYPE;
  v_cod_tip_asi2_cre_afd  ge_tip_asientos.cod_tip_asiento%TYPE;
  xx_afd_immovml          NUMBER;
  xx_afd_immovex          NUMBER;
  xx_afd_vltasci          NUMBER;
  
  CURSOR cur3 IS
     SELECT ct.cod_modulo,
            ct.cod_modalidad,
            ct.cod_oficina,
            ct.cod_moneda,
            d.nro_cuenta,
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
               d.nro_cuenta,
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
  v_redondeo         NUMBER(5);
  --
  CURSOR c_tip_asientos(p_cod_tip_asi ge_tip_asientos.cod_tip_asiento%type,
                        p_cod_tip_asi2 ge_tip_asientos.cod_tip_asiento%type) IS
     SELECT ind_deudor, cod_rubro, ind_plazo, ind_producto, tip_movimiento
       FROM ge_tip_asientos
      WHERE cod_tip_asiento IN (p_cod_tip_asi, p_cod_tip_asi2)
        AND cod_moneda = v_cod_moneda
        AND (cod_sec_contable = v_cod_sec_contable OR cod_sec_contable IS NULL)
        AND (ind_residente = v_residente OR ind_residente = 'X')
        AND (est_cuenta = v_est_cuenta OR nvl(est_cuenta, 'X') = 'X')
        AND (tip_cuenta = v_tip_cuenta OR nvl(tip_cuenta, 'X') = 'X')
        AND (tip_interes = v_tip_interes OR nvl(tip_interes, 'X') = 'X')
        AND (tip_renovacion = v_tip_renovacion OR nvl(tip_renovacion, 'X') = 'X')
        AND (cat_automatica = v_cat_automatica OR nvl(cat_automatica, -1) = -1);

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
         IF substr(p_cod_rubro, 14, 2) IN ('99', '00') THEN
            p_cod_moneda := pag_gen.fu_obt_mon_local;
            p_encontro   := 'S';
         ELSIF substr(p_cod_rubro, 14, 2) IN ('01', '98') THEN
            p_cod_moneda := pag_gen.fu_obt_mon_fuerte;
            p_encontro   := 'S';
         ELSE
            p_encontro := 'N';
         END IF;
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Rec. Rubro ' || p_cod_rubro || '-' || SQLERRM);
   END;
   --
   PROCEDURE lp_ins_pr_dev_diarios(rp_dev IN pr_dev_diarios%ROWTYPE) IS
   BEGIN
      INSERT INTO pr_dev_diarios
      (fecha, nro_cuenta, cod_moneda, cod_oficina, cod_rub_debito, cod_rub_credito,
       descripcion, concepto, mto_debito, mto_credito, mto_mon_rubro, estado, categoria)
      VALUES
      (rp_dev.fecha, rp_dev.nro_cuenta, rp_dev.cod_moneda, rp_dev.cod_oficina,
       rp_dev.cod_rub_debito, rp_dev.cod_rub_credito, rp_dev.descripcion, rp_dev.concepto,
       rp_dev.mto_debito, rp_dev.mto_credito, rp_dev.mto_mon_rubro, rp_dev.estado,
       rp_dev.categoria);
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 'Ins. pr_dev_diarios '||rp_dev.nro_cuenta ||'-'||
                                  rp_dev.descripcion || '-' || SQLERRM);
   END;
BEGIN
  Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; End;
  -- Se busca eliminar los registros hasta 3 meses atrás.
  begin
    select min(a.fecha)
      into v_min_fecha
      from pr_dev_diarios a;
  end;
  if add_months(v_min_fecha,3) <= trunc(sysdate) then
    delete pr_dev_diarios a where a.fecha <= v_min_fecha;
  end if;
  --
  v_msj := ' Intereses devengados ';
  OPEN cur3;
  LOOP
     FETCH cur3
        INTO v_cod_modulo,
             v_cod_modalidad,
             v_cod_oficina,
             v_cod_moneda,
             v_nro_cuenta,
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
          INTO v_cod_tip_asi_cre, v_des_tra_cre, v_cod_tip_asi2_cre
          FROM ge_transacciones
         WHERE cod_modulo = v_cod_modulo
           AND cod_modalidad = v_cod_modalidad
           AND cod_transaccion = 901 -- crédito
           AND cod_tip_asiento IS NOT NULL;
     EXCEPTION
        WHEN no_data_found THEN
           raise_application_error(-20000,
                                   'Transaccion ' || to_char(v_cod_modulo) || '-' ||
                                    to_char(v_cod_modalidad) ||
                                    '-901 no tiene asiento de Crédito definido.');
        WHEN OTHERS THEN
           IF SQLCODE <= -20000 THEN
              RAISE;
           ELSE
              raise_application_error(-20001, 'Error prp_act_dev_diarios ' || SQLERRM);
           END IF;
     END;
     --- ve el tipo de asiento por el CREDITO AFD
     --- si es AFD calcula el % de Interes correspondiente
     IF instr(',' || v_par_afd_cod_ori_fondo || ',', ',' || v_cod_ori_fondo || ',') > 0 THEN
       BEGIN
          SELECT cod_tip_asiento, descripcion, cod_tip_asiento2
            INTO v_cod_tip_asi_cre_afd, v_des_tra_cre_afd, v_cod_tip_asi2_cre_afd
            FROM ge_transacciones
           WHERE cod_modulo = v_cod_modulo
             AND cod_modalidad = v_cod_modalidad
             AND cod_transaccion = 991 -- crédito
             AND cod_tip_asiento IS NOT NULL;
       EXCEPTION
          WHEN no_data_found THEN
             raise_application_error(-20000,
                                     'Transaccion ' || to_char(v_cod_modulo) || '-' ||
                                      to_char(v_cod_modalidad) ||
                                      '-901 no tiene asiento de Crédito definido.');
          WHEN OTHERS THEN
             IF SQLCODE <= -20000 THEN
                RAISE;
             ELSE
                raise_application_error(-20001, 'Error prp_act_dev_diarios ' || SQLERRM);
             END IF;
       END;
     END IF;
     --- ve el tipo de asiento por el DEBITO
     BEGIN
        SELECT cod_tip_asiento, descripcion, cod_tip_asiento
          INTO v_cod_tip_asi_deb, v_des_tra_deb, v_cod_tip_asi2_deb
          FROM ge_transacciones
         WHERE cod_modulo = v_cod_modulo
           AND cod_modalidad = v_cod_modalidad
           AND cod_transaccion = 903 -- débito
           AND cod_tip_asiento IS NOT NULL;
     EXCEPTION
        WHEN no_data_found THEN
           raise_application_error(-20000,
                                   'Transaccion ' || to_char(v_cod_modulo) || '-' ||
                                    to_char(v_cod_modalidad) ||
                                    '-903 no tiene asiento de Débito definido.');
        WHEN OTHERS THEN
           IF SQLCODE <= -20000 THEN
              RAISE;
           ELSE
              raise_application_error(-20002, 'Error prp_act_dev_diarios ' || SQLERRM);
           END IF;
     END;
     ------------------
     -- ve la moneda --
     ------------------
     v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad,
                                       v_cod_mon_local);
     IF v_cod_moneda = v_cod_mon_local THEN
        -- es moneda nacional --
        ------------------------
        xx_immovml := v_mto_interes;
        xx_immovex := 0;
        xx_vltasci := 0;
     ELSE
        -- se obtiene la cotizacion de cierre
        v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
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
     OPEN c_tip_asientos(v_cod_tip_asi_cre,v_cod_tip_asi2_cre);
     v_nro_linea := 0;
     LOOP
        FETCH c_tip_asientos
           INTO v_ind_deudor, v_cod_rubro, v_ind_plazo, v_ind_producto, v_tip_mov_asi;
        EXIT WHEN c_tip_asientos%NOTFOUND;
        ---Reemplaza el valor del tipo de deudor, si importa-
        IF v_ind_deudor = 'S' THEN
           v_cod_rub_cre := substr(v_cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                          substr(v_cod_rubro, 11, 5);
        ELSE
           v_cod_rub_cre := v_cod_rubro;
        END IF;
        ---Reemplaza el codigo del plazo si es necesario -----
        IF v_ind_plazo = 'S' THEN
           v_cod_rub_cre := substr(v_cod_rub_cre, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                          substr(v_cod_rub_cre, 4, 12);
        END IF;
        ---Reemplaza el codigo del producto -----------------------
        IF v_ind_producto = 'S' THEN
           v_cod_rub_cre := substr(v_cod_rub_cre, 1, 10) ||
                          ltrim(to_char(v_cod_pro_contable, '000')) ||
                          substr(v_cod_rub_cre, 14, 2);
        END IF;
        --Reemplaza el código del sector de crédito
        IF substr(v_cod_rubro, 11, 3) = 'SEC' THEN
           v_cod_rub_cre := substr(v_cod_rub_cre, 1, 10) || ltrim(to_char(v_cod_sec_rubro, '000')) ||
                          substr(v_cod_rubro, 14, 2);
        END IF;
        ------------------------------------------------------
        v_encontro := 'S';
        lp_obt_mon_rubro(v_cod_rub_cre, v_mon_rubro, v_encontro);
        IF v_encontro = 'N' THEN
           v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rub_cre;
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
      END LOOP;
        -- ve el tipo de movimiento --
        ------------------------------
        v_tip_movimiento := v_tip_mov_asi;
        IF xx_immovml > 0 THEN
           v_tip_movimiento := v_tip_mov_asi;
           wh_immovml       := xx_immovml;
        ELSE
           wh_immovml := xx_immovml * -1;
           wh_immovex := wh_immovex * -1;
           IF v_tip_mov_asi = 'C' THEN
              v_tip_movimiento := 'D';
           ELSE
              v_tip_movimiento := 'C';
           END IF;
        END IF;
        ------------------------------------------------------
        wh_dcrefer        := 'DEVENG.';
        wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                    to_char(901) || ' ' || v_des_tra_cre, 1, 60);
        vh_cod_oficina    := v_cod_oficina;
     ----- ciclo para GE_TIP_ASIENTOS ------
     -------------------------------
     IF c_tip_asientos%ISOPEN THEN
        CLOSE c_tip_asientos;
     END IF;
     OPEN c_tip_asientos(v_cod_tip_asi_deb, v_cod_tip_asi2_deb);
     v_nro_linea := 0;
     LOOP
        FETCH c_tip_asientos
           INTO v_ind_deudor, v_cod_rubro, v_ind_plazo, v_ind_producto, v_tip_mov_asi;
        EXIT WHEN c_tip_asientos%NOTFOUND;
        ---Reemplaza el valor del tipo de deudor, si importa-
        IF v_ind_deudor = 'S' THEN
           v_cod_rub_deb := substr(v_cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                          substr(v_cod_rubro, 11, 5);
        ELSE
           v_cod_rub_deb := v_cod_rubro;
        END IF;
        ---Reemplaza el codigo del plazo si es necesario -----
        IF v_ind_plazo = 'S' THEN
           v_cod_rub_deb := substr(v_cod_rub_deb, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                          substr(v_cod_rub_deb, 4, 12);
        END IF;
        ---Reemplaza el codigo del producto -----------------------
        IF v_ind_producto = 'S' THEN
           v_cod_rub_deb := substr(v_cod_rub_deb, 1, 10) ||
                          ltrim(to_char(v_cod_pro_contable, '000')) ||
                          substr(v_cod_rub_deb, 14, 2);
        END IF;
        --Reemplaza el código del sector de crédito
        IF substr(v_cod_rubro, 11, 3) = 'SEC' THEN
           v_cod_rub_deb := substr(v_cod_rub_deb, 1, 10) || ltrim(to_char(v_cod_sec_rubro, '000')) ||
                          substr(v_cod_rubro, 14, 2);
        END IF;
        ------------------------------------------------------
        v_encontro := 'S';
        lp_obt_mon_rubro(v_cod_rub_deb, v_mon_rubro, v_encontro);
        IF v_encontro = 'N' THEN
           v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rub_deb;
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
        v_tip_movimiento := v_tip_mov_asi;
        IF xx_immovml > 0 THEN
           v_tip_movimiento := v_tip_mov_asi;
           wh_immovml       := xx_immovml;
        ELSE
           wh_immovml := xx_immovml * -1;
           wh_immovex := wh_immovex * -1;
           IF v_tip_mov_asi = 'C' THEN
              v_tip_movimiento := 'D';
           ELSE
              v_tip_movimiento := 'C';
           END IF;
        END IF;
        ------------------------------------------------------
        wh_dcrefer        := 'DEVENG.';
        wh_dcdescr        := wh_dcdescr||' / '|| substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                    to_char(903) || ' ' || v_des_tra_deb, 1, 60);
        vh_cod_oficina    := v_cod_oficina;
        -----
        -----
        IF wh_immovml <> 0 THEN
           v_nro_linea := v_nro_linea + 1;
           --- Cargar registro de asientos detalles
           r_baade.fecha          := v_fec_actual;
           r_baade.nro_cuenta     := v_nro_cuenta;
           r_baade.cod_moneda     := v_cod_moneda;
           r_baade.cod_oficina    := vh_cod_oficina;
           r_baade.cod_rub_debito := v_cod_rub_deb;
           r_baade.cod_rub_credito := v_cod_rub_cre;
           r_baade.mto_debito     := wh_immovml;
           r_baade.mto_credito    := wh_immovml;
           r_baade.descripcion    := wh_dcdescr;
           r_baade.concepto       := wh_dcrefer;
           r_baade.mto_mon_rubro  := wh_immovex;
           r_baade.estado         := v_est_cuenta;
           r_baade.categoria      := v_cat_automatica;
           lp_ins_pr_dev_diarios(r_baade);
        END IF;
        -- Registro para Rubro AFD
        IF xx_afd_immovml <> 0 THEN
           ----- ciclo para GE_TIP_ASIENTOS ------
           -------------------------------
           IF c_tip_asientos%ISOPEN THEN
              CLOSE c_tip_asientos;
           END IF;
           OPEN c_tip_asientos(v_cod_tip_asi_cre_afd,v_cod_tip_asi2_cre_afd);
           v_nro_linea := 0;
           LOOP
              FETCH c_tip_asientos
                 INTO v_ind_deudor, v_cod_rubro, v_ind_plazo, v_ind_producto, v_tip_mov_asi;
              EXIT WHEN c_tip_asientos%NOTFOUND;
              ---Reemplaza el valor del tipo de deudor, si importa-
              IF v_ind_deudor = 'S' THEN
                 v_cod_rub_cre := substr(v_cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                                substr(v_cod_rubro, 11, 5);
              ELSE
                 v_cod_rub_cre := v_cod_rubro;
              END IF;
              ---Reemplaza el codigo del plazo si es necesario -----
              IF v_ind_plazo = 'S' THEN
                 v_cod_rub_cre := substr(v_cod_rub_cre, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                                substr(v_cod_rub_cre, 4, 12);
              END IF;
              ---Reemplaza el codigo del producto -----------------------
              IF v_ind_producto = 'S' THEN
                 v_cod_rub_cre := substr(v_cod_rub_cre, 1, 10) ||
                                ltrim(to_char(v_cod_pro_contable, '000')) ||
                                substr(v_cod_rub_cre, 14, 2);
              END IF;
              --Reemplaza el código del sector de crédito
              IF substr(v_cod_rubro, 11, 3) = 'SEC' THEN
                 v_cod_rub_cre := substr(v_cod_rub_cre, 1, 10) || ltrim(to_char(v_cod_sec_rubro, '000')) ||
                                substr(v_cod_rubro, 14, 2);
              END IF;
              ------------------------------------------------------
              v_encontro := 'S';
              lp_obt_mon_rubro(v_cod_rub_cre, v_mon_rubro, v_encontro);
              IF v_encontro = 'N' THEN
                 v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rub_cre;
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
            END LOOP;
            -- ve el tipo de movimiento --
            ------------------------------
            v_tip_movimiento := v_tip_mov_asi;
            IF xx_afd_immovml > 0 THEN
               v_tip_movimiento := v_tip_mov_asi;
               wh_immovml       := xx_afd_immovml;
            ELSE
               wh_immovml := xx_afd_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF v_tip_mov_asi = 'C' THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            ------------------------------------------------------
            wh_dcrefer        := 'DEVENG.';
            wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                        to_char(991) || ' ' || v_des_tra_cre, 1, 60);
            vh_cod_oficina    := v_cod_oficina;
            ---
            v_nro_linea := v_nro_linea + 1;
            --- Cargar registro de asientos detalles
            r_baade.fecha          := v_fec_actual;
            r_baade.nro_cuenta     := v_nro_cuenta;
            r_baade.cod_moneda     := v_cod_moneda;
            r_baade.cod_oficina    := vh_cod_oficina;
            r_baade.cod_rub_debito := v_cod_rub_deb;
            r_baade.cod_rub_credito := v_cod_rub_cre;
            r_baade.mto_debito     := wh_immovml;
            r_baade.mto_credito    := wh_immovml;
            r_baade.descripcion    := wh_dcdescr;
            r_baade.concepto       := wh_dcrefer;
            r_baade.mto_mon_rubro  := wh_immovex;
            r_baade.estado         := v_est_cuenta;
            r_baade.categoria      := v_cat_automatica;
            lp_ins_pr_dev_diarios(r_baade);
        END IF;
     END LOOP; -- fin de tipo de asientos --
  END LOOP;
END;
/

