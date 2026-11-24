create or replace function it.FUP_OBT_TIP_AFD(p_cod_modalidad in number)
  return varchar2 is
  v_tipo varchar2(2);
begin
-- MODALIDADES DE PRESTAMOS PARA AFD
  v_tipo := FUG_OBT_PARDINAMICO('TIP_AFD',6,p_cod_modalidad,null,null);
  return(v_tipo);
exception
  when others then
    return NULL;
end FUP_OBT_TIP_AFD;
/

