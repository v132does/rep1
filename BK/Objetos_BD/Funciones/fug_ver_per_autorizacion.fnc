CREATE OR REPLACE FUNCTION IT.FUG_VER_PER_AUTORIZACION
 (P_TIP_AUTORIZACION IN GE_AUT_PEDIDOS.TIP_AUTORIZACION%TYPE)
 RETURN VARCHAR2 IS

--- Recuperar rol que va a autorizar el pedido
   v_tie_permiso VARCHAR2(1) := 'S';

BEGIN
  IF p_tip_autorizacion = 'V' THEN
     IF NOT fug_val_usu_rol('ROL_APR_LIM_VAR', user) THEN
        v_tie_permiso := 'N';
     END IF;
  END IF;
  RETURN v_tie_permiso;
EXCEPTION
   when others then
      return 'N';
END;
/

