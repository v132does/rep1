create or replace procedure it.prw_ins_not_pag_sueldos(p_concepto   it.bw_not_pag_sueldos.concepto%type,
                                                     p_nro_cuenta it.bw_not_pag_sueldos.nro_cuenta%type) is
  v_cod_persona it.bw_not_pag_sueldos.cod_persona%type;
  v_estado      it.bw_not_pag_sueldos.estado%type := 'PENDING';
begin
  --obtenemos el principal de la cuenta
  v_cod_persona := it.fug_obt_cli_principal(p_nro_cuenta, 'P');
  insert into it.bw_not_pag_sueldos (concepto, nro_cuenta, cod_persona, estado) 
  values (p_concepto, p_nro_cuenta, v_cod_persona, v_estado);

exception
  when others then
    null;
end;
/