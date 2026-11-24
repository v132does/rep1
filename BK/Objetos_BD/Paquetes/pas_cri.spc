CREATE OR REPLACE PACKAGE IT.pas_cri IS

   -- Author  : RBATTAGLIA
   -- Created : 23/01/2013 01:38:40 p.m.
   -- Purpose : Nuevo Formato de Envio de CRC

 PROCEDURE lp_obt_mto_rie_documento
   (
      p_cod_persona           IN  ge_cla_operaciones.cod_persona%TYPE,
      p_mto_riesgo            OUT ge_cla_operaciones.tot_deu_real%TYPE
   ) ;
    PROCEDURE lp_obt_dat_cta_vencida
   (
      p_cod_persona IN VARCHAR2,
      p_sal_vencido OUT NUMBER,
      p_int_vencido OUT NUMBER
   ) ;
   -- Procedimiento que contiene los datos exigidos para el modulo de prestamos
   PROCEDURE pr_crc_gen_prestamos;

   -- Procedimiento que contiene los datos exigidos para el modulo de Sobregiros
   PROCEDURE pr_crc_gen_sobregiros;

   -- Procedimiento que contiene los datos exigidos para el modulo de Tarjetas
   PROCEDURE pr_crc_gen_tarjetas;

   -- Procedimiento que contiene los datos exigidos para el modulo de Comercio Exterior
   PROCEDURE pr_crc_gen_comex;

   -- Procedimiento que contiene los datos exigidos para fianzas
   PROCEDURE pr_crc_gen_fianzas;

   -- Procedimiento que contiene los datos exigidos para el modulo de Mesa de Dinero
   PROCEDURE pr_crc_gen_mes_dinero;

   -- Procedimiento que contiene los datos exigidos para cheques comprados
   PROCEDURE pr_crc_gen_che_comprados;
   -- Procedimiento que contiene los datos exigidos para el modulo de Operaciones Vencidas
   PROCEDURE pr_crc_gen_ope_vencidas;

   -- Funcion para obtener el codigo primario de la actividad
   FUNCTION fu_obt_rub_primario(p_cod_persona VARCHAR2) RETURN VARCHAR2;

   -- Funcion para obtener el rubro de la actividad
   FUNCTION fu_obt_rub_economico
   (
      p_nro_cuenta ge_cuentas.nro_cuenta%TYPE,
      p_nom_tabla  VARCHAR2
   ) RETURN VARCHAR2;

   -- Funcion para obtener el codigo de departamento del banco central a partir del codigo de persona
   FUNCTION fu_obt_ref_bco_central(p_cod_persona ba_personas.cod_persona%TYPE) RETURN VARCHAR2;

   -- Funcion para obtener el codigo de departamento del banco central a partir del codigo de departamento
   FUNCTION fu_obt_ref_bco_central(p_cod_departamento ba_departamentos.cod_departamento%TYPE)
      RETURN VARCHAR2;
   /* Genera las tablas para los archivos de la Central de Riesgos. */
   PROCEDURE pr_crc_gen_datos(p_tip_periodo VARCHAR2 DEFAULT 'D');
   -- funcion para obtener el rubro contable del modulo de mesa de dinero
   FUNCTION fu_obt_cod_rubro
   (
      p_nro_cuenta       IN VARCHAR2 DEFAULT NULL,

      p_cod_modulo       IN NUMBER DEFAULT NULL,
      p_cod_modalidad    IN NUMBER DEFAULT NULL,
      p_cod_transaccion  IN NUMBER,
      p_cod_moneda       IN VARCHAR2 DEFAULT NULL,
      p_cod_sec_contable IN VARCHAR2 DEFAULT NULL,
      p_cod_tip_deudor   IN NUMBER DEFAULT NULL,
      p_residente        IN VARCHAR2 DEFAULT NULL,
      p_cod_plazo        IN VARCHAR2,
      p_tip_movimiento   IN VARCHAR2,
      p_cod_sit_contable IN NUMBER DEFAULT NULL,
      p_est_cuenta       IN VARCHAR2 DEFAULT NULL,
      p_tip_renovacion   IN VARCHAR2 DEFAULT NULL,
      p_cat_automatica   IN NUMBER DEFAULT NULL,
      p_tip_interes      IN VARCHAR2 DEFAULT NULL,
      p_tip_cuenta       IN VARCHAR2 DEFAULT NULL,
      p_cod_sec_credito  IN NUMBER DEFAULT NULL
   ) RETURN VARCHAR2;

-- funcion para obtener el rubro contable de los modulos de comex
   FUNCTION fu_obt_rub_contable
   (
      p_cod_modulo IN ba_modulos.cod_modulo%TYPE,
      p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE,
      p_tip_monto  IN VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2;
   -- funcion para obtener el rubro resultado
   FUNCTION fu_obt_rub_resultado
   (
      p_nro_cuenta       IN VARCHAR2,
      p_cod_transaccion  IN NUMBER,
      p_cod_plazo        IN VARCHAR2,
      p_tip_movimiento   IN VARCHAR2,
      p_est_cuenta       IN VARCHAR2 DEFAULT NULL,
      p_tip_renovacion   IN VARCHAR2 DEFAULT NULL,
      p_tip_interes      IN VARCHAR2 DEFAULT NULL,
      p_tip_cuenta       IN VARCHAR2 DEFAULT NULL,
      p_cod_sec_credito  IN NUMBER DEFAULT NULL,
      p_cod_moneda       IN VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2;
   --Obtiene el codigo Iso de la monedafu_obt_cod_entid
   FUNCTION fu_obt_mon_iso(p_cod_moneda IN ba_monedas.cod_moneda%TYPE) RETURN VARCHAR2;
   
   --Obtiene el codigo de moneda
   FUNCTION fu_obt_cod_moneda(p_cod_mon_iso IN ba_monedas.cod_mon_iso%TYPE) RETURN VARCHAR2;

   -- Obtiene el codigo de Entidad
   FUNCTION fu_obt_cod_entidad RETURN NUMBER;

   -- Funcion para obtener el codigo del banco central de la tabla pr_rub_economico.
   FUNCTION fu_obt_cod_bcp(p_cod_rub_economico VARCHAR2) RETURN VARCHAR2;

   -- Funcion para obtener si la cuenta por el rubro contable puede o no ser informado
   FUNCTION fu_pue_env_bcp(p_tip_operacion IN VARCHAR2) RETURN VARCHAR2;
   FUNCTION fu_ope_existe(p_nro_operacion in sb_crc_operaciones_det.nro_operacion%TYPE,
      p_tip_operacion in sb_crc_operaciones_det.tip_operacion%TYPE) RETURN VARCHAR2;

   --- Funcion que retorna si el Ruc sera enviado en forma diaria para envio a CRC
   FUNCTION fu_ruc_sal_diario(p_nro_cuenta IN VARCHAR2) RETURN VARCHAR2;
   -- Devuelve la sigte. fecha de vencimiento de la procesadora con relacion a la fecha ingresada.
   FUNCTION fu_obt_sig_fec_vencimiento(
      p_cod_procesadora IN NUMBER,
      p_cod_modalidad   IN NUMBER DEFAULT NULL,
      p_fecha           IN DATE DEFAULT SYSDATE,
      p_cod_tip_cierre  IN NUMBER DEFAULT 1
      ) RETURN DATE;
   FUNCTION fu_obt_cod_dep_destino(
      p_nro_cuenta ge_cuentas.nro_cuenta%TYPE,
      p_nom_tabla  VARCHAR2
      ) RETURN NUMBER;
   PROCEDURE pr_crc_gen_clasif(p_tip_proceso IN VARCHAR2);

   PROCEDURE pr_crc_gen_movimientos;
   -- Procedimiento que generar informacion referente a las altas de cuentas pasivas
   PROCEDURE pr_crc_gen_pasivas;

   PROCEDURE pr_crc_gen_cta_basica;
   -- Procedimiento que generar informacion referente a las altas de cuentas pignoradas
   PROCEDURE pr_crc_gen_pignorados;
   FUNCTION fu_obt_mto_pignorado(p_cod_modalidad IN ge_modalidades.cod_modalidad%TYPE,
                                 p_nro_cuenta    IN ge_cuentas.nro_cuenta%TYPE) RETURN NUMBER;
   FUNCTION fu_obt_rub_con_tipo(p_nro_cuenta IN VARCHAR2,
                                       p_tip_saldo  IN VARCHAR2,
                                       p_tip_ope    IN VARCHAR2,
                                       p_sit_deuda  IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2;
   -- Procedimiento que generar informacionreferente a las altas de cuentas asentadas con rubros diversos
   PROCEDURE pr_crc_gen_rub_diversos;

   -- Procedimiento que generar informacionreferente a las altas de cuentas asentadas con rubros embargados
   PROCEDURE pr_crc_gen_pasivas_compl;

   PROCEDURE lp_obt_dat_cla_operaciones(
      p_nro_cuenta          IN ge_cla_operaciones.nro_cuenta%TYPE,
      p_dev_no_cobrado      OUT ge_cla_operaciones.dev_no_cobrado%TYPE,
      p_tot_prevision       OUT ge_cla_operaciones.tot_prevision%TYPE,
      p_tot_deu_contingente OUT ge_cla_operaciones.tot_deu_contingente%TYPE,
      p_tot_gar_computables OUT ge_cla_operaciones.tot_gar_computables%TYPE,
      p_cat_automatica      OUT ge_cla_operaciones.cat_automatica%type);
   PROCEDURE lp_obt_dat_cla_operaciones(
      p_cod_modulo          IN  ge_cla_operaciones.cod_modulo%TYPE,
      p_nro_cuenta          IN  ge_cla_operaciones.nro_cuenta%TYPE,
      p_cod_mon_iso         IN  sb_crc_operaciones_det.cod_moneda%TYPE,
      p_dev_no_cobrado      OUT ge_cla_operaciones.dev_no_cobrado%TYPE,
      p_tot_prevision       OUT ge_cla_operaciones.tot_prevision%TYPE,
      p_tot_deu_contingente OUT ge_cla_operaciones.tot_deu_contingente%TYPE,
      p_tot_gar_computables OUT ge_cla_operaciones.tot_gar_computables%TYPE,
      p_cat_automatica      OUT ge_cla_operaciones.cat_automatica%type /*,
        p_porcentaje OUT ge_cla_operaciones.porcentaje%TYPE,
        p_tot_cap_pri_prevision OUT ge_cla_operaciones.tot_cap_pri_prevision%TYPE,
        p_tot_int_pri_prevision OUT ge_cla_operaciones.tot_int_pri_prevision%TYPE,
        p_tot_cap_seg_prevision OUT ge_cla_operaciones.tot_cap_seg_prevision%TYPE,
        p_tot_int_seg_prevision OUT ge_cla_operaciones.tot_int_seg_prevision%TYPE*/
      );
   PROCEDURE pr_crc_gen_saldos;
   FUNCTION lf_obt_sal_bloqueado(p_nro_cuenta IN cc_cta_corrientes.nro_cuenta%TYPE) RETURN NUMBER;
    FUNCTION lf_obt_nro_cta_ori_vencida(p_nro_cuenta ov_cta_vencidas.nro_cuenta%TYPE) RETURN VARCHAR2; 
   FUNCTION fu_obt_cod_per_bco(p_nro_cuenta ge_cuentas.nro_cuenta%TYPE) RETURN VARCHAR2;
   FUNCTION fu_obt_ref_gar_bco_central(p_cod_garantia pr_gar_tipos.cod_garantia%TYPE) RETURN NUMBER;
   FUNCTION fu_obt_tip_operacion( p_tip_operacion IN sb_crc_saldos_det.rub_con_capital%TYPE,
                                  p_domino        IN ba_cod_referencias.dominio%TYPE ) RETURN VARCHAR2;
   FUNCTION fu_obt_operacion(p_nro_operacion sb_crc_operaciones_det.nro_operacion%TYPE,
                             p_tipo      number) RETURN VARCHAR2;
   FUNCTION fu_obt_gar_perfeccionada(p_nro_garantia IN sb_crc_garantias_nov.nro_garantia%TYPE,
                                     p_cod_persona  IN sb_crc_garantias_nov.cod_persona%TYPE) RETURN VARCHAR2;
   PROCEDURE pr_crc_gen_gar_novedades (p_nro_registro IN sb_crc_garantias_det.nro_registro%TYPE);
   PROCEDURE pr_crc_gen_garantias;
   PROCEDURE pr_ins_cta_gar_eliminadas (rp_scgel IN sb_cta_gar_eliminadas%ROWTYPE);
   PROCEDURE pr_ins_cta_garantias_nov (rp_scgel IN sb_cta_garantias_nov%ROWTYPE);
   FUNCTION  fu_obt_cod_tra_computable (p_cod_garantia IN pr_gar_tipos.cod_garantia%TYPE)RETURN NUMBER;
   PROCEDURE pr_crc_ope_gar;
   PROCEDURE pr_ins_crc_ope_no_enviados(rp_gcope sb_crc_operaciones_det%ROWTYPE);
   -- Procedimiento que genera actualizacion de vinculos
   PROCEDURE pr_crc_gen_act_vin;
   --Procedimiento que genera saldos por venta de cartera
   FUNCTION fu_cli_rel_entidad(p_cod_persona IN VARCHAR2) RETURN BOOLEAN;
   --funcion que obtiene los clientes relacionados.
   PROCEDURE pr_crc_gen_relaciones2;
   -- Archivo relaciones2
   -- Procedimiento de saldos ventas de cartera --FIELDESK-34615
   PROCEDURE pr_crc_vta_cartera(p_periodo in varchar2 default 'M'); 
   -- Procedimiento de clasifica venta de cartera --FIELDESK-34615
   PROCEDURE pr_gen_cla_vta_cartera(p_tip_proceso IN VARCHAR2 DEFAULT 'M');
   -- Procedimiento de clasifica venta de cartera codeudores --FIELDESK-34615
   PROCEDURE pr_gen_cla_vta_car_codeudoria(p_tip_proceso IN VARCHAR2 DEFAULT 'M');
   -- Funcion que retorna S o N si es una operacion vta carteras --FIELDESK-34615
   FUNCTION fu_inc_ope_vta_medidas(p_nro_documento IN sb_crc_vinculos_det.nro_documento%TYPE,
                                   p_nro_cuenta    IN ge_cta_clientes.nro_cuenta%TYPE,
                                   p_fecha         IN sb_crc_saldos_det.fecha%TYPE)
     RETURN VARCHAR2;
   -- Funcion que retorna S o N si es una operacion MT --FIELDESK-34615
   FUNCTION fu_inc_ope_medidas(p_nro_documento IN sb_crc_vinculos_det.nro_documento%TYPE,
                               p_nro_cuenta    IN ge_cta_clientes.nro_cuenta%TYPE,
                               p_fecha         IN sb_crc_saldos_det.fecha%TYPE)
     RETURN VARCHAR2;
   -- Categorizacion de codeudores --FIELDESK-34615
   PROCEDURE pr_gen_cat_codeudoria(p_fecha sb_crc_clasificaciones_det.fecha%TYPE DEFAULT NULL);
   PROCEDURE pr_crc_val_datos;
   
   -- Funcion para validar si el documento es de una unipersonal
   FUNCTION fu_es_unipersonal(p_nro_documento sb_crc_vinculos_det.nro_documento%type) RETURN VARCHAR2;
   
   FUNCTION lf_obt_cod_per_codeudor(p_cod_persona IN ba_personas.cod_persona%TYPE) RETURN VARCHAR2;
   
END pas_cri;
/

