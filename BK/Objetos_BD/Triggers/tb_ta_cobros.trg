CREATE OR REPLACE TRIGGER IT.TB_TA_COBROS
 BEFORE INSERT
 ON TA_COBROS
 FOR EACH ROW
BEGIN
  IF fug_obt_tip_implementacion not in (1,7) THEN
    IF inserting THEN
      par_cam.pr_act_pag_cobranza( :new.nro_cuenta,
                                   0,
                                   :new.fec_proceso,
                                   :new.dia_mora,
                                   nvl( :new.monto, 0 ) );
    END IF;
  END IF;
END;
/

