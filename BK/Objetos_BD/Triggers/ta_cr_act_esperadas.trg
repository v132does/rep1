CREATE OR REPLACE TRIGGER IT.TA_CR_ACT_ESPERADAS
 AFTER DELETE OR INSERT OR UPDATE
 ON "IT"."CR_ACT_ESPERADAS"
 FOR EACH ROW
DECLARE
   v_resultado VARCHAR2(250);
BEGIN
   IF inserting THEN
      IF nvl(fug_obt_pardinamico('REQ_VER_PER_PERFIL'), 'N') = 'S' THEN
         v_resultado := fuc_ver_per_persona(:new.cod_persona,'M');
      END IF;
   ELSIF updating THEN
      --- verifico si existe verificacion de personas
      IF (:old.cod_moneda <> :new.cod_moneda OR :old.can_tra_debito <> :new.can_tra_debito OR
         :old.can_tra_credito <> :new.can_tra_credito OR
         :old.mto_pro_debito <> :new.mto_pro_debito OR
         :old.mto_pro_credito <> :new.mto_pro_credito) THEN
         IF nvl(fug_obt_pardinamico('REQ_VER_PER_PERFIL'), 'N') = 'S' THEN
            v_resultado := fuc_ver_per_persona(:old.cod_persona, 'M');
         END IF;
      END IF;
   END IF;
END;
/

