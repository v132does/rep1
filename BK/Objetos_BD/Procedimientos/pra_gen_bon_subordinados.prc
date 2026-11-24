CREATE OR REPLACE PROCEDURE IT.PRA_GEN_BON_SUBORDINADOS IS
   /*
   || Creación de Cuentas para la modalidad 36/Bonos Subordinados,
   || posterior a la importación de datos de la tabla temporal AH_BON_SUBORDINADOS_TMP.
   */

   -- Definicion de cursor donde se encuentran los datos remitidos por la Casa de Bolsa
   CURSOR c_bonos IS
      SELECT a.nom_completo,
             a.nro_documento,
             a.ruc,
             a.nro_operacion,
             a.comitente,
             a.cod_bolsa,
             a.cod_persona,
             a.emisor,
             a.serie,
             a.fec_ini_serie,
             a.fec_vto_serie,
             a.val_tasa,
             a.fec_venta,
             a.can_bonos,
             a.mto_corte,
             a.mto_total,
             a.dia_transcurridos,
             a.int_acumulado,
             a.mto_desembolsar,
             a.mercado,
             a.moneda,
             a.mto_interes,
             a.estado,
             a.nro_cta_credito,
             a.tip_colocacion,
             a.mto_plu_precio,
             a.mto_min_precio
        FROM ah_bon_subordinados_tmp a
       WHERE a.estado = 'NUEVO'
       ORDER BY a.moneda, a.nro_operacion;
   -- En la primera fase solo procesaremos los incluidos como NUEVO
   -- Los modificados se harán manual
   v_mto_interes         NUMBER := 0;
   v_int_calculado       NUMBER := 0;
   v_mto_diferencia      NUMBER := 0;
   v_mto_valia           NUMBER := 0;
   v_cod_transaccion     ge_transacciones.cod_transaccion%TYPE;
   v_cod_tra_alta        ge_transacciones.cod_transaccion%TYPE;
   v_cod_tra_ganancia    ge_transacciones.cod_transaccion%TYPE;
   v_concepto            ge_movimientos.concepto%TYPE;
   v_cod_empresa         ge_entes.cod_ente%TYPE;
   v_cod_tasa            ge_tasas.cod_tasa%TYPE;
   v_val_tasa            ge_tas_fechas.val_tasa%TYPE;
   v_cod_moneda          ba_monedas.cod_moneda%TYPE;
   v_can_cupones         NUMBER;
   v_tip_capitalizacion  ge_par_entes.val_parametro%TYPE;
   v_cod_persona         ge_clientes.cod_persona%TYPE;
   v_nro_cta_cre         ge_cuentas.nro_cuenta%TYPE;
   v_nro_cta_ente        ge_cuentas.nro_cuenta%TYPE;
   v_ult_cupon           VARCHAR2(1) := 'N';
   v_nro_cuenta          ge_cuentas.nro_cuenta%TYPE;
   v_procesa             VARCHAR2(1) := 'N';
   v_hora                ge_movimientos.hora%TYPE;
   v_fec_actual          ge_calendarios.fec_actual%TYPE;
   v_cod_mon_local       ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
   v_cod_mon_fuerte      ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_fuerte;
   v_est_modulo          ba_modulos.estado%TYPE;
   v_moneda              ba_monedas.cod_moneda%TYPE;
   v_nro_secuencia ge_movimientos.nro_secuencia%TYPE := 0;
   v_cod_modulo          ba_modulos.cod_modulo%TYPE;
   v_cod_modalidad       ge_modalidades.cod_modalidad%TYPE;
   v_sal_disponible      NUMBER;
   v_redondeo            NUMBER(5);
   v_mto_cupon           ah_cupones.mto_interes%TYPE;
   v_nom_completo        ba_personas.nom_completo%TYPE;
   v_nvo_estado          ah_cta_vistas.estado%TYPE;
   v_cod_oficina         ge_movimientos.cod_oficina%TYPE;
   r_gmovi               ge_movimientos%ROWTYPE;
   v_nro_serie           ah_titulos.serie%TYPE;
   v_fec_vto_cupon       ah_cupones.fec_vencimiento%TYPE;
   v_fec_vto_cup_ant   ah_cupones.fec_vencimiento%TYPE;
   /*********************************************************************
   || Insertar en AH_TITULOS con el monto correspondiente al Monto Total.
   **********************************************************************
   || Para armar la clave de la tabla, se toma la serie del archivo y se graba en el campo SERIE de la tabla,
   || y el campo Número de Operación del archivo corresponderá al campo NRO_TITULO de la tabla.
   || NRO_TIT_ORIGEN -> SEN(sistema electronico de negociacion)
   */
     FUNCTION FL_CAL_INT_SIMPLE
     (P_CAPITAL ah_bon_subordinados_tmp.mto_corte%TYPE,
      P_CAN_DIAS AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE,
      P_VAL_TASA ah_bon_subordinados_tmp.val_tasa%TYPE
     )
     RETURN NUMBER
     aS

    V_MTO_INTERES NUMBER(18, 6) := 0;
    BEGIN
      v_mto_interes := 0;
      IF NVL(p_can_dias,0) <> 0 THEN
        v_mto_interes := p_capital * p_val_tasa * p_can_dias / 36500;
      END IF;

      RETURN (v_mto_interes);
    END;
   PROCEDURE lp_ins_titulos
   (
      rg_bonos      c_bonos%ROWTYPE,
      p_cod_moneda  VARCHAR2,
      p_cod_persona VARCHAR2
   ) IS
      v_existe CHAR(1);
   BEGIN
      BEGIN
         INSERT INTO ah_titulos
            (serie, nro_titulo, cod_persona, capital, estado, cod_per_endosado, beneficiario,
             fec_apertura, fec_vencimiento, ser_origen, nro_tit_origen, cod_moneda)
         VALUES
            (v_nro_serie, rg_bonos.nro_operacion, p_cod_persona, rg_bonos.mto_total, 'N', NULL,
             rg_bonos.nom_completo, rg_bonos.fec_ini_serie, rg_bonos.fec_vto_serie, 'SEN',
             rg_bonos.serie, p_cod_moneda);
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20030,
                                    'Error al insertar datos en AH_TITULOS. Operación Nro.' ||
                                     rg_bonos.nro_operacion || '-' || SQLERRM);
      END;
      -- Insertar como cliente si todavia no es cliente
      BEGIN
         SELECT 'S' INTO v_existe FROM ge_clientes c WHERE c.cod_persona = p_cod_persona;
      EXCEPTION
         WHEN no_data_found THEN
            BEGIN
               INSERT INTO ge_clientes
                  (cod_persona, cod_oficina, exo_impuestos, cod_usu_oficial, cli_especial,
                   residente, cod_sec_contable, cod_tip_deudor, cod_seg_cliente)
               VALUES
               -- RABP-CNF-09-09-2014 Se modifica fug_obt_ofi_usuario()  
               -- por la funcion fug_obt_ofi_oficial() para asignar la oficina
                  (p_cod_persona, fug_obt_ofi_oficial(p_cod_persona), 'N',
                   fug_obt_pardinamico('COD_USU_OFI_DEFECTO'), 'N', 'S', 'N', 2, 12);
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20021,
                                          'Error al insertar datos en GE_CLIENTES. Cod.Persona Nro=' ||
                                           v_cod_persona || ' ' || SQLERRM);
            END;
      END;
   END;
   /*****************************************************
   || Insertar los Bonos en la tabla AH_CTA_CERTIFICADOS.
   ******************************************************
   || Se deben generar tantas cuentas como cantidad de Bonos se indique en el archivo.
   || El monto correspondiente al saldo total de cada cuenta se toma del campo Corte Mínimo.
   */
   PROCEDURE lp_ins_cta_certificados
   (
      rg_bonos          c_bonos%ROWTYPE,
      p_nro_certificado NUMBER,
      p_cod_persona     VARCHAR2
   ) IS
   BEGIN
      -- RABP-CNF-09-09-2014 Se modifica fug_obt_ofi_usuario() la por la funcion fug_obt_ofi_oficial() para asignar la oficina
      v_nro_cuenta := fug_obt_sig_nro_cuenta(3, 36, fug_obt_ofi_oficial(p_cod_persona), v_cod_moneda, NULL);
      BEGIN
         -- el numero de certificado va a ser un nro secuencial por cada bono comprado en una operacion
         -- como sabremos que es del SEN? y si registramos en algún lugar?
         --**** con el campo SER_ORIGEN de la tabla AH_TITULOS se sabe si es del SEN
         INSERT INTO ah_cta_certificados
            (nro_cuenta, cod_modulo, cod_modalidad, cod_oficina, cod_moneda, denominacion, tipo,
             serie, nro_certificado, beneficiario, tas_personalizada, cod_tasa, fec_apertura,
             fec_vencimiento, capital, est_batch, estado, est_cer_batch, est_certificado,
             aut_pendiente, sal_tot_batch, sal_total, tra_prohibida, tip_capitalizacion,
             nro_cta_credito, cre_automatico, ser_titulo, nro_titulo)
         VALUES
            (v_nro_cuenta, 3, 36, fug_obt_ofi_oficial(p_cod_persona), v_cod_moneda, v_nom_completo, 'O',
             v_nro_serie, p_nro_certificado, rg_bonos.nom_completo, 'N', v_cod_tasa,
             /*v_fec_actual*/ rg_bonos.fec_ini_serie, rg_bonos.fec_vto_serie, rg_bonos.mto_corte,
             'A', 'A', 'E', 'E', 'N', 0, 0, 'N', v_tip_capitalizacion,
             nvl(rg_bonos.nro_cta_credito, v_nro_cta_cre)
             /*Si no se envia la cta.Crédito se toma del parente*/, 'S', v_nro_serie,
             rg_bonos.nro_operacion);
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20030,
                                    /*'Error al insertar datos en AH_CTA_CERTIFICADOS. Documento Nro=' ||
                                     rg_bonos.nro_documento || '-' ||*/ SQLERRM);
      END;
      -- insertar a la persona como principal
      BEGIN
         INSERT INTO ge_cta_clientes
            (cod_persona, nro_cuenta, dig_verificador, cod_oficina, cod_modulo, cod_modalidad,
             relacion)
         VALUES
         -- RABP-CNF-09-09-2014 Se modifica fug_obt_ofi_usuario() la por la funcion fug_obt_ofi_oficial() para asignar la oficina
            (v_cod_persona, v_nro_cuenta, 0, fug_obt_ofi_oficial(p_cod_persona), 3, 36, 'P');
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20030,
                                    'Error al insertar datos en ge_cta_clientes. Código Persona:' ||
                                     v_cod_persona || '-' || SQLERRM);
      END;
   END;
   /*********************************
   || Insertar cupones en AH_CUPONES.
   *********************************/
   PROCEDURE lp_ins_cupones
   (
      rg_bonos      c_bonos%ROWTYPE, -- ah_bon_subordinados_tmp%rowtype,
      p_nro_cuenta  VARCHAR2,
      p_nro_cupon   NUMBER,
      p_ult_cupon   VARCHAR2,
      p_mto_interes NUMBER
   ) IS
      v_fec_vto_cupon ah_cupones.fec_vencimiento%TYPE;
   BEGIN
      /*
      || A partir de la fecha de Habilitación de la Serie se deben calcular los vencimientos de los cupones.
      || Se debe tomar del parámetro del Ente la Forma de Pago de los Cupones (Trimestral o Semestral)
      || para calcular la fecha de vencimiento de los cupones.
      */
      BEGIN
        
      --v_fec_vto_cupon := add_months(rg_bonos.fec_ini_serie, (v_tip_capitalizacion * p_nro_cupon));
      SELECT fecha INTO v_fec_vto_cupon FROM AH_BON_SUB_VTO_TMP t where t.nro_cuota=p_nro_cupon;--NAD-CNFDEEVO-31-11/04/2016
      EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'Falta cargar la fecha de vencimiento.');
      END;      
      -- La fecha de vencimiento del último cupón debe corresponder a la  fecha de vencimiento de la Serie.
      /*IF p_ult_cupon = 'S' AND v_fec_vto_cupon <> rg_bonos.fec_vto_serie THEN
         v_fec_vto_cupon := rg_bonos.fec_vto_serie;
        
      END IF;*/
      /*
      || Si la fecha  resultante no es hábil, no se debe modificar, se debe dejar tal cual se calculó.
      || El procedimiento almacenado que acredita los cupones vencidos PRA_ACR_CUP_VENCIDO
      || verifica si la fecha del sistema es mayor o igual que la fecha de vencimiento,
      || por lo que no existen inconvenientes.
      */
      BEGIN
         INSERT INTO ah_cupones
            (nro_cuenta, tipo, nro_cupon, mto_interes, fec_vencimiento, estado, est_batch)
         VALUES
            (p_nro_cuenta, 'O', p_nro_cupon, p_mto_interes, v_fec_vto_cupon, 'E', 'E');
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Error Ins.Ah_Cupones:' || SQLERRM);
      END;
      /*
      || Si la fecha del sistema es mayor a la fecha de vencimiento del cupón:
      || El Estado del cupón (campo ESTADO) y su Estado Batch (campo EST_BATCH) deben ser P/Pagado.
      || El monto del interés (campo MTO_INTERES) debe ser cero (0).
      */
      IF v_fec_vto_cupon < v_fec_actual THEN
         UPDATE ah_cupones
            SET mto_interes = 0,
                estado      = 'P',
                est_batch   = 'P'
          WHERE nro_cuenta = p_nro_cuenta
            AND nro_cupon = p_nro_cupon;
      END IF;
   END;
   /*********************************************
   || PROCEDIMIENTO PARA DESBLOQUEAR LA CUENTA ||
   *********************************************/
   PROCEDURE lp_desbloquear
   (
      p_nro_cuenta      VARCHAR2,
      p_mto_desembolsar ah_bon_subordinados_tmp.mto_desembolsar%TYPE,
      p_cod_persona     VARCHAR2
   ) IS
      v_tipo               ge_bloqueos.tipo%TYPE;
      v_cod_causa          ge_bloqueos.cod_causa%TYPE;
      v_cod_tra_desbloqueo ge_transacciones.cod_transaccion%TYPE;
      v_mto_bloqueado      ge_bloqueos.monto%TYPE;
      v_nro_documento      ge_bloqueos.nro_documento%TYPE;
      v_es_bloqueado       VARCHAR2(1) := 'N';
   BEGIN
      IF pag_cta.g_ctas.estado NOT IN ('D', 'S', 'T') THEN
         raise_application_error(-20000, 'No puede Desbloquear una Cuenta que no esta Bloqueada. Cta:'||pag_cta.G_CTAS.nro_cuenta||' Estado: '||pag_cta.g_ctas.estado);
      ELSE
         v_cod_causa := fug_obt_parentes(v_cod_empresa, 'COD_CAU_BLO_CUENTA');
         IF nvl(v_cod_causa, 0) = 0 THEN
            raise_application_error(-20000, 'Causa de desbloqueo no definida.');
         END IF;

         BEGIN
            SELECT tipo, monto, nro_documento
              INTO v_tipo, v_mto_bloqueado, v_nro_documento
              FROM ge_bloqueos
             WHERE nro_cuenta = p_nro_cuenta
               AND cod_causa = v_cod_causa;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'Cta.' || p_nro_cuenta ||
                                        ' no posee bloqueo de Saldo para Bono Sobordinado.');
            WHEN too_many_rows THEN
               raise_application_error(-20000,
                                       'Cta.' || p_nro_cuenta ||
                                        ' posee más de 1 bloqueo de Saldo para causal ' ||
                                        v_cod_causa);
            WHEN OTHERS THEN
               raise_application_error(-20000,
                                       'Error consultar Cta.' || p_nro_cuenta || '-' || SQLERRM);
         END;
         IF v_tipo <> 'S' THEN
            raise_application_error(-20000, 'El tipo de bloqueo no es Saldo.');
         ELSIF nvl(v_mto_bloqueado, 0) <> nvl(p_mto_desembolsar, 0) THEN
            raise_application_error(-20000,
                                    'El Monto del bloqueo es distinto al Monto Total a Desembolsar.');
         END IF;

      END IF;
      -- Obtener transaccion del motivo de bloqueo
      BEGIN
         SELECT val_parametro
           INTO v_cod_tra_desbloqueo
           FROM ge_par_causales
          WHERE cod_causa = v_cod_causa
            AND parametro = 'COD_CAU_DES_TRANSACCION';
      EXCEPTION
         WHEN no_data_found THEN
            v_cod_tra_desbloqueo := 507;
      END;
      -- Verifica si no es Bloqueo por Deuda  en la AS.
      IF v_cod_causa <> 234 THEN
         -- actualiza saldo bloqueado
         pag_cta.pr_act_sal_cta(p_nro_cuenta, pag_cta.g_ctas.cod_modalidad, 'D', v_fec_actual,
                                v_hora, 0, 0, nvl(v_mto_bloqueado, 0), NULL, 'S');
         IF pag_cta.fu_obt_cod_error() <> 0 THEN
            raise_application_error(-20000,
                                    'Act.Sal.Cta.' || p_nro_cuenta || '-' ||
                                     pag_cta.fu_obt_msj_error());
         END IF;
         -- borrar el bloqueo
         DELETE FROM ge_bloqueos
          WHERE nro_cuenta = p_nro_cuenta
            AND cod_causa = v_cod_causa;
         -- Verifica si tiene saldo bloqueado para dejarle el estado en Saldo Bloqueado --
         BEGIN
            SELECT 'S'
              INTO v_es_bloqueado
              FROM ge_bloqueos
             WHERE nro_cuenta = p_nro_cuenta
               AND nro_documento <> v_nro_documento
               AND rownum = 1;
         EXCEPTION
            WHEN no_data_found THEN
               v_es_bloqueado := 'N';
         END;
         --actualiza estado de la cta si corresponde
         pag_cta.pr_obt_cuenta(p_nro_cuenta);
         IF nvl(pag_cta.g_ctas.sal_bloqueado, 0) <= 0 AND v_es_bloqueado = 'N' THEN
            v_nro_secuencia := v_nro_secuencia + 1;
            -- RABP-CNF-09-09-2014 Se modifica fug_obt_ofi_usuario() la por la funcion fug_obt_ofi_oficial() para asignar la oficina
            pag_cta.pr_set_variables(USER, v_fec_actual, 317, 'N', 'N', v_nro_secuencia, 'N',
                                     fug_obt_ofi_oficial(p_cod_persona), 3, 36);
            pag_cta.pr_act_estado(p_nro_cuenta, 'N', v_fec_actual, v_hora, NULL, 'S'); --procesar
         END IF;
      END IF;
   END;
   /*************************************************************
   ******************** PROCESO PRINCIPAL ***********************
   *************************************************************/
BEGIN
   
   v_fec_actual    := pag_cal.fu_obt_fec_actual(3);
   v_hora          := to_char(SYSDATE, 'HH24:MI:SS');  

   SELECT estado INTO v_est_modulo FROM ba_modulos WHERE cod_modulo = 3;
   IF v_est_modulo != 2 THEN
      raise_application_error(-20000,
                              'Sistema esta cerrado, no se permiten hacer aperturas ni modificaciones');
   END IF;
   -- RABP_CNF_09-09-2014: Buscamos la empresa para la casa de bolsa
   SELECT cod_ente INTO v_cod_empresa FROM ge_entes WHERE tipo = 'BO';
   IF v_cod_empresa IS NULL THEN
         raise_application_error(-20000,
                                 'No se pudo encontrar la empresa para la CASA DE BOLSA en el sistema.');
   END IF;
   -- RABP_CNF_21-10-2014: Hallamos el código de tasa para la casa de bolsa
   v_cod_tasa   := fug_obt_parentes(v_cod_empresa, 'COD_TAS_BONOS');
    IF v_cod_tasa IS NULL THEN
         raise_application_error(-20000,
                                 'No se pudo encontrar el codigo de tasa para la CASA DE BOLSA en el sistema.');
   END IF;
   -- cursor principal del procedimiento
   FOR i IN c_bonos LOOP
      v_cod_moneda := NULL;
      SELECT decode(TRIM(upper(i.moneda)), 'GUARANIES', 'GS', 'GUARANÍES', 'GS', 'DOLARES', 'USD',
                    NULL)
        INTO v_cod_moneda
        FROM dual;
      IF v_cod_moneda IS NULL THEN
         raise_application_error(-20000,
                                 'No se pudo leer la Moneda de la Serie para Cliente.:' ||
                                  i.nom_completo);
      END IF;
      
      if i.fec_vto_serie < v_fec_actual then       
         raise_application_error(-20000,
                                 'La fecha de venc. de serie, no puede ser menor a :' ||
                                  v_fec_actual||' , valor introducido:'||i.fec_vto_serie||
                                  ' en la fila con el nombre:'||i.nom_completo );
      end if;
      /* -------------
      || VALIDACIONES
      || ------------*/
      /*
      || Si el tipo de colocación corresponde a la casa de Valores,
      || la Persona corresponde a VALORES CASA DE BOLSA S.A
      || y la denominación corresponde a la Persona de la casa de Bolsa.
      || El beneficiario corresponde al nombre del archivo de importación.
      */
      
   -- RABP-CNF-24-09-2014: Cuando es tipo de colocacion Banco se comenta el codigo --
    /*
      IF nvl(i.tip_colocacion, 'x') = 'B' THEN
         v_cod_persona  := NULL;
         v_nom_completo := NULL;
         IF TRIM(i.nro_documento) <> '' OR i.nro_documento IS NOT NULL THEN
            BEGIN
               SELECT a.cod_persona, nom_completo
                 INTO v_cod_persona, v_nom_completo
                 FROM ge_clientes a, ba_personas b
                WHERE a.cod_persona = b.cod_persona
                  AND b.nro_documento = i.nro_documento
                  AND cod_tip_documento = 1; -- CI
            EXCEPTION
               WHEN no_data_found THEN
                  raise_application_error(-20001,
                                          'No existe Código de Persona para documento:' ||
                                           i.nro_documento);
               WHEN too_many_rows THEN
                  raise_application_error(-20002,
                                          'Múltiples registros obtenidos CI: ' || i.nro_documento);
               WHEN OTHERS THEN
                  raise_application_error(-20000, 'Error Obt.CI:' || SQLERRM);
            END;
         ELSIF TRIM(i.ruc) <> '' OR i.ruc IS NOT NULL THEN
            BEGIN
               SELECT a.cod_persona, nom_completo
                 INTO v_cod_persona, v_nom_completo
                 FROM ge_clientes a, ba_personas b
                WHERE a.cod_persona = b.cod_persona
                  AND b.nro_documento = i.ruc
                  AND cod_tip_documento = 6; -- RUC
            EXCEPTION
               WHEN no_data_found THEN
                  raise_application_error(-20001, 'No existe Código de Persona para RUC:' || i.ruc);
               WHEN too_many_rows THEN
                  raise_application_error(-20002, 'Múltiples registros obtenidos RUC: ' || i.ruc);
               WHEN OTHERS THEN
                  raise_application_error(-20000, 'Error Obt.RUC:' || SQLERRM);
            END;
         ELSE
            raise_application_error(-20000,
                                    'CI y RUC no pueden estar vacios. Cliente ' || i.nom_completo);
         END IF;
      END IF;
      */
      /*
      || Si el Bono fue colocado por la Casa de Bolsa,
      || la cuenta de donde se debe debitar es la cuenta de la bolsa
      */
      v_nro_cta_cre := NULL;
      IF nvl(i.tip_colocacion, 'x') = 'C' THEN
         v_cod_persona  := NULL;
         v_nom_completo := NULL;   
         -- RABP_CNF_09-09-2014: Buscamos la persona para la Casa de Bolsa
         BEGIN
            SELECT descripcion, cod_persona
              INTO v_nom_completo, v_cod_persona
              FROM ge_entes
             WHERE tipo = 'BO';
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000, 'Sin datos para el ente de Bonos. Nro. Operación '||i.nro_operacion);
            WHEN too_many_rows THEN
               raise_application_error(-20000, 'Mas de un ente para Bonos. Nro. Operación '||i.nro_operacion);
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Error Obt.Ente p/Bonos. Nro. Operación '||i.nro_operacion||'.Error: '|| SQLERRM);
         END;  
      
         IF v_cod_moneda = v_cod_mon_local THEN
            v_nro_cta_cre := fug_obt_parentes(v_cod_empresa, 'CTA_DEB_BONOS_GS');
         ELSIF v_cod_moneda = v_cod_mon_fuerte THEN
            v_nro_cta_cre := fug_obt_parentes(v_cod_empresa, 'CTA_DEB_BONOS_USD');
         ELSE
            raise_application_error(-20000, 'Moneda no definida');
         END IF;
         -- RABP-CNF-24-09-2014: Cuando es tipo de colocacion Banco se comenta el codigo --
         /*
      ELSE
         IF i.nro_cta_credito IS NOT NULL THEN
            -- validar que la cuenta credito corresponda al cliente
            BEGIN
               SELECT a.cod_modulo, a.cod_modalidad, a.cod_oficina, g.estado, a.nro_cuenta
                 INTO v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_nvo_estado, v_nro_cta_cre
                 FROM ge_cta_clientes a, ge_cuentas g
                WHERE a.cod_persona = v_cod_persona
                  AND a.nro_cuenta = g.nro_cuenta
                  AND a.cod_modulo IN (3, 4)
                  AND a.cod_modalidad IN (31, 41)
                  AND a.nro_cuenta = i.nro_cta_credito
                  AND a.relacion = 'P';
            EXCEPTION
               WHEN no_data_found THEN
                  raise_application_error(-20000,
                                          'No existe Cuenta Crédito:' || i.nro_cta_credito || '-' ||
                                           'para persona ' || v_cod_persona);
               WHEN too_many_rows THEN
                  raise_application_error(-20010,
                                          'Existe mas de un registro para  Cuenta Crédito:' ||
                                           i.nro_cta_credito);
               WHEN OTHERS THEN
                  raise_application_error(-20020, 'Error  Validar Cuenta Crédito:' || SQLERRM);
            END;
            IF v_nvo_estado IN ('C', 'P') THEN
               raise_application_error(-20000,
                                       'Estado no permitido para cuenta:' || i.nro_cta_credito);
            END IF;
         END IF;
         */
      END IF;
      
      IF v_cod_persona IS NULL THEN
         raise_application_error(-20000, 'Persona sin registrar. Cliente ' || i.nom_completo);
      END IF;
      
      IF v_nro_cta_cre IS NULL THEN
         raise_application_error(-20000,
                                 'No se pudo obtener el número de Cuenta. Operación:' ||
                                  i.nro_operacion);
      END IF;
      -- validar que la moneda de la cuenta credito corresponda a la moneda del Bono
      BEGIN
         SELECT cod_moneda INTO v_moneda FROM ge_cuentas WHERE nro_cuenta = v_nro_cta_cre;
      EXCEPTION
         WHEN no_data_found THEN
            raise_application_error(-20000, 'No existe Moneda para Cta.:' || v_nro_cta_cre);
         WHEN too_many_rows THEN
            raise_application_error(-20010,
                                    'Existe mas de un registro de Moneda para Cta.:' ||
                                     i.nro_cta_credito);
         WHEN OTHERS THEN
            raise_application_error(-20020,
                                    'Error  Validar Moneda para Cta.:' || v_nro_cta_cre || '-' ||
                                     SQLERRM);
      END;
      IF v_moneda <> v_cod_moneda THEN
         -- error porque la cuenta de credito(donde se despositara los cupones vencidos es distint a la cuenta a la moneda del bono
         raise_application_error(-20000,
                                 'La Moneda de la Cta.Credito: ' || v_nro_cta_cre || ' ' ||
                                  v_moneda || '  es distinta a la moneda de la Serie:' ||
                                  v_cod_moneda);
      END IF;
      -- Validar monto del corte
      IF i.mto_corte <> (nvl(i.mto_total, 0) / nvl(i.can_bonos, 1)) THEN
         raise_application_error(-20000,
                                 'El monto corte incorrecto. ' || 'Nro.Op.' || i.nro_operacion);
      END IF;
      -- RABP-CNF-13-10-2014: Validamos que la operación tenga documento o RUC --
      IF i.nro_documento IS NULL AND i.ruc IS NULL THEN
         raise_application_error(-20000,
                                 'No se pudo obtener el CI o RUC de la Operación: ' ||
                                  i.nro_operacion);
      END IF;
      
      -- RABP-CNF-13-10-2014: Validamos que la operación tenga monto de interes mayor a cero --
      IF i.mto_interes <= 0  THEN
         raise_application_error(-20000,
                                 'Monto de Total Interes debe ser mayor a cero. Operación: ' ||
                                  i.nro_operacion);
      END IF;
      
      -- RABP-CNF-13-10-2014: Validamos que la fecha no sea nula --
      IF i.fec_ini_serie is null OR i.fec_vto_serie is null OR i.fec_venta is null THEN
         raise_application_error(-20000,
                                 'Formato de fecha no es valida. Operación: ' ||
                                  i.nro_operacion);
      END IF;
      
      -- RABP-CNF-13-10-2014: Validamos que el monto en USD no sea nulo --
      IF v_cod_moneda = v_cod_mon_fuerte THEN
        IF i.int_acumulado is null THEN 
           raise_application_error(-20000,
                                   'Monto Interes Devengado, formato no valido para importar. Operación: ' ||
                                    i.nro_operacion);
        END IF;
        IF i.mto_desembolsar is null THEN 
           raise_application_error(-20000,
                                   'Total a Desembolsar, formato no valido para importar. Operación: ' ||
                                    i.nro_operacion);
        END IF;
        IF i.mto_interes is null THEN 
           raise_application_error(-20000,
                                   'Monto Total Interes, formato no valido para importar. Operación: ' ||
                                    i.nro_operacion);                                    
        END IF;
      END IF;
      
      -- RABP-CNF-21-10-2014: Validamos que la tasa de la planilla sea igual a la parametrizada para la Casa de Bolsa --
      v_val_tasa := fug_obt_val_tasa(3,36,null,null,v_cod_moneda,null,null,v_cod_tasa,null,v_fec_actual);
                              
      IF (i.val_tasa*100) != v_val_tasa THEN
         raise_application_error(-20000,
                                 'El Valor de la Tasa no corresponde al de la pizarra. Operación: ' ||
                                  i.nro_operacion||' i.val_tasa:'||i.val_tasa||' v_val_tasa:'||v_val_tasa);
      END IF;
      
      -- RABP-CNF-21-10-2014: Validamos que el monto de interes sea el correcto de acuerdo a la tasa y cantidad de bonos --
      begin
               
          v_int_calculado:=round(FL_CAL_INT_SIMPLE(nvl(i.mto_corte, 0),

                                         nvl(i.fec_vto_serie -
                                             i.fec_ini_serie,
                                             0),
                                         v_val_tasa) * nvl(i.can_bonos, 0),2);
      exception
        when others then
          v_int_calculado := 0;
      end;
      ---
  
-----
      IF i.mto_interes != v_int_calculado  THEN
         raise_application_error(-20000,
                                 'Monto de Total Interes distinto al Interes Calculado('
                                 ||v_int_calculado||'). Operación: '||i.nro_operacion||'/'|| i.mto_corte||'/'||nvl(i.fec_vto_serie -
                                             i.fec_ini_serie,
                                             0)||'/'||v_val_tasa||'/'|| i.can_bonos);
      END IF;
      
      /* -----------------
      || FIN VALIDACIONES
      || ----------------*/
      -- Insertar en AH_TITULOS
      IF length(i.serie) > 5 THEN
         v_nro_serie := substr(i.serie, length(i.serie) - 4, length(i.serie));
      ELSE
         v_nro_serie := i.serie;
      END IF;
      lp_ins_titulos(i, v_cod_moneda, v_cod_persona);
      /*
      || Para calcular la cantidad de cupones a generar,
      || se toma la fecha de vencimiento de la Serie incluida en el archivo y
      || se verifica la cantidad de meses transcurridos con respecto a la fecha de habilitación de la serie y
      || se divide con el periodo configurado en el parámetro de Ente Forma de Pago,
      || redondeando el resultado hacia arriba.
      */
      v_tip_capitalizacion := fug_obt_parentes(v_cod_empresa, 'FOR_PAG_BONOS'); -- primera fase 6 meses
      IF v_tip_capitalizacion IS NULL THEN
         raise_application_error(-20000, 'Tipo de Capitalizacion no definido-' || SQLERRM);
      END IF;
      v_can_cupones := trunc((fug_obt_dif_meses(i.fec_vto_serie, i.fec_ini_serie)) /
                             v_tip_capitalizacion);
      -- Debemos calcular el monto del interes por cada bono cert
      -- Si la Moneda de la Cuenta es igual a la Moneda Local
      v_redondeo    := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 3, 36, v_cod_moneda);
      --v_mto_interes := round(((i.mto_interes / i.can_bonos) / v_can_cupones), v_redondeo);
      
      /*
      || Para calcular el Interés generado para los cupones,
      || se divide el monto de interés de los cupones entre la cantidad de Bonos indicados en el archivo.
      || Obtengo el monto total de interes de todo el periodo por cada cuenta
      */
      v_mto_diferencia := i.mto_interes - (v_mto_interes * i.can_bonos * v_can_cupones);
      /*
      || Si el monto resultante de la división posee decimales,
      || se debe redondear hacia abajo,
      || de manera a sumar los decimales en el último cupón.
      */
      --Insertar los Bonos en la tabla AH_CTA_CERTIFICADOS.
      FOR j IN 1 .. i.can_bonos LOOP
         lp_ins_cta_certificados(i, j, v_cod_persona);
         -- Insertar cupones en AH_CUPONES.
         v_ult_cupon := 'N';
         FOR k IN 1 .. v_can_cupones LOOP
           begin
             SELECT fecha 
               INTO v_fec_vto_cupon 
               FROM AH_BON_SUB_VTO_TMP t 
              where t.nro_cuota=k;--NAD-CNFDEEVO-31-11/04/2016
           exception
             when no_data_found then
               exit;
           end;
           if k=1 then
            v_fec_vto_cup_ant:=i.fec_ini_serie;
           else
           SELECT fecha INTO v_fec_vto_cup_ant FROM AH_BON_SUB_VTO_TMP t where t.nro_cuota=k-1;
           end if;
            
            if v_fec_vto_cupon is null then
              raise_application_error(-20000,
                                               'Falta cargar la fecha de vencimiento.');
            end if;
            
            v_mto_interes:=round(FL_CAL_INT_SIMPLE(nvl(i.mto_corte, 0),

                                         nvl(v_fec_vto_cupon -
                                             v_fec_vto_cup_ant,
                                             0),
                                         v_val_tasa),2);
            
               v_mto_cupon := v_mto_interes;
            
            lp_ins_cupones(i, v_nro_cuenta, k, v_ult_cupon, v_mto_cupon);
         END LOOP;
      END LOOP;
      
   -- RABP-CNF-24-09-2014: Se comenta la generación de movimientos --
      --- Verificar si puede realizarse la operación sobre la cuenta de débito
      /*
      pag_cta.pr_obt_cuenta(i.nro_cta_credito);
      v_cod_modulo    := pag_cta.g_ctas.cod_modulo;
      v_cod_modalidad := pag_cta.g_ctas.cod_modalidad;
  
      IF nvl(i.tip_colocacion, 'x') = 'B' THEN
         lp_desbloquear(i.nro_cta_credito, i.mto_desembolsar, v_cod_persona);
      END IF;
      
      pag_cta.pr_ver_operacion(v_nro_cta_cre, 3631, 3 /*modulo de la cuenta de debito
                               , 36 --/*modalidad de la cuenta de debito
                                ,'D', v_moneda--/*moneda de la cuenta de debito
                               , i.mto_desembolsar, fug_obt_ofi_oficial(v_cod_persona),
                               --/*variables out
                               pag_cta.g_ctas.cod_modulo,
                               pag_cta.g_ctas.cod_modalidad, v_nvo_estado, v_sal_disponible,
                               v_procesa);
      IF pag_cta.g_cod_error <> 0 OR v_procesa = 'N' THEN
         raise_application_error(-20000,
                                 'Error Ver.Cta.Debito ' || i.nro_cta_credito || '-' ||
                                  pag_cta.g_msj_error);
      END IF;
   
      IF v_procesa = 'S' THEN
         --- DEBITAR de la cuenta
         v_nro_secuencia := v_nro_secuencia + 1;
         IF v_nro_secuencia > 990 THEN
            -- RABP_CNF_10-09-2014: Buscamos la hora disponible
            v_hora          := FUG_OBT_HOR_DISPONIBLE(v_fec_actual, v_hora, USER, 'N');
            --v_hora                := pag_gen.fu_obt_sig_segundo(v_hora);
            v_nro_secuencia := -999;
         END IF;
         pag_cta.pr_act_operacion(v_nro_cta_cre, v_hora, 'D', v_cod_moneda,
                                  round(i.mto_desembolsar, v_redondeo), 3631, 503, i.nro_operacion,
                                  NULL --cotización
                                  , fug_obt_ofi_oficial(v_cod_persona), 3, 36, NULL, NULL,
                                  'Debito Cuenta Nro.Operacion:' || i.nro_operacion, 'S',
                                  v_nro_secuencia, v_fec_actual, NULL, NULL, i.mto_desembolsar);
         IF pag_cta.g_cod_error <> 0 THEN
            raise_application_error(-20000,
                                    'Error Act.Operación.Cta.Debito ' || i.nro_cta_credito || '-' ||
                                     pag_cta.g_msj_error);
         END IF;
      ELSE
         raise_application_error(-20000,
                                 'Error: Cta.' || i.nro_cta_credito ||
                                  '- Sin saldo suficiente para el Débito');
      END IF; */
      /*********************************
      || Acredita en la cuenta del Ente
      *********************************/
      IF v_nro_secuencia > 990 THEN
         -- RABP_CNF_10-09-2014: Buscamos la hora disponible
         v_hora          := FUG_OBT_HOR_DISPONIBLE(v_fec_actual, v_hora, USER, 'N');
         --v_hora                := pag_gen.fu_obt_sig_segundo(v_hora);
         v_nro_secuencia := -999;
      END IF;
      IF v_cod_moneda = v_cod_mon_local THEN
         v_nro_cta_ente := fug_obt_parentes(v_cod_empresa, 'CTA_CRE_BONOS_GS');
      ELSIF v_cod_moneda = v_cod_mon_fuerte THEN
         v_nro_cta_ente := fug_obt_parentes(v_cod_empresa, 'CTA_CRE_BONOS_USD');
      ELSE
         raise_application_error(-20000, 'Moneda no definida');
      END IF;
      
   -- RABP-CNF-24-09-2014: Se comenta la generación de movimientos --
      /*
      pag_cta.pr_set_nro_documento3(v_cod_empresa);
      pag_cta.pr_act_operacion(v_nro_cta_ente, v_hora, 'C', v_cod_moneda /*moneda del corte
                               , round(i.mto_desembolsar, v_redondeo), 3631, 602, i.nro_operacion,
                               NULL, fug_obt_ofi_oficial(v_cod_persona) /*oficina del Gestor
                               , 3, 36, NULL,
                               NULL, 'Crédito automatico de Cuenta ', 'S', v_nro_secuencia,
                               v_fec_actual);
      IF pag_cta.g_cod_error <> 0 THEN
         raise_application_error(-20000,
                                 'Error Act.Operación.Cta.Crédito ' || v_nro_cta_cre || '-' ||
                                  pag_cta.g_msj_error);
      END IF;
      */
      
      /*
      || El monto de la Plusvalía o la Minusvalía ya viene en el archivo.
      || Se generan los movimientos por estos campos al fondear la cuenta.
      || No puede haber Plusvalía y Minusvalía al mismo tiempo.
      */
			v_mto_valia := 0;
      IF nvl(i.mto_plu_precio, 0) > 0 AND nvl(i.mto_min_precio, 0) > 0 THEN
         raise_application_error(-20000, 'No puede haber Plusvalía y Minusvalía al mismo tiempo.');
      END IF;
      IF nvl(i.mto_plu_precio, 0) < 0 OR nvl(i.mto_min_precio, 0) < 0 THEN
         raise_application_error(-20000, 'Monto de Plusvalía o Minusvalía debe ser mayor a cero.');
      END IF;
      v_concepto        := NULL;
      v_cod_transaccion := NULL;
      v_cod_tra_alta    := NULL;
      IF nvl(i.mto_plu_precio, 0) > 0 THEN
         v_cod_transaccion := fug_obt_parentes(v_cod_empresa, 'COD_TRA_DEV_PLUSVALIA');
         v_cod_tra_alta    := fug_obt_parentes(v_cod_empresa, 'COD_TRA_PLUSVALIA_BONOS');
         v_concepto        := 'Plusvalía Nro.Operacion:';
         v_mto_valia       := nvl(i.mto_plu_precio, 0);
      END IF;
      IF nvl(i.mto_min_precio, 0) > 0 THEN
         v_cod_transaccion := fug_obt_parentes(v_cod_empresa, 'COD_TRA_DEV_MINUSVALIA');
         v_cod_tra_alta    := fug_obt_parentes(v_cod_empresa, 'COD_TRA_MINUSVALIA_BONOS');
         v_concepto        := 'Minusvalía Nro.Operacion:';
         v_mto_valia       := nvl(i.mto_min_precio, 0);
      END IF;
      IF nvl(v_mto_valia, 0) > 0 AND v_cod_transaccion IS NULL THEN
         raise_application_error(-20000, 'Transacción Ganancia/Perdida no definida.');
      END IF;
      --- Monto de Ganancia por Plusvalia
      v_cod_tra_ganancia := NULL;
      IF nvl(i.int_acumulado, 0) > 0 THEN
         v_cod_tra_ganancia := fug_obt_parentes(v_cod_empresa, 'COD_TRA_GAN_PLUSVALIA');
      END IF;
      ---
      --- Insertar en la tabla de devengados
      ---
      IF nvl(v_mto_valia, 0) > 0 OR nvl(i.int_acumulado, 0) > 0 THEN
         INSERT INTO ah_dev_bon_subordinados
            (nro_cuenta, cod_modulo, cod_modalidad, fecha, hora, cod_usuario, nro_secuencia, monto,
             mto_equ_local, mto_int_acumulado, cod_moneda, cod_transaccion, cod_tra_alta,
             cod_tra_ganancia, concepto, fec_inicio, fec_vencimiento, estado, mto_dev_anterior,
             mto_dev_actual, mto_dev_acumulado, can_dia_actual, can_dia_anterior, cod_oficina,
             fec_ult_proceso)
         VALUES
            (v_nro_cuenta, 3, 36, v_fec_actual, v_hora, USER, v_nro_secuencia,
             round(nvl(v_mto_valia, 0), v_redondeo),
             round(pag_gen.fu_con_mon_a_moneda(v_cod_moneda, pag_gen.fu_obt_mon_local,
                                                nvl(v_mto_valia, 0)), v_redondeo),
             round(nvl(i.int_acumulado, 0), v_redondeo), v_cod_moneda, v_cod_transaccion,
             v_cod_tra_alta, v_cod_tra_ganancia, v_concepto || i.nro_operacion, i.fec_ini_serie,
             i.fec_vto_serie, 'N', 0, 0, 0, 0, 0, fug_obt_ofi_oficial(v_cod_persona)/*oficina del Gestor*/, NULL);
      END IF;
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error General: PRA_GEN_BON_SUBORDINADOS: ' || SQLERRM);
END;

 
 
/
