CREATE OR REPLACE PUBLIC SYNONYM CC_CHE_REC_AUTOMATICOS FOR it.CC_CHE_REC_AUTOMATICOS;
GRANT ALL ON CC_CHE_REC_AUTOMATICOS TO IT_TEMPORAL;

CREATE OR REPLACE PUBLIC SYNONYM CC_LOG_ERRORES FOR it.CC_LOG_ERRORES;
GRANT ALL ON CC_LOG_ERRORES TO IT_TEMPORAL;

CREATE OR REPLACE PUBLIC SYNONYM fuc_ver_inh_che_devueltos FOR it.fuc_ver_inh_che_devueltos;
GRANT ALL ON fuc_ver_inh_che_devueltos TO IT_TEMPORAL;

CREATE OR REPLACE PUBLIC SYNONYM prc_aut_rch_clearing FOR it.prc_aut_rch_clearing;
GRANT ALL ON prc_aut_rch_clearing TO IT_TEMPORAL;

CREATE OR REPLACE PUBLIC SYNONYM prc_ins_aut_rch_clearing FOR it.prc_ins_aut_rch_clearing;
GRANT ALL ON prc_ins_aut_rch_clearing TO IT_TEMPORAL;

CREATE OR REPLACE PUBLIC SYNONYM prc_ver_che_rec_aut FOR it.prc_ver_che_rec_aut;
GRANT ALL ON prc_ver_che_rec_aut TO IT_TEMPORAL;

create public synonym prc_inh_cli_che_devueltos for it.prc_inh_cli_che_devueltos;
grant ALL on it.prc_inh_cli_che_devueltos to it_temporal;