CREATE OR REPLACE TRIGGER IT.TA_GE_PAG_SUE_IPS_DET
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_PAG_SUE_IPS_DET
 FOR EACH ROW
DECLARE
BEGIN
    if updating then
      if :old.fe_vida = 'N'and :new.fe_vida = 'S' and :new.estado = 'P' then
        -- BSEVOCORE-426 para control de acreditaciones por actualizacion de Fe de Vida
        Insert into GE_PAG_SUE_IPS_REP_TMP( nro_lote, nro_orden, nro_comprobante, nro_doc_jubilado, estado)
        values ( :old.nro_lote, :old.nro_orden, :old.nro_comprobante, :old.nro_doc_jubilado, 'I');
      end if;
    end if;
END;
/

