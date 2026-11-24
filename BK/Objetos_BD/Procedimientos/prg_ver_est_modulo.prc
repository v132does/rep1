create or replace procedure it.prg_ver_est_modulo(p_cod_modulo in number,
                                                  p_es_nocturno out varchar2,
                                                  p_fecha out date) is
  --Procedimiento para verificar est modulo--
  --Ver si es nocturno--
  v_est_modulo  ba_modulos.estado%type;
BEGIN
  v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(p_cod_modulo);
  if v_est_modulo = 2 then -- El modulo está abierto
     p_es_nocturno := 'N';
     p_fecha       := pag_cal.FU_OBT_FEC_ACTUAL(p_cod_modulo);
  else
     p_es_nocturno := 'S';
     p_fecha       := pag_cal.FU_OBT_FEC_PROXIMA(p_cod_modulo);
  end if;
exception
  when others then
    raise_application_error(-20000, 'Error en prg_ver_est_modulo : '||sqlerrm);
END;
/

