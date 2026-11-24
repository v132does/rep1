create or replace package it.PAS_DEP is

  -- Autor     : NGRANCE
  -- Creado    : 24/04/2018 08:30:32 a.m.
  -- Propósito : Gestionar envío/recepción de MTs para las Operaciones DEPO del Sistema Nacional de Pagos

  /*Manejo de Errores*/
  g_lugar         varchar2(250);
  g_msj_error     varchar2(1000);
  g_cod_error     number(3) default 0;
  g_det_msj_error ge_snp_transferencias.error%type := null;

  /*Excepciones*/
  ex_workflow exception;
  ex_salir    exception;
  ex_horario  exception;

  /*Obtiene el código de error del registro del paquete.*/
  function fu_obt_cod_error return number;

  /*Obtiene el mensaje de error contenido en el registro del paquete.*/
  function fu_obt_msj_error return varchar2;

  /*Obtiene un detalle de todos los errores encontrados durante la validación de MTs.*/
  function fu_obt_det_msj_error return varchar2;

  /*Obtiene los datos para la operación Depo.*/
  PROCEDURE pr_obt_dat_depo(p_cod_moneda in ba_monedas.cod_mon_iso%type,
                            p_monto      out sb_snp_lim_depo.monto%type,
                            p_tasa       out sb_snp_lim_depo.tasa%type);
                            
   PROCEDURE pr_obt_dat_fondeo(p_cod_moneda in ba_monedas.cod_mon_iso%type,
                            p_monto      out sb_snp_lim_depo.monto%type);

  /*Envia MT920 de Solicitud de Extractos*/
  PROCEDURE pr_obt_msj_MT920(p_cod_tip_mensaje    in sb_snp_tip_mensajes.cod_mensaje%type,
                             p_nro_cta_bancaria   in ge_snp_cta_bancos.nro_cta_bancaria%type,
                             p_tip_rep_solicitado in number default null,
                             p_ind_debito         in varchar2 default null,
                             p_ind_credito        in varchar2 default null,
                             p_mto_debito         in ge_snp_transferencias.monto%type default 0,
                             p_mto_credito        in ge_snp_transferencias.monto%type default 0,
                             p_cod_moneda         in ge_snp_transferencias.cod_moneda%type,
                             p_tipo_identificador in varchar2);

  /*Halla el BIC del Sistema DEPO*/
  FUNCTION fu_obt_bic_sis_depo return varchar2;

  /*Envia MT524 de Transferencia intraposición*/
  PROCEDURE pr_obt_msj_mt524(p_cod_tip_mensaje in sb_snp_tip_mensajes.cod_mensaje%type default 'MT524',
                             p_cod_moneda      in sb_snp_lim_depo.cod_moneda%type default pag_gen.FU_OBT_MON_LOCAL,
                             p_monto           in sb_snp_lim_depo.monto%type default 0,
                             p_nro_documento   in md_cta_documentos.nro_documento%type,
                             p_nro_referencia  in md_cta_documentos.nro_documento%type default null,
                             p_cancela         in ge_snp_transferencias.estado%type default 'N');

  /*Envia MT549 de Consulta de saldo de instrumentos*/
  PROCEDURE pr_obt_msj_MT549(p_cod_tip_mensaje in sb_snp_tip_mensajes.cod_mensaje%type default 'MT549',
                             p_cod_moneda      in sb_snp_lim_depo.cod_moneda%type default pag_gen.FU_OBT_MON_LOCAL,
                             p_nro_documento   in md_cta_documentos.nro_documento%type default NULL,
                             p_nro_referencia  in ge_snp_transferencias.nro_referencia%type default NULL,
                             p_cancela         in ge_snp_transferencias.estado%type default 'N');

  /*Envia MT986 de Facilidad de Liquidez Intradía FLI por efectivo*/
  PROCEDURE pr_obt_msj_MT986(p_cod_tip_mensaje in sb_snp_tip_mensajes.cod_mensaje%type default 'MT986',
                             p_cod_moneda      in sb_snp_lim_depo.cod_moneda%type default pag_gen.FU_OBT_MON_LOCAL,
                             p_monto           in sb_snp_lim_depo.monto%type default 0,
                             p_nro_documento   in ge_snp_transferencias.ref_oid%type,
                             p_nro_referencia  in ge_snp_transferencias.nro_referencia%type default NULL,
                             p_cancela         in ge_snp_transferencias.estado%type default 'N');

  /*Envia MT595 de Recompra manual de FLI por efectivo*/
  PROCEDURE pr_obt_msj_MT595(p_cod_tip_mensaje in sb_snp_tip_mensajes.cod_mensaje%type default 'MT595',
                             p_cod_moneda      in sb_snp_lim_depo.cod_moneda%type default pag_gen.FU_OBT_MON_LOCAL,
                             p_monto           in sb_snp_lim_depo.monto%type default 0,
                             p_nro_documento   in md_cta_documentos.nro_documento%type,
                             p_nro_referencia  in ge_snp_transferencias.nro_referencia%type default NULL,
                             p_cancela         in ge_snp_transferencias.estado%type default 'N');

  /*Envia MT542 de Conversión manual de FLI a REPO O/N*/
  PROCEDURE pr_obt_msj_MT542(p_cod_tip_mensaje in sb_snp_tip_mensajes.cod_mensaje%type default 'MT542',
                             p_cod_moneda      in sb_snp_lim_depo.cod_moneda%type default pag_gen.FU_OBT_MON_LOCAL,
                             p_monto           in sb_snp_lim_depo.monto%type default 0,
                             p_nro_documento   in md_cta_documentos.nro_documento%type,
                             p_nro_referencia  in ge_snp_transferencias.nro_referencia%type default NULL,
                             p_cancela         in ge_snp_transferencias.estado%type default 'N');

  /*Envia MT541 de Solicitud de Extractos*/
  PROCEDURE pr_obt_msj_mt541(p_cod_tip_mensaje in sb_snp_tip_mensajes.cod_mensaje%type default 'MT541',
                             p_cod_moneda      in sb_snp_lim_depo.cod_moneda%type default pag_gen.FU_OBT_MON_LOCAL,
                             p_monto           in sb_snp_lim_depo.monto%type default 0,
                             p_tasa            in sb_snp_lim_depo.tasa%type default 0,
                             p_nro_referencia  in ge_snp_transferencias.nro_referencia%type default NULL,
                             p_cancela         in ge_snp_transferencias.estado%type default 'N');

  /*Procesa valores para la insercion en GE_SNP_MENSAJES cuando no está esquematizado y envia mail*/
  FUNCTION fu_reg_msj_rec_depo(p_mensaje          in clob,
                               p_ind_msj_recibido in varchar2 default 'S',
                               p_env_mail         in varchar2 default 'S')
    return varchar2;
 /*Obtener la cuenta DEPO LBTR-SPI */ 
 FUNCTION fu_obt_cta_depo(p_cod_moneda in ba_monedas.cod_moneda%type default 'GS' ) return varchar2; 
 
 /*Obtiene las ctas relacionadas a los instrumentos comunicados por el BCP*/ --TCE-159
 procedure pr_obt_cta_instrumento_bcp(p_instrumento     in varchar2,
                                      p_mto_instrumento in number,
                                      p_cuenta          out varchar2); 

 /*Actualiza operaciones de restriccion/liberacion de saldo*/
 PROCEDURE pr_act_sal_restringido(p_nro_cuenta in varchar2,
                                  p_monto      in number,
                                  p_es_restr   in varchar2);                                      

end PAS_DEP;
/
