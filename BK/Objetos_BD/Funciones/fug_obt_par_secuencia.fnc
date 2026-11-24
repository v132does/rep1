CREATE OR REPLACE FUNCTION IT.FUG_OBT_PAR_SECUENCIA
 (P_COD_USU_PIVOT IN ge_con_par_usuarios.COD_USU_PIVOT%TYPE
 ,P_CAMPO IN VARCHAR2)
 RETURN VARCHAR2
 IS
 --COREPESI-1 / Proyecto Mejoras Performance SIPAP--
 v_reg ge_con_par_usuarios%rowtype;
 v_val_parametro ge_par_usuarios.val_parametro%type;

BEGIN
   select x.*
     into v_reg
     from ge_con_par_usuarios x
    where x.cod_usu_pivot = P_COD_USU_PIVOT;

   IF P_CAMPO = 'IND_UTI_SECUENCIA' THEN
      v_val_parametro := V_REG.IND_UTI_SECUENCIA;
   elsif P_CAMPO = 'COD_USU_ACTUAL' THEN
      v_val_parametro := V_REG.COD_USU_ACTUAL;
   elsif P_CAMPO = 'CAN_USU_UTILIZADOS' THEN
      v_val_parametro := V_REG.CAN_USU_UTILIZADOS;
   elsif P_CAMPO = 'CAN_RES_SECUENCIA' THEN
      v_val_parametro := V_REG.CAN_RES_SECUENCIA;
   elsif P_CAMPO = 'COD_USU_ULT_CAMBIO' THEN
      v_val_parametro := V_REG.COD_USU_ULT_CAMBIO;
   elsif P_CAMPO = 'NRO_ULT_CAM_SECUENCIA' THEN
      v_val_parametro := V_REG.NRO_ULT_CAM_SECUENCIA;
   elsif P_CAMPO = 'TOT_ACU_UTI_SECUENCIA' THEN
      v_val_parametro := V_REG.TOT_ACU_UTI_SECUENCIA;
   elsif P_CAMPO = 'CAN_USU_HABILITADOS' THEN
      v_val_parametro := V_REG.CAN_USU_HABILITADOS;
   elsif P_CAMPO = 'COD_SEC_UTILIZADA' THEN
      v_val_parametro := V_REG.COD_SEC_UTILIZADA;
   END IF;

   return v_val_parametro;
exception
      when no_data_found then
        RETURN null;
END;
/

