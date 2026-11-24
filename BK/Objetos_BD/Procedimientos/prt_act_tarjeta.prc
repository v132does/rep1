create or replace procedure it.prt_act_tarjeta(p_cod_persona in ba_personas.cod_persona%type,
                                               p_cod_error   out number,
                                               p_mensaje     out varchar) is
begin
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

  p_cod_error := 0;
  p_mensaje   := 'null';

  update it.ta_lin_pre_aprobado t
     set t.sol_activacion = 'S', t.fec_ult_solicitud = trunc(sysdate)
   where t.cod_persona = p_cod_persona
     and t.estado = 'C';

  if sql%notfound then
    p_cod_error := 1;
    p_mensaje   := 'No se encontraron datos para actualizar';
  end if;

exception
  when others then
    p_cod_error := 99;
    p_mensaje   := 'Ha ocurrido un error';
    prg_ins_log_programas('PRT_ACT_TARJETA', substr(sqlerrm, 1, 4000), p_cod_persona, null);
end prt_act_tarjeta;
/

