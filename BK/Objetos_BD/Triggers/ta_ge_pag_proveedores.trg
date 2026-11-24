CREATE OR REPLACE TRIGGER IT.TA_GE_PAG_PROVEEDORES
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_PAG_PROVEEDORES
 FOR EACH ROW
DECLARE
  r_gbts            ge_pag_bts_mensuales%rowtype;
  /*v_can_operaciones ge_pag_bts_mensuales.can_operaciones%type;
  v_mon_operaciones ge_pag_bts_mensuales.mon_operaciones%type;*/
  --
  PROCEDURE LP_INS_PAG_BTS_MENSUALES(rg_bts ge_pag_bts_mensuales%rowtype) IS
  BEGIN
    INSERT INTO GE_PAG_BTS_MENSUALES (NRO_ORDEN,
                                      NRO_DOC_BENEFICIARIO,
                                      ANO,
                                      MES,
                                      CAN_OPERACIONES,
                                      MON_OPERACIONES)
                              VALUES (rg_bts.nro_orden,
                                      rg_bts.nro_doc_beneficiario,
                                      rg_bts.ano,
                                      rg_bts.mes,
                                      rg_bts.can_operaciones,
                                      rg_bts.mon_operaciones
                                     );
  END;
  --
BEGIN
  --
  IF :new.cod_ente = 1091 THEN
    --
    IF inserting OR updating THEN
      r_gbts.nro_orden            := :new.nro_orden;
      r_gbts.nro_doc_beneficiario := :new.nro_doc_beneficiario;
      r_gbts.ano                  := to_number(to_char(:new.fec_ingreso,'yyyy'));
      r_gbts.mes                  := to_number(to_char(:new.fec_ingreso,'mm'));
      r_gbts.can_operaciones      := 1;
      r_gbts.mon_operaciones      := :new.monto;
    END IF;
    --
    IF inserting THEN
      LP_INS_PAG_BTS_MENSUALES(r_gbts);
    END IF;
    --
    IF updating and :new.estado in ('A') THEN
      BEGIN
        --
        DELETE GE_PAG_BTS_MENSUALES
         WHERE nro_orden = :new.nro_orden
           AND nro_doc_beneficiario = :new.nro_doc_beneficiario;
        /*UPDATE GE_PAG_BTS_MENSUALES
        SET can_operaciones = can_operaciones +1,
            mon_operaciones = mon_operaciones + :new.monto
        WHERE nro_doc_beneficiario = :new.nro_doc_beneficiario;*/
        --
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          LP_INS_PAG_BTS_MENSUALES(r_gbts);
        WHEN OTHERS THEN
          RAISE_APPLICATION_ERROR(-20000,SQLERRM);
      END;
    END IF;
    --
  END IF;
  --
END;
/

