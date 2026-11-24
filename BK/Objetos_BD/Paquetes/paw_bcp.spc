CREATE OR REPLACE PACKAGE IT.PAW_BCP IS
-- Variables Globales
g_bcp_webservice VARCHAR2(150) := fug_obt_pardinamico('WSI_BCP_WEBSERVICE');
g_api_gateway    ge_par_dinamicos.val_parametro%TYPE := trim(fug_obt_pardinamico('SET_GATEWAY_API'));

g_cod_error      number(3);
g_lugar          varchar2(50);
g_error          varchar2(2000);
g_cod_persona    ba_personas.cod_persona%type;
g_fec_actual     ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(1);

FUNCTION FU_OBT_PAR_BCP_SERVICIOS (P_COD_SERVICIO IN NUMBER,
                                   P_TIPO         IN VARCHAR2) RETURN VARCHAR2;
                                   
-- Procedimiento que invoca a todos los servicios
PROCEDURE PR_PRO_EJE_SERVICIOS (P_COD_PERSONA  IN BA_PERSONAS.COD_PERSONA%TYPE,
                                P_PERIODO      IN VARCHAR2,
                                P_COD_SERVICIO IN NUMBER,
                                P_ERROR       OUT VARCHAR2);

-- 1.7.1 Consulta Consolidada Por Persona.
FUNCTION FU_PRO_CON_CONSOLIDADA (P_TIP_DOC_CLI     IN VARCHAR2,
                                 P_NRO_DOC_CLI     IN BA_PERSONAS.NRO_DOCUMENTO%TYPE,
                                 P_CON_CONSOLIDADO IN TYP_LISTA_CONSOLIDADO) RETURN VARCHAR2;
-- 1.7.2 Estado Deuda Afectado Diario Por Persona                                
FUNCTION FU_PRO_EST_DEU_AFE_DIA (P_TIP_DOC_CLI  IN VARCHAR2,
                                 P_NRO_DOC_CLI    IN BA_PERSONAS.NRO_DOCUMENTO%TYPE,
                                 P_COD_RESULTADO  IN GE_BCP_DAT_PERSONALES.COD_RESULTADO%TYPE,
                                 P_DES_RESULTADO  IN GE_BCP_DAT_PERSONALES.DES_RESULTADO%TYPE,
                                 P_COD_TIP_DOCUMENTO IN GE_BCP_DAT_PERSONALES.COD_TIP_DOCUMENTO%TYPE,
                                 P_NRO_DOCUMENTO  IN GE_BCP_DAT_PERSONALES.NRO_DOCUMENTO%TYPE,
                                 P_NOMBRE         IN GE_BCP_DAT_PERSONALES.NOMBRE%TYPE,
                                 P_APELLIDO       IN GE_BCP_DAT_PERSONALES.APELLIDO%TYPE,
                                 P_FEC_NACIMIENTO IN VARCHAR2,
                                 P_COD_PAIS       IN GE_BCP_DAT_PERSONALES.COD_PAIS%TYPE,
                                 P_DES_PAIS       IN GE_BCP_DAT_PERSONALES.DES_PAIS%TYPE,
                                 P_TIP_PERSONA    IN GE_BCP_DAT_PERSONALES.TIP_PERSONA%TYPE,
                                 P_FEC_BAJA       IN VARCHAR2,
                                 P_NRO_GVP        IN GE_BCP_DAT_PERSONALES.NRO_GVP%TYPE,
                                 P_DEU_AFE_DIARIO IN TYP_LISTA_AFECTADO_DIARIO_DET) RETURN VARCHAR2;

-- 1.7.3 Inhabilitación de Cuentas Corrientes Por Persona
FUNCTION FU_PRO_INH_CTA_CTE (P_TIP_DOC_CLI    IN VARCHAR2,
                             P_NRO_DOC_CLI    IN BA_PERSONAS.NRO_DOCUMENTO%TYPE,
                             P_INHABILITACION IN TYP_LISTA_INHABILITACION) RETURN VARCHAR2;
                             
-- 1.7.4 Estado de Deuda Mensual Por Persona
FUNCTION FU_PRO_EST_DEU_MENSUAL (P_TIP_DOC_CLI    IN VARCHAR2,
                                 P_NRO_DOC_CLI    IN BA_PERSONAS.NRO_DOCUMENTO%TYPE,
                                 P_COD_RESULTADO  IN GE_BCP_DAT_PERSONALES.COD_RESULTADO%TYPE,
                                 P_DES_RESULTADO  IN GE_BCP_DAT_PERSONALES.DES_RESULTADO%TYPE,
                                 P_COD_TIP_DOCUMENTO IN GE_BCP_DAT_PERSONALES.COD_TIP_DOCUMENTO%TYPE,
                                 P_NRO_DOCUMENTO  IN GE_BCP_DAT_PERSONALES.NRO_DOCUMENTO%TYPE,
                                 P_NOMBRE         IN GE_BCP_DAT_PERSONALES.NOMBRE%TYPE,
                                 P_APELLIDO       IN GE_BCP_DAT_PERSONALES.APELLIDO%TYPE,
                                 P_FEC_NACIMIENTO IN VARCHAR2,
                                 P_COD_PAIS       IN GE_BCP_DAT_PERSONALES.COD_PAIS%TYPE,
                                 P_DES_PAIS       IN GE_BCP_DAT_PERSONALES.DES_PAIS%TYPE,
                                 P_TIP_PERSONA    IN GE_BCP_DAT_PERSONALES.TIP_PERSONA%TYPE,
                                 P_FEC_BAJA       IN VARCHAR2,
                                 P_NRO_GVP        IN GE_BCP_DAT_PERSONALES.NRO_GVP%TYPE,
                                 P_PERIODO        IN GE_BCP_DAT_PERSONALES.PERIODO%TYPE,
                                 P_CLA_SISTEMA    IN GE_BCP_DAT_PERSONALES.CLA_SISTEMA%TYPE,
                                 P_MTO_DEUDA      IN GE_BCP_DAT_PERSONALES.MTO_DEUDA%TYPE,
                                 P_MTO_CONTINGENCIA IN GE_BCP_DAT_PERSONALES.MTO_CONTINGENCIA%TYPE,
                                 P_MTO_EMI_CODEUD IN GE_BCP_DAT_PERSONALES.MTO_EMI_CODEUDORIA%TYPE,
                                 P_MTO_TOT_RIESGO IN GE_BCP_DAT_PERSONALES.MTO_TOT_RIESGO%TYPE) RETURN VARCHAR2;
                                 
-- 1.7.5 Operaciones Cartera Vendida Por Persona
FUNCTION FU_PRO_OPE_CAR_VENDIDA (P_TIP_DOC_CLI    IN VARCHAR2,
                                 P_NRO_DOC_CLI    IN BA_PERSONAS.NRO_DOCUMENTO%TYPE,
                                 P_COD_RESULTADO  IN GE_BCP_DAT_PERSONALES.COD_RESULTADO%TYPE,
                                 P_DES_RESULTADO  IN GE_BCP_DAT_PERSONALES.DES_RESULTADO%TYPE,
                                 P_COD_TIP_DOCUMENTO IN GE_BCP_DAT_PERSONALES.COD_TIP_DOCUMENTO%TYPE,
                                 P_NRO_DOCUMENTO  IN GE_BCP_DAT_PERSONALES.NRO_DOCUMENTO%TYPE,
                                 P_NOMBRE         IN GE_BCP_DAT_PERSONALES.NOMBRE%TYPE,
                                 P_APELLIDO       IN GE_BCP_DAT_PERSONALES.APELLIDO%TYPE,
                                 P_FEC_NACIMIENTO IN VARCHAR2,
                                 P_COD_PAIS       IN GE_BCP_DAT_PERSONALES.COD_PAIS%TYPE,
                                 P_DES_PAIS       IN GE_BCP_DAT_PERSONALES.DES_PAIS%TYPE,
                                 P_TIP_PERSONA    IN GE_BCP_DAT_PERSONALES.TIP_PERSONA%TYPE,
                                 P_FEC_BAJA       IN VARCHAR2,
                                 P_NRO_GVP        IN GE_BCP_DAT_PERSONALES.NRO_GVP%TYPE,
                                 P_CAR_VENDIDA_DET IN TYP_LISTA_CARTERA_VENDIDA_DET) RETURN VARCHAR2;

-- 1.7.6 Operaciones de Fideicomiso Por Persona
FUNCTION FU_PRO_OPE_FIDEICOMISO (P_TIP_DOC_CLI    IN VARCHAR2,
                                 P_NRO_DOC_CLI    IN BA_PERSONAS.NRO_DOCUMENTO%TYPE,
                                 P_COD_RESULTADO  IN GE_BCP_DAT_PERSONALES.COD_RESULTADO%TYPE,
                                 P_DES_RESULTADO  IN GE_BCP_DAT_PERSONALES.DES_RESULTADO%TYPE,
                                 P_COD_TIP_DOCUMENTO IN GE_BCP_DAT_PERSONALES.COD_TIP_DOCUMENTO%TYPE,
                                 P_NRO_DOCUMENTO  IN GE_BCP_DAT_PERSONALES.NRO_DOCUMENTO%TYPE,
                                 P_NOMBRE         IN GE_BCP_DAT_PERSONALES.NOMBRE%TYPE,
                                 P_APELLIDO       IN GE_BCP_DAT_PERSONALES.APELLIDO%TYPE,
                                 P_FEC_NACIMIENTO IN VARCHAR2,
                                 P_COD_PAIS       IN GE_BCP_DAT_PERSONALES.COD_PAIS%TYPE,
                                 P_DES_PAIS       IN GE_BCP_DAT_PERSONALES.DES_PAIS%TYPE,
                                 P_TIP_PERSONA    IN GE_BCP_DAT_PERSONALES.TIP_PERSONA%TYPE,
                                 P_FEC_BAJA       IN VARCHAR2,
                                 P_NRO_GVP        IN GE_BCP_DAT_PERSONALES.NRO_GVP%TYPE,
                                 P_FIDEICOMISO_DET IN TYP_LISTA_FIDEICOMISO_DET) RETURN VARCHAR2;

-- 1.7.7 Estado de Deuda Diario Por Persona
FUNCTION FU_PRO_EST_DEU_DIARIO  (P_TIP_DOC_CLI    IN VARCHAR2,
                                 P_NRO_DOC_CLI    IN BA_PERSONAS.NRO_DOCUMENTO%TYPE,
                                 P_COD_RESULTADO  IN GE_BCP_DAT_PERSONALES.COD_RESULTADO%TYPE,
                                 P_DES_RESULTADO  IN GE_BCP_DAT_PERSONALES.DES_RESULTADO%TYPE,
                                 P_COD_TIP_DOCUMENTO IN GE_BCP_DAT_PERSONALES.COD_TIP_DOCUMENTO%TYPE,
                                 P_NRO_DOCUMENTO  IN GE_BCP_DAT_PERSONALES.NRO_DOCUMENTO%TYPE,
                                 P_NOMBRE         IN GE_BCP_DAT_PERSONALES.NOMBRE%TYPE,
                                 P_APELLIDO       IN GE_BCP_DAT_PERSONALES.APELLIDO%TYPE,
                                 P_FEC_NACIMIENTO IN VARCHAR2,
                                 P_COD_PAIS       IN GE_BCP_DAT_PERSONALES.COD_PAIS%TYPE,
                                 P_DES_PAIS       IN GE_BCP_DAT_PERSONALES.DES_PAIS%TYPE,
                                 P_TIP_PERSONA    IN GE_BCP_DAT_PERSONALES.TIP_PERSONA%TYPE,
                                 P_FEC_BAJA       IN VARCHAR2,
                                 P_NRO_GVP        IN GE_BCP_DAT_PERSONALES.NRO_GVP%TYPE,
                                 P_PERIODO        IN GE_BCP_DAT_PERSONALES.PERIODO%TYPE,
                                 P_CLA_SISTEMA    IN GE_BCP_DAT_PERSONALES.CLA_SISTEMA%TYPE,
                                 P_MTO_DEUDA      IN GE_BCP_DAT_PERSONALES.MTO_DEUDA%TYPE,
                                 P_MTO_CODEUDORIA IN GE_BCP_DAT_PERSONALES.MTO_CODEUDORIA%TYPE,
                                 P_MTO_CONTINGENCIA  IN GE_BCP_DAT_PERSONALES.MTO_CONTINGENCIA%TYPE,
                                 P_MTO_TOT_RIESGO IN GE_BCP_DAT_PERSONALES.MTO_TOT_RIESGO%TYPE,
                                 P_CAN_ENTIDAD    IN GE_BCP_DAT_PERSONALES.CAN_ENTIDAD%TYPE) RETURN VARCHAR2;

-- 1.7.8 Estado Deuda Afectado Mensual Por Persona  
FUNCTION FU_PRO_EST_DEU_AFE_MEN (P_TIP_DOC_CLI    IN VARCHAR2,
                                 P_NRO_DOC_CLI    IN BA_PERSONAS.NRO_DOCUMENTO%TYPE,
                                 P_COD_RESULTADO  IN GE_BCP_DAT_PERSONALES.COD_RESULTADO%TYPE,
                                 P_DES_RESULTADO  IN GE_BCP_DAT_PERSONALES.DES_RESULTADO%TYPE,
                                 P_COD_TIP_DOCUMENTO IN GE_BCP_DAT_PERSONALES.COD_TIP_DOCUMENTO%TYPE,
                                 P_NRO_DOCUMENTO  IN GE_BCP_DAT_PERSONALES.NRO_DOCUMENTO%TYPE,
                                 P_NOMBRE         IN GE_BCP_DAT_PERSONALES.NOMBRE%TYPE,
                                 P_APELLIDO       IN GE_BCP_DAT_PERSONALES.APELLIDO%TYPE,
                                 P_FEC_NACIMIENTO IN VARCHAR2,
                                 P_COD_PAIS       IN GE_BCP_DAT_PERSONALES.COD_PAIS%TYPE,
                                 P_DES_PAIS       IN GE_BCP_DAT_PERSONALES.DES_PAIS%TYPE,
                                 P_TIP_PERSONA    IN GE_BCP_DAT_PERSONALES.TIP_PERSONA%TYPE,
                                 P_FEC_BAJA       IN VARCHAR2,
                                 P_NRO_GVP        IN GE_BCP_DAT_PERSONALES.NRO_GVP%TYPE,
                                 P_DEU_AFE_MENSUAL IN TYP_LISTA_AFECTADO_MENSUAL_DET) RETURN VARCHAR2;

-- 1.7.9 Datos de Personas
FUNCTION FU_PRO_DAT_PERSONAS    (P_TIP_DOC_CLI    IN VARCHAR2,
                                 P_NRO_DOC_CLI    IN BA_PERSONAS.NRO_DOCUMENTO%TYPE,
                                 P_COD_RESULTADO  IN GE_BCP_DAT_PERSONALES.COD_RESULTADO%TYPE,
                                 P_DES_RESULTADO  IN GE_BCP_DAT_PERSONALES.DES_RESULTADO%TYPE,
                                 P_COD_TIP_DOCUMENTO IN GE_BCP_DAT_PERSONALES.COD_TIP_DOCUMENTO%TYPE,
                                 P_NRO_DOCUMENTO  IN GE_BCP_DAT_PERSONALES.NRO_DOCUMENTO%TYPE,
                                 P_NOMBRE         IN GE_BCP_DAT_PERSONALES.NOMBRE%TYPE,
                                 P_APELLIDO       IN GE_BCP_DAT_PERSONALES.APELLIDO%TYPE,
                                 P_FEC_NACIMIENTO IN VARCHAR2,
                                 P_COD_PAIS       IN GE_BCP_DAT_PERSONALES.COD_PAIS%TYPE,
                                 P_DES_PAIS       IN GE_BCP_DAT_PERSONALES.DES_PAIS%TYPE,
                                 P_GENERO         IN GE_BCP_DAT_PERSONALES.SEXO%TYPE,
                                 P_TIP_PERSONA    IN GE_BCP_DAT_PERSONALES.TIP_PERSONA%TYPE,
                                 P_FEC_BAJA       IN VARCHAR2) RETURN VARCHAR2;

-----------------------------
-- Procedimiento Principal --
-----------------------------
FUNCTION FU_PRO_BCP_WEBSERVICE (P_COD_PERSONA  IN BA_PERSONAS.COD_PERSONA%TYPE,
                                P_PERIODO      IN VARCHAR2,
                                P_COD_SERVICIO IN VARCHAR2) RETURN VARCHAR2;

END PAW_BCP;
/

