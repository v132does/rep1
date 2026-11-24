CREATE OR REPLACE PACKAGE IT.PAG_SUE IS

V_COD_ENTE NUMBER(5);

/* Verifica si no existe algo a reprocesar o sin procesar */
PROCEDURE PR_VER_PAG_SUELDO
 (P_DATOS IN OUT VARCHAR2
 ,P_REPROCESA IN OUT VARCHAR2
 ,P_FECHA IN OUT DATE
 ,P_COD_ENTE IN NUMBER
 ,P_LUGAR IN OUT VARCHAR2
 );
/* Procesa los movimientos */
PROCEDURE PR_ACT_CRED_EMPLEADO
 (P_REPROCESO       IN OUT VARCHAR2
 ,P_COD_ENTE        IN NUMBER
 ,P_NRO_SECUENCIA   IN OUT NUMBER
 ,P_CDOFICI         IN NUMBER
 ,P_FEC_HOY         IN GE_PAG_SUELDOS.FEC_PROCESO%TYPE
 ,P_USUARIO         IN VARCHAR2
 ,P_LUGAR           IN OUT VARCHAR2
 ,P_HUBO_ERROR      OUT VARCHAR2
 ,P_TIPO_TRA_PADRE IN VARCHAR2
 ,P_HOR_MOVIMIENTO IN VARCHAR2 DEFAULT NULL
 ,P_FEC_INSERCION IN GE_PAG_SUELDOS.FEC_INSERCION%TYPE DEFAULT NULL
 , p_nro_movimiento IN bw_movimientos.nro_movimiento%type default 0 /*BWP-37-glopez*/);
/* Inserta los movimientos */
PROCEDURE LP_INS_MOV_SUELDO
 (P_HUBO_ERROR     IN OUT VARCHAR2
 ,P_HORAMOV        IN OUT VARCHAR2
 ,P_REPROCESO      IN VARCHAR2
 ,P_COD_ENTE       IN NUMBER
 ,P_NRO_SECUENCIA  IN OUT NUMBER
 ,P_LUGAR          IN OUT VARCHAR2
 ,P_CDOFICI        IN NUMBER
 ,P_FEC_HOY        IN GE_PAG_SUELDOS.FEC_PROCESO%TYPE
 ,P_USUARIO        IN VARCHAR2
 ,P_TIPO_TRA_PADRE IN VARCHAR2
 ,P_SEC_SGT_MOVIMIENTO OUT NUMBER
 ,p_nro_movimiento     IN bw_movimientos.nro_movimiento%type default 0 /*BWP-37-glopez*/);
/* Borra los datos procesados del temporal */
PROCEDURE LP_DEL_DATOS_TEMPORA
 (P_COD_ENTE IN NUMBER
 ,P_FEC_HOY IN DATE
 ,P_LUGAR IN OUT VARCHAR2
 ,P_NRO_ARCHIVO IN NUMBER DEFAULT NULL
 ,P_COD_USUARIO IN VARCHAR2 DEFAULT USER
 );
/* Verifica creditos y debitos procesados */
PROCEDURE PR_ACT_DATOS_PAGADOS
 (P_COD_ENTE IN NUMBER
 ,P_FEC_HOY IN DATE
 ,P_LUGAR IN OUT VARCHAR2
 );
 /* Verifica cuentas de Aguinaldo */
PROCEDURE PR_VER_CTA_AGUINALDO
 (P_COD_ENTE IN NUMBER
 ,P_FEC_HOY IN DATE
 ,P_LUGAR IN OUT VARCHAR2
 ,P_COD_ERROR IN OUT VARCHAR2
 ,P_CTA_OK IN OUT VARCHAR2
 ,P_NRO_CUENTA IN VARCHAR2
 ,P_NRO_ARCHIVO IN VARCHAR2
 ,P_PRO_CON_ERRORES IN VARCHAR2
 ,P_MONTO IN NUMBER
 ,P_MONEDA IN VARCHAR2
 ,P_CTA_AHORRO IN OUT VARCHAR2
 ,P_TIPO IN VARCHAR2
 ,P_CTA_AGUINALDO IN OUT VARCHAR2
 );
/* Proceso principal de insercion y generacion */
PROCEDURE PR_INS_GE_PAG_SUELDO
 (P_VERIFICA_OK IN OUT VARCHAR2
 ,P_COD_ENTE IN NUMBER
 ,P_CTADBSU IN VARCHAR2
 ,P_TRANPDB IN NUMBER
 ,P_FEC_HOY IN GE_PAG_SUELDOS.FEC_PROCESO%TYPE
 ,P_LUGAR IN OUT VARCHAR2
 ,P_CANT_ERROR OUT NUMBER
 ,P_TCRECAB OUT NUMBER
 ,P_TCREDET OUT NUMBER
 ,P_TDEBDET OUT NUMBER
 ,P_CCREDET OUT NUMBER
 ,P_NRO_ARCHIVO IN NUMBER DEFAULT NULL
 ,P_COD_USUARIO IN VARCHAR2 DEFAULT USER
 ,P_FEC_PROCESO IN GE_PAG_SUELDOS.FEC_PROCESO%TYPE DEFAULT NULL
 ,P_TIP_PAGO IN VARCHAR2 DEFAULT NULL
 );
/* Obtener los datos de la cuenta */
PROCEDURE LP_OBT_DATOS_CUENTA
 (P_NRO_CUENTA IN VARCHAR2
 ,P_TAS_PERSONALIZADA IN OUT VARCHAR2
 ,P_COD_MONEDA IN OUT VARCHAR2
 ,P_LUGAR OUT VARCHAR2
 );
/* Verifica que la cuenta de debito existe en la referencia ingresada en parametros*/
PROCEDURE LP_VER_CUENTA_DEBITO
(P_COD_ENTE IN NUMBER
,P_CTA_DEBITO IN VARCHAR2
,P_EXISTE OUT VARCHAR2);
/* Verifica que ya no se hayan insertado los mov. de sueldos de la fecha */
PROCEDURE LP_VER_DUP_MOV_DIARI
 (P_CUENTA IN VARCHAR2
 ,P_SUELDO IN NUMBER
 ,P_COD_ENTE IN NUMBER
 );
/* Obtener la max hora para todos los movimientos */
PROCEDURE LP_OBT_HORA_MOVIM
 (P_HORA IN OUT VARCHAR2
 ,P_FEC_HOY IN GE_PAG_SUELDOS.FEC_PROCESO%TYPE
 ,P_COD_TRA_PADRE IN VARCHAR2
 ,P_LUGAR OUT VARCHAR2
 );
/* Obtener cant.y monto total de pago de sueldo */
PROCEDURE LP_OBT_MONTO_PROC
 (P_SECUENCIA IN NUMBER
 ,P_COD_ENTE IN NUMBER
 ,P_CANTCRED IN OUT NUMBER
 ,P_MONTCRED IN OUT NUMBER
 ,P_LUGAR OUT VARCHAR2
 ,P_FEC_HOY IN DATE
 );
/* Obtener datos de la empresa */
PROCEDURE PR_OBT_DATOS_EMPRESA
 (P_EMPRESA         IN NUMBER
 ,P_DESCRIP         IN OUT VARCHAR2
 ,P_CTADBSU         IN OUT VARCHAR2
 ,P_TRANPDB         IN OUT NUMBER
 ,P_TRANCOM         IN OUT NUMBER
 ,P_TRANEXC         IN OUT NUMBER
 ,P_TRANPAGUI       IN OUT NUMBER
 ,P_TRANPCOM        IN OUT NUMBER
 ,P_TRANPCRE        IN OUT NUMBER
 ,P_TRANPGRA        IN OUT NUMBER  -- agregado para pago de gratificación
 ,P_DEB_EXCESO      IN OUT VARCHAR2
 ,P_FEC_INICIO      IN OUT DATE
 ,P_FEC_VENCIMIENTO IN OUT DATE
 ,P_SER_ACTIVO      IN OUT VARCHAR2
 ,P_CAN_MAX_TRANS   IN OUT NUMBER
 ,P_NRO_CTA_CONTABLE IN OUT VARCHAR2
 ,P_REFERENCIA_TXT  IN OUT VARCHAR2
 ,P_LUGAR OUT VARCHAR2
 ,P_FEC_HOY IN DATE DEFAULT SYSDATE
 ,P_COD_USUARIO IN VARCHAR2 DEFAULT USER
 );
/* Inserta en la tabla GE_PAG_SUELDOS */
PROCEDURE LP_INS_TABLA
 (P_COD_ENTE      IN NUMBER
 ,P_LUGAR         OUT VARCHAR2
 ,P_NRO_SECUENCIA OUT NUMBER
 ,P_ERROR         OUT VARCHAR2
 ,P_NRO_ARCHIVO IN NUMBER DEFAULT NULL
 ,P_COD_USUARIO IN VARCHAR2 DEFAULT USER
 ,P_FEC_HOY IN GE_PAG_SUELDOS.FEC_PROCESO%TYPE DEFAULT SYSDATE
 ,P_FEC_PROCESO IN GE_PAG_SUELDOS.FEC_PROCESO%TYPE DEFAULT NULL
 ,P_PRO_CON_ERRORES IN VARCHAR2 DEFAULT 'N');

procedure pr_set_cod_ente(p_cod_ente in number);

function fu_obt_cod_ente return number;

FUNCTION Fu_ver_cuenta (p_cta in varchar2) return varchar2;

FUNCTION Fu_dec_cuenta (p_cta in varchar2) return varchar2;

FUNCTION Fu_cod_cuenta (p_cta in varchar2) return varchar2;

FUNCTION Fu_obt_mon_rubro (p_rubro in varchar2) return varchar2;

/* LIQUIDACION DEL ANTICIPO DE SUELDOS Y O/ AGUINALDOS */
PROCEDURE PR_LIQ_ANTICIPOS(p_cod_ente in number, p_tip_tra_padre in varchar2);
/* Obtiene el Saldo Promedio de una Cuenta */
FUNCTION FU_CRE_MEN_PROMEDIO
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_FEC_INI IN DATE
 ,P_FEC_FIN IN DATE
 )
 RETURN NUMBER;

   /* Obtiene la siguiente secuencia que se utilizará para el de proceso */
   FUNCTION fu_obt_sig_nro_secuencia
   (
      p_cod_ente    IN ge_pag_sue_lotes.cod_ente%TYPE,
      p_fec_proceso IN ge_pag_sue_lotes.fec_proceso%TYPE
   ) RETURN NUMBER;

   /* Obtiene la fecha para el proceso en el día de los Pagos de Nóminas */
   FUNCTION fu_obt_fec_proceso RETURN DATE;

   /* Validar si existe un pago pendiente de procesar con los mismos importes y cantidad de registros. */
   PROCEDURE pr_val_pag_duplicado
   (
      p_cod_ente      IN ge_pag_sue_lotes.cod_ente%TYPE,
      p_fec_proceso   IN ge_pag_sue_lotes.fec_proceso%TYPE,
      p_cod_usuario   IN ge_pag_sue_lotes.usu_insercion%TYPE,
      p_mto_credito   IN OUT ge_pag_sue_lotes.mto_credito%TYPE,
      p_mto_debito    IN OUT ge_pag_sue_lotes.mto_debito%TYPE,
      p_can_registros IN OUT ge_pag_sue_lotes.cantidad%TYPE,
      p_can_lotes     IN OUT ge_pag_sue_lotes.cantidad%TYPE
   );

   /* Ejecutar los pagos en Batch, que quedaron en estado ¿Pendiente¿ de acreditación,
     será ejecutado en forma automática en el proceso de cierre diario del sistema. */
  PROCEDURE pr_pag_sue_lotes
   (
     P_TIP_PAG_SUELDO IN VARCHAR2,
     P_COD_ENTE IN ge_pag_sue_lotes.cod_ente%TYPE DEFAULT NULL,
     p_nro_secuencia IN NUMBER DEFAULT NULL
   );
  PROCEDURE pr_env_mai_sueldo
   (
     p_cod_ente IN ge_pag_sueldos.cod_ente%type,
     p_fec_proceso IN ge_pag_sueldos.fec_proceso%type,
     p_nro_secuencia IN ge_pag_sueldos.nro_secuencia%type,
     p_tipo IN varchar2
   );
   /* valida el formato de hora de cierre de pago a proveedores */
   PROCEDURE pr_ver_fmt_hor_cierre
   (
      p_hor_cierre IN ge_par_dinamicos.val_parametro%TYPE
   );
  PROCEDURE pr_pro_deb_automatico
   (
     P_COD_ENTE IN NUMBER,
     P_NRO_SECUENCIA IN OUT NUMBER,
     P_FEC_HOY IN GE_PAG_SUELDOS.FEC_PROCESO%TYPE,
     P_ERROR out varchar2);
  PROCEDURE pr_ins_errores
  (P_NRO_CUENTA IN VARCHAR2,
   P_COD_ENTE IN NUMBER,
   P_FEC_PROCESO IN DATE,
   P_NRO_SECUENCIA IN NUMBER,
   P_COD_MONEDA IN VARCHAR2,
   P_MONTO IN NUMBER,
   P_TIPO IN VARCHAR2,
   P_COD_ERROR IN VARCHAR2,
   P_MSJ_ERROR IN VARCHAR2);
   PROCEDURE pr_ins_log(p_nro_cuenta IN VARCHAR2,
                       p_monto IN NUMBER,
                       p_lugar IN VARCHAR2,
                       p_observacion IN VARCHAR2);
  --funcion para verificar que el nro doc corresponda a la cuenta del clinte
  FUNCTION FU_VER_CTA_DOCUMENTO
    (p_nro_documento varchar2,
     p_cuenta varchar2)
     return varchar2;
END PAG_SUE;
/

