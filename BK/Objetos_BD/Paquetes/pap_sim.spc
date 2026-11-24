create or replace package it.pap_sim is

  -- Author  : GBENITEZ
  -- Created : 20/04/2020 16:59:28
  -- Purpose : Paquete de simulacion de prestamos

  -- Public type declarations
   g_lugar       VARCHAR2(250);
   g_msj_error   VARCHAR2(4000);
   g_cod_error   NUMBER(3) DEFAULT 0;

 PROCEDURE pr_val_cheques(p_nro_cheque in number,
                             p_monto in number,
                             p_fec_emision in date,
                             p_fec_vencimiento in date,
                             p_dias in number);

 PROCEDURE pr_sim_pre_consumo(p_cod_modalidad  in number,
                              p_cod_moneda     in varchar2,
                              p_tip_monto      in varchar2,
                              p_mto_solicitado in number,
                              p_can_cuotas     in number,
                              p_fec_pri_vencimiento in date,
                              p_solicitud      out typ_consolicitud,
                              p_cargos         out typ_listaconcargo,
                              p_cuotas         out typ_listaconcuota,
                              p_tip_persona    in varchar2,
                              p_mto_consolidado in number);

 procedure pr_sim_pre_descuento(p_tip_persona          in varchar2 default 1, --1-Fisica, 2- Juridica
                                p_cod_modalidad        in number,
                                p_cod_moneda           in varchar2,
                                p_monto                in number,
                                p_can_documento        in number,
                                p_val_tasa             in number,
                                p_cod_ent_seguro       in number,
                                p_cod_persona          in varchar2,
                                p_tas_impositiva       in number default 10,
                                p_chequesdet           in typ_cheques,
                                p_fec_inicio           in date,
                                p_fec_pri_vencimiento  in date,
                                p_cod_tasa             in number,
                                p_fec_vencimiento      in  date,
                                p_descripcion          in varchar2,
                                p_cod_oficina          in number,
                                p_tip_monto            in varchar2 default 'B',
                                p_solicitud            out typ_dessolicitud,
                                p_cuotas out typ_listadescuota,
                                p_cargos out typ_listadescargo);

  -- Prestamos con periodo de gracia y cuotas iguales.
 PROCEDURE pr_sim_cuo_iguales(p_cod_modalidad  in number,
                              p_cod_moneda     in varchar2,
                              p_tip_monto      in varchar2,
                              p_mto_solicitado in number,
                              p_can_cuotas     in number,
                              p_fec_pri_vencimiento in date,
                              p_solicitud      out typ_consolicitud,
                              p_cargos         out typ_listaconcargo,
                              p_cuotas         out typ_listaconcuota,
                              p_tip_persona    in varchar2,
                              p_mto_consolidado in number);
/* Obtener tasa efectiva y nominal de prestamo Simulador tmp */
  PROCEDURE PR_OBT_TAS_TMP
   (P_NRO_SOLICITUD IN PR_CTA_PRESTAMOS.NRO_SOLICITUD%TYPE
   ,P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
   ,P_VAL_TAE IN OUT NUMBER
   ,P_VAL_TAN IN OUT NUMBER
   );

end pap_sim;
/

