CREATE OR REPLACE TRIGGER IT.TB_BW_PERFILES
 BEFORE DELETE OR UPDATE
     ON BW_PERFILES
    FOR EACH ROW
DECLARE
    v_cantidad number(5);
BEGIN
  if nvl(:new.afe_per_fisica,'N') = 'N' and
     nvl(:old.afe_per_fisica,'S') = 'S' then
    begin
      select count(*)
        into v_cantidad
        from ge_clientes
       where cod_perfil = :new.cod_perfil;
    exception
      when others then
        v_cantidad := 0;
    end;
    if v_cantidad > 0 then
      raise_application_error(-20000,'El perfil tiene personas físicas asociadas.');
    end if;
  end if;
END;
/

