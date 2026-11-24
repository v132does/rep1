create or replace function it.fug_val_cta_credito(p_cod_per_credito ge_cta_clientes.cod_persona%type,
                                               p_nro_cta_credito ge_cta_clientes.nro_cuenta%type)
  return varchar2 is
  --
  --Función para validar la cuenta en la cual se va a realizar el crédito.
  --
  v_realcion   ge_cta_clientes.relacion%type;
  v_cod_moneda ge_cuentas.cod_moneda%type;
  v_error      varchar2(200) := null;
  v_salir exception;

BEGIN

  v_cod_moneda := fug_obt_mon_cta(p_nro_cta_credito);

  if v_cod_moneda <> pag_gen.fu_obt_mon_local then
    -- 10
    v_error := 'La moneda de la cuenta no corresponde a la de la operación. Debe ser GS.';
    raise v_salir;
  end if; 

  if p_nro_cta_credito is not null then
    v_realcion := FUG_OBT_REL_TARJETA(p_cod_per_credito, p_nro_cta_credito);
    if v_realcion <> 'P' and v_realcion <> 'O' then
      -- 11
      v_error := 'La relación debe ser Principal o Indistinta.';
      raise v_salir;
    End if;
  end if;

  return v_error;

exception

  when v_salir then
    return v_error;
END;
/

