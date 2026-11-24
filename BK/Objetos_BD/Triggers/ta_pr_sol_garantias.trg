CREATE OR REPLACE TRIGGER IT.TA_PR_SOL_GARANTIAS
 AFTER DELETE OR INSERT OR UPDATE
 ON PR_SOL_GARANTIAS
 FOR EACH ROW
DECLARE

   -- Para recuperar datos de la garantía y la propuesta.
   CURSOR garantia IS
      SELECT pr.cod_modulo         cod_mod_prestamo,
             pr.cod_modalidad      cod_mad_prestamo,
             pr.cod_moneda         cod_mon_prestamo,
             pr.cod_oficina        cod_ofi_prestamo,
             ct.cod_modulo         cod_mod_cuenta,
             ct.cod_modalidad      cod_mad_cuenta,
             ct.cod_oficina        cod_ofi_cuenta,
             ct.cod_moneda         cod_mon_cuenta,
             ca.monto              monto,
             ca.nro_cta_referencia nro_cta_referencia
        FROM pr_gar_cash ca, pr_solicitudes pr, ge_cuentas ct
       WHERE ca.nro_garantia = :new.nro_garantia
         AND pr.nro_solicitud = :new.nro_solicitud
         AND ca.nro_cta_referencia = ct.nro_cuenta(+);

   CURSOR garan IS
      SELECT pr.cod_modulo         cod_mod_prestamo,
             pr.cod_modalidad      cod_mad_prestamo,
             pr.cod_moneda         cod_mon_prestamo,
             pr.cod_oficina        cod_ofi_prestamo,
             ct.cod_modulo         cod_mod_cuenta,
             ct.cod_modalidad      cod_mad_cuenta,
             ct.cod_oficina        cod_ofi_cuenta,
             ct.cod_moneda         cod_mon_cuenta,
             ca.monto              monto,
             ca.nro_cta_referencia nro_cta_referencia
        FROM pr_gar_cash ca, pr_solicitudes pr, ge_cuentas ct
       WHERE ca.nro_garantia = :old.nro_garantia
         AND pr.nro_solicitud = :old.nro_solicitud
         AND ca.nro_cta_referencia = ct.nro_cuenta(+);

   v_nro_linea      pr_lineas.nro_linea%TYPE;
   v_cod_mon_linea  pr_lineas.cod_moneda%TYPE;
   v_cod_mod_sol    pr_solicitudes.cod_modalidad%TYPE;
   v_cod_mon_sol    pr_solicitudes.cod_moneda%TYPE;
   v_cod_mon_gar    pr_garantias.cod_moneda%TYPE;
   v_mto_a_aplicar  pr_lineas.mto_aplicado%TYPE;
   v_mto_aplicado   pr_lineas.mto_aplicado%TYPE;
   v_mto_a_apli_gar pr_garantias.mto_aplicado%TYPE;
   v_cot_mon_ori    ge_cotizaciones.val_conversion%TYPE;
   v_cot_mon_des    ge_cotizaciones.val_conversion%TYPE;
   v_mto_bloqueo    ge_bloqueos.monto%TYPE;
   v_mto_bloqueado  ge_bloqueos.monto%TYPE;

   v_nvo_estado     ge_cuentas.estado%TYPE;
   v_sal_disponible ge_cuentas.sal_contable%TYPE;
   v_procesa        VARCHAR2(01);
   v_gar_saldo      pr_garantias.mto_aplicado%TYPE;
   v_aplicado       pr_garantias.mto_aplicado%TYPE;
   v_tipo           pr_garantias.tipo%TYPE;
   v_estado         pr_garantias.estado%TYPE;
   v_nro_solicitud  pr_solicitudes.nro_solicitud%TYPE;
   v_cod_persona    pr_solicitudes.cod_persona%TYPE;

   /* Verificar si es una cuenta de gestión financiera. */
   FUNCTION lf_ver_cta_gestion(p_nro_garantia IN pr_gar_cash.nro_garantia%TYPE) RETURN NUMBER;
   /* Insertar registro de bloqueos. */
   PROCEDURE lp_ins_ge_bloqueos(rp_gbloq IN ge_bloqueos%ROWTYPE);
   v_diferencia         pr_garantias.mto_aplicado%TYPE;
   v_cod_modalidad      ge_cuentas.cod_modalidad%TYPE;
   v_fec_valor          ge_movimientos.fec_valor%TYPE;
   v_hora               ge_movimientos.hora%TYPE;
   r_gbloq              ge_bloqueos%ROWTYPE;
   r_gmovi              ge_movimientos%ROWTYPE;
   v_cantidad           NUMBER(05);
   v_cod_modulo         pr_cta_prestamos.cod_modulo%TYPE;
   v_cod_mad_prestamo   pr_cta_prestamos.cod_modalidad%TYPE;
   v_cod_moneda         pr_cta_prestamos.cod_moneda%TYPE;
   v_cod_oficina        pr_cta_prestamos.cod_oficina%TYPE;
   v_cod_mod_cta        ge_cuentas.cod_modulo%TYPE;
   v_cod_mad_cta        ge_cuentas.cod_modalidad%TYPE;
   v_cod_mon_cta        ge_cuentas.cod_moneda%TYPE;
   v_cod_ofi_cta        ge_cuentas.cod_oficina%TYPE;
   v_nro_cta_referencia ge_cuentas.nro_cuenta%TYPE;
   v_monto              ge_cuentas.sal_contable%TYPE;
   v_nro_secuencia      ge_movimientos.nro_secuencia%TYPE := 0;

   /*Obtener el monto bloqueoado de la cuenta*/
   FUNCTION lf_obt_mto_bloqueo
   (
      p_nro_solicitud IN ge_bloqueos.nro_documento%TYPE,
      p_nro_cuenta    IN ge_bloqueos.nro_cuenta%TYPE
   ) RETURN NUMBER;

   /* Verificar si es una cuenta de gestión financiera. */
   FUNCTION lf_ver_cta_gestion(p_nro_garantia IN pr_gar_cash.nro_garantia%TYPE) RETURN NUMBER IS
      v_cod_modalidad ge_cuentas.cod_modalidad%TYPE;
   BEGIN
      SELECT cod_modalidad
        INTO v_cod_modalidad
        FROM pr_cas_tipos prc, pr_gar_cash prg
       WHERE prg.nro_garantia = p_nro_garantia
         AND prg.cod_cas_tipo = prc.cod_cas_tipo
         AND rownum = 1;
      RETURN v_cod_modalidad;
   EXCEPTION
      WHEN no_data_found THEN
         raise_application_error(-20000, 'Tipo de Garantía ' || p_nro_garantia || ' no registrado');
   END;
   /* Insertar registro de bloqueos. */
   PROCEDURE lp_ins_ge_bloqueos(rp_gbloq IN ge_bloqueos%ROWTYPE) IS
   BEGIN
      INSERT INTO ge_bloqueos
         (nro_cuenta, fec_inicio, nro_documento, cod_causa, monto, hor_inicio, fec_fin, tipo,
          observacion, tip_bloqueo)
      VALUES
         (rp_gbloq.nro_cuenta, rp_gbloq.fec_inicio, rp_gbloq.nro_documento, rp_gbloq.cod_causa,
          rp_gbloq.monto, rp_gbloq.hor_inicio, rp_gbloq.fec_fin, rp_gbloq.tipo, rp_gbloq.observacion,
          'A');
   END;

   /*Obtener el monto bloqueoado de la cuenta*/
   FUNCTION lf_obt_mto_bloqueo
   (
      p_nro_solicitud IN ge_bloqueos.nro_documento%TYPE,
      p_nro_cuenta    IN ge_bloqueos.nro_cuenta %TYPE
   ) RETURN NUMBER IS
      v_monto ge_bloqueos.monto%TYPE;
   BEGIN
      SELECT monto
        INTO v_monto
        FROM ge_bloqueos
       WHERE nro_cuenta = p_nro_cuenta
         AND nro_documento = p_nro_solicitud;
   
      RETURN v_monto;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN NULL;
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Obtener el monto bloqueado ' || SQLERRM);
   END;

   /*Verificar si el bloqueo tipo A ya existe,
   significa q el cash está atado a otro préstamo*/
   FUNCTION lf_ver_bloqueo(p_nro_cuenta IN ge_bloqueos.nro_cuenta%TYPE) RETURN BOOLEAN IS
      v_existe NUMBER;
   BEGIN
      SELECT COUNT(*)
        INTO v_existe
        FROM ge_bloqueos
       WHERE nro_cuenta = p_nro_cuenta
         AND tip_bloqueo = 'A';
      IF v_existe > 0 THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Recup. bloqueo ' || SQLERRM);
   END;
   --Verifica si existe el Vínculo de Tipo Co-Deudor de la Persona
   FUNCTION lf_ver_vinculo
   (
      p_cod_persona     IN ba_vinculos.cod_persona%TYPE,
      p_cod_per_vinculo IN ba_vinculos.cod_per_vinculo%TYPE
   ) RETURN BOOLEAN IS
      v_exi_vinculo NUMBER := 0;
   BEGIN
      SELECT COUNT(*)
        INTO v_exi_vinculo
        FROM ba_vinculos
       WHERE cod_persona = p_cod_persona
         AND cod_per_vinculo = p_cod_per_vinculo
         AND tipo = 'CD';
      IF v_exi_vinculo > 0 THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Recup. Vínculo ' || SQLERRM);
   END;

   /*principal*/
BEGIN
   IF inserting OR updating THEN
      v_nro_solicitud := :new.nro_solicitud;
   ELSE
      v_nro_solicitud := :old.nro_solicitud;
   END IF;

   BEGIN
      SELECT nro_linea, cod_moneda, cod_modalidad, cod_persona
        INTO v_nro_linea, v_cod_mon_sol, v_cod_mod_sol, v_cod_persona
        FROM pr_solicitudes
       WHERE nro_solicitud = v_nro_solicitud;
   EXCEPTION
      WHEN no_data_found THEN
         v_nro_linea := NULL;
   END;

   /*toda la parte de cash x eliminación se hará en las aplicaciones porque
   los trigger dan mutating*/

   /*IF nvl(:new.mto_aplicado,0) <> nvl(:old.mto_aplicado,0) then
     begin
       --- Eliminar bloqueo de ahorros si la garantia es de cash
       if :old.cod_garantia = 5 then
         --- Verificar si corresponde a cuenta de ahorros
         v_cod_modalidad := lf_ver_cta_gestion(:old.nro_garantia);
         if v_cod_modalidad is not null and nvl(:old.mto_aplicado,0) <> 0
         and nvl(:new.mto_aplicado,0) = 0 then
           v_fec_valor := pag_cal.fu_obt_fec_actual(6);
           v_hora      := to_char(sysdate,'hh24:mi:ss');
           --- Recuperar datos del cash y la propuesta
           for gar in garan loop
             --Obtener el monto bloqueado
             v_mto_bloqueado := LF_OBT_MTO_BLOQUEO(:old.nro_solicitud,gar.nro_cta_referencia);
   
             v_nro_secuencia :=  v_nro_secuencia + 1;
             --x ahora elimina si la propuesta original se desasocia de la garantia
             --ver si se debe atar a otra si tiene o verificar si tiene otro asociado
             --antes de eliminar.
             -- Eliminar ge_bloqueos
             delete ge_bloqueos
             where nro_cuenta    = gar.nro_cta_referencia
             and nro_documento = :old.nro_solicitud;
             --- Actualizar saldo bloqueado
             if nvl(v_mto_bloqueado,0) > 0 then
                 If v_cod_modalidad in (31,41) then --x el monto bloqueado
                    --Verificar si se puede realizar el desbloqueo
                    pag_cta.pr_ver_operacion(gar.nro_cta_referencia,
                                              950,--cod_tra_padre
                                              3,
                                              v_cod_modalidad,
                                              'D',
                                              gar.cod_mon_cuenta,
                                              v_mto_bloqueado,
                                              gar.cod_ofi_prestamo,
                                              -- out
                                              pag_cta.g_ctas.cod_modulo,
                                              pag_cta.g_ctas.cod_modalidad,
                                              v_nvo_estado,
                                              v_sal_disponible,
                                              v_procesa,
                                              507); --cod_transaccion
                    if pag_cta.g_cod_error <> 0 or v_procesa = 'N' then
                       raise_application_error(-20000,pag_cta.FU_OBT_MSJ_ERROR);
                    end if;
   
                    pag_cta.PR_ACT_SAL_CTA(gar.nro_cta_referencia, v_cod_modalidad, 'D',
                                v_fec_valor, v_hora, null, null, v_mto_bloqueado, 'N');
                 elsif v_cod_modalidad in (33,34) then--cda --x el monto total
                    --Verificar si se puede realizar el desbloqueo
                    pag_cta.pr_ver_operacion(gar.nro_cta_referencia,
                                              950,--cod_tra_padre
                                              3,
                                              v_cod_modalidad,
                                              'D',
                                              gar.cod_mon_cuenta,
                                              gar.monto,
                                              gar.cod_ofi_prestamo,
                                              -- out
                                              pag_cta.g_ctas.cod_modulo,
                                              pag_cta.g_ctas.cod_modalidad,
                                              v_nvo_estado,
                                              v_sal_disponible,
                                              v_procesa,
                                              507); --cod_transaccion
                    if pag_cta.g_cod_error <> 0 or v_procesa = 'N' then
                       raise_application_error(-20000,pag_cta.FU_OBT_MSJ_ERROR);
                    end if;
   
                    pag_cta.PR_ACT_SAL_CTA(gar.nro_cta_referencia, v_cod_modalidad, 'D',
                                 v_fec_valor, v_hora, null, null, gar.monto, 'N');
                 End if;
                 --- Insertar movimiento de saldo bloqueado
                 r_gmovi.cod_usuario     := user;
                 r_gmovi.hora            := v_hora;
                 r_gmovi.nro_secuencia   := v_nro_secuencia;
                 r_gmovi.cod_modulo      := gar.cod_mod_cuenta;
                 r_gmovi.cod_modalidad   := gar.cod_mad_cuenta;
                 r_gmovi.cod_oficina     := gar.cod_ofi_cuenta;
                 r_gmovi.nro_cuenta      := gar.nro_cta_referencia;
                 r_gmovi.cod_moneda      := gar.cod_mon_cuenta;
                 r_gmovi.fec_valor       := v_fec_valor;
                 r_gmovi.fecha           := v_fec_valor;
                 r_gmovi.cod_tra_padre   := 950; --- Garantías de préstamos
                 r_gmovi.cod_transaccion := 507; --- Saldo bloqueado
                 r_gmovi.estado          := 'N';
                 r_gmovi.cod_ofi_origen  := gar.cod_ofi_prestamo;
                 r_gmovi.reversado       := 'N';
                 r_gmovi.emi_aviso       := 'N';
                 r_gmovi.protegido       := 'N';
                 r_gmovi.cod_mod_padre   := 6;
                 r_gmovi.cod_mad_padre   := gar.cod_mad_prestamo;
                 If v_cod_modalidad in (31,41) then
                    r_gmovi.monto           := nvl(v_mto_bloqueado,0);
                 elsif v_cod_modalidad in (33,34) then
                    r_gmovi.monto           := nvl(gar.monto,0);
                 End if;
                 r_gmovi.nro_documento   := nvl(:old.nro_solicitud,0);
                 r_gmovi.concepto        := 'Desbloqueo por garantia de prestamo';
                 pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                 --- Verificar si posee aun bloqueo
                 begin
                    select count(*) into v_cantidad
                    from ge_bloqueos
                    where nro_cuenta = v_nro_cta_referencia;
                 exception
                    when no_data_found then
                       v_cantidad := 0;
                 end;
                 if v_cantidad = 0 then
                    If v_cod_modalidad in (33,34) then
                       --actualizar campo bloqueado a NO
                       pag_cta.PR_ACT_CTA_BLOQUEO(gar.nro_cta_referencia,'N');
                    else
                       --- Actualizar estado de la cuenta
                       pag_cta.PR_ACT_EST_CTA(gar.nro_cta_referencia, v_cod_modalidad, 'N', v_fec_valor);
                       --- Generar movimiento por cambio de estado
                       v_nro_secuencia :=  v_nro_secuencia + 1;
                       r_gmovi.cod_usuario     := user;
                       r_gmovi.hora            := v_hora;
                       r_gmovi.nro_secuencia   :=  v_nro_secuencia;
                       r_gmovi.cod_modulo      := gar.cod_mod_cuenta;
                       r_gmovi.cod_modalidad   := gar.cod_mad_cuenta;
                       r_gmovi.cod_oficina     := gar.cod_ofi_cuenta;
                       r_gmovi.nro_cuenta      := gar.nro_cta_referencia;
                       r_gmovi.cod_moneda      := gar.cod_mon_cuenta;
                       r_gmovi.fec_valor       := v_fec_valor;
                       r_gmovi.fecha           := v_fec_valor;
                       r_gmovi.cod_tra_padre   := 950; --- Garantías de préstamos
                       r_gmovi.cod_transaccion := 415; --- Estado bloqueo de saldos
                       r_gmovi.est_cuenta      := 'N';
                       r_gmovi.estado          := 'N';
                       r_gmovi.cod_ofi_origen  := gar.cod_ofi_prestamo;
                       r_gmovi.reversado       := 'N';
                       r_gmovi.emi_aviso       := 'N';
                       r_gmovi.protegido       := 'N';
                       r_gmovi.cod_mod_padre   := 6;
                       r_gmovi.cod_mad_padre   := gar.cod_mad_prestamo;
                       r_gmovi.monto           := null;
                       r_gmovi.nro_documento   := :old.nro_solicitud;
                       r_gmovi.cod_causa       := fug_obt_pardinamico('COD_CAU_BLO_GARAN',
                                        gar.cod_mod_prestamo, gar.cod_mad_prestamo, gar.cod_mon_prestamo,
                                        gar.cod_ofi_prestamo);
                       pag_gen.pr_ins_ge_movimiento(r_gmovi);
                    end if;
                 end if;--si hay bloqueos
              end if;
           end loop;--xlas garantias
         end if;--si hay monto
       end if;--garantia 5 cash
     exception
       when others then
         If sqlcode <= -20000 then
            raise;
         else
            raise_application_error(-20001,'Elim. bloqueo'||sqlerrm);
         End if;
     end;
   end if;*/ --mto_aplicado <>
   IF deleting THEN
      IF :old.cod_garantia > 2 AND :old.nro_garantia IS NOT NULL THEN
         --- Actualizar monto aplicado de garantia x monto anterior
         IF :old.mto_aplicado IS NOT NULL THEN
            pap_gar.pr_act_gar_aplicado(:old.nro_garantia, v_cod_mon_sol, :old.mto_aplicado * -1);
         END IF;
      END IF;
   ELSIF inserting OR (updating AND nvl(:new.mto_aplicado, 0) <> nvl(:old.mto_aplicado, 0)) THEN
      BEGIN
         --Actualizar el mto aplicado de garantias por limite
         IF v_nro_linea IS NOT NULL THEN
            -- Recuperar moneda de la linea y de la garantia
            v_cod_mon_linea := pap_gar.fu_obt_mon_linea(v_nro_linea);
            IF :new.cod_garantia > 2 THEN
               v_cod_mon_gar := pap_gar.fu_obt_mon_garantia(:new.nro_garantia);
               -- Convertir el monto a moneda de la linea en la cotizacion actual
               pag_gen.pr_con_mon_a_moneda(v_cod_mon_sol, v_cod_mon_linea,
                                           nvl(:new.mto_aplicado, 0), v_mto_a_aplicar, v_cot_mon_ori,
                                           v_cot_mon_des);
               pag_gen.pr_con_mon_a_moneda(v_cod_mon_sol, v_cod_mon_linea,
                                           nvl(:old.mto_aplicado, 0), v_mto_aplicado, v_cot_mon_ori,
                                           v_cot_mon_des);
            ELSE
               pag_gen.pr_con_mon_a_moneda(v_cod_mon_sol, v_cod_mon_linea,
                                           nvl(:new.mto_aplicado, 0), v_mto_a_aplicar, v_cot_mon_ori,
                                           v_cot_mon_des);
               pag_gen.pr_con_mon_a_moneda(v_cod_mon_sol, v_cod_mon_linea,
                                           nvl(:old.mto_aplicado, 0), v_mto_aplicado, v_cot_mon_ori,
                                           v_cot_mon_des);
            END IF;
            pap_gar.pr_act_tip_limite(v_nro_linea, :new.cod_garantia,
                                      nvl(v_mto_a_aplicar, 0) - nvl(v_mto_aplicado, 0));
            --Actualizar el mto aplicado de garantias por Modalidad
            pap_gar.pr_act_mad_limite(v_nro_linea, :new.cod_garantia,
                                      nvl(v_mto_a_aplicar, 0) - nvl(v_mto_aplicado, 0), 6,
                                      v_cod_mod_sol);
         END IF;
         IF :new.cod_garantia > 2 AND :new.nro_garantia IS NOT NULL THEN
            --Actualizar monto aplicado de garantia x monto anterior (x update) se resta
            IF :old.mto_aplicado IS NOT NULL THEN
               pap_gar.pr_act_gar_aplicado(:new.nro_garantia, v_cod_mon_sol, :old.mto_aplicado * -1);
            END IF;
            --verficiar saldo garantia x tipo implementacion
            --Actualizar monto aplicado de garantia x monto nuevo (x update/insert) se suma
            pap_gar.pr_act_gar_aplicado(:new.nro_garantia, v_cod_mon_sol, nvl(:new.mto_aplicado, 0));
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            IF SQLCODE <= -20000 THEN
               RAISE;
            ELSE
               raise_application_error(-20099, 'Ins.bloqueo ' || SQLERRM);
            END IF;
      END;
   END IF; --inserting updating

   --2430 Fase 1      
   IF inserting THEN   
      IF :new.cod_garantia = 2 THEN
         IF NOT lf_ver_vinculo(v_cod_persona, :new.nro_garantia) THEN
            INSERT INTO ba_vinculos
               (cod_persona, cod_per_vinculo, tipo)
            VALUES
               (v_cod_persona, :new.nro_garantia, 'CD');         
         END IF;
      END IF;   
   ELSIF updating THEN   
      IF :old.nro_garantia <> :new.nro_garantia THEN
         IF :new.cod_garantia = 2 THEN
            DELETE FROM ba_vinculos a
             WHERE a.cod_persona = v_cod_persona
               AND a.cod_per_vinculo = :old.nro_garantia
               AND a.tipo = 'CD';
            IF NOT lf_ver_vinculo(v_cod_persona, :new.nro_garantia) THEN
               INSERT INTO ba_vinculos
                  (cod_persona, cod_per_vinculo, tipo)
               VALUES
                  (v_cod_persona, :new.nro_garantia, 'CD');
            END IF;
         END IF;
      END IF;   
   ELSIF deleting THEN   
      IF :old.cod_garantia = 2 THEN      
         DELETE FROM ba_vinculos a
          WHERE a.cod_persona = v_cod_persona
            AND a.cod_per_vinculo = :old.nro_garantia
            AND a.tipo = 'CD';      
      END IF;   
   END IF;

END;
/

