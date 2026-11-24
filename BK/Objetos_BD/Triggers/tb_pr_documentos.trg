CREATE OR REPLACE TRIGGER IT.TB_PR_DOCUMENTOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON PR_DOCUMENTOS
 FOR EACH ROW
DECLARE
   v_ins_vinculos_nov VARCHAR2(1) DEFAULT 'N';
   rv_scvno           sb_cta_vinculos_nov%ROWTYPE;
BEGIN
   IF inserting THEN
      BEGIN
         SELECT cod_persona
           INTO rv_scvno.cod_persona
           FROM ba_personas
          WHERE cod_tip_documento = :new.cod_tip_documento
            AND nro_documento = :new.nro_documento;
      EXCEPTION
         WHEN no_data_found THEN
            rv_scvno.cod_persona := NULL;
         WHEN OTHERS THEN
            rv_scvno.cod_persona := NULL;
      END;
   ELSIF deleting THEN
      BEGIN
         SELECT cod_persona
           INTO rv_scvno.cod_persona
           FROM ba_personas
          WHERE cod_tip_documento = :old.cod_tip_documento
            AND nro_documento = :old.nro_documento;
      EXCEPTION
         WHEN no_data_found THEN
            rv_scvno.cod_persona := NULL;
         WHEN OTHERS THEN
            rv_scvno.cod_persona := NULL;
      END;
   END IF;
   IF deleting OR inserting THEN
      v_ins_vinculos_nov := 'S';
      IF inserting THEN
         IF fus_ver_crc_vinculos(rv_scvno.cod_persona, 'L', :new.nro_referencia) = 'S' THEN
            rv_scvno.evento     := 'V';
            rv_scvno.nro_cuenta := :new.nro_referencia;
         ELSE
            rv_scvno.evento := NULL;
         END IF;
      ELSIF deleting THEN
         IF fus_ver_crc_vinculos(rv_scvno.cod_persona, 'L', :old.nro_referencia) = 'S' THEN
            rv_scvno.evento     := 'D';
            rv_scvno.nro_cuenta := :old.nro_referencia;
         END IF;
      END IF;
   END IF;
   IF nvl(v_ins_vinculos_nov, 'N') = 'S' AND rv_scvno.evento IS NOT NULL THEN
      rv_scvno.fecha       := to_date(to_char(SYSDATE, 'DDMMYYYY') ||
                                      pag_gen.fu_obt_sig_segundo(to_char(SYSDATE, 'HH24:MI:SS')),
                                      'DDMMYYYY HH24:MI:SS');
      rv_scvno.hora        := pag_gen.fu_obt_sig_segundo(to_char(SYSDATE, 'HH24:MI:SS'));
      rv_scvno.cod_persona := rv_scvno.cod_persona;
      rv_scvno.relacion    := 'L';
      rv_scvno.cod_modulo  := 6;
      BEGIN
         INSERT INTO sb_cta_vinculos_nov
            (fecha, hora, nro_cuenta, cod_persona, evento, relacion, cod_modulo)
         VALUES
            (rv_scvno.fecha, rv_scvno.hora, rv_scvno.nro_cuenta, rv_scvno.cod_persona,
             rv_scvno.evento, rv_scvno.relacion, rv_scvno.cod_modulo);
      EXCEPTION
         WHEN dup_val_on_index THEN
            NULL;
      END;
   END IF;
END;
/

