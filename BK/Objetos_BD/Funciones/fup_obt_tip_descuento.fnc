create or replace function it.FUP_OBT_TIP_DESCUENTO(p_cod_modalidad in number)
  return varchar2 is
  v_tipo varchar2(2);
begin
  v_tipo := FUG_OBT_PARDINAMICO('TIP_DES_DOCUMENTOS',6,p_cod_modalidad,null,null);
  return(v_tipo);
exception
  when others then 
    return null;
end FUP_OBT_TIP_DESCUENTO;
/

