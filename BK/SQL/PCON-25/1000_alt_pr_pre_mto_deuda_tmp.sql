  -- add/modify columns 
alter table it.pr_pre_mto_deuda_tmp 
add tot_cargo number(18,2);
-- add comments to the table 
comment on column it.pr_pre_mto_deuda_tmp.tot_cargo
  is 'Total cargo por cuota.';
