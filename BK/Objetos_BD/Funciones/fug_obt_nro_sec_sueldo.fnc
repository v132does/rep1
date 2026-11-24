create or replace function it.fug_obt_nro_sec_sueldo
  ( p_nro_lote IN VARCHAR2,
   p_cod_usuario IN VARCHAR2 )
  return NUMBER is
  v_max_sec_use_fgdiari NUMBER(07);
begin
  select max (nro_secuencia)
  INTO v_max_sec_use_fgdiari  
  from ge_movimientos 
  where nro_documento2=p_nro_lote
  and cod_usuario= p_cod_usuario;
  return(v_max_sec_use_fgdiari);
exception
  when others then
     raise_application_error(-20000,'fug_obt_nro_sec_sueldo'||sqlerrm);
end fug_obt_nro_sec_sueldo;
/

