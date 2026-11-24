CREATE OR REPLACE FUNCTION IT.FUG_OBT_PUN_COTIZACION
 (P_COD_USUARIO IN VARCHAR2
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
 ,P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE)
 RETURN NUMBER
 IS

V_PUN_COTIZACION GE_USU_LIMITES.PUN_COTIZACION%TYPE;
BEGIN
   V_PUN_COTIZACION := 0;
   -- busqueda si existe en la moneda
   begin
   select MAX(A.PUN_COTIZACION)
     into V_PUN_COTIZACION
     from GE_USU_LIMITES A, BA_USUARIOS B
    where B.COD_USUARIO = P_COD_USUARIO
    and A.COD_MONEDA = P_COD_MONEDA
    and (nvl(a.cod_oficina,-9) = nvl(p_cod_oficina,-9) or a.cod_oficina is null)
    and (nvl(a.cod_modalidad,-9) = nvl(p_cod_modalidad,-9) or a.cod_modalidad is null)
    and (A.COD_USUARIO = P_COD_USUARIO OR (A.COD_USUARIO IS NULL AND A.CATEGORIA = B.CATEGORIA))
    AND NVL(PUN_COTIZACION,0) >0;--para q funcione para cambios
   exception
      when others then V_PUN_COTIZACION := null;
   end;
   return nvl(V_PUN_COTIZACION,0);
EXCEPTION
   when no_data_found then
        raise_application_error(-20000,'No existe límite en GE_USU_LIMITES');
END;
/

