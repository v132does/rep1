CREATE OR REPLACE PROCEDURE IT.prr_gen_vta_cru_nominas IS

   v_dia NUMBER(2);
   v_mes NUMERIC(2);
   v_ano VARCHAR2(4);

   CURSOR nominas_cc IS
      SELECT a.ano, a.mes, a.dia, a.cod_persona, a.nro_cta_nomina
        FROM cr_vta_cruzadas a
       WHERE a.ano = v_ano
         AND a.mes = v_mes
         AND a.dia = v_dia
         AND a.cli_nomina = 'S'
         AND a.tip_nomina = 'CC';

   CURSOR nominas_ca IS
      SELECT a.ano, a.mes, a.dia, a.cod_persona, a.nro_cta_nomina
        FROM cr_vta_cruzadas a
       WHERE a.ano = v_ano
         AND a.mes = v_mes
         AND a.dia = v_dia
         AND a.cli_nomina = 'S'
         AND a.tip_nomina = 'CA';

   v_fecha DATE;

   rg_cr_vta_cru cr_vta_cruzadas%ROWTYPE;

   -------------------------------------

BEGIN

   /*obtener dia,mes,año*/
   SELECT to_number(to_char(SYSDATE, 'DD')),
          to_number(to_char(SYSDATE, 'MM')),
          to_number(to_char(SYSDATE, 'YYYY'))
     INTO v_dia, v_mes, v_ano
     FROM dual;

   SELECT add_months(trunc(SYSDATE), -3) fecha INTO v_fecha FROM dual;

   rg_cr_vta_cru.mto_ult_sueldo := NULL;
   rg_cr_vta_cru.fec_ult_sueldo := NULL;

   -------------------------------------

   FOR ccl IN nominas_cc LOOP

      BEGIN

         SELECT nvl(a.monto, 0), a.fecha
           INTO rg_cr_vta_cru.mto_ult_sueldo, rg_cr_vta_cru.fec_ult_sueldo
           FROM cc_movimientos_his a
          WHERE a.nro_cuenta = ccl.nro_cta_nomina
            AND a.fecha = (SELECT MAX(b.fecha)
                             FROM cc_movimientos_his b
                            WHERE b.nro_cuenta = ccl.nro_cta_nomina
                              AND b.fecha > v_fecha
                              AND b.cod_tra_padre = 303)
            AND a.cod_tra_padre = 303
            AND rownum = 1;

         UPDATE cr_vta_cruzadas a
            SET a.mto_ult_sueldo = rg_cr_vta_cru.mto_ult_sueldo,
                fec_ult_sueldo   = rg_cr_vta_cru.fec_ult_sueldo
          WHERE a.ano = ccl.ano
            AND a.mes = ccl.mes
            AND a.dia = ccl.dia
            AND a.cod_persona = ccl.cod_persona
            AND a.nro_cta_nomina = ccl.nro_cta_nomina;

      EXCEPTION
         WHEN no_data_found THEN
            NULL;
         WHEN OTHERS THEN

            raise_application_error(-20000, 'error en cc_movimientos_his ' || SQLERRM);
      END;

   END LOOP;

   -------------------------------------

   rg_cr_vta_cru.mto_ult_sueldo := NULL;
   rg_cr_vta_cru.fec_ult_sueldo := NULL;

   -------------------------------------

   FOR cal IN nominas_ca LOOP

      BEGIN

         SELECT nvl(a.monto, 0), a.fecha
           INTO rg_cr_vta_cru.mto_ult_sueldo, rg_cr_vta_cru.fec_ult_sueldo
           FROM ah_movimientos_his a
          WHERE a.nro_cuenta = cal.nro_cta_nomina
            AND a.fecha = (SELECT MAX(b.fecha)
                             FROM ah_movimientos_his b
                            WHERE b.nro_cuenta = cal.nro_cta_nomina
                              AND b.fecha > v_fecha
                              AND b.cod_tra_padre = 303)
            AND a.cod_tra_padre = 303
            AND rownum = 1;

         UPDATE cr_vta_cruzadas a
            SET a.mto_ult_sueldo = rg_cr_vta_cru.mto_ult_sueldo,
                fec_ult_sueldo   = rg_cr_vta_cru.fec_ult_sueldo
          WHERE a.ano = cal.ano
            AND a.mes = cal.mes
            AND a.dia = cal.dia
            AND a.cod_persona = cal.cod_persona
            AND a.nro_cta_nomina = cal.nro_cta_nomina;

      EXCEPTION
         WHEN no_data_found THEN
            NULL;
         WHEN OTHERS THEN
            raise_application_error(-20000, 'error en ah_movimientos_his ' || SQLERRM);
      END;

   END LOOP;

END;
/

