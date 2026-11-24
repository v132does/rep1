-- Add/modify columns 
alter table IT.GE_EQU_TARJETAS_HIS add dia_atr_cierre VARCHAR2(5);
alter table IT.GE_EQU_TARJETAS_HIS add lim_cre_dis_cie VARCHAR2(16);
alter table IT.GE_EQU_TARJETAS_HIS add tot_com_cierre VARCHAR2(16);
alter table IT.GE_EQU_TARJETAS_HIS add sal_tot_cierre VARCHAR2(16);
alter table IT.GE_EQU_TARJETAS_HIS add sal_cuo_cierre VARCHAR2(16);
alter table IT.GE_EQU_TARJETAS_HIS add sal_ven_cierre VARCHAR2(16);
alter table IT.GE_EQU_TARJETAS_HIS add lim_cre_cierre VARCHAR2(16);
-- Add comments to the columns 
comment on column IT.GE_EQU_TARJETAS_HIS.dia_atr_cierre
  is 'Días de atraso al Cierre';
comment on column IT.GE_EQU_TARJETAS_HIS.lim_cre_dis_cie
  is 'Límite de crédito / compra disponible al Cierre';
comment on column IT.GE_EQU_TARJETAS_HIS.tot_com_cierre
  is 'Total compras del mes al Cierre';
comment on column IT.GE_EQU_TARJETAS_HIS.sal_tot_cierre
  is 'Saldo total al Cierre';
comment on column IT.GE_EQU_TARJETAS_HIS.sal_cuo_cierre
  is 'Saldo cuotas  al Cierre';
comment on column IT.GE_EQU_TARJETAS_HIS.sal_ven_cierre
  is 'Saldo vencido al Cierre';
comment on column IT.GE_EQU_TARJETAS_HIS.lim_cre_cierre
  is 'Límite de crédito al Cierre';
