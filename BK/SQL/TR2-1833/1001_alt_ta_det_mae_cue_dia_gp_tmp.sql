alter table IT.TA_DET_MAE_CUE_DIA_GP_TMP
add( MTO_CAR_SUSPENSO NUMBER(19,4),
     IVA_INT_SUSPENSO NUMBER(19,4),
     IVA_CAR_SUSPENSO NUMBER(19,4),
     TOT_CAR_SUSPENSO NUMBER(19,4) );
     
alter table IT.TA_DET_MAE_CUE_DIA_GP_TMP modify filler VARCHAR2(95);

comment on column IT.TA_DET_MAE_CUE_DIA_GP_TMP.int_cor_suspenso
  is 'Interes corriente en suspenso acumulados pendiente de aplicar Sin IVA';
comment on column IT.TA_DET_MAE_CUE_DIA_GP_TMP.int_mor_suspenso
  is 'Interes moratorio en suspenso acumulados pendiente de aplicar Sin IVA';
comment on column IT.TA_DET_MAE_CUE_DIA_GP_TMP.int_pun_suspenso
  is 'Interes punitorio en suspenso acumulados pendiente de aplicar Sin IVA';   
comment on column IT.TA_DET_MAE_CUE_DIA_GP_TMP.mto_car_suspenso
  is 'Cargos en suspenso acumulados pendiente de aplicar Sin IVA';
comment on column IT.TA_DET_MAE_CUE_DIA_GP_TMP.iva_int_suspenso
  is 'IVA de todos los intereses en suspenso (IVA de campos 48, 49, 50)';
comment on column IT.TA_DET_MAE_CUE_DIA_GP_TMP.iva_car_suspenso
  is 'IVA de los cargos en suspenso acumulados pendientes de aplicar (IVA de campo 51)';
comment on column IT.TA_DET_MAE_CUE_DIA_GP_TMP.tot_car_suspenso
  is 'Sumatoria de Campos 48, 49, 50, 51, 52, 53';
