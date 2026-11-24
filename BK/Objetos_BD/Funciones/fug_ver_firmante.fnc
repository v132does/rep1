CREATE OR REPLACE FUNCTION IT.FUG_VER_FIRMANTE
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 ,P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
 ,P_MENSAJE_ERROR OUT VARCHAR2
 )
 RETURN VARCHAR2
 IS

V_EXISTE_INHIBICION VARCHAR2(1);
V_MENS VARCHAR2(200);
V_EST_VERIFICACION VARCHAR2(1);
V_ERROR VARCHAR2(5);
begin
   v_error := 0;

   v_existe_inhibicion :=  fug_ver_inhibicion(p_cod_persona, p_cod_modalidad);
   if  v_existe_inhibicion = 'S'  then
      v_error:= '-2000' ;
      p_mensaje_error := 'Persona Inhibida para este tipo de Cuentas.';
      return(v_error);
   end if;
   return  v_error;
EXCEPTION
   WHEN NO_DATA_FOUND  THEN
      p_mensaje_error :=  null;
      return(v_error);
end ;
/

