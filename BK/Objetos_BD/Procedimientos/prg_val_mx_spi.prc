create or replace procedure it.PRG_VAL_MX_SPI(p_id_mensaje    in varchar2,
                                           p_tip_documento in varchar2,
                                           p_nro_documento in varchar2,
                                           p_nom_cliente   in varchar2,
                                           p_nro_cuenta    in varchar2,
                                            p_bic_remitente     in varchar2,
                                            p_tip_doc_remitente in varchar2,
                                            p_nro_doc_remitente in varchar2,
                                            p_nom_remitente     in varchar2,
                                            p_nro_cta_remitente in varchar2,
                                           p_monto         in varchar2,
                                           p_cod_moneda    in varchar2,
                                           p_id_validacion out varchar2,
                                           p_resultado     out varchar2,
                                           p_motivo        out varchar2) is
/*  v_bic             ge_spi_transferencias.bic_origen%type;
  v_result          ge_spi_transferencias.message_result%type;
  v_error           ge_spi_transferencias.error%type;
  v_id_val          ge_spi_transferencias.nro_referencia%type;
  v_cod_mon_hab     varchar2(10) := fug_obt_pardinamico('SPI_COD_MON_HABILITADO');
  v_tiene_error     varchar2(1) := 'N';
  v_cod_rechazo     varchar2(10);
  v_nro_cta_interno ge_cta_clientes.nro_cuenta%type;
  v_cod_persona     ba_personas.cod_persona%type;
  vg_est_modulo     ba_modulos.estado%type;--estado del modulo 3
  V_ESTADO          VARCHAR2(1);
  EX_SALIR EXCEPTION;

  PROCEDURE LP_INS_MENSAJE(p_id_val out ge_spi_transferencias.nro_referencia%type) is
    rg_msj pas_spi.rg_msj;
    pragma AUTONOMOUS_TRANSACTION;
  BEGIN
    rg_msj.NRO_REFERENCIA    := pas_spi.fu_obt_sig_nro_referencia(trunc(sysdate));
    rg_msj.MESSAGE_ID        := p_id_mensaje;
    rg_msj.COD_TRA_PADRE     := PAS_SPI.fu_obt_cod_tra_padre; --'303';
    rg_msj.COD_MODULO        := PAS_SPI.fu_obt_cod_mod_padre; -- '4';
    rg_msj.COD_MODALIDAD     := PAS_SPI.fu_obt_cod_mad_padre; -- '455';
    rg_msj.COD_OFICINA       := pas_spi.fu_obt_cod_oficina;
    rg_msj.COD_MX            := 'PACS.008';
    rg_msj.TIP_OPERACION     := 'P';
    RG_MSJ.FEC_VALOR         := trunc(sysdate);
    RG_MSJ.FEC_RECEPCION     := SYSDATE;
    RG_MSJ.ORIGEN            := 'H';
    rg_msj.TIP_DOC_RECEPTOR := p_tip_documento; -- tipo de documento
    rg_msj.NRO_DOC_RECEPTOR := p_nro_documento; -- número de documento
    rg_msj.NOM_CLI_RECEPTOR := p_nom_cliente; -- nombre
    rg_msj.NRO_CTA_RECEPTOR := p_Nro_cuenta; -- cuenta
    rg_msj.BIC_RECEPTOR     := v_bic; --pas_spi.fu_obt_cta_ban_participante(pas_spi.fu_obt_cod_moneda(p_cod_moneda));
    rg_msj.TIP_DOC_ORIGEN   := p_tip_doc_remitente;
    rg_msj.NRO_DOC_ORIGEN   := p_nro_doc_remitente;
    rg_msj.NOM_CLI_ORIGEN   := p_nom_remitente;
    rg_msj.NRO_CTA_ORIGEN   := p_nro_cta_remitente;
    rg_msj.BIC_ORIGEN       := p_bic_remitente;-- rtrim(substr(p_id_mensaje,0,12),'X');---obtiene el bic de origen
    rg_msj.MONTO      := p_monto; -- (monto) valor de la transferencia
    rg_msj.COD_MONEDA := pas_spi.fu_obt_cod_moneda(p_cod_moneda); -- moneda de la transferencia
    rg_msj.ESTADO     := 'P';
    rg_msj.TIP_CAMBIO := 1;
    rg_msj.MTO_ORIGEN := p_monto;
    RG_MSJ.COD_MON_ORIGEN := pas_spi.fu_obt_cod_moneda(p_cod_moneda);

    pas_spi.pr_ins_transferencias(rg_msj, v_result, v_error);
    p_id_val := rg_msj.NRO_REFERENCIA;
    commit;
  END LP_INS_MENSAJE;

  PROCEDURE LP_ACT_TRANSFERENCIA(P_ID_VAL          IN ge_spi_transferencias.nro_referencia%type,
                                 P_ESTADO          IN GE_SPI_TRANSFERENCIAS.ESTADO%TYPE,
                                 P_RESULT          IN GE_SPI_TRANSFERENCIAS.MESSAGE_RESULT%TYPE,
                                 P_DET_ERROR       IN GE_SPI_TRANSFERENCIAS.ERROR%TYPE,
                                 P_COD_PERSONA     IN GE_SPI_TRANSFERENCIAS.COD_PER_RECEPTOR%TYPE,
                                 P_NRO_CTA_INTERNO IN ge_cta_clientes.nro_cuenta%type) IS
  pragma AUTONOMOUS_TRANSACTION;
  v_error ge_spi_transferencias.error%type;
  BEGIN
    if p_result = 'OK' THEN
       V_ERROR := NULL;
    ELSE
       V_ERROR := PAS_SPI.fu_obt_desc_errores(P_DET_ERROR);
    END IF;
    begin
              pre_ini_aplicacion;
              pae_cnf.g_cod_modulo := 1;
    end;
    
    if  vg_est_modulo in(1,6) then
       V_ERROR := V_ERROR||'*Proceso de cierre en curso.';
    end if;
    update Ge_Spi_Transferencias t
    set    t.estado         = P_ESTADO,
           t.message_result = p_result,
           t.Cod_Error      = P_DET_ERROR,
           T.ERROR          = V_ERROR,
           t.id_validacion  = p_id_val,
           t.cod_per_receptor = P_COD_PERSONA,
           T.NRO_CTA_RECEPTOR = P_NRO_CTA_INTERNO
    WHERE  T.NRO_REFERENCIA = p_id_val;
    commit;
  END LP_ACT_TRANSFERENCIA;

begin
  \***--------------INICIA CUERPO PRINCIPAL-----------------***\
  pas_spi.PR_INS_LOG_MX('PRG_VAL_MX_SPI',
                'p_id_mensaje;p_tip_documento;p_nro_documento;p_nom_cliente;p_nro_cuenta;p_bic_remitente;p_tip_doc_remitente;p_nro_doc_remitente;p_nom_remitente;p_nro_cta_remitente;p_monto;p_cod_moneda',
                 p_id_mensaje||';'||p_tip_documento||';'||p_nro_documento||';'||
                         p_nom_cliente||';'||p_nro_cuenta||';'||p_bic_remitente||';'||
                         p_tip_doc_remitente||';'||p_nro_doc_remitente||';'||p_nom_remitente||';'||
                         p_nro_cta_remitente||';'||p_monto||';'||p_cod_moneda,
                'I',
                'ID_MENSAJE', p_id_mensaje);
  v_bic := pas_snp.fu_obt_cod_swi_participante ( fug_obt_per_entidad );

  LP_INS_MENSAJE(v_id_val);
  if pas_spi.fu_val_mx_duplicado(p_id_mensaje,v_id_val) then
    v_cod_rechazo := 'AM05';--mx duplicado
    RAISE EX_SALIR;
  end if;
  ---validar estado de modulo
  vg_est_modulo := pae_cnf.FU_OBT_EST_MODULO(3);
  if  vg_est_modulo in(1,6) then
    v_cod_rechazo := 'DT02';--politica interna
    RAISE EX_SALIR;
  end if;
  --Nombre del cliente no debe ser nulo
  if p_nom_cliente is null then
    v_tiene_error := 'S';
    v_cod_rechazo := 'RR01'; --Nombre del beneficiario es requerido
    RAISE EX_SALIR;
  end if;
  if p_tip_documento is  null then
    v_cod_rechazo := 'RR03'; --Nro del documento del beneficiario es requerido
    RAISE EX_SALIR;
  end if;
  if p_nro_documento is  null then
    v_cod_rechazo := 'RR02'; --Nro del documento del beneficiario es requerido
    RAISE EX_SALIR;
  end if;
  pas_spi.pr_obt_cta_interna(p_nro_cuenta,
                             pas_spi.fu_obt_cod_tipDocumento(p_tip_documento),
                             p_nro_documento,
                             v_nro_cta_interno,
                             v_cod_persona,
                             v_tiene_error,
                             v_cod_rechazo);
  IF v_tiene_error = 'S' THEN
    RAISE EX_SALIR;
  END IF;
  if instr('*' || v_cod_mon_hab || '*', '*' || pas_spi.fu_obt_cod_moneda(p_cod_moneda) || '*') = 0 then
    --valida Moneda
    v_tiene_error := 'S';
    v_cod_rechazo := 'AC09'; --MONEDA INVALIDA
    RAISE EX_SALIR;
  end if;
  --pas_spi.pr_ver_cta_basica(v_nro_cta_interno,trunc(sysdate),p_monto,v_tiene_error);
  --VAE -- DYDMR-25757 se pasa el valor de la fecha actual para la verificacion de cuenta basica 
   pas_spi.pr_ver_cta_basica(v_nro_cta_interno,pag_cal.FU_OBT_FEC_ACTUAL(4),p_monto,v_tiene_error);
 
 IF v_tiene_error = 'S' THEN
    v_cod_rechazo := 'AG01'; --TRANSACCION INVALIDA POR SER CUENTA BASICA
    RAISE EX_SALIR;
  END IF;
  --v_val_spi := fug_val_mx_spi(v_bic,p_nro_documento, p_nro_cuenta,p_cod_moneda,p_monto, 'R')
  --p_resultado := lf_val_datos;
  p_id_validacion := v_id_val; --s_nro_ref_mx_spi.nextval();
  p_resultado     := 'OK';
  p_motivo        := null;
  LP_ACT_TRANSFERENCIA(v_id_val,'V',p_resultado,p_motivo, v_cod_persona,nvl(v_nro_cta_interno,p_nro_cuenta));
  pas_spi.PR_INS_LOG_MX('PRG_VAL_MX_SPI','P_ID_VALIDACION;P_RESULTADO;P_MOTIVO',p_id_validacion||';'||p_resultado||';'||NVL(p_motivo,'NULL'), 'O','P_ID_VALIDACION',p_id_validacion);
exception
  when ex_salir then
    p_id_validacion := v_id_val;
    p_resultado := 'ERROR';
    p_motivo    := v_cod_rechazo;
    IF FUE_OBT_VAL_MAX_REFCODES('SPI_ERROR_MX',PAS_SPI.fu_obt_cod_rechazo(p_motivo)) <> 'R' THEN
       V_ESTADO := 'C';
    ELSE
       V_ESTADO := 'R';
    END IF;
    LP_ACT_TRANSFERENCIA(v_id_val,V_ESTADO,p_resultado,p_motivo, null,p_nro_cuenta);
    pas_spi.PR_INS_LOG_MX('PRG_VAL_MX_SPI','P_ID_VALIDACION;P_RESULTADO;P_MOTIVO',p_id_validacion||';'||p_resultado||';'||NVL(p_motivo,'NULL'), 'O','P_ID_VALIDACION',p_id_validacion);
*/
begin
null;
end;
/

