CREATE OR REPLACE PROCEDURE IT.prg_ins_exoneracion
(
   p_cod_transaccion    ge_transacciones.cod_transaccion%TYPE,
   p_cod_modulo         ba_modulos.cod_modulo%TYPE,
   p_cod_modalidad      ge_modalidades.cod_modalidad%TYPE,
   p_cod_moneda         ba_monedas.cod_moneda%TYPE,
   p_nro_cuenta         ge_cuentas.nro_cuenta%TYPE DEFAULT NULL,
   p_cod_persona        ba_personas.cod_persona%TYPE DEFAULT NULL,
   p_cod_tasa           ge_tasas.cod_tasa%TYPE DEFAULT NULL,
   p_mto_exoneracion    ge_tas_fechas.val_maximo%TYPE DEFAULT 0,
   p_mto_a_cobrar       ge_tas_fechas.val_maximo%TYPE DEFAULT 0,
   p_usu_autorizador    ge_exoneraciones.cod_usu_autorizador%TYPE DEFAULT USER,
   p_mto_no_cobrado     ge_tas_fechas.val_maximo%TYPE DEFAULT NULL,
   p_cod_autorizacion   ge_autorizaciones.cod_autorizacion%TYPE DEFAULT NULL,
   p_fec_movimiento     ge_movimientos.fecha%TYPE DEFAULT NULL,
   p_hor_movimiento     ge_movimientos.hora%TYPE DEFAULT NULL,
   p_cod_usu_movimiento ge_movimientos.cod_usuario%TYPE DEFAULT NULL
) IS
   v_fec_actual   DATE := pag_cal.fu_obt_fec_actual(1);
   v_des_comision ge_transacciones.descripcion%TYPE;
   ---
   v_tip_renovacion   cb_sal_inventarios.tip_renovacion%TYPE := 'X'; -- TIPO DE RENOVACION (X = NO IMPORTA)
   v_tip_interes      cb_sal_inventarios.tip_interes%TYPE := 'X'; -- TIPO DE INTERES (X = NO IMPORTA)
   v_tip_cuenta       cb_sal_inventarios.tip_operacion%TYPE := 'X'; -- TIPO DE CUENTA (X = NO IMPORTA)
   v_cod_sec_credito  pr_cta_prestamos.cod_sec_credito%TYPE := NULL; -- SECTOR DEL CREDITO (X = NO IMPORTA)
   v_tip_movimiento   VARCHAR2(1) := 'C'; -- Tipo de movimiento de la comisión es siempre C/Crédito
   v_cod_sec_contable ge_clientes.cod_sec_contable%TYPE;
   v_cod_tip_deudor   ge_clientes.cod_tip_deudor%TYPE;
   v_residente        ge_clientes.residente%TYPE;
   v_cat_riesgo       NUMBER;
   v_cod_plazo        ge_plz_contables.cod_plazo%TYPE;
   ---
   v_cod_rubro cb_rubros.cod_rubro%TYPE;
   v_des_rubro cb_rubros.descripcion%TYPE;
   ---
   v_cod_persona     ba_personas.cod_persona%TYPE;
   v_nom_completo    ba_personas.nom_completo%TYPE;
   v_cod_usu_oficial ge_clientes.cod_usu_oficial%TYPE;
   v_cod_seg_cliente ge_clientes.cod_seg_cliente%TYPE;
   ---
   v_deb_prestamos       VARCHAR2(1) := 'N';
   v_deb_solicitudes     VARCHAR2(1) := 'N';
   v_deb_tarjetas        VARCHAR2(1) := 'N';
   v_deb_tar_solicitudes VARCHAR2(1) := 'N';
   v_deb_contratos       VARCHAR2(1) := 'N';
   v_deb_certificados    VARCHAR2(1) := 'N';
   v_deb_automatico      VARCHAR2(1) := 'N';
   ---
   v_cod_tasa        ge_tasas.cod_tasa%TYPE := p_cod_tasa;
   v_tip_tasa        ge_tasas.tipo%TYPE;
   v_fec_inicio      DATE;
   v_fec_vencimiento DATE;
   v_val_tasa        ge_tas_fechas.val_tasa%TYPE;
   v_por_exoneracion ge_tas_fechas.val_extension%TYPE;
   ---
   v_redondeo        NUMBER(1);
   v_tip_valor       ge_tasas.tip_valor%TYPE;
   v_mto_exoneracion ge_tas_fechas.val_maximo%TYPE;
   v_mto_cobrado     ge_tas_fechas.val_maximo%TYPE;
   v_mto_a_cobrar    ge_tas_fechas.val_maximo%TYPE;
   v_mto_no_cobrado  ge_tas_fechas.val_maximo%TYPE;
   ---
   v_paquete        VARCHAR2(1) := 'N';
   v_cod_paquete    ge_paquetes.cod_paquete%TYPE;
   v_es_funcionario VARCHAR2(1) := 'N';
   v_es_nomina      VARCHAR2(1) := 'N';
   v_cod_ente       ge_entes.cod_ente%TYPE;
   ---
   v_usu_autorizador ge_exoneraciones.cod_usu_autorizador%TYPE;
   v_usu_insercion   ge_tasas.usu_insercion%TYPE;
   ---
   v_cod_sub_modalidad ge_sub_modalidades.cod_sub_modalidad%TYPE;
   v_cod_oficina       ba_oficinas.cod_oficina%TYPE;
   --DYDMR-4472 OMM 03/08/2016 -- Datos de Cuentas
   v_cod_ofi_cta       ba_oficinas.cod_oficina%TYPE;
   v_cod_mod_cta       ba_modulos.cod_modulo%TYPE;
   v_est_cuenta        ge_est_cuentas.estado%TYPE;
--
BEGIN
   /*
   || Nombre de la Comisión.
   || Descripción de la Transacción utilizada para el cobro del cargo.
   */
   IF p_cod_modulo IS NULL THEN
      raise_application_error('-20000', 'Se debe especificar el modulo');
   ELSIF p_cod_modalidad IS NULL THEN
      raise_application_error('-20000', 'Se debe especificar la modalidad');
   ELSIF p_cod_transaccion IS NULL THEN
      raise_application_error('-20000', 'Se debe especificar la transaccion');
   ELSIF p_cod_moneda IS NULL THEN --DYDMR-2626
      raise_application_error('-20000', 'Se debe especificar la moneda');
   ELSE
      BEGIN
         v_des_comision := fug_obt_des_transaccion(p_cod_modulo, p_cod_modalidad, p_cod_transaccion);
      EXCEPTION
         WHEN OTHERS THEN
            --DYDMR-2626
            v_des_comision := substr('Error Obt.Descr.Trans: ' || SQLERRM,1,60);
      END;
   END IF;
   /*
   || Nro. de Cliente.
   || Se debe obtener el cliente principal de la cuenta con la función FUG_OBT_CLI_PRINCIPAL.
   */
   v_cod_persona := p_cod_persona;
   IF p_nro_cuenta IS NULL AND p_cod_persona IS NULL THEN
      -- DYDMR-2626
      v_nom_completo := 'No se especifico el Nro. de Cuenta ni el Cliente';
      goto fin_proceso;
   ELSIF p_nro_cuenta IS NOT NULL AND p_cod_persona IS NULL THEN
      v_cod_persona := fug_obt_cli_principal(p_nro_cuenta);
   END IF;
   IF v_cod_persona IS NULL THEN
      -- DYDMR-2626
      v_nom_completo := 'No pudo obtener el Nro. de Cliente a partir de la Cuenta';
      goto fin_proceso;
   ELSE
      BEGIN
         /*
         || Nombre del Cliente.
         || Se obtiene mediante la función FUE_OBT_NOM_PERSONA a la que se le pasa el COD_PERSONA.
         */
         v_nom_completo := fue_obt_nom_persona(v_cod_persona);
      EXCEPTION
         WHEN OTHERS THEN
            -- DYDMR-2626
            v_nom_completo := substr('Error Obt.Nom.Cliente: '|| SQLERRM,1,120);
      END;
      BEGIN
         --- Gestor y Segmento para esa Persona.
         SELECT cod_usu_oficial, cod_seg_cliente
           INTO v_cod_usu_oficial, v_cod_seg_cliente
           FROM ge_clientes
          WHERE cod_persona = v_cod_persona;
      EXCEPTION
         WHEN OTHERS THEN
            -- DYDMR-2626
            v_nom_completo := substr('Error Obt.Gestor y Segmento: '|| SQLERRM,1,120);
      END;
   END IF;
   /*
   || Rubro del Balance.
   || Se obtiene mediante la función PAB_INV.FU_OBT_COD_RUBRO, 
   || a partir del código de transacción utilizado para el cobro del cargo.
   */
   v_cod_sub_modalidad := NULL;
   IF p_nro_cuenta IS NULL THEN
      BEGIN
         SELECT a.cod_sec_contable, a.cod_tip_deudor, a.residente, to_number(nvl(a.cat_riesgo, 1))
           INTO v_cod_sec_contable, v_cod_tip_deudor, v_residente, v_cat_riesgo
           FROM ge_clientes a
          WHERE a.cod_persona = p_cod_persona;
      EXCEPTION
         WHEN OTHERS THEN
            v_cod_sec_contable := NULL;
            v_cod_tip_deudor   := NULL;
            v_residente        := NULL;
            v_cat_riesgo       := NULL;
      END;
   ELSE
      -- DYDMR-4656 al pag_cta no se le pasa cuentas de prestamo
      if nvl(p_cod_modulo, 4) = 6 then
         Begin
            Select a.cod_oficina, a.cod_modulo, a.estado
              into v_cod_ofi_cta, v_cod_mod_cta, v_est_cuenta
            from ge_cuentas a
            where a.nro_cuenta = p_nro_cuenta ;
         Exception
            WHEN OTHERS THEN
               v_cod_ofi_cta := v_cod_oficina ;
               v_cod_mod_cta := p_cod_modulo ;
               v_est_cuenta  := null ;
         End ;
      else
         pag_cta.pr_obt_cuenta(p_nro_cuenta);
         v_cod_ofi_cta := pag_cta.G_CTAS.cod_oficina ;
         v_cod_mod_cta := pag_cta.g_ctas.cod_modulo ;
         v_est_cuenta  := pag_cta.g_ctas.est_batch ;
      end if ;   

      v_cod_sub_modalidad := fug_obt_cod_sub_modalidad(p_nro_cuenta);
      
      v_cod_oficina := v_cod_ofi_cta ;
      BEGIN
         SELECT a.cod_sec_contable, a.cod_tip_deudor, a.residente, to_number(nvl(a.cat_riesgo, 1))
           INTO v_cod_sec_contable, v_cod_tip_deudor, v_residente, v_cat_riesgo
           FROM ge_clientes a, ge_cta_clientes b
          WHERE a.cod_persona = b.cod_persona
            AND b.nro_cuenta = p_nro_cuenta
            AND b.relacion = 'P';
      EXCEPTION
         WHEN OTHERS THEN
            v_cod_sec_contable := NULL;
            v_cod_tip_deudor   := NULL;
            v_residente        := NULL;
            v_cat_riesgo       := NULL;
      END;
   END IF;
   --
   BEGIN
      SELECT a.cod_plazo
        INTO v_cod_plazo
        FROM ge_plz_contables a
       WHERE a.can_dias =
             (SELECT MIN(b.can_dias)
                FROM ge_plz_contables b
               WHERE b.can_dias >= add_months(v_fec_actual, 12) - v_fec_actual);
   EXCEPTION
      WHEN OTHERS THEN
         v_cod_plazo := NULL;
   END;

   -- CROMEEXO-1 obtiene y almacena en tmp datos del rubro
   prg_obt_dat_rubro(p_cod_modulo, p_cod_modalidad, p_cod_transaccion, p_cod_moneda,
                            v_cod_sec_contable, v_cod_tip_deudor, v_residente, to_char(v_cod_plazo),
                            v_tip_movimiento, v_cod_rubro, v_est_cuenta,
                            v_tip_renovacion, v_cat_riesgo, v_tip_interes, v_tip_cuenta,
                            v_cod_sec_credito, v_des_rubro, v_fec_actual);
   
   /*
   || Cuenta asociada a un Préstamo o CDA o Depósito a Plazo:
   || verificar si el cliente tiene activo uno de estos productos.
   || Devolver el valor SI o NO
   */
   -- CROMEEXO-1 solo busca informacion si corresponde al modulo especifico
   IF p_nro_cuenta is not null then
     IF p_cod_modulo = 6 then
       BEGIN
          SELECT 'S'
            INTO v_deb_prestamos
            FROM pr_cta_prestamos
           WHERE nro_cta_debito = p_nro_cuenta
             AND estado = 'N';
       EXCEPTION
          WHEN no_data_found THEN
             v_deb_prestamos := 'N';
          WHEN too_many_rows THEN
             v_deb_prestamos := 'S';
          WHEN OTHERS THEN
             raise_application_error('-20000', 'Al Obt.Deb.Automatico del Prestamo: ' || SQLERRM);
       END;
       ---         
       BEGIN
          SELECT 'S'
            INTO v_deb_solicitudes
            FROM pr_solicitudes
           WHERE nro_cta_debito = p_nro_cuenta;
       EXCEPTION
          WHEN no_data_found THEN
             v_deb_solicitudes := 'N';
          WHEN too_many_rows THEN
             v_deb_solicitudes := 'S';
          WHEN OTHERS THEN
             raise_application_error('-20000',
                                     'Al Obt.Deb.Automatico de la Solicitud del Prestamo: ' || SQLERRM);
       END;
     END IF;
     ---
     IF p_cod_modulo = 5 then
       BEGIN
          SELECT 'S'
            INTO v_deb_tarjetas
            FROM ta_cta_tarjetas
           WHERE nro_cta_debito = p_nro_cuenta;
       EXCEPTION
          WHEN no_data_found THEN
             v_deb_tarjetas := 'N';
          WHEN too_many_rows THEN
             v_deb_tarjetas := 'S';
          WHEN OTHERS THEN
             raise_application_error('-20000', 'Al Obt.Deb.Automatico de la Tarjeta: ' || SQLERRM);
       END;
       ---
       BEGIN
          SELECT 'S'
            INTO v_deb_tar_solicitudes
            FROM ta_solicitudes
           WHERE nro_cta_debito = p_nro_cuenta;
       EXCEPTION
          WHEN no_data_found THEN
             v_deb_tar_solicitudes := 'N';
          WHEN too_many_rows THEN
             v_deb_tar_solicitudes := 'S';
          WHEN OTHERS THEN
             raise_application_error('-20000',
                                     'Al Obt.Deb.Automatico de la Solicitud de la Tarjeta: ' || SQLERRM);
       END;
     END IF;
     ---
     BEGIN
        SELECT 'S'
          INTO v_deb_contratos
          FROM cs_contratos c
         WHERE c.nro_cta_debito = p_nro_cuenta
           AND c.estado NOT IN ('C', 'R'); -- (C)ancelados y (R)echazados
     EXCEPTION
        WHEN no_data_found THEN
           v_deb_contratos := 'N';
        WHEN too_many_rows THEN
           v_deb_contratos := 'S';
        WHEN OTHERS THEN
           raise_application_error('-20000', 'Al Obt.Deb.Automatico del Contrato: ' || SQLERRM);
     END;
     ---
     IF p_cod_modulo = 3 then
       BEGIN
          SELECT 'S'
            INTO v_deb_certificados
            FROM ah_cta_certificados a
           WHERE a.nro_cta_credito = p_nro_cuenta
             AND a.estado NOT IN ('T', 'C');
       EXCEPTION
          WHEN no_data_found THEN
             v_deb_certificados := 'N';
          WHEN too_many_rows THEN
             v_deb_certificados := 'S';
          WHEN OTHERS THEN
             raise_application_error('-20000', 'Al Obt.Deb.Automatico del Certificado: ' || SQLERRM);
       END;
     END IF;
   end if;
   ---
   IF v_deb_prestamos = 'S' OR
      v_deb_solicitudes = 'S' OR
      v_deb_tarjetas = 'S' OR
      v_deb_tar_solicitudes = 'S' OR
      v_deb_contratos = 'S' OR
      v_deb_certificados = 'S' THEN
      v_deb_automatico := 'S';
   END IF;
   /*
   || Datos de la tasa
   */
   IF v_cod_tasa IS NULL THEN
      BEGIN
         SELECT cod_tasa
           INTO v_cod_tasa
           FROM ge_transacciones
          WHERE cod_transaccion = p_cod_transaccion
            AND cod_modulo = p_cod_modulo
            AND cod_modalidad = p_cod_modalidad;
      EXCEPTION
         WHEN no_data_found THEN
            v_cod_tasa := NULL;
         WHEN OTHERS THEN
            raise_application_error('-20000', 'Al Obt.Tasa: ' || SQLERRM);
      END;
   END IF;
   IF v_cod_tasa IS NOT NULL THEN
      --- Tipo de tasa. (F=Fija, V=Variable ).
      BEGIN
         SELECT tip_valor, tipo
           INTO v_tip_valor, v_tip_tasa
           FROM ge_tasas
          WHERE cod_tasa = v_cod_tasa;
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error('-20000', 'Al Obt.Tipo de Tasa: ' || SQLERRM);
      END;
   END IF;
   /*
   || FEC_INICIO: Fecha de inicio de la tasa para la cuenta.
   || FEC_VENCIMIENTO: Fecha de vencimiento de la tasa para la cuenta.
   || POR_EXONERACION: % de Exoneración. VAL_EXTENSION.
   */
   IF v_tip_tasa = 'F' THEN
      BEGIN
         SELECT fec_insercion, fec_vencimiento, val_tasa, val_extension, usu_insercion
           INTO v_fec_inicio, v_fec_vencimiento, v_val_tasa, v_por_exoneracion, v_usu_insercion
           FROM ge_tas_fechas
          WHERE nvl(cod_modulo, nvl(p_cod_modulo, -1)) = nvl(p_cod_modulo, -1)
            AND nvl(cod_modalidad, nvl(p_cod_modalidad, -1)) = nvl(p_cod_modalidad, -1)
            AND nvl(cod_sub_modalidad, nvl(v_cod_sub_modalidad, -1)) = nvl(v_cod_sub_modalidad, -1)
            AND nvl(cod_oficina, nvl(v_cod_oficina, -1)) = nvl(v_cod_oficina, -1)
            AND nvl(cod_moneda, nvl(p_cod_moneda, 'x')) = nvl(p_cod_moneda, 'x')
            AND nro_cuenta = p_nro_cuenta --cuenta
            AND cod_tasa = v_cod_tasa
            AND fec_vigencia =
                (SELECT MAX(fec_vigencia)
                   FROM ge_tas_fechas
                  WHERE nvl(cod_modulo, nvl(p_cod_modulo, -1)) = nvl(p_cod_modulo, -1)
                    AND nvl(cod_modalidad, nvl(p_cod_modalidad, -1)) = nvl(p_cod_modalidad, -1)
                    AND nvl(cod_sub_modalidad, nvl(v_cod_sub_modalidad, -1)) = nvl(v_cod_sub_modalidad, -1)
                    AND nvl(cod_oficina, nvl(v_cod_oficina, -1)) = nvl(v_cod_oficina, -1)
                    AND nvl(cod_moneda, nvl(p_cod_moneda, 'x')) = nvl(p_cod_moneda, 'x')
                    AND nro_cuenta = p_nro_cuenta --cuenta
                    AND cod_tasa = v_cod_tasa
                    AND fec_vigencia <= v_fec_actual);
      
      EXCEPTION
         WHEN no_data_found THEN
            BEGIN
               SELECT fec_insercion, fec_vencimiento, val_tasa, val_extension, usu_insercion
                 INTO v_fec_inicio, v_fec_vencimiento, v_val_tasa, v_por_exoneracion, v_usu_insercion
                 FROM ge_tas_fechas
                WHERE nvl(cod_modulo, nvl(p_cod_modulo, -1)) = nvl(p_cod_modulo, -1)
                  AND nvl(cod_modalidad, nvl(p_cod_modalidad, -1)) = nvl(p_cod_modalidad, -1)
                  AND nvl(cod_sub_modalidad, nvl(v_cod_sub_modalidad, -1)) = nvl(v_cod_sub_modalidad, -1)
                  AND nvl(cod_oficina, nvl(v_cod_oficina, -1)) = nvl(v_cod_oficina, -1)
                  AND nvl(cod_moneda, nvl(p_cod_moneda, 'x')) = nvl(p_cod_moneda, 'x')
                  AND nro_cuenta IS NULL
                  AND cod_tasa = v_cod_tasa
                  AND cod_persona = v_cod_persona --persona
                  AND fec_vigencia =
                      (SELECT MAX(fec_vigencia)
                         FROM ge_tas_fechas
                        WHERE nvl(cod_modulo, nvl(p_cod_modulo, -1)) = nvl(p_cod_modulo, -1)
                          AND nvl(cod_modalidad, nvl(p_cod_modalidad, -1)) = nvl(p_cod_modalidad, -1)
                          AND nvl(cod_sub_modalidad, nvl(v_cod_sub_modalidad, -1)) = nvl(v_cod_sub_modalidad, -1)
                          AND nvl(cod_oficina, nvl(v_cod_oficina, -1)) = nvl(v_cod_oficina, -1)
                          AND nvl(cod_moneda, nvl(p_cod_moneda, 'x')) = nvl(p_cod_moneda, 'x')
                          AND nro_cuenta IS NULL
                          AND cod_tasa = v_cod_tasa
                          AND cod_persona = v_cod_persona --persona
                          AND fec_vigencia <= v_fec_actual);
            
            EXCEPTION
               WHEN no_data_found THEN
                     --- DYDMR-2442 ERROR - Cobro de Cargos por uso de ATM - PRA_COB_CAR_USO_ATM - SC 20887 
                     DECLARE CURSOR fijas IS
                      SELECT fec_insercion, fec_vencimiento, val_tasa, val_extension, usu_insercion
                        FROM ge_tas_fechas
                       WHERE nvl(cod_modulo, nvl(p_cod_modulo, -1)) = nvl(p_cod_modulo, -1)
                         AND nvl(cod_modalidad, nvl(p_cod_modalidad, -1)) = nvl(p_cod_modalidad, -1)
                         AND nvl(cod_sub_modalidad, nvl(v_cod_sub_modalidad, -1)) = nvl(v_cod_sub_modalidad, -1)
                         AND nvl(cod_oficina, nvl(v_cod_oficina, -1)) = nvl(v_cod_oficina, -1)
                                AND nvl(cod_moneda, nvl(p_cod_moneda, 'x')) = nvl(p_cod_moneda, 'x')
                                AND nro_cuenta IS NULL
                                AND cod_tasa = v_cod_tasa
                                AND cod_persona IS NULL
                                AND fec_vigencia <= v_fec_actual/*);*/
                       ORDER BY DECODE(COD_MODULO, NULL, 0, 1) +
                                DECODE(COD_MODALIDAD, NULL, 0, 1) +
                                DECODE(COD_SUB_MODALIDAD, NULL, 0, 1) DESC, fec_vigencia DESC;
                  BEGIN
                     IF fijas%isopen THEN
                        CLOSE fijas;
                     END IF;
                     OPEN fijas;
                        FETCH fijas INTO v_fec_inicio, v_fec_vencimiento, v_val_tasa,
                                         v_por_exoneracion, v_usu_insercion;
                     IF FIJAS%NOTFOUND THEN
                        --No es un error propiamente, por eso se omite el SQLERRM (ORA-0000, Normal succesful completion)
                              raise_application_error('-20000', 'Al Obt.Tasa Fija p/General: ' || 
                              'modulo:'|| nvl(p_cod_modulo, -1) ||
                              ', modalidad:'|| nvl(p_cod_modalidad, -1) ||
                              ', sub_modalidad:' || nvl(v_cod_sub_modalidad, -1) ||
                              ', oficina:' || nvl(v_cod_oficina, -1) ||
                              ', moneda:' || nvl(p_cod_moneda, 'x') ||
                              ', tasa:' || v_cod_tasa ||
                              SQLERRM);
                           END IF;
                     CLOSE FIJAS;
                  END;
               WHEN OTHERS THEN
                  raise_application_error('-20000', 'Al Obt.Tasa Fija p/Cliente: ' || SQLERRM);
            END;
         WHEN OTHERS THEN
            raise_application_error('-20000', 'Al Obt.Tasa Fija p/Cuenta: ' || SQLERRM);
      END;
   ELSIF v_tip_tasa = 'V' THEN
      DECLARE
         CURSOR rango IS
            SELECT fec_insercion, fec_vencimiento, val_tasa, val_extension, usu_insercion
              FROM ge_tas_rangos
             WHERE nvl(cod_modulo, nvl(p_cod_modulo, -1)) = nvl(p_cod_modulo, -1)
               AND nvl(cod_modalidad, nvl(p_cod_modalidad, -1)) = nvl(p_cod_modalidad, -1)
               AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
               AND nvl(cod_oficina,nvl(v_cod_oficina,-1)) = nvl(v_cod_oficina,-1)
               AND nvl(cod_moneda, nvl(p_cod_moneda, 'x')) = nvl(p_cod_moneda, 'x')
               AND nro_cuenta = p_nro_cuenta
               AND cod_tasa = p_cod_tasa
               AND val_hasta >= nvl(p_mto_a_cobrar, 0)
               AND fec_vigencia <= v_fec_actual
             ORDER BY decode(cod_modulo, NULL, 0, 1) + decode(cod_modalidad, NULL, 0, 1) +
                       decode(cod_sub_modalidad, NULL, 0, 1) DESC,
                      decode(nro_cuenta, NULL, 0, 1) DESC, fec_vigencia DESC, val_hasta ASC;
      
      BEGIN
         IF rango%ISOPEN THEN
            CLOSE rango;
         END IF;
         OPEN rango;
         FETCH rango
            INTO v_fec_inicio, v_fec_vencimiento, v_val_tasa, v_por_exoneracion, v_usu_insercion;
         IF rango%NOTFOUND THEN
            -- si no encuentra por cuenta busca por persona
            -- Buscar si esta personalizado por Persona
            DECLARE
               CURSOR rango IS
                  SELECT fec_insercion, fec_vencimiento, val_tasa, val_extension, usu_insercion
                    FROM ge_tas_rangos
                   WHERE nvl(cod_modulo, nvl(p_cod_modulo, -1)) = nvl(p_cod_modulo, -1)
                     AND nvl(cod_modalidad, nvl(p_cod_modalidad, -1)) = nvl(p_cod_modalidad, -1)
                     AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
                     AND nvl(cod_oficina,nvl(v_cod_oficina,-1)) = nvl(v_cod_oficina,-1)
                     AND nvl(cod_moneda, nvl(p_cod_moneda, 'x')) = nvl(p_cod_moneda, 'x')
                     AND nro_cuenta IS NULL
                     AND cod_tasa = p_cod_tasa
                     AND cod_persona = v_cod_persona
                     AND val_hasta >= nvl(p_mto_a_cobrar, 0)
                     AND fec_vigencia <= v_fec_actual
                   ORDER BY decode(cod_modulo, NULL, 0, 1) + decode(cod_modalidad, NULL, 0, 1) +
                             decode(cod_sub_modalidad, NULL, 0, 1) DESC,
                            decode(cod_persona, NULL, 0, 1) DESC, fec_vigencia DESC, val_hasta ASC;
            BEGIN
               IF rango%ISOPEN THEN
                  CLOSE rango;
               END IF;
               OPEN rango;
               FETCH rango
                  INTO v_fec_inicio, v_fec_vencimiento, v_val_tasa, v_por_exoneracion, v_usu_insercion;
                  IF rango%NOTFOUND THEN
                  -- DYDMR-9521 IEC03 si no encuentra, busca la tasa base
                  DECLARE
                     CURSOR rango IS
                        SELECT fec_insercion, fec_vencimiento, val_tasa, val_extension, usu_insercion
                           FROM ge_tas_rangos
                          WHERE nvl(cod_modulo,nvl(p_cod_modulo,-1))               = nvl(p_cod_modulo,-1)
                              AND nvl(cod_modalidad,nvl(p_cod_modalidad,-1))         = nvl(p_cod_modalidad,-1)
                              AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
                              AND nvl(cod_oficina,nvl(v_cod_oficina,-1))             = nvl(v_cod_oficina,-1)
                              AND nvl(cod_ente,nvl(v_cod_ente,-1))                   = nvl(v_cod_ente,-1)
                              AND nvl(cod_moneda,nvl(p_cod_moneda,'x'))              = nvl(p_cod_moneda,'x')
                              AND nro_cuenta  IS NULL
                              and cod_persona IS NULL
                              AND cod_tasa                                           = p_cod_tasa
                              AND val_hasta                                         >= NVL(p_mto_a_cobrar,0)
                              AND fec_vigencia                                      <= v_fec_actual
                         ORDER BY DECODE(COD_MODULO, NULL, 0, 1) +
                                  DECODE(COD_MODALIDAD, NULL, 0, 1) +
                                  DECODE(COD_SUB_MODALIDAD, NULL, 0, 1) DESC, fec_vigencia DESC, val_hasta ASC;
                  BEGIN
                     IF rango%ISOPEN THEN
                        CLOSE rango;
                     END IF;
                     OPEN rango;
                     FETCH rango
                        INTO v_fec_inicio, v_fec_vencimiento, v_val_tasa, v_por_exoneracion, v_usu_insercion;
                     CLOSE rango;
                  END;
               END IF;
            END;
         END IF;
         CLOSE rango;
      END;
   END IF;

   /*
   || MTO_EXONERACION: Importe de la Exoneración.
   || MTO_COBRADO: Importe Cobrado.
   || MTO_A_COBRAR: Importe a cobrar s/Tarifario.
   || MTO_NO_COBRADO: Importe no percibido = importe a cobrar s/Tarifario - importe cobrado.
   */
   --> DYDMR-2626
   v_mto_exoneracion := nvl(p_mto_exoneracion, 0);
   v_mto_a_cobrar    := nvl(p_mto_a_cobrar, 0);
   -->
   /*
   || DYDMR-9486 IEC04 - Relevamiento y Ajustes a Exoneraciones de Prestamos
   || se elimina calculo personalizado de desembolso de prestamos, se realiza dentro de los procesos de prestamo
   */
   IF nvl(v_mto_exoneracion, 0) = 0 AND
      nvl(p_mto_a_cobrar, 0) <> 0 THEN
      --DYDMR-2626
      --raise_application_error('-20000', 'No tiene monto exonerado.');
      goto fin_proceso;
   ELSIF nvl(v_mto_exoneracion, 0) <> 0 AND
         nvl(p_mto_a_cobrar, 0) = 0 THEN
      --DYDMR-2626
      --raise_application_error('-20000', 'No tiene monto a cobrar.');
      goto fin_proceso;
   ELSIF nvl(v_mto_exoneracion, 0) <> 0 AND
         nvl(p_mto_a_cobrar, 0) <> 0 THEN
      v_mto_exoneracion := nvl(p_mto_exoneracion, 0);
      v_mto_a_cobrar    := nvl(p_mto_a_cobrar, 0);
   ELSE -- DYDMR-2626
      goto fin_proceso;
   END IF;
   v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_mod_cta, null, p_cod_moneda);
   
   IF nvl(p_mto_no_cobrado, 0) = 0 THEN
      IF nvl(v_tip_valor,'V') = 'V' THEN
         -- si es un valor, se toma directamente
         v_mto_no_cobrado := nvl(v_mto_a_cobrar, 0) - nvl(v_mto_exoneracion, 0);
      ELSE
         -- si es un porcentaje, se considera incluido en el cargo
         v_mto_no_cobrado := (round(nvl(v_mto_a_cobrar, 0) * nvl(v_val_tasa, 0) / (100 + nvl(v_val_tasa,0)),
                                    v_redondeo)) - nvl(v_mto_a_cobrar, 0);
      END IF;
      v_mto_cobrado := nvl(v_mto_exoneracion, 0);
   ELSE
      v_mto_no_cobrado := p_mto_no_cobrado;
      v_mto_cobrado    := nvl(v_mto_a_cobrar, 0) - nvl(v_mto_no_cobrado, 0);
   END IF;
   v_por_exoneracion := (nvl(v_mto_no_cobrado, 0) * 100) / nvl(v_mto_a_cobrar, 1);
   /*
   || Verificar Si el cliente tiene o no algún paquete asociado a esa cuenta
   || TIP_PAQUETE: Tipo de Paquete
   || ES_FUNCIONARIO: Funcionario: S/N
   || ES_NOMINA: Nómina: S/N - Si el cliente ingreso en un grupo de nómina
   || COD_ENTE: Empresa asociada: La empresa a la cual correspondía la nómina al momento de ingreso   
   */
   BEGIN
      SELECT 'S', cod_paquete
        INTO v_paquete, v_cod_paquete
        FROM ge_paq_cuentas
       WHERE nro_cuenta = p_nro_cuenta;
   EXCEPTION
      WHEN no_data_found THEN
         v_paquete     := 'N';
         v_cod_paquete := NULL;
      WHEN too_many_rows THEN
         v_paquete     := 'S';
         v_cod_paquete := NULL;
      WHEN OTHERS THEN
         raise_application_error('-20000', 'Al Obt.Paquete: ' || SQLERRM);
   END;
   ---
   BEGIN
      v_es_funcionario := fug_es_empleado(v_cod_persona);
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error('-20000', 'Al consultar si es Funcionario: ' || SQLERRM);
   END;
   ---
   BEGIN
      v_es_nomina := fug_es_cli_nomina(v_cod_persona, p_nro_cuenta);
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error('-20000', 'Al consultar si es Nomina: ' || SQLERRM);
   END;
   ---
   BEGIN
      v_cod_ente := fug_obt_ent_pag_sue(p_nro_cuenta);
   EXCEPTION
      WHEN no_data_found THEN
         v_cod_ente := NULL;
      WHEN OTHERS THEN
         raise_application_error('-20000', 'Al Obt.Ente de Pago Nomina: ' || SQLERRM);
   END;
   --> Fase 3: Buscar el usuario autorizador de la tasa
   BEGIN
      SELECT a.usu_insercion
        INTO v_usu_autorizador
        FROM ge_tas_solicitadas a
       WHERE a.cod_tasa = v_cod_tasa
         AND nvl(a.fec_vigencia,v_fec_actual) >= nvl(v_fec_inicio,v_fec_actual)
         AND nvl(a.fec_vencimiento,v_fec_actual) <= nvl(v_fec_vencimiento,v_fec_actual)
         AND a.estado = 'A'
         AND (a.nro_cuenta = p_nro_cuenta or a.cod_persona = v_cod_persona);
   EXCEPTION
      WHEN OTHERS THEN
         v_usu_autorizador := null;
   END;
   IF v_usu_autorizador IS NULL THEN
      IF v_usu_insercion IS NOT NULL THEN
         v_usu_autorizador := v_usu_insercion;
      ELSE
         v_usu_autorizador := nvl(p_usu_autorizador, USER);
      END IF;
   END IF;
   --<
   /*
   || Insetar las exoneraciones
   */
   <<fin_proceso>> -- DYDMR-2626
   IF (nvl(v_mto_cobrado,0) <= nvl(v_mto_a_cobrar,0)) AND
      (nvl(v_por_exoneracion,0) >= 0 AND nvl(v_por_exoneracion,0) <= 100) AND
      v_usu_autorizador IS NOT NULL THEN
      INSERT INTO ge_exoneraciones
         (
          --- Datos parámetro
          fecha, cod_transaccion, cod_modulo, cod_modalidad,
          --- Datos Rubro
          cod_rubro, des_rubro, des_comision, cod_moneda,
          --- Datos Cuenta
          cod_persona, nombre, nro_cuenta, est_cuenta, cod_ofi_cuenta,
          --- Datos Cliente
          cod_usu_oficial, cod_seg_cliente, deb_automatico,
          --- Datos Tasa
          fec_inicio, fec_vencimiento, cod_tasa, val_tasa, por_exoneracion,
          --- Datos importe
          mto_exoneracion, mto_cobrado, mto_a_cobrar, mto_no_cobrado,
          --- Datos complementarios
          paquete, cod_paquete, es_funcionario, es_nomina, cod_ente,
          --- Datos usuario
          cod_ofi_usuario, cod_usu_autorizador, cod_ofi_exoneracion,
          --- BSEVOCORE-40 datos para reversion 2019/10 NAF
          cod_autorizacion, fec_movimiento, hor_movimiento, cod_usu_movimiento)
      VALUES
         (
          --- Transacción utilizada para el cobro del cargo.
          v_fec_actual, p_cod_transaccion, p_cod_modulo, p_cod_modalidad,
          --- Rubros y descripciones obtenidas
          v_cod_rubro, v_des_rubro, v_des_comision, p_cod_moneda,
          --- Cliente principal
          v_cod_persona, v_nom_completo, p_nro_cuenta,
          --- Estado y Sucursal de la cuenta del cliente.
          v_est_cuenta, v_cod_ofi_cta,
          --- Oficial y Segmento del Cliente
          v_cod_usu_oficial, v_cod_seg_cliente, v_deb_automatico,
          --- Datos Tasa
          v_fec_inicio, v_fec_vencimiento, v_cod_tasa, v_val_tasa, v_por_exoneracion,
          --- Datos importe
          v_mto_exoneracion, v_mto_cobrado, v_mto_a_cobrar, v_mto_no_cobrado,
          --- Datos complementarios
          v_paquete, v_cod_paquete, v_es_funcionario, v_es_nomina, v_cod_ente,
          --- Usuario y Oficina del usuario que registra la Exoneración.
          fug_obt_ofi_usuario(user), v_usu_autorizador, fug_obt_ofi_usuario(v_usu_autorizador),
          --- BSEVOCORE-40 datos para reversion
          p_cod_autorizacion, trunc(p_fec_movimiento), trim(p_hor_movimiento), trim(p_cod_usu_movimiento));
   END IF;
END prg_ins_exoneracion;
/

