CREATE OR REPLACE PACKAGE IT.PAB_DEP is

  -- Purpose : Procedimiento que genera los movimientos por deposito interno.

  /* Realiza el calculo de los Depositos Internos.*/
  PROCEDURE PR_GEN_DEP_INTERNOS;
  
  /* Procedimiento que inserta asientos manuales. */
  PROCEDURE PR_INS_ASI_MANUALES(rp_bamde IN cb_asientos_det%ROWTYPE);
  
  /* Reversa los asientos de Depositos Internos. */
  PROCEDURE PR_REV_DEP_INTERNOS;
  
  /* Genera los Asientos Manuales de Deposito Interno. */
  PROCEDURE PR_GEN_MOV_CONTABLES;
  
  /* Verifica que exista movimientos ya generados de Dep. Internos para realizar el Inicio de Día. */
  PROCEDURE PR_VAL_DEP_INTERNOS;
  
  /* Obtiene el saldo promedio de las cuentas operativas por oficina.*/
  FUNCTION FU_OBT_MTO_DEP_INTERNOS(P_ANHO        IN GE_CTA_DEP_INTERNOS_DET.ANO%TYPE,
                                   P_MES         IN GE_CTA_DEP_INTERNOS_DET.MES%TYPE,
                                   P_COD_OFICINA IN GE_CUENTAS.COD_OFICINA%TYPE,
                                   P_COD_MONEDA  IN GE_CUENTAS.COD_MONEDA%TYPE)
  RETURN NUMBER;
  
  /* Realiza el calculo de los Depositos Internos por Cuenta de Clientes.*/
  PROCEDURE PR_GEN_CTA_DEP_INTERNO;
  
  /* Genera los Asientos Manuales de Deposito Interno por Cuenta de Clientes. */
  PROCEDURE PR_GEN_MOV_CTA_CLIENTE;

END PAB_DEP;
/

