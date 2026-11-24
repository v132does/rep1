CREATE OR REPLACE PACKAGE IT.pag_evr IS
  --Paquete para Evaluación de Riesgos del Cliente
  --PLD: Prevención de Lavado de Dinero.
  --FT: Financiamiento al Terrorismo.
  --FP: Financiamiento de la Proliferación.
  
  -- Función que retorna la fecha de vencimiento según el riesgo y fecha de evaluación
  --- Se utiliza cuando el usuario cargue por pantalla la fecha de inicio y se invoca a esta función
  FUNCTION fu_cal_venc_perfil(p_cod_riesgo     IN VARCHAR2,
                              p_fec_evaluacion IN DATE DEFAULT SYSDATE)
    RETURN DATE;

  -- Función que obtiene el código de riesgo actual del cliente
  FUNCTION fu_obt_riesgo_cli(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN VARCHAR2;
    
  -- Función que muestra el riesgo actual del cliente
  --- Se utiliza para poder visualizar en la pantalla principal
  FUNCTION fu_ver_riesgo_cli(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN VARCHAR2;

  -- Función que muestra el riesgo actual del cliente
  --- Se utiliza para poder visualizar en la pantalla principal
  FUNCTION fu_ver_venc_perfil(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN DATE;

  -- Procedimiento que actualiza masivamente cr_per_tip_operaciones en base a lo importado
  PROCEDURE pr_pro_act_riesgo(p_cod_persona    IN VARCHAR2 DEFAULT NULL,
                              p_cod_riesgo     IN VARCHAR2,
                              p_fec_evaluacion IN DATE DEFAULT SYSDATE,
                              p_codigo_error   OUT NUMBER,
                              p_mensaje_error  OUT VARCHAR2);

END pag_evr;
/
