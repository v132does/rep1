ALTER TABLE it.cr_per_tip_operaciones_tmp ADD (
    fon_propio  varchar2(1) default 'N' ,
    fon_salario varchar2(1) default 'N' , 
    fon_prestamos   varchar2(1) default 'N' ,
    fon_vta_activos varchar2(1) default 'N' ,
    fon_ren_financieras varchar2(1) default 'N' ,
    fon_ahorro   varchar2(1) default 'N' ,
    fon_herencia varchar2(1) default 'N' ,
    fon_transferencias varchar2(1) default 'N' ,
    fon_otros varchar2(35) default null,
    pro_ingresos varchar2(1) default 'N' ,
    pro_ahorros  varchar2(1) default 'N' ,
    pro_ven_alq  varchar2(1) default 'N' ,
    pro_gas_operativos varchar2(1) default 'N' ,
    pro_otros varchar2(35) default  null
   
);

  comment on column cr_per_tip_operaciones_tmp.fon_propio
  is 'Indica si tiene Fondo Propio (S/N).';
  comment on column cr_per_tip_operaciones_tmp.fon_salario
  is 'Salario';
  comment on column cr_per_tip_operaciones_tmp.fon_prestamos
  is 'Préstamos.';
  comment on column cr_per_tip_operaciones_tmp.fon_vta_activos
  is 'Venta de Activos.';
  comment on column cr_per_tip_operaciones_tmp.fon_ren_financieras
  is 'Renovaciones Financieras.';
  comment on column cr_per_tip_operaciones_tmp.fon_ahorro
  is 'Ahorro';
  comment on column cr_per_tip_operaciones_tmp.fon_herencia
  is 'Herencia.';
  comment on column cr_per_tip_operaciones_tmp.fon_transferencias
  is 'Transferencias.';
  comment on column cr_per_tip_operaciones_tmp.fon_otros
  is 'Otros.';
  comment on column cr_per_tip_operaciones_tmp.pro_ingresos
  is 'Ingresos.';
   comment on column cr_per_tip_operaciones_tmp.pro_ahorros
  is 'Ahorros.';
  comment on column cr_per_tip_operaciones_tmp.pro_ven_alq
  is 'Venta/Alquileres.';
  comment on column cr_per_tip_operaciones_tmp.pro_gas_operativos
  is 'Gastos Operativos.';
  comment on column cr_per_tip_operaciones_tmp.pro_otros
  is 'Otros.';
  
  
  
  
