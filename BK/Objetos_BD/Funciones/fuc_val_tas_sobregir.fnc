CREATE OR REPLACE FUNCTION IT.FUC_VAL_TAS_SOBREGIR
 (P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_VAL_TASA IN NUMBER := 0
 )
 RETURN VARCHAR2
 IS

V_MSG VARCHAR2(200);
-- Retorna nulo si la tasa es valida de lo contrario el mensaje de error.
/*   Objetivo      : Se creo para que se encargue de verificar si la tasa ingresada esta
   								 dentro del rango permitido. Este procedimiento debe reemplazar a las
   								 verificaciones de tasa de sobregiro existentes.
*/
Begin
   /* Ver si no se tiene que preguntar por el codigo de la Moneda Guaranies
    de la Tabla parametros.*/
   If p_cod_moneda = pag_gen.fu_obt_mon_local and nvl(p_val_tasa, 0) not between 1 and 48 Then
      v_msg := 'Tasa para '||pag_gen.fu_obt_mon_local||' debe ser menor a 48';
      If nvl(p_val_tasa, 0) <= 0 Then
         v_msg := 'Tasa para '||pag_gen.fu_obt_mon_local||' debe ser mayor a 0';
      End If;
   Elsif p_cod_moneda = pag_gen.fu_obt_mon_fuerte and nvl(p_val_tasa, 0) not between 1 and 20 Then
      v_msg := 'Tasa para '||pag_gen.fu_obt_mon_fuerte||' debe ser menor a 20';
      If nvl(p_val_tasa, 0) <= 0 Then
         v_msg := 'Tasa para '||pag_gen.fu_obt_mon_fuerte||' debe ser mayor a 0';
      End If;
   End If;
   Return v_msg;
End;
/

