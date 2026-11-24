CREATE OR REPLACE PROCEDURE IT.pra_pro_aho_programado IS
  v_mto_interes        NUMBER(22,2);
  v_msj_error          VARCHAR2(2000);
  v_fec_capitalizacion DATE;
BEGIN

  -- Procedimiento llamado del cierre para provision de ahorros programados
  BEGIN
    v_fec_capitalizacion := pag_cal.FU_OBT_FEC_ACTUAL(3);
    paa_pro.pr_pro_aho_programado(NULL, 'S', v_fec_capitalizacion, v_mto_interes);
  EXCEPTION
    WHEN OTHERS THEN
      v_msj_error := SQLERRM;
      IF v_msj_error LIKE '%No encontre registros en AH_CTA_PLAZOS%' THEN
        NULL; -- Seguir en caso que no existan Ahorros Programados
      ELSE
        raise_application_error(-20000,'Error en PRA_CAP_AHO_PROGRAMADO'||SQLERRM);
      END IF;
  END;
END;
/
