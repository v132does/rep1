create or replace function it.FUT_OBT_TAR_PREPAGAS(p_cod_modalidad in number)
  return varchar2 is
  v_tipo varchar2(2);
begin
  v_tipo := nvl(fug_obt_pardinamico('TIP_TAR_PREPAGA',5,p_cod_modalidad,null,null), 'N');
  return(v_tipo);
exception
  when others then
    return 'N';
end FUT_OBT_TAR_PREPAGAS;
/

