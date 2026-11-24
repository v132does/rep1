CREATE OR REPLACE PROCEDURE IT.PRP_ACT_VEN_LIM_GLOBAL IS
v_fec_actual date;

cursor c_lim_global is
    select rowid fila, nro_linea
      from pr_gru_lineas
     where trunc(fec_vencimiento) <=  v_fec_actual
      and estado not in ('C','V');
begin
  v_fec_actual := PAG_CAL.FU_OBT_FEC_ACTUAL(6);

  for c_lim in c_lim_global loop

    prp_ins_his_lim_global(c_lim.nro_linea);

    begin
      update pr_gru_lineas set estado = 'V'
       where rowid = c_lim.fila;
    exception
      when others then
          raise_application_error(-20000,'Act. Vto. Límite Global N°:'||c_lim.nro_linea||'. '||sqlerrm);
    end;
  end loop;
end PRP_ACT_VEN_LIM_GLOBAL;
/

