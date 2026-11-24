CREATE OR REPLACE PROCEDURE IT.PRJ_VAL_DUPLICACION
   (p_nro_caja  in number,
    p_cod_tra_padre in number,
    p_cod_moneda in varchar2,
    p_nro_documento in number,
    p_cod_respuesta in out varchar2,
    p_msj_respuesta in out varchar2) 
 IS 
 v_dato varchar2(100);
BEGIN
   Select 0 into v_dato
     from cj_movimientos
    where nro_caja = p_nro_caja
      and cod_tra_padre = p_cod_tra_padre
      and cod_moneda = p_cod_moneda
      and nro_documento = p_nro_documento
      and estado IN ('N','P')
      and cod_tra_padre not in (357,360,355)  -- no se valida el pago de cupon,ni cobro cuota caja, ni desglose de cheques
      and rownum = 1;
   -- ya existe el comprobante ingresado   
   p_cod_respuesta := '001';
   p_msj_respuesta := 'Documento ya ingresado al sistema.';
exception
  when no_data_found then
     return;   
  when too_many_rows then
     p_cod_respuesta := '001';
     p_msj_respuesta := 'Documento ya ingresado al sistema.';
  when others then
     p_cod_respuesta := '999';
     p_msj_respuesta := 'CJ_MOVIMIENTOS '||SQLERRM;      
END PRJ_VAL_DUPLICACION;
/

