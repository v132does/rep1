create or replace function it.fug_obt_concepto_his
  ( p_nro_cuenta IN VARCHAR2,
  p_nro_lote IN VARCHAR2,
    p_cod_mad_padre IN VARCHAR2,
   p_cod_mod_padre IN VARCHAR2,
   p_cod_tra_padre IN VARCHAR2 )
  return varchar2 is
  v_cnmovim varchar2(50);
begin
                 select decode(p_cod_tra_padre,'304','Pago de  Sueldo','1304','Pago de  Aguinaldo','1305','Pago de  Comision','1306','Credito en  Cuenta',null)
                 into v_cnmovim
                 from gv_movimientos
                 where nro_cuenta=p_nro_cuenta
                 and nro_documento2=p_nro_lote
                 and cod_mad_padre =p_cod_mad_padre
                 and cod_mod_padre = p_cod_mod_padre
                 and cod_tra_padre=p_cod_tra_padre 
                 and cod_transaccion = 503;
  return(v_cnmovim);
exception
  when others then
      raise_application_error(-20000,'fug_obt_concepto'||sqlerrm);
end fug_obt_concepto_his;
/

