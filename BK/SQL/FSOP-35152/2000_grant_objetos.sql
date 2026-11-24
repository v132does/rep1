BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END;
/
grant select on IT.GE_CAUSALES_DET to IT_TEMPORAL;
create or replace public synonym GE_CAUSALES_DET for IT.GE_CAUSALES_DET;
grant execute on IT.fue_obt_dat_camp_fec to IT_TEMPORAL;
create or replace public synonym fue_obt_dat_camp_fec for IT.fue_obt_dat_camp_fec;
grant execute on IT.fug_obt_cod_cau_bcp to IT_TEMPORAL;
create or replace public synonym fug_obt_cod_cau_bcp for IT.fug_obt_cod_cau_bcp;

grant select on IT.cc_movimientos_his to IT_TEMPORAL;
create or replace public synonym cc_movimientos_his for IT.cc_movimientos_his;
commit;
