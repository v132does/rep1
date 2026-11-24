create or replace function it.fup_obt_mod_sit_garantia(p_nro_garantia number,
                                                    p_cod_usuario  varchar2,
                                                    p_cod_oficina  number default null)
return varchar2 is
  v_cod_oficina ba_oficinas.cod_oficina%type;
  v_cod_ofi_usu ba_oficinas.cod_oficina%type;
  v_cod_rol     ge_par_dinamicos.val_parametro%type;
  v_nom_tabla   pr_gar_tipos.nom_tab_anexa%type;
  v_modifica    varchar2(1) := 'S';
begin
  v_cod_ofi_usu := fug_obt_ofi_usuario(p_cod_usuario);
  --
  begin
    select g.cod_oficina, t.nom_tab_anexa
      into v_cod_oficina, v_nom_tabla
      from pr_garantias g,
           pr_gar_tipos t
     where g.cod_garantia = t.cod_garantia
       and g.nro_garantia = p_nro_garantia;
  exception
    when others then
      raise_application_error(-20000,'Error al buscar la garantía. '||sqlerrm);
  end;
  --
  if p_cod_oficina is not null then
    v_cod_oficina := p_cod_oficina;
  end if;
  --
  --if v_nom_tabla = 'PR_GAR_DOCUMENTOS' then
    if v_cod_ofi_usu <> v_cod_oficina then
      v_cod_rol := fug_obt_pardinamico('GAR_MOD_SITUACION',null,null,null,v_cod_oficina);
      --
      if v_cod_rol is not null then
        --
        begin
          select distinct 'S'
            into v_modifica
            from ba_usu_roles r
           where r.cod_usuario = p_cod_usuario
             and v_cod_rol LIKE '%*'||ltrim(rtrim(r.cod_rol))||'*%';
        exception
          when no_data_found then
            v_modifica := 'N';
          when others then
            raise_application_error(-20000,'Error al buscar el rol del Usuario. '||sqlerrm);
        end;
      else
        v_modifica := 'N';
      end if;
    end if;
  --end if;
  --
  return v_modifica;
end;
/

