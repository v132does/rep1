ALTER TABLE IT.ta_tarjetas ADD (
id RAW(16),
id_virtual as (CASE  WHEN "ID" IS NULL THEN NULL ELSE LOWER(SUBSTR(RAWTOHEX("ID"),1,8)||'-'||SUBSTR(RAWTOHEX("ID"),9,4)||'-'||SUBSTR(RAWTOHEX("ID"),13,4)||'-'||SUBSTR(RAWTOHEX("ID"),17,4)||'-'||SUBSTR(RAWTOHEX("ID"),21,12)) END)
);
comment on column IT.TA_TARJETAS.id
  is 'Identificador de la tarjeta en raw';
comment on column IT.TA_TARJETAS.id_virtual
  is 'Identificador virtual de la tarjeta en formato UUID V7';

create index IT.IN_TTARJ_ID on IT.TA_TARJETAS (ID) ONLINE;
create index IT.IN_TTARJ_ID_VIRTUAL on IT.TA_TARJETAS (ID_VIRTUAL) ONLINE;

