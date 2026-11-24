CREATE OR REPLACE PROCEDURE IT.PRC_PRO_DEB_SAL_MIN
 IS
v_modul        ge_cuentas.cod_modulo%type;
  v_modal        ge_cuentas.cod_modalidad%type;
  v_ofici        ge_cuentas.cod_oficina%type;
  v_moned        ge_cuentas.cod_moneda%type;
  v_cdtrans      ge_movimientos.cod_transaccion%type;
  v_hrmovim      ge_movimientos.hora%type;
  v_encontro     varchar2(1);
  v_traprohi     varchar2(1) := 'N';
  v_autoriza     varchar2(1) := 'N';
  v_salprom      cc_cta_corrientes.sal_total%type;
  v_slminpa      cc_cta_corrientes.sal_total%type;
  v_sldispo      cc_cta_corrientes.sal_total%type;
  v_mesact       cc_sal_mensuales.mes%type;
  v_aniact       cc_sal_mensuales.ano%type;
  v_imtrans      cc_cta_corrientes.sal_total%type;
  v_tasaper      varchar2(1);
  v_montcar      ge_movimientos.monto%type;
  v_cmoncar      ge_movimientos.monto%type;
  v_cdtasca      ge_movimientos.cod_tasa%type;
  v_vltasca      ge_movimientos.val_tasa%type;
  v_montimp      cc_cta_corrientes.sal_total%type;
  v_cdtasim      ge_movimientos.cod_tasa%type;
  v_vltasim      ge_movimientos.val_tasa%type;
  v_imdebit      cc_cta_corrientes.sal_total%type;
  v_lgpuede      varchar2(1);
  v_esmovim      varchar2(1);
  v_concept      ge_movimientos.concepto%type;
  v_slprome      cc_cta_corrientes.sal_total%type;
  v_cuantos      NUMBER;
  v_slparam      NUMBER;   -- saldo de parametro --
  v_hay_param    varchar2(1);
  v_dias         NUMBER(2,0);
  v_cdusuar      ba_usuarios.cod_usuario%type;
  v_vltasa       ge_tas_fechas.val_tasa%type;
  v_fec_vigencia ge_tas_fechas.fec_vigencia%type;
  v_tipo         ge_tasas.tipo%type;
  v_cdtasas      ah_cta_vistas.cod_tasa%type;
  v_fcdehoy      date;
  v_fcfinal      date;
  v_tpvlpor      varchar2(1);
  v_nrsecue      ge_movimientos.nro_secuencia%type;
  v_nrcuent      cc_cta_corrientes.nro_cuenta%type;
  v_cdmodul      cc_cta_corrientes.cod_modulo%type;
  v_cdmodal      cc_cta_corrientes.cod_modalidad%type;
  v_cdofici      cc_cta_corrientes.cod_oficina%type;
  v_cdmoned      cc_cta_corrientes.cod_moneda%type;
  v_redondeo     number(5);
CURSOR ofi IS
  select distinct cod_modulo, cod_modalidad,cod_oficina, cod_moneda
    from cc_cta_corrientes
   where estado not in ('C','P','A','T','D','X')
     and cod_modalidad = 41
     and fec_apertura <= v_fcdehoy;
r_cte cc_cta_corrientes%rowtype;
CURSOR cte IS
  select *
    from cc_cta_corrientes
   where estado not in ('C','P','A','T','D','X')
     and cod_modalidad = 41
     and cod_modulo    = v_modul
     and cod_modalidad = v_modal
     and cod_oficina   = v_ofici
     and cod_moneda    = v_moned
     and fec_apertura <= v_fcdehoy
for update of estado;
PROCEDURE LP_ACT_AUT (p_modulo      IN     NUMBER,
                      p_modalidad   IN     NUMBER,
                      p_oficina     IN     NUMBER,
                      p_cuenta      IN     CHAR,
                      p_transaccion IN     NUMBER,
                      p_encontro    OUT CHAR);
/* Verifica y devuelve el saldo promedio. */
PROCEDURE LP_VER_SAL_PROMEDIO
         (p_modulo      IN   NUMBER,
          p_modalidad   IN   NUMBER,
          p_oficina     IN   NUMBER,
          p_cuenta      IN   CHAR,
          p_anioactual  IN   NUMBER,
          p_mesactual   IN   NUMBER,
          p_saldo_prom  OUT  NUMBER,
          p_encontro    OUT  CHAR);
/* Actualiza /Inserta Saldos Mensuales */
PROCEDURE LP_ACT_SAL_MENSUAL (P_TOTAL IN NUMBER,
                              P_CDMODUL IN NUMBER,
                              P_CDMODAL IN NUMBER,
                              P_CDOFICI IN NUMBER,
                              P_NRCUENT IN VARCHAR2);
PROCEDURE LP_ACT_AUT (p_modulo      IN     NUMBER,
                      p_modalidad   IN     NUMBER,
                      p_oficina     IN     NUMBER,
                      p_cuenta      IN     CHAR,
                      p_transaccion IN     NUMBER,
                      p_encontro    OUT CHAR) IS
BEGIN
    update ge_autorizaciones set
           cod_usuario     = v_cdusuar,
           fec_utilizacion = v_fcdehoy,
           hor_utilizacion = v_hrmovim
     where cod_modulo      = p_modulo
       and cod_modalidad   = p_modalidad
       and nro_cuenta      = p_cuenta
       and cod_transaccion = p_transaccion
       and eximido         = 'S';
    IF SQL%FOUND THEN
       p_encontro := 'S';
    ELSE
       p_encontro := 'N';
    END IF;
END;
PROCEDURE LP_VER_SAL_PROMEDIO
         (p_modulo      IN   NUMBER,
          p_modalidad   IN   NUMBER,
          p_oficina     IN   NUMBER,
          p_cuenta      IN   CHAR,
          p_anioactual  IN   NUMBER,
          p_mesactual   IN   NUMBER,
          p_saldo_prom  OUT  NUMBER,
          p_encontro    OUT  CHAR) IS
BEGIN
    p_encontro := 'S';
    SELECT round(NVL(sal_acu_diario,0)/can_dia_acumulado,2)
      INTO p_saldo_prom
      FROM cc_sal_mensuales
     WHERE cod_modulo    = p_modulo
       AND cod_modalidad = p_modalidad
       AND cod_oficina   = p_oficina
       AND nro_cuenta    = p_cuenta
       AND ano           = p_anioactual
       AND mes           = p_mesactual;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      raise_application_error(-20000,'No encontro en saldos mensuales. Cta : ' || p_cuenta);
      p_encontro := 'N';
END;
PROCEDURE LP_ACT_SAL_MENSUAL (P_TOTAL IN NUMBER,
                              P_CDMODUL IN NUMBER,
                              P_CDMODAL IN NUMBER,
                              P_CDOFICI IN NUMBER,
                              P_NRCUENT IN VARCHAR2)IS
V_DIAS    NUMBER(2,0);
v_minpa   cc_cta_corrientes.sal_total%type;
v_acsaldi cc_cta_corrientes.sal_total%type;
v_salinic cc_cta_corrientes.sal_total%type;
v_ctdiast NUMBER(7);
v_fcproxi DATE;
rv_gcale  GE_CALENDARIOS%ROWTYPE;
v_atransf cc_cta_corrientes.sal_total%type;
v_ctacomb varchar2(1);
BEGIN
  rv_gcale  := pag_cal.fu_obt_reg_cal(4);
  v_fcproxi := rv_gcale.fec_proxima;
  select nvl(cc.sal_total, 0) - nvl(cc.sal_retenido, 0),
         nvl(cco.sal_minimo, FUG_OBT_SAL_MIN_TRASPASO(nro_cta_cte)), nvl(cc.cta_combinada, 'N')
    into v_salinic, v_atransf, v_ctacomb
    from cc_cta_combinadas cco,
         cc_cta_corrientes cc
   where cco.nro_cta_cte(+) = cc.nro_cuenta
     and cc.cod_modulo    = p_cdmodul
     and cc.cod_modalidad = p_cdmodal
     and cc.cod_oficina   = p_cdofici
     and cc.nro_cuenta    = p_nrcuent;
  If v_ctacomb = 'S' and v_salinic >  v_atransf Then
    v_salinic := v_atransf;
  End If;
  UPDATE cc_sal_mensuales
     SET sal_ini_mes = nvl(v_salinic, 0)
   WHERE cod_modulo    = p_cdmodul
     AND cod_modalidad = p_cdmodal
     AND cod_oficina   = p_cdofici
     AND nro_cuenta    = p_nrcuent
     AND ano           = to_number(to_char(v_fcproxi,'YYYY'))
     AND mes           = to_number(to_char(v_fcproxi,'MM'));
  IF v_fcdehoy + 1 <> v_fcproxi THEN
     V_DIAS := TO_NUMBER(TO_CHAR(v_fcproxi,'DD')) - 1;
     /* Actualiza valores saldo acumulado del mes*/
     UPDATE cc_sal_mensuales
        SET sal_acu_diario = v_dias * nvl(v_salinic, 0)
      WHERE cod_modulo    = p_cdmodul
        AND cod_modalidad = p_cdmodal
        AND cod_oficina   = p_cdofici
        AND nro_cuenta    = p_nrcuent
        AND ano           = to_number(to_char(v_fcproxi,'YYYY'))
        AND mes           = to_number(to_char(v_fcproxi,'MM'));
    -- SALDOS DEUDORES --
    ------------------------------------------------------------
     If nvl(v_salinic, 0) < 0 Then
       UPDATE cc_sal_mensuales
         SET sal_acu_deudor = v_dias * nvl(v_salinic, 0) * -1,
             can_dia_deudor = v_DIAS,
             sal_acu_acreedor = 0,
             can_dia_acreedor = 0
       WHERE cod_modulo    = p_cdmodul
         AND cod_modalidad = p_cdmodal
         AND cod_oficina   = p_cdofici
         AND nro_cuenta    = p_nrcuent
         AND ano           = to_number(to_char(v_fcproxi,'YYYY'))
         AND mes           = to_number(to_char(v_fcproxi,'MM'));
   -- SALDOS ACREEDORES -- menor a cero
    ------------------------------------------------------------
     Else
       UPDATE cc_sal_mensuales
          SET sal_acu_acreedor = v_dias * nvl(v_salinic, 0),
              can_dia_acreedor = v_DIAS,
              sal_acu_deudor = 0,
              can_dia_deudor = 0
        WHERE cod_modulo    = p_cdmodul
          AND cod_modalidad = p_cdmodal
          AND cod_oficina   = p_cdofici
          AND nro_cuenta    = p_nrcuent
          AND ano           = to_number(to_char(v_fcproxi,'YYYY'))
          AND mes           = to_number(to_char(v_fcproxi,'MM'));
     End If;
  END IF;
  IF SQL%NOTFOUND THEN
    raise_application_error(-20000,'No existe reg de mes proximo en CC_SAL_MENSUALES');
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error '||p_nrcuent||' '||sqlerrm);
END;
--
BEGIN
  v_cuantos := 0;
  v_hrmovim := to_char(sysdate,'HH24:MI:SS');
  v_aniact  := to_char(v_fcdehoy,'YYYY');
  v_mesact  := to_char(v_fcdehoy,'MM');
  v_cdusuar := substr(user,1,10);
  v_fcdehoy := pag_cal.fu_obt_fec_actual(4);
  --DELETE fcdbmin;
  OPEN ofi;
  LOOP
      FETCH ofi INTO v_modul, v_modal, v_ofici, v_moned;
      EXIT WHEN ofi%NOTFOUND;
      --
      v_slparam := FUG_OBT_PARDINAMICO('SAL_MIN_PACTADO',v_modul,v_modal, v_moned,
                                       v_ofici);
      If nvl(v_slparam,0) > 0 then
        v_encontro :=  'S';
      End if;
      v_hay_param := v_encontro;
      --
      ---- ciclo para cada modulo, modal y ofic diferente -----
      IF cte%ISOPEN THEN
        CLOSE cte;
      END IF;
      OPEN cte;
      LOOP
        FETCH cte INTO r_cte;
        EXIT WHEN cte%NOTFOUND;
        v_nrsecue := 0;
        v_nrcuent := r_cte.nro_cuenta;
        v_cdmodul := r_cte.cod_modulo;
        v_cdmodal := r_cte.cod_modalidad;
        v_cdofici := r_cte.cod_oficina;
        v_tasaper := nvl(r_cte.tas_personalizada,'N');
        v_cdtasas := null;
        v_cdtrans := 528;
        v_hrmovim := TO_CHAR(SYSDATE,'HH24:MI:SS');
        /* ve si tiene transacciones prohibidas */
        ------------------------------------------
        v_traprohi := 'N';
        IF r_cte.tra_prohibida = 'S' THEN
          v_encontro := PAG_CTA.FU_VER_TRA_PROHIBIDA(r_cte.nro_cuenta, 528,
                                                     r_cte.cod_modulo, r_cte.cod_modalidad);
          IF v_encontro = 'S' THEN
             v_traprohi := 'S';
          END IF;
        END IF;
        /* ve si tiene autorizacion */
        ------------------------------------------
        v_autoriza := 'N';
        IF r_cte.aut_pendiente = 'S' THEN
          LP_ACT_AUT (r_cte.cod_modulo, r_cte.cod_modalidad,
                      r_cte.cod_oficina, r_cte.nro_cuenta,
                      528,v_encontro);
          IF v_encontro = 'S' THEN
             v_autoriza := 'S';
          END IF;
        END IF;
        -- ve saldo promedio                   --
        -----------------------------------------
        v_salprom := 0;
        v_encontro := 'N';
        LP_VER_SAL_PROMEDIO (r_cte.cod_modulo, r_cte.cod_modalidad,
                             r_cte.cod_oficina, r_cte.nro_cuenta,
                             v_aniact       , v_mesact,
                             v_salprom      , v_encontro);
        IF v_encontro = 'N' THEN
            v_slminpa := r_cte.sal_minimo;
            IF v_slminpa IS NULL THEN
              IF v_hay_param = 'N' THEN
                 GOTO siguiente_registro;
              END IF;
              v_slminpa := v_slparam;
            END IF;
            --
            IF v_salprom >= v_slminpa THEN
              GOTO siguiente_registro;
            END IF;
            /* calcular el monto del cargo a debitar */
            v_sldispo := NVL(r_cte.sal_total,0) -
                         NVL(r_cte.sal_retenido,0) -
                         NVL(r_cte.sal_bloqueado,0);
            v_cdmoned := r_cte.cod_moneda;
            v_fcfinal := v_fcdehoy;
            v_cdtrans := 528;
            v_tpvlpor := ' ';
            PAG_GEN.PR_OBT_VAL_TASA(r_cte.cod_modulo,r_cte.cod_modalidad,r_cte.cod_oficina,
                                    r_cte.nro_cuenta,r_cte.cod_moneda,0,
                                    v_tasaper, v_cdtasas,v_cdtrans,v_fcfinal,
                                   -- OUT
                                    v_vltasa,v_fec_vigencia,v_tpvlpor,v_tipo);
            IF v_tpvlpor = 'V' THEN
              If v_traprohi = 'S' or v_autoriza = 'S' Then
                 v_montcar := 0;
              Else
                 v_montcar := v_vltasa;
              End If;
              v_cmoncar := v_vltasa;
            ELSE
              raise_application_error(-20000,'Cargo de saldo minimo no puede ser porcentual ');
            END IF;
            IF v_cdtasas  IS NULL OR v_vltasa  = 0 THEN
               v_montcar := 0;
               v_cmoncar := 0;
            END IF;
            /* calcular el monto del impuesto sobre el cargo a debitar */
            -------------------------------------------------------------
            v_vltasca := v_vltasa;
            v_cdtasca := v_cdtasas;
            v_imtrans := v_montcar;
            v_montimp := 0;
            --- Agregado para que calcule el impuesto ---
            /* ve si tiene transacciones prohibidas */
            ------------------------------------------
            v_traprohi := 'N';
            IF r_cte.tra_prohibida = 'S' THEN
              v_encontro := PAG_CTA.FU_VER_TRA_PROHIBIDA(r_cte.nro_cuenta, 529,
                                                         r_cte.cod_modulo, r_cte.cod_modalidad);
              IF v_encontro = 'S' THEN
                v_traprohi := 'S';
              END IF;
            END IF;
            v_nrcuent := r_cte.nro_cuenta;
            v_cdmodul := r_cte.cod_modulo;
            v_cdmodal := r_cte.cod_modalidad;
            v_cdofici := r_cte.cod_oficina;
            v_tasaper := nvl(r_cte.tas_personalizada,'N');
            v_cdtasas := null;
            v_cdtrans := 529;
            v_cdmoned := r_cte.cod_moneda;
            v_fcfinal := v_fcdehoy;
            v_tpvlpor := ' ';
            PAG_GEN.PR_OBT_VAL_TASA(r_cte.cod_modulo,r_cte.cod_modalidad,r_cte.cod_oficina,
                                    r_cte.nro_cuenta,r_cte.cod_moneda,0,
                                    v_tasaper, v_cdtasas,v_cdtrans,v_fcfinal,
                                   -- OUT
                                    v_vltasa,v_fec_vigencia,v_tpvlpor,v_tipo);
            v_vltasim := v_vltasa;
            v_cdtasim := v_cdtasas;
            v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',r_cte.cod_modulo,r_cte.cod_modalidad,r_cte.cod_moneda);
            IF v_tpvlpor = 'V' THEN
              raise_application_error(-20000,'IVA de Cargo de saldo minimo debe ser porcentual');
            ELSE
                If v_traprohi = 'N' Then
                  If v_cmoncar > 0 Then
                     v_montimp := ROUND(nvl(v_cmoncar,0) *
                                        nvl(v_vltasim,0) / 100, v_redondeo);
                  End If;
                End If;
            END IF;
            --  /* calcular la diferencia para saber si el saldo disponible
            --     alcanza para el debito del cargo e impuesto.               */
            v_imdebit := v_montcar + v_montimp;
            v_lgpuede := 'S';
            IF v_sldispo - v_imdebit < 0 THEN
              ----------------------------------------------------------
              -- esta rutina ruben cambio para que igual debite saldo --
              -- minimo si no tiene saldo suficiente el 26/02/96      --
              -- anteriormente solo tenia (ww_lgpuede := N), y se le  --
              -- agrego (v_lgpuede := 'S' y v_esmovim := 'N')       --
              ----------------------------------------------------------
              --v_lgpuede := 'N';
              v_lgpuede := 'S';
              v_esmovim := 'N';
            END IF;
            IF v_lgpuede = 'S' THEN
              v_esmovim := 'N';
            ELSE
              If v_montcar > 0 Then
                 v_concept := 'DEBITO POR SALDO MINIMO';
                 v_esmovim := 'E';
                 -- grabar en tabla de trabajo --
                 /*INSERT INTO fcdbmin
                  (tb_cdofici, tb_nrcuent, tb_cdmoned,
                   tb_sldispo, tb_slprome, tb_slminpa)
                 VALUES
                  (r_cte.cod_oficina, r_cte.nro_cuenta, r_cte.cod_moneda,
                   v_sldispo, v_slprome, v_slminpa);*/
                 v_cuantos := v_cuantos + 1;
              End If;
            END IF;
            --
            IF v_montcar > 0 THEN
             -- movimiento de debito
             -----------------------
               v_nrsecue := v_nrsecue + 1;
               insert into ge_movimientos
                (cod_usuario, hora, nro_secuencia,
                 cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
                 cod_moneda, cod_tra_padre, cod_transaccion, fecha,
                 fec_valor, monto, estado, cod_ofi_origen,
                 cod_tasa, val_tasa, cod_mod_padre, cod_mad_padre,
                 reversado, protegido)
               VALUES
                (v_CDUSUAR, v_HRMOVIM, v_NRSECUE,
                 r_cte.cod_modulo, r_cte.cod_modalidad, r_cte.cod_oficina,
                 r_cte.nro_cuenta, r_cte.cod_moneda, 325,528,v_fcdehoy,
                 v_fcdehoy, v_montcar, v_esmovim,r_cte.cod_oficina,
                 v_cdtasca, v_vltasca,4, 41,'N','N');
            END IF;
            IF v_montimp > 0 THEN
             -- movimiento de debito
             -----------------------
               v_nrsecue := v_nrsecue + 1;
               insert into ge_movimientos
                (cod_usuario, hora, nro_secuencia,
                 cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
                 cod_moneda, cod_tra_padre, cod_transaccion, fecha,
                 fec_valor, monto, estado, cod_ofi_origen,
                 cod_tasa, val_tasa, cod_mod_padre, cod_mad_padre,
                 reversado, protegido)
               values
                (v_cdusuar, v_hrmovim, v_nrsecue,
                 r_cte.cod_modulo, r_cte.cod_modalidad, r_cte.cod_oficina,
                 r_cte.nro_cuenta, r_cte.cod_moneda, 529,529,v_fcdehoy,
                 v_fcdehoy, v_montimp, v_esmovim,r_cte.cod_oficina,
                 v_cdtasim, v_vltasim,4, 41,'N','N');
            IF v_lgpuede = 'S' then
             -- actualizar el maestro de cuentas corrientes
              update cc_cta_corrientes
                 set sal_total = sal_total - v_imdebit ,
                     fec_ult_movimiento = v_fcdehoy,
                     hor_ult_movimiento = v_hrmovim
               where current of cte;
             -- actualizar el acumulado de saldos mensuales
              LP_ACT_SAL_MENSUAL(v_imdebit, r_cte.cod_modulo,
                                 r_cte.cod_modalidad,r_cte.cod_oficina, r_cte.nro_cuenta);
            end if;
          End if;
        End if;
        <<siguiente_registro>>
        NULL;
      END LOOP;
  END LOOP; -- de oficina --
  IF ofi%ISOPEN THEN
    CLOSE ofi;
  END IF;
  IF cte%ISOPEN THEN
    CLOSE cte;
  END IF;
EXCEPTION
  when no_data_found then
    raise_application_error(-20000,'No existe datos en el archivo');
end;
/

