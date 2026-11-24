CREATE OR REPLACE FUNCTION IT.fug_obt_rel_tarjeta(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                                                  P_NRO_CUENTA  IN GE_CUENTAS.NRO_CUENTA%TYPE)
  RETURN VARCHAR2 IS

  V_RELACION ge_cta_clientes.relacion%type := NULL;
  -- Retorna la relacion de la persona en una cuenta específica.--
BEGIN
  Select RELACION
    into V_RELACION
    from GE_CTA_CLIENTES
   where NRO_CUENTA  = P_NRO_CUENTA
     and COD_PERSONA = P_COD_PERSONA;
 
  Return V_RELACION;

Exception
  When OTHERS Then
    Return '1';
END;
/

