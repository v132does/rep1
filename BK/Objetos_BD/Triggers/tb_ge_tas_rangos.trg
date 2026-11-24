CREATE OR REPLACE TRIGGER IT.TB_GE_TAS_RANGOS
   BEFORE DELETE OR INSERT ON GE_TAS_RANGOS
   FOR EACH ROW

DECLARE
   v_tip_cta varchar2(2) := null;
   v_nro_cuenta  ge_tas_rangos.nro_cuenta%type  := null;
   v_cod_persona ge_tas_rangos.cod_persona%type := null;

/* Identificar tipo de cuenta, a la vista o corriente */
PROCEDURE lp_tip_cuenta IS
BEGIN
   SELECT DECODE(c.cod_modulo, 3, 'CV','CC')
     INTO v_tip_cta
     FROM ge_cta_clientes c
    WHERE c.relacion = 'P'
      AND c.cod_modulo in (3, 4)
      AND c.nro_cuenta = v_nro_cuenta;
EXCEPTION
   WHEN no_data_found THEN
      v_tip_cta := null;
   WHEN others THEN
      raise_application_error(-20001,'Error al intentar recuperar tipo de cuenta ' ||sqlerrm);
END;

BEGIN
   pag_gen.pr_ini_variables(null, null);
   IF inserting THEN
      v_nro_cuenta := :new.nro_cuenta;
      v_cod_persona:= :new.cod_persona;
   ELSIF deleting THEN
      v_nro_cuenta := :old.nro_cuenta;
      v_cod_persona:= :old.cod_persona;
      IF :old.cod_persona IS NOT NULL OR :old.nro_cuenta IS NOT NULL THEN
         BEGIN
            INSERT INTO ge_tas_per_eliminadas
               (cod_tasa, tipo, cod_persona, nro_cuenta, fec_vigencia, val_minimo, val_maximo,
                val_tasa, por_exoneracion, fec_vencimiento)
            VALUES
               (:old.cod_tasa, 'R', :old.cod_persona, :old.nro_cuenta, :old.fec_vigencia, NULL, :old.val_hasta,
                :old.val_tasa, :old.val_extension, :old.fec_vencimiento);
         END;
      END IF;
   END IF;
   IF v_nro_cuenta is not null THEN
      lp_tip_cuenta;
      pag_gen.g_nro_cuenta := v_nro_cuenta;
      pag_gen.g_tip_cuenta := v_tip_cta;
   ELSIF v_cod_persona is not null THEN
      pag_gen.g_cod_persona := v_cod_persona;
   END IF;
END;
/

