create or replace package it.RSHK_Prestamos is

  -- Author  : XPY5008
  -- Created : 1/29/2010 3:12:03 PM
  -- Purpose :

  -- Public type declarations
  --type <TypeName> is <Datatype>;

  -- Public constant declarations
  --<ConstantName> constant <Datatype> := <Value>;

  -- Public variable declarations
  --<VariableName> <Datatype>;

  -- Public function and procedure declarations
  --function <FunctionName>(<Parameter> <Datatype>) return <Datatype>;


  --HELPERS

  PROCEDURE "MIG_PR_ERROR_LOG_REGISTRAR" (p_procedim in varchar2, p_cliente in varchar2, p_mensaje in varchar2, p_modulo in varchar2);
  PROCEDURE "MIG_PR_LOG_REGISTRAR" (p_mensaje in varchar2, p_modulo in varchar2);


  FUNCTION "PR_OBTENER_SGTE_VENC_CUOTA" (p_nro_cuenta varchar2, p_vencimiento date) return date;
  PROCEDURE "MI_MIG_PR_CUOTAS_V3";

  PROCEDURE "MI_MIG_PR_CTA_PRESTAMOS";

  PROCEDURE "OBTENER_INFO_SOLICITUD_PR";
  FUNCTION "RSHK_NUM2DATE_AAAAMMDD" (p_date number)return date;

  FUNCTION "GET_PRINCIPAL" (p_divisa IN NUMBER, p_riesgo IN NUMBER,
p_suc IN NUMBER, p_propuesta IN NUMBER, p_congru IN NUMBER)
RETURN NUMBER;

  FUNCTION "GET_INTERESES_PR" (p_riesgo IN NUMBER, p_suc IN NUMBER, p_propuesta IN NUMBER, p_congru IN NUMBER, v_iadinteres OUT NUMBER, v_intereses OUT NUMBER)RETURN NUMBER;
  FUNCTION "PR_OBTENER_CTA_ORIGINAL" (p_filler varchar2, p_propren number, p_cta_original varchar2, p_divisa number)
return varchar2;

  FUNCTION "GET_SCHEME_CODE" (p_congru varchar2, p_nuries number, p_sucursalfu number,
p_propuesta number, p_sector out varchar2, p_propren in number, p_divisa number, p_procdnt number) RETURN VARCHAR2;

FUNCTION "RSHK_OBTENER_NUM_CUENTA" (p_ctasuc IN NUMBER, p_tipocta IN NUMBER, p_subcta IN NUMBER)
RETURN VARCHAR2;

  FUNCTION "RSHK_NUM2DATE_AMMDD" (p_date number)return date;
  PROCEDURE "ACTUALIZAR_INFO_PRESTAMOS";

  PROCEDURE "RSHK_GENERAR_NUMEROS_CUENTA" (p_sucursal IN NUMBER, p_tipo varchar2);
  PROCEDURE "GENERAR_NUMEROS_CUENTA_SUC" (p_tipo in varchar2);

  --Procedimientos principales

  PROCEDURE "RSHK_EXECUTE_CREATE_INDEX" (p_stmt in varchar2);
  PROCEDURE "TODO_PRESTAMOS2";
  PROCEDURE "TODO_PR_MEZCLADOR";

end RSHK_Prestamos;
/

