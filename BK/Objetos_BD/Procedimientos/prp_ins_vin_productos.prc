create or replace procedure it.PRP_INS_VIN_PRODUCTOS(p_nro_linea  in pr_lineas.nro_linea%type,
                                                  p_nro_cuenta in ge_cuentas.nro_cuenta%type,
                                                  p_motivo     in varchar2 default null) is
  -- CRO-JM-07/2015: CROALCVC-1 Insercion histórico de Asociaciones de límites de crédito:
  v_cod_motivo   varchar2(3);
  v_cod_persona  pr_lin_vin_productos_his.cod_persona%type;
  v_cod_moneda   varchar2(3);
  v_mto_aplicado number;
  v_mto_limite   number;

  function fu_ver_productos(p_nro_linea   in pr_lineas.nro_linea%type, -- verificamos que no esté insertado en la tabla de histórico de Asociaciones de Límites
                            p_nro_cuenta  in ge_cuentas.nro_cuenta%type,
                            p_cod_persona in pr_lineas.cod_persona%type,
                            p_cod_motivo  in varchar2 default null)
    return boolean is
    v_existe varchar2(1);
  begin
    begin
      select 'S'
        into v_existe
        from pr_lin_vin_productos_his a
       where a.nro_linea = p_nro_linea
         and a.nro_cuenta = p_nro_cuenta
         and a.cod_persona = p_cod_persona
         and a.cod_motivo = p_cod_motivo;
    exception
      when others then
        v_existe := 'N';
    end;
    if v_existe = 'S' then
      return(true);
    else
      return(false);
    end if;
  end fu_ver_productos;

  function fu_val_cuenta(p_nro_cuenta in pr_lin_vin_productos_his.nro_cuenta%type)
    return boolean is
    v_cta_existente varchar2(1);
  begin
    begin
      --pregunta si existe la cuenta
      select 'S'
        into v_cta_existente
        from ge_cta_clientes a
       where a.nro_cuenta = p_nro_cuenta
         and a.relacion = 'P';
    exception
      when others then
        v_cta_existente := 'N';
    end;
    if v_cta_existente = 'S' then
      return(true);
    else
      return(false);
    end if;
  end fu_val_cuenta;

begin
  if nvl(pae_cnf.G_PROGRAMA, 'X') = ('GPPROFIN') then
    v_cod_motivo := '01'; --caso 1
  else
    if p_motivo = 'C' then
      v_cod_motivo := '03'; --caso 3
    elsif p_motivo = 'A' then
      v_cod_motivo := '02'; --caso 2
    end if;
  end if;
  begin
    select a.cod_persona, a.cod_moneda, a.monto, a.mto_aplicado
      into v_cod_persona, v_cod_moneda, v_mto_limite, v_mto_aplicado
      from pr_lineas a
     where a.nro_linea = p_nro_linea;
  exception
    when no_data_found then
      dbms_output.put_line('No se ha encontrado codigo persona! ');
    when others then
      dbms_output.put_line('Error al buscar codigo persona! ' || sqlerrm);
  end;

  if not fu_ver_productos(p_nro_linea,
                          p_nro_cuenta,
                          v_cod_persona,
                          v_cod_motivo) and fu_val_cuenta(p_nro_cuenta) then
    insert into pr_lin_vin_productos_his
      (nro_linea,
       cod_persona,
       nro_cuenta,
       cod_moneda,
       mto_aplicado,
       mto_limite,
       hora,
       fecha,
       cod_usuario,
       cod_motivo)
    values
      (p_nro_linea,
       v_cod_persona,
       p_nro_cuenta,
       v_cod_moneda,
       v_mto_aplicado,
       v_mto_limite,
       to_char(sysdate, 'HH24:MI:SS'),
       trunc(sysdate),
       user,
       v_cod_motivo);
  end if;
Exception
  when others then
    dbms_output.put_line('Error al insertar asociacion de límite/producto! ' ||
                         sqlerrm);
end prp_ins_vin_productos;
--
/

