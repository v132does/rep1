create or replace function it.fug_es_banco(p_cod_persona ge_bancos.cod_persona%type)
  return varchar2 is
  v_es_banco varchar2(1);
  v_fun_lim_bancos ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('OPE_CAM_HAB_LIM_BANCOS');
  v_per_excluida   ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('OPE_CAM_LIM_PER_EXCLUIDA');
begin
  select distinct 'S'
    into v_es_banco
    from ge_bancos g
   where g.cod_persona = p_cod_persona
     ---Bancos Excluidos de control - Excepción BCP - Persona 89603
     and instr(','||v_per_excluida||',',','||g.cod_persona||',') < 1;

 if v_fun_lim_bancos = 'N' then
    v_es_banco := 'N';
    return nvl(v_es_banco, 'N');
 else   
    return nvl(v_es_banco, 'N');
 end if;

exception
  when no_data_found then
    v_es_banco := 'N';
    return v_es_banco;
  when others then
    v_es_banco := 'N';
    return v_es_banco;
end;
/

