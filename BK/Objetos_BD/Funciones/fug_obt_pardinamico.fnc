CREATE OR REPLACE FUNCTION IT.FUG_OBT_PARDINAMICO
 (P_PARAMETRO IN GE_PAR_DINAMICOS.PARAMETRO%TYPE
 ,P_COD_MODULO IN NUMBER DEFAULT NULL
 ,P_COD_MODALIDAD IN NUMBER DEFAULT NULL
 ,P_COD_MONEDA IN VARCHAR2 DEFAULT NULL
 ,P_COD_OFICINA IN NUMBER  DEFAULT NULL
 ,P_COD_SUB_MODALIDAD IN varchar2 DEFAULT NULL
 )
 RETURN VARCHAR2
 IS
v_val_parametro ge_par_dinamicos.val_parametro%type;
cursor param is
   select /*+ RULE */ val_parametro
     from ge_par_dinamicos
    where nvl(cod_modulo,nvl(p_cod_modulo,-1)) = nvl(p_cod_modulo,-1)
      and nvl(cod_modalidad,nvl(p_cod_modalidad,-1)) = nvl(p_cod_modalidad,-1)
      and nvl(cod_sub_modalidad,nvl(p_cod_sub_modalidad,-1)) = nvl(p_cod_sub_modalidad,-1)
      and nvl(cod_oficina,nvl(p_cod_oficina,-1)) = nvl(p_cod_oficina,-1)
      and nvl(cod_moneda,nvl(p_cod_moneda,'x')) = nvl(p_cod_moneda,'x')
      and parametro = p_parametro
    order by decode(cod_modulo,null,0,1) +
             decode(cod_modalidad,null,0,1) +
             decode(cod_sub_modalidad,null,0,1) +
             decode(cod_oficina,null,0,1) +
             decode(cod_moneda,null,0,1) desc;  -- esto es para tomar en orden de importancia
BEGIN
   open param;
   fetch param into v_val_parametro;
   if param%notfound then
      close param;
      raise no_data_found;
   else
      close param;
   end if;
   return v_val_parametro;
   exception
      when no_data_found then
         return null;
/*         raise_application_error(-20000,
         'No existe valor p/parametro '||p_parametro);*/
END;
/

