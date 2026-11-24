create or replace procedure it.prg_rea_pre_aprobados(p_lote          ge_pro_pre_aprobados.lote%type,
                                                     p_cod_persona   ge_pro_pre_aprobados.cod_persona%type,
                                                     p_nro_solicitud ge_pro_pre_aprobados.nro_solicitud%type,
                                                     p_cod_modulo    ge_pro_pre_aprobados.cod_modulo%type) IS
  --DYDMR-7966 - Incidencia SAU - ITGF - Solicitud TDC con Preaprobados
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN

  if p_cod_modulo = 5 and p_nro_solicitud is not null then
    begin
      UPDATE ge_pro_pre_aprobados
         SET estado              = 'V',
             cod_causa           = null,
             cod_usu_cancelacion = null,
             nro_solicitud       = null,
             cod_modalidad       = null,
             cod_sub_modalidad   = null
       WHERE cod_persona = p_cod_persona
         AND nro_solicitud = p_nro_solicitud
         AND estado = 'C'
         AND lote = p_lote;
    exception
      when others then
        raise_application_error(-20000,
                                'Al Actualizar ge_pro_pre_aprobados. ' ||
                                sqlerrm);
    end;
  
  elsif p_cod_modulo = 6 and p_nro_solicitud is not null then
    begin
      UPDATE ge_pro_pre_aprobados
         SET estado              = 'V',
             cod_causa           = null,
             cod_usu_cancelacion = null,
             nro_solicitud       = null
       WHERE cod_persona = p_cod_persona
         AND nro_solicitud = p_nro_solicitud
         AND estado = 'C'
         AND lote = p_lote;
    exception
      when others then
        raise_application_error(-20001,
                                'Al Actualizar ge_pro_pre_aprobados. ' ||
                                sqlerrm);
    end;
  
  end if;
  commit;
exception
  when others then
    raise_application_error(-20002,
                            'en proceso: prg_rea_pre_aprobados. ' ||
                            sqlerrm);
END;
/

