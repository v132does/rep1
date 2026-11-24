CREATE OR REPLACE TRIGGER IT.TB_BW_TIP_MENSAJES
 BEFORE DELETE OR UPDATE
     ON BW_TIP_MENSAJES
    FOR EACH ROW
DECLARE
  v_cantidad number(5);
BEGIN
  -- Consulta
  if nvl(:new.consulta,'N') = 'N'and
     nvl(:old.consulta,'S') = 'S' then
    begin
      select count(*)
        into v_cantidad
        from bw_rol_permisos p
       where p.cod_tip_mensaje = :new.cod_tip_mensaje
         and p.consulta = 'S';
    exception
      when others then
        v_cantidad := 0;
    end;
    if v_cantidad > 0 then
      raise_application_error (-20000,'El mensaje '||:new.cod_tip_mensaje||' está definido en Permisos por Perfil.');
    end if;
  end if;
  -- Ingresa
  if nvl(:new.ingresa,'N') = 'N'and
     nvl(:old.ingresa,'S') = 'S' then
    begin
      select count(*)
        into v_cantidad
        from bw_rol_permisos p
       where p.cod_tip_mensaje = :new.cod_tip_mensaje
         and p.ingresa = 'S';
    exception
      when others then
        v_cantidad := 0;
    end;
    if v_cantidad > 0 then
      raise_application_error (-20000,'El mensaje '||:new.cod_tip_mensaje||' está definido en Permisos por Perfil.');
    end if;
  end if;
  -- Autoriza
  if nvl(:new.autoriza,'N') = 'N'and
     nvl(:old.autoriza,'S') = 'S' then
    begin
      select count(*)
        into v_cantidad
        from bw_rol_permisos p
       where p.cod_tip_mensaje = :new.cod_tip_mensaje
         and p.autoriza = 'S';
    exception
      when others then
        v_cantidad := 0;
    end;
    if v_cantidad > 0 then
      raise_application_error (-20000,'El mensaje '||:new.cod_tip_mensaje||' está definido en Permisos por Perfil.');
    end if;
  end if;
END;
/

