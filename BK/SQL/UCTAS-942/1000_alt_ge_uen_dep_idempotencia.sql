alter table it.ge_uen_dep_idempotencia rename column idempotency_key to cod_idempotencia;
alter table it.ge_uen_dep_idempotencia rename column status to estado;
alter table it.ge_uen_dep_idempotencia modify estado varchar2(30);
alter table it.ge_uen_dep_idempotencia rename column movement_id to referencia;
alter table it.ge_uen_dep_idempotencia rename column created_at to fec_insercion;
alter table it.ge_uen_dep_idempotencia rename column response to datos;
alter table it.ge_uen_dep_idempotencia modify datos varchar2(500);
alter table it.ge_uen_dep_idempotencia add fec_modificacion date default sysdate not null;
alter table it.ge_uen_dep_idempotencia add usu_insercion varchar2(10) default substr(user,1,10) not null;
alter table it.ge_uen_dep_idempotencia add usu_modificacion varchar2(10) default substr(user,1,10) not null;
comment on column IT.ge_uen_dep_idempotencia.cod_idempotencia
  is 'Codigo de idempotencia';
comment on column IT.ge_uen_dep_idempotencia.estado
  is 'Estado del registro';
comment on column IT.ge_uen_dep_idempotencia.referencia
  is 'Referencia del registro';
comment on column IT.ge_uen_dep_idempotencia.datos
  is 'Datos del registro';
comment on column IT.ge_uen_dep_idempotencia.fec_insercion
  is 'Fecha de insercion del registro';
comment on column IT.ge_uen_dep_idempotencia.usu_insercion
  is 'Usuario que inserto el registro';
comment on column IT.ge_uen_dep_idempotencia.fec_modificacion
  is 'Fecha de modificacion del registro';
comment on column IT.ge_uen_dep_idempotencia.usu_modificacion
  is 'Usuario que modifico el registro';
