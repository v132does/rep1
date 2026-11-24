create or replace procedure it.PRT_ELI_TAB_BANCARD
as
begin
execute immediate 'truncate table it.ta_tarjetas_tmp';
execute immediate 'truncate table it.ta_cobros_tmp';
execute immediate 'truncate table it.ta_cta_tarjetas_tmp';
execute immediate 'truncate table it.ta_cta_tarjetas_pro_tmp';
execute immediate 'truncate table it.ta_cta_lin_tarjetas_tmp';
execute immediate 'truncate table it.ta_cta_sal_tarjetas_tmp';
execute immediate 'truncate table it.ta_cuentas_tmp';
execute immediate 'truncate table it.ta_int_per_tarjetas_tmp';
execute immediate 'truncate table it.ta_personas_tmp';
execute immediate 'truncate table it.ta_tar_cuentas_tmp';
execute immediate 'truncate table it.ta_sal_fin_tarjetas_tmp';
execute immediate 'truncate table it.ta_tas_int_tarjetas_tmp';
execute immediate 'truncate table it.ta_mov_diarios_tmp';
execute immediate 'truncate table it.ta_mov_intereses_tmp';
execute immediate 'truncate table it.ta_seg_vida_tmp';
execute immediate 'truncate table it.ta_mov_extracto_tmp';
execute immediate 'truncate table it.ta_mov_resumenes_tmp';
execute immediate 'truncate table it.ta_inf_gas_financieros_tmp';
end;
/

