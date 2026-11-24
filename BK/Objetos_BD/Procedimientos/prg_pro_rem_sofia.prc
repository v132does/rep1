create or replace procedure it.prg_pro_rem_sofia is
v_fecha date := pag_cal.FU_OBT_FEC_ACTUAL(4);
begin
for i in 1..3
loop
  v_fecha := pag_cal.fu_obt_fec_habil(v_fecha-1,-1, 1);
end loop;
   -- este proceso permite generar la remision automatica de los cobros del sistema sofia
   prg_pro_remision(fug_obt_pardinamico('COD_SER_SOFIA'),999,v_fecha);
end;
/

