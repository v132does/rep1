create or replace procedure it.prg_can_seguros is
  v_existe varchar2(1):= 'N';
  v_error  varchar2(300):= null;
  cursor c_seg is
    select a.cod_persona, a.nro_seguro
      from ge_cli_seguros_tmp a;
begin
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END; 
  for c in c_seg loop
    begin
      select 'S'
        into v_existe
        from ge_cli_seguros a
       where a.cod_persona = c.cod_persona
         and a.nro_seguro = c.nro_seguro;
    exception
      when no_data_found then
        v_existe := 'N';
        v_error := 'No existe Seguro '||c.nro_seguro||' para la persona '||c.cod_persona;
      when others then
        v_existe := 'N';
        v_error := 'Error al cancelar Seguro '||c.nro_seguro||' '||sqlerrm;
    end;
    if v_existe = 'S' then
       update ge_cli_seguros a
          set a.estado = 'C'
        where a.cod_persona = c.cod_persona
          and a.nro_seguro = c.nro_seguro;
    elsif v_error is not null then
       update ge_cli_seguros_tmp a
          set a.error = v_error
        where a.cod_persona = c.cod_persona
          and a.nro_seguro = c.nro_seguro;
    end if;
  end loop;
  --** Elimina los registros de la tabla temporal **--
  begin
    delete ge_cli_seguros_tmp a
     where a.error is null;
     commit;
  exception
     when others then
        raise_application_error(-20060, 'Error al eliminar registros de GE_CLI_SEGUROS_TMP '||SQLERRM);
  end;
  if v_error = 'S' then
    RAISE_APPLICATION_ERROR(-20000,'Archivo contiene errores. Verifique. ');
  end if;
end prg_can_seguros;
/

