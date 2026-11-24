create or replace procedure it.PRT_OBT_DAT_TAR_GP(p_cod_persona     in BA_PERSONAS.COD_PERSONA%type,
                                                  p_nom_cliente     out AH_TAR_DEBITOS.EMBOZADO%type,
                                                  p_nro_cta_debito  out TA_IMP_DAT_EMBOZADOS.NRO_CTA_DEB_GLOBAL%type,
                                                  P_nro_tar_debito  out TA_TARJETAS.NRO_TARJETA%type,
                                                  p_ult_dig_TD      out AH_TAR_DEBITOS.NRO_TARJETA%type,
                                                  p_fec_vencimiento out VARCHAR2,
                                                  p_tip_tar_Debito  out VARCHAR2,
                                                  p_nro_cta_credito out TA_TARJETAS.NRO_CUENTA%type,
                                                  p_nro_tar_credito out TA_TARJETAS.NRO_TARJETA%type,
                                                  p_ult_dig_tc      out TA_TARJETAS.NRO_TARJETA%type,
                                                  p_color           out VARCHAR2,
                                                  p_cod_banco       out GE_BANCOS.COD_BANCO%type,
                                                  p_cod_err         out NUMBER,
                                                  p_msg_err         out VARCHAR2) IS
  v_log_error varchar2(4000);
begin
  p_cod_err:=0;
  begin
    select nvl(t.nom_embozar, d.embozado) nom_cliente,
           d.nro_cuenta,
           lpad(SUBSTR(s.nro_pan_pro_secundario, -4, 4),
                length(s.nro_pan_pro_secundario),
                '*') nro_tar_debito,
           SUBSTR(s.nro_pan_pro_secundario, -4, 4) ult_dig_TD,
           to_char(d.fec_vencimiento, 'MM/YY') fec_vencimiento,
           decode(d.tip_tar_debito,
                  'MV',
                  'VIRTUALDEBITCARD',
                  'MF',
                  'DEBIT',
                  '') tip_tar_Debito,
           t.nro_cuenta nro_cta_credito,
           lpad(SUBSTR(t.nro_tarjeta, -4, 4), 16, '*') nro_tar_credito,
           SUBSTR(t.nro_tarjeta, -4, 4) ult_dig_tc,
           decode(d.cod_ent_procesadora,
                  fug_obt_pardinamico('COD_ENT_GLOBAL'),
                  it.FUE_OBT_DES_REFCODES('COL_TARJETAS', 1, 'S'),
                  null) color
      into p_nom_cliente,
           p_nro_cta_debito,
           P_nro_tar_debito,
           p_ult_dig_TD,
           p_fec_vencimiento,
           p_tip_tar_Debito,
           p_nro_cta_credito,
           p_nro_tar_credito,
           p_ult_dig_tc,
           p_color
      from ta_imp_dat_embozados s, ah_tar_debitos d, ta_tarjetas t
     where s.cod_persona = p_cod_persona
       and s.cod_persona = d.cod_persona(+)
       and s.nro_cta_deb_global = d.nro_cta_global(+)
       and SUBSTR(s.nro_pan_pro_secundario, -4, 4) = d.nro_tarjeta(+)
       and nvl(d.tar_activa, 'N') = 'S'
       and s.cod_persona = t.cod_persona(+)
       and s.nro_cuenta = t.nro_cuenta(+)
       and SUBSTR(s.nro_pan_pro_principal, -4, 4) =
           SUBSTR(t.nro_tarjeta(+), -4, 4)
        and nvl(t.vigente(+), 'N') = 'S';
  exception
    when no_data_found then
      begin
        select d.embozado nom_cliente,
               d.nro_cuenta nro_cta_debito,
               lpad(SUBSTR(d.nro_tarjeta, -4, 4), 16, '*') nro_tar_debito,
               SUBSTR(d.nro_tarjeta, -4, 4) ult_dig_td,
               to_char(d.fec_vencimiento, 'MM/YY') fec_vencimiento,
               decode(d.tip_tar_debito, 'MV', 'VIRTUALDEBITCARD', 'DEBIT') tip_tarjeta,
               null nro_cta_credito,
               null nro_tar_credito,
               null ult_dig_tc,
               decode(d.cod_ent_procesadora,
                      fug_obt_pardinamico('COD_ENT_GLOBAL'),
                      it.FUE_OBT_DES_REFCODES('COL_TARJETAS', 1, 'S'),
                      null) color
          into p_nom_cliente,
               p_nro_cta_debito,
               P_nro_tar_debito,
               p_ult_dig_TD,
               p_fec_vencimiento,
               p_tip_tar_Debito,
               p_nro_cta_credito,
               p_nro_tar_credito,
               p_ult_dig_tc,
               p_color
          from ah_tar_debitos d, ah_cta_vistas ct
         where d.cod_persona = p_cod_persona
           and d.nro_cuenta = ct.nro_cuenta
           and d.tar_activa = 'S'
           and nvl(d.tip_tar_debito, 'MV') = 'MV'
           and d.cod_ent_procesadora = fug_obt_pardinamico('COD_ENT_GLOBAL')
           and d.nro_cta_global not in
               (select ex.nro_cta_deb_global
                  from ta_imp_dat_embozados ex
                 where ex.nro_cta_deb_global = d.nro_cta_global
                   and ex.cod_persona = d.cod_persona
                   and SUBSTR(ex.nro_pan_pro_secundario, -4, 4) =
                       d.nro_tarjeta);
      exception
        when no_data_found then
          p_cod_err := 2;
          p_msg_err := 'No se encuentran datos para la persona ' ||
                       p_cod_persona;
        when others then
          p_cod_err   := 3;
          p_msg_err   := 'Ocurrio un error inesperado al intentar datos para la persona ' ||
                         p_cod_persona;
          v_log_error := substr(p_msg_err || ' ' || sqlerrm, 1, 4000);
      end;
    when others then
      p_cod_err   := 1;
      p_msg_err   := 'Ocurrio un error inesperado al intentar datos para la persona ' ||
                     p_cod_persona;
      v_log_error := p_msg_err || ' ' || sqlerrm;
  end;
  if nvl(p_cod_err, 0) = 0 then
    begin
      select b.cod_banco
        into p_cod_banco
        from ge_bancos b
       where cod_persona = fug_obt_per_entidad
         and sigla = 'UENO';
    exception
      when others then
        p_cod_err   := 4;
        p_msg_err   := 'Ocurrio un error al intentar recuperar codigo de banco';
        v_log_error := substr(p_msg_err || ' ' || sqlerrm, 1, 4000);
    end;
  end if;
  if nvl(p_cod_err, 0) != 0 then
    p_nom_cliente     := null;
    p_nro_cta_debito  := null;
    P_nro_tar_debito  := null;
    p_ult_dig_TD      := null;
    p_fec_vencimiento := null;
    p_tip_tar_Debito  := null;
    p_nro_cta_credito := null;
    p_nro_tar_credito := null;
    p_ult_dig_tc      := null;
    p_color           := null;
  
    if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
      prg_ins_log_programas('PRT_OBT_DAT_TAR_GP',
                            substr(' Error: ' ||
                                   nvl(v_log_error, p_msg_err),
                                   1,
                                   4000),
                            p_cod_persona,
                            null);
    end if;
  end if;
exception
  when others then
    p_cod_err         := 99;
    p_msg_err         := 'Ocurrio un error inesperado al intentar recuperar datos de la tarjeta';
    v_log_error       := substr(p_msg_err ||
                                DBMS_UTILITY.format_error_stack || ' - ' ||
                                DBMS_UTILITY.format_error_backtrace,
                                1,
                                4000);
    p_nom_cliente     := null;
    p_nro_cta_debito  := null;
    P_nro_tar_debito  := null;
    p_ult_dig_TD      := null;
    p_fec_vencimiento := null;
    p_tip_tar_Debito  := null;
    p_nro_cta_credito := null;
    p_nro_tar_credito := null;
    p_ult_dig_tc      := null;
    p_color           := null;
    if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
      prg_ins_log_programas('PRT_OBT_DAT_TAR_GP',
                            substr(' Error: ' || v_log_error, 1, 4000),
                            p_cod_persona,
                            null);
    end if;
end PRT_OBT_DAT_TAR_GP;
/

