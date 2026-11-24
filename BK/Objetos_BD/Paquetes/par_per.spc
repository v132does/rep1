CREATE OR REPLACE PACKAGE IT.par_per IS
  g_cod_persona       ba_personas.cod_persona%TYPE;
  g_cod_modulo        ba_modulos.cod_modulo%TYPE;
  g_cod_modalidad     ge_modalidades.cod_modalidad%TYPE;
  g_mto_solicitud     ge_solicitudes.monto%TYPE;
  g_mon_local         ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
  g_nro_solicitud     pr_solicitudes.nro_solicitud%TYPE;
  g_mto_max_solicitud ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('MAX_MTO_SOL_CASADO');
  salir EXCEPTION;
  error EXCEPTION;
  g_ban_inf_laboral  VARCHAR2(1) := 'N'; --variable que indica que ya emitio mensaje que falta inf.laboral
  g_ban_tip_vivienda VARCHAR2(1) := 'N'; --variable que indica que ya emitio mensaje que falta tip.vivienda
  ------ '62.255.100.11' 4466-- desarrollo
  ---'192.168.1.232' 4466-- produccion
  g_servidor   VARCHAR2(20) := fug_obt_pardinamico('DIP_SCK_CON_ANTECEDENTES');
  g_puerto     NUMBER(4) := fug_obt_pardinamico('PTO_SCK_CON_ANTECEDENTES');
  g_tie_espera NUMBER(4) := NULL;
  --Funcion Principal
  FUNCTION fu_val_dat_personas(p_cod_persona   IN ba_personas.cod_persona%TYPE,
                               p_cod_modulo    IN ba_modulos.cod_modulo%TYPE,
                               p_cod_modalidad IN ge_modalidades.cod_modalidad%TYPE,
                               p_mto_solicitud IN pr_solicitudes.monto%TYPE,
                               p_ind_evaluacion IN pr_solicitudes.ind_evaluacion%type default 'S')
    RETURN BOOLEAN;
  FUNCTION fu_val_per_fisicas(p_cod_persona   IN ba_personas.cod_persona%TYPE,
                              p_cod_modulo    IN ba_modulos.cod_modulo%TYPE,
                              p_cod_modalidad IN ge_modalidades.cod_modalidad%TYPE,
                              p_mto_solicitud IN pr_solicitudes.monto%TYPE)
    RETURN BOOLEAN;
  FUNCTION fu_val_per_laborales(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN BOOLEAN;
  FUNCTION fu_val_per_financieros(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN BOOLEAN;
  FUNCTION fu_val_per_propiedades(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN BOOLEAN;
  FUNCTION fu_val_per_patrimonios(p_cod_persona IN ba_personas.cod_persona%TYPE,
                                  p_mon_local   IN ba_monedas.cod_moneda%TYPE)
    RETURN BOOLEAN;
  FUNCTION fu_sol_ver_personas(p_cod_persona   IN ba_personas.cod_persona%TYPE,
                               p_cod_modulo    IN ba_modulos.cod_modulo%TYPE,
                               p_cod_modalidad IN ge_modalidades.cod_modalidad%TYPE)
    RETURN BOOLEAN;
  FUNCTION fu_obt_per_nominas(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN VARCHAR2;
  FUNCTION fu_val_verificaciones(p_cod_persona   IN ba_personas.cod_persona%TYPE,
                                 p_nro_solicitud pr_solicitudes.nro_solicitud%TYPE DEFAULT NULL,
                                 p_cod_modulo    ba_modulos.cod_modulo%TYPE DEFAULT NULL,
                                 p_cod_modalidad ge_modalidades.cod_modalidad%TYPE DEFAULT NULL)
    RETURN VARCHAR2;
  PROCEDURE pr_ins_err_tablas(p_tabla        IN ge_sol_ver_personas_det_tmp.tabla%TYPE,
                              p_campo        IN ge_sol_ver_personas_det_tmp.campo%TYPE,
                              p_error        IN ge_sol_ver_personas_det_tmp.error%TYPE,
                              p_ins_registro OUT VARCHAR2);
  PROCEDURE pr_err_mensajes(p_mensaje IN VARCHAR2);
  --Fase 2
  FUNCTION fu_ver_reg_antecedentes(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN BOOLEAN;
  FUNCTION fu_obt_dat_infocheck(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN VARCHAR2;
  FUNCTION fu_obt_dat_informconf(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN VARCHAR2;
  FUNCTION fu_obt_dat_crc(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN BOOLEAN;
  --Fase 3
  FUNCTION fu_obt_ult_mto_nomina(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN NUMBER;
  PROCEDURE pr_gen_rie_evaluaciones(p_nro_solicitud IN pr_solicitudes.nro_solicitud%TYPE,
                                    p_nro_intento   OUT NUMBER,
                                    p_mensaje       OUT VARCHAR2,
                                    p_cod_modulo    IN ba_modulos.cod_modulo%TYPE,
                                    p_cod_modalidad IN ge_modalidades.cod_modalidad%TYPE);
  PROCEDURE pr_act_pre_aprobado( p_nro_solicitud     IN ge_pro_pre_aprobados.nro_solicitud%TYPE,
                                 p_cod_persona       IN ge_pro_pre_aprobados.cod_persona%TYPE,
                                 p_cod_modulo        IN ge_pro_pre_aprobados.cod_modulo%TYPE,
                                 p_cod_modalidad     IN ge_pro_pre_aprobados.cod_modalidad%TYPE,
                                 p_cod_sub_modalidad IN ge_pro_pre_aprobados.cod_sub_modalidad%TYPE default null -- PCCFPPTC-1 -- Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core -- 10/2016 --
                                );

   -- Valida los datos obligatorios por código de actividad primaria del cliente.
   FUNCTION fu_val_dat_segmentacion(p_cod_persona    IN ba_personas.cod_persona%TYPE,
                                    p_cod_modulo     IN ba_modulos.cod_modulo%TYPE,
                                    p_cod_modalidad  IN ge_modalidades.cod_modalidad%TYPE,
                                    p_mto_solicitud  IN pr_solicitudes.monto%TYPE)
   RETURN BOOLEAN;

   FUNCTION fu_obt_pro_mto_nomina(p_cod_persona IN ba_personas.cod_persona%TYPE,
                                  p_fec_calculo IN ge_calendarios.fec_actual%type default null)
    RETURN NUMBER;

  FUNCTION fu_obt_nro_cta_ampliacion(p_nro_solicitud IN ta_sol_lineas.nro_solicitud%TYPE)
    RETURN VARCHAR2;

  FUNCTION fu_obt_des_ale_scoring(p_cod_modulo number, p_cod_modalidad number, p_cod_alerta varchar2)
    RETURN VARCHAR2;

  FUNCTION fu_obt_dat_inf_economico(p_nro_solicitud number,
                                    p_nro_intento   number,
                                    p_nro_secuencia number,
                                    p_cod_modulo    number,
                                    p_cod_modalidad number)
    RETURN TYP_INFECONOMICOS;
  /**
   * Obtiene el monto de los ingresos por tipo de concepto
   * @param p_cod_persona codigo de persona del cliente
   * @param p_tip_ingreso codigo tipo del ingreso que se quiere saber
   */
  FUNCTION fu_obt_ingresos(p_cod_persona IN VARCHAR2,
                           p_tip_ingreso IN VARCHAR2,
                           p_nro_secuencia in NUMBER DEFAULT NULL) RETURN NUMBER;
  /**
   * Calcula el monto de la maxima cuota mas cargos
   * @param p_nro_solicitud numero solicitud del prestamo
   */
  FUNCTION fu_cal_cuota(p_nro_solicitud IN NUMBER) RETURN NUMBER;
END;
/

