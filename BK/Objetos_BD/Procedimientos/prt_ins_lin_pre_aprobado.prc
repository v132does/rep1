create or replace procedure it.PRT_INS_LIN_PRE_APROBADO(p_cod_persona          ta_lin_pre_aprobado.cod_persona%type,
                                                        p_mto_oferta           ta_lin_pre_aprobado.mon_lin_pre_aprobado%type,
                                                        p_mto_cuo_aproximado   it.ba_per_gen_ofertas.mto_cuo_aproximado%type,
                                                        p_cod_pla_pre_aprobado ta_lin_pre_aprobado.cod_pla_pre_aprobado%type,
                                                        p_tie_ingreso          varchar2,
                                                        p_cod_error            OUT NUMBER,
                                                        p_msj_error            OUT VARCHAR2) is
  v_cod_pre_aprobado     ta_lin_pre_aprobado.cod_pre_aprobado%type;
  v_fin_oferta           ta_lin_pre_aprobado.fec_fin_oferta%type;
  v_mto_lin_pre_aprobado ta_lin_pre_aprobado.mon_lin_pre_aprobado%type;
  v_monto                ta_lin_pre_aprobado.mon_lin_pre_aprobado%type;
  v_cod_error            number;
  v_log_mensaje          varchar2(4000);
  v_mto_min_oferta       ge_par_dinamicos.val_parametro%type;
  v_can_dias_ven         ge_par_dinamicos.val_parametro%type;
  v_ctr_ven_oferta       ge_par_dinamicos.val_parametro%type;
  v_mto_max_oferta       ge_par_dinamicos.val_parametro%type;
  v_existe               varchar2(1) := 'N';
  v_pre_vigente          VARCHAR2(1) := 'N';
  v_cod_modalidad        ta_lin_pre_aprobado.cod_modalidad%type;

begin
  savepoint insert_pre_aprobado;
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  v_mto_min_oferta := fug_obt_pardinamico('TAR_MTO_MIN_OFERTA');
  v_mto_max_oferta := fug_obt_pardinamico('TAR_MTO_MAX_OFERTA');
  if nvl(v_mto_min_oferta, '0') = '0' then
    v_cod_error   := 5;
    v_log_mensaje := 'Falta configurar parametro TAR_MTO_MIN_OFERTA';
  end if;
  v_ctr_ven_oferta := fug_obt_pardinamico('TAR_CTR_VEN_OFERTA');
  if nvl(v_ctr_ven_oferta, '0') = '0' then
    v_cod_error   := 5;
    v_log_mensaje := 'Falta configurar parametro TAR_CTR_VEN_OFERTA';
  end if;
  BEGIN
    SELECT nvl(max(cod_pre_aprobado), 0) + 1
      INTO v_cod_pre_aprobado
      FROM ta_lin_pre_aprobado;
  EXCEPTION
    WHEN no_data_found THEN
      v_cod_pre_aprobado := 1;
    WHEN OTHERS THEN
      v_cod_error   := 1;
      v_log_mensaje := substr('Error al recuperar valor de codigo pre aprobado ' ||
                              sqlerrm,
                              1,
                              4000);
  END;
  if nvl(v_cod_error, 0) = 0 then
    if nvl(p_tie_ingreso, 'N') = 'S' then
      /*ba_per_gen_ofertas.mto_cuo_aproximado y multiplicarlo por 10*/
      if nvl(p_mto_cuo_aproximado, 0) > 0 then
        v_monto := p_mto_cuo_aproximado * 10;
      else
        v_cod_error   := 4;
        v_log_mensaje := 'El monto de cuota aproximado debe ser mayor a 0';
      end if;
    else
      /*Si el cliente no cuenta con ingresos registrados se debe obtener el monto de la oferta del pre aprobado pr_pre_aprobados.mon_pre_aprobado*/
      v_monto := p_mto_oferta;
    end if;
  
    /*El monto de l?nea de TC debe ser redondeado de a Gs. 100.000 para abajo.*/
    if nvl(v_cod_error, 0) = 0 then
      select v_monto - mod(v_monto, 100000)
        into v_mto_lin_pre_aprobado
        from dual;
    
      if nvl(v_ctr_ven_oferta, 'N') = 'S' then
        v_can_dias_ven := fug_obt_pardinamico('TAR_CAN_DIAS_VEN');
        if nvl(v_can_dias_ven, '0') = '0' then
          v_cod_error   := 5;
          v_log_mensaje := 'Falta configurar parametro TAR_CAN_DIAS_VEN';
        else
          v_fin_oferta := pag_cal.FU_OBT_FEC_ACTUAL(5) + v_can_dias_ven;
        end if;
      end if;
    end if;
    if nvl(v_mto_lin_pre_aprobado, 0) >= nvl(v_mto_max_oferta, 0) then
      v_mto_lin_pre_aprobado := v_mto_max_oferta;
    end if;
    if nvl(v_cod_error, 0) = 0 then
      begin
        select 'S'
          into v_existe
          from ta_lin_pre_aprobado a
         where a.cod_persona = p_cod_persona
           and a.estado in ('G', 'C');
      exception
        when no_data_found then
          v_existe := 'N';
        when too_many_rows then
          v_existe := 'S';
        when others then
          v_existe := 'N';
      end;
      if v_existe = 'S' then
        v_cod_error   := 7;
        v_log_mensaje := 'El Cliente ya posee otra oferta pre aprobada vigente.';
      end if;
    end if;
    if nvl(v_cod_error, 0) = 0 then
      begin
        select 'S'
          into v_pre_vigente
          from ta_cta_tarjetas p, ta_solicitudes s
         where p.nro_solicitud = s.nro_solicitud
           and p.cod_modulo = s.cod_modulo
           and p.cod_modalidad = s.cod_modalidad
           and p.cod_moneda = s.cod_moneda
           and s.cod_persona = p_cod_persona
           and p.estado = 'N'
           and exists (select 1
                  from ta_tarjetas ta
                 where ta.nro_cuenta = p.nro_cuenta);
      exception
        when no_data_found then
          v_pre_vigente := 'N';
        when too_many_rows then
          v_pre_vigente := 'S';
        when others then
          v_pre_vigente := 'N';
      end;
      if v_pre_vigente = 'S' then
        v_cod_error   := 8;
        v_log_mensaje := 'El cliente ya posse un tarjeta activa';
      end if;
    end if;
    if nvl(v_cod_error, 0) = 0 then
      begin
        select a.cod_modalidad
          into v_cod_modalidad
          from ta_lin_pre_aprobado a
         where a.cod_persona = p_cod_persona
           and a.estado in ('G', 'C');
      exception
        when no_data_found then
          v_cod_modalidad := null;
        when too_many_rows then
          v_cod_modalidad := '1';
        when others then
          v_cod_modalidad := null;
      end;
      IF instr(fug_obt_pardinamico('TA_COD_MOD_PREAPROBADO'),
               v_cod_modalidad) = 0 THEN
        v_cod_error   := 9;
        v_log_mensaje := 'No esta permitida la modalidad' ||
                         v_cod_modalidad || 'para preaprobados';
      end if;
    end if;
    if nvl(v_cod_error, 0) = 0 then
      if nvl(v_mto_lin_pre_aprobado, 0) >= nvl(v_mto_min_oferta, 0) then
        insert into ta_lin_pre_aprobado
          (cod_pre_aprobado,
           cod_pla_pre_aprobado,
           fec_ini_oferta,
           fec_fin_oferta,
           cod_oficina,
           cod_usu_oficial,
           cod_persona,
           mon_lin_pre_aprobado,
           cod_modalidad,
           cod_rub_economico,
           cod_moneda,
           estado)
        values
          (v_cod_pre_aprobado,
           p_cod_pla_pre_aprobado,
           pag_cal.FU_OBT_FEC_ACTUAL(5),
           v_fin_oferta,
           61,
           'OVIRTUAL',
           p_cod_persona,
           v_mto_lin_pre_aprobado,
           53,
           '970107',
           pag_gen.FU_OBT_MON_LOCAL,
           'C');
      else
        v_cod_error   := 6;
        v_log_mensaje := 'El monto calculado ' || v_mto_lin_pre_aprobado ||
                         ' es menor al monto minimo de oferta. Monto minimo = ' ||
                         v_mto_min_oferta;
      end if;
    elsif nvl(v_cod_error, 0) != 0 then
      insert into TA_LOG_PRE_APROBADOS
        (COD_PRE_APROBADO, COD_PLA_PRE_APROBADO, COD_PERSONA, ERR_REGISTRO)
      values
        (v_cod_pre_aprobado,
         p_cod_pla_pre_aprobado,
         p_cod_persona,
         v_log_mensaje);
    end if;
  end if;
  if nvl(v_cod_error, 0) != 0 then
    p_cod_error := v_cod_error;
    p_msj_error := v_log_mensaje;
    prg_ins_log_programas('PRT_INS_LIN_PRE_APROBADO',
                          substr(' Error: ' || v_cod_error || ' - ' ||
                                 v_log_mensaje,
                                 1,
                                 4000),
                          p_cod_persona,
                          null);
    if nvl(p_cod_error, 0) in (7,8) then
          p_cod_error := 0;
          p_msj_error := null;
    end if;
                              
    --rollback to insert_pre_aprobado;
  else
    p_cod_error := 0;
  end if;
exception
  when others then
    v_cod_error   := 99;
    v_log_mensaje := substr('Ocurrio un error inesperado ' ||
                            DBMS_UTILITY.format_error_stack || ' - ' ||
                            DBMS_UTILITY.format_error_backtrace,
                            1,
                            4000);
    p_cod_error   := v_cod_error;
    p_msj_error   := v_log_mensaje;
    prg_ins_log_programas('PRT_INS_LIN_PRE_APROBADO',
                          substr(' Error: ' || v_cod_error || ' - ' ||
                                 v_log_mensaje,
                                 1,
                                 4000),
                          p_cod_persona,
                          null);
    rollback to insert_pre_aprobado;
end PRT_INS_LIN_PRE_APROBADO;
/

