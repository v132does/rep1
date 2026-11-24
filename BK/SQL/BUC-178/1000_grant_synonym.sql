CREATE OR REPLACE PUBLIC SYNONYM cc_pro_tmp_vencidos FOR it.cc_pro_tmp_vencidos;
CREATE OR REPLACE PUBLIC SYNONYM prg_blo_ven_sobregiros FOR it.prg_blo_ven_sobregiros;

grant select, insert, update, delete on IT.CC_PRO_TMP_VENCIDOS to IT_TEMPORAL;
grant execute on it.prg_blo_ven_sobregiros to it_temporal;
