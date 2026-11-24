CREATE OR REPLACE PROCEDURE IT.PRY_VER_CIRCUITO
 (P_COD_GRUPO IN AP_GRUPOS.COD_GRUPO%TYPE
 ,P_COD_TIP_REQUERIMIENTO IN AP_GRU_TIP_REQ.COD_TIP_REQUERIMIENTO%TYPE
 )
 IS

V_EXISTE NUMBER(1);
BEGIN

   --Verifica que el circuito de Aprobación esté completo
   --(Debe existir el Grupo Principal dentro del Circuito)
   select count(*)
   into v_existe
   from ap_grupos g, ap_gru_tip_req gr, ap_grupos ga
   where g.cod_grupo = gr.cod_grupo
   and g.cod_grupo = p_cod_grupo
   and gr.cod_tip_requerimiento = p_cod_tip_requerimiento
   and ga.cod_grupo = gr.cod_gru_aprueba
   and ga.principal = 'S'
   and ga.estado = 'A';

   if v_existe = 0 then
      raise_application_error(-20000,
      'No se puede insertar un Requerimiento cuyo Circuito de Aprobación no posee Grupo Principal');
   end if;
END;
/

