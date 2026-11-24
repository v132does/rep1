create or replace procedure it.PRB_GEN_ASI_PAGINADO is
  v_result varchar2(100);
begin
  v_result := pai_int.gen_asientos_paginado('INTERFAZ_DE_ASIENTOS_'||TO_CHAR(SYSDATE,'YYMMDD'), 10000);
/*  if v_result is not null then
     raise_application_error(-20000,'Error '||v_result);
  end if;*/
end PRB_GEN_ASI_PAGINADO;
/

