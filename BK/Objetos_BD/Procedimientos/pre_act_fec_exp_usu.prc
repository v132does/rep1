CREATE OR REPLACE PROCEDURE IT.PRE_ACT_FEC_EXP_USU
 (P_COD_USUARIO IN BA_USUARIOS.COD_USUARIO%TYPE
 )
 IS

/* Verificar si existe el modulo general. */
FUNCTION LF_VER_EXI_GENERAL
 RETURN BOOLEAN;
--- OBS: Este procedimiento es dinamico para el caso en que se instale el modulo base
   --- y no el modulo general.
   v_general boolean;
   v_cur_dinamico integer;

/* Verificar si existe el modulo general. */
FUNCTION LF_VER_EXI_GENERAL
 RETURN BOOLEAN
 IS
v_cantidad number(01);
BEGIN
   select 1
   into v_cantidad
   from ba_modulos
   where cod_modulo = 1;
   return true;
exception
   when no_data_found then
      return false;
   when too_many_rows then
      return true;
END;
BEGIN
   --- Verificar si existe instalado el módulo general
   v_general := lf_ver_exi_general;
   if v_general then
      --- Verificar si se valida expiración o no
         --- Recuperar dias a modificar
         --- Modificar usuario
      pae_din.pr_eje_curdinam(
        'DECLARE  v_validar varchar2(01); v_dias number(05); '||
        'BEGIN v_validar := fug_obt_pardinamico('||''''||'CON_FEC_EXPIRA'||''''||',null,null,null,null); '||
        ' if v_validar = '||''''||'S'||''''||' then '||
        '    v_dias := fug_obt_pardinamico('||''''||'DIA_EXPIRA'||''''||',null,null,null,null); '||
        '    update ba_usuarios '||
        '    set fec_exp_clave = trunc(sysdate) + v_dias '||
        '    where cod_usuario = '||''''||p_cod_usuario||''''||';'||
        ' end if; '||
        'END;');
   end if;
exception
   when others then
      null;
END;
/

