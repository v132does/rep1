create or replace procedure it.prg_cli_onboarding(p_nro_documento in varchar2,
                                                  p_doc_persona   out varchar2,
                                                  p_pro_activo    out varchar2,
                                                  p_onboarding    out varchar2) is
begin

  select decode(count(*), 0, 'N', 'S')
    into p_doc_persona
    from ba_personas p, ba_per_fisicas f
   where p.nro_documento = p_nro_documento
    and p.cod_persona=f.cod_persona;

  select decode(count(*), 0, 'N', 'S')
    into p_pro_activo
    from ge_cta_clientes c, ba_personas p, ba_per_fisicas f
   where c.cod_persona = p.cod_persona
     and p.nro_documento = p_nro_documento
   and c.relacion = 'P'
     and ((c.cod_modalidad = 334 and c.usu_insercion != 'APITRANSAC') or
         c.cod_modalidad != 334)
     and fug_obt_can_cta_activa(c.cod_persona) != 0
    and p.cod_persona=f.cod_persona;

  select decode(count(*), 0, 'N', 'S')
    into p_onboarding
    from ba_personas ba
   where ba.nro_documento = p_nro_documento
     and fue_tab_dat_adicional('GE_CLIENTES',
                               'GEN_COD_USU_PLATAFORMA',
                               ba.cod_persona) is not null;

exception
  when others then
    raise_application_error(-20000, 'PRG_CLI_ONBOARDING ' || sqlerrm);
end prg_cli_onboarding;
/

