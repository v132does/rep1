CREATE OR REPLACE PACKAGE IT.PAG_CAR is

  -- Created : 27/12/2007 03:21:33 p.m.
  -- Purpose : paquete que maneja todo el esquema de cobro de cargos.

  -- Public type declarations
  --type <TypeName> is <Datatype>;

  -- Public constant declarations
  --<ConstantName> constant <Datatype> := <Value>;

  -- Public variable declarations
  --<VariableName> <Datatype>;
  g_monto number(18,2);
  g_mto_cargo number(18,2);

  -- Public function and procedure declarations
  --procedimiento que recupera los cargos
  PROCEDURE PR_OBT_CARGOS
   (P_COD_OFI_ORIGEN IN GE_CUENTAS.COD_OFICINA%TYPE
   ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
   ,P_COD_MONEDA IN GE_CUENTAS.COD_MONEDA%TYPE
   ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
   ,P_COD_MODULO IN GE_CUENTAS.COD_MODULO%TYPE
   ,P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE
   ,P_COD_TRA_CARGO IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
   ,P_IVA_INCLUIDO  IN VARCHAR2 DEFAULT 'S'
   ,P_COD_TAS_CARGO OUT GE_MOVIMIENTOS.COD_TASA%TYPE
   ,P_VAL_TAS_CARGO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
   ,P_VAL_CARGO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
   ,P_COD_TRA_IMPUESTO OUT GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
   ,P_COD_TAS_IMPUESTO OUT GE_MOVIMIENTOS.COD_TASA%TYPE
   ,P_VAL_TAS_IMPUESTO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
   ,P_VAL_IMPUESTO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
   );
  --procedimiento que realiza los débitos, créditos
  PROCEDURE PR_DEB_CRE_BATCH
   (P_COD_DEB_CRE IN GE_DEB_CRE_BATCH.COD_DEB_CRE_BATCH%TYPE
   ,P_NRO_CUENTA  IN VARCHAR2 DEFAULT NULL
   );
  --procedimiento que alimenta al listado
  PROCEDURE PR_DEB_CRE_BATCH_TMP
  (p_parametros in varchar2
   );
  --Funcion que devuelve modulo,modalidad,transaccion del cargo
  PROCEDURE FU_OBT_PAR_CARGO
  (P_COD_DEB_CRE    IN GE_DEB_CRE_BATCH.COD_DEB_CRE_BATCH%TYPE
  ,P_COD_MODULO    OUT GE_CUENTAS.COD_MODULO%TYPE
  ,P_COD_MODALIDAD OUT GE_CUENTAS.COD_MODALIDAD%TYPE
  ,P_COD_TRANSACCION OUT GE_TRANSACCIONES.COD_MODALIDAD%TYPE
   );
   --Procedimiento que se encarga del cobro de cuota anual batch en tarjetas
   PROCEDURE PR_CUO_ANU_TARJETAS(P_COD_DEB_CRE IN GE_DEB_CRE_BATCH.COD_DEB_CRE_BATCH%TYPE);
end pag_car;
/

