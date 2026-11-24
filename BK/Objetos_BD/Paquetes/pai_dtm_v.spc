create or replace package it.PAI_DTM_V is

  -- Author  : PY00297
  -- Created : 24/07/2009 05:13:07 p.m.
  -- Purpose : Intrefaz DATAMART
  
  -- Public type declarations
--  type <TypeName> is <Datatype>;
  
  -- Public constant declarations
--  <ConstantName> constant <Datatype> := <Value>;

  -- Public variable declarations
--  <VariableName> <Datatype>;


function fu_obt_fecha return date;
  -- Public function and procedure declarations
--  function <FunctionName>(<Parameter> <Datatype>) return <Datatype>;
PROCEDURE PR_CAR_CTUPMMDD;
--Genera el CATALOGO de Gestores del Banco.
PROCEDURE PR_GEN_FUUPMMDD;

--Genera el CATALOGO de Moneda
PROCEDURE PR_GEN_MOUPMMDD;

--Genera catalogo de Operadores
PROCEDURE PR_GEN_OPUPMMDD;

--Genera Catalogo de Productos Contables
PROCEDURE PR_GEN_PRUPMMDD;

--Genera Catalogo de Transacciones
PROCEDURE PR_GEN_TTUPMMDD;

--Genera Catalogo de Oficinas
PROCEDURE PR_GEN_UOUPMMDD;

--Genera Archivo de Clientes Titulares
PROCEDURE PR_GEN_CTUPMMDD;

--Genera Archivo de Cotitulares 
PROCEDURE PR_GEN_TCUPMMDD;

--Genera Archivo de Inversiones de Clientes
PROCEDURE PR_GEN_INUPMMDD;

--Genera Archivo de Saldos de Cuentas por Clientes
PROCEDURE PR_GEN_SAUPMMDD;

--Genera Archivo de Transacciones de Clientes
PROCEDURE PR_GEN_TRUPMMDD;


--Carga la tabla de IC_DIA_INHABILES
PROCEDURE PR_INS_DIA_INHABILES;

--Genera Archivo de Dias Inhabiles del Banco
PROCEDURE PR_GEN_DIUPMMDD;

--Genera Catalogo de Titularidades
PROCEDURE PR_GEN_TIUPMMDD;

--Generar Archivos para DATAMART
PROCEDURE PR_GEN_ARC_DATAMART;

--Funcion que obtiene determinadas fechas de la cuenta.
/*P_TIP_FECHA VALORES POSIBLES
1=FECHA DE ULTIMO MOVIMIENTO DE LA CUENTA
2=FECHA DE APERTURA
3=FECHA DE CANCELACION
4=FECHA VENCIMIENTO
*/
FUNCTION FU_OBT_FEC_CUENTAS(P_NRO_CUENTA IN VARCHAR2,
                       P_MODALIDAD IN NUMBER,
                       P_TIP_FECHA NUMBER) 
                               return date;

--Funcion que da formato al codigo de los gestores
FUNCTION FU_FOR_COD_GESTOR(P_COD_USUARIO IN BA_USUARIOS.COD_USUARIO%TYPE)
                          RETURN VARCHAR2;

--Funcion que trae el estado de la cuenta de un cliente
FUNCTION FU_OBT_EST_CUENTA(P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE,
                           P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE)
                           RETURN CHAR;
--Funcion que obtiene el grupo econi¿omico del cliente
FUNCTION FU_OBT_COD_GRU_ECONOMICO(P_COD_PERSONA IN GE_CLIENTES.COD_PERSONA%TYPE)
         RETURN NUMBER;
         
--Funcion que obtiene el nombre del grupo economico
FUNCTION FU_OBT_NOM_GRU_ECONOMICO(P_COD_GRU_ECONOMICO IN GE_GRU_ECONOMICOS.COD_GRU_ECONOMICO%TYPE)
RETURN VARCHAR2;

--funcion que obtiene el nombre del cliente
FUNCTION FU_OBT_NOM_CLIENTE(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
RETURN VARCHAR2;

--Funcion que obtiene el gestor del cliente.
FUNCTION FU_OBT_GESTOR(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
RETURN VARCHAR2;

--Funcion que obtiene el pais Donde Reside el Cliente.
FUNCTION FU_OBT_PAIS(P_COD_PERSONA IN BA_DIRECCIONES.COD_PERSONA%TYPE)
RETURN NUMBER;

--Funcion que obtiene la fecha de ingreso del Cliente.
FUNCTION FU_OBT_FEC_ING_CLIENTE(P_COD_PERSONA IN GE_CLIENTES.COD_PERSONA%TYPE)
RETURN DATE;

--Funcion que da formato a los montos 
FUNCTION FU_FOR_MONTOS(P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE)
RETURN VARCHAR2;

--Funcion que obtiene el capital de la cuenta
FUNCTION FU_OBT_CAP_CUENTA(P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE,
                           P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE)
                           RETURN NUMBER;
--Funcion que obtiene el  devengado de Ahorro a la Vista
FUNCTION FU_OBT_DEV_AV
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_FEC_ULT_CAPITALIZACION IN AH_CTA_VISTAS.FEC_ULT_CAPITALIZACION%TYPE
 )
 RETURN NUMBER;
 
--Funcion que obtiene el nombre del gestor
FUNCTION FU_OBT_NOM_GESTOR(P_COD_USUARIO IN BA_USUARIOS.COD_USUARIO%TYPE)
RETURN VARCHAR2;

--Funcion de segmentacion de Riesgos de Clientes.
FUNCTION FU_OBT_SEG_RIE_CLIENTE(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                                P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE)
RETURN NUMBER;

--Funcion que obtiene el saldo de la cuenta.
FUNCTION FU_OBT_SAL_CUENTA(P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE)
RETURN NUMBER;

--Funcion que obtiene el tipo de persona
FUNCTION FU_OBT_TIP_PERSONA(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
RETURN VARCHAR2;

--Funcion de conversion de cuenta del sistema IT->AS
FUNCTION FU_OBT_NRO_CTA_ANTERIOR(P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE,
                                 P_COD_MONEDA IN GE_CUENTAS.COD_MONEDA%TYPE)
RETURN VARCHAR2;

--Funcion de conversion de cuenta del sistema AS->IT
FUNCTION FU_OBT_NRO_CTA_IT(P_NRO_CUENTA in varchar2)
RETURN VARCHAR2;

--Funcion que obtiene la fecha del modulo
FUNCTION FU_OBT_fec_actual(P_COD_MODULO in ge_cuentas.cod_modulo%type)
RETURN date;

end PAI_DTM_V;
/

