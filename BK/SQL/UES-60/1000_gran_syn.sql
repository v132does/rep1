create public synonym bw_bff_databag for it.bw_bff_databag;
grant select, insert, update, delete on it.bw_bff_databag to it_temporal;

CREATE public SYNONYM S_NRO_BW_BFF_DATABAG FOR IT.S_NRO_BW_BFF_DATABAG;
GRANT SELECT ON IT.S_NRO_BW_BFF_DATABAG TO IT_TEMPORAL;
