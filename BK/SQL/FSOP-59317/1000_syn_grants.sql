CREATE PUBLIC SYNONYM cb_fac_masivas_his FOR it.cb_fac_masivas_his;
CREATE PUBLIC SYNONYM cb_fac_masivas_tmp FOR it.cb_fac_masivas_tmp;
CREATE PUBLIC SYNONYM prb_obt_pun_expedicion FOR it.prb_obt_pun_expedicion;
CREATE PUBLIC SYNONYM prb_fac_masivas FOR it.prb_fac_masivas;

GRANT ALL ON it.cb_fac_masivas_his TO IT_TEMPORAL;
GRANT ALL ON it.cb_fac_masivas_tmp TO IT_TEMPORAL;
GRANT EXECUTE ON it.prb_obt_pun_expedicion TO IT_TEMPORAL;
GRANT EXECUTE ON it.prb_fac_masivas TO IT_TEMPORAL;

