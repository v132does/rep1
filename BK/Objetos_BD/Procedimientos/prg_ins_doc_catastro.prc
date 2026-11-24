create or replace procedure it.prg_ins_doc_catastro(p_cod_persona ba_personas.cod_persona%type,
                                                 p_nro_cuenta  ge_cta_clientes.nro_cuenta%type default null) is
  v_existe varchar2(1);

begin

  begin
    select 'S'
      into v_existe
      from ge_doc_catastros
     where cod_persona = p_cod_persona
       and nvl(nro_cuenta, 0) = nvl(p_nro_cuenta, 0);
  exception
    when no_data_found then
      null;
    when others then
      null;
  end;
  ---En estas condiciones se valida al cliente y la cuenta: 1-Si no corresponde a Nómina, 
  ---2- Que no este registrado en Catastros, 3- Que no sea funcionario del Banco
  ---CROOC-6 - Ajustes Oficina de Catastros - LC-Septiembre/2014
  if FUG_ES_CLI_NOMINA(p_cod_persona, p_nro_cuenta) = 'N' and
     nvl(v_existe, 'N') = 'N' and
     FUG_ES_EMPLEADO(p_cod_persona)  = 'N' then
    begin
      insert into ge_doc_catastros
        (cod_doc_catastro,
         cod_persona,
         nro_cuenta,
         cod_tip_documento,
         nro_documento,
         fec_vto_documento,
         observacion,
         estado)
      values
        (s_cod_doc_catastro.nextval,
         p_cod_persona,
         p_nro_cuenta,
         'C',
         null,
         null,
         null,
         'N');
    exception
      when others then
        raise_application_error(-20002, 'Error prg_ins_doc_catastro ' || SQLERRM);
    end;
  end if;
end;
/

