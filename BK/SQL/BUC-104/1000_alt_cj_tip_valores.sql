alter table it.cj_tip_valores add estado VARCHAR2(1) default 'S'; 
comment on column it.cj_tip_valores.estado is 'Indica Estado de Valor (S-Activo, N-Inactivo.)'; 
