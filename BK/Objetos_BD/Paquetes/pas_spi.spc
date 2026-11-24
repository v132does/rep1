create or replace package it.PAS_SPI is

  -- (c) 2021 - ITTI DIGITAL 
  -- Autores: Belen Rolon - Nelson Grance - Nathalia Recalde
  -- Created : 21/12/2021 18:05:07
  -- Purpose : Gestionar envío/recepción de MX para el Sistema de Pagos Instantáneos

   g_fec_actual          constant date    := pag_cal.fu_obt_fec_actual(1);
   g_gru_dir_correo      constant ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico( 'SNP_GRU_DIR_CORREO' );
   g_cod_tra_padre ge_transacciones.cod_transaccion%type := 303;
   g_cod_mod_padre ge_transacciones.cod_modulo%type      := 4;
   g_cod_mad_padre ge_modalidades.cod_modalidad%type     := 455;
   g_cod_mon_iso_local   varchar2(3)      := 'PYG';
   g_pac_002             varchar2(10)     := 'pacs.002';
   g_pac_028             varchar2(10)     := 'pacs.028';
   g_pac_004             varchar2(10)     := 'pacs.004'; -- JFF 07/02/2022
   g_pac_018             varchar2(10)     := 'pacs.018'; -- JFF 07/02/2022
   g_cam_019             varchar2(10)     := 'camt.019'; -- JFF 07/02/2022
   g_pac_008             varchar2(10)     := 'pacs.008';
   g_pai_013             varchar2(10)     := 'pain.013';
   g_pai_001             varchar2(10)     := 'pain.001';
   g_pai_002             varchar2(10)     := 'pain.002';
   g_pai_014             varchar2(10)     := 'pain.014';
   g_cam_060             varchar2(10)     := 'camt.060';
   g_cam_011             varchar2(10)     := 'camt.011';
   g_cam_009             varchar2(10)     := 'camt.009';
   g_cam_018             varchar2(10)     := 'camt.018';
   g_cam_025             varchar2(10)     := 'camt.025'; -- JFF 10/02/2022
   g_cam_033             varchar2(10)     := 'camt.033';
   g_cam_034             varchar2(10)     := 'camt.034'; -- JFF 16/02/2022
   g_cam_010             varchar2(10)     := 'camt.010';
   g_cam_052             varchar2(10)     := 'camt.052'; -- JFF 16/02/2022   
   g_adm_002             varchar2(10)     := 'admi.002'; -- JFF 07/02/2022
   g_adm_004             varchar2(10)     := 'admi.004'; -- JFF 07/02/2022
   g_cam_029             varchar2(10)     := 'camt.029'; -- MGF 25/05/2023
   g_cam_056             varchar2(10)     := 'camt.056'; -- MGF 25/05/2023
   g_rch_ac01            varchar2(10)     := 'AC01';
   g_rch_ac04            varchar2(10)     := 'AC04';
   g_rch_ac09            varchar2(10)     := 'AC09';
   g_rch_rr02            varchar2(10)     := 'RR02';
   g_rch_dt02            varchar2(10)     := 'DT02';
   g_rch_ag01            varchar2(10)     := 'AG01';
   g_rch_am02            varchar2(10)     := 'AM02';
   g_rch_am04            varchar2(10)     := 'AM04';
   g_rch_dt03            varchar2(10)     := 'DT03';
   g_rch_ms03            varchar2(10)     :='MS03';
   g_nom_respuesta       varchar2(2000):=null;
   g_cod_mon_local       varchar2(3)      := pag_gen.fu_obt_mon_local;
   g_msj_error           varchar2(2000);
   g_cod_error           number(3)        default 0;
   g_tip_rch             varchar2(10)     :=null;
   g_horario             varchar2(1)      := 'D'; -- Dia normal
   g_es_mov_noc          varchar2(1)      := 'N'; -- Graba S/N mov nocturnos
   g_es_cta_noc          varchar2(1)      := 'N'; -- Graba S/N ctas noctunas
   g_fec_actual_h        date; -- fecha de hoy
   g_mod_estado          ba_modulos.estado%TYPE;
   g_fec_valor           date := g_fec_actual;
   ex_error              exception;
   ex_salir              exception;
   g_lugar               varchar2(250);
   --SPI F2
   v_cod_tra_padre       ge_movimientos.cod_tra_padre%type;
   v_cod_mod_padre       ge_movimientos.cod_mod_padre%type;
   v_cod_mad_padre       ge_movimientos.cod_mad_padre%type;
   v_cod_ofi_debito      ge_movimientos.cod_ofi_origen%type;
   v_cod_mod             ge_transacciones.cod_modulo%TYPE;
   v_cod_mad             ge_transacciones.cod_modalidad%TYPE;
   v_est_cuenta          ah_cta_vistas.estado%TYPE;
   v_sal_disponible      ah_cta_vistas.sal_total%type;
   v_procesa             varchar(1); 
   v_tra_deb             ge_movimientos.cod_transaccion%TYPE;
   g_reversion           varchar2(1):='N';
--Tipo de dato para la mensajería
  type rg_msj is record
  (nro_referencia               ge_snp_transferencias.nro_referencia%type
  ,nro_lote                     ge_snp_transferencias.nro_lote%type
  ,nro_sec_lote                 ge_snp_transferencias.nro_sec_lote%type
  ,cod_modulo                   ge_snp_transferencias.cod_modulo%type
  ,cod_modalidad                ge_snp_transferencias.cod_modalidad%type
  ,cod_oficina                  ge_snp_transferencias.cod_oficina%type
  ,cod_msj_swift                ge_snp_transferencias.cod_msj_swift%type
  ,cod_tip_operacion            ge_snp_transferencias.cod_tip_operacion%type
  ,cod_sub_tip_operacion        ge_snp_transferencias.cod_sub_tip_operacion%type
  ,msj_swift                    ge_snp_transferencias.msj_swift%type
  ,fec_ingreso                  ge_snp_transferencias.fec_ingreso%type
  ,fec_recepcion                ge_snp_transferencias.fec_recepcion%type
  ,fec_valor                    ge_snp_transferencias.fec_valor%type
  ,fecha                        ge_snp_transferencias.fecha%type
  ,hora                         ge_snp_transferencias.hora%type
  ,cod_usuario                  ge_snp_transferencias.cod_usuario%type
  ,cod_moneda                   ge_snp_transferencias.cod_moneda%type
  ,monto                        ge_snp_transferencias.monto%type
  ,cod_per_solicitante          ge_snp_transferencias.cod_per_solicitante%type
  ,nom_solicitante              ge_snp_transferencias.nom_solicitante%type
  ,dir_solicitante              ge_snp_transferencias.dir_solicitante%type
  ,cod_tip_doc_solicitante      ge_snp_transferencias.cod_tip_doc_solicitante%type
  ,nro_doc_solicitante          ge_snp_transferencias.nro_doc_solicitante%type
  ,nro_cta_solicitante          ge_snp_transferencias.nro_cta_solicitante%type
  ,cod_swi_pte_solicitante      ge_snp_transferencias.cod_swi_pte_solicitante%type
  ,cod_swi_suc_solicitante      ge_snp_transferencias.cod_swi_suc_solicitante%type
  ,nro_cta_pte_solicitante      ge_snp_transferencias.nro_cta_pte_solicitante%type
  ,nro_cta_suc_pte_solicitante  ge_snp_transferencias.nro_cta_suc_pte_solicitante%type
  ,cod_per_beneficiario         ge_snp_transferencias.cod_per_beneficiario%type
  ,nom_beneficiario             ge_snp_transferencias.nom_beneficiario%type
  ,dir_beneficiario             ge_snp_transferencias.dir_beneficiario%type
  ,cod_tip_doc_beneficiario     ge_snp_transferencias.cod_tip_doc_beneficiario%type
  ,nro_doc_beneficiario         ge_snp_transferencias.nro_doc_beneficiario%type
  ,nro_cta_beneficiario         ge_snp_transferencias.nro_cta_beneficiario%type
  ,cod_swi_pte_beneficiario     ge_snp_transferencias.cod_swi_pte_beneficiario%type
  ,cod_swi_suc_beneficiario     ge_snp_transferencias.cod_swi_suc_beneficiario%type
  ,nro_cta_pte_beneficiario     ge_snp_transferencias.nro_cta_pte_beneficiario%type
  ,nro_cta_suc_pte_beneficiario ge_snp_transferencias.nro_cta_suc_pte_beneficiario%type
  ,concepto                     ge_snp_transferencias.concepto%type
  ,observacion                  ge_snp_transferencias.observacion%type
  ,nro_ref_externa              ge_snp_transferencias.nro_ref_externa%type
  ,tip_cargo                    ge_snp_transferencias.tip_cargo%type
  ,mto_cargo                    ge_snp_transferencias.mto_cargo%type
  ,ind_valor                    ge_snp_transferencias.ind_valor%type
  ,situacion                    ge_snp_transferencias.situacion%type
  ,estado                       ge_snp_transferencias.estado%type
  ,tip_rechazo                  ge_snp_transferencias.tip_rechazo%type
  ,prioridad                    ge_snp_transferencias.prioridad%type
  ,nro_operacion                ge_snp_transferencias.nro_operacion%type
  ,tip_mensaje                  ge_snp_transferencias.tip_mensaje%type
  ,cod_usu_transaccion          ge_snp_transferencias.cod_usu_transaccion%type
  ,ref_oid                      ge_snp_transferencias.ref_oid%type
  ,imp_inf_hacienda             ge_snp_transferencias.imp_inf_hacienda%type
  ,error                        ge_snp_transferencias.error%type
  ,origen                       ge_snp_transferencias.origen%type
  ,plataforma                   ge_snp_transferencias.plataforma%type
  ,indemnizado                  ge_snp_transferencias.indemnizado%type
  ,cod_servicio                 ge_snp_transferencias.cod_servicio%type
  ,usu_insercion                ge_snp_transferencias.usu_insercion%type
  ,usu_modificacion             ge_snp_transferencias.usu_modificacion%type
  );
  g_msj rg_msj;
function fu_obt_cod_error return number;
function fu_obt_msj_error return varchar2;
function fu_tip_msj_spi(p_cod_msj_swift  ge_snp_par_mensajes.cod_msj_swift%type) return varchar2;
function fu_tip_msj_ver(p_cod_msj_mx  ge_spi_cab_versiones.version%type) return varchar2;
function fu_obt_sig_nro_ref_externa ( p_fecha IN ge_snp_transferencias.fecha%type default NULL ) return varchar2;
function fu_obt_tra_spi(p_cod_moneda ge_snp_transferencias.cod_moneda%type, p_monto ge_snp_transferencias.monto%type,p_ind_pat varchar2 default 'N',p_cod_swift ge_snp_transferencias.cod_swi_pte_beneficiario%type) return varchar2;
function fu_obt_dif_seg return number;
function fu_obt_cta_ban_participante( p_cod_swift  in ge_snp_transferencias.cod_swi_pte_solicitante%type,
                                      p_cod_moneda in ba_monedas.cod_moneda%type) return varchar;
function fu_obt_cta_bancaria( p_nro_cuenta in cc_cta_bancarias.nro_cta_bancaria%type,
                              p_tip_cuenta in varchar2 ) return varchar2;
function fu_obt_cta_lbtr_reserva(p_nro_cuenta in cc_cta_bancarias.nro_cta_bancaria%type,p_tip_cuenta in varchar2)return varchar2;
function fu_val_cta_lbtr_reserva(p_cod_swift            in ge_snp_transferencias.cod_swi_pte_solicitante%type,
                                 p_cod_moneda           in ba_monedas.cod_moneda%type,
                                 p_nro_cta_participante in ge_snp_cta_bancos.nro_cta_bancaria%type)return varchar;
procedure pr_obt_dat_envio_automatico(p_tipo_mensaje in varchar2,
                                      p_monto out sb_snp_lim_depo.monto%type,
                                      p_cta_sol out cc_cta_bancarias.nro_cta_bancaria%type);
function fu_val_cta_ban_participante ( p_cod_swift            in ge_snp_transferencias.cod_swi_pte_solicitante%type,
                                       p_cod_moneda           in ba_monedas.cod_moneda%type,
                                       p_nro_cta_participante in ge_snp_cta_bancos.nro_cta_bancaria%type
                                       ) return varchar;
function fu_obt_cab_spi(p_tip_msj_swift            in ge_snp_par_mensajes.tipo%type, p_nro_ref_externa  in ge_snp_transferencias.nro_ref_externa%type ) return typ_ObtdatCabecera;
procedure lp_ver_horario(p_cod_modulo in ba_modulos.cod_modulo%type);
/*Genera la solicitud del reporte insertando datos en la tabla ge_spi_reportes*/
 procedure pr_gen_inf_spi (p_nro_cuenta         in ge_spi_informes.nro_cta_solicitante%type,
                             p_cod_moneda  in ge_spi_informes.cod_moneda%type,
                             p_monto       in ge_spi_informes.monto%type,
                             p_cod_informe in varchar2,
                             p_nro_ref_original in ge_snp_transferencias.nro_ref_externa%type);
procedure pr_gen_res_spi(p_nro_cuenta  in ge_spi_informes.nro_cta_solicitante%type,
                                                   p_cod_informe in varchar2,
                                                   p_nro_ref_original in ge_snp_transferencias.nro_ref_externa%type,
                                                   p_inf_suplementaria   varchar2);
procedure pr_obt_fec_hor_actual(p_cod_modulo in ba_modulos.cod_modulo%type,
                             p_fecha      out date,
                             p_hora       out varchar2);
/*Genera mensajeria parcial a partir del Movimiento*/
  procedure pr_gen_mov_snp ( p_hora            in  ge_movimientos.hora%type,
                             p_fecha           in  ge_movimientos.fecha%type,
                             p_cod_usuario     in  ge_movimientos.cod_usuario%type,
                             p_gen_workflow    in  varchar2 default 'S',
                             p_origen          in  ge_snp_transferencias.origen%type default 'I',
                             p_plataforma      in  ge_snp_transferencias.plataforma%type default 'S',
                             p_nro_ref_externa in  ge_snp_transferencias.nro_ref_externa%type default null,
                             p_ind_enviado     in  varchar2 default 'S',
                             p_cod_programa    out ba_programas.cod_programa%type,
                             p_nro_referencia  out ge_snp_transferencias.nro_referencia%type);
procedure pr_obt_tra_pen_008(p_dat_cabecera out typ_ObtdatCabecera,p_dat_transferencias out typ_ObtTransPendiente008,p_dat_mensaje out typ_mensajeria_spi );
procedure pr_obt_inf_pen_009(p_dat_cabecera out typ_ObtdatCabecera,p_dat_transferencias out typ_ObtInfPendiente,p_dat_mensaje out typ_mensajeria_spi);
procedure pr_obt_inf_pen_011(p_dat_cabecera out typ_ObtdatCabecera,p_dat_transferencias out typ_ObtInfPendiente,p_dat_mensaje out typ_mensajeria_spi);
procedure pr_obt_inf_pen_060(p_dat_cabecera out typ_ObtdatCabecera,p_dat_transferencias out typ_ObtInfPendiente,p_dat_mensaje out typ_mensajeria_spi);
procedure pr_obt_inf_pen_028(p_dat_cabecera out typ_ObtdatCabecera,p_dat_transferencias out typ_ObtInfPago,p_dat_mensaje out typ_mensajeria_spi );
procedure pr_obt_inf_pen_033(p_dat_cabecera out typ_ObtdatCabecera,p_dat_transferencias out typ_ObtInfPago,p_dat_mensaje out typ_mensajeria_spi );
procedure pr_obt_inf_pen_018(p_dat_cabecera out typ_ObtdatCabecera,p_dat_transferencias out typ_ObtInfPendiente,p_dat_mensaje out typ_mensajeria_spi );
procedure pr_obt_inf_res_002(p_dat_cabecera out typ_ObtdatCabecera,p_dat_transferencias out typ_ObtInfPago,p_dat_mensaje out typ_mensajeria_spi );
procedure pr_act_inf_spi (p_nro_ref_externa in   ge_spi_informes.nro_ref_externa%type,
                            p_estado         in  ge_spi_informes.estado%type,
                            p_situacion      in  ge_spi_informes.situacion%type,
                            p_msj_mx         in  ge_spi_informes.msj_mx%type,
                            p_error          in  ge_spi_informes.error%type,
                            p_dat_mensaje    out typ_mensajeria_spi);
procedure pr_act_tra_spi (p_nro_ref_externa in   ge_snp_transferencias.nro_ref_externa%type,
                            p_estado         in  ge_snp_transferencias.estado%type,
                            p_situacion      in  ge_snp_transferencias.situacion%type,
                            p_msj_mx         in  ge_snp_transferencias.msj_swift%type,
                            p_error          in  ge_snp_transferencias.error%type,
                            p_dat_mensaje    out typ_mensajeria_spi);
procedure pr_pro_msj_recibidos(p_dat_recibidos in  typ_Obtdatmsjrespuesta,p_dat_mensaje out typ_mensajeria_spi );
procedure pr_reg_msj_generico( p_dat_recibidos in  typ_Obtdatmsjrespuesta,
                              p_ind_msj_recibido in varchar2 default 'S',
                              p_env_mail         in varchar2 default 'S'
                            );
procedure pr_pro_msj_rec_008(p_dat_recibidos in  typ_ObtTransrecibido008,p_dat_mensaje out typ_mensajeria_spi );
procedure pr_ini_registros;
procedure pr_reg_operacion( p_mensaje   in long,p_respuesta in varchar2);
/*Registra LOG de la tabla ba_log_spi*/
procedure pr_reg_operacion_spi( p_mensaje   in long, p_respuesta in varchar2);
procedure pr_obt_cta_interna( p_nro_cuenta            in  ge_snp_transferencias.nro_cta_beneficiario%type,
                              p_tip_documento         in  ba_personas.cod_tip_documento%type,
                              p_nro_documento         in  ba_personas.nro_documento%type,
                              p_nro_cta_interno       out ge_cuentas.nro_cuenta%type,
                              p_cod_persona           out ba_personas.cod_persona%type
                            );
procedure pr_gen_env_aut_008( p_fec_valor     in ge_snp_transferencias.fec_valor%type default null,
                                  p_can_sin_fondo in varchar2 default 'N'
                                );
procedure pr_gen_rev_tra_008(p_nro_ref_externa in ge_snp_transferencias.nro_ref_externa%type);
function fu_obt_est_hor_spi ( p_cod_msj_swift     in ge_snp_transferencias.cod_msj_swift%type,
                              p_tip_operacion     in ge_snp_transferencias.cod_tip_operacion%type,
                              p_sub_tip_operacion in ge_snp_transferencias.cod_sub_tip_operacion%type
                            ) return varchar2;
PROCEDURE pr_gen_env_api_reporte( p_nro_referencia         out ge_spi_sol_reportes.nro_referencia%type,
                                  p_reportType             out ge_spi_sol_reportes.tip_reporte%type,
                                  p_acc_code               out ge_spi_sol_reportes.nro_cta_solicitante%type,
                                  p_partic_code            out ge_spi_sol_reportes.cod_swi_solicitante%type,
                                  p_payment_status         out ge_spi_sol_reportes.est_pago%type,
                                  p_date_beg               out ge_spi_sol_reportes.fec_desde%type,
                                  p_fecha_end              out ge_spi_sol_reportes.fec_hasta%type,
                                  p_sess_id                out ge_spi_sol_reportes.id_sesion%type,
                                  p_bank_op_code           out ge_spi_sol_reportes.tip_instrumento%type,
                                  p_ttc                    out ge_spi_sol_reportes.tip_transaccion%type,
                                  p_formato                out ge_spi_sol_reportes.formato%type
                            );
procedure pr_gen_rec_api_reporte(p_nro_referencia  in ge_spi_res_reportes.nro_referencia%type,
                                 p_id_peticion     in ge_spi_res_reportes.id_peticion%type,
                                 p_estado          in ge_spi_res_reportes.estado%type,
                                 p_cod_err         out number,
                                 p_msj_error       in out varchar2);

procedure pr_obt_reg_res_api(p_nro_referencia out ge_spi_res_reportes.nro_referencia%type,
                             p_id_peticion    out ge_spi_res_reportes.id_peticion%type,
                             p_estado         out ge_spi_res_reportes.estado%type,
                          --   p_respuesta      out ge_spi_res_reportes.respuesta%type,
                             p_fec_ult_con    out ge_spi_res_reportes.fec_ult_consulta%type,
                             p_formato        out ge_spi_res_reportes.formato%type);

procedure pr_rec_arc_api(p_nro_referencia in ge_spi_res_reportes.nro_referencia%type,
                         p_archivo        in ge_spi_res_reportes.respuesta%type,
                         p_cod_err        out number,
                         p_msj_error      out varchar2);

procedure pr_gen_env_mail_api(p_nro_referencia in ge_spi_res_reportes.nro_referencia%type,
                              p_correo         in varchar2);
procedure pr_env_alerta(p_cod_persona in ba_personas.cod_persona%type,
                                   p_tip_producto in ge_mai_onb_templates.tip_producto%type,
                                   p_inf_json in ba_env_correos.parametros%type);
function fu_obt_tra_spi_notificacion(p_cod_moneda ge_snp_transferencias.cod_moneda%type, p_monto ge_snp_transferencias.monto%type,p_ind_pat varchar2 default 'N',p_cod_swift ge_snp_transferencias.cod_swi_pte_beneficiario%type,p_tipo varchar2 ) return varchar2;
/*
insertar registro en ge_spi_solicitudes
*/
procedure  pr_ins_sol_spi (p_reg ge_spi_solicitudes%rowtype,p_cod_solicitud out number);
/*
Se aplican las validaciones que determinan si una tranf. SPI puede ser devuelta.
*/
procedure pr_val_dev_spi(p_ref_tra_original in varchar2,
                         p_mto_devolver     in number,
                         p_origen           in varchar2,
                         p_cod_retorno      out number,
                         p_men_retorno      out varchar2);
/*
Procesa el envío de pacs004 - Devolución de transferencia
*/
procedure pr_pro_env_004(p_ref_tra_original in varchar2,
                         p_mto_devolver     in number,
                         p_origen           in varchar2,
                         p_mot_rechazo      in varchar2,
                         p_modo             in varchar2,
                         p_reg_devolucion   out pas_snp.rg_msj,
                         p_cod_retorno      out number,
                         p_men_retorno      out varchar2,
                         p_cod_solicitud    in out number,
                         p_usuario          in varchar2);

/*
Determina si la transferencia corresponde a un sub-participante
*/
function fu_val_tra_subpte(p_tipo in varchar2,p_sub_tipo in varchar2) return boolean;
/* Obtiene transferencias pendientes pacs.004 */
procedure pr_obt_tra_pen_004(p_dat_cabecera out typ_ObtdatCabecera,p_dat_transferencias out typ_ObtTransPendiente004,p_dat_mensaje out typ_mensajeria_spi );
/*
Se aplican las validaciones que determinan si se puede registra la solicitud de pago por SPI
*/
procedure pr_val_sol_pago(p_cod_moneda       in varchar2,
                          p_monto            in number,
                          p_bic              in varchar2,
                          p_sub_pte          in varchar2,
                          p_cuenta           in varchar2,          
                          p_cod_retorno      out number,
                          p_men_retorno      out varchar2);
/* Procesa transferencias recibidas pacs.004 */
procedure pr_pro_msj_rec_004(p_dat_recibidos in  typ_ObtTransrecibido004,p_dat_mensaje out typ_mensajeria_spi);
/*
Valida si la funcionalidad de la fase2 está cerificada para la entidad financiera
p_funcionalidad: dominio --> SPI_PTE_CER_DEVOLUCION - SPI_PTE_CER_SOL_DEVOL - SPI_PTE_SOL_PAGO
p_tip_filtro: dominio --> S filtro por el codigo swift de la entidad 
- C filtro por el codigo de persona asignado a la entidad
p_filtro: el codigo swift o el codigo de la persona.
*/
function fu_val_fun_fase2(p_funcionalidad in varchar2,
                          p_tip_filtro in varchar2,
                          p_filtro in varchar2) return varchar2;
/*
SPI - FASE2  Envío de solicitude pago (pain.013) al MS
*/
procedure pr_obt_tra_pen_013(p_dat_cabecera out typ_ObtdatCabecera,p_dat_solicitud out typ_ObtSolicitudPago013,p_dat_mensaje out typ_mensajeria_spi);
/* Procesa Reversion de pacs.004 recibidos que no cumplan validaciones, generando un pacs.008 de devolución */ 
procedure pr_gen_rev_dev_004(p_nro_ref_externa in ge_snp_transferencias.nro_ref_externa%type,
                             p_nro_ref_msj_original in ge_spi_solicitudes.nro_ref_msj_original%type);
/*
Cancela de forma automática los circuitos que no fueron autorizados/rechazados.
*/                            
procedure pr_can_aut_solicitudes;
/*
Se aplican las validaciones que determinan si se puede generar una Solicitud de Devolucion por una transf. SPI.
*/      
procedure pr_val_sol_dev_spi(p_ref_tra_original in varchar2,
                             p_mto_devolver     in number,
                             p_origen           in varchar2,
                             p_cod_retorno      out number,
                             p_men_retorno      out varchar2); 
/*
Procesa el envío de camt.056 - Solicitud de Devolución de transferencia
*/
procedure pr_pro_env_056(p_ref_tra_original in varchar2,
                         p_mto_devolver     in number,
                         p_origen           in varchar2,
                         p_mot_solicitud    in varchar2,
                         p_modo             in varchar2,
                         p_reg_devolucion   out pas_snp.rg_msj,
                         p_cod_retorno      out number,
                         p_men_retorno      out varchar2,
                         p_cod_solicitud    in out number,
                         p_usuario          in varchar2);                               
/*
Devolver un pacs008 en respuesta a un pain.013 que no se puedo acreditar
*/
procedure pr_gen_rev_dev_013(p_nro_referencia in ge_snp_transferencias.nro_referencia%type,
                             p_cod_respuesta  out number,
                             p_mensaje        out varchar2,
                             p_ref_devolucion out number);
/* 
Obtiene solicitudes pendientes de envio camt.056 
*/
procedure pr_obt_sol_pen_056(p_dat_cabecera out typ_ObtdatCabecera,p_dat_solicitud out typ_ObtSolDevPendiente056,p_dat_mensaje out typ_mensajeria_spi ); 
/*
Actualiza el estado y la situacion de las solicitudes SPI.
Debe ser invocado por el XAIX
*/
procedure pr_act_solicitudes (p_nro_ref_externa   in ge_snp_transferencias.nro_ref_externa%type,
                              p_estado            in  ge_snp_transferencias.estado%type,
                              p_situacion         in  ge_snp_transferencias.situacion%type,
                              p_msj_mx            in  ge_snp_transferencias.msj_swift%type,
                              p_error             in  ge_snp_transferencias.error%type,
                              p_dat_mensaje       out typ_mensajeria_spi);       
/*Genera codigo UERT a partir de una clave*/
function fu_obt_uetr(p_clave in number) return varchar2;  
/*
Inserta las solicitudes recibidas
*/
procedure pr_pro_sol_recibidas(p_dat_recibidos in typ_ObtSolRecibido,p_dat_mensaje out typ_mensajeria_spi);
/*
SPI - FASE2  Envío de solicitude pago (pain.014) al MS
*/
procedure pr_obt_tra_pen_014(p_dat_cabecera out typ_ObtdatCabecera,p_dat_solicitud out typ_ObtRespuesta014,p_dat_mensaje out typ_mensajeria_spi);
/*Procesa la autorización de una solicitud recibida*/
procedure pr_pro_aut_solicitud(p_cod_solicitud in ge_spi_solicitudes.cod_sol_spi%type,
                               p_origen        in varchar2,
                               p_usuario       in varchar2,
                               p_monto         in number,
                               p_cod_retorno   out number,
                               p_men_retorno   out varchar2);                    
/*
SPI - FASE2  Envío de Rechazo de Solicitud de devolución Recibida (camt.029) al MS
*/
procedure pr_obt_tra_pen_029(p_dat_cabecera out typ_ObtdatCabecera,p_dat_respuesta out typ_ObtRechazoSoldev029,p_dat_mensaje out typ_mensajeria_spi);
/*Procesa el rechazo de una solicitud recibida*/
procedure pr_pro_rec_solicitud(p_cod_solicitud in ge_spi_solicitudes.cod_sol_spi%type,
                               p_cod_rechazo   in ge_spi_solicitudes.tip_rechazo%type,
                               p_cod_retorno   out number,
                               p_men_retorno   out varchar2);   
/*
SPI - FASE2  Envío de solicitude pago (pain.014) al MS
*/
procedure pr_obt_tra_pen_002(p_dat_cabecera out typ_ObtdatCabecera,p_dat_solicitud out typ_ObtRespuesta002,p_dat_mensaje out typ_mensajeria_spi);
/*
Obtiene los datos del OMP
*/
function fu_obt_dat_omp(p_cod_swift in varchar2) return ge_entes%rowtype;                                            

/*Obtiene el tipo de persona , F: Fisica , J: Juridica*/
function fu_obt_tip_persona(p_cod_persona in varchar2) return varchar2;
/*
Envía notificaciones sobre solicitudes de pago o solicitudes de inicio de pago
*/
procedure pr_not_sol_pago(p_notifica in varchar2,p_solicitud in ge_spi_solicitudes%rowtype,p_cod_rechazo in varchar2 default null);                                       
/*
Cancela de forma automática las solicitudes de devolución que no fueron autorizados/rechazados.
*/                            
procedure pr_can_aut_sol_dev;
/*Reversa operacion de transferencia spi*/
PROCEDURE pr_rev_ope_spi(  p_nro_referencia in ge_snp_transferencias.nro_referencia%type,p_concepto       in ge_movimientos.concepto%type default null,p_estado         in ge_snp_transferencias.estado%type default 'C',
                           p_ref_externa   ge_snp_transferencias.nro_ref_externa%type,   p_fecha         ge_movimientos.fecha%type,
                           p_hora          ge_movimientos.hora%type,
                           p_cod_usuario   ge_movimientos.cod_usuario%type);
end PAS_SPI;
/
