CREATE OR REPLACE TRIGGER IT.TB_PR_GARANTIAS
 BEFORE UPDATE or DELETE
 ON PR_GARANTIAS
 FOR EACH ROW
DECLARE
   v_fec_actual ge_calendarios.fec_actual%TYPE := pag_cal.fu_obt_fec_actual(1);
       -- Creado por CB. DYDMR-7
BEGIN
   -- DYDMR-4068 Ago/2016
   If deleting and :old.estado = 'I' Then
      -- Cuenta Corriente
         delete from cc_cta_garantias WHERE nro_garantia=:old.nro_garantia;
      -- Tarjetas.
         delete from ta_cta_garantias WHERE nro_garantia=:old.nro_garantia;
      -- Préstamos.
         delete from pr_cta_garantias WHERE nro_garantia=:old.nro_garantia;
      -- Operaciones Vencidas.
         delete from ov_cta_garantias WHERE nro_garantia=:old.nro_garantia;
      -- Comercio Exterior.
         delete from cx_cta_garantias WHERE nro_garantia=:old.nro_garantia;
   End If;
   
   IF :new.estado != :old.estado THEN
      IF :old.estado = 'I' AND :new.estado = 'C' THEN
         :new.fec_confirmacion := v_fec_actual;
      END IF;
   END IF;
   IF :new.ind_uti_tercero = 'N' AND :old.ind_uti_tercero = 'S' THEN
      DECLARE
         v_nro_cta_vinculada pr_cta_garantias.nro_cuenta%TYPE;
      BEGIN
         SELECT MAX(cg.nro_cuenta)
           INTO v_nro_cta_vinculada
           FROM pr_cta_garantias cg, ge_cta_clientes cl
          WHERE cl.nro_cuenta = cg.nro_cuenta
            AND cl.relacion = 'P'
            AND :new.ind_uti_tercero = 'N'
            AND :new.cod_persona <> cl.cod_persona
            AND :new.cod_garantia = cg.cod_garantia
            AND :new.nro_garantia = cg.nro_garantia;
      
         IF v_nro_cta_vinculada IS NOT NULL THEN
            raise_application_error(-20090,
                                    'La cuenta ' || v_nro_cta_vinculada ||
                                     ' está vinculada a la garantía ' || :new.cod_garantia || ' - ' ||
                                     :new.nro_garantia || '.');
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20091, 'ERROR. Al verificar cuentas vinculadas ' || SQLERRM);
      END;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error en el trigger TB_PR_GARANTIAS. '||SQLERRM);
END;
/

