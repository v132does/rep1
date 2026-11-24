CREATE OR REPLACE FUNCTION IT.FUG_OBT_SIT_CUENTA (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE   ) RETURN VARCHAR2 IS
  --> Retorna la situación de la cuenta. Activo S/N.
  Result varchar2(1) := 'N';
BEGIN
   select b.activo
     into result
     from ge_cuentas a, ge_est_cuentas b
    where a.cod_modulo      = b.cod_modulo
      and a.cod_modalidad   = b.cod_modalidad
      and a.estado          = b.estado
      and a.nro_cuenta      = p_nro_cuenta;
    return(Result); 
EXCEPTION
  WHEN OTHERS THEN
       RETURN 'N';
END;
/

