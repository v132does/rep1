create or replace procedure it.prb_des_gra_asientos is
begin
prg_act_par_dinamico('BLO_GRA_ASIENTOS',null, null, null, null, 'N');
exception
  when others then
    RAISE_APPLICATION_ERROR(-20000,'Error en prb_des_gra_asientos '||sqlerrm);
end prb_des_gra_asientos;
/

