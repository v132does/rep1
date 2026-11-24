
--- sinonimo ---
create or replace public synonym prg_obt_dat_par_beneficiario for IT.prg_obt_dat_par_beneficiario;
create or replace public synonym prg_obt_fec_val_transferencia for IT.prg_obt_fec_val_transferencia;
create or replace public synonym prs_tra_obt_usu_hor_mov_env for IT.prs_tra_obt_usu_hor_mov_env;
create or replace public synonym prg_pro_mov_transferencia for IT.prg_pro_mov_transferencia;

create or replace public synonym TYP_TRA_MOVIMIENTO for IT.TYP_TRA_MOVIMIENTO;
create or replace public synonym S_COD_TRANSFERENCIA for IT.S_COD_TRANSFERENCIA;
create or replace public synonym GE_DAT_TRANSFERENCIAS for IT.GE_DAT_TRANSFERENCIAS;
--
create or replace public synonym s_hor_mov_bepsa_bepsa1 for IT.s_hor_mov_bepsa_bepsa1;
create or replace public synonym s_hor_mov_bepsa_bepsa2 for IT.s_hor_mov_bepsa_bepsa2;
create or replace public synonym s_hor_mov_bepsa_bepsa3 for IT.s_hor_mov_bepsa_bepsa3;
create or replace public synonym s_hor_mov_bepsa_bepsa4 for IT.s_hor_mov_bepsa_bepsa4;
create or replace public synonym s_hor_mov_bepsa_bepsa5 for IT.s_hor_mov_bepsa_bepsa5;
create or replace public synonym s_hor_mov_bepsa_bepsa6 for IT.s_hor_mov_bepsa_bepsa6;
create or replace public synonym s_hor_mov_bepsa_bepsa7 for IT.s_hor_mov_bepsa_bepsa7;
create or replace public synonym s_hor_mov_bepsa_bepsa8 for IT.s_hor_mov_bepsa_bepsa8;
create or replace public synonym s_hor_mov_bepsa_bepsa9 for IT.s_hor_mov_bepsa_bepsa9;
create or replace public synonym s_hor_mov_bepsa_bepsa10 for IT.s_hor_mov_bepsa_bepsa10;
--
create or replace public synonym s_hor_mov_transfer_transfer1 for IT.s_hor_mov_transfer_transfer1;
create or replace public synonym s_hor_mov_transfer_transfer2 for IT.s_hor_mov_transfer_transfer2;
create or replace public synonym s_hor_mov_transfer_transfer3 for IT.s_hor_mov_transfer_transfer3;
create or replace public synonym s_hor_mov_transfer_transfer4 for IT.s_hor_mov_transfer_transfer4;
create or replace public synonym s_hor_mov_transfer_transfer5 for IT.s_hor_mov_transfer_transfer5;
create or replace public synonym s_hor_mov_transfer_transfer6 for IT.s_hor_mov_transfer_transfer6;
create or replace public synonym s_hor_mov_transfer_transfer7 for IT.s_hor_mov_transfer_transfer7;
create or replace public synonym s_hor_mov_transfer_transfer8 for IT.s_hor_mov_transfer_transfer8;
create or replace public synonym s_hor_mov_transfer_transfer9 for IT.s_hor_mov_transfer_transfer9;
create or replace public synonym s_hor_mov_transfer_transfer10 for IT.s_hor_mov_transfer_transfer10;

--
create or replace public synonym s_hor_mov_pagopar_pagopar1 for IT.s_hor_mov_pagopar_pagopar1;
create or replace public synonym s_hor_mov_pagopar_pagopar2 for IT.s_hor_mov_pagopar_pagopar2;
create or replace public synonym s_hor_mov_pagopar_pagopar3 for IT.s_hor_mov_pagopar_pagopar3;
create or replace public synonym s_hor_mov_pagopar_pagopar4 for IT.s_hor_mov_pagopar_pagopar4;
create or replace public synonym s_hor_mov_pagopar_pagopar5 for IT.s_hor_mov_pagopar_pagopar5;
create or replace public synonym s_hor_mov_pagopar_pagopar6 for IT.s_hor_mov_pagopar_pagopar6;
create or replace public synonym s_hor_mov_pagopar_pagopar7 for IT.s_hor_mov_pagopar_pagopar7;
create or replace public synonym s_hor_mov_pagopar_pagopar8 for IT.s_hor_mov_pagopar_pagopar8;
create or replace public synonym s_hor_mov_pagopar_pagopar9 for IT.s_hor_mov_pagopar_pagopar9;
create or replace public synonym s_hor_mov_pagopar_pagopar10 for IT.s_hor_mov_pagopar_pagopar10;


--- granteo ---
grant execute on it.prg_obt_dat_par_beneficiario to IT_TEMPORAL;
grant execute on it.prg_obt_fec_val_transferencia to IT_TEMPORAL;
grant execute on it.prs_tra_obt_usu_hor_mov_env to IT_TEMPORAL;
grant execute on it.prg_pro_mov_transferencia to IT_TEMPORAL;
grant execute on it.TYP_TRA_MOVIMIENTO to IT_TEMPORAL;
grant select on it.S_COD_TRANSFERENCIA to IT_TEMPORAL;
grant select on it.s_hor_mov_transfer_transfer1 to IT_TEMPORAL;
grant select on it.s_hor_mov_transfer_transfer2 to IT_TEMPORAL;
grant select on it.s_hor_mov_transfer_transfer3 to IT_TEMPORAL;
grant select on it.s_hor_mov_transfer_transfer4 to IT_TEMPORAL;
grant select on it.s_hor_mov_transfer_transfer5 to IT_TEMPORAL;
grant select on it.s_hor_mov_transfer_transfer6 to IT_TEMPORAL;
grant select on it.s_hor_mov_transfer_transfer7 to IT_TEMPORAL;
grant select on it.s_hor_mov_transfer_transfer8 to IT_TEMPORAL;
grant select on it.s_hor_mov_transfer_transfer9 to IT_TEMPORAL;
grant select on it.s_hor_mov_transfer_transfer10 to IT_TEMPORAL;
--
grant select on it.s_hor_mov_pagopar_pagopar1 to IT_TEMPORAL;
grant select on it.s_hor_mov_pagopar_pagopar2 to IT_TEMPORAL;
grant select on it.s_hor_mov_pagopar_pagopar3 to IT_TEMPORAL;
grant select on it.s_hor_mov_pagopar_pagopar4 to IT_TEMPORAL;
grant select on it.s_hor_mov_pagopar_pagopar5 to IT_TEMPORAL;
grant select on it.s_hor_mov_pagopar_pagopar6 to IT_TEMPORAL;
grant select on it.s_hor_mov_pagopar_pagopar7 to IT_TEMPORAL;
grant select on it.s_hor_mov_pagopar_pagopar8 to IT_TEMPORAL;
grant select on it.s_hor_mov_pagopar_pagopar9 to IT_TEMPORAL;
grant select on it.s_hor_mov_pagopar_pagopar10 to IT_TEMPORAL;
--
grant select on it.s_hor_mov_bepsa_bepsa1 to IT_TEMPORAL;
grant select on it.s_hor_mov_bepsa_bepsa2 to IT_TEMPORAL;
grant select on it.s_hor_mov_bepsa_bepsa3 to IT_TEMPORAL;
grant select on it.s_hor_mov_bepsa_bepsa4 to IT_TEMPORAL;
grant select on it.s_hor_mov_bepsa_bepsa5 to IT_TEMPORAL;
grant select on it.s_hor_mov_bepsa_bepsa6 to IT_TEMPORAL;
grant select on it.s_hor_mov_bepsa_bepsa7 to IT_TEMPORAL;
grant select on it.s_hor_mov_bepsa_bepsa8 to IT_TEMPORAL;
grant select on it.s_hor_mov_bepsa_bepsa9 to IT_TEMPORAL;
grant select on it.s_hor_mov_bepsa_bepsa10 to IT_TEMPORAL;
--
grant select,insert,update,delete on it.GE_DAT_TRANSFERENCIAS to IT_TEMPORAL;

