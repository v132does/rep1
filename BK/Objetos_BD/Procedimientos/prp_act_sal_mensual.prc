CREATE OR REPLACE PROCEDURE IT.PRP_ACT_SAL_MENSUAL
 IS
v_contador number(8) := 0;
v_fcdehoy  date;
v_fcproxi  date;
v_ani_fchoy number(4);
v_mes_fchoy number(2);
v_ani_fcprx number(4);
v_mes_fcprx number(2);
v_diferdia number;
v_diferde1 number;
v_nro_cta pr_cta_prestamos.nro_cuenta%type;
rv_gcale   ge_calendarios%rowtype;
c_limit CONSTANT NUMBER := 10000;
cursor mae_cur is
  select cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,sal_capital,
         sal_interes
    from pr_cta_prestamos
   where estado <> 'N';
TYPE t_tab_mae IS TABLE OF mae_cur%ROWTYPE;
  v_tab_mae t_tab_mae;
v_para number(2) := 0;
v_saldo ge_cuentas.sal_promedio%type;
v_can_dias number(5);

-- Manejo de excepciones en bloque FORALL
  ex_dml_errors EXCEPTION;
  PRAGMA EXCEPTION_INIT(ex_dml_errors, -24381);
  v_idx     NUMBER;
  v_msj_error varchar2(4000);

begin
  rv_gcale    := pag_cal.fu_obt_reg_cal(6);
  v_fcdehoy   := pag_cal.fu_obt_fec_actual(6);
  v_fcproxi   := rv_gcale.fec_proxima;
  
  v_mes_fchoy := TO_NUMBER(TO_CHAR(v_fcdehoy, 'MM'));
  v_ani_fchoy := TO_NUMBER(TO_CHAR(v_fcdehoy, 'YYYY'));
  v_mes_fcprx := TO_NUMBER(TO_CHAR(v_fcproxi, 'MM'));
  v_ani_fcprx := TO_NUMBER(TO_CHAR(v_fcproxi, 'YYYY'));

  IF v_mes_fcprx <> v_mes_fchoy THEN
     v_diferdia := (last_day(v_fcdehoy) - v_fcdehoy) + 1;
     v_diferde1 := TO_NUMBER(TO_CHAR(v_fcproxi, 'DD')) - 1;
  ELSE
     v_diferdia := v_fcproxi - v_fcdehoy;
     v_diferde1 := 0;
  END IF;
OPEN mae_cur;
  LOOP
    FETCH mae_cur BULK COLLECT INTO v_tab_mae LIMIT c_limit;
    v_contador := v_contador + v_tab_mae.COUNT;
    EXIT WHEN v_tab_mae.COUNT = 0;

    BEGIN
      FORALL i IN 1 .. v_tab_mae.COUNT SAVE EXCEPTIONS
        MERGE INTO pr_sal_mensuales t
        USING DUAL ON (t.nro_cuenta = v_tab_mae(i).nro_cuenta 
                   AND t.ano = v_ani_fchoy 
                   AND t.mes = v_mes_fchoy)
        WHEN MATCHED THEN
          UPDATE SET 
             t.tot_cap_acumulado = NVL(t.tot_cap_acumulado, 0) + (v_tab_mae(i).sal_capital * v_diferdia),
             t.tot_int_acumulado = NVL(t.tot_int_acumulado, 0) + (v_tab_mae(i).sal_interes * v_diferdia),
             t.can_dia_acumulado = NVL(t.can_dia_acumulado, 0) + v_diferdia,
             t.sal_cap_actual    = v_tab_mae(i).sal_capital,
             t.sal_int_actual    = v_tab_mae(i).sal_interes
        WHEN NOT MATCHED THEN
          INSERT (cod_modulo, cod_modalidad, cod_oficina, nro_cuenta, ano, mes,
                  sal_cap_actual, sal_int_actual, 
                  tot_cap_acumulado, tot_int_acumulado, can_dia_acumulado)
          VALUES (v_tab_mae(i).cod_modulo, v_tab_mae(i).cod_modalidad, v_tab_mae(i).cod_oficina, 
                  v_tab_mae(i).nro_cuenta, v_ani_fchoy, v_mes_fchoy,
                  v_tab_mae(i).sal_capital, v_tab_mae(i).sal_interes,
                  v_tab_mae(i).sal_capital * v_diferdia,
                  v_tab_mae(i).sal_interes * v_diferdia, v_diferdia);
      EXCEPTION
      WHEN ex_dml_errors THEN
         v_idx := SQL%BULK_EXCEPTIONS(1).ERROR_INDEX;
         v_msj_error := SQLERRM(-SQL%BULK_EXCEPTIONS(1).ERROR_CODE);
         v_nro_cta := v_tab_mae(v_idx).nro_cuenta;
         v_saldo := v_tab_mae(v_idx).sal_capital * v_diferdia;
         v_can_dias := v_diferdia;
         RAISE_APPLICATION_ERROR(-20000, 
            'Error Batch en MERGE. Cta: ' || v_nro_cta || 
            ' - Saldo Calc: ' || v_saldo || 
            ' - Dias: ' || v_can_dias || 
            ' - Error: ' || v_msj_error);
    END;
    BEGIN
      FORALL i IN 1 .. v_tab_mae.COUNT SAVE EXCEPTIONS
        UPDATE ge_cuentas c
           SET sal_promedio = (
               SELECT ROUND(DECODE(can_dia_acumulado, 0, 0, tot_cap_acumulado / can_dia_acumulado), 2)
                 FROM pr_sal_mensuales p
                WHERE p.nro_cuenta = c.nro_cuenta
                  AND p.ano = v_ani_fchoy
                  AND p.mes = v_mes_fchoy
           )
         WHERE c.nro_cuenta = v_tab_mae(i).nro_cuenta;
     EXCEPTION
        WHEN ex_dml_errors THEN
             v_idx := SQL%BULK_EXCEPTIONS(1).ERROR_INDEX;
             v_msj_error := SQLERRM(-SQL%BULK_EXCEPTIONS(1).ERROR_CODE);
             v_nro_cta := v_tab_mae(v_idx).nro_cuenta;     
             RAISE_APPLICATION_ERROR(-20000, 
                'Error Batch en UPDATE GE_CUENTAS. Cta: ' || v_nro_cta || ' - ' || v_msj_error);
        END;

      IF v_diferde1 <> 0 THEN
       BEGIN
        FORALL i IN 1 .. v_tab_mae.COUNT SAVE EXCEPTIONS
           INSERT INTO pr_sal_mensuales
             (cod_modulo, cod_modalidad, cod_oficina, nro_cuenta, ano, mes,
              sal_cap_actual, sal_int_actual, 
              tot_cap_acumulado, tot_int_acumulado, can_dia_acumulado)
           VALUES
             (v_tab_mae(i).cod_modulo, v_tab_mae(i).cod_modalidad, v_tab_mae(i).cod_oficina, 
              v_tab_mae(i).nro_cuenta, v_ani_fcprx, v_mes_fcprx,
              v_tab_mae(i).sal_capital, v_tab_mae(i).sal_interes,
              v_tab_mae(i).sal_capital * v_diferde1,
              v_tab_mae(i).sal_interes * v_diferde1, v_diferde1);
       EXCEPTION
        WHEN ex_dml_errors THEN
           v_idx := SQL%BULK_EXCEPTIONS(1).ERROR_INDEX;
           v_msj_error := SQLERRM(-SQL%BULK_EXCEPTIONS(1).ERROR_CODE);
           v_nro_cta   := v_tab_mae(v_idx).nro_cuenta;
           v_saldo     := v_tab_mae(v_idx).sal_capital * v_diferde1;
           v_can_dias  := v_diferde1;
           RAISE_APPLICATION_ERROR(-20000, 
              'Error Batch en INSERT NUEVO MES. Cta: ' || v_nro_cta || 
              ' - Saldo Calc: ' || v_saldo || 
              ' - Dias: ' || v_saldo || 
              ' - OraErr: ' || v_msj_error);
      END;
      END IF;
    END LOOP;
    
    if v_contador = 0 then
       raise_application_error(-20000,'No se encontraron cuentas activas en pr_cta_prestamos');
    end if; 
  CLOSE mae_cur;
exception
 when others then
    raise_application_error(-20000,'El ult. nro. es '||to_char(v_para)||'-'||to_char(v_nro_cta)||' - '||v_diferdia||' - '||v_saldo ||' - '||v_can_dias  ||SQLERRM);
end;
/
