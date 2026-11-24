CREATE OR REPLACE FUNCTION IT.FUB_OBT_FEC_INI_DEV_AS400
 (P_NRO_CUENTA IN PR_DEVENGADOS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_DEVENGADOS.NRO_CUOTA%TYPE
 )
 RETURN DATE
 IS
v_fec_inicio pr_cta_prestamos.fec_inicio%type;
BEGIN

   select fec_inicio_dev
     into v_fec_inicio
     from pr_cuotas_maecartera
    where nro_cuenta = p_nro_cuenta
      and nro_cuota = p_nro_cuota;
    return v_fec_inicio;
exception
   when no_data_found then
      return null;
END;
/

