create or replace function it.fug_obt_cod_banco return number is

  v_cod_banco ge_bancos.cod_banco%type;

begin
  select to_number(substr(pag_gen.fu_obt_cod_entidad,3,2))
    into v_cod_banco
    from dual;
  return(v_cod_banco);
exception
  when others then
    return 0;
end fug_obt_cod_banco;
/

