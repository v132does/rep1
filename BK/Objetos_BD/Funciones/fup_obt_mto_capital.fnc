CREATE OR REPLACE FUNCTION IT.FUP_OBT_MTO_CAPITAL
(
   p_nro_cuenta             pr_cuotas.nro_cuenta%TYPE,
   p_fecha                  DATE,
   p_dias_atraso            pr_cta_prestamos.dia_atraso%TYPE,
   p_tip_saldo              VARCHAR2,
   p_tip_monto              VARCHAR2,
   p_fec_ult_categorizacion DATE,
   p_valor                  varchar2 default 'C'
) RETURN NUMBER IS
   v_mto_cap_cobrado         pr_cuotas.mto_capital%TYPE;
   v_sal_cobrado             pr_cuotas.sal_capital%type;
   v_error                   number;
   v_mensaje                 varchar2(4000);
   v_sal_capital             pr_cuotas.sal_capital%TYPE;
   v_monto                   pr_cuotas.mto_capital%TYPE;
   v_cod_modulo              ge_cuentas.cod_modulo%TYPE;
   v_nro_cuo_desde           pr_cuotas.nro_cuota%TYPE;
   v_nro_cuo_hasta           pr_cuotas.nro_cuota%TYPE;
   v_cod_ofi_origen          pr_cta_prestamos.cod_oficina%type;
   v_sal_interes             pr_cuotas.sal_interes%type;
   v_sal_int_ade             pr_cuotas.sal_int_documentado%type;
   v_mora                    pr_cuotas.mto_capital%type;
   v_mora_interes            pr_cuotas.mto_capital%type;
   v_mora_int_ade            pr_cuotas.mto_capital%type;
   v_punitorio               pr_cuotas.mto_capital%type;
   v_impuesto                pr_cuotas.mto_capital%type;
   v_cargo                   pr_cuotas.mto_capital%type;
   v_cargo_iva               pr_cuotas.mto_capital%type;
   v_int_descontado          pr_cuotas.mto_interes%type;
   v_dia_mora                pr_cta_prestamos.dia_atraso%type;
   v_cod_tra_padre           ge_transacciones.cod_transaccion%type := 360;
   v_cancelacion             varchar2(1);
   v_renueva                 varchar2(1);
   v_cancel_rrr              varchar2(1);
   v_tot_deuda               ge_cla_operaciones.tot_deu_real%type;
   v_fec_cobro               date := pae_cnf.fu_obt_fec_actual(6);
   /*
    p_tip_monto: 'M'(Cuando se debe recuperar el monto capital ó Interés total) - 'C'(Cuando se debe recuperar el capital ó Interés cobrado).
    p_tip_saldo: 'O'(Cuando se busca el saldo capital ó Interés original) - 'V'(Cuando se debe recuperar el saldo capital ó Interés vencido).
    p_valor    : 'H'( recuperar la deuda capital e intereses) - 'C'(Cuando se debe recuperar el monto capital) - 'I'(Cuando se debe recuperar el monto interés)
   */
BEGIN
   BEGIN
     SELECT cod_modulo
       INTO v_cod_modulo
       FROM ge_cuentas
      WHERE nro_cuenta = p_nro_cuenta;
   EXCEPTION
     WHEN OTHERS THEN
       v_cod_modulo := null;
   END;
   IF nvl(p_valor, 'C') = 'C' THEN
      IF v_cod_modulo = 6 THEN
         BEGIN
            SELECT SUM(mto_capital)
              INTO v_mto_cap_cobrado
              FROM pr_cobros
             WHERE nro_cuenta = p_nro_cuenta
               AND (fecha > p_fec_ult_categorizacion OR p_fec_ult_categorizacion IS NULL);
         EXCEPTION
            WHEN OTHERS THEN
               v_mto_cap_cobrado := 0;
         END;
         IF p_tip_monto = 'M' THEN
            BEGIN
               SELECT SUM(sal_capital)
                 INTO v_sal_capital
                 FROM pr_cuotas
                WHERE nro_cuenta = p_nro_cuenta
                  AND ((p_tip_saldo = 'V' AND (p_fecha - fec_vencimiento) > p_dias_atraso) OR
                      (p_tip_saldo = 'O'));
            EXCEPTION
               WHEN OTHERS THEN
                  v_sal_capital := 0;
            END;
         END IF;
      ELSIF v_cod_modulo = 15 THEN   
         BEGIN
            SELECT SUM(mto_total)
              INTO v_mto_cap_cobrado
              FROM ov_cobros
             WHERE nro_cuenta = p_nro_cuenta
               AND fecha > p_fec_ult_categorizacion;
         EXCEPTION
            WHEN OTHERS THEN
               v_mto_cap_cobrado := 0;
         END;
         IF p_tip_monto = 'M' THEN
            BEGIN
               SELECT sal_total
                 INTO v_sal_capital
                 FROM ov_cta_vencidas
                WHERE nro_cuenta = p_nro_cuenta;
            EXCEPTION
               WHEN OTHERS THEN
                  v_sal_capital := 0;
            END;
         END IF;
      END IF; 
      v_monto := nvl(v_mto_cap_cobrado, 0) + nvl(v_sal_capital, 0);     
   ELSIF nvl(p_valor,'C') = 'H' THEN --Res 12 Préstamos Hip.
      IF v_cod_modulo = 6 THEN
         BEGIN
            SELECT SUM(
                    nvl(a.mto_capital, 0) +
                    nvl(a.mto_interes, 0) +
                    nvl(a.mto_int_documentado, 0) +
                    nvl(a.mto_int_moratorio, 0) +
                    nvl(a.mto_int_mor_interes, 0) +
                    nvl(a.mto_int_mor_adelantado, 0) + 
                    nvl(a.mto_int_punitorio,0) + 
                    nvl(a.mto_cargo,0) + 
                    nvl(a.mto_impuesto,0))
              INTO v_mto_cap_cobrado
              FROM pr_cobros a
             WHERE nro_cuenta = p_nro_cuenta
               AND (fecha > p_fec_ult_categorizacion OR p_fec_ult_categorizacion IS NULL);
         EXCEPTION
            WHEN OTHERS THEN
               v_mto_cap_cobrado := 0;
         END;
         IF p_tip_monto = 'M' THEN
            BEGIN
               SELECT MIN(nro_cuota), MAX(nro_cuota)
                 INTO v_nro_cuo_desde, v_nro_cuo_hasta
                 FROM pr_cuotas
                WHERE nro_cuenta = p_nro_cuenta
                  AND nro_cuota > 0
                  AND estado <> 'N'
                  AND ((p_tip_saldo = 'V' AND (p_fecha - fec_vencimiento) > p_dias_atraso) OR
                      (p_tip_saldo = 'O'));
            EXCEPTION
               WHEN OTHERS THEN
                  v_nro_cuo_desde := null;
                  v_nro_cuo_hasta := null;
            END;
            --inicializar variables de cobro
            pap_pre.pr_ini_var_cobro;
            pap_pre.pr_ini_autorizacion;
            pap_pre.pr_obt_deu_prestamo(p_nro_cuenta, v_fec_cobro, v_nro_cuo_desde, v_nro_cuo_hasta, v_cod_ofi_origen, v_sal_cobrado, v_error,
                                        v_mensaje, v_sal_capital, v_sal_interes, v_sal_int_ade, v_mora, v_mora_interes,
                                        v_mora_int_ade, v_punitorio, v_impuesto, v_cargo, v_cargo_iva, v_int_descontado,
                                        v_dia_mora, v_cod_tra_padre, v_cancelacion,v_renueva,v_cancel_rrr);
            commit;                            
            v_tot_deuda := nvl(v_sal_capital,0)  +
                           nvl(v_sal_interes,0)  +
                           nvl(v_mora,0)         +
                           nvl(v_mora_interes,0) +
                           nvl(v_mora_int_ade,0) +
                           nvl(v_punitorio,0)    +
                           nvl(v_impuesto,0)     +
                           nvl(v_cargo,0)      /*+
                           nvl(v_cargo_iva,0)*/  ;                            
         END IF;                                             
      END IF; 
      v_monto := nvl(v_mto_cap_cobrado, 0) + nvl(v_tot_deuda, 0);  
   Elsif nvl(p_valor,'C') = 'I' Then
       BEGIN
          SELECT SUM(mto_interes)
            INTO v_mto_cap_cobrado
            FROM pr_cobros
           WHERE nro_cuenta = p_nro_cuenta
             AND (fecha > p_fec_ult_categorizacion OR p_fec_ult_categorizacion IS NULL);
       EXCEPTION
          WHEN OTHERS THEN
             v_mto_cap_cobrado := 0;
       END;
       IF p_tip_monto = 'M' THEN
          BEGIN
             SELECT SUM(sal_interes)
               INTO v_sal_capital
               FROM pr_cuotas
              WHERE nro_cuenta = p_nro_cuenta
                AND ((p_tip_saldo = 'V' AND (p_fecha - fec_vencimiento) > p_dias_atraso) OR
                    (p_tip_saldo = 'O'));
          EXCEPTION
             WHEN OTHERS THEN
                v_sal_capital := 0;
          END;
       END IF;
       v_monto := nvl(v_mto_cap_cobrado, 0) + nvl(v_sal_capital, 0);
   End If;
   RETURN v_monto;

END;
/

