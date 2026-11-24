create or replace procedure it.prg_ver_mod_horario(p_cod_modulo in number default null) is
  v_est_modulo   ba_modulos.estado%type;
  v_horario      varchar2(1) := 'D'; -- (D) Dia, (T) Tarde, (N) Nocturno
  v_cod_modulo ba_modulos.cod_modulo%type;
begin
  v_cod_modulo := nvl(p_cod_modulo,4);
  v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(v_cod_modulo);
  if v_est_modulo = 2 Then -- El modulo está abierto
     v_horario := 'D'; --- Día
  else
     v_horario := 'N'; --- Noche
  end if;
  pag_cta.g_horario := v_horario; -- seteamos la variable global del pag_cta
exception
  when others then
    raise_application_error(-20001,'Error en prg_ver_mod_horario: '||sqlerrm);
end prg_ver_mod_horario;
/

