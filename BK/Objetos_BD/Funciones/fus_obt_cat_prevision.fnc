CREATE OR REPLACE FUNCTION IT.FUS_OBT_CAT_PREVISION
(P_COD_PERSONA IN GE_CLA_OPERACIONES.COD_PERSONA%TYPE,
 P_FECHA IN GE_CLA_OPERACIONES_HIS.FECHA%TYPE,
 P_COD_GRU_ECONOMICO IN GE_CLIENTES.COD_GRU_ECONOMICO%TYPE DEFAULT NULL)
RETURN NUMBER
AS
  v_categoria ge_cla_operaciones_his.cat_automatica%type;
BEGIN
  IF P_COD_GRU_ECONOMICO IS NULL THEN 
    --Verifico las operaciones que posee el cliente.
     SELECT nvl(MAX(a.cat_automatica),1)
       INTO v_categoria
       FROM ge_cla_operaciones_his a
      WHERE a.cod_persona = P_COD_PERSONA
        AND a.fecha = P_FECHA;
  ELSE     
    --Verifico las operaciones que posee el grupo económico
     SELECT nvl(MAX(a.cat_automatica),1)
       INTO v_categoria
       FROM ge_cla_operaciones_his a
      WHERE EXISTS ( SELECT 0 
                       FROM ge_clientes c
                      WHERE c.cod_gru_economico = P_COD_GRU_ECONOMICO
                        AND a.cod_persona = c.cod_persona )
        AND a.fecha = P_FECHA; 
  END IF;      
  RETURN v_categoria;
EXCEPTION
  WHEN OTHERS THEN
     v_categoria := 1;
     RETURN v_categoria;
END;
/

