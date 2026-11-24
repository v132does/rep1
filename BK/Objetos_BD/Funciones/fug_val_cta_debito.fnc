create or replace function it.fug_val_cta_debito(p_nro_cuenta     in varchar2,
                                                 p_cod_moneda     in ge_cuentas.cod_moneda%type,
                                                 p_cod_mod_origen in ge_cuentas.cod_modulo%type)
  return varchar2 is
  /* Función que realiza validaciones sobre una cuenta de la cual se quiere debitar operaciones,
  Recibe de parametros: El nro. de cuenta - p_nro_cuenta,
                        La moneda del cuenta - p_cod_moneda,
                        El modulo origen, modulo que registrará a la cuenta p/ el debito - p_cod_mod_origen,
                        La persona titular de la cuenta - p_cod_persona*/
  v_cod_modulo        ge_cuentas.cod_modulo%type;
  v_cod_modalidad     ge_cuentas.cod_modalidad%type;
  v_cod_sub_modalidad ge_cuentas.cod_sub_modalidad%TYPE;
  v_cod_oficina       ge_cuentas.cod_oficina%type;
  v_cod_moneda        ge_cuentas.cod_moneda%type;
  v_estado            ge_cuentas.estado%type := null;
  v_result            varchar2(1);
begin
  v_result := 'N';
  begin
    select a.cod_modulo, a.cod_modalidad, a.cod_oficina, b.cod_sub_modalidad
      into v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sub_modalidad
      from ge_cta_clientes a, ge_cuentas b
     WHERE a.nro_cuenta = b.nro_cuenta
       AND a.nro_cuenta = p_nro_cuenta
       and relacion = 'P';
  exception
    when no_data_found then
      raise_application_error(-20000,
                              'Número de Cuenta: ' || p_nro_cuenta ||
                              ' no esta registrada en la tabla ge_cta_clientes');
  end;
  if p_cod_mod_origen = 16 then
    -- Módulo de donde se realiza la consulta
    IF fug_obt_pardinamico('COD_MAD_DEB_COMBO2',v_cod_modulo,v_cod_modalidad,p_cod_moneda,v_cod_oficina,v_cod_sub_modalidad) = 'S' THEN
      begin
        select estado, cod_moneda
          into v_estado, v_cod_moneda
          from ah_cta_vistas
         where nro_cuenta = p_nro_cuenta;
      exception
        when no_data_found then
          raise_application_error(-20000,
                                  'Número de Cuenta: ' || p_nro_cuenta ||
                                  ' no esta registrada en la tabla ah_cta_vistas');
      end;
    elsif v_cod_modulo = 4 then
      begin
        select estado, cod_moneda
          into v_estado, v_cod_moneda
          from ge_cuentas
         where nro_cuenta = p_nro_cuenta;
      exception
        when no_data_found then
          raise_application_error(-20000,
                                  'Número de Cuenta: ' || p_nro_cuenta ||
                                  ' no esta registrada en la tabla ge_cuentas');
      end;
    else
      raise_application_error(-20000,
                              'Tipo de cuenta no habilitada para Débito Automático..');
    end if;
  end if;

  if nvl(v_estado, 'C') not in ('A', 'N', 'I', 'X', 'S') then
    raise_application_error(-20000,
                            'El estado de la Cuenta no es válido para el Débito Automático.');
  else
    v_result := 'S';
  end if;
  if v_cod_moneda != p_cod_moneda then
    raise_application_error(-20000,
                            'La moneda de la Cuenta (' || v_cod_moneda ||
                            ') debe ser igual a la moneda de la operación (' ||
                            p_cod_moneda || ')');
  else
    v_result := 'S';
  end if;

  return v_result;
exception
  when no_data_found then
    raise_application_error(-20000,
                            'Error al verificar el Número de Cuenta: ' ||
                            p_nro_cuenta || ' ' || sqlerrm);

end;
/

