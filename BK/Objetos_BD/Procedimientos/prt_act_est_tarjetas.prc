CREATE OR REPLACE PROCEDURE IT.prt_act_est_tarjetas IS
BEGIN

  update ta_lin_pre_aprobado
     set estado = 'V'
   where fec_fin_oferta <= Trunc(Sysdate)
     and estado in ('C', 'G');
EXCEPTION
 when others then
    raise_application_error(-20000,
                            'Error en PRT_ACT_EST_TARJETAS: ' || sqlerrm);

END;
/

