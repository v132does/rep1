CREATE OR REPLACE PACKAGE IT.PAB_IVA IS

/* retorna el punto de expedicion para el tipo de comprobante */
FUNCTION fu_obt_pun_expedicion
   (  p_tip_comprobante IN VARCHAR2,
      p_cod_oficina     IN ba_oficinas.cod_oficina%TYPE DEFAULT NULL,
      p_cod_modulo      IN ba_modulos.cod_modulo%TYPE DEFAULT NULL,
      p_cod_modalidad   IN ge_modalidades.cod_modalidad%TYPE DEFAULT NULL
   ) RETURN NUMBER;

/* Genera libro venta de las reversiones. */
PROCEDURE PR_GEN_NOT_CREDITO
 (P_COD_PERSONA IN VARCHAR2 := null
 ,P_FECHA IN DATE := null
 ,P_HORA IN VARCHAR2 := null
 ,P_COD_USUARIO IN VARCHAR2 := null
 );
/* Insertar el libro de venta cabecera. */
PROCEDURE PR_INS_LIB_VEN_CAB
 (RP_BLVEN IN CB_LIB_VENTAS%ROWTYPE
 );
/* Insertar detalle del Libro Venta */
PROCEDURE PR_INS_LIB_VEN_DET
 (RP_BLVDE IN CB_LIB_VENTAS_DET%ROWTYPE
 );
/* Genera libro venta de las operaciones. */
PROCEDURE PR_GEN_FACTURA
 (P_COD_PERSONA IN VARCHAR2 := null
 ,P_FECHA IN DATE := null
 ,P_HORA IN varchar2 := null
 ,P_COD_USUARIO IN VARCHAR2 := null
 );
/* Función que obtiene la secuencia anterior */ 
FUNCTION FU_OBT_SEC_ANTERIOR(p_fecha in date,
                              p_hora in varchar2,
                              p_cod_usuario in varchar2,
                              p_nro_secuencia in number)
 return number;
 
/* Insertar detalle del Libro Venta */
PROCEDURE PR_INS_LIB_VEN_TMP
 (RP_BLVDT IN CB_LIB_VENTAS_DET_TMP%ROWTYPE
 );
/* Genera el libro de ventas temporal. */
PROCEDURE PR_GEN_LIB_VTA_TMP
 (P_COD_PERSONA IN VARCHAR2 DEFAULT NULL
 ,P_FECHA IN DATE DEFAULT NULL
 ,P_HORA IN VARCHAR2 DEFAULT NULL
 ,P_COD_USUARIO IN VARCHAR2 DEFAULT NULL
 ,P_NRO_SECUENCIA IN NUMBER DEFAULT NULL
 );
/* Verifica si un movimiento es de iva o no */
FUNCTION FU_MOV_CON_IVA
 (P_COD_MODULO IN NUMBER
 ,P_COD_MODALIDAD IN NUMBER
 ,P_COD_TRANSACCION IN NUMBER
 ,P_COD_TIP_MOV_RUBRO IN VARCHAR2 := null
 ,P_COD_RUBRO IN VARCHAR2 := null
 )
 RETURN VARCHAR2;
 /* Verifica si un movimiento es de cargo */
FUNCTION FU_MOV_CARGO
 (P_COD_MODULO IN NUMBER
 ,P_COD_MODALIDAD IN NUMBER
 ,P_COD_TRANSACCION IN NUMBER
 ,P_COD_TIP_MOV_RUBRO IN VARCHAR2 := null
 ,P_COD_RUBRO IN VARCHAR2 := null
 )
 RETURN VARCHAR2;
 /* RETORNA LA PERSONA QUE PAGO EL IVA */
PROCEDURE PR_OBT_DAT_PERSONA
 (P_COD_MOD_PADRE IN NUMBER,
  P_COD_MAD_PADRE IN NUMBER,--AP3035
  P_COD_USUARIO IN VARCHAR2,
  P_FECHA IN DATE,
  P_HORA IN VARCHAR2,
  P_NRO_SECUENCIA IN NUMBER,
  P_NRO_CUENTA IN VARCHAR2,
  P_NRO_DOCUMENTO2 IN VARCHAR2,
  P_REFERENCIA IN VARCHAR2,
  P_COD_MONEDA IN VARCHAR2,
  P_MTO_IVA IN NUMBER,
  P_VAL_TASA IN NUMBER,
  P_COD_PERSONA in OUT VARCHAR2,
  P_NRO_DOCUMENTO OUT VARCHAR2,
  P_NOM_COMPLETO  OUT VARCHAR2);
 -- genera los movimientos en tmp por los asientos manuales del dia
 PROCEDURE PR_GEN_LIB_VTA_TMP_ASI;
 -- generacion del tmp a partir de movimientos de tarjetas de credito
 PROCEDURE PR_GEN_LIB_VTA_TMP_TAR;
 -- PROCEDIMIENTO PARA CORRER EN EL CIERRE
 PROCEDURE PR_PRO_CIERRE;
/* Genera libro venta de las operaciones y retorna la factura */
FUNCTION FU_GEN_FACTURA
 (P_COD_PERSONA IN VARCHAR2
 ,P_FECHA IN DATE default null
 ,P_HORA IN varchar2 default null
 ,P_COD_USUARIO IN VARCHAR2 default null
 )
 RETURN VARCHAR2;
  /* Genera libro venta de las operaciones y retorna la nota de credito */
FUNCTION FU_GEN_NOT_CREDITO --BBVASOP-1209
 (P_COD_PERSONA IN VARCHAR2
 ,P_FECHA       IN DATE     DEFAULT NULL
 ,P_HORA        IN VARCHAR2 DEFAULT NULL
 ,P_COD_USUARIO IN VARCHAR2 DEFAULT NULL
 )
 RETURN VARCHAR2;
/* OBTENGO EL CODIGO DE PERSONA */
FUNCTION  FU_OBT_COD_PERSONA
 (P_COD_MOD_PADRE IN NUMBER,
  P_COD_USUARIO IN VARCHAR2,
  P_FECHA IN DATE,
  P_HORA IN VARCHAR2,
  P_NRO_SECUENCIA IN NUMBER,
  P_NRO_CUENTA IN VARCHAR2,
  P_REFERENCIA IN VARCHAR2,
  P_COD_MONEDA IN VARCHAR2,
  P_MTO_IVA IN NUMBER,
  P_VAL_TASA IN NUMBER)
  RETURN VARCHAR2;

/* Recupera y actualiza el nro. de factura utilizado */
PROCEDURE PR_OBT_NRO_FACTURA
 (p_cod_oficina in number
 ,p_fecha in date
 ,p_tip_comprobante in varchar2
 ,p_nro_factura out number
 ,p_nro_timbrado out varchar2
 ,p_fec_timbrado out date);

FUNCTION FU_OBT_ULT_NRO_EMITIDO
 (p_cod_oficina in number
 ,p_tip_comprobante in varchar2)
RETURN NUMBER;

FUNCTION FU_MOV_FACTURADO
 (P_FECHA IN DATE,
  P_HORA IN VARCHAR2,
  P_COD_USUARIO IN VARCHAR2)
RETURN BOOLEAN;

 /* devuelve el codigo del rubro correspondiente al cargo asociado al iva */
FUNCTION FU_OBT_RUB_CARGO(p_fecha in date, p_cod_usuario in varchar2, p_hora in varchar2, p_nro_secuencia in number)
 RETURN VARCHAR2;

 /* Actualiza los ajustes IVA de movimientos realizados en moneda extranjera.*/
PROCEDURE PR_ACT_EQU_LOCAL(P_FECHA IN DATE            DEFAULT NULL,
                        P_HORA IN VARCHAR2         DEFAULT NULL,
                        P_COD_USUARIO IN VARCHAR2  DEFAULT NULL);

/*Procedimiento que inserta en la tabla de observaciones los registros con errores */
PROCEDURE PR_INS_OBSERVACIONES(P_FEC_TMP   IN cb_lib_ventas_det_tmp.Fecha%type       DEFAULT NULL,
                               P_HOR_TMP   IN cb_lib_ventas_det_tmp.hora%type        DEFAULT NULL,
                               P_USU_TMP   IN cb_lib_ventas_det_tmp.cod_usuario%type DEFAULT NULL,
                               P_REVERSADO IN cb_lib_ventas_det_tmp.reversado%type   DEFAULT NULL);
                               
/* Insertar detalle del Libro Compra Temporal */
PROCEDURE PR_INS_LIB_COM_TMP
 (RP_BLCDT IN CB_LIB_COMPRAS_DET_TMP%ROWTYPE
 ); 

/* Genera Libro Venta/Compra de las Operaciones de Cambios. */
PROCEDURE PR_GEN_FAC_CAMBIO
 (P_COD_PERSONA IN VARCHAR2 := null
 ,P_FECHA IN DATE := null
 ,P_HORA IN varchar2 := null
 ,P_COD_USUARIO IN VARCHAR2 := null
 );
 
/* Insertar detalle del Libro Compra */
PROCEDURE PR_INS_LIB_COM_DET
 (RP_BLCDE IN CB_LIB_COMPRAS_DET%ROWTYPE
 ); 
 
 /* Genera libro venta y compra de operaciones de cambios, retorna nro de factura */
FUNCTION FU_GEN_FAC_CAMBIO
 (P_COD_PERSONA IN VARCHAR2
 ,P_FECHA IN DATE default null
 ,P_HORA IN varchar2 default null
 ,P_COD_USUARIO IN VARCHAR2 default null
 )
 RETURN VARCHAR2;
 
/* Genera compra por INR, retorna nro de factura */
FUNCTION FU_GEN_FAC_INR
 (P_COD_PERSONA IN VARCHAR2
 ,P_FECHA IN DATE default null)
 RETURN VARCHAR2;
END PAB_IVA;
/

