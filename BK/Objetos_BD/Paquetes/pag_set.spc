CREATE OR REPLACE PACKAGE IT.PAG_SET IS

  -- obtener el codigo de cuenta a traves de un codigo de impuesto
  FUNCTION fu_obt_cod_cuenta(p_cod_impuesto IN ge_set_impuestos.cod_impuesto%TYPE)
    RETURN VARCHAR2;

  PROCEDURE pr_act_estado(p_ruc           IN VARCHAR2,
                          p_nro_boleta    IN VARCHAR2,
                          p_fec_documento IN DATE,
                          p_estado        IN VARCHAR2,
                          p_xml           IN xmltype,
                          p_can_reintento IN NUMBER DEFAULT 0);
  
  -- procedimiento para llamar al API para actualizar las OTs
  PROCEDURE pr_ot_actualizar;

  -- procedimiento para establecer la secuencia de OT por contingencia
  PROCEDURE pr_ot_establecer(p_nro_secuencia IN NUMBER, p_tip_ot IN NUMBER);

  -- Funcion para guardarOT o consultarOT , invoca al gateway de yaguarete
  FUNCTION fu_env_ot(p_fecha         IN DATE,
                     p_nro_documento IN ge_set_pagos.nro_orden%TYPE,
                     p_tip_ot        IN ge_set_pagos.tip_orden%TYPE,
                     p_importe       IN ge_set_pagos.monto%TYPE,
                     p_cta_bcp       IN ge_set_impuestos.cod_cuenta%TYPE,
                     p_consulta      IN VARCHAR2 DEFAULT 'S')
    RETURN typ_postrespuesta;

  PROCEDURE PR_GEN_PAG_SET_OT(p_nro_orden in ge_set_ordenes.nro_orden%type DEFAULT NULL);
  
  FUNCTION fu_val_api(p_api_key IN VARCHAR2) RETURN VARCHAR2;

  -- obtener tipo OT
  FUNCTION fu_obt_tip_ot(p_cod_impuesto IN ge_set_impuestos.cod_impuesto%TYPE)
    RETURN NUMBER;

END PAG_SET;
/

