CREATE OR REPLACE PROCEDURE IT.PRJ_VAL_MONEDA
   (p_cod_moneda in varchar2,
    p_cod_respuesta in out varchar2,
    p_msj_respuesta in out varchar2) 
 IS 
 v_descripcion varchar2(100);
BEGIN
   Select descripcion
     into v_descripcion
     from ba_monedas
    where cod_moneda = p_cod_moneda;
exception
  when no_data_found then
     p_cod_respuesta := '001';
     p_msj_respuesta := 'Moneda no habilitada en el Sistema.';
  when too_many_rows then
     p_cod_respuesta := '002';
     p_msj_respuesta := 'Moneda duplicada.';
  when others then
     p_cod_respuesta := '999';
     p_msj_respuesta := 'BA_MONEDAS '||SQLERRM;      
END PRJ_VAL_MONEDA;
/

