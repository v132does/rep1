-- Add/modify columns 
alter table IT.GE_EQU_TARJETAS add dia_atr_cierre VARCHAR2(5);
alter table IT.GE_EQU_TARJETAS add lim_cre_dis_cie varchar2(16);
alter table IT.GE_EQU_TARJETAS add tot_com_cierre varchar2(16);
alter table IT.GE_EQU_TARJETAS add sal_tot_cierre varchar2(16);
alter table IT.GE_EQU_TARJETAS add sal_cuo_cierre varchar2(16);
alter table IT.GE_EQU_TARJETAS add sal_ven_cierre varchar2(16);
alter table IT.GE_EQU_TARJETAS add lim_cre_cierre varchar2(16);
-- Add comments to the columns 
comment on column IT.GE_EQU_TARJETAS.dia_atr_cierre
  is 'Días de atraso al Cierre';
comment on column IT.GE_EQU_TARJETAS.lim_cre_dis_cie
  is 'Límite de crédito / compra disponible al Cierre';
comment on column IT.GE_EQU_TARJETAS.tot_com_cierre
  is 'Total compras del mes al Cierre';
comment on column IT.GE_EQU_TARJETAS.sal_tot_cierre
  is 'Saldo total al Cierre';
comment on column IT.GE_EQU_TARJETAS.sal_cuo_cierre
  is 'Saldo cuotas  al Cierre';
comment on column IT.GE_EQU_TARJETAS.sal_ven_cierre
  is 'Saldo vencido al Cierre';
comment on column IT.GE_EQU_TARJETAS.lim_cre_cierre
  is 'Límite de crédito al Cierre';


