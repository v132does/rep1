create or replace procedure it.PRP_INS_HIS_LIM_GLOBAL(P_NRO_LINEA IN NUMBER) is
  v_estado            pr_lineas.estado%type;
  v_cod_gru_economico ge_gru_economicos.cod_gru_economico%type;
  v_lugar             varchar2(400) := null;
  v_sec_registro      number;

Begin

 begin
  v_lugar := 'Buscando secuencia para insertar histórico';
    select s_cod_reg_his_lim_global.Nextval 
      into v_sec_registro 
      from dual;
 exception
   when others then
   raise_application_error(-20000, v_lugar || ': ' || p_nro_linea || '-' || sqlerrm);
 end;
 
  Select estado, cod_gru_economico
    into v_estado, v_cod_gru_economico
    from pr_gru_lineas
   where nro_linea = p_nro_linea;
  ---
  begin
    v_lugar := 'Insertando pr_gru_lineas_his';
    Insert into pr_gru_lineas_his
      (nro_linea, cod_gru_economico, cod_moneda, monto, fec_vencimiento, fec_otorgamiento, mto_aplicado,
       descripcion, estado, observacion, niv_aprobacion, cotizacion, fec_aprobacion, nro_acta, usu_insercion, 
       fec_insercion, usu_modificacion, fec_modificacion, nro_secuencia, mto_ope_especificas, cod_campana)
      Select nro_linea, cod_gru_economico, cod_moneda, monto, fec_vencimiento, fec_otorgamiento,  mto_aplicado,
             descripcion, estado, observacion, niv_aprobacion,  cotizacion, fec_aprobacion, nro_acta, usu_insercion, 
       fec_insercion, usu_modificacion, fec_modificacion, v_sec_registro,mto_ope_especificas, cod_campana
        from pr_gru_lineas
       where nro_linea = p_nro_linea;
  exception
    when no_data_found then 
      null;
    when others then
      raise_application_error(-20000, v_lugar || ': ' || p_nro_linea ||' cod_gru_economico = '||
                              v_cod_gru_economico || '-' || sqlerrm);
  end;

  ---
  v_lugar := 'Insertando pr_gru_lin_tip_garantias_his';
  begin
    Insert into pr_gru_lin_tip_garantias_his
      (nro_linea, cod_garantia, mto_limite, mto_aplicado, usu_insercion, 
       fec_insercion, usu_modificacion, fec_modificacion, nro_secuencia)
      select nro_linea, cod_garantia, mto_limite, mto_aplicado, usu_insercion, 
       fec_insercion, usu_modificacion, fec_modificacion, v_sec_registro
        from pr_gru_lin_tip_garantias
       where nro_linea = p_nro_linea;
  exception
    when no_data_found then 
      null;
    when others then
      raise_application_error(-20000, v_lugar || ': ' || p_nro_linea ||' cod_gru_economico = ' ||
                              v_cod_gru_economico || ' ' || sqlerrm);
  end;
  ---
  begin
    v_lugar := 'Insertando pr_gru_lin_tip_gar_mad_his';
    Insert into pr_gru_lin_tip_gar_mad_his
      (nro_linea, cod_garantia, cod_modulo, cod_modalidad, mto_limite, mto_aplicado, usu_insercion, 
       fec_insercion, usu_modificacion, fec_modificacion, nro_secuencia)
      Select nro_linea, cod_garantia, cod_modulo, cod_modalidad, mto_limite, mto_aplicado, usu_insercion, 
       fec_insercion, usu_modificacion, fec_modificacion, v_sec_registro
        from pr_gru_lin_tip_gar_mad
       where nro_linea = p_nro_linea;
  exception
    when no_data_found then 
      null;
    when others then
      raise_application_error(-20000, v_lugar || ': ' || p_nro_linea || ' cod_gru_economico = ' ||
                              v_cod_gru_economico || ' ' || sqlerrm);
  end;
  ---
  v_lugar := 'Insertando pr_gru_lin_aplicaciones_his';
  begin
    Insert into pr_gru_lin_aplicaciones_his
      (nro_linea, cod_gru_economico, cod_persona, cod_moneda, mto_aplicado, usu_insercion, 
       fec_insercion, usu_modificacion, fec_modificacion, nro_secuencia, nro_lin_individual, estado)
      Select nro_linea, cod_gru_economico, cod_persona, cod_moneda, mto_aplicado, usu_insercion, 
       fec_insercion, usu_modificacion, fec_modificacion, v_sec_registro, nro_lin_individual, estado 
        from pr_gru_lin_aplicaciones
       where nro_linea = p_nro_linea;
  exception
    when no_data_found then 
      null;   
    when others then
      raise_application_error(-20000, v_lugar || ': ' || p_nro_linea ||' cod_gru_economico = ' ||
                              v_cod_gru_economico || ' ' || sqlerrm);
  end;
  ---
  
    ---
  v_lugar := 'Insertando pr_gru_lin_aplicaciones_his-especificos';
  begin
    Insert into pr_ope_gru_economicos_his
      (cod_gru_economico, cod_persona, nom_completo, nro_linea, monto, mto_aplicado,
       mto_ope_especifica, saldo, apl_linea, nro_secuencia)
      Select cod_gru_economico, cod_persona, nom_completo, nro_linea, monto, mto_aplicado,
       mto_ope_especifica, saldo, 'N', v_sec_registro
        from pv_ope_gru_economicos ope
       where cod_gru_economico = v_cod_gru_economico
       and nro_linea != 0
       and not exists (select 1 
                         from pr_gru_lin_aplicaciones apl
                        where apl.cod_persona = ope.cod_persona
                          and apl.cod_gru_economico = ope.cod_gru_economico);

  exception
    when no_data_found then 
      null;   
    when others then
      raise_application_error(-20000, v_lugar || ': ' || p_nro_linea ||' cod_gru_economico = ' ||
                              v_cod_gru_economico || ' ' || sqlerrm);
  end;

  v_lugar := 'Insertando pr_gru_lin_aplicaciones_his-aplicados';
  begin

    Insert into pr_ope_gru_economicos_his
      (cod_gru_economico, cod_persona, nom_completo, nro_linea, monto, mto_aplicado,
       mto_ope_especifica, saldo, apl_linea, nro_secuencia)
      Select cod_gru_economico, cod_persona, nom_completo, nro_linea, monto, mto_aplicado,
       mto_ope_especifica, saldo, 'S', v_sec_registro
        from pv_ope_gru_economicos ope
       where ope.cod_gru_economico = v_cod_gru_economico
       and (ope.nro_linea = 0 
           or (ope.nro_linea != 0
              and exists (select 1 
                            from pr_gru_lin_aplicaciones apl
                           where apl.cod_persona = ope.cod_persona
                             and apl.cod_gru_economico = ope.cod_gru_economico)));

  exception
    when no_data_found then 
      null;   
    when others then
      raise_application_error(-20000, v_lugar || ': ' || p_nro_linea ||' cod_gru_economico = ' ||
                              v_cod_gru_economico || ' ' || sqlerrm);
  end;
  ---
Exception
   when no_data_found then 
      null; 
   when others then
    if sqlcode <= -20000 then
      raise;
    else
      raise_application_error(-20000,'PRP_INS_HIS_LIM_GLOBAL:'|| v_lugar||'-'||  p_nro_linea || ' cod_gru_economico = ' ||
                              v_cod_gru_economico || ' ' || sqlerrm);
    end if;
End PRP_INS_HIS_LIM_GLOBAL;
/

