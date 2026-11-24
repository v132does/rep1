CREATE OR REPLACE FUNCTION IT.FUJ_OBT_NOT_CAJERO
 (P_NRO_CAJA IN NUMBER
 )
 RETURN VARCHAR2
 IS
v_msj varchar2(500) := '';
v_fila varchar2(200);
  PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
begin
  --> CRO-FACPOD-04/11/2014: Se quita el simbolo para evitar desplegar el mensaje en pantalla

  Select substr(descripcion||CHR(10)||detalle,1,490), rowid
    into v_msj, v_fila
    from cr_per_notas b
   where cod_persona = (select cod_persona
                          from ba_usuarios a, cj_cajas j
                         where j.nro_caja = p_nro_caja
                           and j.cod_usuario = a.cod_usuario)
     and estado = 'P' --- Solo notas pendientes
     and medio = 'C' -- solo cajas dydmr-5350
     and rownum = 1;
     -- actualizo el mensaje como enviado
   update cr_per_notas
      set estado = 'R'
    where rowid = v_fila;
  commit;
  return v_msj;
Exception
  When NO_DATA_FOUND Then
     return '';
  When TOO_MANY_ROWS Then
     return v_msj;
end;
/

