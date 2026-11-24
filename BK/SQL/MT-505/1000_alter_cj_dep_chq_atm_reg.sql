-- Add/modify columns 
alter table CJ_DEP_CHQ_ATM_REG add est_cheque VARCHAR2(30) default 'I';
alter table CJ_DEP_CHQ_ATM_REG add hora VARCHAR2(8);
alter table CJ_DEP_CHQ_ATM_REG add cod_usuario VARCHAR2(10);
alter table CJ_DEP_CHQ_ATM_REG add nro_secuencia NUMBER(3);
-- Add comments to the columns 
comment on column CJ_DEP_CHQ_ATM_REG.est_cheque
  is 'Estado del cheque. I= Ingresado TED,  D = Depositado caja, R= Rechazado caja. , N= No procesado.';
comment on column CJ_DEP_CHQ_ATM_REG.hora
  is 'Hora del movimiento.';
comment on column CJ_DEP_CHQ_ATM_REG.cod_usuario
  is 'Codigo de operador.';
comment on column CJ_DEP_CHQ_ATM_REG.nro_secuencia
  is 'Numero de secuencia.';
