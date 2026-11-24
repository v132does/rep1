create or replace public synonym GE_UEN_DEP_IDEMPOTENCIA for IT.GE_UEN_DEP_IDEMPOTENCIA;
grant select, update, delete, insert on IT.GE_UEN_DEP_IDEMPOTENCIA to IT_TEMPORAL;

create or replace public synonym GE_UEN_EXT_IDEMPOTENCIA for IT.GE_UEN_EXT_IDEMPOTENCIA;
grant select, update, delete, insert on IT.GE_UEN_EXT_IDEMPOTENCIA to IT_TEMPORAL;
