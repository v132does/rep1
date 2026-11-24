CREATE OR REPLACE TRIGGER IT.TB_GE_TRANSACCIONES_DET
 BEFORE DELETE OR INSERT OR UPDATE
 ON GE_TRANSACCIONES_DET
 FOR EACH ROW



DECLARE

/* Obtener tipo de transacciones. */
FUNCTION LF_OBT_TIP_TRANSAC
 (P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_MODULO IN GE_TRANSACCIONES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_TRANSACCIONES.COD_MODALIDAD%TYPE
 )
 RETURN VARCHAR2;
   v_tipo ge_transacciones.tipo%type;

/* Obtener tipo de transacciones. */
FUNCTION LF_OBT_TIP_TRANSAC
 (P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_MODULO IN GE_TRANSACCIONES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_TRANSACCIONES.COD_MODALIDAD%TYPE
 )
 RETURN VARCHAR2
 IS
v_tipo ge_transacciones.tipo%type;
BEGIN
   select tipo
   into v_tipo
   from ge_transacciones
   where cod_transaccion = p_cod_transaccion
   and cod_modulo = p_cod_modulo
   and cod_modalidad = p_cod_modalidad;
   return v_tipo;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Rec. Tipo Det. Trans. '||to_char(p_cod_transaccion)||
      ' Mod. '||to_char(p_cod_modulo)||' Modal. '||to_char(p_cod_modalidad)||
      ' no registrado');
END;
BEGIN
null;
-- se anula porque cualquier transaccion puede tener hijos
/*
   if inserting then
      v_tipo := lf_obt_tip_transac(:new.cod_transaccion, :new.cod_modulo, :new.cod_modalidad);
      if v_tipo <> 'P' then
         raise_application_error(-20000,
         'Solo transacciones padres pueden detallarse');
      end if;
   end if;
*/   
END;
/

