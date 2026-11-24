create or replace function it.fua_val_cta_basica(p_cod_persona ba_personas.nro_documento%type default null, p_tip_consulta varchar2 default 'C') -- p_tip_consulta = 'I' si se inserta, 'C' si consulta
  return varchar2 is

  v_can_cta_sis    number(1) := 0;
  v_can_cta_bbva   number(1) := 0;
  v_can_cta_basica number(1) := 0;
  v_cta_basica     varchar2(1) := 'N';
  v_can_max_cta_basica number(3) := 0;
  v_can_insercion  number(1) := 0;
begin

  begin
    select nvl(c.cant_sis, 0)
      into v_can_cta_sis
      from ba_personas a, ba_tip_documentos b, ge_bcp_cta_basica_tmp c
     where a.cod_tip_documento = b.cod_tip_documento
       and c.tipo_ident = b.abreviatura
       and c.nrident = a.nro_documento
       and a.cod_persona = p_cod_persona;
  exception
    when no_data_found then
      v_can_cta_sis := 0;
  end;

    select count(b.nro_cuenta)
      into v_can_cta_bbva
      from ge_cta_clientes a, ah_cta_vistas b
     where a.nro_cuenta = b.nro_cuenta
       and b.cod_sub_modalidad = 26
       and a.relacion = 'P'
       and b.estado not in ('P','C')
       and a.cod_persona = p_cod_persona;

  v_can_cta_basica := v_can_cta_sis + v_can_cta_bbva;
  v_can_max_cta_basica := fug_obt_pardinamico('MAX_CAN_CTA_BASICAS', 3, 31, 'GS', null, '26');

  if nvl(p_tip_consulta, 'C') = 'I' then
     v_can_insercion := 1;
  else
     v_can_insercion := 0;
  end if;
  if nvl(v_can_cta_basica, 0) + nvl(v_can_insercion,0) <= nvl(v_can_max_cta_basica,0) and
     ((nvl(v_can_cta_bbva, 0) = 0 and  v_can_insercion = 1) or v_can_insercion = 0) then --se le suma 1 por la cuenta que se est� insertando
     v_cta_basica := 'S';
  end if;

  return v_cta_basica;
end;
/

