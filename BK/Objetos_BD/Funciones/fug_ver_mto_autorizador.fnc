CREATE OR REPLACE FUNCTION IT.FUG_VER_MTO_AUTORIZADOR
 (P_COD_TRA_PADRE IN GE_AUTORIZADORES.COD_TRA_PADRE%TYPE
 ,P_COD_MOD_PADRE IN GE_AUTORIZADORES.COD_MOD_PADRE%TYPE
 ,P_COD_MAD_PADRE IN GE_AUTORIZADORES.COD_MAD_PADRE%TYPE
 ,P_COD_OFICINA IN GE_AUTORIZADORES.COD_OFICINA%TYPE
 ,P_MONTO IN GE_AUTORIZADORES.MONTO%TYPE
)
 RETURN varchar2 IS

--- Recuperar usuario que va a autorizar el pedido
   v_cod_usuario ge_autorizadores.cod_usuario%type;
cursor aut is
   select cod_usuario
     from ge_autorizadores
    where nvl(cod_tra_padre,nvl(p_cod_tra_padre,-1)) = nvl(p_cod_tra_padre,-1)
      and nvl(cod_mod_padre,nvl(p_cod_mod_padre,-1)) = nvl(p_cod_mod_padre,-1)
      and nvl(cod_mad_padre,nvl(p_cod_mad_padre,-1)) = nvl(p_cod_mad_padre,-1)
      and nvl(cod_oficina,nvl(p_cod_oficina,-1)) = nvl(p_cod_oficina,-1)
      and nvl(monto,nvl(p_monto,-1)) >= nvl(p_monto,-1)
      and cod_usuario = user;
BEGIN
   for reg in aut loop
       v_cod_usuario:= reg.cod_usuario;
   end loop;
   if v_cod_usuario is null then
      return 'N';
   else
      return 'S';
   end if;
EXCEPTION
   when others then
      return 'N';
END;
/

