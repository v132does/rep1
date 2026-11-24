CREATE OR REPLACE TRIGGER IT.AA_GE_PAG_SUE_IPS_DET
  AFTER DELETE OR UPDATE
     ON GE_PAG_SUE_IPS_DET
    FOR EACH ROW
DECLARE
   /*
   || Archivo creado por el Generador de Triggers de Auditoría
   */
BEGIN
   IF updating THEN
      IF :old.ESTADO = 'P' AND :NEW.ESTADO = 'A' THEN
         --actualizamos el campo ge_pag_sue_ips.MTO_ACREDITADO con la sumatoria de los créditos realizados.
         UPDATE ge_pag_sue_ips c
            SET c.mto_acreditado = c.mto_acreditado + :new.IMPORTE
          WHERE C.Nro_Lote = :NEW.Nro_Lote;
      END IF;
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      pag_ips.pr_ins_bitacora(:new.nro_lote, :new.nro_orden, 'Error al actualizar el total acreditado.');
END;
/

