CREATE OR REPLACE PACKAGE IT.PAI_AST IS
  -- Paquete utilizado para las interfaces ITGF y la herramienta ASSIST
  -- Fecha: 30/04/2014
  -- Autor: Sergio Servín Arce
  ---------------------------------------------------------------------------
  -- FUNCIONES

  -- Función que obtiene la fecha de proceso
  FUNCTION FU_OBT_FEC_PROCESO
  RETURN DATE;

  -- Función que retorna el nombre del la persora Física o Juridica
  FUNCTION FU_OBT_NOM_CLIENTE(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                              P_TIPO VARCHAR2)
  RETURN VARCHAR2;

  -- Función que retorna el nombre del la persora Física o Juridica
  FUNCTION FU_OBT_APE_CLIENTE(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                              P_TIPO VARCHAR2)
  RETURN VARCHAR2;

  -- Función que retorna la descripción del tipo de documento
  FUNCTION FU_OBT_DES_TIP_DOC(P_COD_TIP_DOCUMENTO IN BA_TIP_DOCUMENTOS.COD_TIP_DOCUMENTO%TYPE) RETURN BA_TIP_DOCUMENTOS.DESCRIPCION%TYPE;

  -- Función que retorna la descripción de la actividad
  FUNCTION FU_OBT_DES_ACTIVIDAD(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE, P_TIP_PERSONA VARCHAR2) RETURN BA_TIP_DOCUMENTOS.DESCRIPCION%TYPE;

  -- Función que retorna la fecha de nacimento en caso de persona física y la fecha de apertura en coso de persona jurídica
  FUNCTION FU_OBT_FEC_NACIMIENTO(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE, P_TIP_PERSONA VARCHAR2)
  RETURN VARCHAR2;

  -- Función que retorna el código de pais ISO en caso de que el tipo de busqueda sea "N" retorna el pais de la nacionalizacion, sino retorna el país de la dirección principal
  FUNCTION FU_OBT_COD_ISO_PAIS(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                               P_TIP_BUSQUEDA VARCHAR2,
                               P_COD_PAIS BA_PAISES.COD_PAIS%TYPE)
  RETURN GE_AST_PAISES.COD_AST_PAIS%TYPE;

  -- Función que retorna la dirección principal del cliente
  FUNCTION FU_OBT_DIR_PRINCIPAL(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
  RETURN VARCHAR2;

  -- Función que obtiene la dirección principal
  FUNCTION FU_OBT_TEL_PRINCIPAL(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
  RETURN VARCHAR2;

  -- Funcion que retorna la descripción del departamento, de la ciudad o el cód. Postal dependiento del tipo de busqueda
  FUNCTION FU_OBT_DES_DEP_CIU_POS(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE, P_TIP_BUSQUEDA VARCHAR2) RETURN VARCHAR2;

  -- Funcion que retorna el pep (indicador que esta o no en la lista PEP)
  FUNCTION FU_OBT_PEP(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE) RETURN CR_INF_FONDOS.PEP%TYPE;

  -- Funcion que retorna el cod de Herencia
  FUNCTION FU_OBT_COD_HERENCIA(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE) RETURN VARCHAR2;

  -- Función que obtiene la región de la cuenta
  FUNCTION FU_OBT_REGION_CUENTA(P_COD_OFICINA IN GE_CLIENTES.COD_OFICINA%TYPE)
  RETURN VARCHAR2;

  -- Función que retorna la fecha en que empezó con la instución
  FUNCTION FU_OBT_FEC_ING_CLIENTE(P_COD_PERSONA IN GE_CLIENTES.COD_PERSONA%TYPE)RETURN DATE;

  -- Función que obtiene la fecha cerrada o cancelada de la cuenta
  FUNCTION FU_OBT_FEC_CANCELACION(P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE,
                                  P_COD_MODULO IN GE_MODALIDADES.COD_MODULO%TYPE,
                                  P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE,
                                  P_TIPO IN VARCHAR2)
  RETURN VARCHAR2;

  -- Función que recupera la fecha de implementación de ASSIST
  FUNCTION FU_OBT_FEC_IMP_ASSIST RETURN DATE;

  -- Función que recupera la fecha de maduración (a partir de que fecha se tomaría para las alertas)
  FUNCTION FU_OBT_FEC_MADURACION
  RETURN VARCHAR2;

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
  /*FUNCTION FU_OBT_DAT_TRANSFERENCIA(P_COD_REFERENCIA IN LC_TRANSFERENCIAS.NRO_REFERENCIA%TYPE,
                                     P_TIP_REFERENCIA IN LC_TRANSFERENCIAS.COD_TIP_REFERENCIA%TYPE,
                                     P_DATO IN NUMBER )
  RETURN VARCHAR2;*/

  -- Obtiene datos de la transferencia.
  FUNCTION FU_OBT_DAT_TRANSFERENCIA(P_NRO_OPERACION IN LC_TRANSFERENCIAS.NRO_OPERACION%TYPE,
                                    P_NRO_CTA_REFERENCIA IN LC_TRANSFERENCIAS.NRO_CTA_REFERENCIA%TYPE,
                                   -- P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE,
                                    P_DATO IN NUMBER,
                                    P_HORA GE_MOVIMIENTOS.HORA%TYPE,
                                    P_USUARIO GE_MOVIMIENTOS.COD_USUARIO%TYPE,
                                    P_FECHA GE_MOVIMIENTOS.FECHA%TYPE ,
                                    P_TIPO_MOV VARCHAR2,
                                    P_COD_TRA_PADRE GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
                                    P_COD_TRANSACCION GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
                                    P_COD_GRU_TRANSACCION GE_AST_TRANSACCIONES.COD_GRU_TRANSACCION%TYPE,
                                    P_COD_BANCO GE_BANCOS.COD_BANCO%type,
                                    P_MONTO GE_MOVIMIENTOS.MONTO%TYPE)
  RETURN VARCHAR2;

  -- Función que retorna la descripción del banco
  FUNCTION FU_OBT_DES_BANCO(P_COD_BANCO LC_TRANSFERENCIAS.COD_BCO_CORRESPONSAL%TYPE,
                            P_SIGLA GE_BANCOS.SIGLA%TYPE)
  RETURN VARCHAR2;

  --Función que retorna la descripción del Banco Originador en transacciones SNP (interbanco)
  FUNCTION FU_OBT_DES_BAN_SNP(P_NRO_CTA_BANCARIA GE_SNP_CTA_BANCOS.NRO_CTA_BANCARIA%TYPE)
  RETURN VARCHAR2;

  --Función que retorna el nro de tipo de Canal de la transacción
  FUNCTION FU_OBT_NUM_CANAL_TRANSACCION(P_COD_USUARIO BA_USUARIOS.COD_USUARIO%TYPE)
  RETURN NUMBER;

  --Función que retorna el BENEFICIARIO/ORIGINADOR en trasnacciones internas(TRANINT-I/E) assist
  FUNCTION FU_OBT_NOM_PERSONA_TRNINT(P_HORA GE_MOVIMIENTOS.HORA%TYPE,
                                    P_USUARIO GE_MOVIMIENTOS.COD_USUARIO%TYPE,
                                    P_FECHA GE_MOVIMIENTOS.FECHA%TYPE,
                                    P_NRO_CTA_CLIENTE GE_CTA_CLIENTES.NRO_CUENTA%TYPE,
                                    P_TIPO_MOV VARCHAR2,
                                    P_MONTO_TR GE_MOVIMIENTOS.MONTO%TYPE,
                                    P_COD_TRA_PADRE GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
                                    P_COD_TRANSACCION GE_TRANSACCIONES.COD_TRANSACCION%TYPE)
  RETURN VARCHAR2;


  --CONTROL DE DEVOLUCIÓN DE CHEQUES (S/N)
  FUNCTION FU_OBT_IND_CHEQ_DEVUELTO(P_NRO_DOCUMENTO GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE,
                                    P_USUARIO GE_MOVIMIENTOS.COD_USUARIO%TYPE,
                                    P_FECHA GE_MOVIMIENTOS.FECHA%TYPE,
                                    P_NRO_CTA_CLIENTE GE_CTA_CLIENTES.NRO_CUENTA%TYPE,
                                    P_TIPO_MOV VARCHAR2,
                                    P_MONTO_TR GE_MOVIMIENTOS.MONTO%TYPE)
  RETURN VARCHAR2;


  --Función que retorna el BANCO BENEFICIARIO/ORIGINADOR en trasnacciones Nacionales(TRASFN-I/E) assist
  FUNCTION FU_OBT_NOM_BANCO_TRASFN(P_HORA GE_MOVIMIENTOS.HORA%TYPE,
                                    P_USUARIO GE_MOVIMIENTOS.COD_USUARIO%TYPE,
                                    P_FECHA GE_MOVIMIENTOS.FECHA%TYPE,
                                    P_NRO_CTA_CLIENTE GE_CTA_CLIENTES.NRO_CUENTA%TYPE,
                                    P_TIPO_MOV VARCHAR2,
                                    P_MONTO_TR GE_MOVIMIENTOS.MONTO%TYPE)
                                 --   P_COD_TRA_PADRE GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
                                    --P_COD_TRANSACCION GE_TRANSACCIONES.COD_TRANSACCION%TYPE)
  RETURN VARCHAR2;

  -- Verifica si ya se proceso en la fecha
  FUNCTION FU_VER_FEC_PROCESO(P_FECHA DATE)
  RETURN BOOLEAN;

  -- Verifica si el cliente es principal de alguna cuenta
  FUNCTION FU_VER_CLI_PRINCIPAL(P_COD_PERSONA BA_PERSONAS.COD_PERSONA%TYPE)
  RETURN VARCHAR2;

  -- PROCEDIMIENTOS

  -- Procedimiento que genera archivo TXT para ASSIST.
  PROCEDURE PR_GEN_ARCHIVO_AST(P_NOM_ARCHIVO IN VARCHAR2,
                              -- P_SQL IN VARCHAR2,
                               --P_CON_CABECERA IN VARCHAR2,
                               --P_SEPARADOR IN VARCHAR2,
                               P_AGREGA IN VARCHAR2);

  -- Procedimiento principal que genera los archivos para ASSIST.
  PROCEDURE PR_GEN_ARC_ASSIST;
 /* -- Procedimiento principal que genera los archivos para ASSIST.
  PROCEDURE PR_GEN_ARC_ASSIST_FINAL;*/

  -- Regeneración de archivos de a una fecha dada que ya se haya procesado.
  PROCEDURE PR_REGEN_ARC_ASSIST;

  -- Prrocedimiento que guarda en el temporal las cuentas a procesar en la fecha.
  PROCEDURE PR_INS_CTA_ASSIST;

  -- Procedimiento que genera el archivo de grupos de transacciones a una fecha determinada.
  PROCEDURE PR_GEN_ARC_GRU_TRA(P_FEC_PROCESO IN DATE);

  -- Procedimiento que genera el archivo de transacciones a una fecha determinada.
  PROCEDURE PR_GEN_ARC_TRANSACCIONES(P_FEC_PROCESO IN DATE);

  -- Procedimiento que genera el archivo de paises a una fecha determinada.
  PROCEDURE PR_GEN_ARC_PAISES(P_FEC_PROCESO IN DATE);

  -- Procedimiento que genera el archivo de departamentos (Estados) a una fecha determinada.
  PROCEDURE PR_GEN_ARC_DEPARTAMENTOS(P_FEC_PROCESO IN DATE);

  -- Procedimiento que genera el archivo de regiones a una fecha determinada.
  PROCEDURE PR_GEN_ARC_REGIONES(P_FEC_PROCESO IN DATE);

  -- Procedimiento que genera el archivo de sucursales a una fecha determinada.
  PROCEDURE PR_GEN_ARC_SUCURSALES(P_FEC_PROCESO IN DATE);

  -- Procedimiento que genera el archivo de monedas a una fecha determinada.
  PROCEDURE PR_GEN_ARC_MONEDAS(P_FEC_PROCESO IN DATE);

  -- Procedimiento que genera el archivo de oficial de cuentas a una fecha determinada.
  PROCEDURE PR_GEN_ARC_OFI_CTA(P_FEC_PROCESO IN DATE);

  -- Procedimiento que genera el archivo de Objetivo de Cuentas a una fecha determinada.
  PROCEDURE PR_GEN_ARC_OBJ_CTA(P_FEC_PROCESO IN DATE);

  -- Procedimiento que genera el archivo de Propósito de Cuenta a una fecha determinada.
  PROCEDURE PR_GEN_ARC_PRO_CTA(P_FEC_PROCESO IN DATE);

  -- Procedimiento que genera el archivo de Tipos de Cuentas a una fecha determinada.
  PROCEDURE PR_GEN_ARC_TIP_CTA(P_FEC_PROCESO IN DATE);

  -- Procedimiento que genera el archivo de Origen de Fondos a una fecha determinada.
  PROCEDURE PR_GEN_ARC_ORI_FDO(P_FEC_PROCESO IN DATE);

  -- Procedimiento que genera el archivo de tipos de Relación a una fecha determinada.
  PROCEDURE PR_GEN_ARC_TIP_REL(P_FEC_PROCESO IN DATE);

  -- Procedimeinto que genera el archivo de Clientes a una fecha determinada.
  PROCEDURE PR_GEN_ARC_CLIENTES(P_FEC_PROCESO IN DATE);

  -- Procedimiento que genera el archivo de Cuentas a una fecha determinada.
  PROCEDURE PR_GEN_ARC_CUENTAS(P_FEC_PROCESO IN DATE);

  -- Archivo que genera el archivo de Relaciones de clientes cuentas a una fecha determinada.
  PROCEDURE PR_GEN_ARC_RELACIONES(P_FEC_PROCESO IN DATE);

  -- Archivo que genera el archivo de perfiles de clientes a una fecha determinada.
  PROCEDURE PR_GEN_ARC_PERFILES(P_FEC_PROCESO IN DATE);

  -- Archivo que genera el archivo de definiciones por el usuario a una fecha determinada.
  PROCEDURE PR_GEN_ARC_USER_DEFINED(P_FEC_PROCESO IN DATE);

  -- Archivo que genera el archivo de Transacciones (movimientos) de cuentas de clientes a una fecha determinada.
  PROCEDURE PR_GEN_ARC_MOVIMIENTOS(P_FEC_PROCESO IN DATE);
  -- FIN
END PAI_AST;
/

