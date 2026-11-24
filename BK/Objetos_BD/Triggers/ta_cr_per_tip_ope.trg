CREATE OR REPLACE TRIGGER IT.TA_CR_PER_TIP_OPE
 AFTER INSERT OR DELETE OR UPDATE
 ON "IT"."CR_PER_TIP_OPERACIONES"
 FOR EACH ROW

DECLARE
   v_resultado        VARCHAR2(250) := NULL;
   rp_cptoh           cr_per_tip_operaciones_his%ROWTYPE;
   v_usu_cumplimiento VARCHAR2(1) := fug_val_usu_roles(USER,'COD_ROL_PER_PERFIL');
   PROCEDURE lp_ins_cr_per_tip_ope_his(rp_cptoh cr_per_tip_operaciones_his%ROWTYPE) IS
   BEGIN
      INSERT INTO cr_per_tip_operaciones_his
         (cod_persona, cod_modulo, cod_modalidad, cod_moneda, fec_inicio, fec_vencimiento,
          mto_limite, novedad, usu_ver_perfil, fec_ver_perfil, est_ver_perfil)
      VALUES
         (rp_cptoh.cod_persona, rp_cptoh.cod_modulo, rp_cptoh.cod_modalidad, rp_cptoh.cod_moneda,
          rp_cptoh.fec_inicio, rp_cptoh.fec_vencimiento, rp_cptoh.mto_limite, rp_cptoh.novedad,
          rp_cptoh.usu_ver_perfil, rp_cptoh.fec_ver_perfil, rp_cptoh.est_ver_perfil);
   END;
BEGIN
   IF inserting THEN
      IF nvl(fug_obt_pardinamico('REQ_VER_PER_PERFIL'), 'N') = 'S' and user not in ('PERSONS','APITRANSAC') 
         AND NVL(v_usu_cumplimiento,'N') = 'N' then
            v_resultado := fuc_ver_per_persona(:new.cod_persona, 'M');
      elsif user in ('PERSONS','APITRANSAC') then
            begin   
              pre_ins_dat_adicionales(:new.cod_persona, 'A');
            exception
              when others then
              null;
            end;
      ELSIF NVL(v_usu_cumplimiento,'N') = 'S' THEN
        pre_ins_dat_adicionales(:new.cod_persona, 'A');
      END IF;

      rp_cptoh.cod_persona     := :new.cod_persona;
      rp_cptoh.cod_modulo      := :new.cod_modulo;
      rp_cptoh.cod_modalidad   := :new.cod_modalidad;
      rp_cptoh.cod_moneda      := :new.cod_moneda;
      rp_cptoh.fec_inicio      := :new.fec_inicio;
      rp_cptoh.fec_vencimiento := :new.fec_vencimiento;
      rp_cptoh.mto_limite      := :new.mto_limite;
      rp_cptoh.novedad         := 'I';
      rp_cptoh.usu_ver_perfil  := fue_per_dat_adicional(:new.cod_persona, 'USU_VER_PERFIL');
      rp_cptoh.fec_ver_perfil  := fue_per_dat_adicional(:new.cod_persona, 'FEC_VER_PERFIL');
      rp_cptoh.est_ver_perfil  := fue_per_dat_adicional(:new.cod_persona, 'EST_VER_PERFIL');
      lp_ins_cr_per_tip_ope_his(rp_cptoh);

   END IF;
   IF updating OR deleting THEN
      --- verifico si existe verificacion de personas
      IF updating THEN
         IF (:old.cod_modulo <> :new.cod_modulo OR :old.cod_modalidad <> :new.cod_modalidad OR
            :old.cod_moneda <> :new.cod_moneda OR :old.mto_limite <> :new.mto_limite OR
            :old.fec_inicio <> :new.fec_inicio OR :old.fec_vencimiento <> :new.fec_vencimiento) THEN
            IF nvl(fug_obt_pardinamico('REQ_VER_PER_PERFIL'), 'N') = 'S' and user not in ('PERSONS','APITRANSAC') 
               AND NVL(v_usu_cumplimiento,'N') = 'N' then
               v_resultado := fuc_ver_per_persona(:new.cod_persona, 'M');
            elsif user in ('PERSONS','APITRANSAC') then
              begin   
                 pre_ins_dat_adicionales(:new.cod_persona, 'A');
              exception
                when others then
                null;
              end;          
              v_resultado := fuc_ver_per_persona(:old.cod_persona, 'M');
            ELSIF NVL(v_usu_cumplimiento,'N') = 'S' THEN
              pre_ins_dat_adicionales(:new.cod_persona, 'A');
            END IF;
         END IF;
         rp_cptoh.cod_persona     := :old.cod_persona;
         rp_cptoh.cod_modulo      := :old.cod_modulo;
         rp_cptoh.cod_modalidad   := :old.cod_modalidad;
         rp_cptoh.cod_moneda      := :old.cod_moneda;
         rp_cptoh.fec_inicio      := :old.fec_inicio;
         rp_cptoh.fec_vencimiento := :old.fec_vencimiento;
         rp_cptoh.mto_limite      := :old.mto_limite;
         rp_cptoh.usu_ver_perfil  := fue_per_dat_adicional(:old.cod_persona, 'USU_VER_PERFIL');
         rp_cptoh.fec_ver_perfil  := fue_per_dat_adicional(:old.cod_persona, 'FEC_VER_PERFIL');
         rp_cptoh.est_ver_perfil  := fue_per_dat_adicional(:old.cod_persona, 'EST_VER_PERFIL');
         rp_cptoh.novedad         := 'M';
         lp_ins_cr_per_tip_ope_his(rp_cptoh);
      ELSIF deleting THEN
         rp_cptoh.cod_persona     := :old.cod_persona;
         rp_cptoh.cod_modulo      := :old.cod_modulo;
         rp_cptoh.cod_modalidad   := :old.cod_modalidad;
         rp_cptoh.cod_moneda      := :old.cod_moneda;
         rp_cptoh.fec_inicio      := :old.fec_inicio;
         rp_cptoh.fec_vencimiento := :old.fec_vencimiento;
         rp_cptoh.mto_limite      := :old.mto_limite;
         rp_cptoh.usu_ver_perfil  := fue_per_dat_adicional(:old.cod_persona, 'USU_VER_PERFIL');
         rp_cptoh.fec_ver_perfil  := fue_per_dat_adicional(:old.cod_persona, 'FEC_VER_PERFIL');
         rp_cptoh.est_ver_perfil  := fue_per_dat_adicional(:old.cod_persona, 'EST_VER_PERFIL');
         rp_cptoh.novedad         := 'E';
         lp_ins_cr_per_tip_ope_his(rp_cptoh);
      END IF;
   END IF;  
END;
/
