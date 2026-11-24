CREATE OR REPLACE FUNCTION IT."GET_CUENTA_DEBITO_NUEVA" (p_riesgo IN NUMBER, p_propuesta IN NUMBER)
return VARCHAR2
IS
       v_suc NUMBER(3);
       v_cta NUMBER(10);
       v_sub NUMBER(10);
       v_nuevo_num_cuenta varchar2(12);
BEGIN

      /* select od.desuc, od.decta, od.desub into v_suc, v_cta, v_sub
          from olmaeact_deautocar od
              where od.deriesgo = p_riesgo  and od.deprop = p_propuesta;

       select nro_cta_it into v_nuevo_num_cuenta
          from cc_nros_cta where suc = v_suc and sub = v_sub and cta = v_cta;*/

       return v_nuevo_num_cuenta;

EXCEPTION
       WHEN NO_DATA_FOUND THEN return null;
       WHEN TOO_MANY_ROWS THEN raise_application_error(-20000,'Error!! '||SQLCODE||' '||SQLERRM);
END;
/

