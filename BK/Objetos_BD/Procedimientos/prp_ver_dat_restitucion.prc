create or replace procedure it.prp_ver_dat_restitucion is

  rp_pcpre           pr_cta_prestamos%rowtype;
  r_vcven            ov_cta_vencidas%rowtype;
  v_det_error        ge_log_errores.det_error%type;
  v_err_pro          number(30);
  v_err_msj          varchar2(4000);
  v_procesa          varchar2(1);
  v_ind_prestamo     varchar2(1) := 'N';
  v_ind_ope_vencidas varchar2(1) := 'N';
  ex_error exception;
  v_nro_cuenta       pr_cta_prestamos.nro_cuenta%type;
  v_modalidad        pr_cta_prestamos.cod_modalidad%type;
  cursor c_tot_archivo is
    select t.nro_cuenta from it.ge_restitucion_tmp t;

  procedure lp_con_modalidad(p_ind_tipo        in varchar2,
                             p_nro_cuenta      in varchar2) IS

  v_parametro      ge_parametros.parametro%type;
  v_sub_modalidad  ge_par_dinamicos.cod_sub_modalidad%type;
  v_cod_modulo     ge_par_dinamicos.cod_modulo%type;
  BEGIN
    if p_ind_tipo = 'PRE' then
      --prestamos
      pap_pre.pr_obt_dat_prestamo(p_nro_cuenta, rp_pcpre);
      if rp_pcpre.cod_modalidad = 676 then
        v_parametro := 'MOD_DES_FI_DDCHE';
      elsif rp_pcpre.cod_modalidad = 675 then 
        v_parametro := 'MOD_DES_FI_PREST'; 
      end if;
      if v_parametro is not null then 
        select d.cod_sub_modalidad, d.cod_modulo
         into v_sub_modalidad, v_cod_modulo
        from ge_par_dinamicos d
        where d.parametro = v_parametro
          and d.cod_modalidad = rp_pcpre.cod_modalidad;
      end if;  
      --if rp_pcpre.cod_modalidad not in  ('690', '691') then
      if instr(fug_obt_pardinamico('MOD_DES_FI_DDCHE',v_cod_modulo,rp_pcpre.cod_modalidad,null, null,v_sub_modalidad),rp_pcpre.cod_modalidad)=0 and
        instr(fug_obt_pardinamico('MOD_DES_FI_PREST',v_cod_modulo,rp_pcpre.cod_modalidad,null, null,v_sub_modalidad),rp_pcpre.cod_modalidad)=0 then
        v_procesa := 'N';
        v_nro_cuenta:=rp_pcpre.nro_cuenta;
      end if;
      if rp_pcpre.estado='N' then--DA-9335
        v_procesa := 'N';
        v_nro_cuenta:=rp_pcpre.nro_cuenta;
      end if;
    elsif p_ind_tipo = 'OPV' then
      --operaciones vencidas
      pav_ove.pr_obt_dat_ope_vencida(p_nro_cuenta, r_vcven);
      if rp_pcpre.cod_modalidad = 152 then 
         v_parametro := 'MOD_DES_FI_VEN';
      end if; 
      if v_parametro is not null then 
        select d.cod_sub_modalidad, d.cod_modulo
         into v_sub_modalidad, v_cod_modulo
        from ge_par_dinamicos d
        where d.parametro = v_parametro
          and d.cod_modalidad = rp_pcpre.cod_modalidad;
      end if; 
      --if r_vcven.cod_modalidad <> '152'  then
      if instr(fug_obt_pardinamico('MOD_DES_FI_VEN',v_cod_modulo,rp_pcpre.cod_modalidad,null, null,v_sub_modalidad),rp_pcpre.cod_modalidad)=0 then
        v_procesa := 'N';
        v_nro_cuenta:=r_vcven.nro_cuenta;
      end if;
       if r_vcven.estado='C' then--DA-9335
        v_procesa := 'N';
        v_nro_cuenta:=r_vcven.nro_cuenta;
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
      lp_con_modalidad('PRE', tot.nro_cuenta);
    elsif v_ind_ope_vencidas = 'S' then
      lp_con_modalidad('OPV', tot.nro_cuenta);
    end if;
    v_ind_prestamo:='N';
    v_ind_ope_vencidas:='N';
  end loop;
  if v_procesa = 'S' then
    for arc in c_tot_archivo loop
      --busca modalidad origen
      v_modalidad:=to_number(fug_obt_paradicional(arc.nro_cuenta,
                                     'MOD_CAM_MOD_DESTINO'));
     if v_modalidad is not null then
      --invoca al pr_pro_restitucion para cambio de modalidad
      prp_pro_restitucion(v_modalidad,
                  arc.nro_cuenta,
                        v_err_pro,
                        v_err_msj);

      if v_err_pro <> 0 then
        raise ex_error;
      else
        --borra modalidad origen guardada DA-9248
            delete ge_cta_dat_adicionales
             where nro_cuenta = arc.nro_cuenta
               and parametro = 'MOD_CAM_MOD_DESTINO';
               
            delete ge_cta_dat_adicionales
             where nro_cuenta = arc.nro_cuenta
               and parametro = 'SUB_CAM_MOD_DESTINO';   
      end if;
      else
         v_err_pro := 11;
         v_err_msj := 'La cuenta  '||arc.nro_cuenta||' no tiene el parametro de modalidad definido';
         raise ex_error;
      end if;
    end loop;
  elsif nvl(v_procesa, 'N') = 'N' then
    v_err_pro := 10;
    v_err_msj := 'Ninguna cuenta del archivo podrá ser procesada, cuentas con inconsistencias Ej.: Nro cuenta: '||v_nro_cuenta;
    raise ex_error;
  end if;
exception
  when ex_error then
    v_det_error := v_err_pro || ' ' || v_err_msj;
    PRG_INS_LOG_PROGRAMAS('PRP_VER_DAT_RESTITUCION',
                          substr(v_det_error, 1, 4000),
                          null,
                          null);

    raise_application_error(-20000, 'Error: ' || v_det_error);
  when others then
    v_det_error := DBMS_UTILITY.format_error_backtrace || ' ' ||
                   DBMS_UTILITY.format_error_stack;

    PRG_INS_LOG_PROGRAMAS('PRP_VER_DAT_RESTITUCION',
                          substr(v_det_error, 1, 4000),
                          null,
                          null);
end prp_ver_dat_restitucion;
/

