CREATE OR REPLACE FUNCTION IT.FUY_ES_GERENTE_TI
 (P_COD_USUARIO IN BA_USUARIOS.COD_USUARIO%TYPE
 )
 RETURN VARCHAR2
 IS

V_ES_GERENTE VARCHAR2(1) := 'N';
V_CANT NUMBER := 0;
BEGIN

   select count(*)
   into v_cant
   from ba_usu_roles
   where cod_usuario = p_cod_usuario
   and cod_rol = 'ITAP_GERENTE_TI';

   if v_cant > 0 then
      v_es_gerente := 'S';
   elsif v_cant = 0 then
      v_es_gerente := 'N';
   end if;

return v_es_gerente;

EXCEPTION
    WHEN OTHERS THEN
    raise_application_error(-20001,
      'FUY_ES_GERENTE_TI'||SQLERRM);
END;
/

