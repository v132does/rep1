create or replace function it.fug_eva_informconf(P_COD_PERSONA IN VARCHAR2) return varchar2 is
  r_inf ge_per_informes%rowtype;
  v_evaluacion varchar2(1);
begin
  v_evaluacion := 'L'; -- Empieza con Limpio.
  -- Retorna la evaluacion del InformConf
  select * into r_inf
    from ge_per_informes a
   where a.cod_persona = p_cod_persona
     and a.fecha = (Select max(fecha)
                     from ge_per_informes
                    where cod_persona = p_cod_persona);
  If r_inf.demanda = 'S' then
     If r_inf.fec_fin_demanda is not null then
        v_evaluacion := 'F';
     Else
        v_evaluacion := 'V';
     end if;
  End if;
  If r_inf.convocatoria = 'S' and nvl(v_evaluacion, 'F') = 'F' then
     If r_inf.fec_fin_convocatoria is not null then
        v_evaluacion := 'F';
     Else
        v_evaluacion := 'V';
     End if;
  End if;
  If r_inf.remate = 'S' or 
     r_inf.moroso = 'S' or 
     r_inf.inhibicion = 'S' or
     r_inf.inh_ctacte = 'S' then
     v_evaluacion := 'V';
  End if;
  Return v_evaluacion;
exception
  when no_data_found then
     return ('S');
  when others then 
     raise_application_error(-20000,'fug_eva_informconf '||sqlerrm);  
end fug_eva_informconf;
/

