create or replace function it.fui_pue_ver
(p_cod_unidad in number,
 p_cod_oficial in varchar2 default null)
return varchar2 is
v_puede               varchar2(1) := 'N';
v_cod_usu_responsable varchar2(10);
v_cod_unidad          number(5) := p_cod_unidad;
v_es_oficial          varchar2(5);
v_categoria           varchar2(10);
v_cta_empl            varchar2(1);
begin
   if p_cod_oficial is not null then
      if p_cod_oficial = user then
         v_puede := 'S';
      else
         begin
           select n.cod_usu_responsable
             into v_cod_usu_responsable
             from ig_uni_negocios n, ba_usuarios u
            where u.cod_unidad = n.cod_unidad
              and u.cod_usuario = p_cod_oficial;
           if v_cod_usu_responsable = user then
              -- es responsable de la unidad del oficial
              v_puede := 'S';
           end if;
         exception
            when no_data_found then
               v_puede := 'N';
         end;
      end if;
   end if;
   if v_puede = 'N' then
       begin
         select 'S'
           into v_puede
           from ig_uni_negocios n
          where n.cod_usu_responsable = user
            and n.cod_unidad = p_cod_unidad;
       exception
          when too_many_rows then
             v_puede := 'S';
          when no_data_found then
             v_puede := 'N';
       end;
   end if;
   if v_puede = 'N' then
      -- veo si el usuario es un oficial, entonces puede ver su unidad
      begin
         select cod_unidad, categoria, oficial, u.ver_cta_empleados
           into v_cod_unidad, v_categoria, v_es_oficial, v_cta_empl
           from ba_usuarios u
          where u.cod_usuario = user;
         if v_categoria in ('SC','GC','PC') or v_cta_empl='S' then -- gte, sub gte comercial O planificacion y Control y RRHH
            v_puede := 'S';
         elsif v_es_oficial = 'S' and v_cod_unidad = p_cod_unidad and p_cod_oficial is null then
            v_puede := 'S';
         end if;
      exception
         when others then
            v_puede := 'N';
      end;
      if v_puede = 'N' then
          -- puede que el usuario sea un encargado de la regional al cual pertenece el oficial
          begin
             select 'S'
               into v_puede
               from ba_gru_oficinas c, ba_oficinas b, ig_uni_negocios a
              where a.cod_unidad = p_cod_unidad --v_cod_unidad
                and a.cod_oficina = b.cod_oficina
                and c.cod_gru_oficina = b.cod_gru_oficina
                and c.cod_usu_encargado = user
                and rownum = 1;
          exception
             when others then
                v_puede := 'N';
          end;
      end if;
   end if;
   return v_puede;
exception
   when others then
      return 'N';
end;
/

