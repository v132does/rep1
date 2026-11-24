CREATE OR REPLACE TRIGGER IT.TA_CR_INF_FONDOS
 AFTER DELETE OR INSERT OR UPDATE
 ON "IT"."CR_INF_FONDOS"
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
      IF (:old.fon_transferencias <> :new.fon_transferencias OR
         :old.fon_salario <> :new.fon_salario OR :old.fon_prestamos <> :new.fon_prestamos OR
         :old.fon_vta_activos <> :new.fon_vta_activos OR
         :old.fon_ren_financieras <> :new.fon_ren_financieras OR
         :old.fon_ahorro <> :new.fon_ahorro OR :old.fon_herencia <> :new.fon_herencia OR
         :old.fon_otros <> :new.fon_otros OR :old.pro_ingresos <> :new.pro_ingresos OR
         :old.pro_ahorros <> :new.pro_ahorros OR :old.pro_ven_alq <> :new.pro_ven_alq OR
         :old.pro_gas_operativos <> :new.pro_gas_operativos OR :old.pro_otros <> :new.pro_otros) AND
         NOT (:old.pep_observacion <> :new.pep_observacion) or :new.pep <> 'S'
           THEN
         IF nvl(fug_obt_pardinamico('REQ_VER_PER_PERFIL'), 'N') = 'S' THEN
           v_resultado := fuc_ver_per_persona(:old.cod_persona,'M');
         END IF;
        ELSE
         IF  (:old.pep_observacion <> :new.pep_observacion or :old.pep <> :new.pep ) THEN
             IF nvl(fug_obt_pardinamico('REQ_VER_PER_PERFIL'), 'N') = 'S' THEN
               -- Le indico que es una persona PEPs para esos casos debe tomar otro circuito.
              v_resultado := fuc_ver_per_persona(:old.cod_persona,'P');
             END IF;
         END IF;
      END IF;
   END IF;

END;
/

