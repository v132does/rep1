CREATE OR REPLACE PROCEDURE IT.prueba_solicitud (p_nro in number,
p_fecha in date) IS
   r_psoli     pr_solicitudes%rowtype;
   v_error     number(10):=0;
   v_mensaje   varchar2(1000);
   v_mto_cargo pr_solicitudes.mto_cargo%type;
   v_mto_int_adelantado pr_solicitudes.mto_interes%type;
BEGIN
   pap_pre.pr_obt_dat_solicitud(p_nro, r_psoli, v_mto_cargo, v_mto_int_adelantado);
   pap_pre.PR_VAL_DESEMBOLSO(p_nro, r_psoli, p_fecha, v_error, v_mensaje);
   if v_error <> 0 then
   	  --:global.error := v_error;
   	  raise_application_error(-20000,v_error||' - '||v_mensaje);
   	  --raise form_trigger_failure;
   end if;
END;
/

