create or replace procedure it.prp_act_est_pre_che_roga(p_nro_oferta pr_pre_che_roga.nro_oferta%type,
                                                        p_cod_error  out number,
                                                        p_mensaje    out varchar2) is

  v_cod_error  number;
  v_det_error  varchar2(4000);
  v_lugar      varchar2(4000);
  v_exi_oferta varchar2(1); 

begin
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  if p_nro_oferta is null then
    v_cod_error := 99;
    v_det_error := 'Número de oferta no puede ser nulo.!';
    p_cod_error := v_cod_error;
    p_mensaje   := v_det_error;
    return;
  end if;
  -- valida que nro_oferta sea valida
  begin
    select 'S'
      into v_exi_oferta
      from pr_pre_che_roga
     where nro_oferta = p_nro_oferta;
  exception
    when no_data_found then
      v_exi_oferta := 'N';
      v_cod_error  := 99;
    when others then
      v_cod_error := 99;
      raise_application_error(-20000, 'En PR_PRE_CHE_ROGA ' || SQLERRM);
  end;
  if nvl(v_exi_oferta, 'N') = 'S' then
  
    update pr_pre_che_roga s
       set s.inv_acepto = 'S'
     where s.nro_oferta = p_nro_oferta;
    if sql%notfound then
      v_cod_error := 99;
      v_lugar     := 'Actualiza Aceptación de Invitado.';
      v_det_error := sqlerrm;
      it.prg_ins_log_programas('PRP_ACT_EST_PRE_CHE_ROGA',
                               v_lugar || ' - ' || v_det_error,
                               null,
                               null);
    end if;
  
    if nvl(v_cod_error, 0) = 0 then
      p_cod_error := 0;
      p_mensaje   := 'Procesado exitosamente.!';
      commit;
    else
      p_cod_error := v_cod_error;
      p_mensaje   := 'No procesado.!';
      rollback;
    end if;
  
  else
    v_lugar     := 'Valida Numero de Oferta.';
    v_det_error := 'Numero de oferta no existe. ' || sqlerrm;
    it.prg_ins_log_programas('PRP_ACT_EST_PRE_CHE_ROGA',
                             v_lugar || ' - ' || v_det_error,
                             null,
                             null);
    p_cod_error := v_cod_error;
    p_mensaje   := 'Numero de Oferta no existe.!';
  end if;

exception
  when others then
    v_lugar     := 'When others del proceso prp_act_est_pre_che_roga.';
    v_det_error := sqlerrm;
    it.prg_ins_log_programas('PRP_ACT_EST_PRE_CHE_ROGA',
                             v_lugar || ' - ' || v_det_error,
                             null,
                             null);
  
end;
/
