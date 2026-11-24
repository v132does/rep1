create or replace procedure it.prp_eli_dat_preaprobado (p_cod_persona pr_solicitudes.cod_persona%type) is

  Cursor pre_aprobados is
    select s.nro_solicitud
       from pr_solicitudes s
     where s.cod_persona = p_cod_persona
      and estado in( 'S','L')
      and exists (Select 1 from pr_pre_aprobados p
                  where p.cod_persona = s.cod_persona
                    and p.nro_solicitud = s.nro_solicitud
                    and instr(fug_obt_pardinamico('EST_ACT_PREAPROBADO'),p.estado) > 0)
      and not exists (select 1
                         from pr_cta_prestamos x
                       where x.nro_solicitud = s.nro_solicitud);
Begin
 For c in pre_aprobados Loop
    --Borrar la solicitud de los pre-aprobados que ya se genero
    Delete from pr_sol_destinos
     where nro_Solicitud = c.nro_solicitud;

    Delete from pr_sol_gestiones
     where nro_Solicitud = c.nro_solicitud;

    Delete from pr_sol_cargos
     where nro_Solicitud = c.nro_solicitud;

    Delete from pr_sol_cuotas
     where nro_Solicitud = c.nro_solicitud;

    Delete from pr_sol_destinos
     where nro_solicitud = c.nro_solicitud;

    Delete from pr_sol_garantias
     where nro_solicitud = c.nro_solicitud;

    Delete from pr_sol_tasas
     where nro_solicitud = c.nro_solicitud;

    Delete from ge_che_custodias
     where nro_referencia = c.nro_solicitud;

    Delete from pr_solicitudes a
     where nro_solicitud = c.nro_solicitud;

    Update pr_pre_aprobados p
       set p.nro_solicitud = null
     where p.cod_persona = p_cod_persona
       and p.nro_solicitud = c.nro_solicitud
       and instr(fug_obt_pardinamico('EST_ACT_PREAPROBADO'), p.estado) > 0;

 End Loop;

end prp_eli_dat_preaprobado;
/

