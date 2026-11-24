CREATE OR REPLACE PACKAGE IT.PAS_LCR IS

  PROCEDURE PR_LIMPIAR_TMP;

  PROCEDURE PR_LIMPIAR_FINAL(P_FECHA_PROCESO IN DATE);

  PROCEDURE PR_EJECUTAR_SQL_ITEM(p_sql           CLOB,
                                 p_nro_item      NUMBER,
                                 p_id_padre      NUMBER,
                                 p_agrupador     NUMBER,
                                 --p_orden         NUMBER,
                                 p_porcentaje    NUMBER,
                                 p_fecha_proceso DATE,
                                 p_id_bcp        number,
                                 p_reporta       varchar2,
                                 p_cotizacion    number);

  PROCEDURE PR_TMP_A_FINAL(p_fecha_proceso IN DATE);

  PROCEDURE PR_INSERTA_ITEM_FINAL(p_fecha_proceso IN DATE,
                                  p_nro_item      IN NUMBER);

  PROCEDURE PR_GEN_DATOS(p_fecha_proceso IN DATE, p_bal_cerrado in varchar2);

  PROCEDURE PR_GEN_INFORME(p_fecha_proceso  IN DATE,
                           p_nombre_archivo OUT VARCHAR2);

  PROCEDURE PR_PRO_GEN_LCR;

  PROCEDURE PR_CARGAR_LIQ_INV_TMP (p_fecha_proceso IN DATE);
  
  PROCEDURE PR_GEN_BALANCE(P_FECHA_PROCESO IN DATE);
  
  PROCEDURE pr_totaliza_item (
     p_fec_proceso IN DATE,
     p_nro_item_padre IN NUMBER,
     p_items_hijos IN VARCHAR2
  );

  PROCEDURE pr_totaliza_saldos_lcr (
     p_fec_proceso IN DATE
  );

  PROCEDURE pr_calcula_items_lcr (
     p_fec_proceso IN DATE
  );

  PROCEDURE PR_CARGAR_SAL_EFE (p_fecha_proceso IN DATE);

END PAS_LCR;
/
