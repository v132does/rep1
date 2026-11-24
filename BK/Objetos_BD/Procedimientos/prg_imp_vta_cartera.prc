create or replace procedure it.prg_imp_vta_cartera is
  v_existe_reten  number default 0; --existe retencion
  v_existe_ruc    number default 0; --existe ruc del comprador
  v_existe_monto  number default 0; --existe monto de venta
  v_existe_ente   number default 0; --existe ente
  v_procesado     varchar2(30);
  v_control       number;
  v_persona_ente  ge_entes.cod_persona%type := null;
  v_ruc_comprador ge_inv_vta_cartera_tmp.ruc_comprador%type;
  v_nom_comprador ba_personas.nom_completo%type;
  v_monto_venta   ge_inv_vta_cartera_tmp.monto%type;
  v_cod_ente      ge_inv_vta_cartera_tmp.cod_ente%type;
  v_nro_lote      ge_fil_vta_cartera.ref_lote%type;
  v_cant_modulo   number default 0;
  v_modulo        varchar2(5);
  v_verifica_ente ge_inv_vta_cartera_tmp.cod_ente%type;

begin
  -- verificamos si la cuenta tiene retención
  select count(*)
    into v_existe_reten
    from ge_inv_vta_cartera_tmp a
   where a.nro_cuenta in (select b.nro_cuenta
                            from ah_retenciones b
                           where b.fec_final >= sysdate); --fecha de fin de retencion mayor o igual a la fecha

  if v_existe_reten <> 0 then
    raise_application_error(-20000,
                            'Dentro de la cartera existe/en ' ||
                            v_existe_reten ||
                            ' cuenta/as con retencion, favor gestionar antes de continuar.');
  end if;

  -- verificamos que todos tengan ruc del comprador
  select count(*)
    into v_existe_ruc
    from ge_inv_vta_cartera_tmp a
   where a.ruc_comprador is not null;

  if v_existe_ruc = 0 then
    raise_application_error(-20000,
                            'No existe el RUC del comprador, favor gestionar antes de continuar.');
  end if;

  -- verificamos que todos tengan monto de venta
  select count(*)
    into v_existe_monto
    from ge_inv_vta_cartera_tmp a
   where a.monto is not null;

  if v_existe_monto = 0 then
    raise_application_error(-20000,
                            'No existe el monto de venta de cartera, favor gestionar antes de continuar.');
  end if;

  -- verificamos que todos tengan ente
  select count(*)
    into v_existe_ente
    from ge_inv_vta_cartera_tmp a
   where a.cod_ente is not null;

  if v_existe_ente = 0 then
    raise_application_error(-20000,
                            'No existe el Ente, favor gestionar antes de continuar.');
  end if;
  
  -- verificamos que todos tengan ente
begin  
  select distinct(cod_modulo)
    into v_cant_modulo
    from ge_inv_vta_cartera_tmp a;
 exception
   when too_many_rows then
    raise_application_error(-20000,
                            'Existen más de un módulo. Favor realizar por separado.');
   when others then
    raise_application_error(-20000,
                            'Error al consultar el modulo del archivo.');                          
 end;  

  -- verificamos los datos obligatorios
  begin
    select a.ruc_comprador, a.monto, a.cod_ente, '#'||a.cod_modulo
      into v_ruc_comprador, v_monto_venta, v_cod_ente, v_modulo
      from ge_inv_vta_cartera_tmp a
     where a.ruc_comprador is not null
       and a.monto is not null
       and a.cod_ente is not null
       and rownum = 1
     fetch first 1 rows only;
  exception
    when others then
      raise_application_error(-20000,
                              'Error en consultar datos de la venta de cartera. ' ||
                              sqlerrm);
  end;

  --verificamos si el comprador pertenece a un ente
  begin
    select g.cod_persona, b.nom_completo, g.cod_ente
      into v_persona_ente, v_nom_comprador, v_verifica_ente
      from ge_entes g, ba_personas b
     where g.cod_persona = b.cod_persona
       and g.tipo = 'DC'
       and b.nro_documento = v_ruc_comprador
       and rownum = 1;
  exception
    when others then
      v_persona_ente := null;
  end;

  if v_persona_ente is null then
    raise_application_error(-20000,
                            'Persona no pertenece a ningún ente. ' ||
                            sqlerrm);
  end if;
  
  if v_verifica_ente <> v_cod_ente then
    raise_application_error(-20000,
                            'Código Ente de importación ' ||v_cod_ente|| ' no pertenece al comprador. Ente '||v_verifica_ente||' '||
                            sqlerrm);   
  end if;
  
  --verificamos el lote
  -- Consultamos el numero de referencia de lote
Begin
 select max(ref_lote)
   into v_nro_lote
    from ge_fil_vta_cartera a
    where a.prevision is null
    and   a.nomina is null
    and   a.dia_desde is null
    and   a.dia_hasta is null;
  exception
    when others then
      v_nro_lote := null;
  end;    

  --generamos la venta 
  begin
    prg_gen_inv_vta_cartera(null,
                            null,
                            null,
                            null,
                            null,
                            null,
                            null,
                            null,
                            null,
                            v_modulo,
                            null,
                            v_nro_lote,
                            v_control,
                            null,
                            'P');
    commit;
  exception
    when others then
      raise_application_error(-20000, 'Error ' || sqlerrm);
  end;

  if v_control <= 0 then
    raise_application_error(-20000,
                            'No se generó la cartera, 0 registros. Favor verificar. '||v_control);
  end if;
  -- Consultamos el numero de referencia de lote
Begin 
 select max(ref_lote)
   into v_nro_lote
    from ge_fil_vta_cartera a
    where a.prevision is null
    and   a.nomina is null
    and   a.dia_desde is null
    and   a.dia_hasta is null;
  exception
    when others then
      raise_application_error(-20000, 'Error al consulta el último lote' || sqlerrm);
  end;
  --proceso para terminar el proceso de venta de cartera
  begin
    --se confirma la venta de la cartera
    prg_con_vta_cartera(v_ruc_comprador,
                        v_nom_comprador,
                        v_monto_venta,
                        v_nro_lote,
                        v_procesado,
                        v_cod_ente);
    if v_procesado <> 'OK' then
       raise_application_error(-20000, 'Ocurrio un Error ' || sqlerrm);                      
    end if;
  exception
    when others then
      raise_application_error(-20000, 'Error ' || sqlerrm);
  end;
end;
/

