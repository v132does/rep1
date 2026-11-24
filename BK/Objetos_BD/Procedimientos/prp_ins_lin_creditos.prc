create or replace procedure it.prp_ins_lin_creditos is
  cursor c_lineas is
  select a.cod_persona, a.cod_moneda, a.mto_limite, a.fec_inicio, a.fec_fin, a.cod_tip_garantia,
         a.mto_garantia, a.cod_modalidad, a.mto_modalidad, a.descripcion, a.observacion
    from pr_lin_cred_masiva a;

  v_nro_linea number;
begin
  for x in c_lineas loop
     select s_nro_linea.nextval
       into v_nro_linea
       from dual;
     ---Insertar en pr_lineas
     begin
        insert into pr_lineas(nro_linea, cod_persona, cod_moneda, monto, fec_vencimiento, fec_otorgamiento, descripcion, estado, observacion)
               values(v_nro_linea, x.cod_persona, x.cod_moneda, x.mto_limite, x.fec_fin, x.fec_inicio, x.descripcion, 'A', x.observacion);

        --Si no hay error y tiene la garantia, insertar en pr_lin_tip_garantias
        if nvl(x.cod_tip_garantia,0) <> 0 then
          begin
             insert into pr_lin_tip_garantias(nro_linea, cod_garantia, mto_limite)
               values(v_nro_linea, x.cod_tip_garantia, x.mto_garantia);

             --Si no hay error y tiene la garantia y modalidad, insertar en pr_lin_tip_gar_mad
             if nvl(x.cod_modalidad,0) <> 0 then
                begin
                   insert into pr_lin_tip_gar_mad(nro_linea, cod_garantia, cod_modulo, cod_modalidad, mto_limite)
                      values(v_nro_linea, x.cod_tip_garantia, 6, x.cod_modalidad, x.mto_modalidad);
                exception
                   when others then
                      raise_application_error(-20003, 'Error al insertar en pr_lin_tip_gar_mad - Persona'||x.cod_persona|| ' ' ||sqlerrm);
                end;
             end if;
          exception
            when others then
               raise_application_error(-20002, 'Error al insertar pr_lin_tip_garantias - Persona: '||x.cod_persona||' '||sqlerrm);
          end;
        end if;
     exception
        when others then
          raise_application_error(-20001, 'Error al insertar pr_lineas - Persona: '||x.cod_persona||' '||sqlerrm);
     end;
  end loop;
exception
  when others then
    raise_application_error(-20000, 'Error al ejecutar procedimiento: '||sqlerrm);
end;
/

