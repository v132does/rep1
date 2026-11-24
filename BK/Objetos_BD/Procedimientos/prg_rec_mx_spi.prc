create or replace procedure it.PRG_REC_MX_SPI(p_id_mensaje        in varchar2,
                                           p_id_validacion     in varchar2,
                                           p_id_sesion         in varchar2,
                                           p_id_pago           out varchar2,
                                           p_resultado         out varchar2,
                                           p_motivo            out varchar2) is
                                           begin
                                             null;
/*  RG_MSJ   PAS_SPI.rg_msj;
  v_result varchar2(256);
  PROCEDURE LP_ACT_MX_VALIDADO IS
    pragma autonomous_transaction;
  BEGIN
    begin
       pre_ini_aplicacion;
       pae_cnf.g_cod_modulo := 1;
    end;
    UPDATE GE_SPI_TRANSFERENCIAS T
       SET T.ESTADO         = 'O',
           T.ID_SESION      = P_ID_SESION,
           t.id_pago        = P_ID_VALIDACION
     WHERE T.NRO_REFERENCIA = P_ID_VALIDACION;
     commit;
  END LP_ACT_MX_VALIDADO;

  procedure lp_obt_reg_transferencia(p_nro_referencia in ge_spi_transferencias.nro_referencia%type,
                                     p_rg_msj         out PAS_SPI.rg_msj,
                                     P_RESULT         OUT VARCHAR2) is
  begin
    select t.message_id,
           t.NRO_REFERENCIA,
           t.COD_TRA_PADRE,
           t.COD_MODULO,
           t.COD_MODALIDAD,
           t.COD_OFICINA,
           t.COD_MX,
           t.TIP_OPERACION,
           t.FEC_VALOR,
           t.FEC_RECEPCION,
           t.FECHA,
           t.HORA,
           t.COD_USUARIO,
           t.COD_MONEDA,
           t.MONTO,
           t.COD_PER_ORIGEN,
           t.NOM_CLI_ORIGEN,
           t.TIP_DOC_ORIGEN,
           t.NRO_DOC_ORIGEN,
           t.NRO_CTA_ORIGEN,
           t.BIC_ORIGEN,
           t.COD_PER_RECEPTOR,
           t.NOM_CLI_RECEPTOR,
           t.TIP_DOC_RECEPTOR,
           t.NRO_DOC_ORIGEN,
           t.NRO_CTA_RECEPTOR,
           t.BIC_RECEPTOR,
           t.ORIGEN,
           T.Cod_Mon_Origen,
           t.mto_origen,
           t.tip_cambio
      into p_rg_msj.MESSAGE_ID,
           p_rg_msj.NRO_REFERENCIA,
           p_rg_msj.COD_TRA_PADRE,
           p_rg_msj.COD_MODULO,
           p_rg_msj.COD_MODALIDAD,
           p_rg_msj.COD_OFICINA,
           p_rg_msj.COD_MX,
           p_rg_msj.TIP_OPERACION,
           p_rg_msj.FEC_VALOR,
           p_rg_msj.FEC_RECEPCION,
           p_rg_msj.FECHA,
           p_rg_msj.HORA,
           p_rg_msj.COD_USUARIO,
           p_rg_msj.COD_MONEDA,
           p_rg_msj.MONTO,
           p_rg_msj.COD_PER_ORIGEN,
           p_rg_msj.NOM_CLI_ORIGEN,
           p_rg_msj.TIP_DOC_ORIGEN,
           p_rg_msj.NRO_DOC_ORIGEN,
           p_rg_msj.NRO_CTA_ORIGEN,
           p_rg_msj.BIC_ORIGEN,
           p_rg_msj.COD_PER_RECEPTOR,
           p_rg_msj.NOM_CLI_RECEPTOR,
           p_rg_msj.TIP_DOC_RECEPTOR,
           p_rg_msj.NRO_DOC_ORIGEN,
           p_rg_msj.NRO_CTA_RECEPTOR,
           p_rg_msj.BIC_RECEPTOR,
           p_rg_msj.ORIGEN,
           P_RG_MSJ.COD_MON_ORIGEN,
           P_RG_MSJ.MTO_ORIGEN,
           P_RG_MSJ.TIP_CAMBIO
      from ge_spi_transferencias t
     where t.nro_referencia = p_nro_referencia;
    P_RESULT := 'OK';
  exception
    when no_Data_found then
      P_RESULT := 'ERROR';
  end lp_obt_reg_transferencia;

BEGIN
  \* ---INICIA EL CUERPO PRINCIPAL--- *\
 pas_spi.PR_INS_LOG_MX('PRG_REC_MX_SPI','P_ID_MENSAJE;P_ID_VALIDACION;P_ID_SESION',p_id_mensaje||';'||NVL(p_id_validacion,'NULL')||';'||NVL(p_id_sesion,'NULL'),'I','ID_MENSAJE', p_id_mensaje);

  LP_ACT_MX_VALIDADO;
  lp_obt_reg_transferencia(P_ID_VALIDACION, RG_MSJ, V_RESULT);
  IF V_RESULT <> 'OK' THEN
    P_RESULTADO := 'ERROR';
    P_MOTIVO    := 'AG09'; -- no se recibio pago original
  else
    PAS_SPI.pr_pro_transferencias(RG_MSJ, p_resultado, p_motivo);
    if p_resultado = 'OK' then
      p_id_pago   := P_ID_VALIDACION; --456789;--s_nro_ref_mx_spi.nextval();
      p_motivo    := null;
      p_resultado := 'OK';
     
    else
      --  p_id_pago   := P_ID_VALIDACION; --456789;--s_nro_ref_mx_spi.nextval();
      p_resultado := 'ERROR';
      p_motivo    := null;
      BEGIN
        begin
           pre_ini_aplicacion;
           pae_cnf.g_cod_modulo := 1;
        end;
        UPDATE Ge_Spi_Transferencias T
           SET T.ERROR = pas_spi.g_msj_error,
               T.ESTADO = 'E'
         WHERE T.NRO_REFERENCIA = P_ID_VALIDACION;
      END;
    END IF;
  end if;
  pas_spi.PR_INS_LOG_MX('PRG_REC_MX_SPI','P_ID_PAGO;P_RESULTADO;P_MOTIVO',p_id_validacion||';'||p_resultado||';'||NVL(p_motivo,'NULL'), 'O','P_ID_PAGO',p_id_pago);
*/
end;
/

