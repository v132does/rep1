create or replace procedure it.prt_act_tar_atm (
  p_cod_persona ba_personas.cod_persona%type,
  p_respuesta varchar2,
  p_cod_canal number default null) is

  
  --v_afinidad      ta_sol_aprobadas_tmp.afinidad%type;
  --v_sub_afinidad  ta_sol_aprobadas_tmp.sub_afinidad%type;
  --v_cod_modalidad ta_sol_aprobadas_tmp.cod_modalidad%type;
  --v_nro_solicitud ta_sol_aprobadas_tmp.nro_solicitud%type;
  --v_cod_tip_doc   ta_sol_aprobadas_tmp.cod_tip_documento%type;
  v_error         ta_sol_aprobadas_tmp.det_error%type;
  v_acepta        ge_cli_aprobados_atm_tmp.acepta%type;
  --r_gcli          ge_cli_aprobados_atm%rowtype;
begin
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END; 
  if p_respuesta = '#DS#' then
    v_acepta := 'S';
  else
    v_acepta := 'N';
  end if;
    
    update ge_cli_aprobados_atm_tmp a
       set a.acepta = v_acepta,
           a.cod_canal = p_cod_canal
     where a.cod_persona = p_cod_persona
       and nvl(a.acepta,'N') != 'S' -- Para que vuelva a mostrar igual si no es aceptado.
       and a.det_error is null;
    
    /*begin
      select a.nro_documento,fue_obt_doc_principal(a.cod_persona) cod_tip_doc,a.cod_persona,a.lin_aprobada,a.cod_oficina,
             a.clase,a.afinidad,a.tip_envio,a.retener,a.nom_embozar, a.adicional,
             a.deb_automatico,a.nro_cta_debito,a.mod_pago,a.cod_tip_cierre
        into r_gcli.nro_documento,v_cod_tip_doc,r_gcli.cod_persona,r_gcli.lin_aprobada,r_gcli.cod_oficina,
             r_gcli.clase,r_gcli.afinidad,r_gcli.tip_envio,r_gcli.retener,r_gcli.nom_embozar,r_gcli.adicional,
             r_gcli.deb_automatico,r_gcli.nro_cta_debito,r_gcli.mod_pago,r_gcli.cod_tip_cierre
        from ge_cli_aprobados_atm_tmp a
       where a.cod_persona = p_cod_persona
         and a.acepta is null
         and a.det_error is null;
    exception
      when no_data_found then
        r_gcli := null;
        v_error := 'Error al buscar Cliente Pre-Aprobado';
    end;*/
    --if v_error is not null then
    
    -- Se borra previamente para que permanezca siempre el ultimo.
    delete from ge_cli_aprobados_atm a
     where cod_persona = p_cod_persona;
          
      insert into ge_cli_aprobados_atm
         (nro_documento, cod_persona, lin_aprobada, cod_oficina, clase, afinidad, tip_envio, retener, nom_embozar,
          adicional, deb_automatico, nro_cta_debito, mod_pago, cod_tip_cierre, acepta, det_error, cod_canal, cod_campana, pun_scoring, pro_mora) --CNFNORMA-195 -- Scoring IFRS9 - Fase 2    
         (select nro_documento, cod_persona, lin_aprobada, cod_oficina, clase, afinidad, tip_envio, retener, nom_embozar,
                 adicional, deb_automatico, nro_cta_debito, mod_pago, cod_tip_cierre, acepta, det_error, cod_canal, cod_campana, pun_scoring, pro_mora --CNFNORMA-195 -- Scoring IFRS9 - Fase 2 
            from ge_cli_aprobados_atm_tmp
           where cod_persona = p_cod_persona);
    --end if;

  
  
  --sacar en otro proceso
  /*begin
    select substr(val_minimo, 1, 6), substr(val_minimo, 7, 2)
      into v_afinidad, v_sub_afinidad
      from ba_cod_referencias
     where dominio = 'EQU_AFINIDAD'
       and val_maximo = r_gcli.clase--i.val_maximo
       and abreviatura = r_gcli.afinidad;--i.abreviatura;
  exception
    when no_data_found then
      v_error := nvl(v_error, '') || '#' ||
                 'Afinidad SIGRIM no definida. Verificar en dominio EQU_AFINIDAD';
  end;
  
  begin
    select distinct cod_modalidad
      into v_cod_modalidad
      from ta_tipos t
     where t.afinidad = v_afinidad
       and nvl(t.sub_afinidad, '00') = nvl(v_sub_afinidad, '00');
  exception
    when no_data_found then
      v_error := nvl(v_error, '') || '#' || 'Modalidad no registrada para la afinidad ' ||
                 v_afinidad || ' sub-afinidad ' || v_sub_afinidad;
  end;
  
  begin
    select s_nro_solicitud.nextval
      into v_nro_solicitud
      from sys.dual;
  exception
    when others then
      v_error := nvl(v_error, '') || '#' || 'Error al traer secuencia de solicitudes : ' || SQLERRM;
  end;
  
  if v_error is null then
    begin
      insert into ta_sol_aprobadas_tmp 
         (nro_documento, cod_tip_documento, monto, cod_oficina, cod_modalidad, 
          afinidad, nom_embozado,cod_tip_cierre, cod_persona, sub_afinidad, 
          nro_solicitud, abreviatura, val_maximo)
      values
         (r_gcli.nro_documento, v_cod_tip_doc, r_gcli.lin_aprobada, r_gcli.cod_oficina, v_cod_modalidad,
          v_afinidad, r_gcli.nom_embozar, r_gcli.cod_tip_cierre, r_gcli.cod_persona, v_sub_afinidad,
          v_nro_solicitud, r_gcli.afinidad, r_gcli.clase);
      prt_act_sol_aprobada(v_nro_solicitud);--genera la solicitud en estado APR
      update ge_cli_aprobados_atm_tmp a
         set a.acepta = 'S'
       where a.cod_persona = p_cod_persona
         and a.acepta is null
         and a.det_error is null;
    exception
      when others then
        v_error := 'No se pudo crear la solicitud '|| sqlerrm;
    end;
  else
    update ge_cli_aprobados_atm_tmp a
       set a.det_error = v_error
     where a.cod_persona = p_cod_persona
       and a.acepta is null
       and a.det_error is null;
  end if;*/
  
end prt_act_tar_atm;
/

