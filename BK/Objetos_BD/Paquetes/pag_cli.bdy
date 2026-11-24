CREATE OR REPLACE PACKAGE BODY IT.pag_cli IS
   PROCEDURE pr_obt_dat_proveedor
   (
      p_empresa          IN NUMBER,
      p_descripcion      OUT VARCHAR2,
      p_cod_tra_padre    OUT NUMBER,
      p_ref_txt          OUT VARCHAR2,
      p_ent_beneficiario OUT VARCHAR2,
      p_cod_tas_com_cli  OUT NUMBER,
      p_cod_tra_com_cli  OUT NUMBER
   ) IS 
      ------------------------------------------------------------
      /* Obtener datos de la empresa */
   BEGIN

      SELECT lower(descripcion) INTO p_descripcion FROM ge_entes WHERE cod_ente = p_empresa;

      p_cod_tra_padre := to_number(fug_obt_parentes(p_empresa, 'COD_TRA_PAD_PCOME'));

      IF p_cod_tra_padre IS NULL THEN
         raise_application_error(-20320, 'La empresa no posee Transaccion Padre. Verifique!!!');
      END IF;

      p_ref_txt := fug_obt_parentes(p_empresa, 'NOM_ARC_COMERCIOS');

      IF p_ref_txt IS NULL THEN
         raise_application_error(-20370, 'La empresa no tiene definido archivo txt. Verifique!!!');
      END IF;
      --p_ent_beneficiario := to_number(fug_obt_parentes(p_empresa, 'COD_ENT_BENEFICIARIO'));
      p_ent_beneficiario := fug_obt_parentes(p_empresa, 'COD_ENT_BENEFICIARIO');
      p_cod_tas_com_cli  := to_number(fug_obt_parentes(p_empresa, 'COD_TAS_COM_CLI'));
      p_cod_tra_com_cli  := to_number(fug_obt_parentes(p_empresa, 'COD_TRA_COM_CLI'));

   EXCEPTION
      WHEN no_data_found THEN
         raise_application_error(-20400, 'Empresa Inexistente... Verifique.');
      WHEN too_many_rows THEN
         raise_application_error(-20450, 'Empresa Duplicada... AVISE AL ADMINISTRADOR.');
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20450, 'Al recup. datos de la Empresa. ' || SQLERRM);
         END IF;
   END;
   PROCEDURE pr_ver_cuentas
   (
      p_nro_lote IN NUMBER,
      p_cod_ente IN NUMBER
   ) IS
      r_gpser           ge_pag_com_clientes%ROWTYPE;
      v_cod_mon_debito  ba_monedas.cod_moneda%TYPE;
      v_cod_mon_credito ba_monedas.cod_moneda%TYPE;
      v_estado          ge_est_cuentas.estado%TYPE;
      v_cod_modulo      ba_modulos.cod_modulo%TYPE;
      v_cod_modalidad   ge_cuentas.cod_modalidad%TYPE;
      v_cta_combinada   ah_cta_vistas.cta_combinada%TYPE;
      v_error           VARCHAR2(250);
      v_cod_ente        ge_entes.cod_ente%TYPE;

      CURSOR c_ser IS
         SELECT fecha,
                nro_ref_externa,
                nro_cta_debito,
                beneficiario,
                tip_documento,
                nro_documento,
                nro_cta_credito,
                cod_moneda,
                cod_ent_externa,
                monto
           FROM ge_pag_com_clientes
          WHERE nro_lote = p_nro_lote
            AND cod_ente = p_cod_ente;
   BEGIN
      FOR i IN c_ser LOOP
         IF i.nro_cta_credito IS NOT NULL AND
            i.cod_ent_externa = fug_obt_parentes(p_cod_ente, 'COD_ENT_BENEFICIARIO') THEN
            pag_cta.pr_obt_cuenta(i.nro_cta_credito);
            IF pag_cta.fu_obt_cod_error() <> 0 THEN
               v_error := 'Recup.Cta.Crédito ' || pag_cta.fu_obt_msj_error();
            END IF;
            v_cod_mon_credito := pag_cta.g_ctas.cod_moneda;
            v_estado          := pag_cta.g_ctas.estado;
            v_cod_modulo      := pag_cta.g_ctas.cod_modulo;
            v_cod_modalidad   := pag_cta.g_ctas.cod_modalidad;
            v_cta_combinada   := pag_cta.g_ctas.cta_combinada;

            IF v_cod_modalidad NOT IN (31, 41) THEN
               v_error := 'Modalidad Cta Crédito no corresponde';
               RETURN;
            END IF;
            IF v_estado IN ('A', 'C', 'T', 'D') THEN
               v_error := 'Estado de Cta crédito inválido';
            END IF;
            r_gpser.observacion := v_error;
         END IF;
         IF i.nro_cta_debito IS NOT NULL AND
            i.cod_ent_externa = fug_obt_parentes(v_cod_ente, 'COD_ENT_BENEFICIARIO') THEN
            pag_cta.pr_obt_cuenta(i.nro_cta_debito);
            IF pag_cta.fu_obt_cod_error() <> 0 THEN
               v_error := 'Recup.Cta.Débito ' || pag_cta.fu_obt_msj_error();
            END IF;
            v_cod_mon_debito := pag_cta.g_ctas.cod_moneda;
            v_estado         := pag_cta.g_ctas.estado;
            v_cod_modulo     := pag_cta.g_ctas.cod_modulo;
            v_cod_modalidad  := pag_cta.g_ctas.cod_modalidad;
            v_cta_combinada  := pag_cta.g_ctas.cta_combinada;

            IF v_cod_modalidad NOT IN (31, 41) THEN
               v_error := 'Modalidad Cta Débito no corresponde';
               RETURN;
            END IF;
            IF v_estado IN ('A', 'C', 'T', 'D') THEN
               v_error := 'Estado de Cta Débito inválido';
            END IF;
            r_gpser.observacion := v_error;
         END IF;
         IF v_cod_mon_debito IS NOT NULL AND v_cod_mon_credito IS NOT NULL THEN
            IF v_cod_mon_debito <> v_cod_mon_credito THEN
               v_error             := 'Moneda de débito y Crédito deben ser iguales.';
               r_gpser.observacion := r_gpser.observacion || v_error;
            END IF;
         END IF;

         UPDATE ge_pag_com_clientes
            SET observacion = r_gpser.observacion
          WHERE nro_lote = p_nro_lote
            AND cod_ente = p_cod_ente;
      END LOOP;
   END;

   PROCEDURE pr_gen_arc_pago(p_nro_lote NUMBER) IS
     CURSOR c_ordenes IS
         SELECT fecha,
                nro_ref_externa,
                nro_cta_debito,
                nro_cta_credito,
                cod_moneda, --moneda del credito
                cod_ent_externa,
                monto,
                estado,
                beneficiario,
                observacion,
                cod_ente,
                nro_lote
           FROM ge_pag_com_clientes
          WHERE nro_lote = p_nro_lote
          ORDER BY nro_cta_debito;
      v_archivo     utl_file.file_type;
      v_nom_ascii   VARCHAR2(50);
      v_buffer      VARCHAR2(5000);
      v_cabecera    VARCHAR2(5000);
      v_fecha       DATE         := pag_cal.fu_obt_fec_actual(3);
      v_directorio  VARCHAR2(100):= fug_obt_pardinamico('DIR_PAG_COM_CLIENTES');
      v_mto_cnb     gv_movimientos.MONTO%type;
      v_mto_ueno    ge_deu_com_clientes.mto_tot_pend%type;
      v_tip_mov     varchar2(1);
      v_fec_arc     DATE := pag_cal.fu_obt_fec_actual(1);
   BEGIN

   IF utl_file.is_open(v_archivo) THEN
      utl_file.fclose(v_archivo);
   END IF;

   v_nom_ascii := 'PROCESADO_WEPA_' || to_char(v_fecha, 'DDMMYYYY') || '.txt';

   v_archivo   := utl_file.fopen(v_directorio, v_nom_ascii, 'w');

   v_cabecera    := 'FECHA;' ||
                    'NRO_REF_EXTERNA;' ||
                    'NRO_CTA_DEBITO;' ||
                    'NRO_CTA_CREDITO;' ||
                    'COD_MONEDA;' ||
                    'COD_ENT_EXTERNA;' ||
                    'MONTO;' ||
                    'ESTADO;' ||
          'BENEFICIARIO;' ||
                    'COD_ENTE;' ||
                    'NRO_LOTE/NRO_COMPROBANTE;' ||
                    'OBSERVACION;' ||
                    'MONTO_CNB;' ||
                    'MONTO_UENO;' ||
                    'TIP_MOVIMIENTO';

   utl_file.put_line(v_archivo, v_cabecera);

   FOR reg in c_ordenes LOOP
       if upper(reg.beneficiario) like '%WEPA%' THEN
         v_tip_mov := 'C';
       else
        v_tip_mov := 'D';
       end if;
     --se obtiene monto cnb por cada registro-----
     begin
       select a.monto
         into v_mto_cnb
         from ge_movimientos a
        where a.nro_documento = reg.nro_lote
          and a.nro_cuenta = reg.nro_cta_debito
          and a.fecha = v_fec_arc
          and a.cod_transaccion = 8916
          and cod_tra_padre = 8915
          and a.nro_documento3 = reg.cod_ente;
     EXCEPTION
       WHEN no_data_found THEN
         v_mto_cnb := 0;
       when too_many_rows then
         select a.monto
           into v_mto_cnb
           from ge_movimientos a
          where a.nro_documento = reg.nro_lote
            and a.nro_cuenta = reg.nro_cta_debito
            and a.fecha = v_fec_arc
            and a.cod_transaccion = 8916
            and cod_tra_padre = 8915
            and a.nro_documento3 = reg.cod_ente
            and rownum = 1;
       when others then
         raise_application_error(-20001,
                                 'Error al buscar gv_movimientos.' ||
                                 sqlerrm);
     end;
     --se obtiene monto ueno por cada registro -----
     begin
       select b.mto_tot_pend
         into v_mto_ueno
         from ge_deu_com_clientes b
        where b.nro_lote = p_nro_lote
          and b.nro_cta_debito = reg.nro_cta_debito
          and b.estado != 'P'
          and b.cod_ente = reg.cod_ente;
     EXCEPTION
       WHEN no_data_found THEN
         v_mto_ueno := 0;
       when too_many_rows then
         select b.mto_tot_pend
           into v_mto_ueno
           from ge_deu_com_clientes b
          where b.nro_lote = p_nro_lote
            and b.nro_cta_debito = reg.nro_cta_debito
            and b.estado != 'P'
            and b.cod_ente = reg.cod_ente
            and rownum = 1;
       when others then
         raise_application_error(-20002,
                                 'Error al buscar ge_deu_com_clientes.' ||
                                 sqlerrm);

     end;
        v_buffer    := reg.fecha || ';' ||
                       reg.nro_ref_externa|| ';' ||
                       reg.nro_cta_debito|| ';' ||
                       reg.nro_cta_credito|| ';' ||
                       reg.cod_moneda|| ';' ||
                       reg.cod_ent_externa|| ';' ||
                       reg.monto|| ';' ||
                       reg.estado|| ';' ||
                       reg.beneficiario|| ';' ||
                       reg.cod_ente|| ';' ||
                       reg.nro_lote|| ';' ||
                       reg.observacion|| ';' ||
                       v_mto_cnb|| ';' ||
                       v_mto_ueno|| ';' ||
                       v_tip_mov;


        utl_file.put_line(v_archivo, v_buffer);

   END LOOP;

     utl_file.fclose(v_archivo);

   END;


   PROCEDURE pr_act_obs_mov(  p_nro_cuenta  IN NUMBER,
                              p_nro_lote    IN NUMBER,
                              p_cod_moneda  IN VARCHAR2,
                              p_tipo        IN VARCHAR2, --(D/C)
                              p_mensaje     IN VARCHAR2,
                              p_id          IN VARCHAR2
                            ) IS
   BEGIN

     IF p_tipo = 'D' THEN

         UPDATE ge_pag_com_clientes a
            SET a.observacion    = a.observacion||p_mensaje
          WHERE a.nro_cta_debito = p_nro_cuenta
            AND a.cod_moneda     = p_cod_moneda
            AND a.nro_lote       = p_nro_lote
            AND rowid            = p_id;

     ELSIF p_tipo = 'C' THEN

         UPDATE ge_pag_com_clientes a
            SET a.observacion     = a.observacion||p_mensaje
          WHERE a.nro_cta_credito = p_nro_cuenta
            AND a.cod_moneda      = p_cod_moneda
            AND a.nro_lote        = p_nro_lote
            AND rowid             = p_id;

     END IF;

   END;

   PROCEDURE pr_ins_ge_pag_com_cli
   (
      p_cod_ente IN NUMBER DEFAULT NULL,
      p_fecha    IN DATE DEFAULT NULL
   ) IS
      v_existe_per      VARCHAR2(1);
      v_existe_ente     VARCHAR2(1);
      v_persona         ba_personas.cod_persona%TYPE;
      v_cod_persona     ba_personas.cod_persona%TYPE;
      r_gpser           ge_pag_com_clientes%ROWTYPE;
      v_cod_mon_debito  ba_monedas.cod_moneda%TYPE;
      v_cod_mon_credito ba_monedas.cod_moneda%TYPE;
      v_estado          ge_est_cuentas.estado%TYPE;
      v_cod_modulo      ba_modulos.cod_modulo%TYPE;
      v_cod_modalidad   ge_cuentas.cod_modalidad%TYPE;
      v_cta_combinada   ah_cta_vistas.cta_combinada%TYPE;
      v_error           VARCHAR2(250);
      v_cod_entidad     ge_par_dinamicos.parametro%TYPE;
      v_cod_ente        ge_entes.cod_ente%TYPE;
      v_existe          VARCHAR2(1);

      CURSOR c_ser IS
         SELECT fecha,
                nro_ref_externa,
                nro_cta_debito,
                beneficiario,
                tip_documento,
                nro_documento,
                nro_cta_credito,
                cod_moneda,
                cod_ent_externa,
                monto
           FROM ge_pag_com_clientes_tmp;

      PROCEDURE lp_ins_ge_pag_com_clientes(r_gpser ge_pag_com_clientes%ROWTYPE) IS
      BEGIN
         INSERT INTO ge_pag_com_clientes
            (fecha, nro_ref_externa, nro_cta_debito, beneficiario, tip_documento, nro_documento,
             nro_cta_credito, cod_moneda, cod_ent_externa, monto, nro_lote, nro_sec_lote, estado,
             observacion, for_pago, cod_ente)
         VALUES
            (r_gpser.fecha, r_gpser.nro_ref_externa, r_gpser.nro_cta_debito, r_gpser.beneficiario,
             r_gpser.tip_documento, r_gpser.nro_documento, r_gpser.nro_cta_credito,
             r_gpser.cod_moneda, r_gpser.cod_ent_externa, r_gpser.monto, r_gpser.nro_lote,
             r_gpser.nro_sec_lote, r_gpser.estado, r_gpser.observacion, r_gpser.for_pago,
             r_gpser.cod_ente);
      END;

   BEGIN
      BEGIN
         pre_ini_aplicacion;
         pae_cnf.g_cod_modulo := 1;
      END;
      SELECT s_nro_lote.nextval INTO r_gpser.nro_lote FROM dual;
      FOR i IN c_ser LOOP
         r_gpser.observacion := NULL;
         v_existe_per        := NULL;
         v_persona           := NULL;
         v_error             := NULL;
         v_cod_mon_credito   := NULL;
         r_gpser.for_pago    := NULL;

         BEGIN
            SELECT 'S', cod_persona
              INTO v_existe_per, v_persona
              FROM ba_personas
             WHERE nro_documento = i.nro_documento;
         EXCEPTION
            WHEN no_data_found THEN
               v_existe_per := 'N';
         END;
         BEGIN
            SELECT cod_persona
              INTO v_cod_persona
              FROM ge_cta_clientes e
              WHERE e.nro_cuenta = i.nro_cta_credito
               AND e.relacion = 'P';
         EXCEPTION
            WHEN no_data_found THEN
               v_cod_persona := NULL;
               v_existe_per  := 'N';
         END;
         BEGIN
            SELECT cod_ente
              INTO v_cod_ente
              FROM ge_entes e
             WHERE e.cod_persona = v_cod_persona
               AND e.tipo = 'PA';
         EXCEPTION
            WHEN no_data_found THEN
               v_cod_ente    := 0;
         END;

         v_cod_entidad := fug_obt_parentes(v_cod_ente, 'COD_ENT_BENEFICIARIO');
         BEGIN
            SELECT DISTINCT 'S'
              INTO v_existe
              FROM ge_pag_com_clientes e
             WHERE e.cod_ente = v_cod_ente
               AND e.nro_ref_externa = i.nro_ref_externa
               AND e.estado <> 'A'
               AND e.fecha = i.fecha;
         EXCEPTION
            WHEN no_data_found THEN
               v_existe := 'N';
         END;

         IF i.nro_cta_credito IS NOT NULL AND i.cod_ent_externa = v_cod_entidad THEN
            pag_cta.pr_obt_cuenta(i.nro_cta_credito);
            IF pag_cta.fu_obt_cod_error() <> 0 THEN
               v_error := 'Recup.Cta.Crédito ' || pag_cta.fu_obt_msj_error();
            END IF;
            v_cod_mon_credito := pag_cta.g_ctas.cod_moneda;
            v_estado          := pag_cta.g_ctas.estado;
            v_cod_modulo      := pag_cta.g_ctas.cod_modulo;
            v_cod_modalidad   := pag_cta.g_ctas.cod_modalidad;
            v_cta_combinada   := pag_cta.g_ctas.cta_combinada;

            IF v_cod_modalidad NOT IN (31, 41, 43) THEN
               v_error := 'Modalidad Cta Crédito no corresponde';
            END IF;
            IF v_estado IN ('A', 'C', 'T', 'D') THEN
               v_error := 'Estado de Cta crédito inválido';
            END IF;
            r_gpser.observacion := v_error;
         END IF;
         IF i.nro_cta_debito IS NOT NULL AND i.cod_ent_externa = v_cod_entidad THEN
            pag_cta.pr_obt_cuenta(i.nro_cta_debito);
            IF pag_cta.fu_obt_cod_error() <> 0 THEN
               v_error := 'Recup.Cta.Débito ' || pag_cta.fu_obt_msj_error();
            END IF;
            v_cod_mon_debito := pag_cta.g_ctas.cod_moneda;
            v_estado         := pag_cta.g_ctas.estado;
            v_cod_modulo     := pag_cta.g_ctas.cod_modulo;
            v_cod_modalidad  := pag_cta.g_ctas.cod_modalidad;
            v_cta_combinada  := pag_cta.g_ctas.cta_combinada;

            IF v_cod_modalidad NOT IN (31, 41, 43) THEN
               v_error := 'Modalidad Cta Débito no corresponde';
            END IF;
            IF v_estado IN ('A', 'C', 'T') THEN
               v_error := 'Estado de Cta Débito inválido';
            END IF;
            r_gpser.observacion := v_error;
         END IF;
         IF v_existe = 'S' THEN
            r_gpser.observacion := 'Archivo duplicado. Verifique.';
         END IF;
         IF v_cod_mon_debito IS NOT NULL AND i.cod_ent_externa = v_cod_entidad THEN
            IF v_cod_mon_debito <> i.cod_moneda THEN
               v_error             := 'Moneda de débito y Crédito deben ser iguales.';
               r_gpser.observacion := r_gpser.observacion || v_error;
            END IF;
         END IF;

         IF i.cod_ent_externa = v_cod_entidad THEN
            --crédito en cuenta
            r_gpser.for_pago := 'C';
         ELSIF v_cod_ente = 0 THEN -- no se encontro ningun Ente
            r_gpser.for_pago := 'C';
            r_gpser.observacion := r_gpser.observacion || 'El codigo de Ente no existe';
         ELSE
            -- transferencia sipap.
            r_gpser.for_pago := 'T';
         END IF;
         SELECT s_nro_sec_comercios.nextval INTO r_gpser.nro_sec_lote FROM dual;
         r_gpser.fecha           := i.fecha;
         r_gpser.cod_ente        := v_cod_ente;
         r_gpser.nro_ref_externa := i.nro_ref_externa;
         r_gpser.nro_cta_debito  := i.nro_cta_debito;
         r_gpser.beneficiario    := i.beneficiario;
         r_gpser.tip_documento   := i.tip_documento;
         r_gpser.estado          := 'C';
         r_gpser.nro_documento   := i.nro_documento;
         r_gpser.nro_cta_credito := i.nro_cta_credito;
         r_gpser.cod_moneda      := i.cod_moneda;
         r_gpser.cod_ent_externa := i.cod_ent_externa;
         r_gpser.monto           := i.monto;

         lp_ins_ge_pag_com_clientes(r_gpser);
      END LOOP;
   END;

   PROCEDURE pr_cre_pag_com_cuentas
   (
      p_cod_ente  IN NUMBER DEFAULT NULL,
      p_nro_lote  IN NUMBER,
      p_error     OUT VARCHAR2,
      p_msj_error OUT VARCHAR2
   ) IS
      v_cod_modulo       ge_movimientos.cod_modulo%TYPE;
      v_cod_modalidad    ge_movimientos.cod_modalidad%TYPE;
      v_fec_actual       ge_calendarios.fec_actual%TYPE := pag_cal.fu_obt_fec_actual(1);
      v_nro_secuencia    ge_movimientos.nro_secuencia%TYPE := 0;
      v_hora             ge_movimientos.hora%TYPE := fug_ini_hora(SYSDATE, 'HH24:MI:SS');
      v_cod_oficina      ge_movimientos.cod_oficina%TYPE;
      v_cod_tra_debito   ge_transacciones.cod_transaccion%TYPE;
      v_con_credito      ge_movimientos.concepto%TYPE; -- concepto movimiento crédito
      v_con_debito       ge_movimientos.concepto%TYPE; -- concepto movimiento débito
      v_descripcion      ge_entes.descripcion%TYPE;
      v_cod_tra_padre    ge_par_entes.val_parametro%TYPE;
      v_cod_tas_com_cli  ge_par_entes.val_parametro%TYPE;
      v_cod_tra_com_cli  ge_par_entes.val_parametro%TYPE;
      v_val_tas_cargo    ge_movimientos.val_tasa%TYPE;
      v_estado           ge_cuentas.estado%TYPE;
      v_sal_disponible   ge_cuentas.sal_contable%TYPE;
      v_cod_tas_cargo    ge_movimientos.cod_tasa%TYPE;
      v_val_cargo        ge_movimientos.val_tasa%TYPE;
      v_cod_tra_impuesto ge_movimientos.cod_transaccion%TYPE;
      v_cod_tas_impuesto ge_movimientos.cod_tasa%TYPE;
      v_val_tas_impuesto ge_movimientos.val_tasa%TYPE;
      v_val_impuesto     ge_movimientos.val_tasa%TYPE;
      v_mto_cargo        ge_movimientos.monto%TYPE;
      r_gmovi            ge_movimientos%ROWTYPE;
      v_mto_impuesto     ge_movimientos.monto%TYPE := 0;
      v_ref_txt          ge_par_entes.val_parametro%TYPE;
      v_ent_beneficiario ge_par_entes.val_parametro%TYPE;
      v_ind_procesa      VARCHAR2(1);
      v_existe           VARCHAR2(1);
      v_procesa          VARCHAR2(1) := 'N';

      CURSOR c_ordenes IS
         SELECT fecha,
                nro_ref_externa,
                nro_cta_debito,
                beneficiario,
                tip_documento,
                nro_documento,
                nro_cta_credito,
                cod_moneda,
                cod_ent_externa,
                monto,
                nro_lote,
                nro_sec_lote,
                estado,
                observacion,
                for_pago,
                fec_pago,
                cod_ente
           FROM ge_pag_com_clientes
          WHERE estado IN ('C', 'R', 'P')
            AND trunc(fecha) <= v_fec_actual -- x si el pago se cargó el día anterior, igual debe procesar hoy
            AND cod_ente = p_cod_ente
            AND nro_lote = p_nro_lote
            AND for_pago = 'C'
            AND observacion IS NULL -- SIN ERRORES
          ORDER BY nro_cta_debito;

   BEGIN
      v_ind_procesa := 'N';
      DELETE FROM ge_pag_com_debitos_tmp;
      p_error := '00';
      pr_obt_dat_proveedor(p_cod_ente, v_descripcion, v_cod_tra_padre, v_ref_txt,
                           v_ent_beneficiario, v_cod_tas_com_cli, v_cod_tra_com_cli);
      v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      FOR reg IN c_ordenes LOOP
         --- busco los datos de la cta crédito, sólo si tuviera
         IF reg.nro_cta_credito IS NOT NULL THEN
            BEGIN
               SELECT cod_modulo, cod_modalidad, cod_oficina
                 INTO v_cod_modulo, v_cod_modalidad, v_cod_oficina
                 FROM ge_cuentas
                WHERE nro_cuenta = reg.nro_cta_credito;
            EXCEPTION
               WHEN no_data_found THEN
                  p_error     := '01';
                  p_msj_error := 'Cta. de crédito inexistente Nro ' || reg.nro_cta_credito;
               WHEN OTHERS THEN
                  p_error     := '02';
                  p_msj_error := 'ErRor Critico con Cta. de crédito. ' || SQLERRM;
            END;
         END IF;

         -- Opción de pago Crédito en Cuenta
         v_con_credito := substr('Crédito en Cuenta: Empresa ' || v_descripcion, 1, 100);

         -- CRÉDITO EN CUENTA
         IF p_error = '00' THEN
            pag_cta.pr_set_nro_documento3(p_cod_ente);
            /* acreditar la cuenta de crédito */
            pag_cta.pr_act_operacion(reg.nro_cta_credito, v_hora,
                                     -- Hora
                                     'C', reg.cod_moneda,
                                     -- Moneda de la Operación
                                     reg.monto, v_cod_tra_padre,
                                     -- COD_TRA_PADRE
                                     602,
                                     -- COD_TRA_HIJO
                                     reg.cod_ente,
                                     -- :PROV.NRO_RECIBO,
                                     NULL,
                                     -- Cotización
                                     v_cod_oficina,
                                     -- cod_ofi_origen
                                     v_cod_modulo,
                                     -- cod_mod_padre
                                     v_cod_modalidad,
                                     -- cod_mad_padre
                                     NULL,
                                     -- cod_tasa
                                     NULL,
                                     -- val_tasa
                                     v_con_credito,
                                     -- Descripción
                                     'S',
                                     -- emi_aviso
                                     v_nro_secuencia, v_fec_actual);

            IF pag_cta.fu_obt_cod_error() <> 0 THEN
               p_error     := '05';
               p_msj_error := 'Error con Cta Cred ' || reg.nro_cta_credito || '-' ||
                              pag_cta.fu_obt_msj_error;
            END IF;
            --- Si no hubo errores actualiza tablas
            IF p_error = '00' THEN
               UPDATE ge_pag_com_clientes
                  SET estado   = 'N',
                      fec_pago = v_fec_actual
                WHERE cod_ente = reg.cod_ente
                  AND nro_sec_lote = reg.nro_sec_lote
                  AND nro_cta_credito = reg.nro_cta_credito
                  AND nro_lote = reg.nro_lote
                  AND estado IN ('C', 'R');
               v_ind_procesa := 'S';

               IF SQL%NOTFOUND THEN
                  p_error     := '06';
                  p_msj_error := 'Error al actualizar ge_pag_com_clientes. Ente-Lote: ' ||
                                 reg.cod_ente || '-' || reg.nro_lote;
               END IF;
            END IF;
            -- Actualiza temporal para debitos.
            BEGIN
               SELECT DISTINCT 'S'
                 INTO v_existe
                 FROM ge_pag_com_debitos_tmp
                WHERE nro_cta_debito = reg.nro_cta_debito
                  AND cod_moneda = reg.cod_moneda
                  AND nro_lote = reg.nro_lote;

               UPDATE ge_pag_com_debitos_tmp
                  SET mto_total = mto_total + reg.monto,
                      cantidad  = cantidad + 1,
                      hora      = v_hora
                WHERE nro_cta_debito = reg.nro_cta_debito
                  AND cod_moneda = reg.cod_moneda
                  AND nro_lote = reg.nro_lote;

            EXCEPTION
               WHEN no_data_found THEN
                  INSERT INTO ge_pag_com_debitos_tmp
                     (nro_cta_debito, cod_moneda, nro_lote, cantidad, mto_total, hora)
                  VALUES
                     (reg.nro_cta_debito, reg.cod_moneda, reg.nro_lote, 1, reg.monto, v_hora);
               WHEN OTHERS THEN
                  NULL;
            END;
         END IF;
      END LOOP;
      -- actualiza débitos.
      IF v_ind_procesa = 'S' THEN
         DECLARE
            CURSOR deb IS
               SELECT nro_cta_debito, mto_total, cod_moneda, cantidad, hora
                 FROM ge_pag_com_debitos_tmp;
         BEGIN
            FOR i IN deb LOOP
               BEGIN
                  SELECT cod_modulo, cod_modalidad, cod_oficina
                    INTO v_cod_modulo, v_cod_modalidad, v_cod_oficina
                    FROM ge_cuentas
                   WHERE nro_cuenta = i.nro_cta_debito;
               EXCEPTION
                  WHEN no_data_found THEN
                     p_error     := '01';
                     p_msj_error := 'Cta. de débito inexistente Nro ' || i.nro_cta_debito;
                  WHEN OTHERS THEN
                     p_error     := '02';
                     p_msj_error := 'Error Critico con Cta. de debito. ' || SQLERRM;
               END;
               v_mto_cargo    := 0;
               v_mto_impuesto := 0;
               -- debito el monto total y la comision
               v_con_debito := substr('Débito por Transferencia: Empresa ' || v_descripcion, 1, 100);
               IF v_cod_modalidad IN (31, 41) AND p_error = '00' THEN
                  pag_cta.pr_ver_operacion(i.nro_cta_debito, v_cod_tra_padre, v_cod_modulo,
                                           v_cod_modalidad, 'D', i.cod_moneda, i.mto_total,
                                           v_cod_oficina, v_cod_modulo, v_cod_modalidad, v_estado,
                                           v_sal_disponible, v_procesa, 503);
                  IF v_procesa = 'N' THEN
                     p_error     := '07';
                     p_msj_error := 'Error con Cta Debito ' || i.nro_cta_debito || '-' ||
                                    pag_cta.fu_obt_msj_error;
                  END IF;

                  IF v_procesa = 'S' THEN
                     pag_cta.pr_set_nro_documento3(p_cod_ente);
                     /* debitar a la cuenta de débito */
                     pag_cta.pr_act_operacion(i.nro_cta_debito, i.hora,
                                              -- Hora
                                              'D', i.cod_moneda, i.mto_total, v_cod_tra_padre,
                                              -- COD_TRA_PADRE
                                              nvl(v_cod_tra_debito, 503),
                                              -- COD_TRA_HIJO
                                              p_nro_lote, NULL,
                                              -- Cotizacion
                                              v_cod_oficina,
                                              -- cod_ofi_origen
                                              v_cod_modulo,
                                              -- cod_mod_padre
                                              v_cod_modalidad,
                                              -- cod_mad_padre
                                              NULL,
                                              -- cod_tasa
                                              NULL,
                                              -- val_tasa
                                              v_con_debito, 'S',
                                              -- emi_aviso
                                              v_nro_secuencia, v_fec_actual);

                     IF pag_cta.fu_obt_cod_error() <> 0 THEN
                        p_error     := '09';
                        p_msj_error := 'Error al Tratar de Procesar Debito. ' ||
                                       pag_cta.fu_obt_msj_error;
                     END IF;
                  END IF;
               END IF;
               ---------------------------Cobro de comisión ---------------------------------
               -- calcula la comision en la moneda del credito.
               IF v_cod_tra_com_cli IS NOT NULL THEN
                  prg_obt_cargos(v_cod_oficina, i.nro_cta_debito, i.cod_moneda, i.mto_total,
                                 v_cod_modulo, v_cod_modalidad, v_cod_tra_com_cli, v_cod_tas_com_cli,
                                 v_val_tas_cargo, v_val_cargo, v_cod_tra_impuesto,
                                 v_cod_tas_impuesto, v_val_tas_impuesto, v_val_impuesto);

                  v_mto_cargo    := nvl(v_val_cargo, 0) * i.cantidad;
                  v_mto_impuesto := nvl(v_val_impuesto, 0) * i.cantidad;
               END IF;

               IF v_mto_cargo > 0 THEN
                  -- Se inserta registro por el cargo
                  v_hora              := pag_gen.fu_obt_sig_segundo(v_hora);
                  r_gmovi.cod_usuario := USER;
                  r_gmovi.hora        := v_hora;
                  r_gmovi.fecha       := v_fec_actual;
                  -- Aumento la secuencia
                  v_nro_secuencia       := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia := v_nro_secuencia;
                  --
                  r_gmovi.cod_modulo      := v_cod_modulo;
                  r_gmovi.cod_modalidad   := v_cod_modalidad;
                  r_gmovi.cod_oficina     := v_cod_oficina;
                  r_gmovi.cod_moneda      := i.cod_moneda;
                  r_gmovi.fec_valor       := v_fec_actual;
                  r_gmovi.cod_tra_padre   := v_cod_tra_padre;
                  r_gmovi.cod_mod_padre   := 3;
                  r_gmovi.cod_mad_padre   := 31;
                  r_gmovi.cod_transaccion := v_cod_tra_com_cli; --1026;
                  r_gmovi.monto           := v_mto_cargo;
                  r_gmovi.nro_documento   := i.nro_cta_debito;
                  r_gmovi.cod_ofi_origen  := v_cod_oficina;
                  r_gmovi.emi_aviso       := 'N';
                  r_gmovi.concepto        := 'Cargo por Cobro de Servicios. ';
                  r_gmovi.estado          := 'N';
                  r_gmovi.reversado       := 'N';
                  r_gmovi.cod_rubro       := NULL;
                  r_gmovi.cod_tasa        := v_cod_tas_cargo;
                  r_gmovi.val_tasa        := v_mto_cargo;
                  r_gmovi.tip_mov_rubro   := NULL;
                  r_gmovi.cod_persona     := NULL;
                  r_gmovi.referencia      := i.nro_cta_debito;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi);

                  IF v_cod_tra_impuesto IS NOT NULL THEN
                     --Tiene impuesto asociado
                     --realizar el debito x el impuesto
                     r_gmovi.cod_usuario   := USER;
                     r_gmovi.hora          := v_hora;
                     r_gmovi.fecha         := v_fec_actual;
                     v_nro_secuencia       := v_nro_secuencia + 1;
                     r_gmovi.nro_secuencia := v_nro_secuencia;
                     --
                     r_gmovi.cod_modulo      := v_cod_modulo;
                     r_gmovi.cod_modalidad   := v_cod_modalidad;
                     r_gmovi.cod_oficina     := v_cod_oficina;
                     r_gmovi.cod_moneda      := i.cod_moneda;
                     r_gmovi.fec_valor       := v_fec_actual;
                     r_gmovi.cod_tra_padre   := v_cod_tra_padre;
                     r_gmovi.cod_mod_padre   := 3;
                     r_gmovi.cod_mad_padre   := 31;
                     r_gmovi.cod_transaccion := v_cod_tra_impuesto;
                     r_gmovi.monto           := nvl(v_mto_impuesto, 0);
                     r_gmovi.nro_documento   := i.nro_cta_debito;
                     r_gmovi.cod_ofi_origen  := v_cod_oficina;
                     r_gmovi.emi_aviso       := 'N';
                     r_gmovi.concepto        := 'Iva S/ Cargos. ';
                     r_gmovi.estado          := 'N';
                     r_gmovi.reversado       := 'N';
                     r_gmovi.cod_rubro       := NULL;
                     r_gmovi.cod_tasa        := v_cod_tas_impuesto;
                     r_gmovi.val_tasa        := v_val_tas_impuesto;
                     r_gmovi.tip_mov_rubro   := NULL;
                     r_gmovi.cod_persona     := NULL;
                     r_gmovi.referencia      := i.nro_cta_debito;
                     pag_gen.pr_ins_ge_movimiento(r_gmovi);
                  END IF;

                  IF v_cod_modalidad IN (31, 41) AND p_error = '00' THEN
                     pag_cta.pr_ver_operacion(i.nro_cta_debito, v_cod_tra_padre, v_cod_modulo,
                                              v_cod_modalidad, 'D', i.cod_moneda,
                                              (v_mto_cargo + v_mto_impuesto), v_cod_oficina,
                                              v_cod_modulo, v_cod_modalidad, v_estado,
                                              v_sal_disponible, v_procesa, 503);
                     IF v_procesa = 'N' THEN
                        p_error     := '07';
                        p_msj_error := 'Error con Cta Debito ' || i.nro_cta_debito || '-' ||
                                       pag_cta.fu_obt_msj_error;
                     END IF;

                     IF v_procesa = 'S' THEN
                        -- Se inserta el débito a la cuenta.
                        pag_cta.pr_act_operacion(i.nro_cta_debito, v_hora, 'D', i.cod_moneda,
                                                 --Moneda de la Operación
                                                 (v_mto_cargo + v_mto_impuesto),
                                                 --v_val_tas_cargo,
                                                 v_cod_tra_padre, 503,
                                                 -- Debito
                                                 i.nro_cta_debito, NULL,
                                                 --COTIZACION
                                                 v_cod_oficina,
                                                 --cod_ofi_origen
                                                 3,
                                                 --cod_mod_padre
                                                 31,
                                                 --cod_mad_padre
                                                 NULL,
                                                 --cod_tasa
                                                 v_val_tas_impuesto,
                                                 --val_tasa
                                                 'Cargo por Cobro de Servicios. ', 'S',
                                                 --emi_aviso
                                                 v_nro_secuencia, v_fec_actual);
                     END IF;
                  END IF;
               END IF;
            END LOOP;
         END;
      END IF;

   EXCEPTION
      WHEN OTHERS THEN
         p_error := '99';
         raise_application_error(-20000, 'Error transf. cuentas ' || p_msj_error || SQLERRM);
   END;

   PROCEDURE pr_cre_pag_com_cuentas_cta
   (
      p_cod_ente  IN NUMBER DEFAULT NULL,
      p_nro_lote  IN NUMBER,
      p_error     OUT VARCHAR2,
      p_msj_error OUT VARCHAR2
   ) IS
      v_cod_modulo           ge_movimientos.cod_modulo%TYPE;
      v_cod_modulo_cre       ge_movimientos.cod_modulo%TYPE;
      v_cod_modalidad        ge_movimientos.cod_modalidad%TYPE;
      v_cod_modalidad_cre    ge_movimientos.cod_modalidad%TYPE;
      v_fec_actual           ge_calendarios.fec_actual%TYPE := pag_cal.fu_obt_fec_actual(1);
      v_nro_secuencia        ge_movimientos.nro_secuencia%TYPE := 0;
      v_hora                 ge_movimientos.hora%TYPE := fug_ini_hora(SYSDATE, 'HH24:MI:SS');
      v_hor_bloqueo          ge_movimientos.hora%TYPE;
      v_cod_oficina          ge_movimientos.cod_oficina%TYPE;
      v_cod_oficina_cre      ge_movimientos.cod_oficina%TYPE;
      v_cod_tra_debito       ge_transacciones.cod_transaccion%TYPE := 8916;
      v_con_credito          ge_movimientos.concepto%TYPE; -- concepto movimiento crédito
      v_con_debito           ge_movimientos.concepto%TYPE; -- concepto movimiento débito
      v_descripcion          ge_entes.descripcion%TYPE;
      v_cod_tra_padre        ge_par_entes.val_parametro%TYPE;
      v_cod_tas_com_cli      ge_par_entes.val_parametro%TYPE;
      v_cod_tra_com_cli      ge_par_entes.val_parametro%TYPE;
      v_val_tas_cargo        ge_movimientos.val_tasa%TYPE;
      v_estado               ge_cuentas.estado%TYPE;
      v_sal_disponible       ge_cuentas.sal_contable%TYPE;
      v_cod_tas_cargo        ge_movimientos.cod_tasa%TYPE;
      v_val_cargo            ge_movimientos.val_tasa%TYPE;
      v_cod_tra_impuesto     ge_movimientos.cod_transaccion%TYPE;
      v_cod_tas_impuesto     ge_movimientos.cod_tasa%TYPE;
      v_val_tas_impuesto     ge_movimientos.val_tasa%TYPE;
      v_val_impuesto         ge_movimientos.val_tasa%TYPE;
      v_mto_cargo            ge_movimientos.monto%TYPE;
      r_gmovi                ge_movimientos%ROWTYPE;
      v_mto_impuesto         ge_movimientos.monto%TYPE := 0;
      v_ref_txt              ge_par_entes.val_parametro%TYPE;
      v_ent_beneficiario     ge_par_entes.val_parametro%TYPE;
      v_ind_procesa          VARCHAR2(1) := 'N';
      v_existe               VARCHAR2(1);
      v_procesa_deb          VARCHAR2(1) := 'N';
      v_procesa_cre          VARCHAR2(1) := 'N';
      v_procesa              VARCHAR2(1) := 'N';
      v_denominacion         ge_cuentas.denominacion%TYPE;
      v_res_bloqueo          varchar2(4000);
      v_res_desbloqueo       varchar2(4000);
      v_cta_debito           ge_cuentas.nro_cuenta%type;
      v_mto_transitoria      ge_movimientos.monto%type;
      v_mto_debito           ge_movimientos.monto%type;
      v_usa_transitoria      varchar2(1) := 'N';
      v_exi_deuda            number;
      v_mto_deuda            ge_movimientos.monto%type;
      v_cta_wepa             varchar2(500);
      v_nro_cta              ge_cuentas.nro_cuenta%type;
      v_sal_cta_debito       ah_cta_vistas.sal_total%type;
      v_cod_en_cli_pago      ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('COD_ENT_PAG_CLI_COMERCIO'),0);
      v_usu_cle              ba_usuarios.cod_usuario%type := fug_obt_pardinamico('USU_CLE_WEPA');
      -- Se agregan variables para evitar que al verifiacar la operacion se modifique el campo de modulo y modalidad DA-10290
      v_cod_modulo_cred     ge_movimientos.cod_modulo%TYPE;
      v_cod_modalidad_cred  ge_movimientos.cod_modalidad%TYPE;
      v_cod_modulo_deb      ge_movimientos.cod_modulo%TYPE;
      v_cod_modalidad_deb   ge_movimientos.cod_modalidad%TYPE;
      CURSOR c_ordenes IS
         SELECT case
                when pae_uti.fu_obt_posicion(v_cod_en_cli_pago, cod_ente) > 0 then
                  1
                  else
                  2
                end nro_orden,
                fecha,
                nro_ref_externa,
                nro_cta_debito,
                beneficiario,
                tip_documento,
                nro_documento,
                nro_cta_credito,
                cod_moneda,
                cod_ent_externa,
                monto,
                nro_lote,
                nro_sec_lote,
                estado,
                observacion,
                for_pago,
                fec_pago,
                cod_ente,
                rowid id
           FROM ge_pag_com_clientes 
          WHERE estado IN ('C', 'R', 'P')
            AND trunc(fecha) <= v_fec_actual -- x si el pago se cargó el día anterior, igual debe procesar hoy
           -- AND cod_ente = p_cod_ente
            AND (cod_ente = p_cod_ente or p_cod_ente is null)
            AND nro_lote = p_nro_lote
            AND for_pago = 'C'
            AND observacion IS NULL -- SIN ERRORES
          ORDER BY 1;--nro_cta_debito;

   BEGIN
      p_error       :=  '00';
      p_msj_error   :=  NULL;
      DELETE FROM ge_pag_com_debitos_tmp;

      v_hora := pag_gen.fu_obt_sig_segundo(v_hora);

      FOR reg IN c_ordenes LOOP
        p_error       :=  '00';
        p_msj_error   :=  NULL;
        v_procesa_deb :=  'N';
        v_procesa_cre :=  'N';
        v_mto_deuda   :=0;
        v_usa_transitoria:='N';
        v_res_desbloqueo:=null;
        v_res_bloqueo:=null;
        v_exi_deuda:=0;
        v_sal_cta_debito:=0;
        v_cta_wepa:=null;
        v_mto_transitoria :=0;
        v_cta_debito:=null;
        v_nro_cta := reg.nro_cta_debito;
        --if v_nro_secuencia >= 998 then
        if v_nro_secuencia >= 996 then
          v_nro_secuencia := 1;
          v_hora          := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
        end if;

        v_cta_wepa :=  fug_obt_pardinamico('NRO_CTA_WEPA',null,null,reg.cod_moneda,null);

        pr_obt_dat_proveedor(reg.cod_ente/*p_cod_ente*/, v_descripcion, v_cod_tra_padre, v_ref_txt,
                             v_ent_beneficiario, v_cod_tas_com_cli, v_cod_tra_com_cli);

         v_mto_cargo    := 0;
         v_mto_impuesto := 0;

         -- busco los datos de la cta debito, sólo si tuviera
         IF reg.nro_cta_debito IS NOT NULL THEN

           BEGIN
              SELECT cod_modulo, cod_modalidad, cod_oficina, denominacion
                INTO v_cod_modulo_deb, v_cod_modalidad_deb, v_cod_oficina, v_denominacion
                FROM ge_cuentas
               WHERE nro_cuenta = reg.nro_cta_debito;
           EXCEPTION
              WHEN no_data_found THEN
                 v_cod_modulo_deb    := NULL;
                 v_cod_modalidad_deb := NULL;
                 v_cod_oficina   := NULL;
                 p_error         := '01';
                 p_msj_error     := 'Cta. de débito inexistente Nro ' || reg.nro_cta_debito;
              WHEN OTHERS THEN
                 v_cod_modulo_deb    := NULL;
                 v_cod_modalidad_deb := NULL;
                 v_cod_oficina   := NULL;
                 p_error         := '02';
                 p_msj_error     := 'Error Critico con Cta. de debito. ' || SQLERRM;
           END;

         END IF;

         -- Opcion de Pago Debito en Cuenta
         v_con_debito := substr('Débito en Cuenta: Empresa ' || v_denominacion, 1, 100);
         v_hor_bloqueo := pag_gen.fu_obt_sig_segundo(v_hora);
         IF v_cod_modalidad_deb IN (31, 41, 43) AND p_error = '00' THEN
         -- if reg.nro_cta_debito!=v_cta_wepa then -- si no es una cuenta de wepa realizo el desbloqueo
         --Si es una cuenta Wepa no realizo el desbloqueo
          if (instr(v_cta_wepa,','||reg.nro_cta_debito||',')) = 0 then
            v_res_desbloqueo := FUG_DES_BLO_CTA_CLEARING(p_nro_cuenta  => reg.nro_cta_debito,
                                                         p_tip_bloqueo => 'D',
                                                         p_estado      => 'N',
                                                         p_hora        => v_hor_bloqueo); --desbloquea cuenta debito
              if nvl(v_res_desbloqueo, 'X') != 'OK' then
                     p_error     := '10';
                     p_msj_error := v_res_desbloqueo;
                     pr_act_obs_mov(reg.nro_cta_debito,
                                reg.nro_lote,
                                reg.cod_moneda,
                                'D',
                                p_msj_error,
                                reg.id
                                );
              end if;
          end if;
          IF nvl(p_error,'00')='00' then
               -- verifico si la cuenta tiene deuda pendiente
               begin
                 select count(1)
                   into v_exi_deuda
                   from ge_deu_com_clientes c
                  where c.nro_cta_debito =  reg.nro_cta_debito
                    and estado != 'P';
               exception
                 when no_data_found then
                   v_exi_deuda       := 0;
               end;

              pag_cta.pr_ver_operacion(reg.nro_cta_debito, v_cod_tra_padre, v_cod_modulo_deb,
                                       v_cod_modalidad_deb, 'D', reg.cod_moneda, reg.monto,
                                       v_cod_oficina, v_cod_modulo_deb, v_cod_modalidad_deb, v_estado,
                                       v_sal_disponible, v_procesa_deb, 503);
              v_sal_cta_debito:=v_sal_disponible;
             IF v_procesa_deb = 'N' THEN

               if UPPER(pag_cta.fu_obt_msj_error) like '%SALDO%INSUFICIENTE%' then --si el error es saldo insuficiente
                 v_procesa_deb:='S';
               else
                 p_error      := '03';
                 p_msj_error  := 'Error con Cta Debito ' || reg.nro_cta_debito || '-' ||
                                  pag_cta.fu_obt_msj_error;
                 pr_act_obs_mov(reg.nro_cta_debito,
                                reg.nro_lote,
                                reg.cod_moneda,
                                'D',
                                p_msj_error,
                                reg.id
                                );
              end if;
             END IF;
           END IF;
         END IF;

         -- Opción de pago Crédito en Cuenta
         v_con_credito := substr('Crédito en Cuenta: Empresa ' || v_descripcion, 1, 100);

          --- busco los datos de la cta crédito, sólo si tuviera
         IF reg.nro_cta_credito IS NOT NULL THEN

            BEGIN
               SELECT cod_modulo, cod_modalidad, cod_oficina
                 INTO v_cod_modulo_cred, v_cod_modalidad_cred, v_cod_oficina_cre
                 FROM ge_cuentas
                WHERE nro_cuenta = reg.nro_cta_credito;
            EXCEPTION
               WHEN no_data_found THEN
                  v_cod_modulo_cred    := NULL;
                  v_cod_modalidad_cred := NULL;
                  v_cod_oficina_cre   := NULL;
                  p_error             := '04';
                  p_msj_error         := 'Cta. de crédito inexistente Nro ' || reg.nro_cta_credito;
               WHEN OTHERS THEN
                  v_cod_modulo_cred    := NULL;
                  v_cod_modalidad_cred := NULL;
                  v_cod_oficina_cre   := NULL;
                  p_error             := '05';
                  p_msj_error         := 'Error Critico con Cta. de crédito. ' || SQLERRM;
            END;

         END IF;

         -- verificamos la cuenta credito

         IF v_cod_modalidad_cred IN (31, 41, 43) AND p_error = '00' THEN


             pag_cta.pr_ver_operacion(reg.nro_cta_credito, v_cod_tra_padre, v_cod_modulo_cred,
                                      v_cod_modalidad_cred, 'C', reg.cod_moneda, reg.monto,
                                      v_cod_oficina_cre, v_cod_modulo_cred, v_cod_modalidad_cred, v_estado,
                                      v_sal_disponible, v_procesa_cre, 602);


             IF v_procesa_cre = 'N' THEN
                 p_error     := '06';
                 p_msj_error := 'Error con Cta Credito ' || reg.nro_cta_credito || '-' ||
                                pag_cta.fu_obt_msj_error;
                 pr_act_obs_mov(reg.nro_cta_credito,
                                 reg.nro_lote,
                                 reg.cod_moneda,
                                 'C',
                                 p_msj_error,
                                 reg.id
                                 );
             END IF;

         END IF;
         --------------------- SE REALIZA EL DEBITO Y EL CREDITO ------------------------

         IF ( v_procesa_deb = 'S' AND v_procesa_cre = 'S' ) THEN
           if nvl(fug_obt_pardinamico('NRO_CTA_TRANSITORIA',null,null,reg.cod_moneda,null), 'X') = 'X' then
              p_error     := '06';
              p_msj_error := 'El parametro "NRO_CTA_TRANSITORIA" en la moneda '||reg.cod_moneda||' no se encuentra configurada';
              pr_act_obs_mov(reg.nro_cta_debito,
                               reg.nro_lote,
                               reg.cod_moneda,
                               'D',
                               p_msj_error,
                               reg.id
                               );
           end if;

             pag_cta.pr_set_nro_documento3(nvl(reg.cod_ente, p_cod_ente));
        IF nvl(p_error, '00') = '00' THEN
            if nvl(v_sal_cta_debito, 0) >= nvl(reg.monto, 0) or
                  nvl(v_sal_cta_debito, 0) = 0 then
                 if nvl(v_sal_cta_debito, 0) >= nvl(reg.monto, 0) then
                   v_cta_debito     := reg.nro_cta_debito;

                 elsif nvl(v_sal_cta_debito, 0) = 0 then

                     v_cta_debito :=  fug_obt_pardinamico('NRO_CTA_TRANSITORIA',null,null,reg.cod_moneda,null);
                     v_mto_deuda:=reg.monto;

                 end if;

             /* debitar a la cuenta de débito */
             pag_cta.pr_act_operacion(v_cta_debito, v_hora,
                                      -- Hora
                                      'D', reg.cod_moneda, reg.monto, v_cod_tra_padre,
                                      -- COD_TRA_PADRE
                                      nvl(v_cod_tra_debito, 8916),
                                      -- COD_TRA_HIJO
                                      p_nro_lote, NULL,
                                      -- Cotizacion
                                      v_cod_oficina,
                                      -- cod_ofi_origen
                                      v_cod_modulo_deb,
                                      -- cod_mod_padre
                                      v_cod_modalidad_deb,
                                      -- cod_mad_padre
                                      NULL,
                                      -- cod_tasa
                                      NULL,
                                      -- val_tasa
                                      v_con_debito, 'S',
                                      -- emi_aviso
                                      v_nro_secuencia, v_fec_actual);

             IF pag_cta.fu_obt_cod_error() <> 0 THEN
                p_error     := '07';
                p_msj_error := 'Error al Tratar de Procesar Debito. Cta:  ' ||v_cta_debito||' - '||
                               pag_cta.fu_obt_msj_error;
                pr_act_obs_mov(reg.nro_cta_debito,
                               reg.nro_lote,
                               reg.cod_moneda,
                               'D',
                               p_msj_error,
                               reg.id
                               );
             END IF;

               ELSIF nvl(v_sal_cta_debito, 0) < nvl(reg.monto, 0) and
                     nvl(v_sal_cta_debito, 0) > 0 THEN

                   v_mto_debito := v_sal_cta_debito; --si se puede usar la cuenta transitoria se le debita todo el saldo disponible


                 if nvl(p_error, '00') = '00' then
                   /* debitar a la cuenta de débito */
                   pag_cta.pr_act_operacion(reg.nro_cta_debito,
                                            v_hora,
                                            -- Hora
                                            'D',
                                            reg.cod_moneda,
                                            v_mto_debito,
                                            v_cod_tra_padre,
                                            -- COD_TRA_PADRE
                                            nvl(v_cod_tra_debito, 503),
                                            -- COD_TRA_HIJO
                                            p_nro_lote,
                                            NULL,
                                            -- Cotizacion
                                            v_cod_oficina,
                                            -- cod_ofi_origen
                                            v_cod_modulo_deb,
                                            -- cod_mod_padre
                                            v_cod_modalidad_deb,
                                            -- cod_mad_padre
                                            NULL,
                                            -- cod_tasa
                                            NULL,
                                            -- val_tasa
                                            v_con_debito,
                                            'S',
                                            -- emi_aviso
                                            v_nro_secuencia,
                                            v_fec_actual);

                   IF pag_cta.fu_obt_cod_error() <> 0 THEN
                     p_error     := '09';
                     p_msj_error := 'Error al Tratar de Procesar Debito Cta: ' ||reg.nro_cta_debito||' - '||
                                    pag_cta.fu_obt_msj_error;
                     pr_act_obs_mov(reg.nro_cta_credito,
                              reg.nro_lote,
                              reg.cod_moneda,
                              'D',
                              p_msj_error,
                              reg.id
                              );
                   END IF;
                 END IF;

                 if nvl(p_error, '00') = '00' then
                   -- si se puede usar la transitoria se debita la diferencia
                   /* debitar a la cuenta transitoria la diferencia */
                   v_mto_transitoria := reg.monto - v_mto_debito;
                   v_mto_deuda:=v_mto_transitoria;
                   v_cta_debito      := fug_obt_pardinamico('NRO_CTA_TRANSITORIA',null,null,reg.cod_moneda,null);
                   pag_cta.pr_set_variables(v_usu_cle,
                           v_fec_actual,
                           v_cod_tra_padre,
                           'N',
                           'N',
                           v_nro_secuencia,
                           null,
                           fug_obt_ofi_usuario(v_usu_cle),
                           v_cod_modulo_deb,
                           v_cod_modalidad_deb);
                   pag_cta.pr_act_operacion(v_cta_debito,
                                            v_hora,
                                            -- Hora
                                            'D',
                                            reg.cod_moneda,
                                            v_mto_transitoria,
                                            v_cod_tra_padre,
                                            -- COD_TRA_PADRE
                                            nvl(v_cod_tra_debito, 503),
                                            -- COD_TRA_HIJO
                                            p_nro_lote,
                                            NULL,
                                            -- Cotizacion
                                            v_cod_oficina,
                                            -- cod_ofi_origen
                                            v_cod_modulo_deb,
                                            -- cod_mod_padre
                                            v_cod_modalidad_deb,
                                            -- cod_mad_padre
                                            NULL,
                                            -- cod_tasa
                                            NULL,
                                            -- val_tasa
                                            v_con_debito,
                                            'S',
                                            -- emi_aviso
                                            v_nro_secuencia,
                                            v_fec_actual);

                   IF pag_cta.fu_obt_cod_error() <> 0 THEN
                     p_error     := '09';
                     p_msj_error := 'Error al Tratar de Procesar Debito Cta: ' ||v_cta_debito||' - '
                                    ||pag_cta.fu_obt_msj_error;
                    pr_act_obs_mov(reg.nro_cta_credito,
                              reg.nro_lote,
                              reg.cod_moneda,
                              'D',
                              p_msj_error,
                              reg.id
                              );
                   END IF;
                 END IF;
               END IF;
             END IF;
               if nvl(p_error, '00') = '00' and nvl(v_mto_deuda,0)>0 then

                 insert into ge_deu_com_clientes
                   (fec_operacion,
                     nro_cta_debito,
                     beneficiario,
                     nro_lote,
                     tip_documento,
                     nro_documento,
                     cod_moneda,
                     mto_tot_pend,
                     estado,
                    cod_ente
                    )
                 values
                   (v_fec_actual,
                    reg.nro_cta_debito,
                    reg.beneficiario,
                    reg.nro_lote,
                    reg.tip_documento,
                    reg.nro_documento,
                    reg.cod_moneda,
                    v_mto_deuda,
                    'N',
                    reg.cod_ente);
               end if;

          -- CRÉDITO EN CUENTA
            pag_cta.pr_set_nro_documento3(nvl(reg.cod_ente, p_cod_ente));
            pag_cta.pr_set_variables(v_usu_cle,
                           v_fec_actual,
                           v_cod_tra_padre,
                           'N',
                           'N',
                           v_nro_secuencia,
                           null,
                           fug_obt_ofi_usuario(v_usu_cle),
                           v_cod_modulo_cred,
                           v_cod_modalidad_cred);


            /* acreditar la cuenta de crédito */
            pag_cta.pr_act_operacion(reg.nro_cta_credito, v_hora,
                                     -- Hora
                                     'C', reg.cod_moneda,
                                     -- Moneda de la Operación
                                     reg.monto, v_cod_tra_padre,
                                     -- COD_TRA_PADRE
                                     8917, --602,
                                     -- COD_TRA_HIJO
                                     --reg.cod_ente,
                                     reg.Nro_Lote,
                                     -- :PROV.NRO_RECIBO,
                                     NULL,
                                     -- Cotización
                                     v_cod_oficina_cre,
                                     -- cod_ofi_origen
                                     v_cod_modulo_cred,
                                     -- cod_mod_padre
                                     v_cod_modalidad_cred,
                                     -- cod_mad_padre
                                     NULL,
                                     -- cod_tasa
                                     NULL,
                                     -- val_tasa
                                     v_con_credito,
                                     -- Descripción
                                     'S',
                                     -- emi_aviso
                                     v_nro_secuencia, v_fec_actual);

            IF pag_cta.fu_obt_cod_error() <> 0 THEN
               p_error     := '08';
               p_msj_error := 'Error al Tratar de Procesar Debito ' || reg.nro_cta_credito || '-' ||
                              pag_cta.fu_obt_msj_error;
               pr_act_obs_mov(reg.nro_cta_credito,
                              reg.nro_lote,
                              reg.cod_moneda,
                              'C',
                              p_msj_error,
                              reg.id
                              );
            END IF;

         END IF;

          ---------------------------Cobro de comisión ---------------------------------
          -- calcula la comision en la moneda del credito.
          IF v_cod_tra_com_cli IS NOT NULL THEN
              prg_obt_cargos(v_cod_oficina, reg.nro_cta_debito, reg.cod_moneda, reg.monto,
                             v_cod_modulo_deb, v_cod_modalidad_deb, v_cod_tra_com_cli, v_cod_tas_com_cli,
                             v_val_tas_cargo, v_val_cargo, v_cod_tra_impuesto,
                             v_cod_tas_impuesto, v_val_tas_impuesto, v_val_impuesto);

              v_mto_cargo    := nvl(v_val_cargo, 0); --* i.cantidad;
              v_mto_impuesto := nvl(v_val_impuesto, 0); --* i.cantidad;
           END IF;

           IF v_mto_cargo > 0 THEN
              -- Se inserta registro por el cargo
              v_hora              := pag_gen.fu_obt_sig_segundo(v_hora);
              r_gmovi.cod_usuario := USER;
              r_gmovi.hora        := v_hora;
              r_gmovi.fecha       := v_fec_actual;
              -- Aumento la secuencia
              v_nro_secuencia       := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia := v_nro_secuencia;
              --
              r_gmovi.cod_modulo      := v_cod_modulo_deb;
              r_gmovi.cod_modalidad   := v_cod_modalidad_deb;
              r_gmovi.cod_oficina     := v_cod_oficina;
              r_gmovi.cod_moneda      := reg.cod_moneda;
              r_gmovi.fec_valor       := v_fec_actual;
              r_gmovi.cod_tra_padre   := v_cod_tra_padre;
              r_gmovi.cod_mod_padre   := 3;
              r_gmovi.cod_mad_padre   := 31;
              r_gmovi.cod_transaccion := v_cod_tra_com_cli; --1026;
              r_gmovi.monto           := v_mto_cargo;
              r_gmovi.nro_documento   := reg.nro_cta_debito;
              r_gmovi.cod_ofi_origen  := v_cod_oficina;
              r_gmovi.emi_aviso       := 'N';
              r_gmovi.concepto        := 'Cargo por Cobro de Servicios. ';
              r_gmovi.estado          := 'N';
              r_gmovi.reversado       := 'N';
              r_gmovi.cod_rubro       := NULL;
              r_gmovi.cod_tasa        := v_cod_tas_cargo;
              r_gmovi.val_tasa        := v_mto_cargo;
              r_gmovi.tip_mov_rubro   := NULL;
              r_gmovi.cod_persona     := NULL;
              r_gmovi.referencia      := reg.nro_cta_debito;
              pag_gen.pr_ins_ge_movimiento(r_gmovi);

              IF v_cod_tra_impuesto IS NOT NULL THEN
                 --Tiene impuesto asociado
                 --realizar el debito x el impuesto
                 r_gmovi.cod_usuario   := USER;
                 r_gmovi.hora          := v_hora;
                 r_gmovi.fecha         := v_fec_actual;
                 v_nro_secuencia       := v_nro_secuencia + 1;
                 r_gmovi.nro_secuencia := v_nro_secuencia;
                 --
                 r_gmovi.cod_modulo      := v_cod_modulo_deb;
                 r_gmovi.cod_modalidad   := v_cod_modalidad_deb;
                 r_gmovi.cod_oficina     := v_cod_oficina;
                 r_gmovi.cod_moneda      := reg.cod_moneda;
                 r_gmovi.fec_valor       := v_fec_actual;
                 r_gmovi.cod_tra_padre   := v_cod_tra_padre;
                 r_gmovi.cod_mod_padre   := 3;
                 r_gmovi.cod_mad_padre   := 31;
                 r_gmovi.cod_transaccion := v_cod_tra_impuesto;
                 r_gmovi.monto           := nvl(v_mto_impuesto, 0);
                 r_gmovi.nro_documento   := reg.nro_cta_debito;
                 r_gmovi.cod_ofi_origen  := v_cod_oficina;
                 r_gmovi.emi_aviso       := 'N';
                 r_gmovi.concepto        := 'Iva S/ Cargos. ';
                 r_gmovi.estado          := 'N';
                 r_gmovi.reversado       := 'N';
                 r_gmovi.cod_rubro       := NULL;
                 r_gmovi.cod_tasa        := v_cod_tas_impuesto;
                 r_gmovi.val_tasa        := v_val_tas_impuesto;
                 r_gmovi.tip_mov_rubro   := NULL;
                 r_gmovi.cod_persona     := NULL;
                 r_gmovi.referencia      := reg.nro_cta_debito;
                 pag_gen.pr_ins_ge_movimiento(r_gmovi);
              END IF;

              IF v_cod_modalidad_deb IN (31, 41) AND p_error = '00' THEN
                 pag_cta.pr_ver_operacion(reg.nro_cta_debito, v_cod_tra_padre, v_cod_modulo_deb,
                                          v_cod_modalidad_deb, 'D', reg.cod_moneda,
                                          (v_mto_cargo + v_mto_impuesto), v_cod_oficina,
                                          v_cod_modulo_deb, v_cod_modalidad_deb, v_estado,
                                          v_sal_disponible, v_procesa, 503);
                 IF v_procesa = 'N' THEN
                    p_error     := '07';
                    p_msj_error := 'Error con Cta Debito ' || reg.nro_cta_debito || '-' ||
                                   pag_cta.fu_obt_msj_error;
                 END IF;

                 IF v_procesa = 'S' THEN
                    -- Se inserta el débito a la cuenta.
                    pag_cta.pr_act_operacion(reg.nro_cta_debito, v_hora, 'D', reg.cod_moneda,
                                             --Moneda de la Operación
                                             (v_mto_cargo + v_mto_impuesto),
                                             --v_val_tas_cargo,
                                             v_cod_tra_padre, 503,
                                             -- Debito
                                             reg.nro_cta_debito, NULL,
                                             --COTIZACION
                                             v_cod_oficina,
                                             --cod_ofi_origen
                                             3,
                                             --cod_mod_padre
                                             31,
                                             --cod_mad_padre
                                             NULL,
                                             --cod_tasa
                                             v_val_tas_impuesto,
                                             --val_tasa
                                             'Cargo por Cobro de Servicios. ', 'S',
                                             --emi_aviso
                                             v_nro_secuencia, v_fec_actual);
                 END IF;
              END IF;
           END IF;

           if nvl(v_res_desbloqueo, 'X') = 'OK' then
                   -- vuelve a bloquear la cuenta debito
                --if reg.nro_cta_debito!=v_cta_wepa then -- si no es una cuenta de wepa realizo el desbloqueo
                --Si es una cuenta Wepa no realizo el bloqueo
                 if (instr(v_cta_wepa,','||reg.nro_cta_debito||',')) = 0 then
                   v_hor_bloqueo:= pag_gen.fu_obt_sig_segundo(v_hora);
                   v_res_bloqueo := FUG_DES_BLO_CTA_CLEARING(p_nro_cuenta  => reg.nro_cta_debito,
                                                             p_tip_bloqueo => 'B',
                                                             p_estado      => 'D',
                                                             p_hora        => v_hor_bloqueo);
                   if nvl(v_res_bloqueo, 'X') != 'OK' then
                     p_error     := '10';
                     p_msj_error := v_res_bloqueo;
                     pr_act_obs_mov(reg.nro_cta_credito,
                              reg.nro_lote,
                              reg.cod_moneda,
                              'D',
                              p_msj_error,
                              reg.id
                              );
                   end if;
                 end if;
               end if;

          --- Si no hubo errores actualiza tablas
          IF p_error = '00' THEN

             UPDATE ge_pag_com_clientes
                SET estado   = 'N',
                    fec_pago = v_fec_actual
              WHERE cod_ente = reg.cod_ente
                AND nro_sec_lote = reg.nro_sec_lote
                AND nro_cta_credito = reg.nro_cta_credito
                AND nro_lote = reg.nro_lote
                AND estado IN ('C', 'R');

             IF SQL%NOTFOUND THEN
                p_error     := '06';
                p_msj_error := 'Error al actualizar ge_pag_com_clientes. Ente-Lote: ' ||
                               reg.cod_ente || '-' || reg.nro_lote;
             END IF;
          END IF;
      END LOOP;

      --dejamos en 00 para que se pueda realizar el commit
      p_error     := '00';
      p_msj_error := NULL;
   EXCEPTION
      WHEN OTHERS THEN
         p_error := '99';
         raise_application_error(-20000, 'Error transf. cuenta: '||v_nro_cta||' - Sec: '||v_nro_secuencia||' - ' || p_msj_error || SQLERRM);
   END;

   PROCEDURE pr_cre_pag_com_sipap
   (
      p_cod_ente  IN NUMBER DEFAULT NULL,
      p_nro_lote  IN NUMBER,
      p_error     OUT VARCHAR2,
      p_msj_error OUT VARCHAR2
   ) IS
      v_cod_modulo       ge_movimientos.cod_modulo%TYPE;
      v_cod_modalidad    ge_movimientos.cod_modalidad%TYPE;
      v_estado           ge_cuentas.estado%TYPE;
      v_sal_disponible   ge_movimientos.monto%TYPE;
      v_procesa          VARCHAR2(1) := 'N';
      v_descripcion      ge_entes.descripcion%TYPE;
      v_cod_moneda       ba_monedas.cod_moneda%TYPE;
      v_fec_actual       ge_calendarios.fec_actual%TYPE := pag_cal.fu_obt_fec_actual(1);
      v_nro_secuencia    ge_movimientos.nro_secuencia%TYPE := 0;
      v_hora             ge_movimientos.hora%TYPE := fug_ini_hora(SYSDATE, 'HH24:MI:SS');
      v_cod_oficina      ge_movimientos.cod_oficina%TYPE;
      v_cod_tra_padre    ge_transacciones.cod_transaccion%TYPE;
      v_cod_tra_debito   ge_transacciones.cod_transaccion%TYPE;
      v_val_impuesto     ge_movimientos.val_tasa%TYPE;
      v_con_credito      ge_movimientos.concepto%TYPE; -- concepto movimiento crédito
      v_con_debito       ge_movimientos.concepto%TYPE; -- concepto movimiento débito
      v_cod_tra_credito  ge_transacciones.cod_transaccion%TYPE;
      v_tip_movimiento   ge_tip_asientos.tip_movimiento%TYPE;
      v_cod_usuario      VARCHAR2(30) := USER;
      v_mto_cargo        ge_movimientos.monto%TYPE;
      v_val_tas_cargo    ge_movimientos.val_tasa%TYPE;
      v_cod_tas_cargo    ge_movimientos.cod_tasa%TYPE;
      v_cod_tra_impuesto ge_movimientos.cod_transaccion%TYPE;
      v_nro_cta_bancaria cc_cta_bancarias.nro_cta_bancaria%TYPE;
      v_nro_cta_ban_sol  cc_cta_bancarias.nro_cta_bancaria%TYPE;
      v_cod_tas_com_cli  ge_par_entes.val_parametro%TYPE;
      v_cod_tra_com_cli  ge_par_entes.val_parametro%TYPE;
      v_mto_impuesto     ge_movimientos.monto%TYPE := 0;
      v_cod_tas_impuesto ge_movimientos.cod_tasa%TYPE;
      v_val_tas_impuesto ge_movimientos.val_tasa%TYPE;
      v_val_cargo        ge_movimientos.val_tasa%TYPE;
      v_nro_cuenta       ge_cuentas.nro_cuenta%TYPE;
      v_swift            ge_bancos.cod_swift%TYPE;
      v_ref_txt          ge_par_entes.val_parametro%TYPE;
      v_ent_beneficiario ge_par_entes.val_parametro%TYPE;
      r_gmovi            ge_movimientos%ROWTYPE;
      v_cta_debito       ge_cuentas.nro_cuenta%TYPE;
      v_est_transf       ge_snp_transferencias.estado%TYPE := NULL;
      v_nro_ref_snp      ge_snp_transferencias.nro_referencia%TYPE := NULL;
      v_err_trf          ge_snp_transferencias.error%TYPE := NULL;
      v_ind_procesa      VARCHAR2(1);
      v_existe           VARCHAR2(1);

      CURSOR c_ordenes IS
         SELECT fecha,
                nro_ref_externa,
                nro_cta_debito,
                beneficiario,
                tip_documento,
                nro_documento,
                nro_cta_credito,
                cod_moneda, --moneda del credito
                cod_ent_externa,
                monto,
                nro_lote,
                estado,
                observacion,
                for_pago,
                fec_pago,
                cod_ente,
                nro_sec_lote
           FROM ge_pag_com_clientes
          WHERE estado IN ('C', 'R', 'P')
            AND fecha <= v_fec_actual -- x si el pago se cargó el día anterior, igual debe procesar hoy
            --AND cod_ente = p_cod_ente
            AND (cod_ente = p_cod_ente or p_cod_ente is null)
            AND nro_lote = p_nro_lote
            AND for_pago = 'T'
            AND observacion IS NULL -- SIN ERRORES
          ORDER BY nro_cta_debito;

      PROCEDURE pr_ins_transferencia
      (
         p_hora                 IN VARCHAR2,
         p_fecha                IN DATE DEFAULT NULL,
         p_cod_usuario          IN VARCHAR2 DEFAULT NULL,
         p_plataforma           IN ge_snp_transferencias.plataforma%TYPE DEFAULT 'X', --X-Adapter
         p_ind_enviado          IN VARCHAR2 DEFAULT 'S',
         p_swi_pte_beneficiario IN VARCHAR2,
         p_beneficiario         IN VARCHAR2,
         p_tip_documento        IN VARCHAR2,
         p_nro_doc_beneficiario IN VARCHAR2,
         p_cta_beneficiario     IN VARCHAR2
      ) IS
         v_fecha           DATE := p_fecha;
         v_cod_usuario     VARCHAR2(30) := p_cod_usuario;
         v_cod_programa    VARCHAR2(50) := NULL;
         v_gen_workflow    VARCHAR2(1) := 'N';
         v_nro_referencia  ge_snp_transferencias.nro_referencia%TYPE := NULL;
         v_nro_ref_externa ge_snp_transferencias.nro_ref_externa%TYPE := NULL;
         v_msj_swift       VARCHAR2(4000);
      BEGIN

         pas_snp.pr_gen_mov_snp(p_hora => p_hora, p_fecha => v_fecha,
                                p_cod_usuario => v_cod_usuario, p_gen_workflow => v_gen_workflow,
                                p_origen => 'I', p_plataforma => p_plataforma,
                                p_nro_ref_externa => v_nro_ref_externa,
                                p_ind_enviado => p_ind_enviado, p_cod_programa => v_cod_programa,
                                p_nro_referencia => v_nro_referencia);
         UPDATE ge_snp_transferencias
            SET cod_swi_pte_beneficiario = p_swi_pte_beneficiario,
                cod_per_beneficiario     = '1',
                nom_beneficiario         = p_beneficiario,
                dir_beneficiario         = 'ESTRELLA Y 14 DE MAYO SN',
                cod_tip_doc_beneficiario = fue_obt_tip_documento(p_tip_documento),
                nro_doc_beneficiario     = p_nro_doc_beneficiario,
                nro_cta_beneficiario     = p_cta_beneficiario,
                tip_mensaje              = 'CRED',
                nro_cta_pte_solicitante  = v_nro_cta_bancaria,
                nro_cta_pte_beneficiario = v_nro_cta_ban_sol
          WHERE nro_referencia = v_nro_referencia;
         IF pas_snp.fu_obt_cod_error <> 0 THEN
            raise_application_error(-20000,
                                    'Error en proceso sipap. ' || pas_snp.fu_obt_cod_error || '-' ||
                                     pas_snp.fu_obt_msj_error);
         END IF;
         v_msj_swift := pas_snp.fu_obt_msj_mt103(v_nro_referencia, 'N');
         UPDATE ge_snp_transferencias
            SET msj_swift = v_msj_swift
          WHERE nro_referencia = v_nro_referencia;

         pas_snp.pr_gen_arc_swift(v_nro_referencia);
         v_nro_ref_snp := v_nro_referencia;
      END;
   BEGIN

    /*  pr_obt_dat_proveedor(p_cod_ente, v_descripcion, v_cod_tra_padre, v_ref_txt,
                           v_ent_beneficiario, v_cod_tas_com_cli, v_cod_tra_com_cli);*/
      DELETE FROM ge_pag_com_debitos_tmp;
      v_ind_procesa := 'N';
      p_error       := '00';
      FOR reg IN c_ordenes LOOP
         pr_obt_dat_proveedor(reg.cod_ente, v_descripcion, v_cod_tra_padre, v_ref_txt,
                           v_ent_beneficiario, v_cod_tas_com_cli, v_cod_tra_com_cli);
         v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
         pag_cta.pr_set_nro_documento3(p_cod_ente);
         pag_cta.pr_set_nro_documento2('103' || '001' || '002');
         if v_nro_secuencia >= 998 then
          v_nro_secuencia := 1;
          v_hora          := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
         end if;
         BEGIN
            SELECT nro_cuenta, nro_cta_bancaria
              INTO v_nro_cuenta, v_nro_cta_bancaria
              FROM cc_cta_bancarias
             WHERE cod_modalidad = 455
               AND cod_moneda = reg.cod_moneda
               AND estado = 'N';
         EXCEPTION
            WHEN no_data_found THEN
               p_error     := '01';
               p_msj_error := 'Cta. SIPAP no existe.';
            WHEN OTHERS THEN
               p_error     := '02';
               p_msj_error := 'Error al obtener cta. SIPAP.' || SQLERRM;
         END;
         v_cod_tra_credito := 196;
         v_cod_tra_padre   := 303; ---Transacción Padre de la Operación
         v_cod_tra_debito  := 503; -- Transacción Hijo de la Operación Débito
         v_tip_movimiento  := pas_snp.fu_obt_tip_mov_transaccion(4, 455, 196);
         ---se utiliza función para evaluar el estado a imputar en las operaciones
         v_estado := fug_obt_est_mov_confirmado(reg.monto, reg.cod_moneda, 4, 455, 303, 'X', NULL,
                                                NULL);
         BEGIN
            SELECT cod_modulo, cod_modalidad, cod_oficina, cod_moneda
              INTO v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_moneda
              FROM ge_cuentas
             WHERE nro_cuenta = reg.nro_cta_debito;
            v_cta_debito := reg.nro_cta_debito;
         EXCEPTION
            WHEN no_data_found THEN
               p_error     := '01';
               p_msj_error := 'Cta. de débito inexistente Nro ' || reg.nro_cta_debito;
            WHEN OTHERS THEN
               p_error     := '02';
               p_msj_error := 'Error Crítico con Cta. de débito. ' || SQLERRM;
         END;
         IF v_cod_modalidad IN (31, 41) AND p_error = '00' THEN
            pag_cta.pr_ver_operacion(reg.nro_cta_debito, v_cod_tra_padre, v_cod_modulo,
                                     v_cod_modalidad, 'D', v_cod_moneda, reg.monto, v_cod_oficina,
                                     v_cod_modulo, v_cod_modalidad, v_estado, v_sal_disponible,
                                     v_procesa, 503);
            IF v_procesa = 'N' THEN
               p_error     := '07';
               p_msj_error := 'Error con Cta Debito ' || reg.nro_cta_debito || '-' ||
                              pag_cta.fu_obt_msj_error;
            END IF;

            IF p_error = '00' THEN
               pag_cta.pr_set_nro_documento3(p_cod_ente);
               /* debitar a la cuenta de débito */
               pag_cta.pr_act_operacion(reg.nro_cta_debito, v_hora,
                                        -- Hora
                                        'D', v_cod_moneda, reg.monto, v_cod_tra_padre,
                                        -- COD_TRA_PADRE
                                        nvl(v_cod_tra_debito, 503),
                                        -- COD_TRA_HIJO
                                        reg.nro_lote,
                                        -- :PROV.NRO_RECIBO,
                                        NULL,
                                        -- Cotizacion
                                        v_cod_oficina,
                                        -- cod_ofi_origen
                                        4,
                                        -- cod_mod_padre
                                        455,
                                        -- cod_mad_padre
                                        NULL,
                                        -- cod_tasa
                                        NULL,
                                        -- val_tasa
                                        v_con_debito, 'S',
                                        -- emi_aviso
                                        v_nro_secuencia, v_fec_actual);
               v_ind_procesa := 'S'; -- solo si es que procesa
               IF pag_cta.fu_obt_cod_error() <> 0 THEN
                  p_error     := '09';
                  p_msj_error := 'Error al Tratar de Procesar Debito. ' || pag_cta.fu_obt_msj_error;
               END IF;
            END IF;
         END IF;
         IF v_ind_procesa = 'S' THEN
            /* acreditar la cuenta de crédito */
            pag_cta.pr_act_operacion(v_nro_cuenta, v_hora,
                                     -- Hora
                                     'C', reg.cod_moneda,
                                     -- Moneda de la Operación
                                     reg.monto, v_cod_tra_padre,
                                     -- COD_TRA_PADRE
                                     v_cod_tra_credito,
                                     -- COD_TRA_HIJO
                                     reg.nro_lote,
                                     -- :PROV.NRO_RECIBO,
                                     NULL,
                                     -- Cotización
                                     v_cod_oficina,
                                     -- cod_ofi_origen
                                     4,
                                     -- cod_mod_padre
                                     455,
                                     -- cod_mad_padre
                                     NULL,
                                     -- cod_tasa
                                     NULL,
                                     -- val_tasa
                                     v_con_credito,
                                     -- Descripción
                                     'S',
                                     -- emi_aviso
                                     v_nro_secuencia, v_fec_actual);
            IF pag_cta.fu_obt_cod_error() <> 0 THEN
               p_error     := '05';
               p_msj_error := 'Error con Cta Cred ' || reg.nro_cta_credito || '-' ||
                              pag_cta.fu_obt_msj_error;
            END IF;
            --- Si no hubo errores actualiza tablas
            IF p_error = '00' THEN
               -- Actualiza temporal para debitos.
               BEGIN
                  SELECT DISTINCT 'S'
                    INTO v_existe
                    FROM ge_pag_com_debitos_tmp
                   WHERE nro_cta_debito = reg.nro_cta_debito
                     AND cod_moneda = reg.cod_moneda
                     AND nro_lote = reg.nro_lote;

                  UPDATE ge_pag_com_debitos_tmp
                     SET mto_total = mto_total + reg.monto,
                         cantidad  = cantidad + 1
                   WHERE nro_cta_debito = reg.nro_cta_debito
                     AND cod_moneda = reg.cod_moneda
                     AND nro_lote = reg.nro_lote;

               EXCEPTION
                  WHEN no_data_found THEN
                     INSERT INTO ge_pag_com_debitos_tmp
                        (nro_cta_debito, cod_moneda, nro_lote, cantidad, mto_total)
                     VALUES
                        (reg.nro_cta_debito, reg.cod_moneda, reg.nro_lote, 1, reg.monto);
                  WHEN OTHERS THEN
                     NULL;
               END;
            END IF;
         END IF;
         BEGIN
            SELECT cod_swift INTO v_swift FROM ge_bancos WHERE cod_banco = reg.cod_ent_externa;
         EXCEPTION
            WHEN no_data_found THEN
               v_swift := NULL;
            WHEN OTHERS THEN
               v_swift := NULL;
         END;
         v_nro_cta_ban_sol := pas_snp.fu_obt_cta_ban_participante(v_swift, reg.cod_moneda);
         pr_ins_transferencia(p_hora => v_hora, p_fecha => v_fec_actual,
                              p_cod_usuario => v_cod_usuario, p_plataforma => NULL,
                              p_ind_enviado => 'S', p_swi_pte_beneficiario => v_swift,
                              p_beneficiario => reg.beneficiario,
                              p_tip_documento => reg.tip_documento,
                              p_nro_doc_beneficiario => reg.nro_documento,
                              p_cta_beneficiario => reg.nro_cta_credito);

         BEGIN
            SELECT estado, error
              INTO v_est_transf, v_err_trf
              FROM ge_snp_transferencias
             WHERE nro_referencia = v_nro_ref_snp;
         EXCEPTION
            WHEN no_data_found THEN
               p_error     := '09';
               p_msj_error := 'No se encuentra la transferencia. ';
            WHEN OTHERS THEN
               p_error     := '10';
               p_msj_error := 'Error Critico con transferencia sipap. ' || SQLERRM;
         END;
         IF v_est_transf = 'A' THEN
            UPDATE ge_pag_com_clientes
               SET estado   = 'N',
                   fec_pago = v_fec_actual
             WHERE cod_ente = reg.cod_ente
               AND nro_sec_lote = reg.nro_sec_lote
               AND nro_lote = reg.nro_lote
               AND estado IN ('C', 'R');
            v_ind_procesa := 'S';

            IF SQL%NOTFOUND THEN
               p_error     := '08';
               p_msj_error := 'Error al actualizar ge_pag_com_clientes. ';
            END IF;
         ELSIF v_est_transf = 'C' THEN

            UPDATE ge_pag_com_clientes
               SET estado   = 'P',
                   fec_pago = v_fec_actual
             WHERE cod_ente = reg.cod_ente
               AND nro_sec_lote = reg.nro_sec_lote
               AND nro_lote = reg.nro_lote
               AND estado IN ('C', 'R');
            v_ind_procesa := 'N';
            p_error       := '09';
            p_msj_error   := v_err_trf;
            IF SQL%NOTFOUND THEN
               p_error     := '10';
               p_msj_error := 'Error al actualizar ge_pag_com_clientes. ';
            END IF;
         END IF;

      END LOOP;
      IF v_ind_procesa = 'S' THEN
         DECLARE
            CURSOR deb IS
               SELECT nro_cta_debito, mto_total, cod_moneda, cantidad FROM ge_pag_com_debitos_tmp;
         BEGIN
            FOR i IN deb LOOP
               BEGIN
                  SELECT cod_modulo, cod_modalidad, cod_oficina
                    INTO v_cod_modulo, v_cod_modalidad, v_cod_oficina
                    FROM ge_cuentas
                   WHERE nro_cuenta = i.nro_cta_debito;
               EXCEPTION
                  WHEN no_data_found THEN
                     p_error     := '01';
                     p_msj_error := 'Cta. de débito inexistente Nro ' || i.nro_cta_debito;
                  WHEN OTHERS THEN
                     p_error     := '02';
                     p_msj_error := 'Error Critico con Cta. de debito. ' || SQLERRM;
               END;
               v_mto_cargo    := 0;
               v_mto_impuesto := 0;
               ---------------------------Cobro de comisión ---------------------------------
               -- calcula la comision en la moneda del credito.
               IF v_cod_modalidad IN (31, 41) AND p_error = '00' THEN
                  pag_cta.pr_ver_operacion(i.nro_cta_debito, v_cod_tra_padre, v_cod_modulo,
                                           v_cod_modalidad, 'D', i.cod_moneda, i.mto_total,
                                           v_cod_oficina, v_cod_modulo, v_cod_modalidad, v_estado,
                                           v_sal_disponible, v_procesa, 503);
                  IF v_procesa = 'N' THEN
                     p_error     := '07';
                     p_msj_error := 'Error con Cta Debito ' || i.nro_cta_debito || '-' ||
                                    pag_cta.fu_obt_msj_error;
                  END IF;

                  ---------------------------Cobro de comisión ---------------------------------
                  -- calcula la comision en la moneda del credito.
                  IF v_cod_tra_com_cli IS NOT NULL THEN
                     prg_obt_cargos(v_cod_oficina, i.nro_cta_debito, i.cod_moneda, i.mto_total,
                                    v_cod_modulo, v_cod_modalidad, v_cod_tra_com_cli,
                                    v_cod_tas_com_cli, v_val_tas_cargo, v_val_cargo,
                                    v_cod_tra_impuesto, v_cod_tas_impuesto, v_val_tas_impuesto,
                                    v_val_impuesto);

                     v_mto_cargo    := nvl(v_val_cargo, 0) * i.cantidad;
                     v_mto_impuesto := nvl(v_val_impuesto, 0) * i.cantidad;
                  END IF;
                  IF v_mto_cargo > 0 THEN
                     v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
                     -- Se inserta registro por el cargo
                     r_gmovi.cod_usuario := USER;
                     r_gmovi.hora        := v_hora;
                     r_gmovi.fecha       := v_fec_actual;
                     -- Aumento la secuencia
                     v_nro_secuencia       := v_nro_secuencia + 1;
                     r_gmovi.nro_secuencia := v_nro_secuencia;
                     --
                     r_gmovi.cod_modulo      := v_cod_modulo;
                     r_gmovi.cod_modalidad   := v_cod_modalidad;
                     r_gmovi.cod_oficina     := v_cod_oficina;
                     r_gmovi.cod_moneda      := i.cod_moneda;
                     r_gmovi.fec_valor       := v_fec_actual;
                     r_gmovi.cod_tra_padre   := v_cod_tra_padre;
                     r_gmovi.cod_mod_padre   := 3;
                     r_gmovi.cod_mad_padre   := 31;
                     r_gmovi.cod_transaccion := v_cod_tra_com_cli; --1026;
                     r_gmovi.monto           := v_mto_cargo;
                     r_gmovi.nro_documento   := i.nro_cta_debito;
                     r_gmovi.cod_ofi_origen  := v_cod_oficina;
                     r_gmovi.emi_aviso       := 'N';
                     r_gmovi.concepto        := 'Cargo por Cobro de Servicios. ';
                     r_gmovi.estado          := 'N';
                     r_gmovi.reversado       := 'N';
                     r_gmovi.cod_rubro       := NULL;
                     r_gmovi.cod_tasa        := v_cod_tas_cargo;
                     r_gmovi.val_tasa        := v_mto_cargo;
                     r_gmovi.tip_mov_rubro   := NULL;
                     r_gmovi.cod_persona     := NULL;
                     r_gmovi.referencia      := i.nro_cta_debito;
                     pag_gen.pr_ins_ge_movimiento(r_gmovi);

                     IF v_cod_tra_impuesto IS NOT NULL THEN
                        --Tiene impuesto asociado
                        --realizar el debito x el impuesto
                        r_gmovi.cod_usuario     := USER;
                        r_gmovi.hora            := v_hora;
                        r_gmovi.fecha           := v_fec_actual;
                        v_nro_secuencia         := v_nro_secuencia + 1;
                        r_gmovi.nro_secuencia   := v_nro_secuencia;
                        r_gmovi.cod_modulo      := v_cod_modulo;
                        r_gmovi.cod_modalidad   := v_cod_modalidad;
                        r_gmovi.cod_oficina     := v_cod_oficina;
                        r_gmovi.cod_moneda      := i.cod_moneda;
                        r_gmovi.fec_valor       := v_fec_actual;
                        r_gmovi.cod_tra_padre   := v_cod_tra_padre;
                        r_gmovi.cod_mod_padre   := 3;
                        r_gmovi.cod_mad_padre   := 31;
                        r_gmovi.cod_transaccion := v_cod_tra_impuesto;
                        r_gmovi.monto           := nvl(v_mto_impuesto, 0);
                        r_gmovi.nro_documento   := i.nro_cta_debito;
                        r_gmovi.cod_ofi_origen  := v_cod_oficina;
                        r_gmovi.emi_aviso       := 'N';
                        r_gmovi.concepto        := 'Iva S/ Cargos. ';
                        r_gmovi.estado          := 'N';
                        r_gmovi.reversado       := 'N';
                        r_gmovi.cod_rubro       := NULL;
                        r_gmovi.cod_tasa        := v_cod_tas_impuesto;
                        r_gmovi.val_tasa        := v_val_tas_impuesto;
                        r_gmovi.tip_mov_rubro   := NULL;
                        r_gmovi.cod_persona     := NULL;
                        r_gmovi.referencia      := i.nro_cta_debito;
                        pag_gen.pr_ins_ge_movimiento(r_gmovi);
                     END IF;
                     -- Se inserta el débito a la cuenta.
                     pag_cta.pr_act_operacion(i.nro_cta_debito, v_hora, 'D', i.cod_moneda,
                                              --Moneda de la Operación
                                              (v_mto_cargo + v_mto_impuesto),
                                              --v_val_tas_cargo,
                                              v_cod_tra_padre, 503,
                                              -- Debito
                                              i.nro_cta_debito, NULL,
                                              --COTIZACION
                                              v_cod_oficina,
                                              --cod_ofi_origen
                                              3,
                                              --cod_mod_padre
                                              31,
                                              --cod_mad_padre
                                              NULL,
                                              --cod_tasa
                                              v_val_tas_impuesto,
                                              --val_tasa
                                              'Cargo por Cobro de Servicios. ', 'S',
                                              --emi_aviso
                                              v_nro_secuencia, v_fec_actual);
                  END IF;
               END IF;
            END LOOP;
         END;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         p_error := '99';
         raise_application_error(-20000, 'Error transf. sipap. ' || p_msj_error || SQLERRM);
   END;
   PROCEDURE pr_cre_pag_com
   (
      p_cod_ente  IN NUMBER DEFAULT NULL,
      p_nro_lote  IN NUMBER,
      p_error     OUT VARCHAR2,
      p_msj_error OUT VARCHAR2
   ) IS
      v_err_cuentas     VARCHAR2(2);
      v_err_sipap       VARCHAR2(2);
      v_msj_err_sipap   VARCHAR2(4000);
      v_msj_err_cuentas VARCHAR2(4000);
   BEGIN
      pr_cre_pag_com_cuentas_cta(p_cod_ente, p_nro_lote, v_err_cuentas, v_msj_err_cuentas);
     -- pr_cre_pag_com_cuentas(p_cod_ente, p_nro_lote, v_err_cuentas, v_msj_err_cuentas);

      pr_cre_pag_com_sipap(p_cod_ente, p_nro_lote, v_err_sipap, v_msj_err_sipap);
      --v_err_sipap := '00';
      -- Veifica si terminó bien hace commit, sino hace rollback
      IF v_err_sipap = '00' AND v_err_cuentas = '00' OR
         (v_err_sipap IS NULL AND v_err_cuentas = '00') OR
         (v_err_sipap = '00' AND v_err_cuentas IS NULL) THEN
         p_error := '00';
         COMMIT;
      ELSE
         IF v_err_sipap IS NULL AND v_err_cuentas IS NULL THEN
            p_error     := '99';
            p_msj_error := 'No existen datos para procesar en la fecha.';
         ELSE
            IF v_err_sipap <> '00' THEN
               p_error := v_err_sipap;
            ELSIF v_err_cuentas <> '00' THEN
               p_error := v_err_cuentas;
            END IF;
            p_msj_error := v_msj_err_sipap || '-' || v_msj_err_cuentas;
            ROLLBACK;
         END IF;
      END IF;
      --Generamos el archivo de salida
      pr_gen_arc_pago(p_nro_lote);
   EXCEPTION
      WHEN OTHERS THEN
         p_error     := '99';
         p_msj_error := SQLERRM;
   END;

END;
/
