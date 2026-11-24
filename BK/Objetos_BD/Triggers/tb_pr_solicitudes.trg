CREATE OR REPLACE TRIGGER IT.TB_PR_SOLICITUDES
 BEFORE DELETE OR INSERT OR UPDATE
 ON "IT"."PR_SOLICITUDES"
 FOR EACH ROW
DECLARE

   CURSOR garantias IS
      SELECT cod_garantia, mto_aplicado
        FROM pr_sol_garantias
       WHERE nro_solicitud = :new.nro_solicitud;

   v_mto_a_aplicar       pr_lineas.mto_aplicado%TYPE;
   v_mto_aplicado        pr_lineas.mto_aplicado%TYPE;
   v_nro_cci             ge_cuentas.nro_cuenta%TYPE;
   v_cod_mon_cta_credito VARCHAR2(3);
   /* Validar datos ingresados en la solicitud. */
   PROCEDURE lp_val_dat_solicitud;
   v_nro_solicitud ge_solicitudes.nro_solicitud%TYPE;
   v_cot_mon_ori   ge_cotizaciones.val_conversion%TYPE;
   v_cot_mon_des   ge_cotizaciones.val_conversion%TYPE;
   v_cod_mon_linea pr_lineas.cod_moneda%TYPE;

   /* Validar datos ingresados en la solicitud. */
   PROCEDURE lp_val_dat_solicitud 
   IS
   BEGIN
      IF fug_obt_tip_implementacion = 3 THEN
         /* 1-) La modalidad 61 Prestamos c/ Pagares debe permitir grabar solo
             operaciones con un vencimiento de capital (Plazo Fijo)
         2-) La modalidad 65 Prestamos Amortizables debe permitir grabar solo
             operaciones mas de (1) vencimiento de capital.(Amortizables) */
         IF :new.cod_modalidad = 61 AND :new.tipo <> 'P' THEN
            raise_application_error(-20000, 'Operaciones de Prestamos c/Pagare solo pueden ser a Plazo Fijo');
         END IF;
         IF :new.cod_modalidad = 65 AND :new.tipo <> 'A' THEN
            raise_application_error(-20000, 'Operaciones de Prestamos Amortizables deben ser de mas de un pago');
         END IF;
      END IF;
   END;

BEGIN
   IF updating THEN
      --si está vinculado a cci no permitir modificar
      IF :new.monto <> :old.monto OR :new.cod_modalidad <> :old.cod_modalidad OR
         :new.cod_moneda <> :old.cod_moneda OR :new.tip_monto <> :old.tip_monto OR :new.cod_persona <> :old.cod_persona THEN
         v_nro_cci := fux_obt_cci_prestamo(:old.nro_solicitud);
         IF v_nro_cci IS NOT NULL THEN
            raise_application_error(-20000, 'Solicitud vinculada a C.C.I.'|| v_nro_cci ||'.No puede modificar Monto, Tipo de Monto, Moneda ni Modalidad.');
         END IF;
      END IF;
      IF :new.estado <> :old.estado THEN
         IF :new.estado = 'D' THEN
            --- Actualizar solicitudes a pendiente de desembolso
            BEGIN
               SELECT nro_solicitud
                 INTO v_nro_solicitud
                 FROM ge_solicitudes
                WHERE nro_sol_prestamo = :new.nro_solicitud;
               UPDATE ge_solicitudes 
            SET cod_estado = 'PDE' 
    WHERE nro_solicitud = v_nro_solicitud;
            EXCEPTION
               WHEN no_data_found THEN
                  NULL;
               WHEN OTHERS THEN
                  raise_application_error(-20000, 'Act. Solicitud ' || SQLERRM);
            END;
         ELSIF :new.estado = 'L' THEN
            --verificar que las garantías estén confirmadas
            IF NOT fup_ver_gar_confirm(:new.nro_solicitud) AND fug_obt_tip_implementacion <> 1 THEN
               raise_application_error(-20000, 'No puede Aprobar la Solicitud, posee Garantías no confirmadas.');
            END IF;
         ELSIF :new.estado IN ('N', 'R') THEN
            v_nro_cci := fux_obt_cci_prestamo(:new.nro_solicitud);
            IF v_nro_cci IS NOT NULL and :new.estado = 'N' THEN -- DYDMR-3288
               raise_application_error(-20000, 'No se puede Cancelar Solicitud vinculada a CCI ' || v_nro_cci); -- DYDMR-3288
            END IF;
            IF :old.estado IN ('A') THEN
               raise_application_error(-20000, 'No se puede Rechazar Solicitud ya desembolsada.');
            ELSIF :old.estado IN ('L') then 
              -- Si tiene pre-aprobado y PRE_RECHAZA_PREAPROBADO es 'S' , si permite rechazar
              -- Si no tiene pre-aprobado y PRE_RECHAZA_PREAPROBADO es 'S', no permite rechazar
              -- Si PRE_RECHAZA_PREAPROBADO es 'N', si permite rechazar
                 IF fug_obt_pardinamico('PRE_RECHAZA_PREAPROBADO') = 'N' and fug_val_can_pre_aprobado(:old.cod_persona,:old.cod_modulo,:old.cod_modalidad,:old.Nro_Solicitud) = 'S' THEN --Solo se emite el mensaje si no es pre-aprobado
                         raise_application_error(-20000, 'No se puede Rechazar Solicitud Pendiente de desembolso.');
                 END IF;
            END IF;        
            IF :old.nro_linea IS NOT NULL THEN
               -- Actualizar linea de crédito y mto aplicado de la linea
               pap_gar.pr_act_lin_aplicado(:old.nro_linea, (nvl(:old.mto_lin_aplicado, 0) * -1));
            END IF;
         END IF;
      END IF;
     -- Cambio solicitado por MIS, la oficina a guardar debe ser la oficina del oficial de la cuenta - RABP 08/10/2013 
      if :new.cod_oficina != :old.cod_oficina and :new.cod_oficina != FUG_OBT_OFI_OFICIAL(:new.Cod_Persona) then
         raise_application_error(-20000,'La Oficina de la cuenta debe llevar la oficina del Oficial: '||fue_obt_des_oficina(FUG_OBT_OFI_OFICIAL(:new.Cod_Persona))||' ('||FUG_OBT_OFI_OFICIAL(:new.Cod_Persona)||')');
      End If;
   END IF;

   IF inserting OR updating THEN
      --- Validar datos generales de la solicitud
      lp_val_dat_solicitud;
   END IF;
   IF deleting THEN
      --verificar si está vinculada a una cci
      v_nro_cci := fux_obt_cci_prestamo(:new.nro_solicitud);
      IF v_nro_cci IS NOT NULL THEN
         raise_application_error(-20000, 'No se puede Eliminar Solicitud vinculada a CCI ' || v_nro_cci);
      END IF;
   
      --- Eliminar historico de estados
      DELETE pr_sol_gestiones 
       WHERE nro_solicitud = :old.nro_solicitud;
   END IF;

   --- Actualizar linea de crédito
   IF inserting AND :new.nro_linea IS NOT NULL AND :new.nro_solicitud > 0 THEN
      -- Recuperar moneda de la linea
      v_cod_mon_linea := pap_gar.fu_obt_mon_linea(:new.nro_linea);
      -- Convertir el monto a moneda de la linea en la cotizacion actual
      pag_gen.pr_con_mon_a_moneda(:new.cod_moneda, v_cod_mon_linea, :new.tot_prestamo,
                                  v_mto_a_aplicar, v_cot_mon_ori, v_cot_mon_des);
      :new.mto_lin_aplicado := :new.tot_prestamo;
   
      -- Actualizar linea de crédito y mto aplicado del crédito en moneda de la linea
      pap_gar.pr_act_lin_aplicado(:new.nro_linea, v_mto_a_aplicar);
   ELSIF updating AND :new.nro_solicitud > 0 THEN
      --- Si no estaba asociado a una linea y se asocia debe tener mismo trato que insert
      IF :new.nro_linea IS NOT NULL AND :old.nro_linea IS NULL AND :new.estado != 'A' THEN
         -- Recuperar moneda de la linea
         v_cod_mon_linea := pap_gar.fu_obt_mon_linea(:new.nro_linea);
         -- Convertir el monto a moneda de la linea en la cotizacion actual
         pag_gen.pr_con_mon_a_moneda(:new.cod_moneda, v_cod_mon_linea, :new.tot_prestamo,
                                     v_mto_a_aplicar, v_cot_mon_ori, v_cot_mon_des);
         :new.mto_lin_aplicado := :new.tot_prestamo;
      
         -- Actualizar linea de crédito y mto aplicado del crédito en moneda de la linea
         pap_gar.pr_act_lin_aplicado(:new.nro_linea, v_mto_a_aplicar);
      END IF;
      --- Si se desasocia la linea
      IF :new.nro_linea IS NULL AND :old.nro_linea IS NOT NULL AND :new.estado != 'A' THEN
         v_cod_mon_linea := pap_gar.fu_obt_mon_linea(:old.nro_linea);
         -- Convertir el monto a moneda de la linea en la cotizacion actual
         pag_gen.pr_con_mon_a_moneda(:new.cod_moneda, v_cod_mon_linea, :old.mto_lin_aplicado,
                                     v_mto_aplicado, v_cot_mon_ori, v_cot_mon_des);
         pap_gar.pr_act_lin_aplicado(:old.nro_linea, (nvl(v_mto_aplicado, 0) * -1));
         FOR gar IN garantias LOOP
            pag_gen.pr_con_mon_a_moneda(:new.cod_moneda, v_cod_mon_linea, nvl(gar.mto_aplicado, 0),
                                        v_mto_aplicado, v_cot_mon_ori, v_cot_mon_des);
            --Actualizar el mto aplicado de tipos de garantia por limite
            pap_gar.pr_act_tip_limite(:old.nro_linea, gar.cod_garantia, nvl(v_mto_aplicado, 0) * -1);
            --Actualizar el mto aplicado de garantias por Modalidad
            pap_gar.pr_act_mad_limite(:old.nro_linea, gar.cod_garantia, nvl(v_mto_aplicado, 0) * -1,
                                      6, :new.cod_modalidad);
         END LOOP;
      
         IF :new.nro_linea IS NULL THEN
            :new.mto_lin_aplicado := NULL;
         END IF;
      END IF;
      IF :new.nro_solicitud = :old.nro_solicitud THEN
         IF (:new.tot_prestamo <> :old.tot_prestamo AND :new.nro_linea IS NOT NULL) OR
            (:new.nro_linea IS NOT NULL AND :old.nro_linea IS NOT NULL) THEN
            --If :new.nro_linea = :old.nro_linea then
            IF :old.nro_linea IS NOT NULL THEN
               -- Recuperar moneda de la linea
               v_cod_mon_linea := pap_gar.fu_obt_mon_linea(:old.nro_linea);
               pag_gen.pr_con_mon_a_moneda(:new.cod_moneda, v_cod_mon_linea, :old.mto_lin_aplicado,
                                           v_mto_aplicado, v_cot_mon_ori, v_cot_mon_des);
               --desasocia la linea
               pap_gar.pr_act_lin_aplicado(:old.nro_linea, (nvl(v_mto_aplicado, 0) * -1));
            END IF;
            -- Recuperar moneda de la linea
            v_cod_mon_linea := pap_gar.fu_obt_mon_linea(:new.nro_linea);
            -- Convertir el monto a moneda de la linea en la cotizacion actual
            pag_gen.pr_con_mon_a_moneda(:new.cod_moneda, v_cod_mon_linea, :new.tot_prestamo,
                                        v_mto_a_aplicar, v_cot_mon_ori, v_cot_mon_des);
            :new.mto_lin_aplicado := :new.tot_prestamo;
            -- Actualizar linea de crédito y mto aplicado del crédito en moneda de la linea
            pap_gar.pr_act_lin_aplicado(:new.nro_linea, v_mto_a_aplicar);
         END IF;
      END IF;
   ELSIF deleting THEN
      ---- Actualizar linea de crédito
      IF :old.nro_linea IS NOT NULL THEN
         -- Recuperar moneda de la linea
         v_cod_mon_linea := pap_gar.fu_obt_mon_linea(:old.nro_linea);
         pag_gen.pr_con_mon_a_moneda(:new.cod_moneda, v_cod_mon_linea, :old.mto_lin_aplicado,
                                     v_mto_aplicado, v_cot_mon_ori, v_cot_mon_des);
         pap_gar.pr_act_lin_aplicado(:old.nro_linea, (nvl(v_mto_aplicado, 0) * -1));
      END IF;
   END IF;

   IF inserting OR updating THEN
      --- Validar datos generales de la solicitud
      lp_val_dat_solicitud;
   END IF;
   IF deleting THEN
      --- Eliminar historico de estados
      DELETE pr_sol_gestiones 
       WHERE nro_solicitud = :old.nro_solicitud;
   END IF;

   IF inserting OR updating THEN
      --- Validar datos la moneda Solicitud contra la moneda de la cuenta credito o debito
      IF nvl(:new.nro_cta_debito, 'X') <> 'X' THEN
         v_cod_mon_cta_credito := fug_obt_mon_cta(:new.nro_cta_debito);
         IF :new.cod_moneda <> v_cod_mon_cta_credito THEN
            raise_application_error(-20000, 'Error: Moneda en la Cta.Relacionada Diferente a Moneda de la Solicitud. Verifique...');
         END IF;
      END IF;
      IF :new.tip_renovacion is null AND nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GPPROFIN' then
        IF :old.estado not in ('A','N','R') then --Agregar validación por estado de la solicitud, excluir desembolsado, Cancelado y rechazado.
         raise_application_error(-20000, 'Error: Valor inválido para el Campo Tipo Renovación.. Verifique...'); 
        END IF;
      END IF;
   END IF;
   /*comentado para pruebas 12/07/2007
   if inserting or updating then
      --- Modificación agregada al programa de tasas variables
      --- Valida si la modalidad está asociada a un origen de fondos
      if ( FUP_OBT_ORI_FON_MODALIDAD(:new.COD_MODALIDAD) = :new.COD_ORI_FONDO ) 
        or ( NVL(FUP_OBT_ORI_FON_MODALIDAD(:new.COD_MODALIDAD),0) = 0 )then
         null;
      else
         raise_application_error(-20000,'Error: La Modalidad esta asociada un Origen de Fondos Diferente. Verifique...');
      end if;
   end if;
   */
   --TASVAR: 22/11/2018 Si se cancela la solicitud se borra de Tasa Variable
   if  updating THEN
      if :new.estado='C' then
         DELETE FROM PR_TAS_VARIABLES A WHERE A.NRO_SOLICITUD= :NEW.NRO_SOLICITUD;
         DELETE FROM PR_TAS_VARIABLES_DET A WHERE A.NRO_SOLICITUD= :NEW.NRO_SOLICITUD;
      END IF;
   end if;
   IF deleting THEN
         DELETE FROM PR_TAS_VARIABLES A WHERE A.NRO_SOLICITUD= :NEW.NRO_SOLICITUD;
         DELETE FROM PR_TAS_VARIABLES_DET A WHERE A.NRO_SOLICITUD= :NEW.NRO_SOLICITUD;
   END IF;
END;
/

