CREATE OR REPLACE PROCEDURE IT.prp_act_est_prestamos IS

BEGIN

  --for reg in prestamo loop
  BEGIN
    delete from ba_per_gen_ofertas a
     where exists (Select t.cod_pre_aprobado, t.cod_persona
              from it.pr_pre_aprobados t
             where t.fec_fin_oferta <= pag_cal.fu_obt_fec_actual(3)
               and t.estado in ('C', 'G')
               and t.cod_persona = a.cod_persona);
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20001,
                              'Error al borrar la oferta. ' || sqlerrm);
  END;

  begin
    update pr_pre_aprobados t
       set t.estado = 'V'
     where t.fec_fin_oferta <= pag_cal.fu_obt_fec_actual(3)
       and t.estado in ('C', 'G');
  exception
    when others then
      raise_application_error(-20001,
                              'Error al actualizar pr_pre_aprobados. ' ||
                              sqlerrm);
  end;
  --end loop;

exception
  when others then
    raise_application_error(-20000,
                            'Error en PRP_ACT_EST_PRESTAMOS: ' || sqlerrm);
END;
/

