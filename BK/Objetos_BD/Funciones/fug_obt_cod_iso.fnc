create or replace function it.FUG_OBT_COD_ISO(p_cod_moneda in ba_monedas.cod_moneda%TYPE) return varchar2 IS
v_cod_mon_iso ba_monedas.cod_mon_iso%type;
--Función que devuelve el código de la moneda según la norma ISO 4027
BEGIN
  begin
    select a.cod_mon_iso
      into v_cod_mon_iso
      from ba_cod_referencias t, ba_monedas a
     where t.dominio = 'COD_ISO_PAI_MON'
       and a.cod_moneda = t.val_maximo
       and a.cod_moneda = p_cod_moneda;
    return v_cod_mon_iso;
  exception
    when others then
      raise_application_error(-20000,'Error al obtener el código ISO 4027 de la moneda '||to_char(p_cod_moneda));
  end;
END;
/

