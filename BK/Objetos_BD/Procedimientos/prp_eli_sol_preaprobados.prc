create or replace procedure it.prp_eli_sol_preaprobados is
 CURSOR prestamo IS
select a.cod_pre_aprobado, a.cod_persona, a.estado, b.nro_solicitud
  from pr_pre_aprobados a, pr_solicitudes b
 where a.cod_persona = b.cod_persona
   and a.estado not in ('D', 'N')
   and b.estado not in ('A','R','D','N')
   and b.usu_insercion in ('LOANS','HBANKF')
   and b.Fec_Insercion < (sysdate - 10/1440)
   and not exists (select 1
          from pr_Cta_prestamos c
         where c.nro_solicitud = b.nro_solicitud);

begin
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  for reg in prestamo loop
    delete from pr_sol_destinos where nro_solicitud = reg.nro_solicitud;
    delete from pr_sol_gestiones where nro_solicitud = reg.nro_solicitud;
    delete from pr_sol_cargos where nro_solicitud = reg.nro_solicitud;
    delete from pr_sol_cuotas where nro_solicitud = reg.nro_solicitud;
    delete from pr_sol_destinos where nro_solicitud = reg.nro_solicitud;
    delete from pr_sol_garantias where nro_solicitud = reg.nro_solicitud;
    delete from pr_sol_tasas where nro_solicitud = reg.nro_solicitud;
    delete from ge_che_custodias where nro_referencia = reg.nro_solicitud;
    delete from pr_solicitudes a where a.Nro_Solicitud = reg.nro_solicitud;
    if reg.estado = 'V' then
      update pr_pre_aprobados
         set nro_solicitud = null
       where cod_persona = reg.cod_persona
         and cod_pre_aprobado = reg.cod_pre_aprobado;
    else
      update pr_pre_aprobados
         set estado = 'C', nro_solicitud = null
       where cod_persona = reg.cod_persona
         and cod_pre_aprobado = reg.cod_pre_aprobado;
    end if;
  commit;
  end loop;
exception
  when others then
    raise_application_error(-20000,
                            'Error en prp_eli_sol_preaprobados: ' ||
                            sqlerrm);
END;
/
