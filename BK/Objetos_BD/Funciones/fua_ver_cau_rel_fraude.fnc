create or replace function it.fua_ver_cau_rel_fraude(p_cod_causa in number) return varchar2 is
  --Proyecto SDFNVTDD-1 Vto Aleatorio de Tarjeta Debito por Fraude--
  v_cau_rel_fraude varchar2(1);
begin
  v_cau_rel_fraude := 'N';
  select 'S'
    into v_cau_rel_fraude
    from ge_par_causales x
   where x.cod_causa = p_cod_causa
     and x.parametro = 'CAU_REL_FRAUDE'
     and nvl(x.val_parametro,'N') = 'S';
   return v_cau_rel_fraude;
exception
  when no_data_found then
    return 'N';
  when others then
    raise_application_error(-20002, 'Error en fua_ver_cau_rel_fraude: '||sqlerrm);
end;
/

