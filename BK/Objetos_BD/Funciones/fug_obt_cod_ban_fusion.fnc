create or replace function it.fug_obt_cod_ban_fusion return number is

  v_cod_banco ge_bancos.cod_banco%type;

begin
  select to_number(fug_obt_pardinamico('COD_BAN_FUSION'))
    into v_cod_banco
    from dual;
  return(v_cod_banco);
exception
  when others then
    return 0;
end fug_obt_cod_ban_fusion;
/

