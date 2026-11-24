CREATE OR REPLACE PROCEDURE IT.PRA_CAP_CTA_VISTA_CIERRE IS
  v_mto_interes number(22,2);
  v_fec_capitalizacion date;
Begin
  -- Creado en fecha: 29/06/2004 por OPGM
  -- Objetivo: Sea llamado desde el proceso de cierre para capitalizar todas las cuentas...
  v_fec_capitalizacion := pag_cal.FU_OBT_FEC_ACTUAL(3);
  pra_cap_cta_vista(null, 'S', v_fec_capitalizacion, v_mto_interes);
End;
/

