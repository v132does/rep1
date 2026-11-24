create or replace function it.fug_pag_sal_autoriza(p_cod_persona   in ba_personas.cod_persona%type,
                                                p_nro_documento in bw_mov_pendientes.nro_documento%type,
                                                p_tipo          in char)
  return varchar is
  v_retorno varchar(200);
begin
  if p_tipo = 'R' then
    for caut in (Select trim(v.cod_per_vinculo) || ' ' ||
                        fue_obt_nom_persona(v.cod_per_vinculo) persona
                   from ba_vinculos v
                  where v.cod_persona = p_cod_persona
                    and instr(v.cod_perfil, 'AUTORIZA') > 0) loop
      if trim(v_retorno) is null then
        v_retorno := caut.persona;
      else
        v_retorno := v_retorno || ', ' || trim(caut.persona);
      end if;
    end loop;
  else
    for caut in (Select trim(a.cod_persona) || ' ' ||
                        fue_obt_nom_persona(a.cod_persona) persona
                   from bw_autorizaciones a
                  where nro_documento = p_nro_documento)
    
     loop
      if trim(v_retorno) is null then
        v_retorno := caut.persona;
      else
        v_retorno := v_retorno || ', ' || trim(caut.persona);
      end if;
    end loop;
  end if;
  return v_retorno;
exception
  when others then
    return '';
end;
/

