CREATE OR REPLACE FUNCTION IT.FUG_OBT_PUNTAJE
 (P_COD_MODULO IN GE_SOL_PUNTAJES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_SOL_PUNTAJES.COD_MODALIDAD%TYPE
 ,P_COD_CAMPANA IN GE_SOL_PUNTAJES.COD_CAMPANA%TYPE
 ,P_COD_CANAL IN GE_SOL_PUNTAJES.COD_CANAL%TYPE
 )
 RETURN NUMBER
 IS
v_cod_puntaje ge_sol_puntajes.cod_puntaje%type;
BEGIN
   select cod_puntaje
     into v_cod_puntaje
     from ge_sol_puntajes
    where cod_modulo = p_cod_modulo
      and nvl(cod_modalidad,nvl(p_cod_modalidad,-1)) = nvl(p_cod_modalidad,-1)
      and nvl(cod_campana,nvl(p_cod_campana,-1)) = nvl(p_cod_campana,-1)
      and nvl(cod_canal,nvl(p_cod_canal,-1)) = nvl(p_cod_canal,-1);
   return v_cod_puntaje;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Puntaje no definido p/Mod: '||p_cod_modulo||' Modal: '||p_cod_modalidad||
      ' Camp: '||p_cod_campana||' Canal '||p_cod_canal);
END;
/

