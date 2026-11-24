create or replace procedure it.PRL_ACT_EST_TRANSFERENCIAS is

  v_dias        number(2) := fug_obt_lla_pardinamico('DIA_SIN_CONFIRMAR', null, null, null, null);
  v_fec_actual  date      := pag_cal.fu_obt_fec_actual(7);  
  
  --Se obtiene las operaciones en efectivo que estan sin confirmar despues de n dias
  /*Se comenta este proceso pq en BBVA no matan las Transf.Recibidas, quedan en estado PENDIENTE*/
  cursor tran is
  select rowid registro
    from lc_transferencias tra
    where estado not in ('FO','OK','AN','DE')
      and nro_cta_referencia is null 
      and cod_modalidad = 75
      and v_fec_actual - trunc(fec_recepcion) > v_dias;
begin
 /* for x in tran loop
    update lc_transferencias
      set estado = 'DE'
     where rowid = x.registro;
  end loop;*/null;
end PRL_ACT_EST_TRANSFERENCIAS;
/

