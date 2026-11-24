CREATE OR REPLACE PROCEDURE IT.PRA_CAP_CTA_PREVIO_CIERRE IS
  v_mto_interes number(22,2);
  v_fec_capitalizacion date;
Begin
  -- Objetivo: Sea llamado desde el proceso de cierre para identificar las cuentas que capitalizan
  v_fec_capitalizacion := pag_cal.FU_OBT_FEC_ACTUAL(3);
  PRA_CAP_CTA_VIS_PREVIO(null, 'S', v_fec_capitalizacion, v_mto_interes);
End;
/
