CREATE OR REPLACE PROCEDURE IT.PRJ_VER_PEN_CAJA
 (P_NRO_CUENTA IN VARCHAR2
 ,P_COD_TRA_PADRE IN NUMBER
 ,P_FECHA IN DATE
 ,P_USUARIO OUT VARCHAR2
 ,P_HORA OUT VARCHAR2
 ,P_COD_TRANSACCION OUT NUMBER
 ,P_COD_RESPUESTA OUT VARCHAR2
 ,P_MSJ_RESPUESTA OUT VARCHAR2
 )
 IS
BEGIN
  declare
    v_hora   varchar2(8);
    v_tran   number(4);
 Begin
 /*Modif VC 27/04/05 se agregó el usuario*/
      Select g.hora , g.cod_transaccion, g.cod_usuario into v_hora, v_tran, p_usuario
     from ge_movimientos g
    where g.cod_tra_padre = p_cod_tra_padre and
          g.fecha         = p_fecha and
          g.reversado     = 'N' and
          g.estado        = 'J'
          and exists
             (select 1 from ge_movimientos mov
                  where  mov.nro_cuenta    = p_nro_cuenta
                     and mov.cod_tra_padre = p_cod_tra_padre
                     and mov.fecha         = g.fecha
                     and mov.hora          = g.hora
                     and mov.reversado     = 'N'
                     and mov.cod_usuario   = g.cod_usuario ) and
          rownum = 1;


   p_hora            :=  v_hora;
   p_cod_transaccion :=  v_tran;

   -- es pendiente de pasar por caja
   p_cod_respuesta := '001';
 exception
  when no_data_found then
   p_cod_respuesta := '000';
  when others then
     p_cod_respuesta := '999';
     p_msj_respuesta := 'PRJ_VER_PEN_CAJA:'||SQLERRM;
 end;

END PRJ_VER_PEN_CAJA;
/

