CREATE OR REPLACE PROCEDURE IT.PRG_ACT_PAR_DINAMICO
 (P_PARAMETRO IN GE_PAR_DINAMICOS.PARAMETRO%TYPE
 ,P_COD_MODULO IN NUMBER := NULL
 ,P_COD_MODALIDAD IN NUMBER := NULL
 ,P_COD_MONEDA IN VARCHAR2 := 'NULL'
 ,P_COD_OFICINA IN NUMBER := NULL
 ,P_VALOR IN GE_PAR_DINAMICOS.VAL_PARAMETRO%TYPE
 ,P_COD_SUB_MODALIDAD IN NUMBER DEFAULT NULL
 )
 IS
BEGIN
   update ge_par_dinamicos
   set val_parametro = p_valor
   where parametro = p_parametro
   and nvl(nvl(cod_modulo,p_cod_modulo),-1)       = nvl(p_cod_modulo,-1)
   and nvl(nvl(cod_modalidad,p_cod_modalidad),-1) = nvl(p_cod_modalidad,-1)
   and nvl(nvl(cod_sub_modalidad,p_cod_sub_modalidad),-1) = nvl(p_cod_sub_modalidad,-1)
   and nvl(nvl(cod_moneda,p_cod_moneda),'X')      = nvl(p_cod_moneda,'X')
   and nvl(nvl(cod_oficina,p_cod_oficina),-1)     = nvl(p_cod_oficina,-1);
   if sql%notfound then
      raise_application_error(-20000,
      'No pudo actualizarse parametro '||p_parametro||' p/ Ofi '||p_cod_oficina||' Mod '||p_cod_modulo||' Mad '||p_cod_modalidad||
      ' Mon '||p_cod_moneda);
   end if;
EXCEPTION
  WHEN OTHERS THEN
      raise_application_error(-20001,
      'No pudo actualizarse OTRO ERROR '||SQLERRM);
END;
/

