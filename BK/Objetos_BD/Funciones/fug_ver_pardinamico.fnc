CREATE OR REPLACE FUNCTION IT.FUG_ver_PARDINAMICO
 (P_PARAMETRO IN GE_PAR_DINAMICOS.PARAMETRO%TYPE
 ,P_COD_MODULO IN NUMBER DEFAULT NULL
 ,P_COD_MODALIDAD IN NUMBER DEFAULT NULL
 ,P_COD_MONEDA IN VARCHAR2 DEFAULT NULL
 ,P_COD_OFICINA IN NUMBER DEFAULT NULL
 ,p_cod_sub_modalidad in number default null
 )
 RETURN VARCHAR2
 IS
v_val_parametro ge_par_dinamicos.val_parametro%type;
BEGIN
   select val_parametro
   into v_val_parametro
   from ge_par_dinamicos
   where nvl(cod_modulo,nvl(p_cod_modulo,-1)) = nvl(p_cod_modulo,-1)
   and nvl(cod_modalidad,nvl(p_cod_modalidad,-1)) = nvl(p_cod_modalidad,-1)
   and nvl(cod_sub_modalidad,nvl(p_cod_sub_modalidad,-1)) = nvl(p_cod_sub_modalidad,-1)
   and nvl(cod_oficina,nvl(p_cod_oficina,-1)) = nvl(p_cod_oficina,-1)
   and nvl(cod_moneda,nvl(p_cod_moneda,'x')) = nvl(p_cod_moneda,'x')
   and parametro = p_parametro;
   return 'S';
   exception
      when no_data_found then
         return 'N';
END;
/

