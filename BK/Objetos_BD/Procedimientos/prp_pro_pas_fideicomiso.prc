create or replace procedure it.prp_pro_pas_fideicomiso(p_cod_mod_destino in number,
                                                      p_nro_cuenta      in varchar2,
                                                      p_error           out varchar2,
                                                      p_men_error       out varchar2) is

  v_error            ge_log_errores.det_error%type;
  v_det_error        ge_log_errores.det_error%type;
  v_men_error        varchar2(4000);
  v_ind_prestamo     varchar2(1) := 'N';
  v_ind_ope_vencidas varchar2(1) := 'N';
  v_secuencia ge_movimientos.nro_secuencia%type:=0;
  v_horamovim ge_movimientos.hora%type:=null;
  rp_pcpre           pr_cta_prestamos%rowtype;
  r_vcven            ov_cta_vencidas%rowtype; 
  v_existe           varchar2(1):='N';
  ex_error exception;
  v_parametro        ge_parametros.parametro%type;
  v_sub_modalidad    varchar2(10) ;

begin

  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  p_error := 0;
  ---
  begin
    --busca en pr_cta_prestamos
    select 'S'
      into v_ind_prestamo
      from pr_cta_prestamos pre
     where pre.nro_cuenta = p_nro_cuenta;
  exception
    when no_data_found then
      v_ind_prestamo := 'N';
      -- busca en ov_cta_vencidas
      begin
        select 'S'
          into v_ind_ope_vencidas
          from ov_cta_vencidas opeven
         where opeven.nro_cuenta = p_nro_cuenta;
      exception
        when no_data_found then
          v_ind_ope_vencidas := 'N'; --no es operacion vencida
        when others then
          v_ind_ope_vencidas := 'N'; --algun error no es operacion vencida
      end;
    when others then
      v_ind_prestamo := 'N'; --algun error no es prestamo
  end;
  ---
  begin
	select 'S'
	  into v_existe
	  from ge_parametros
	 where parametro = 'MOD_CAM_MOD_DESTINO';
  exception
	when no_data_found then
	  p_error     := 115;
	  p_men_error := 'El parametro MOD_CAM_MOD_DESTINO no existe, configure!';
	  raise ex_error;
  end; 
  if v_ind_prestamo = 'S' then
    declare
      ex_insert_excep exception;
    begin
      
        pap_pre.pr_obt_dat_prestamo(p_nro_cuenta, rp_pcpre);
        --- Almacenar en el parámetro de la cuenta la modalidad Original
        insert into ge_cta_dat_adicionales
          (nro_cuenta, parametro, val_parametro)
        values
          (p_nro_cuenta, 'MOD_CAM_MOD_DESTINO', to_char(rp_pcpre.cod_modalidad));
          
        insert into ge_cta_dat_adicionales
          (nro_cuenta, parametro, val_parametro)
        values
          (p_nro_cuenta, 'SUB_CAM_MOD_DESTINO', to_char(rp_pcpre.cod_sub_modalidad));  
    exception
      when ex_insert_excep then
        p_error     := 101;
        p_men_error := substr('Error al insertar ge_cta_dat_adicionales ' ||
                              sqlerrm,
                              1,
                              4000);
        raise ex_error;
    end;
    
    if p_cod_mod_destino = 676 then
      v_parametro := 'MOD_DES_FI_DDCHE';
    elsif p_cod_mod_destino = 675 then 
      v_parametro := 'MOD_DES_FI_PREST';
    elsif p_cod_mod_destino = 152 then 
      v_parametro := 'MOD_DES_FI_VEN';
    end if;
    
    if v_parametro is not null then 
      select d.cod_sub_modalidad
       into v_sub_modalidad 
      from ge_par_dinamicos d
      where d.parametro = v_parametro
        and d.cod_modalidad = p_cod_mod_destino;
    end if;
      
    --Actualiza estructuras de tabla con el cambio de modalidad 
    --ge_cuentas
    begin
      update ge_cuentas
         set cod_modalidad = p_cod_mod_destino,
             cod_sub_modalidad = v_sub_modalidad
       where nro_cuenta = p_nro_cuenta;
    exception
      when others then
        p_error     := 102;
        p_men_error := substr('Error al actualizar tabla ge_cuentas ' ||
                              sqlerrm,
                              1,
                              4000);
      
    end;
    --ge_cta_Clientes
    begin
      update ge_cta_Clientes
         set cod_modalidad = p_cod_mod_destino
       where nro_cuenta = p_nro_cuenta
       and relacion='P';--DA-9104
    exception
      when others then
        p_error     := 103;
        p_men_error := substr('Error al actualizar tabla ge_cta_Clientes ' ||
                              sqlerrm,
                              1,
                              4000);
    end;
    --pr_cta_prestamos
    begin
      update pr_cta_prestamos
         set cod_modalidad = p_cod_mod_destino,
             cod_sub_modalidad = v_sub_modalidad
       where nro_cuenta = p_nro_cuenta;
    exception
      when others then
        p_error     := 104;
        p_men_error := substr('Error al actualizar tabla pr_cta_prestamos ' ||
                              sqlerrm,
                              1,
                              4000);
    end;
    --pr_sal_mensuales
    begin
      update pr_sal_mensuales
         set cod_modalidad = p_cod_mod_destino
       where nro_cuenta = p_nro_cuenta;
    exception
      when others then
        p_error     := 105;
        p_men_error := substr('Error al actualizar tabla pr_sal_mensuales ' ||
                              sqlerrm,
                              1,
                              4000);
    end;
    --ge_movimientos
    begin
      update ge_movimientos
         set cod_modalidad = p_cod_mod_destino
       where nro_cuenta = p_nro_cuenta;
    exception
      when others then
        p_error     := 106;
        p_men_error := substr('Error al actualizar tabla ge_movimientos ' ||
                              sqlerrm,
                              1,
                              4000);
    end;
    
    if p_error =0 then
       if v_horamovim is null then
           if v_secuencia + 3 > 999 then
              --v_secuencia := 0;
              v_horamovim := pag_gen.FU_OBT_SIG_SEGUNDO(v_horamovim);
            ELSE
              --v_secuencia := v_secuencia + 1;
              v_horamovim          := fug_obt_mov_hora;
           end if;
       end if; 
         
          --si no hay errores, genera movimientos de pase a fideicomiso
          prp_gen_asi_fideicomiso('FID',p_nro_cuenta,rp_pcpre.cod_modulo,v_horamovim,p_cod_mod_destino,p_error,p_men_error);
   
  end if;
  elsif v_ind_ope_vencidas = 'S' then
   
    declare
      ex_insert_excep exception;
    begin
        pav_ove.pr_obt_dat_ope_vencida(p_nro_cuenta, r_vcven);
      --- Almacenar en el parámetro de la cuenta la modalidad Original
      insert into ge_cta_dat_adicionales
        (nro_cuenta, parametro, val_parametro)
      values
        (p_nro_cuenta, 'MOD_CAM_MOD_DESTINO', to_char(r_vcven.cod_modalidad));
    exception
      when others then
        p_error     := 107;
        p_men_error := substr('Error al insertar ge_cta_dat_adicionales ' ||
                              sqlerrm,
                              1,
                              4000);
        raise ex_error;
    end;
    --ov_cta_vencidas
    begin
      update ov_cta_vencidas
         set cod_modalidad = p_cod_mod_destino
       where nro_cuenta = p_nro_cuenta;
    exception
      when others then
        p_error     := 108;
        p_men_error := substr('Error al actualizar tabla ov_cta_vencidas ' ||
                              sqlerrm,
                              1,
                              4000);
        raise ex_error;
    end;
    --ge_cuentas
    begin
      update ge_cuentas
         set cod_modalidad = p_cod_mod_destino
       where nro_cuenta = p_nro_cuenta;
    exception
      when others then
        p_error     := 109;
        p_men_error := substr('Error al actualizar tabla ge_cuentas ' ||
                              sqlerrm,
                              1,
                              4000);
         raise ex_error;
    end;
    --ge_Cta_clientes
    begin
      update ge_Cta_clientes
         set cod_modalidad = p_cod_mod_destino
       where nro_cuenta = p_nro_cuenta
       and relacion='P';
    exception
      when others then
        p_error     := 110;
        p_men_error := substr('Error al actualizar tabla ge_Cta_clientes ' ||
                              sqlerrm,
                              1,
                              4000);
         raise ex_error;
    end;
    --ov_sal_mensuales
    begin
      update ov_sal_mensuales
         set cod_modalidad = p_cod_mod_destino
       where nro_cuenta = p_nro_cuenta;
    exception
      when others then
        p_error     := 111;
        p_men_error := substr('Error al actualizar tabla ov_sal_mensuales ' ||
                              sqlerrm,
                              1,
                              4000);
         raise ex_error;
    end;
    --ge_movimientos
    begin
      update ge_movimientos
         set cod_modalidad = p_cod_mod_destino
       where nro_cuenta = p_nro_cuenta;
    exception
      when others then
        p_error     := 112;
        p_men_error := substr('Error al actualizar tabla ge_movimientos ' ||
                              sqlerrm,
                              1,
                              4000);
         raise ex_error;
    end;
     if p_error =0 then
       if v_horamovim is null then
           if v_secuencia + 3 > 999 then
              --v_secuencia := 0;
              v_horamovim := pag_gen.FU_OBT_SIG_SEGUNDO(v_horamovim);
            ELSE
              --v_secuencia := v_secuencia + 1;
              v_horamovim          := fug_obt_mov_hora;
           end if;
       end if; 
         
          --si no hay errores, genera movimientos de pase a fideicomiso
          prp_gen_asi_fideicomiso('FID',p_nro_cuenta,r_vcven.cod_modulo,v_horamovim,p_cod_mod_destino,p_error,p_men_error);
   
          end if;
       if p_error <> 0 then
         raise ex_error;
       end if; 
  end if;
  
exception
  when ex_error then
    v_det_error := p_error || ' ' || p_men_error;
    prg_ins_log_programas('PRP_PRO_PAS_FIDEICOMISO',
                          substr(v_det_error, 1, 4000),
                          null,
                          null);


  when others then
    v_det_error := DBMS_UTILITY.format_error_backtrace || ' ' ||
                   DBMS_UTILITY.format_error_stack;
  
    it.prg_ins_log_programas('PRP_PRO_PAS_FIDEICOMISO',
                             substr(v_det_error, 1, 4000),
                             null,
                             null);

end prp_pro_pas_fideicomiso;
/

