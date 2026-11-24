CREATE OR REPLACE FUNCTION IT.fui_obt_mov_cuenta
(P_FECHA IN DATE, P_HORA IN VARCHAR2, P_COD_USUARIO IN VARCHAR2)
RETURN VARCHAR2 IS
v_nro_cuenta varchar2(20);
BEGIN
   if p_fecha = pai_sgt.V_FEC_PROCESO then
     SELECT NRO_CUENTA
       INTO V_NRO_CUENTA
       FROM ge_movimientos
      WHERE FECHA = P_FECHA
        AND HORA = P_HORA
        AND COD_USUARIO = P_COD_USUARIO
        AND NRO_CUENTA IS NOT NULL
        AND ROWNUM = 1;
   else
     SELECT NRO_CUENTA
       INTO V_NRO_CUENTA
       FROM gv_movimientos
      WHERE FECHA = P_FECHA
        AND HORA = P_HORA
        AND COD_USUARIO = P_COD_USUARIO
        AND NRO_CUENTA IS NOT NULL
        AND ROWNUM = 1;    
   end if;  
   RETURN V_NRO_CUENTA;
EXCEPTION
   WHEN OTHERS THEN
      --raise_application_error(-20000,' Mov de '||p_fecha||' '||p_hora||' '||p_cod_usuario||' no tiene cuenta.Verificar');
   V_NRO_CUENTA:= '1075810';
   RETURN V_NRO_CUENTA;
END;
/

