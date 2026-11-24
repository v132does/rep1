create or replace procedure it.prp_ver_dat_fideicomiso is

  rp_pcpre           pr_cta_prestamos%rowtype;
  r_vcven            ov_cta_vencidas%rowtype;
  v_error            ge_log_errores.det_error%type;
  v_det_error        ge_log_errores.det_error%type;
  v_err_pro          number(30);
  v_err_msj          varchar2(4000);
  v_motivo           varchar2(1000);
  v_procesa          varchar2(1);
  v_ind_prestamo     varchar2(1) := 'N';
  v_ind_ope_vencidas varchar2(1) := 'N';
  ex_error exception;
  v_nro_cuenta pr_cta_prestamos.nro_cuenta%type;
  cursor c_tot_archivo is
    select t.nro_cuenta, t.cod_modalidad from it.ge_pas_fideicomiso_tmp t;

  procedure lp_con_modalidad(p_ind_tipo        in varchar2,
                             p_nro_cuenta      in varchar2,
                             p_cod_mod_destino number) IS
  
  v_parametro      ge_parametros.parametro%type;
  v_sub_modalidad  ge_par_dinamicos.cod_sub_modalidad%type;
  v_cod_modulo     ge_par_dinamicos.cod_modulo%type;
  BEGIN
    if p_cod_mod_destino = 676 then
      v_parametro := 'MOD_DES_FI_DDCHE';
    elsif p_cod_mod_destino = 675 then 
      v_parametro := 'MOD_DES_FI_PREST';
    elsif p_cod_mod_destino = 152 then 
      v_parametro := 'MOD_DES_FI_VEN';
    end if;
    
    if v_parametro is not null then 
      select d.cod_sub_modalidad, d.cod_modulo
       into v_sub_modalidad, v_cod_modulo
      from ge_par_dinamicos d
      where d.parametro = v_parametro
        and d.cod_modalidad = p_cod_mod_destino;
    end if;
    if p_ind_tipo = 'PRE' then
      --prestamos
      pap_pre.pr_obt_dat_prestamo(p_nro_cuenta, rp_pcpre);
      if rp_pcpre.cod_modalidad in ('660', '608') and
         --p_cod_mod_destino <> 691 then
         --descuento de cheques
         instr(fug_obt_pardinamico('MOD_DES_FI_DDCHE',v_cod_modulo,p_cod_mod_destino,null, null,v_sub_modalidad),p_cod_mod_destino)=0 then
        v_procesa    := 'N';
        v_nro_cuenta := rp_pcpre.nro_cuenta;
        v_motivo     := ' Modalidad asignada en planilla incorrecta para la cuenta '||rp_pcpre.nro_cuenta;
      elsif rp_pcpre.cod_modalidad not in ('660', '608') and
            --p_cod_mod_destino <> 690 then
            instr(fug_obt_pardinamico('MOD_DES_FI_PREST',v_cod_modulo,p_cod_mod_destino,null, null,v_sub_modalidad),p_cod_mod_destino)=0 then 
        v_procesa    := 'N';
        v_nro_cuenta := rp_pcpre.nro_cuenta;
        v_motivo     := ' Modalidad asignada en planilla incorrecta para la cuenta '||rp_pcpre.nro_cuenta;
      end if;
      if rp_pcpre.estado = 'N' then
        --DA-9335
        v_procesa    := 'N';
        v_nro_cuenta := rp_pcpre.nro_cuenta;
        v_motivo     := ' Cuenta cancelada';
      end if;
    elsif p_ind_tipo = 'OPV' then
      --operaciones vencidas
      pav_ove.pr_obt_dat_ope_vencida(p_nro_cuenta, r_vcven);
      if r_vcven.cod_modalidad = '151' and /*p_cod_mod_destino <> 152*/
        instr(fug_obt_pardinamico('MOD_DES_FI_VEN',v_cod_modulo,p_cod_mod_destino,null, null,v_sub_modalidad),p_cod_mod_destino)=0 then 
        v_procesa    := 'N';
        v_nro_cuenta := r_vcven.nro_cuenta;
        v_motivo     := ' Modalidad asignada en planilla incorrecta para la cuenta '||rp_pcpre.nro_cuenta;
      end if;
      if r_vcven.estado = 'C' then
        --DA-9335
        v_procesa    := 'N';
        v_nro_cuenta := r_vcven.nro_cuenta;
        v_motivo     := ' Cuenta cancelada';
      end if;
    end if;
  
  END lp_con_modalidad;

begin
  v_procesa := 'S';
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;

  for tot in c_tot_archivo loop
    --lee el archivo total
    begin
      --busca en pr_cta_prestamos
      select 'S'
        into v_ind_prestamo
        from pr_cta_prestamos pre
       where pre.nro_cuenta = tot.nro_cuenta;
    exception
      when no_data_found then
        -- busca en ov_cta_vencidas
        begin
          select 'S'
            into v_ind_ope_vencidas
            from ov_cta_vencidas opeven
           where opeven.nro_cuenta = tot.nro_cuenta;
        exception
          when no_data_found then
            v_procesa := 'N'; -- no procesa nada
          when others then
            v_procesa := 'N'; --algun error ya no procesa nada
        end;
      when others then
        v_procesa := 'N'; --algun error ya no procesa nada
    end;
    if v_ind_prestamo = 'S' then
      lp_con_modalidad('PRE', tot.nro_cuenta, tot.cod_modalidad);
    elsif v_ind_ope_vencidas = 'S' then
      lp_con_modalidad('OPV', tot.nro_cuenta, tot.cod_modalidad);
    end if;
    v_ind_prestamo     := 'N';
    v_ind_ope_vencidas := 'N';
  end loop;
  if v_procesa = 'S' then
    for arc in c_tot_archivo loop
      --invoca al pr_proc_pase_fideicomiso para cambio de modalidad
      it.prp_pro_pas_fideicomiso(arc.cod_modalidad,
                                arc.nro_cuenta,
                                v_err_pro,
                                v_err_msj);
      if v_err_pro <> 0 then
        v_err_pro := 10;
        v_err_msj := ' Error en proceso ' || v_err_msj;
        raise ex_error;
      end if;
    end loop;
  elsif nvl(v_procesa, 'N') = 'N' then
    v_err_pro := 11;
    v_err_msj := 'Ninguna cuenta del archivo podrá ser procesada,cuentas con inconsistencias Ej.: Nro cuenta: ' ||
                 v_nro_cuenta || ' Motivo: ' || v_motivo;
    raise ex_error;
  end if;
exception
  when ex_error then
    v_det_error := v_err_pro || ' ' || v_err_msj;
    PRG_INS_LOG_PROGRAMAS('PRP_VER_DAT_FIDEICOMISO',
                          substr(v_det_error, 1, 4000),
                          null,
                          null);
  
    raise_application_error(-20000, 'Error: ' || v_det_error);
  when others then
    v_det_error := DBMS_UTILITY.format_error_backtrace || ' ' ||
                   DBMS_UTILITY.format_error_stack;
  
    PRG_INS_LOG_PROGRAMAS('PRP_VER_DAT_FIDEICOMISO',
                          substr(v_det_error, 1, 4000),
                          null,
                          null);
    raise_application_error(-20000, 'Error: ' || v_det_error);
end prp_ver_dat_fideicomiso;
/

