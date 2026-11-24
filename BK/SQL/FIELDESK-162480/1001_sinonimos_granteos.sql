create or replace public synonym sv_salida_de_efectivo for it.sv_salida_de_efectivo;
grant select on it.sv_salida_de_efectivo to dev_temporal;

create or replace public synonym sv_salida_de_efectivo_res for it.sv_salida_de_efectivo_res;
grant select on it.sv_salida_de_efectivo_res to dev_temporal;

create or replace public synonym fub_obt_venc_aplazo for it.fub_obt_venc_aplazo;
grant execute on it.fub_obt_venc_aplazo to dev_temporal;

create or replace public synonym psb_lcr_liq_inv_tmp for it.sb_lcr_liq_inv_tmp;
grant select, insert, update, delete on it.psb_lcr_liq_inv_tmp to dev_temporal;
