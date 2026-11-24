CREATE OR REPLACE TRIGGER IT.TB_PR_GAR_WARRANTS
  BEFORE INSERT OR UPDATE ON PR_GAR_WARRANTS
  FOR EACH ROW
DECLARE
   v_fec_inicio      pr_garantias.fec_inicio%TYPE;
   v_fec_vencimiento pr_garantias.fec_vencimiento%TYPE;
BEGIN
   IF :new.cod_ent_seguro IS NOT NULL THEN
      IF :new.fec_ini_seguro IS NULL THEN
         raise_application_error(-20000, 'La Fecha de Inicio de Seguro debe cargarse.');
      END IF;
      IF :new.fec_vto_seguro IS NULL THEN
         raise_application_error(-20000, 'La Fecha Vencimiento de Seguro debe cargarse.');
      END IF;
      IF :new.nro_poliza IS NULL THEN
         raise_application_error(-20000, 'El Nro. de Póliza debe cargarse.');
      END IF;
   ELSE
      IF :new.fec_ini_seguro IS NOT NULL THEN
         raise_application_error(-20000,
                                 'La Fecha Inicio de Seguro no puede cargarse sin Aseguradora.');
      END IF;
      IF :new.fec_vto_seguro IS NOT NULL THEN
         raise_application_error(-20000,
                                 'La Fecha Vencimiento de Seguro no puede cargarse sin Aseguradora.');
      END IF;
      IF :new.nro_poliza IS NOT NULL THEN
         raise_application_error(-20000, 'El Nro. de Póliza no puede cargarse sin Aseguradora.');
      END IF;
   END IF;
   IF :new.fec_ini_seguro > :new.fec_vto_seguro THEN
      raise_application_error(-20000,
                              'La Fecha de inicio de la Seguro no puede ser mayor a la Fecha Final de Seguro');
   END IF;
   BEGIN
      SELECT g.fec_inicio, g.fec_vencimiento
        INTO v_fec_inicio, v_fec_vencimiento
        FROM pr_garantias g
       WHERE g.nro_garantia = :new.nro_garantia;
   EXCEPTION
      WHEN OTHERS THEN
         v_fec_inicio      := NULL;
         v_fec_vencimiento := NULL;
   END;
   IF v_fec_inicio > v_fec_vencimiento THEN
      raise_application_error(-20000,
                              'La Fecha de Valor de Garantía no puede ser mayor a la Fecha de Vencimiento de Garantía.');
   END IF;
END;
/

