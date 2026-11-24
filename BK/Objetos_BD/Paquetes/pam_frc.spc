CREATE OR REPLACE PACKAGE IT.PAM_FRC IS

  -- Proposito: Operativa + contabilizacion cuentas producto FLI/REPO (138/139/140)

  ---------------------------------------------------------------------------
  -- Manejo de errores
  ---------------------------------------------------------------------------
  FUNCTION fu_obt_cod_error RETURN NUMBER;
  FUNCTION fu_obt_msj_error RETURN VARCHAR2;

  ---------------------------------------------------------------------------
  -- Datos de cabecera MT547 / MT546
  ---------------------------------------------------------------------------
  TYPE t_dat_cuenta_fli_repo IS RECORD (
    monto           NUMBER,
    mto_interes     NUMBER,
    deal_total      NUMBER,
    fec_inicio      DATE,
    fec_vencimiento DATE,
    tasa            NUMBER,
    cod_moneda      VARCHAR2(3)
  );

  ---------------------------------------------------------------------------
  -- Resolver ref_543 (Rxxxxx/543)
  ---------------------------------------------------------------------------
  FUNCTION fu_res_ref_543 (
    p_cod_msj_swift   IN VARCHAR2,
    p_nro_referencia  IN VARCHAR2,
    p_ref_543         IN VARCHAR2 DEFAULT NULL,
    p_msj_swift       IN CLOB DEFAULT NULL
  ) RETURN VARCHAR2;

  ---------------------------------------------------------------------------
  -- Capital, fechas, interes y moneda desde MT547 (alta) o MT546 (conversion)
  ---------------------------------------------------------------------------
  FUNCTION fu_obt_dat_cuenta (
    p_nro_referencia IN VARCHAR2
  ) RETURN t_dat_cuenta_fli_repo;

  ---------------------------------------------------------------------------
  -- Handler operativa desde pas_dep (506 alta, 546 conversion, 545 cierre)
  ---------------------------------------------------------------------------
  PROCEDURE pr_pro_cta_msj_recibido (
    p_cod_msj_swift  IN VARCHAR2,
    p_nro_referencia IN VARCHAR2,
    p_ref_543        IN VARCHAR2 DEFAULT NULL,
    p_tip_producto   IN VARCHAR2 DEFAULT NULL,
    p_msj_swift      IN CLOB DEFAULT NULL
  );

  ---------------------------------------------------------------------------
  -- Contabilizacion — API publica (composites)
  ---------------------------------------------------------------------------

  -- Monto a asentar en baja/alta DEAL: FLI=capital; REPO=capital+interes
  FUNCTION fu_obt_monto_baja (
    p_cod_modalidad IN NUMBER,
    p_monto_capital IN NUMBER,
    p_monto_interes IN NUMBER DEFAULT 0
  ) RETURN NUMBER;

  -- Inserta movs de alta producto: 815+818; en REPO tambien 819 (interes)
  PROCEDURE pr_ins_mov_alta_producto (
    p_nro_cuenta       IN VARCHAR2,
    p_cod_modalidad    IN NUMBER,
    p_monto            IN NUMBER,
    p_mto_interes      IN NUMBER DEFAULT 0,
    p_cod_moneda       IN VARCHAR2 DEFAULT 'GS',
    p_fecha_movimiento IN DATE DEFAULT NULL,
    p_hora_movimiento  IN ge_movimientos.hora%TYPE DEFAULT NULL,
    p_nro_secuencia    IN OUT NUMBER
  );

  -- Inserta movs de baja producto: 816+820; en REPO tambien 822 (interes a resultado)
  PROCEDURE pr_ins_mov_baja_producto (
    p_nro_cuenta       IN VARCHAR2,
    p_cod_modalidad    IN NUMBER,
    p_monto            IN NUMBER,
    p_mto_interes      IN NUMBER DEFAULT 0,
    p_cod_moneda       IN VARCHAR2 DEFAULT 'GS',
    p_fecha_movimiento IN DATE DEFAULT NULL,
    p_hora_movimiento  IN ge_movimientos.hora%TYPE DEFAULT NULL,
    p_nro_secuencia    IN OUT NUMBER
  );

  -- Inserta un mov de garantia por titulo: 823 cesion (alta) o 824 liberacion (baja)
  PROCEDURE pr_ins_mov_garantia (
    p_nro_cuenta       IN VARCHAR2,
    p_cod_modalidad    IN NUMBER,
    p_monto            IN NUMBER,
    p_cod_moneda       IN VARCHAR2 DEFAULT 'GS',
    p_cod_modalidad_pd IN NUMBER,
    p_es_alta          IN VARCHAR2,
    p_fecha_movimiento IN DATE DEFAULT NULL,
    p_hora_movimiento  IN ge_movimientos.hora%TYPE DEFAULT NULL,
    p_nro_secuencia    IN OUT NUMBER
  );

  -- Obtiene cuenta producto (nro, montos, moneda) por ref_543 + modalidad + estado
  PROCEDURE pr_obt_cta_producto (
    p_ref_543           IN VARCHAR2,
    p_cod_modalidad     IN NUMBER,
    p_estado            IN VARCHAR2,
    p_nro_cuenta        OUT md_cta_documentos.nro_cuenta%TYPE,
    p_monto             OUT md_cta_documentos.monto%TYPE,
    p_mto_interes       OUT md_cta_documentos.mto_interes%TYPE,
    p_cod_moneda        OUT md_cta_documentos.cod_moneda%TYPE
  );

  -- Orquesta contabilizacion post-operativa segun MT: 506 alta, 545 baja, 546 conversion
  PROCEDURE pr_pro_con_msj_recibido (
    p_cod_msj_swift  IN VARCHAR2,
    p_nro_referencia IN VARCHAR2,
    p_ref_543        IN VARCHAR2 DEFAULT NULL,
    p_fecha          IN DATE DEFAULT NULL,
    p_hora           IN ge_movimientos.hora%TYPE DEFAULT NULL,
    p_nro_secuencia  IN OUT NUMBER,
    p_nro_cuenta     IN VARCHAR2 DEFAULT NULL,
    p_cod_modalidad  IN NUMBER DEFAULT NULL
  );

END PAM_FRC;
/
