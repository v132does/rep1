CREATE OR REPLACE FUNCTION IT.FUG_PUE_VER_CLIENTE
 (P_COD_PERSONA IN GE_CLIENTES.COD_PERSONA%TYPE
 )
 RETURN VARCHAR2
 IS
v_puede_ver varchar2(1) := 'N';
begin
   if fug_cli_confidencial(p_cod_persona) = 'N' then
     v_puede_ver := 'N';
   else
     v_puede_ver := 'S';
   end if;
   if fue_obt_ve_cta_cli(user, p_cod_persona) = 'N' then
      v_puede_ver := 'N';
   else
     v_puede_ver := 'S';
   end if;
   If v_puede_ver = 'S' then
     -- si es de riesgos pueve ver todos los clientes
     begin
       select 'S'
         into v_puede_ver
         from ba_usuarios z, ba_usu_roles x
        where x.cod_usuario = user
          and x.cod_rol like '%RIESGOS%'
          and z.cod_usuario = x.cod_usuario;
     exception
       when no_data_found then
         v_puede_ver := 'N';
     end;
     if v_puede_ver = 'N' then
       -- verifica si es oficial
       begin
         select 'S'
           into v_puede_ver
           from ba_usuarios
          where cod_usuario = user
            and oficial = 'S';
         --verifica si es su cliente
         begin
           select 'S'
             into v_puede_ver
             from ge_clientes c
            where c.cod_persona = p_cod_persona
              and c.cod_usu_oficial = user;
         exception
           when no_data_found then
             v_puede_ver := 'N';
         end;
       exception
         when no_data_found then
           v_puede_ver := 'N';
       end;
     end if;
   End if;
   return v_puede_ver;
end;
/

