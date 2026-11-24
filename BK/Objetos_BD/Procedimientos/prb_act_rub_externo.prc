CREATE OR REPLACE PROCEDURE IT.PRB_ACT_RUB_EXTERNO is
  cursor c_rubros is
  select a.cod_rubro_madrid, upper(a.descripcion) descripcion, a.tipo_rub
    from cb_tmp_ctas a;

  v_existe varchar2(1) := 'N';
begin
   for x in c_rubros loop
      v_existe := 'N';
      if x.tipo_rub = 'C' then --Cta. Consolidacion
         /*Buscar si existe en la tabla real cb_cta_consolidacion*/
        begin
           select 'S'
             into v_existe
             from cb_rub_consolidacion cta
            where cta.cod_consolidacion = x.cod_rubro_madrid;
        exception
           when no_data_found then
              v_existe := 'N';
           when too_many_rows then
              v_existe := 'S';
           when others then
              v_existe := 'N';
        end;
        if nvl(v_existe,'N') = 'S' then
          begin
             update cb_rub_consolidacion c
                set c.descripcion = x.descripcion
              where c.cod_consolidacion = x.cod_rubro_madrid;
          exception
             when others then
                raise_application_error(-20001, 'Error al actualizar rubros Conso: '||x.cod_rubro_madrid||' '||sqlerrm);
          end;
        else
          begin
             insert into cb_rub_consolidacion(cod_consolidacion, descripcion)
                    values (x.cod_rubro_madrid, x.descripcion);
          exception
             when others then
               raise_application_error(-20001, 'Error al insertar rubro Conso: '||x.cod_rubro_madrid||' '||sqlerrm);
          end;
        end if;
      elsif x.tipo_rub = 'G' then --Cta. Gestion
         /*Buscar si existe en la tabla real cb_cta_gestion*/
        begin
           select 'S'
             into v_existe
             from cb_rub_gestion cta
            where cta.cod_gestion = x.cod_rubro_madrid;
        exception
           when no_data_found then
              v_existe := 'N';
           when too_many_rows then
              v_existe := 'S';
           when others then
              v_existe := 'N';
        end;
        if nvl(v_existe,'N') = 'S' then
          begin
             update cb_rub_gestion c
                set c.descripcion = x.descripcion
              where c.cod_gestion = x.cod_rubro_madrid;
          exception
             when others then
                raise_application_error(-20001, 'Error al actualizar rubros Gestio: '||x.cod_rubro_madrid||' '||sqlerrm);
          end;
        else
          begin
             insert into cb_rub_gestion(cod_gestion, descripcion)
                    values (x.cod_rubro_madrid, x.descripcion);
          exception
             when others then
               raise_application_error(-20001, 'Error al insertar rubro Gestion: '||x.cod_rubro_madrid||' '||sqlerrm);
          end;
        end if;
      end if;

   end loop;
exception
   when others then
      raise_application_error(-20000, 'Error al ejecutar procedimiento prb_act_rub_externo: '||sqlerrm);
end;
/

