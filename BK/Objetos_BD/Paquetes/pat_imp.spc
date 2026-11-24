CREATE OR REPLACE PACKAGE it.pat_imp IS
   -- Variables Públicas
   r_log ta_logs%ROWTYPE;
   --
   c_fec_actual CONSTANT DATE := pag_cal.fu_obt_fec_actual(5);
   c_mon_local  CONSTANT ge_cuentas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
   --
   g_nro_cuenta    ge_cuentas.nro_cuenta%TYPE;
   g_cod_modulo    ba_modulos.cod_modulo%TYPE;
   g_cod_modalidad ge_modalidades.cod_modalidad%TYPE;
   g_cod_oficina   ba_oficinas.cod_oficina%TYPE;
   g_cod_moneda    ge_cuentas.cod_moneda%TYPE;
   g_cotizacion    ge_cotizaciones.val_compra%TYPE;
   g_dias          NUMBER;
   g_old_categoria ta_cta_tarjetas.cat_automatica%TYPE;
   g_sal_tarjeta   ta_cta_tarjetas.sal_facturar%TYPE;
   g_secuencia     ge_movimientos.nro_secuencia%TYPE;
   g_hor_movim     ge_movimientos.hora%TYPE;
   --
   g_nro_reg NUMBER;
   --
   g_tip_implementacion ge_par_generales.tip_implementacion%TYPE := fug_obt_tip_implementacion;
   --*******************************************--
   -- Public function and procedure declarations
   PROCEDURE pr_pro_bancard(p_nro_cuenta IN VARCHAR2 DEFAULT NULL);
   PROCEDURE pr_imp_cta_tarjetas(p_nro_cuenta IN VARCHAR2 DEFAULT NULL);
   PROCEDURE pr_ins_cobro_ban;
   PROCEDURE pr_pro_procard;
   /* Procesa los datos de CABAL */
   PROCEDURE pr_pro_cabal;
   /* Procesa los cobros de CABAL */
   PROCEDURE pr_ins_cobro_cabal;
   /* Cambio de Categoría */
   PROCEDURE pr_cam_categoria(p_nro_cuenta IN pr_cta_prestamos.nro_cuenta%TYPE DEFAULT NULL);
   /* Proceso de cambio de estado de tarjetas. */
   PROCEDURE pr_pro_cam_est_tar
   (
      p_nro_cuenta    IN ge_cuentas.nro_cuenta%TYPE,
      p_old_categoria IN ta_cta_tarjetas.cat_automatica%TYPE,
      p_new_categoria IN ta_cta_tarjetas.cat_automatica%TYPE
   );
   /* Actualizar la categoría de una tarjeta. */
   PROCEDURE pr_act_cat_tarjeta
   (
      p_nro_cuenta     IN ta_cta_tarjetas.nro_cuenta%TYPE,
      p_cat_automatica IN ta_cta_tarjetas.cat_automatica%TYPE
   );
   /* Realizar asientos contables por el cambio de estado del préstamo. */
   PROCEDURE pr_ins_asiento
   (
      p_cod_tra_padre   IN ge_movimientos.cod_tra_padre%TYPE,
      p_cod_transaccion IN ge_movimientos.cod_transaccion%TYPE,
      p_monto           IN ge_movimientos.monto%TYPE,
      p_concepto        IN ge_movimientos.concepto%TYPE,
      p_estado          IN ge_movimientos.est_cuenta%TYPE
   );
   /* Recupera monto previsión de ge_cla_operaciones. */
   FUNCTION fu_obt_prevision(p_nro_cuenta IN pr_cta_prestamos.nro_cuenta%TYPE) RETURN NUMBER;
   PROCEDURE pr_pro_tarjeta;
   /* Inserta la persona con los datos recibidos de cada Procesadora */
   PROCEDURE pr_ins_persona
   (
      p_administradora IN ge_entes.cod_ente%TYPE,
      p_nro_documento  IN ba_personas.nro_documento%TYPE,
      p_tip_documento  IN ba_personas.cod_tip_documento%TYPE,
      p_nombre         IN ba_personas.nom_completo%TYPE,
      p_fec_nacimiento IN ba_per_fisicas.fec_nacimiento%TYPE,
      p_cod_sexo       IN ba_per_fisicas.cod_sexo%TYPE,
      p_est_civil      IN ba_per_fisicas.est_civil%TYPE,
      p_cod_promotor   IN ba_personas.cod_usu_promotor%TYPE,
      p_cod_persona    IN OUT ba_per_fisicas.cod_persona%TYPE,
      p_ok             OUT BOOLEAN
   );
   /* Inserta los datos de nuevas sucursales para una procesadora determinada */
   PROCEDURE pr_ins_sucursal
   (
      p_cod_procesadora IN ta_sucursales.cod_ent_procesadora%TYPE,
      p_cod_sucursal    IN ta_sucursales.cod_sucursal%TYPE
   );
   FUNCTION fu_val_numero(p_dato VARCHAR2) RETURN NUMBER;
   PROCEDURE pr_ver_errores;
   /* Inserta el registro de Log en la tabla TA_LOGS */
   PROCEDURE pr_log
   (
      p_mensaje ta_logs.comentario%TYPE,
      p_error   BOOLEAN DEFAULT TRUE
   );
   /* Verifica que no se hayan producido errores, en la tabla TA_LOGS */
   PROCEDURE pr_ver_log;
   /* Inicializa la tabla TA_LOGS */
   PROCEDURE pr_bor_log;
   /* Actualiza la fecha de último proceso de la cuenta */
   PROCEDURE pr_act_ult_pro
   (
      p_nro_cuenta ge_cuentas.nro_cuenta%TYPE,
      p_fec_actual DATE
   );
   /* Cancela las cuentas que no vienieron de la procesadora */
   PROCEDURE pr_pro_can_cta;
   /* Verifica que exista la relaci{on  de la cuenta con el cliente */
   FUNCTION fu_exi_cta_cli
   (
      p_nro_cuenta  ge_cuentas.nro_cuenta%TYPE,
      p_cod_persona ba_personas.cod_persona%TYPE
   ) RETURN BOOLEAN;
   /* Devuelve el valor para CI y RUC de la tabla de tipos de documentos */
   PROCEDURE pr_obt_documentos
   (
      p_cod_ci  OUT NUMBER,
      p_cod_ruc OUT NUMBER,
      p_cod_pas OUT NUMBER,
      p_cod_dni OUT NUMBER,
      p_cod_cad OUT NUMBER,
      p_cod_cie OUT NUMBER,
      p_cod_crc OUT NUMBER
   );
   /* Devuelve el número de documento recibido SIN los ceros adelante */
   FUNCTION fu_con_documento
   (
      p_nro_documento IN VARCHAR2,
      p_mensaje       OUT VARCHAR2
   ) RETURN VARCHAR2;
   /* Setea las tarjetas para dejar una sola como VIGENTE */
   PROCEDURE pr_pro_set_vigente;
     /* Setea las tarjetas para dejar una sola como VIGENTE - Procard*/
   PROCEDURE pr_pro_set_vig_procard;
   /* Devuelve la fecha de cierre de la procesadora en el mes/año indicado */
   FUNCTION fu_obt_fec_cierre
   (
      p_cod_procesadora IN NUMBER,
      p_cod_modalidad   IN NUMBER DEFAULT NULL,
      p_cod_tip_cierre  IN NUMBER DEFAULT 3
   ) RETURN DATE;
   /* Inserta la tabla TA_SAL_CIERRE para la cuenta indicada */
   PROCEDURE pr_ins_sal_cierre
   (
      p_nro_cuenta IN VARCHAR2,
      p_fec_cierre IN DATE,
      p_procesadora IN NUMBER DEFAULT NULL --FSPC-509
   );
   /* Devuelve la fecha de vencimiento de la procesadora en el mes/año indicado */
   FUNCTION fu_obt_fec_vencim
   (
      p_cod_procesadora IN NUMBER,
      p_cod_modalidad   IN NUMBER DEFAULT NULL,
      p_cod_tip_cierre  IN NUMBER DEFAULT 1
   ) RETURN DATE;
    -- verificar si se utilizan
   FUNCTION FU_ELI_ACENTOS( P_CADENA VARCHAR2,
                           P_CORREO VARCHAR2 DEFAULT 'N'
                           ) RETURN VARCHAR2;
   FUNCTION FU_VAL_CORREO( P_MAIL        VARCHAR2,
                          P_COD_PERSONA ba_personas.cod_persona%TYPE DEFAULT NULL
                          ) RETURN VARCHAR2;
   -- Actualiza en forma dinámica campos definidos en el dominio TAR_ACT_ACENTOS
   PROCEDURE PR_ACT_ACENTOS( P_DOMINIO     ba_cod_referencias.dominio%TYPE,
                            P_COD_PERSONA ba_personas.cod_persona%TYPE DEFAULT NULL
                            );
   PROCEDURE PR_ACT_SOLICITUDES(P_NRO_SOLICITUD ta_solicitudes.nro_solicitud%TYPE DEFAULT NULL);
  ---
   /* Carga en una tabla temporal la información recuperada de .txt*/
   PROCEDURE pr_imp_conciliacion;
   /* Distribuye en distintas tablas la información recolectada en la tabla temporal*/
   PROCEDURE pr_ins_conciliacion;
   /* Realiza los mov. correspondientes a los Totales insertados en la tabla TA_TOT_CONCILIACIONES*/
   PROCEDURE pr_gen_mov_conciliacion;

   PROCEDURE pr_ins_log_error
   (
      p_mensaje ta_logs.comentario%TYPE,
      p_error   BOOLEAN DEFAULT TRUE
   );

   /* Devuelve el nro de cuenta de una tarjeta*/
  FUNCTION FU_OBT_NRO_CUENTA( P_NRO_TARJETA IN TA_TARJETAS.NRO_TARJETA%TYPE) RETURN VARCHAR2;
  /* Obtiene importes de deudas de la cuenta*/
  PROCEDURE PR_OBT_DEU_TARJETA( P_NRO_CUENTA       IN  TA_CTA_TARJETAS.NRO_CUENTA%TYPE,
                                P_NRO_TARJETA      IN  TA_TARJETAS.NRO_TARJETA%TYPE,
                                P_SAL_PAG_MINIMO   OUT TA_CTA_TARJETAS.SAL_PAG_MINIMO%TYPE,
                                P_SAL_ULT_EXTRACTO OUT TA_CTA_TARJETAS.SAL_ULT_EXTRACTO%TYPE,
                                P_DEU_TOTAL        OUT TA_CTA_TARJETAS.SAL_FACTURAR%TYPE,
                                P_FEC_ULT_CIERRE   OUT TA_CTA_TARJETAS.FEC_ULT_CIERRE%TYPE,
                                P_NOM_EMBOZAR      OUT TA_TARJETAS.NOM_EMBOZAR%TYPE
                              );

   /* Indica si una cuenta genera impresion de extracto */
  FUNCTION FU_RET_EXTRACTO(P_NRO_CUENTA IN TA_CTA_TARJETAS.NRO_CUENTA%TYPE) RETURN VARCHAR2;
   /*Servicio de compensacion de bocas de cobranzas t107
    procesa todas las operaciones realizadas entre WEPA y BANCARD */
  
  PROCEDURE pr_com_bca_cobranza;


END pat_imp;
/
