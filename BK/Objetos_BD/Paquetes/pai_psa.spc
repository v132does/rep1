CREATE OR REPLACE PACKAGE IT.PAI_PSA IS
   -- Paquete utilizado para las interfaces ITGF y la herramienta PSAML
   -- Fecha: 01/09/2021
   -- Autor: Sergio Servín Arce
   ---------------------------------------------------------------------------
   -- FUNCIONES

   -- Función que obtiene la fecha de proceso
   FUNCTION FU_OBT_FEC_PROCESO RETURN DATE;

   -- Función que retorna el total activo o pasivo
   FUNCTION FU_OBT_SAL_CLI(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                           P_TIPO        VARCHAR2) RETURN NUMBER;
   FUNCTION FU_OBT_EST_CIVIL(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                             P_TIPO        IN VARCHAR2) RETURN VARCHAR2;

   -- Función que retorna el nombre del la persora Física o Juridica
   FUNCTION FU_OBT_NOM_CLIENTE(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                               P_TIPO        VARCHAR2,
                               P_ORDEN       NUMBER) RETURN VARCHAR2;

   -- Función que retorna el nombre del la persora Física o Juridica
   FUNCTION FU_OBT_APE_CLIENTE(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                               P_TIPO        VARCHAR2,
                               P_ORDEN       NUMBER) RETURN VARCHAR2;

   -- Función que retorna la descripción del tipo de documento
   FUNCTION FU_OBT_DES_TIP_DOC(P_COD_TIP_DOCUMENTO IN BA_TIP_DOCUMENTOS.COD_TIP_DOCUMENTO%TYPE)
      RETURN BA_TIP_DOCUMENTOS.DESCRIPCION%TYPE;

   -- Función que retorna la descripción de la actividad
   FUNCTION FU_OBT_DES_ACTIVIDAD(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                                 P_TIP_PERSONA VARCHAR2)
      RETURN BA_TIP_DOCUMENTOS.DESCRIPCION%TYPE;

   -- Función que retorna la fecha de nacimento en caso de persona física y la fecha de apertura en coso de persona jurídica
   FUNCTION FU_OBT_FEC_NACIMIENTO(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                                  P_TIP_PERSONA VARCHAR2) RETURN date;

   -- Función que retorna el código de pais ISO en caso de que el tipo de busqueda sea "N" retorna el pais de la nacionalizacion, sino retorna el país de la dirección principal
   FUNCTION FU_OBT_COD_ISO_PAIS(P_COD_PERSONA  IN BA_PERSONAS.COD_PERSONA%TYPE,
                                P_TIP_BUSQUEDA VARCHAR2,
                                P_COD_PAIS     BA_PAISES.COD_PAIS%TYPE)
      RETURN GE_AST_PAISES.COD_AST_PAIS%TYPE;

   -- Función que retorna la dirección principal del cliente
   FUNCTION FU_OBT_DIR_PRINCIPAL(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                                 p_tipo        in varchar2) RETURN VARCHAR2;

   -- Función que obtiene la dirección principal
   FUNCTION FU_OBT_TEL_PRINCIPAL(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                                 p_tipo        in varchar2) RETURN VARCHAR2;

   -- Funcion que retorna la descripción del departamento, de la ciudad o el cód. Postal dependiento del tipo de busqueda
   FUNCTION FU_OBT_DES_DEP_CIU_POS(P_COD_PERSONA  IN BA_PERSONAS.COD_PERSONA%TYPE,
                                   P_TIP_BUSQUEDA VARCHAR2) RETURN VARCHAR2;
   -- Funcion que retorna la descripción del departamento, de la ciudad o el cód. Postal dependiento del tipo de busqueda
   FUNCTION FU_OBT_COD_CIU(P_COD_PERSONA  IN BA_PERSONAS.COD_PERSONA%TYPE,
                           P_TIP_BUSQUEDA VARCHAR2) RETURN VARCHAR2;

   -- Funcion que retorna el pep (indicador que esta o no en la lista PEP)
   FUNCTION FU_OBT_PEP(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
      RETURN CR_INF_FONDOS.PEP%TYPE;

   -- Funcion que retorna el cod de Herencia
   FUNCTION FU_OBT_COD_HERENCIA(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
      RETURN VARCHAR2;

   -- Función que obtiene la región de la cuenta
   FUNCTION FU_OBT_REGION_CUENTA(P_COD_OFICINA IN GE_CLIENTES.COD_OFICINA%TYPE)
      RETURN VARCHAR2;

   -- Función que retorna la fecha en que empezó con la instución
   FUNCTION FU_OBT_FEC_ING_CLIENTE(P_COD_PERSONA IN GE_CLIENTES.COD_PERSONA%TYPE)
      RETURN DATE;

   -- Función que obtiene la fecha cerrada o cancelada de la cuenta
   FUNCTION FU_OBT_FEC_CANCELACION(P_NRO_CUENTA    IN GE_CUENTAS.NRO_CUENTA%TYPE,
                                   P_COD_MODULO    IN GE_MODALIDADES.COD_MODULO%TYPE,
                                   P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE,
                                   P_TIPO          IN VARCHAR2) RETURN date;

   -- Función que recupera la fecha de implementación de ASSIST
   FUNCTION FU_OBT_FEC_IMP_ASSIST RETURN DATE;

   -- Función que recupera la fecha de maduración (a partir de que fecha se tomaría para las alertas)
   FUNCTION FU_OBT_FEC_MADURACION RETURN VARCHAR2;

   -- Función que recupera el proposito de la cuenta
   FUNCTION FU_OBT_PRO_CUENTAS(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
      RETURN VARCHAR2;

   -- Función que recupera el código de proposito
   FUNCTION FU_OBT_COD_PRO_CUENTAS(P_PROPOSITO GE_PRO_CUENTAS.DESCRIPCION%TYPE)
      RETURN VARCHAR2;

   -- Función que recupera el tipo de objetivo de la cuenta
   FUNCTION FU_OBT_TIP_OBJ_CUENTA(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
      RETURN VARCHAR2;

   -- Función que recupera el proposito de la cuenta
   FUNCTION FU_OBT_FON_CUENTAS(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
      RETURN VARCHAR2;

   -- Función que recupera el código de fuente de fondo de la cuenta
   FUNCTION FU_OBT_COD_FON_CUENTAS(P_FONDO GE_ORI_FONDOS.DESCRIPCION%TYPE)
      RETURN VARCHAR2;


   -- Obtiene datos de la transferencia.
   FUNCTION FU_OBT_DAT_TRANSFERENCIA(P_NRO_OPERACION      IN LC_TRANSFERENCIAS.NRO_OPERACION%TYPE,
                                     P_NRO_CTA_REFERENCIA IN LC_TRANSFERENCIAS.NRO_CTA_REFERENCIA%TYPE,
                                     -- P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE,
                                     P_DATO                IN NUMBER,
                                     P_HORA                GE_MOVIMIENTOS.HORA%TYPE,
                                     P_USUARIO             GE_MOVIMIENTOS.COD_USUARIO%TYPE,
                                     P_FECHA               GE_MOVIMIENTOS.FECHA%TYPE,
                                     P_TIPO_MOV            VARCHAR2,
                                     P_COD_TRA_PADRE       GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
                                     P_COD_TRANSACCION     GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
                                     P_COD_GRU_TRANSACCION GE_AST_TRANSACCIONES.COD_GRU_TRANSACCION%TYPE,
                                     P_COD_BANCO           GE_BANCOS.COD_BANCO%type,
                                     P_MONTO               GE_MOVIMIENTOS.MONTO%TYPE)
      RETURN VARCHAR2;

   -- Obtener canal de la operacion
   FUNCTION FU_OBT_NRO_CANAL(P_COD_TRA_PADRE GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE,
                             P_COD_USUARIO   GE_MOVIMIENTOS.COD_USUARIO%TYPE
                             --,P_COD_PERSONA    GE_MOVIMIENTOS.COD_PERSONA%TYPE
                            ,
                             P_NRO_DOCUMENTO  GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE,
                             P_NRO_DOCUMENTO2 GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE,
                             P_NRO_DOCUMENTO3 GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE,
                             P_NRO_CUENTA     GE_MOVIMIENTOS.NRO_CUENTA%TYPE,
                             P_FEC_INSERCION  GE_MOVIMIENTOS.FEC_INSERCION%TYPE)
      RETURN NUMBER;

   -- Función que retorna la descripción del banco
   FUNCTION FU_OBT_DES_BANCO(P_COD_BANCO LC_TRANSFERENCIAS.COD_BCO_CORRESPONSAL%TYPE,
                             P_SIGLA     GE_BANCOS.SIGLA%TYPE) RETURN VARCHAR2;

   --Función que retorna la descripción del Banco Originador en transacciones SNP (interbanco)
   FUNCTION FU_OBT_DES_BAN_SNP(P_NRO_CTA_BANCARIA GE_SNP_CTA_BANCOS.NRO_CTA_BANCARIA%TYPE)
      RETURN VARCHAR2;

   --Función que retorna el nro de tipo de Canal de la transacción
   FUNCTION FU_OBT_NUM_CANAL_TRANSACCION(P_COD_USUARIO BA_USUARIOS.COD_USUARIO%TYPE)
      RETURN NUMBER;

   --Función que retorna el BENEFICIARIO/ORIGINADOR en trasnacciones internas(TRANINT-I/E) assist
   FUNCTION FU_OBT_NOM_PERSONA_TRNINT(P_HORA            GE_MOVIMIENTOS.HORA%TYPE,
                                      P_USUARIO         GE_MOVIMIENTOS.COD_USUARIO%TYPE,
                                      P_FECHA           GE_MOVIMIENTOS.FECHA%TYPE,
                                      P_NRO_CTA_CLIENTE GE_CTA_CLIENTES.NRO_CUENTA%TYPE,
                                      P_TIPO_MOV        VARCHAR2,
                                      P_MONTO_TR        GE_MOVIMIENTOS.MONTO%TYPE,
                                      P_COD_TRA_PADRE   GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
                                      P_COD_TRANSACCION GE_TRANSACCIONES.COD_TRANSACCION%TYPE)
      RETURN VARCHAR2;

   --CONTROL DE DEVOLUCIÓN DE CHEQUES (S/N)
   FUNCTION FU_OBT_IND_CHEQ_DEVUELTO(P_NRO_DOCUMENTO   GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE,
                                     P_USUARIO         GE_MOVIMIENTOS.COD_USUARIO%TYPE,
                                     P_FECHA           GE_MOVIMIENTOS.FECHA%TYPE,
                                     P_NRO_CTA_CLIENTE GE_CTA_CLIENTES.NRO_CUENTA%TYPE,
                                     P_TIPO_MOV        VARCHAR2,
                                     P_MONTO_TR        GE_MOVIMIENTOS.MONTO%TYPE)
      RETURN VARCHAR2;

   --Función que retorna el BANCO BENEFICIARIO/ORIGINADOR en trasnacciones Nacionales(TRASFN-I/E) assist
   FUNCTION FU_OBT_NOM_BANCO_TRASFN(P_HORA            GE_MOVIMIENTOS.HORA%TYPE,
                                    P_USUARIO         GE_MOVIMIENTOS.COD_USUARIO%TYPE,
                                    P_FECHA           GE_MOVIMIENTOS.FECHA%TYPE,
                                    P_NRO_CTA_CLIENTE GE_CTA_CLIENTES.NRO_CUENTA%TYPE,
                                    P_TIPO_MOV        VARCHAR2,
                                    P_MONTO_TR        GE_MOVIMIENTOS.MONTO%TYPE)
   --   P_COD_TRA_PADRE GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
      --P_COD_TRANSACCION GE_TRANSACCIONES.COD_TRANSACCION%TYPE)
    RETURN VARCHAR2;

   -- Verifica si ya se proceso en la fecha
   FUNCTION FU_VER_FEC_PROCESO(P_FECHA DATE) RETURN BOOLEAN;

   -- Verifica si el cliente es principal de alguna cuenta
   FUNCTION FU_VER_CLI_PRINCIPAL(P_COD_PERSONA BA_PERSONAS.COD_PERSONA%TYPE)
      RETURN VARCHAR2;

   FUNCTION FU_OBT_NRO_SUB_OPERACION(P_COD_PERSONA IN VARCHAR2,
                                     P_NRO_CUENTA  IN VARCHAR2) RETURN NUMBER;
   FUNCTION FU_OBT_NRO_CTA_ITGF(P_NRO_CTA_BANTOTAL  IN NUMBER,
                                P_NRO_SUB_OPERACION IN NUMBER) RETURN VARCHAR2;

   FUNCTION FU_CLI_EXI_ENBANTOTAL(P_COD_PAIS      IN VARCHAR2,
                                  P_TIP_DOCUMENTO IN VARCHAR2,
                                  P_NRO_DOCUMENTO IN VARCHAR2) RETURN VARCHAR2;

   FUNCTION FU_OBT_OFI_BANTOTAL(P_COD_OFICIAL IN VARCHAR2) RETURN NUMBER;

   -- PROCEDIMIENTOS

   PROCEDURE PR_TRU_TAB_BANTOTAL;

   --PROCEDIMIENTO GENERACIÓN DE SCORING MASIVO PARA ALTAS MASIVAS
   PROCEDURE PR_GEN_SCORING;

   --PROCEDIMIENTO PARA CONTROL DE REGISTROS HISTÓRICOS Y MANEJO DE ERRORES
   PROCEDURE PR_PRE_PRO_REGISTROS(P_NOM_TABLA IN VARCHAR2,
                                  P_FECHA     IN DATE,
                                  P_TIPO      IN VARCHAR2);
   PROCEDURE PR_ENV_MAIL(P_FEC_PROCESO IN DATE, P_TIP_PROCESO IN VARCHAR2);

   --procedimiento de generación inicial de cuentas y sub operaciones
   PROCEDURE PR_MIG_CTA_CLIENTES;

   --procedimiento de generación inicial de cuentas y sub operaciones
   PROCEDURE PR_MIG_CTA_CLIENTES_DEV(P_FEC_DESDE IN DATE,
                                     P_FEC_HASTA IN DATE);

   --procedimiento de equivalencias
   FUNCTION FU_OBT_COD_BTL_PSA(P_VAL_ITGF VARCHAR2, P_NOM_TABLA VARCHAR2)
      RETURN VARCHAR2;

   --procedimiento de equivalencias
   FUNCTION FU_OBT_COD_BTL_PSA(P_VAL1_ITGF VARCHAR2,
                               P_VAL2_ITGF VARCHAR2,
                               P_NOM_TABLA VARCHAR2) RETURN VARCHAR2;

   FUNCTION FU_OBT_DES_CIU_BTL_PSA(P_COD_CIU_ITGF  VARCHAR2,
                                   P_COD_PAIS_ITGF VARCHAR2) RETURN VARCHAR2;
   FUNCTION FU_OBT_COD_CIU_BT(P_COD_CIU_ITGF  VARCHAR2,
                              P_COD_PAIS_ITGF VARCHAR2,
                              P_NOM_TABLA     VARCHAR2) RETURN VARCHAR2;

   FUNCTION FU_OBT_COD_REF_BT(P_DOMINIO VARCHAR2, P_VAL_ITGF VARCHAR2)
      RETURN VARCHAR2;

   FUNCTION FU_OBT_COD_ITGF(P_VAL_BT VARCHAR2, P_NOM_TABLA VARCHAR2)
      RETURN VARCHAR2;

   FUNCTION FU_OBT_SEG_CLIENTE(P_COD_PERSONA IN VARCHAR2) return varchar2;

   function FU_OBT_RIE_CLIENTE(P_COD_PAIS IN VARCHAR2, P_TIP_DOC IN VARCHAR2, P_NRO_DOC IN VARCHAR2) RETURN NUMBER;


   -- Procedimiento principal que REgeneraR los archivos para PSAML.
   PROCEDURE PR_REGEN_DAT_PSAML;

   -- Procedimiento principal que genera los archivos para PSAML.
   PROCEDURE PR_GEN_DAT_PSAML;

   -- Procedimiento principal que genera los archivos para PSAML.pruebas
   PROCEDURE PR_GEN_DAT_PSAML_DEV(P_FEC_dESDE IN DATE, P_FEC_HASTA IN DATE);

   -- Procedimiento principal que genera los archivos para PSAML.
   PROCEDURE PR_GEN_DAT_PSAML_TEST(P_FEC_PROCESO IN DATE);
   -- Procedimiento principal que genera los archivos para PSAML.
   PROCEDURE PR_GEN_DAT_PSAML_TEST_MASIVO(P_FEC_DESDE IN DATE, P_FEC_HASTA IN DATE);

   --ACTUALIZACIÓN DE TOTAL ACTIVO Y PASIVO DEL CLIENTE
   PROCEDURE PR_ACT_PAS_ACT_CLIENTE;

   --PASAR AL HISTÍRICO EL RESULTADO DE PIC
   PROCEDURE PR_PAS_HIS_PIC_RESULT;

   -- Prrocedimiento que guarda en el temporal las cuentas a procesar en la fecha.
   PROCEDURE PR_INS_CTA_PSAML(P_FEC_PROCESO IN DATE);

   -- Prrocedimiento que guarda en el temporal las cuentas a procesar en la fecha.
   PROCEDURE PR_INS_CTA_PSAML_DEV(P_FEC_dESDE IN DATE, P_FEC_HASTA IN DATE);

   -- Procedimeinto que genera el archivo de Clientes a una fecha determinada.
   PROCEDURE PR_GEN_ARC_CLIENTES(P_FEC_PROCESO IN DATE);

   -- Procedimeinto que genera el archivo de lista de Clientes a una fecha determinada.
   PROCEDURE PR_GEN_ARC_LIS_CLIENTE(P_FEC_PROCESO IN DATE);

   -- Procedimiento que genera el archivo de Cuentas a una fecha determinada.
   PROCEDURE PR_GEN_ARC_CUENTAS(P_FEC_PROCESO IN DATE);

   -- Archivo que genera el archivo de Relaciones de clientes cuentas a una fecha determinada.
   PROCEDURE PR_GEN_ARC_RELACIONES(P_FEC_PROCESO IN DATE);

   -- Archivo que genera el archivo de perfiles de clientes a una fecha determinada.
   PROCEDURE PR_GEN_ARC_PERFILES(P_FEC_PROCESO IN DATE);

   -- Archivo que genera el archivo de definiciones por el usuario a una fecha determinada.
   PROCEDURE PR_GEN_ARC_CATALOGOS;

   -- Archivo que genera el archivo de Transacciones (movimientos) de cuentas de clientes a una fecha determinada.
   PROCEDURE PR_GEN_ARC_MOVIMIENTOS(P_FEC_PROCESO IN DATE);
   PROCEDURE PR_REGEN_ARC_MOVIMIENTOS(P_FEC_PROCESO IN DATE);

   PROCEDURE PR_GEN_ARC_MOV_MASIVOS(P_FEC_DESDE IN DATE,
                                    P_FEC_HASTA IN DATE);
   --ACTUALIZA CUENTAS DUPLICADAS DE PERSONAS QUE CAMBIARON DE DOCUMENTO PAIS O TIP DOCUENTO.                                    
   PROCEDURE PR_ACT_CTA_CLIENTES;

   --Proceso PIC
   PROCEDURE PR_PRO_PIC(p_fec_desde date, p_fec_hasta date);
   --REPROCESO DE PIC
   PROCEDURE PR_REP_PRO_PIC(p_fec_desde date, p_fec_hasta date);
   --PROCESOS AUXILIARES DE TEST
   PROCEDURE PR_PRO_AUX_PIC(p_fec_desde date, p_fec_hasta date);
   --PROCEDURE PIC MENSUAL
   PROCEDURE PR_GEN_PRO_PIC;
   --Procedure PIC para procesar un mes entero para regularización de los datos
   PROCEDURE PR_GEN_PRO_PIC_REG;
   -- FIN
END PAI_PSA;
/

