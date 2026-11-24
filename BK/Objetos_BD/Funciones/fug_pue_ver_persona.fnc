create or replace function it.fug_pue_ver_persona
(p_cod_persona in varchar2)
return varchar2 is
v_puede varchar2(1) := 'N';
v_cod_oficina number(5);
v_cod_usu_oficial varchar2(10);
begin
   select cod_usu_oficial, cod_oficina
     into v_cod_usu_oficial, v_cod_oficina
     from ge_clientes
    where cod_persona = p_cod_persona;
   if v_cod_usu_oficial = user then
      v_puede := 'S';
   else
     -- si es el encargado de la Agencia puede ver lo de la Agencia
     begin
       select 'S'
         into v_puede
         from ba_oficinas
        where cod_oficina = v_cod_oficina
          and cod_usu_encargado = user;
     exception
        when no_data_found then
          v_puede := 'N';
     end;
     if v_puede = 'N' then
        -- Verifico si es encargado de la regional
        begin
          -- El cliente es del grupo de oficinas(relacion con la oficina del cliente),
          -- y el usuario es el encargado de dicho grupo, se muestra, sino NO.
          Select 'S' into v_puede
            from ba_gru_oficinas g, ba_oficinas o
           where g.cod_usu_encargado = user
             and g.cod_gru_oficina = o.cod_gru_oficina
             and o.cod_oficina = v_cod_oficina;
        exception
          when no_data_found then
             v_puede := 'N';
        end;
        -- Sigue sin poder ver
        if v_puede = 'N' then
           -- si es el operativo de la agencia, debe ver lo de la Agencia
           begin
             select 'S'
               into v_puede
               from ba_usuarios z, ba_usu_roles x
              where x.cod_usuario = user
                and x.cod_rol like '%OPERATIV%'
                and z.cod_usuario = x.cod_usuario
                and z.cod_oficina = v_cod_oficina
                and rownum = 1;
           exception
              when no_data_found then
                v_puede := 'N';
           end;
           if v_puede = 'N' then
               -- Si el usuario es de Auditoria, Administrativo, suministro u Operaciones puede ver todo
               begin
                 select 'S'
                   into v_puede
                   from ba_usu_roles x
                  where x.cod_usuario = user
                    and (x.cod_rol like '%OPERAC%' or
                         x.cod_rol like '%AUDITOR%' or
                         x.cod_rol like '%ADMINIS%' or
                         x.cod_rol like '%GTE_NEG%' or
                         x.cod_rol like '%GCIA_NEG%' or
                         x.cod_rol like '%GEREN%' or
                         x.cod_rol like '%ANALIS%' or
                         x.cod_rol like '%RIESG%' or
                         x.cod_rol like '%RRHH%')
                    and rownum = 1;
               exception
                  when no_data_found then
                    v_puede := 'N';
               end;

           end if;
        end if;
     end if;
   end if;
   return v_puede;
exception
   when others then
      return 'N';
end;
/

