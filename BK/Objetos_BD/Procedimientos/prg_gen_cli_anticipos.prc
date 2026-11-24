CREATE OR REPLACE PROCEDURE IT.PRG_GEN_CLI_ANTICIPOS (p_fecha IN DATE,
                                                  --Parámetros de la Empresa
                                                  p_cod_empresa IN NUMBER,
                                                  --Parámetros del Cliente
                                                  p_cod_oficina       IN NUMBER,
                                                  p_cod_usu_oficial   IN VARCHAR2,
                                                  p_cod_departamento  IN NUMBER,
                                                  p_tip_extracto      IN VARCHAR2,
                                                  p_cod_moneda        IN VARCHAR2,
                                                  p_cod_modulo        IN ba_modulos.cod_modulo%TYPE,
                                                  p_cod_modalidad     IN ge_modalidades.cod_modalidad%TYPE,
                                                  p_cod_sub_modalidad IN ge_sub_modalidades.cod_sub_modalidad%TYPE,
                                                  p_alta              IN varchar2 default 'N',
                                                  p_tip_tdd           IN VARCHAR2 ) IS

   rg_par_cuentas        ge_seg_par_cuentas%ROWTYPE;
   v_cod_persona         ba_personas.cod_persona%TYPE;
   v_codigo              ba_personas.cod_persona%TYPE;
   v_est_civil           ba_per_fisicas.est_civil%TYPE;
   v_area                ba_telefonos.area%TYPE;
   v_tipo                ba_telefonos.tipo%TYPE;
   v_num_telefono        ba_telefonos.telefono%TYPE;
   v_cod_ciudad          ba_ciudades.cod_ciudad%TYPE;
   v_nro_cuenta          ge_cuentas.nro_cuenta%TYPE;
   v_nro_sec_movimiento  ge_movimientos.nro_secuencia%TYPE := 0;
   v_cod_ofi_origen      ge_movimientos.cod_ofi_origen%TYPE;
   v_emp_nro_cuenta      cc_cta_corrientes.nro_cuenta%TYPE;
   v_cod_seg_cliente     ge_clientes.cod_seg_cliente%TYPE := fug_obt_pardinamico('SEG_CLI_CTA_PLA_SUELDO');  
   v_cod_cargo           cr_tip_cargos.cod_tip_cargo%TYPE := 43;
   v_estado              cc_cta_corrientes.estado%TYPE := 'A'; -- Estado de la Cuenta Corriente y de Ahorro
   v_cod_moneda          cc_cta_corrientes.cod_moneda%TYPE;
   v_denominacion        cc_cta_corrientes.denominacion%TYPE;
   v_nom_chequera        cc_cta_corrientes.nom_chequera%TYPE;
   v_embozado            ah_tar_debitos.embozado%TYPE;
   v_fec_vencimiento     ah_tar_debitos.fec_vencimiento%TYPE;
   v_direccion           ba_direcciones.direccion%TYPE;
   v_obs_direccion       ba_direcciones.observacion%TYPE;
   v_cod_concepto        cr_con_ing_egr.cod_concepto%TYPE;
   v_anio                VARCHAR2(10);
   v_observacion         VARCHAR2(50) := 'PLAN SUELDO';
   v_cli_existe          VARCHAR2(1) := 'N';
   v_tas_existe          VARCHAR2(1) := 'N';
   v_ret_existe          VARCHAR2(1) := 'N';
   v_tra_existe          VARCHAR2(1) := 'N';
   v_cod_ofi_ahorro      NUMBER(5) := NULL;
   v_emp_cod_persona     ba_personas.cod_persona%TYPE;
   v_cod_dir_laboral     ba_direcciones.cod_direccion%TYPE;
   v_cod_tel_laboral     ba_telefonos.cod_telefono%TYPE;
   v_cod_tip_documento   ba_tip_documentos.cod_tip_documento%TYPE;
   v_nro_documento       ba_personas.nro_documento%TYPE;
   v_secuencia           NUMBER;
   existe                NUMBER;
   v_lugar               VARCHAR2(50);
   v_cod_pro_bancard     VARCHAR2(10) := fug_obt_pardinamico('COD_PRO_BANCARD', NULL, NULL, NULL, NULL);

   --Ajustes variables--
   v_nro_bin_procesadora ah_tar_debitos.nro_bin%TYPE := '';--inicializamos vacío para luego asignarle bin de visa o Infonet
   v_nro_bin_tdd_infonet ah_tar_debitos.nro_bin%TYPE := fug_obt_parentes(v_cod_pro_bancard, 'NRO_BIN_TDD_INFONET');--TDD NUEVO BIN
   v_nro_bin_tdd_visa    ah_tar_debitos.nro_bin%TYPE := fug_obt_parentes(v_cod_pro_bancard, 'NRO_BIN_TAR_DEBITO');-- TDD BIN VISA
   v_mto_ref_tdd_infonet ge_pag_sue_emp_tmp.sueldo%type := to_number(fug_obt_pardinamico('MTO_SUELDO_TDD_INFONET'));
   v_asi_tip_tdd_manual ge_par_dinamicos.val_parametro%type := NVL(fug_obt_parentes(p_cod_empresa, 'ASI_TIP_TDD_MANUAL'),'N');
   v_tip_tar_debito ah_tar_debitos.tip_tar_debito%type;
   --v_tip_tar_deb_nomina ah_tar_debitos.tip_tar_debito%type := 'I';--default NOMINA
   v_tip_tar_deb_nomina ah_tar_debitos.tip_tar_debito%type := fug_obt_pardinamico('TIP_TD_NOM_1'); --BSEVOCORE-1007
   v_tip_tar_deb_VISA ah_tar_debitos.tip_tar_debito%type := 'N';--default NOMINA
   v_exi_cta_nomina varchar2(5);

   --
   v_hab_tdd_mastercard varchar2(1) := fug_obt_pardinamico( 'HAB_TDD_MASTERCARD' );
   v_nro_bin_tdd_mastercard number  := fug_obt_parentes(fug_obt_pardinamico('COD_PRO_BANCARD'),'NRO_BIN_TDD_MASTERCARD');  -- Nro. BIN
   v_nro_bin_tdd_mastercard_black number  := fug_obt_parentes(fug_obt_pardinamico('COD_PRO_BANCARD'),'NRO_BIN_TDD_MASTERCARD_BLACK');-- BSEVOCORE-1029
   --

   v_fec_actual          cr_act_esperadas.fecha%TYPE := pag_cal.fu_obt_fec_actual(3);
   v_cod_mod_cuenta      ba_modulos.cod_modulo%TYPE;
   v_cod_mad_cuenta      ge_modalidades.cod_modalidad%TYPE;
   v_cod_sub_modalidad   ge_sub_modalidades.cod_sub_modalidad%TYPE;
   v_per_cal_lin_sobregiro number;
   v_cod_modulo          ge_cuentas.cod_modulo%type;
   v_men_fatca           varchar2(200);
   v_cod_pais            ba_paises.cod_pais%type;
   v_cod_profesion       ba_profesiones.cod_profesion%type;
   v_cod_sec_contable    ge_clientes.cod_sec_contable%type;
   v_cod_ente            ge_entes.cod_ente%type;
   v_por_lim_sueldo      number;
   v_mto_sob_sueldo      cc_lin_sobregiros.monto%type;
   v_mto_sueldo          cr_per_ing_egresos.importe%type;
   v_cta_anterior        ah_cta_vistas.nro_cuenta%TYPE := NULL;
   v_nro_lote            ge_pag_sue_emp.nro_lote%type;
   v_pri_nombre          ge_pag_sue_emp_tmp.pri_nombre%type;
   v_seg_nombre          ge_pag_sue_emp_tmp.seg_nombre%type;
   v_tip_extracto        ge_clientes.tip_extracto%type;
   v_loa                 cr_per_ing_egresos.importe%type;--- agregado via BSEVOCORE-971

   -- Obtiene los clientes temporales.
   CURSOR tem IS
      SELECT nro_cedula, tip_documento, pri_nombre, seg_nombre, pri_apellido, seg_apellido,
             ape_casada, fec_nacimiento, sexo, est_civil, direccion, ciudad,
             translate(telefono, '0123456789!"#$%&/()=?¡°|-.,;:{}[]¨*', '0123456789') telefono,
             sueldo, nvl(mto_ant_sueldo, 0) mto_ant_sueldo,
             nvl(mto_ant_aguinaldo, 0) mto_ant_aguinaldo, nro_cta_ahorro, fec_ingreso, tip_tarjeta,
             fec_vto_documento, nro_solicitud, gen_cuenta, a.dir_fiscal, a.cod_pai_fiscal, a.cod_pai_fatca,
             translate(celular, '0123456789!"#$%&/()=?¡°|-.,;:{}[]¨*', '0123456789') celular,
             mail, pais, profesion, nvl(cod_sec_contable,'N')cod_sec_contable, sobregiro, direc_kit, decode(tip_contrato,'T','T','I') tip_contrato,--DYDMR-7937
             nro_lote, doc_pais
        FROM ge_pag_sue_emp_tmp a
       WHERE cod_empresa = p_cod_empresa
         AND generar     = 'S';

   -- Obtiene los Parámetros de las Tasa y Tarifas.
   CURSOR cta_tas IS
      SELECT cod_tasa, valor
        FROM ge_seg_par_cta_tas
       WHERE cod_modulo        = p_cod_modulo
         AND cod_modalidad     = p_cod_modalidad
         AND cod_sub_modalidad = p_cod_sub_modalidad
         AND cod_seg_cliente   = v_cod_seg_cliente
         AND cod_moneda        = v_cod_moneda;

   -- Obtiene parámetros de Retenciones.
   CURSOR cta_ret IS
      SELECT cod_retencion, can_dia_retencion
        FROM ge_seg_par_cta_ret
       WHERE cod_modulo        = p_cod_modulo
         AND cod_modalidad     = p_cod_modalidad
         AND cod_sub_modalidad = p_cod_sub_modalidad
         AND cod_seg_cliente   = v_cod_seg_cliente
         AND cod_moneda        = v_cod_moneda;

   -- Obtiene parámetros de Transacciones Prohibidas.
   CURSOR cta_tra IS
      SELECT cod_transaccion, cod_mod_transaccion, cod_mad_transaccion
        FROM ge_seg_par_cta_tra
       WHERE cod_modulo        = p_cod_modulo
         AND cod_modalidad     = p_cod_modalidad
         AND cod_sub_modalidad = p_cod_sub_modalidad
         AND cod_seg_cliente   = v_cod_seg_cliente
         AND cod_moneda        = v_cod_moneda;

   -- Funcion que retorna si existe o no Cta. para el Ente
   FUNCTION lf_ver_cuenta
   (
      p_tip_documento VARCHAR2,
      p_nro_documento VARCHAR2,
      p_cod_modalidad ge_modalidades.cod_modalidad%TYPE
   ) RETURN VARCHAR2 IS
      v_existe VARCHAR2(1);
   BEGIN
      -- Ver si tiene cuenta cte. para el ente
      IF p_cod_modalidad = 41 THEN
         BEGIN
            SELECT 'S'
              INTO v_existe
              FROM cc_cta_corrientes c,
                   ge_cta_clientes   cl,
                   ba_personas       p
             WHERE p.cod_tip_documento = p_tip_documento
               AND p.nro_documento     = p_nro_documento
               AND cl.cod_persona      = p.cod_persona
               AND cl.relacion         = 'P'
               -- DYDMR-1758-ITGF-Inconvenientes con Vinculacion de Cuentas-SC14090-EGC20/05/2015 ('I')
               AND c.estado          not in('C','P','I')
               AND c.nro_cuenta        = cl.nro_cuenta
               AND c.cod_ente          = p_cod_empresa;
         EXCEPTION
            WHEN no_data_found THEN
               v_existe := 'N';
            WHEN TOO_MANY_ROWS THEN
               v_existe := 'S';
            WHEN OTHERS THEN
               v_existe := 'N';
               raise_application_error(-20001, 'Error al verificar ctas. ctes. Tipo= '||p_nro_documento||' '||SQLERRM);
         END;
      ELSE
         BEGIN
            SELECT 'S'
              INTO v_existe
              FROM ah_cta_vistas   c,
                   ge_cta_clientes cl,
                   ba_personas     p
             WHERE p.cod_tip_documento = p_tip_documento
               AND p.nro_documento     = p_nro_documento
               AND cl.cod_persona      = p.cod_persona
               AND cl.relacion         = 'P'
               -- DYDMR-1758-ITGF-Inconvenientes con Vinculacion de Cuentas-SC14090-EGC20/05/2015 ('I')
               AND c.estado          not in('C','P','I')
               AND c.nro_cuenta        = cl.nro_cuenta
               AND c.cod_ente          = p_cod_empresa;
         EXCEPTION
            WHEN no_data_found THEN
               v_existe := 'N';
            WHEN TOO_MANY_ROWS THEN
               v_existe := 'S';
            WHEN OTHERS THEN
               v_existe := 'N';
               raise_application_error(-20001, 'Error al verificar cuentas ahorro. Tipo= '||p_nro_documento||' '||SQLERRM);
         END;
      END IF;

      RETURN v_existe;

   END;

   --Cta. Ahorro Vista
   FUNCTION lf_obt_cta_aho_vista
   (
      p_persona        VARCHAR2,
      p_documento      VARCHAR2,
      p_llamado        VARCHAR2,
      p_denominacion   VARCHAR2,
      p_cod_modulo     VARCHAR2,
      p_cod_ofi_ahorro VARCHAR2,
      p_sueldo         NUMBER,
      p_nom_chequera   VARCHAR2,
      p_tip_contrato   cr_inf_laborales.tip_contrato%type
   ) RETURN VARCHAR2;

   --Cta. Cte.
   FUNCTION lf_obt_cta_corriente
   (
      p_persona        VARCHAR2,
      p_documento      VARCHAR2,
      p_llamado        VARCHAR2,
      p_denominacion   VARCHAR2,
      p_cod_modulo     VARCHAR2,
      p_cod_ofi_ahorro VARCHAR2,
      p_sueldo         NUMBER,
      p_nom_chequera   VARCHAR2,
      p_fec_ingreso    DATE DEFAULT pag_cal.fu_obt_fec_actual(4),
      p_tip_contrato   cr_inf_laborales.tip_contrato%type
   ) RETURN VARCHAR2;

   -- Busca si ya existe la persona o cliente
   FUNCTION lf_obt_personas
   (
      p_nro_documento     VARCHAR2,
      p_cod_tip_documento VARCHAR2,
      p_pri_nombre        VARCHAR2,
      p_pri_apellido      VARCHAR2,
      p_seg_nombre        VARCHAR2,
      p_seg_apellido      VARCHAR2,
      p_sexo              VARCHAR2,
      p_fec_nacimiento    DATE
   ) RETURN VARCHAR2 IS
      v_per_existe    VARCHAR2(1) := 'N';
      v_nro_documento ba_personas.nro_documento%TYPE;
   BEGIN
      -- Busca la personas en Gestión
      BEGIN
         SELECT cod_persona
           INTO v_codigo
           FROM ba_personas
          WHERE nro_documento     = p_nro_documento
            AND cod_tip_documento = p_cod_tip_documento;

         v_per_existe := 'S';
      EXCEPTION
         WHEN no_data_found THEN
            v_per_existe := 'N';
         WHEN OTHERS THEN
            raise_application_error(-20001, 'Error al buscar la persona. Docuemento Nro= '||p_nro_documento||' '||SQLERRM);
      END;

      IF v_per_existe = 'S' THEN
         -- Si el documento existe busca si el primer nombre y primer apellido son iguales con el ingresado.
         BEGIN
            SELECT 'S'
              INTO v_per_existe
              FROM ba_per_fisicas
             WHERE upper(ltrim(rtrim(pri_nombre)))   = upper(ltrim(rtrim(p_pri_nombre)))
               AND upper(ltrim(rtrim(pri_apellido))) = upper(ltrim(rtrim(p_pri_apellido)))
               AND cod_persona                       = v_codigo;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20002, 'Existe una persona con el Documento Nro= '||p_nro_documento);
            WHEN OTHERS THEN
               raise_application_error(-20003, 'Error al buscar la persona. Documento Nro= '||p_nro_documento||' '||SQLERRM);
         END;

         BEGIN
            SELECT DISTINCT 'S', tip_extracto
              INTO v_cli_existe, v_tip_extracto
              FROM ge_clientes
             WHERE cod_persona = v_codigo;
         EXCEPTION
            WHEN no_data_found THEN
               v_cli_existe := 'N';
            WHEN OTHERS THEN
               raise_application_error(-20004, 'Error al buscar el cliente. Documento Nro= '||p_nro_documento||' '||SQLERRM);
         END;

      ELSE

         BEGIN
            SELECT p.nro_documento
              INTO v_nro_documento
              FROM ba_personas    p,
                   ba_per_fisicas pf
             WHERE p.cod_persona                                = pf.cod_persona
               AND upper(ltrim(rtrim(pri_nombre)))              = upper(ltrim(rtrim(p_pri_nombre)))
               AND upper(ltrim(rtrim(pri_apellido)))            = upper(ltrim(rtrim(p_pri_apellido)))
               AND upper(ltrim(rtrim(nvl(seg_nombre, 'XX'))))   = upper(ltrim(rtrim(nvl(p_seg_nombre, 'XX'))))
               AND upper(ltrim(rtrim(nvl(seg_apellido, 'XX')))) = upper(ltrim(rtrim(nvl(p_seg_apellido, 'XX'))))
               AND nvl(fec_nacimiento, SYSDATE)                 = nvl(p_fec_nacimiento, SYSDATE)
               AND cod_sexo                                     = nvl(p_sexo, 'X')
               AND rownum                                       = 1;
         EXCEPTION
            WHEN no_data_found THEN
               v_per_existe := 'N';
            WHEN OTHERS THEN
               raise_application_error(-20005, 'Error al buscar Personas Parecidas. Documento Nro= '||p_nro_documento||' '||SQLERRM);
         END;

         IF v_nro_documento IS NOT NULL THEN
            raise_application_error(-20006, 'Existen personas parecidas para '||p_pri_nombre||' '||p_pri_apellido||' verifique en el sistema el Documento Nro= '||v_nro_documento||' '||SQLERRM);
         END IF;

      END IF;

      RETURN v_per_existe;

   END;

   -- Funcion que retorna el codigo de persona desde el documento
   FUNCTION lf_obt_cod_persona
   (
      p_nro_documento     VARCHAR2,
      p_cod_tip_documento VARCHAR2
   ) RETURN VARCHAR2 IS
      v_codigo ba_personas.cod_persona%TYPE;
   BEGIN
      -- Busca la persona
      BEGIN
         SELECT cod_persona
           INTO v_codigo
           FROM ba_personas
          WHERE nro_documento     = p_nro_documento
            AND cod_tip_documento = p_cod_tip_documento;
      EXCEPTION
         WHEN no_data_found THEN
            v_codigo := NULL;
         WHEN OTHERS THEN
            raise_application_error(-20001, 'Error al buscar la persona. Docuemento Nro= '||p_nro_documento||' '||SQLERRM);
      END;

      RETURN v_codigo;

   END;
   -- Recupera el nombre que puede ser almacenado dependiendo de la cantidad de caracteres permitidos
   FUNCTION lf_obt_nombre
   (
      p_pri_nombre   VARCHAR2,
      p_seg_nombre   VARCHAR2,
      p_pri_apellido VARCHAR2,
      p_seg_apellido VARCHAR2,
      p_tamano       NUMBER
   ) RETURN VARCHAR2 IS
      v_nombre VARCHAR2(120);
   BEGIN

      IF length(p_pri_nombre||' '||p_seg_nombre||' '||p_pri_apellido||' '||p_seg_apellido) > p_tamano THEN
         IF length(p_pri_nombre||' '||p_pri_apellido||' '||p_seg_apellido) > p_tamano THEN
            IF length(p_pri_nombre||' '||p_pri_apellido||' '||p_seg_apellido) > p_tamano THEN
               v_nombre := p_pri_nombre||' '||p_pri_apellido;
            ELSE
               v_nombre := TRIM(p_pri_nombre||' '||p_pri_apellido||' '||p_seg_apellido);
            END IF;
         ELSE
            v_nombre := TRIM(p_pri_nombre||' '||p_pri_apellido||' '||p_seg_apellido);
         END IF;
      ELSE
         v_nombre := TRIM(p_pri_nombre||' '||p_seg_nombre||' '||p_pri_apellido||' '||p_seg_apellido);
      END IF;

      RETURN v_nombre;
   END;
   --
   PROCEDURE lp_obt_dat_cuentas(p_nro_cuenta VARCHAR2,
                                p_cod_mod_cuenta ba_modulos.cod_modulo%type,
                                p_cod_mad_cuenta ge_modalidades.cod_modalidad%type) IS
   BEGIN
      IF p_cod_moneda IS NOT NULL THEN
         v_cod_moneda := p_cod_moneda;
      ELSE
         -- Obtiene datos de la Cuenta Corriente de la Empresa
         BEGIN
            SELECT cod_moneda
              INTO v_cod_moneda
              FROM cc_cta_corrientes
             WHERE nro_cuenta = p_nro_cuenta;
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20008, 'Error al buscar datos CC_CTA_CORRIENTES. Cta: '||p_nro_cuenta||'-'||SQLERRM);
         END;
      END IF;

      -- Obtiene parámetros de la Cuenta.
      BEGIN
         SELECT tip_extracto, tip_capitalizacion, cod_tasa, gen_tar_debito
           INTO rg_par_cuentas.tip_extracto, rg_par_cuentas.tip_capitalizacion,
                rg_par_cuentas.cod_tasa, rg_par_cuentas.gen_tar_debito
           FROM ge_seg_par_cuentas
          WHERE cod_modulo      = p_cod_mod_cuenta
            AND cod_modalidad   = p_cod_mad_cuenta
            AND cod_seg_cliente = v_cod_seg_cliente
            AND cod_moneda      = v_cod_moneda;
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20009, 'Error al buscar parámetros del Plan Sueldo. '||p_cod_modulo||'-'||p_cod_modalidad||'-'||SQLERRM);
      END;
   END;

   --
   FUNCTION lf_obt_cta_corriente
   (
      p_persona        VARCHAR2,
      p_documento      VARCHAR2,
      p_llamado        VARCHAR2,
      p_denominacion   VARCHAR2,
      p_cod_modulo     VARCHAR2,
      p_cod_ofi_ahorro VARCHAR2,
      p_sueldo         NUMBER,
      p_nom_chequera   VARCHAR2,
      p_fec_ingreso    DATE DEFAULT pag_cal.fu_obt_fec_actual(4),
      p_tip_contrato   cr_inf_laborales.tip_contrato%type
   ) RETURN VARCHAR2 IS
      v_inhibido          VARCHAR2(1);
      v_inhabilitado      VARCHAR2(1);
      v_err_infocheck     VARCHAR2(100);
      v_cod_ente          cc_cta_corrientes.cod_ente%TYPE;
      v_cuenta            ah_cta_vistas.nro_cuenta%TYPE := NULL;
      v_existe            VARCHAR2(1);
      v_emi_chequeras     varchar2(1) default 'N';
      v_mto_min_chequeras number;
      v_cod_tip_chequera  cc_tip_chequeras.cod_tip_chequera%type;
      v_can_cheques       cc_tip_chequeras.can_cheques%type;
      v_edad              number;
      v_exi_telegrama     VARCHAR2(1);
      v_cod_cau_desvinculacion varchar2(200) := fug_obt_pardinamico('SUE_CAU_TEL_DESVINCULACION');

   BEGIN

      v_inhibido := fug_ver_inhibicion(p_persona, 41);


      BEGIN
         v_err_infocheck := par_per.fu_obt_dat_infocheck(p_persona);
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20005, 'Error al generar datos de Infocheck. Documento Nro = '||p_documento||' '||v_err_infocheck);
      END;

       BEGIN
         SELECT g.sit_infocheck
           INTO v_inhabilitado
           FROM ge_cli_antecedentes g
          WHERE cod_persona = p_persona;
      EXCEPTION
         WHEN others THEN
            v_inhabilitado := null;
      END;

      BEGIN
        SELECT trunc(to_char(sysdate,'YYYY')) - to_char(t.fec_nacimiento,'YYYY')
          INTO v_edad
          FROM ba_per_fisicas t
         WHERE t.cod_persona = p_persona;
      EXCEPTION
        WHEN others THEN
          v_edad := 0;
      END;

      IF v_inhabilitado = '3' THEN

         IF p_llamado = 'F' THEN
            -- si es llamado desde la funcion LF_OBT_CTA_AHO_VISTA.
            UPDATE ge_pag_sue_emp_tmp
               SET error = 'Cliente inhabilitado para operar con CTA. AV. y CTA. CTE.'
             WHERE cod_empresa = p_cod_empresa
               AND nro_cedula  = p_documento;
            --PCCREPAN-3 Mejoras Pago de Nómina Fase 1
            insert into tm_log_sueldos
            (nro_cuenta, nro_documento, cod_ente, monto, lugar, observacion)
            values
            (v_cuenta, p_documento, p_cod_empresa, null, 'prg_gen_cli_anticipos - lf_obt_cta_corriente', 'Cuenta NO generada. Cliente inhabilitado para operar con CTA. AV. y CTA. CTE.');
         ELSE
               v_cuenta := lf_obt_cta_aho_vista(p_persona, p_documento, 'F', p_denominacion,
                                                p_cod_modulo, p_cod_ofi_ahorro, p_sueldo,
                                                p_nom_chequera, p_tip_contrato);
         END IF;

      ELSE
         IF v_inhibido = 'S' OR v_edad < fug_obt_pardinamico('ANO_MEN_EDAD') THEN

            IF p_llamado = 'F' THEN
               -- si es llamado desde la funcion LF_OBT_CTA_AHO_VISTA.
               UPDATE ge_pag_sue_emp_tmp
                  SET error = 'Cliente inhibido para operar con CTA. AV. y CTA. CTE.'
                WHERE cod_empresa = p_cod_empresa
                  AND nro_cedula  = p_documento;
               --PCCREPAN-3 Mejoras Pago de Nómina Fase 1
               insert into tm_log_sueldos
               (nro_cuenta, nro_documento, cod_ente, monto, lugar, observacion)
               values
               (v_cuenta, p_documento, p_cod_empresa, null, 'prg_gen_cli_anticipos - lf_obt_cta_corriente', 'Cuenta NO generada. Cliente inhibido para operar con CTA. AV. y CTA. CTE.');
            ELSE
                  v_cuenta := lf_obt_cta_aho_vista(p_persona, p_documento, 'F', p_denominacion,
                                                   p_cod_modulo, p_cod_ofi_ahorro, p_sueldo,
                                                   p_nom_chequera, p_tip_contrato);
            END IF;

         ELSE

            BEGIN
               SELECT cc.cod_ente, cc.nro_cuenta
                 INTO v_cod_ente, v_cta_anterior
                 FROM ge_cta_clientes   c,
                      cc_cta_corrientes cc,
                      ge_entes          e
                WHERE c.cod_persona = p_persona
                  AND c.relacion    = 'P'
                  AND cc.nro_cuenta = c.nro_cuenta
                  AND cc.cod_moneda = v_cod_moneda
                  -- DYDMR-1758-ITGF-Inconvenientes con Vinculacion de Cuentas-SC14090-EGC20/05/2015 ('I')
                  AND cc.estado     NOT IN ('C', 'P'/*, 'I'*/)--PCCREPAN-3 Mejoras Pago de Nómina Fase 1
                  AND e.cod_ente    = cc.cod_ente
                  AND e.cod_ente    <> p_cod_empresa
                  AND e.tipo        = 'SU'
                  AND ROWNUM        = 1;
            EXCEPTION
               WHEN no_data_found THEN
                  --PCCREPAN-3 Mejoras Pago de Nómina Fase 1
                  begin
                    SELECT cc.cod_ente, cc.nro_cuenta
                      INTO v_cod_ente, v_cta_anterior
                      FROM ge_cta_clientes   c,
                           cc_cta_corrientes cc,
                           ge_entes          e
                     WHERE c.cod_persona = p_persona
                       AND c.relacion    = 'P'
                       AND cc.nro_cuenta = c.nro_cuenta
                       AND cc.cod_moneda = v_cod_moneda
                       AND cc.estado     NOT IN ('C', 'P')
                       AND e.cod_ente    = cc.cod_ente
                       AND e.cod_ente    = p_cod_empresa
                       AND e.tipo        = 'SU'
                       AND ROWNUM        = 1;
                  exception
                    when no_data_found then
                        v_cod_ente := NULL;
                  end;
               WHEN OTHERS THEN
                  raise_application_error(-20005, 'Error al buscar la Cuenta Cte. con Ente. Documento Nro= '||p_documento||' '||SQLERRM);
            END;

          /*MEJORAS CONTROL DE CREACIÓN DE CUENTA: solo puede tener una cuenta con sub modalidad nóminas sea AH o CTACTE*/
            begin
               select CA.COD_ENTE
                     ,CA.NRO_CUENTA
                 into V_COD_ENTE
                     ,V_CTA_ANTERIOR
                 from GE_CTA_CLIENTES C
                     ,AH_CTA_VISTAS   CA
                     ,GE_ENTES        E
                where C.COD_PERSONA = P_PERSONA
                  and C.RELACION = 'P'
                  and CA.NRO_CUENTA = C.NRO_CUENTA
                  and CA.COD_MONEDA = V_COD_MONEDA
                     -- DYDMR-1758-ITGF-Inconvenientes con Vinculacion de Cuentas-SC14090-EGC20/05/2015 ('I')
                  and CA.ESTADO not in ('C', 'P' /*, 'I'*/) --PCCREPAN-3 Mejoras Pago de Nómina Fase 1
                  and E.COD_ENTE = CA.COD_ENTE
                  --and E.COD_ENTE <> P_COD_EMPRESA
                  AND ca.cod_sub_modalidad = 11--(sub modalidad nómina AHorro)
                  and E.TIPO = 'SU'
                  and ROWNUM = 1;
                  v_exi_cta_nomina := 'S';
            exception
               when NO_DATA_FOUND then
                   null;--para que no pise los controles anteriores
                   v_exi_cta_nomina := NULL;
               when others then
                  RAISE_APPLICATION_ERROR(-20005,
                                          'Error al buscar la Cuenta AV. con Ente. Documento Nro= ' ||
                                          P_DOCUMENTO || ' ' || sqlerrm);
            end;
          /* fin MEJORAS CONTROL DE CREACIÓN DE CUENTA: solo puede tener una cuenta con sub modalidad nóminas sea AH o CTACTE*/

            IF v_cod_ente IS NOT NULL THEN
               --PCCREPAN-3 Mejoras Pago de Nómina Fase 1
               IF v_cod_ente = p_cod_empresa then
                 insert into tm_log_sueldos
                 (nro_cuenta, nro_documento, cod_ente, monto, lugar, observacion)
                 values
                 (v_cta_anterior, p_documento, p_cod_empresa, null, 'prg_gen_cli_anticipos - lf_obt_cta_corriente', 'La persona ya posee cuenta para la Sub-modalidad y el ente.');
                 --DYDMR-3951 Se mejora el mensaje de error
                 UPDATE ge_pag_sue_emp_tmp
                    SET error = 'Cliente ya posee CTA CTE/AHORRO asignada a la Empresa'
                  WHERE cod_empresa = p_cod_empresa
                    AND nro_cedula  = p_documento;

               ELSE
                 UPDATE ge_pag_sue_emp_tmp
                    SET error = 'Cliente ya posee CTA CTE/AHORRO asignada a otra Empresa'
                  WHERE cod_empresa = p_cod_empresa
                    AND nro_cedula  = p_documento;

                 insert into tm_log_sueldos
                 (nro_cuenta, nro_documento, cod_ente, monto, lugar, observacion)
                 values
                 (v_cta_anterior, p_documento, p_cod_empresa, null, 'prg_gen_cli_anticipos - lf_obt_cta_corriente', 'Cuenta NO generada. Cliente ya posee CTA. CTE. vinculado a un ente en estado Inactiva, Normal, Abierta, Verificación o Bloqueo de Saldo, Cancelada o Pendiente de Cancelación.');
                 --
                 update cc_cta_corrientes cc
                    set cc.cod_ente = p_cod_empresa
                  where cc.nro_cuenta = v_cta_anterior;

                  IF NVL(v_exi_cta_nomina,'X') ='S' THEN
                    update AH_CTA_VISTAS cc
                    set cc.cod_ente = p_cod_empresa
                  where cc.nro_cuenta = v_cta_anterior;
                  END IF;

                 BEGIN
                  select 'S'
                    into v_exi_telegrama
                    from ge_telegramas
                   where ref_cuentas = v_cta_anterior
                     and instr(v_cod_cau_desvinculacion, to_char(cod_causa)) > 0;
                 EXCEPTION
                   WHEN TOO_MANY_ROWS THEN
                     v_exi_telegrama := 'S';
                   WHEN NO_DATA_FOUND THEN
                     v_exi_telegrama := 'N';
                 END;

                 IF v_exi_telegrama = 'S' THEN
                   update ge_telegramas g
                      set g.estado = 'N'
                    where g.ref_cuentas = v_cta_anterior;
                 END IF;
               END IF;
            ELSE
               BEGIN
                  SELECT cc.nro_cuenta
                    INTO v_cuenta
                    FROM ge_cta_clientes   c,
                         cc_cta_corrientes cc
                   WHERE c.cod_persona        = p_persona
                     AND c.relacion           = 'P'
                     AND cc.nro_cuenta        = c.nro_cuenta
                     AND cc.cod_moneda        = v_cod_moneda
                     -- DYDMR-1758-ITGF-Inconvenientes con Vinculacion de Cuentas-SC14090-EGC20/05/2015 ('I')
                     AND cc.estado            NOT IN ('C', 'P'/*, 'I'*/)--PCCREPAN-3 Mejoras Pago de Nómina Fase 1
                     AND cc.cod_sub_modalidad = p_cod_sub_modalidad;
               EXCEPTION
                  WHEN no_data_found THEN
                     v_cuenta := NULL;
                  WHEN OTHERS THEN
                     raise_application_error(-20005, 'Error al buscar la Cuenta Cte. para la Sub-Modalidad. Documento Nro= '||p_documento||' '||SQLERRM);
               END;



               IF v_cuenta IS NOT NULL THEN

                  if p_llamado = 'F' THEN
                     UPDATE ge_pag_sue_emp_tmp
                        SET error = 'Inhibido para CTA.AV y ya posee CTA.CTE. para la Sub-Mod.'
                      WHERE cod_empresa = p_cod_empresa
                        AND nro_cedula  = p_documento;
                     --PCCREPAN-3 Mejoras Pago de Nómina Fase 1
                    insert into tm_log_sueldos
                    (nro_cuenta, nro_documento, cod_ente, monto, lugar, observacion)
                    values
                    (v_cuenta, p_documento, p_cod_empresa, null, 'prg_gen_cli_anticipos - lf_obt_cta_corriente', 'Cuenta NO generada. Cliente Inhibido para CTA.AV. y ya posee CTA.CTE.');
                  elsif p_llamado = 'C' THEN
                    -- Actualiza Inf. Laboral y el ente a la cta. cte.
                    /* DYDMR-1758 - ITGF - Inconvenientes con Vinculacion de Cuentas - SC 14090.
                       Comentado para no realizar la vinculación al ente. Sólo guarda el mensaje para el usuario.*/
                    /*BEGIN
                      SELECT nvl(MAX(nro_secuencia),0) + 1
                        INTO v_secuencia
                        FROM cr_inf_laborales
                       WHERE cod_persona = v_cod_persona;
                    EXCEPTION
                      WHEN OTHERS THEN
                      v_secuencia := 1;
                    END;
                    Begin
                      update cr_inf_laborales
                         set mto_ingreso = p_sueldo,
                             fec_ingreso = p_fec_ingreso
                       where cod_persona = v_cod_persona
                         and lug_trabajo = fue_obt_nom_ente(p_cod_empresa);
                    If sql%notfound THEN
                      INSERT INTO cr_inf_laborales
                        (cod_persona, nro_secuencia, lug_trabajo, tip_cargo, tip_ingreso, actual,
                         cod_moneda, mto_ingreso, observacion, fec_ingreso, cod_ramo, tip_empleo,
                         cod_direccion, cod_telefono)
                       VALUES
                        (v_cod_persona, v_secuencia, fue_obt_nom_ente(p_cod_empresa), 43, 23, 'S',
                         p_cod_moneda, p_sueldo, 'PLAN SUELDO', p_fec_ingreso, 28, 'D',
                         v_cod_dir_laboral, v_cod_tel_laboral);
                    End If;
                    End;
                    -- Act. ente en la cuenta
                    Begin
                      Update cc_cta_corrientes
                         set cod_ente = p_cod_empresa
                       where nro_cuenta = v_cuenta;
                    Exception
                      when others then
                        UPDATE ge_pag_sue_emp_tmp
                           SET error = 'Cliente ya posee CTA. CTE. para la Sub-Modalidad. - No se pudo actualizar el Ente.'
                         WHERE cod_empresa = p_cod_empresa
                           AND nro_cedula  = p_documento;
                    end;*/
                    UPDATE ge_pag_sue_emp_tmp
                       SET error = 'Cliente ya posee CTA. CTE. para la Sub-Modalidad. Verifique.'
                     WHERE cod_empresa = p_cod_empresa
                       AND nro_cedula  = p_documento;
                    --PCCREPAN-3 Mejoras Pago de Nómina Fase 1
                    v_cod_mod_cuenta:= 4;
                    v_cod_mad_cuenta:= 41;

                    if p_cod_modulo = 3 then
                        v_cuenta := fug_obt_sig_nro_cuenta(v_cod_mod_cuenta, v_cod_mad_cuenta, p_cod_oficina,
                                                    v_cod_moneda, p_persona);
                        v_cod_sub_modalidad := fug_obt_pardinamico('COD_SUB_MOD_NOMINAS',v_cod_mod_cuenta,v_cod_mad_cuenta);
                    else
                        v_cuenta := fug_obt_sig_nro_cuenta(p_cod_modulo, p_cod_modalidad, p_cod_oficina,
                                                       v_cod_moneda, p_persona);
                        v_cod_sub_modalidad := p_cod_sub_modalidad;
                    end if;

                    lp_obt_dat_cuentas(v_emp_nro_cuenta,v_cod_mod_cuenta,v_cod_mad_cuenta);

                    BEGIN
                       v_lugar := '18-Insert CC_CTA_CORRIENTES';
                       INSERT INTO cc_cta_corrientes
                          (cod_modulo, cod_modalidad, cod_oficina, nro_cuenta, dig_verificador,
                           cod_moneda, denominacion, can_fir_requeridas, can_fir_registradas,
                           fec_apertura, ret_personalizada, tas_personalizada, sal_minimo,
                           aut_pendiente, acu_sobregiro, tra_prohibida, cta_combinada, estado,
                           nom_chequera, mto_apertura, fre_extracto, cod_ente,
                           reg_firma, cod_sub_modalidad)
                       VALUES
                          (v_cod_mod_cuenta, v_cod_mad_cuenta, p_cod_ofi_ahorro, v_cuenta, 0,
                           v_cod_moneda, p_denominacion, 1, 1,
                           p_fecha, 'N', 'N', 0,
                           'N', 'N', 'N', 'N', 'A',
                           v_nom_chequera, p_sueldo, rg_par_cuentas.tip_extracto, p_cod_empresa,
                           'INDIVIDUAL', v_cod_sub_modalidad);

                       if p_cod_modulo = 3 then
                         UPDATE ge_pag_sue_emp_tmp
                           SET error = 'Cliente inhibido para CTA AV. Se ha creado una CTA. CTE.'
                         WHERE cod_empresa = p_cod_empresa
                           AND nro_cedula  = p_documento;
                       end if;

                    EXCEPTION
                       WHEN OTHERS THEN
                          raise_application_error(-20030, 'Error al insertar datos en CC_CTA_CORRIENTES. Documento Nro= '||p_documento||' '||SQLERRM);
                    END;
                    --
                    insert into tm_log_sueldos
                    (nro_cuenta, nro_documento, cod_ente, monto, lugar, observacion)
                    values
                    (v_cuenta, p_documento, p_cod_empresa, null, 'prg_gen_cli_anticipos - lf_obt_cta_corriente',
                     'Cliente ya posee CTA. CTE. sin ente vinculado. Se ha creado una nueva cuenta vinculada al ente: '||p_cod_empresa||' Verifique.');
                  else
                      UPDATE ge_pag_sue_emp_tmp
                         SET error = 'Cliente ya posee CTA. CTE. para la Sub-Modalidad.'
                       WHERE cod_empresa = p_cod_empresa
                         AND nro_cedula  = p_documento;
                  end if;
                  --v_cuenta := NULL; --solo para crear tiene datos

               ELSE
                  v_cod_mod_cuenta:= 4;
                  v_cod_mad_cuenta:= 41;

                  if p_cod_modulo = 3 then
                      v_cuenta := fug_obt_sig_nro_cuenta(v_cod_mod_cuenta, v_cod_mad_cuenta, p_cod_oficina,
                                                  v_cod_moneda, p_persona);
                      v_cod_sub_modalidad := fug_obt_pardinamico('COD_SUB_MOD_NOMINAS',v_cod_mod_cuenta,v_cod_mad_cuenta);
                  else
                      v_cuenta := fug_obt_sig_nro_cuenta(p_cod_modulo, p_cod_modalidad, p_cod_oficina,
                                                     v_cod_moneda, p_persona);
                      v_cod_sub_modalidad := p_cod_sub_modalidad;
                  end if;

                  lp_obt_dat_cuentas(v_emp_nro_cuenta,v_cod_mod_cuenta,v_cod_mad_cuenta);

                  BEGIN
                     v_lugar := '18-Insert CC_CTA_CORRIENTES';
                     INSERT INTO cc_cta_corrientes
                        (cod_modulo, cod_modalidad, cod_oficina, nro_cuenta, dig_verificador,
                         cod_moneda, denominacion, can_fir_requeridas, can_fir_registradas,
                         fec_apertura, ret_personalizada, tas_personalizada, sal_minimo,
                         aut_pendiente, acu_sobregiro, tra_prohibida, cta_combinada, estado,
                         nom_chequera, mto_apertura, fre_extracto, cod_ente,
                         reg_firma, cod_sub_modalidad)
                     VALUES
                        (v_cod_mod_cuenta, v_cod_mad_cuenta, p_cod_ofi_ahorro, v_cuenta, 0,
                         v_cod_moneda, p_denominacion, 1, 1,
                         p_fecha, 'N', 'N', 0,
                         'N', 'N', 'N', 'N', 'A',
                         v_nom_chequera, p_sueldo, rg_par_cuentas.tip_extracto, p_cod_empresa,
                         'INDIVIDUAL', v_cod_sub_modalidad);

                     if p_cod_modulo = 3 then
                       UPDATE ge_pag_sue_emp_tmp
                         SET error = 'Cliente inhibido para CTA AV. Se ha creado una CTA. CTE.'
                       WHERE cod_empresa = p_cod_empresa
                         AND nro_cedula  = p_documento;
                     end if;

                  EXCEPTION
                     WHEN OTHERS THEN
                        raise_application_error(-20030, 'Error al insertar datos en CC_CTA_CORRIENTES. Documento Nro= '||p_documento||' '||SQLERRM);
                  END;
                  -- **veo si tiene cargada la informacion laboral
                   DECLARE
                      v_lug_trabajo VARCHAR2(100);
                      v_mto_ingreso cr_inf_laborales.mto_ingreso%type;
                      v_existe      VARCHAR2(1) DEFAULT 'N';
                   BEGIN
                      v_lugar := '114-LUG_TRABAJO';
                      SELECT descripcion
                        INTO v_lug_trabajo
                        FROM ge_entes
                       WHERE cod_ente = p_cod_empresa;
                         BEGIN
                           SELECT nvl(MAX(nro_secuencia),0) + 1
                             INTO v_secuencia
                             FROM cr_inf_laborales
                            WHERE cod_persona = v_cod_persona;
                         EXCEPTION
                           WHEN NO_DATA_FOUND THEN
                           v_secuencia := 1;
                           WHEN OTHERS THEN
                           v_secuencia := 1;
                         END;
                         BEGIN
                           SELECT 'S', mto_ingreso
                              INTO v_existe, v_mto_ingreso
                              FROM cr_inf_laborales
                             WHERE cod_persona = v_cod_persona
                               AND lug_trabajo = v_lug_trabajo;
                         EXCEPTION
                           WHEN NO_DATA_FOUND THEN
                             v_existe := 'N';
                           WHEN OTHERS THEN
                             v_existe := 'N';
                         END;
                            IF v_existe = 'N' THEN
                               INSERT INTO cr_inf_laborales
                                  (cod_persona, nro_secuencia, lug_trabajo, tip_cargo, tip_ingreso, actual,
                                   cod_moneda, mto_ingreso, observacion, fec_ingreso, cod_ramo, tip_empleo,
                                   cod_direccion, cod_telefono, tip_contrato)
                               VALUES
                                  (v_cod_persona, v_secuencia, v_lug_trabajo, 43, 23, 'S',
                                   p_cod_moneda, p_sueldo, 'PLAN SUELDO', p_fec_ingreso, 28, 'D',
                                   v_cod_dir_laboral, v_cod_tel_laboral, p_tip_contrato);
                            ELSIF v_mto_ingreso != p_sueldo THEN
                              UPDATE cr_inf_laborales
                                 SET mto_ingreso = p_sueldo
                               WHERE cod_persona = v_cod_persona
                                 AND lug_trabajo = v_lug_trabajo;
                            END IF;


                   EXCEPTION
                      WHEN OTHERS THEN
                         raise_application_error(-20000, 'Error al crear Informacion laboral. Persona '||fue_obt_nom_persona(v_cod_persona)||SQLERRM);
                   END;
                --- Actualizo la fecha de inicio de sobregiro para la cuenta. BBVADES 2576
                     update ge_cta_dat_adicionales
                        set val_parametro = to_char(p_fecha,'dd/mm/yyyy')
                      where parametro = 'SOB_FEC_INI_LINEA'
                        and nro_cuenta = v_cuenta;
                   IF SQL%NOTFOUND THEN
                       insert into ge_cta_dat_adicionales(nro_cuenta,parametro,val_parametro)
                            values(v_cuenta,'SOB_FEC_INI_LINEA',to_char(p_fecha,'dd/mm/yyyy'));
                   END IF;
                   /*GENERA CHEQUERA*/
                    v_emi_chequeras     := fug_obt_parentes(p_cod_empresa,'EMI_CHEQUERAS');
                    v_mto_min_chequeras := fug_obt_parentes(p_cod_empresa,'SAL_MIN_EMI_CHEQUERAS');
                    v_cod_tip_chequera  := fug_obt_pardinamico('COD_TIP_CHEQUERA',
                                                               v_cod_mod_cuenta,
                                                               v_cod_mad_cuenta,
                                                               v_cod_moneda,
                                                               p_cod_ofi_ahorro,
                                                               v_cod_sub_modalidad);
                    IF nvl(v_emi_chequeras,'N') = 'S' and
                      v_mto_min_chequeras <= p_sueldo and v_mto_min_chequeras is not null THEN
                      BEGIN
                        SELECT a.can_cheques
                          INTO v_can_cheques
                          FROM cc_tip_chequeras a
                         WHERE a.cod_tip_chequera = nvl(v_cod_tip_chequera,1);
                      END;
                      BEGIN
                        INSERT INTO cc_sol_chequeras
                        (nro_cuenta, fecha, hora, cod_usuario, cod_tip_chequera, cantidad, can_hojas, estado,
                         cod_ofi_retiro, observacion, tip_solicitud)
                        VALUES
                        (v_cuenta, p_fecha, to_char(SYSDATE,'HH24:MI:SS'), USER, v_cod_tip_chequera, 1, v_can_cheques, 'V',
                         p_cod_ofi_ahorro, null, 'N');
                      EXCEPTION
                        WHEN OTHERS THEN
                        raise_application_error(-20005, 'Error al Insertar Solicitudes de Chequera. Documento Nro= '||p_documento||' '||SQLERRM);
                      END;
                    END IF;
               END IF;
            END IF;
         END IF;
      END IF;

      RETURN v_cuenta;
   END;
   --
   FUNCTION lf_obt_tar_debito
   (
      p_cod_persona VARCHAR2,
      p_documento   VARCHAR2,
      p_nro_cuenta  VARCHAR2
   ) RETURN VARCHAR2 IS
      v_existe VARCHAR2(1) := 'N';
   BEGIN
      BEGIN
         SELECT DISTINCT 'S'
           INTO v_existe
           FROM ah_tar_debitos
          WHERE cod_persona       = p_cod_persona
            AND nro_cuenta        = p_nro_cuenta
            AND cod_est_solicitud NOT IN (1, 2, 16); -- Rechazada, Ingresada, Anulada
      EXCEPTION
         WHEN no_data_found THEN
            v_existe := 'N';
         WHEN OTHERS THEN
            raise_application_error(-20005, 'Error al buscar Tarjeta de Débito. Documento Nro= '||p_documento||' '||SQLERRM);
      END;

      RETURN v_existe;
   END;

   FUNCTION lf_obt_cta_aho_vista
   (
      p_persona        VARCHAR2,
      p_documento      VARCHAR2,
      p_llamado        VARCHAR2,
      p_denominacion   VARCHAR2,
      p_cod_modulo     VARCHAR2,
      p_cod_ofi_ahorro VARCHAR2,
      p_sueldo         NUMBER,
      p_nom_chequera   VARCHAR2,
      p_tip_contrato   cr_inf_laborales.tip_contrato%type
   ) RETURN VARCHAR2 IS
      v_cuenta            ah_cta_vistas.nro_cuenta%TYPE := NULL;
      v_cod_ente          ah_cta_vistas.cod_ente%TYPE;
      v_inhibido          VARCHAR2(1);
      v_existe            VARCHAR2(1);
   BEGIN

      v_inhibido := fug_ver_inhibicion(p_persona, 31);

      IF v_inhibido = 'S' THEN

         IF p_llamado = 'F' THEN
            -- si es llamado desde la funcion LF_OBT_CTA_CORRIENTE.
            UPDATE ge_pag_sue_emp_tmp
               SET error = 'Cliente inhibido para operar con CTA. CTE. y CTA. AV.'
             WHERE cod_empresa = p_cod_empresa
               AND nro_cedula  = p_documento;
            --PCCREPAN-3 Mejoras Pago de Nómina Fase 1
            insert into tm_log_sueldos
            (nro_cuenta, nro_documento, cod_ente, monto, lugar, observacion)
            values
            (v_cuenta, p_documento, p_cod_empresa, null, 'prg_gen_cli_anticipos - lf_obt_cta_aho_vista', 'Cuenta NO generada. Cliente inhibido para operar con CTA. CTE. y CTA. AV.');
         ELSE
               v_cuenta := lf_obt_cta_corriente(p_persona, p_documento, 'F', p_denominacion, p_cod_modulo,
                                                p_cod_ofi_ahorro, p_sueldo, p_nom_chequera,null, p_tip_contrato);
         END IF;
      ELSE
         BEGIN
            SELECT ca.cod_ente, ca.nro_cuenta
              INTO v_cod_ente, v_cta_anterior
              FROM ge_cta_clientes c,
                   ah_cta_vistas   ca,
                   ge_entes        e
             WHERE c.cod_persona = p_persona
               AND c.relacion    = 'P'
               AND ca.nro_cuenta = c.nro_cuenta
               AND ca.cod_moneda = v_cod_moneda
               -- DYDMR-1758-ITGF-Inconvenientes con Vinculacion de Cuentas-SC14090-EGC20/05/2015 ('I')
               AND ca.estado     NOT IN ('C', 'P'/*, 'I'*/)--PCCREPAN-3 Mejoras Pago de Nómina Fase 1
               AND e.cod_ente    = ca.cod_ente
               AND e.cod_ente    <> p_cod_empresa
               AND e.tipo        = 'SU'
               AND ROWNUM        = 1;
         EXCEPTION
            WHEN no_data_found THEN
              -- DYDMR-3951 validar que no existan cuentas asociadas al mismo ENTE (ALV - JUN/2016)
              BEGIN
                select av.cod_ente, av.nro_cuenta
                  into v_cod_ente, v_cta_anterior
                  from ge_cta_clientes c, ah_cta_vistas av, ge_entes e
                 where c.cod_persona = p_persona
                   and c.relacion = 'P'
                   and av.nro_cuenta = c.nro_cuenta
                   and av.cod_moneda = v_cod_moneda
                   and av.estado NOT IN ('C', 'P')
                   and e.cod_ente = av.cod_ente
                   and e.cod_ente = p_cod_empresa
                   and e.tipo = 'SU'
                   and rownum = 1;
              EXCEPTION
                when no_data_found then
                  v_cod_ente := NULL;
              END;
            WHEN OTHERS THEN
               raise_application_error(-20005, 'Error al buscar la Cuenta AV. con Ente. Documento Nro= '||p_documento||' '||SQLERRM);
         END;

         --MEJORA EN CONTROL DE CREACIÓN DE CUENTAS QUE LOS CLIENTES NO TENGAN YA CREADO OTRA CTA CON SUB MODALIDAD NÓMINA
         begin
            select CC.COD_ENTE
                  ,CC.NRO_CUENTA
              into V_COD_ENTE
                  ,V_CTA_ANTERIOR
              from GE_CTA_CLIENTES   C
                  ,CC_CTA_CORRIENTES CC
                  ,GE_ENTES          E
             where C.COD_PERSONA = P_PERSONA
               and C.RELACION = 'P'
               and CC.NRO_CUENTA = C.NRO_CUENTA
               and CC.COD_MONEDA = V_COD_MONEDA
                  -- DYDMR-1758-ITGF-Inconvenientes con Vinculacion de Cuentas-SC14090-EGC20/05/2015 ('I')
               and CC.ESTADO not in ('C', 'P' /*, 'I'*/) --PCCREPAN-3 Mejoras Pago de Nómina Fase 1
               and E.COD_ENTE = CC.COD_ENTE
               --and E.COD_ENTE <> P_COD_EMPRESA
               AND CC.COD_SUB_MODALIDAD = 9--sUB MODALIDAD NÓMINA cta cte
               and E.TIPO = 'SU'
               and ROWNUM = 1;
               v_exi_cta_nomina := 'S';
         exception
            when NO_DATA_FOUND then
                null;--para que no pise los controles anteriores
                v_exi_cta_nomina :=  NULL;
            when others then
               RAISE_APPLICATION_ERROR(-20005,
                                       'Error al buscar la Cuenta Cte. con Ente. Documento Nro= ' ||
                                       P_DOCUMENTO || ' ' || sqlerrm);
         end;
         --FIN MEJORA

         IF v_cod_ente IS NOT NULL THEN
            --DYDMR-3951 se agrega la insercion en el log
            if v_cod_ente = p_cod_empresa then

              insert into tm_log_sueldos
              (nro_cuenta, nro_documento, cod_ente, monto, lugar, observacion)
              values
              (v_cta_anterior, p_documento, p_cod_empresa, null, 'prg_gen_cli_anticipos - lf_obt_cta_aho_vista', 'La persona ya posee cuenta para la Sub-modalidad y el ente.');
              --se mejora el mensaje de error
              UPDATE ge_pag_sue_emp_tmp
                 SET error = 'Cliente ya posee CTA AV./CTACTE para el Ente seleccionado'
               WHERE cod_empresa = p_cod_empresa
                 AND nro_cedula  = p_documento;
            else
              UPDATE ge_pag_sue_emp_tmp
                 SET error = 'Cliente ya posee CTA AV./CTACTE para otro Ente'
               WHERE cod_empresa = p_cod_empresa
                 AND nro_cedula  = p_documento;
            --PCCREPAN-3 Mejoras Pago de Nómina Fase 1
              insert into tm_log_sueldos
              (nro_cuenta, nro_documento, cod_ente, monto, lugar, observacion)
              values
             (v_cta_anterior, p_documento, p_cod_empresa, null, 'prg_gen_cli_anticipos - lf_obt_cta_aho_vista', 'Cuenta NO generada. Cliente ya posee CTA.AV/CTACTE vinculado a un ente en estado Inactiva, Normal, Abierta, Verificación o Bloqueo de Saldo, Cancelada o Pendiente de Cancelación.');
              --
              update ah_cta_vistas aa
                 set aa.cod_ente = p_cod_empresa
               where aa.nro_cuenta = v_cta_anterior;

               IF NVL(v_exi_cta_nomina,'X') = 'S' THEN
                 update CC_CTA_CORRIENTES aa
                 set aa.cod_ente = p_cod_empresa
               where aa.nro_cuenta = v_cta_anterior;

               END IF;
            end if;
         ELSE
            BEGIN
               SELECT ca.nro_cuenta
                 INTO v_cuenta
                 FROM ge_cta_clientes c,
                      ah_cta_vistas   ca
                WHERE c.cod_persona        = p_persona
                  AND c.relacion           = 'P'
                  AND ca.nro_cuenta        = c.nro_cuenta
                  AND ca.cod_moneda        = v_cod_moneda
                  -- DYDMR-1758-ITGF-Inconvenientes con Vinculacion de Cuentas-SC14090-EGC20/05/2015 ('I')
                  AND ca.estado            NOT IN ('C', 'P'/*, 'I'*/)--PCCREPAN-3 Mejoras Pago de Nómina Fase 1
                  AND ca.cod_sub_modalidad = p_cod_sub_modalidad;
            EXCEPTION
               WHEN no_data_found THEN
                  v_cuenta := NULL;
               WHEN OTHERS THEN
                  raise_application_error(-20005, 'Error al buscar la Cuenta AV. Documento Nro= '||p_documento||' '||SQLERRM);
            END;

            IF v_cuenta IS NOT NULL THEN
              if p_llamado = 'F' THEN
                  UPDATE ge_pag_sue_emp_tmp
                    SET error = 'Inhibido para CTA.CTE. y ya posee CTA.AV para la Sub-Mod.'
                  WHERE cod_empresa = p_cod_empresa
                    AND nro_cedula  = p_documento;
                  --PCCREPAN-3 Mejoras Pago de Nómina Fase 1
                  insert into tm_log_sueldos
                  (nro_cuenta, nro_documento, cod_ente, monto, lugar, observacion)
                  values
                  (v_cuenta, p_documento, p_cod_empresa, null, 'prg_gen_cli_anticipos - lf_obt_cta_aho_vista', 'Cuenta NO generada. Cliente Inhibido para CTA.CTE. y ya posee CTA.AV.');
              else
                 UPDATE ge_pag_sue_emp_tmp
                    SET error = 'Cliente ya posee CTA.AV para la Sub-Modalidad.'
                  WHERE cod_empresa = p_cod_empresa
                    AND nro_cedula  = p_documento;
                 --PCCREPAN-3 Mejoras Pago de Nómina Fase 1
                 v_cod_mod_cuenta:= 3;
                 v_cod_mad_cuenta:= 31;

                 if p_cod_modulo = 4 then
                   v_cuenta := fug_obt_sig_nro_cuenta(v_cod_mod_cuenta, v_cod_mad_cuenta, p_cod_oficina,
                                                    v_cod_moneda, p_persona);
                   v_cod_sub_modalidad := fug_obt_pardinamico('COD_SUB_MOD_NOMINAS',v_cod_mod_cuenta,v_cod_mad_cuenta);
                 else
                   v_cuenta := fug_obt_sig_nro_cuenta(p_cod_modulo, p_cod_modalidad, p_cod_oficina,
                                                    v_cod_moneda, p_persona);
                   v_cod_sub_modalidad := p_cod_sub_modalidad;
                 end if;

                 lp_obt_dat_cuentas(v_emp_nro_cuenta,v_cod_mod_cuenta,v_cod_mad_cuenta);

                 BEGIN
                    INSERT INTO ah_cta_vistas
                       (cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
                        dig_verificador, cod_moneda, denominacion, fre_extracto, fec_apertura, ret_personalizada,
                        tas_personalizada, tip_capitalizacion, cod_tasa, aut_pendiente, tra_prohibida,
                        cta_combinada, estado, est_batch, cod_sub_modalidad, cod_ente, reg_firma, mto_apertura)
                    VALUES
                       (v_cod_mod_cuenta, v_cod_mad_cuenta, nvl(p_cod_ofi_ahorro, p_cod_oficina), v_cuenta,
                        0, v_cod_moneda, p_denominacion, rg_par_cuentas.tip_extracto, p_fecha, 'N',
                        'N', rg_par_cuentas.tip_capitalizacion, rg_par_cuentas.cod_tasa, 'N', 'N',
                        'N', 'A', 'A', v_cod_sub_modalidad, p_cod_empresa, 'INDIVIDUAL', p_sueldo);

                   if p_cod_modulo = 4 then
                       UPDATE ge_pag_sue_emp_tmp
                         SET error = 'Cliente inhibido para CTA CTE. Se ha creado una CTA. AV.'
                       WHERE cod_empresa = p_cod_empresa
                         AND nro_cedula  = p_documento;
                       --PCCREPAN-3 Mejoras Pago de Nómina Fase 1
                       insert into tm_log_sueldos
                       (nro_cuenta, nro_documento, cod_ente, monto, lugar, observacion)
                       values
                       (v_cuenta, p_documento, p_cod_empresa, null, 'prg_gen_cli_anticipos - lf_obt_cta_aho_vista', 'Cliente inhibido para CTA CTE. Se ha creado una CTA. AV.');
                   end if;
                 EXCEPTION
                    WHEN OTHERS THEN
                       raise_application_error(-20030, 'Error al insertar datos en AH_CTA_VISTAS. Documento Nro= '||p_documento||' '||SQLERRM);
                 END;
                 --PCCREPAN-3 Mejoras Pago de Nómina Fase 1
                 insert into tm_log_sueldos
                    (nro_cuenta, nro_documento, cod_ente, monto, lugar, observacion)
                    values
                    (v_cuenta, p_documento, p_cod_empresa, null, 'prg_gen_cli_anticipos - lf_obt_cta_aho_vista', 'Cliente ya posee CTA.AV sin ente vinculado. Se ha creado una nueva cuenta vinculada al ente: '||p_cod_empresa||' Verifique.');
              end if;
              v_cuenta := NULL; --solo para crear tiene datos
            ELSE

               v_cod_mod_cuenta:= 3;
               v_cod_mad_cuenta:= 31;

               if p_cod_modulo = 4 then
                 v_cuenta := fug_obt_sig_nro_cuenta(v_cod_mod_cuenta, v_cod_mad_cuenta, p_cod_oficina,
                                                  v_cod_moneda, p_persona);
                 v_cod_sub_modalidad := fug_obt_pardinamico('COD_SUB_MOD_NOMINAS',v_cod_mod_cuenta,v_cod_mad_cuenta);
               else
                 v_cuenta := fug_obt_sig_nro_cuenta(p_cod_modulo, p_cod_modalidad, p_cod_oficina,
                                                  v_cod_moneda, p_persona);
                 v_cod_sub_modalidad := p_cod_sub_modalidad;
               end if;

               lp_obt_dat_cuentas(v_emp_nro_cuenta,v_cod_mod_cuenta,v_cod_mad_cuenta);

               BEGIN
                  INSERT INTO ah_cta_vistas
                     (cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
                      dig_verificador, cod_moneda, denominacion, fre_extracto, fec_apertura, ret_personalizada,
                      tas_personalizada, tip_capitalizacion, cod_tasa, aut_pendiente, tra_prohibida,
                      cta_combinada, estado, est_batch, cod_sub_modalidad, cod_ente, reg_firma, mto_apertura)
                  VALUES
                     (v_cod_mod_cuenta, v_cod_mad_cuenta, nvl(p_cod_ofi_ahorro, p_cod_oficina), v_cuenta,
                      0, v_cod_moneda, p_denominacion, rg_par_cuentas.tip_extracto, p_fecha, 'N',
                      'N', rg_par_cuentas.tip_capitalizacion, rg_par_cuentas.cod_tasa, 'N', 'N',
                      'N', 'A', 'A', v_cod_sub_modalidad, p_cod_empresa, 'INDIVIDUAL', p_sueldo);

             if p_cod_modulo = 4 then
                 UPDATE ge_pag_sue_emp_tmp
                   SET error = 'Cliente inhibido para CTA CTE. Se ha creado una CTA. AV.'
                 WHERE cod_empresa = p_cod_empresa
                   AND nro_cedula  = p_documento;
                 --PCCREPAN-3 Mejoras Pago de Nómina Fase 1
                 insert into tm_log_sueldos
                 (nro_cuenta, nro_documento, cod_ente, monto, lugar, observacion)
                 values
                 (v_cuenta, p_documento, p_cod_empresa, null, 'prg_gen_cli_anticipos - lf_obt_cta_aho_vista', 'Cliente inhibido para CTA CTE. Se ha creado una CTA. AV.');
             end if;
               EXCEPTION
                  WHEN OTHERS THEN
                     raise_application_error(-20030, 'Error al insertar datos en AH_CTA_VISTAS. Documento Nro= '||p_documento||' '||SQLERRM);
               END;

            END IF;

         END IF;

      END IF;

      RETURN v_cuenta;
   END;

   -- INICIO PROCESO PRINCIPAL --
BEGIN
    BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;

   ----Proyecto: CLI_COM_ALIADOS - xpy0038 - 06/2014
   if nvl(p_alta,'N') = 'N' then
   v_emp_nro_cuenta := fug_obt_parentes(p_cod_empresa, 'NRO_CTA_DEBITO');

   lp_obt_dat_cuentas(v_emp_nro_cuenta, p_cod_modulo, p_cod_modalidad);
   end if;

   -- datos de la empresa
   BEGIN
      SELECT cod_persona
        INTO v_emp_cod_persona
        FROM ge_entes
       WHERE cod_ente = p_cod_empresa;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Error al obtener cÓdigo de persona de la empresa. '||SQLERRM);
   END;



   FOR t IN tem LOOP
      -- Inicializa variables
      v_codigo         := NULL;
      v_cli_existe     := 'N';
      v_ret_existe     := 'N';
      v_tra_existe     := 'N';
      v_tas_existe     := 'N';
      v_cod_ofi_ahorro := NULL;
      v_cta_anterior   := NULL;

      --ASIGNACIÓN DE BIN  (para procesos que no son nóminas)
      if v_hab_tdd_mastercard = 'S' then   --si esta habilitado ya, se da de alta Mastercard
        V_NRO_BIN_PROCESADORA := V_NRO_BIN_TDD_MASTERCARD;
        v_tip_tar_debito      :='M';
      else
        V_NRO_BIN_PROCESADORA := V_NRO_BIN_TDD_VISA;
        v_tip_tar_debito      :='N';
      end if;

      if (P_COD_MODULO = 3 AND P_COD_MODALIDAD = 31 AND  P_COD_SUB_MODALIDAD = 11) OR
         (P_COD_MODULO = 4 AND P_COD_MODALIDAD = 41 AND  P_COD_SUB_MODALIDAD = 9) then --SUBMODALIDAD NOMINAS  (CTA CTE / AHORROS)
          --asigna el nro de bin de TDD
          if (V_ASI_TIP_TDD_MANUAL = 'N' OR (V_ASI_TIP_TDD_MANUAL ='S' AND P_TIP_TDD IS NULL)) then
             --si no es seleccionado por el usuario (lo hace automático)

             --ASIGNA DE FORMA AUTOMÁTICA DE ACUERDO AL SUELDO DEL CLIENTE (<= 5.000.000)
             if pal_cam.FU_CON_MON_A_MONEDA(P_COD_MONEDA,'GS',T.SUELDO) <= V_MTO_REF_TDD_INFONET then

                --menor o igual a 5.000.000 GS
                V_NRO_BIN_PROCESADORA := V_NRO_BIN_TDD_INFONET;
                V_TIP_TAR_DEBITO := V_TIP_TAR_DEB_NOMINA;
             else
                --si ya esta habilitado Mastercard, se asigna MASTERCARD, sino, VISA
                IF v_hab_tdd_mastercard ='S' THEN
                  V_NRO_BIN_PROCESADORA := V_NRO_BIN_TDD_MASTERCARD;
                  V_TIP_TAR_DEBITO := 'M';
                ELSE
                  V_NRO_BIN_PROCESADORA := V_NRO_BIN_TDD_VISA;
                  V_TIP_TAR_DEBITO := V_TIP_TAR_DEB_VISA;
                END IF;
             end if;

          else
             --SI SELECCIÓN MANUAL DEL USUARIO
             if P_TIP_TDD = 'N' and v_hab_tdd_mastercard ='N' then
                --VISA
                V_NRO_BIN_PROCESADORA := V_NRO_BIN_TDD_VISA;
                V_TIP_TAR_DEBITO := V_TIP_TAR_DEB_VISA;
             elsif P_TIP_TDD = 'I' then
                --INFONET
                V_NRO_BIN_PROCESADORA := V_NRO_BIN_TDD_INFONET;
                V_TIP_TAR_DEBITO := V_TIP_TAR_DEB_NOMINA;
             elsif P_TIP_TDD = 'P' then
                --MASTERCARD BLACK
                V_NRO_BIN_PROCESADORA := V_NRO_BIN_TDD_MASTERCARD_BLACK;
                V_TIP_TAR_DEBITO := 'P';
             else
               --MASTERCARD
               V_NRO_BIN_PROCESADORA := V_NRO_BIN_TDD_MASTERCARD;
               V_TIP_TAR_DEBITO := 'M';
             end if;

          end if;
      end if;

      -- Obtiene el tipo de documento
      BEGIN
         SELECT cod_tip_documento
           INTO v_cod_tip_documento
           FROM ba_tip_documentos
          WHERE abreviatura = t.tip_documento;
         --and cod_tip_documento in (1,2,3,5); -- CI, PAS, CRP, CRC
      EXCEPTION
         WHEN no_data_found THEN
            raise_application_error(-20010, 'Tipo de documento no registrado. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
      END;
      ----Proyecto: CLI_COM_ALIADOS - xpy0038 - 06/2014
      v_cod_persona := lf_obt_cod_persona(t.nro_cedula, v_cod_tip_documento);

      IF nvl(t.gen_cuenta, 'N') = 'N' or (nvl(t.gen_cuenta, 'N')= 'S' and v_cod_persona is null) OR
         nvl(p_alta,'N') = 'S' THEN
         --Si es crear solo las cuentas no debe entrar a crear personas
         v_lugar := '1-Datos Persona';
         -- **DATOS PERSONAS** --
         IF lf_obt_personas(t.nro_cedula, v_cod_tip_documento, t.pri_nombre, t.pri_apellido,
                            t.seg_nombre, t.seg_apellido, t.sexo, t.fec_nacimiento) = 'N' THEN

            v_nro_documento := t.nro_cedula;

            -- ba_personas
            SELECT s_cod_persona.nextval
              INTO v_cod_persona
              FROM dual;

            if p_cod_empresa = '1060' then
               v_cod_pais := 1;
            else
              begin
                select a.cod_pais
                  into v_cod_pais
                  from ba_paises a
                 where a.descripcion = upper(t.pais);
              exception
                when no_data_found then
                  raise_application_error(-20000,'Error al buscar Pais. Documento Nro: '||t.nro_cedula||' '||sqlerrm);
              end;
            end if;

            BEGIN
               INSERT INTO ba_personas
                  (cod_persona,
                   nom_completo,
                   tipo, cod_tip_documento, nro_documento, cod_pais,
                   cod_actividad, est_verificacion,
                   obs_verificacion, fec_vto_documento,dir_correo)
               VALUES
                  (v_cod_persona,
                   t.pri_nombre||' '||t.seg_nombre||' '||t.pri_apellido||' '||t.seg_apellido,
                   'F', v_cod_tip_documento, t.nro_cedula, v_cod_pais/*1*/, 701, 'V',
                   'PLAN SUELDOS', t.fec_vto_documento, decode(paw_bel.lf_val_mail(t.mail),'S',t.mail,null));--se verifica que el mail sea el correcto, caso contrario no registra.
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20010, 'Error al insertar datos en BA_PERSONAS. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
            END;

            ---CROFATCA-132 - IDENTIFICACION DE CLIENTES PERSONAS JURIDICAS - FATCA : ITC-LCABRERA 05/2014
            if t.cod_pai_fatca is not null then
              BEGIN
                 INSERT INTO BA_PER_DAT_ADICIONALES (cod_persona  , parametro      , val_parametro          )
                                             VALUES (v_cod_persona, 'COD_PAI_SEG_NACIONALIDAD', t.cod_pai_fatca);
              EXCEPTION
                 WHEN OTHERS THEN
                    raise_application_error(-20010, 'Error al insertar datos en BA_PER_DAT_ADICIONALES. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
              END;
            end if;
            v_lugar := '2-Obtengo estado Civil';

            IF t.est_civil IS NOT NULL THEN
               -- ba_per_fisicas
               BEGIN
                  SELECT val_minimo
                    INTO v_est_civil
                    FROM ba_cod_referencias
                   WHERE dominio    = 'COD_EST_CIVIL'
                     AND val_minimo = t.est_civil;
               EXCEPTION
                  WHEN no_data_found THEN
                     raise_application_error(-20011, 'No existe estado civil definido. Documento Nro= '||t.nro_cedula);
                  WHEN OTHERS THEN
                     raise_application_error(-20012, 'Error al buscar el Estado Civil Documento. Nro= '||t.nro_cedula||' '||SQLERRM);
               END;
            ELSE
               v_est_civil := 'S';
            END IF;

            IF t.profesion IS NOT NULL THEN
               -- ba_per_fisicas
               BEGIN
                  SELECT cod_profesion
                    INTO v_cod_profesion
                    FROM ba_profesiones
                   WHERE ltrim(rtrim(upper(descripcion))) = upper(t.profesion);
               EXCEPTION
                  WHEN no_data_found THEN
                     raise_application_error(-20011, 'No existe Profesion definida. Documento Nro= '||t.nro_cedula);
                  WHEN OTHERS THEN
                     raise_application_error(-20012, 'Error al buscar la Profesion Documento. Nro= '||t.nro_cedula||' '||SQLERRM);
               END;
            END IF;

            BEGIN
               v_lugar := '3-Insert BA_PER_FISICAS';
               INSERT INTO ba_per_fisicas
                  (cod_persona, pri_nombre, pri_apellido, est_civil, cod_sexo, cod_pai_nacionalidad,
                   seg_nombre, seg_apellido, fec_nacimiento, cod_profesion)
               VALUES
                  (v_cod_persona, t.pri_nombre, t.pri_apellido, v_est_civil, t.sexo, v_cod_pais/*1*/,
                   t.seg_nombre, t.seg_apellido, t.fec_nacimiento, v_cod_profesion);
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20013, 'Error al insertar datos en BA_PER_FISICAS. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
            END;

            -- ba_direcciones
      ---CROFATCA-132 - IDENTIFICACION DE CLIENTES PERSONAS JURIDICAS - FATCA : ITC-LCABRERA 05/2014
            If t.direccion is null and t.dir_fiscal is not null Then
               raise_application_error(-20000, 'No puede importar una Persona con Dir. Fiscal y SIN Dir. Particular. Doc.Nro: '||t.nro_cedula||' '||SQLERRM);

            ElsIf t.direccion is not null Then
               IF t.ciudad IS NOT NULL THEN
                  -- Busca primero por nombre exacto
                  BEGIN
                     SELECT c.cod_ciudad
                       INTO v_cod_ciudad
                       FROM ba_ciudades c
                      WHERE translate(upper(c.descripcion), 'ÁÉÍÓÚ', 'AEIOU') = ltrim(rtrim(translate(t.ciudad, 'ÁÉÍÓÚ', 'AEIOU')))
                        AND c.cod_pais = v_cod_pais; -- DYDMR-3928 Se agrega la validación por país. (ALV - JUN/2016)
                  EXCEPTION
                     WHEN OTHERS THEN
                        NULL;
                  END;

                  -- Buscar por nombre similar
                  IF v_cod_ciudad IS NULL THEN
                     BEGIN
                        SELECT b.cod_ciudad
                          INTO v_cod_ciudad
                          FROM ba_ciudades b
                         WHERE translate(upper(b.descripcion), 'ÁÉÍÓÚ', 'AEIOU') LIKE
                               '%'||ltrim(rtrim(translate(t.ciudad, 'ÁÉÍÓÚ', 'AEIOU')))||'%'
                           and b.cod_pais = nvl(v_cod_pais, b.cod_pais) -- DYDMR-3928 Se agrega la validación por país. (ALV - JUN/2016)
                           and rownum = 1 ;
                     EXCEPTION
                        WHEN OTHERS THEN
                           raise_application_error(-20014, 'Error al buscar la ciudad '||t.ciudad||'. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
                     END;
                  END IF;

               ELSE
                  v_cod_ciudad := NULL;
               END IF;

               BEGIN
                  v_lugar         := '4-Direccion';
                  v_direccion     := substr(t.direccion, 1, 80);
                  v_obs_direccion := substr(t.direccion, 81);

                  INSERT INTO ba_direcciones
                     (cod_persona, cod_direccion, tipo, principal, direccion, cod_pais, cod_ciudad, observacion)
                  VALUES
                     (v_cod_persona, 1, 'P', 'S', v_direccion, v_cod_pais /*1*/, v_cod_ciudad, v_obs_direccion);

               EXCEPTION
                  WHEN OTHERS THEN
                     raise_application_error(-20015, 'Error al insertar datos en BA_DIRECCIONES. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
               END;

               v_cod_dir_laboral := 2;

            ELSE
               v_cod_dir_laboral := 1;
            END IF;

            -- direccion laboral
            BEGIN
               v_lugar := '5-Insert BA_DIRECCIONES';
               INSERT INTO ba_direcciones
                  (cod_persona, cod_direccion, tipo, principal, direccion, cod_pais, cod_ciudad)
                  SELECT v_cod_persona, v_cod_dir_laboral, tipo, 'N', direccion, cod_pais, cod_ciudad
                    FROM ba_direcciones
                   WHERE cod_persona = v_emp_cod_persona
                     AND tipo        = 'L'
                     AND rownum      = 1;

               IF SQL%ROWCOUNT = 0 THEN
                  -- no tiene direcion laboral
                  v_cod_dir_laboral := NULL;
               END IF;

               IF v_cod_dir_laboral = 1 THEN
                  UPDATE ba_direcciones
                     SET principal = 'S'
                   WHERE cod_persona   = v_cod_persona
                     AND cod_direccion = v_cod_dir_laboral;
               END IF;

            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20000, 'Error al insertar direccion laboral. Nro Documento= '||t.nro_cedula||' '||SQLERRM);
            END;

            ---CROFATCA-132 - IDENTIFICACION DE CLIENTES PERSONAS JURIDICAS - FATCA : ITC-LCABRERA 05/2014
            If t.dir_fiscal is not null and t.cod_pai_fiscal is not null then
                 Begin
                      -- Insertar datos en la tabla
                      INSERT INTO ba_direcciones (cod_persona  , cod_direccion, tipo, principal, direccion    , cod_pais        )
                                          values (v_cod_persona,  NULL        , 'F' , 'N'      ,  t.dir_fiscal, t.cod_pai_fiscal);
                 EXCEPTION
                      WHEN OTHERS THEN
                        raise_application_error(-20010, 'Error al insertar la dirección fiscal. Documento Nro= ' || t.nro_cedula || ' ' || SQLERRM);
                 END;
            End If;
            -- direccion de envios
            INSERT INTO ge_dir_envios
               (cod_persona, tip_envio, referencia, nro_cuenta, observacion)
            VALUES
               (v_cod_persona, 'D', 1, NULL, NULL);

            -- ba_telefonos
            IF t.telefono IS NOT NULL THEN

               v_lugar := '6-Telefono';
               IF t.telefono LIKE '09%' THEN
                  v_area         := substr(t.telefono, 1, 4);
                  v_tipo         := 'C';
                  v_num_telefono := substr(substr(t.telefono, 5), 1, 10);
               ELSE
                  v_area         := NULL;
                  v_tipo         := 'B';
                  v_num_telefono := substr(t.telefono, 1, 10);
               END IF;

               BEGIN
                  v_lugar := '7-Insert BA_TELEFONOS';
                  INSERT INTO ba_telefonos
                     (cod_persona, tipo, tip_linea, telefono, principal, area, cod_telefono)
                  VALUES
                     (v_cod_persona, 'P', v_tipo, v_num_telefono, 'S', v_area, 1);
               EXCEPTION
                  WHEN OTHERS THEN
                     raise_application_error(-20016, 'Error al insertar datos en BA_TELEFONOS. Nro Documento= '||t.nro_cedula||' '||SQLERRM);
               END;

               v_cod_tel_laboral := 2;
            ELSE
               v_cod_tel_laboral := 1;
            END IF;
            if t.celular is not null then
               v_lugar := 'Celular';
               v_area         := substr(t.celular, 1, 4);
               v_tipo         := 'C';
               v_num_telefono := substr(substr(t.celular, 5), 1, 10);

               BEGIN
                  v_lugar := '7-Insert BA_TELEFONOS';
                  INSERT INTO ba_telefonos
                     (cod_persona, tipo, tip_linea, telefono, principal, area, cod_telefono)
                  VALUES
                     (v_cod_persona, 'P', v_tipo, v_num_telefono, 'N', v_area, v_cod_tel_laboral);
               EXCEPTION
                  WHEN OTHERS THEN
                     raise_application_error(-20016, 'Error al insertar datos en BA_TELEFONOS. Nro Documento= '||t.nro_cedula||' '||SQLERRM);
               END;
               v_cod_tel_laboral := 3;
            else
               v_cod_tel_laboral := 2;
            end if;

            -- telefono laboral
            BEGIN

               v_lugar := '8-Insert BA_TELEFONOS';
               INSERT INTO ba_telefonos
                  (cod_persona, tipo, tip_linea, telefono, principal, area, cod_telefono)
                  SELECT v_cod_persona, tipo, tip_linea, telefono, 'N', area, v_cod_tel_laboral
                    FROM ba_telefonos
                   WHERE cod_persona = v_emp_cod_persona
                     AND tipo        = 'L'
                     AND rownum      = 1
                     AND tip_linea = 'B';

               IF SQL%ROWCOUNT = 0 THEN
                  -- no tiene telefono laboral
                  v_cod_tel_laboral := NULL;
               END IF;

               IF v_cod_tel_laboral = 1 THEN
                  UPDATE ba_telefonos
                     SET principal = 'S'
                   WHERE cod_persona  = v_cod_persona
                     AND cod_telefono = v_cod_tel_laboral;
               END IF;

            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20000, 'Error al insertar telefono laboral. Nro Documento= '||t.nro_cedula||' '||SQLERRM);
            END;

            if t.mail is not null then
               v_lugar := 'Email';
               begin
                 insert into ba_mails
                    (cod_persona, tipo, dir_correo, principal)
                 values
                    (v_cod_persona, 'L', t.mail, 'S');
               exception
                  when others then
                     raise_application_error(-20016, 'Error al insertar datos en BA_MAILS. Nro Documento= '||t.nro_cedula||' '||SQLERRM);
               end;
            end if;
            ----Proyecto: CLI_COM_ALIADOS - xpy0038 - 06/2014
            IF nvl(p_alta,'N') = 'N' THEN
            BEGIN
               -- Perfil de cliente - Origen de fondos - Proposito de la cuenta
               v_lugar := '9-Insert CR_INF_FONDOS';
               INSERT INTO cr_inf_fondos
                  (cod_persona, fon_salario, pro_ingresos)
               VALUES
                  (v_cod_persona, 'S', 'S');

               -- Perfil de cliente - Actividades esperadas
               v_lugar := '10-Insert CR_ACT_ESPERADAS';
               v_loa := (t.sueldo*2);
               INSERT INTO cr_act_esperadas
                  (cod_persona, fecha, cod_moneda, can_tra_debito, can_tra_credito, mto_pro_debito, mto_pro_credito)
               VALUES
                  (v_cod_persona, v_fec_actual, 'GS', 20, 20, v_loa, v_loa);

               -- Perfil de cliente - Tipo de operaciones
               v_lugar := '11-Insert CR_PER_TIP_OPERACIONES';
               INSERT INTO cr_per_tip_operaciones
                  (cod_persona, cod_modulo, cod_modalidad)
               VALUES
                  (v_cod_persona, 4, 41);

            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20000, 'Error al insertar perfil de cliente. Nro Documento= '||t.nro_cedula||' '||SQLERRM);
            END;
            END IF;
         ELSE
            -- Si la persona existe carga la variable
            v_cod_persona := v_codigo;
         END IF;
         ----Proyecto: CLI_COM_ALIADOS - xpy0038 - 06/2014
         IF nvl(p_alta,'N') = 'S' then
            -- MDPCLACLI-3
            BEGIN
              select a.cod_ente
                INTO v_cod_ente
                from ge_entes a
               where a.descripcion like '%PRE-EMBOZADAS%';
            EXCEPTION
               WHEN no_data_found THEN
                  v_cod_ente := 0;
            END;
            IF p_cod_empresa <> v_cod_ente THEN
               BEGIN
                  INSERT INTO ge_com_aliados
                     (cod_ente, cod_persona, cod_moneda, mto_facturacion)
                  VALUES
                     (p_cod_empresa, v_cod_persona, p_cod_moneda, t.sueldo);
               EXCEPTION
                  WHEN DUP_VAL_ON_INDEX THEN
                     UPDATE ge_com_aliados
                        SET mto_facturacion = t.sueldo,
                            cod_moneda = p_cod_moneda
                      WHERE cod_ente = p_cod_empresa
                        AND cod_persona = v_cod_persona;
                  WHEN OTHERS THEN
                     raise_application_error(-20017, 'Error al insertar el Comercio Aliado. Nro Documento= '||t.nro_cedula||' '||SQLERRM);
               END;
            END IF;
            IF v_cli_existe = 'N' THEN

              if p_cod_empresa = '1060' then
                 v_cod_sec_contable := 'N';
              else
                 v_cod_sec_contable := t.cod_sec_contable;
              end if;
              BEGIN
                 INSERT INTO ge_clientes
                    (cod_persona, cod_oficina, cod_usu_oficial, cod_departamento, tip_extracto,
                     cod_seg_cliente, residente, cod_sec_contable, cod_tip_deudor)
                 VALUES
                    (v_cod_persona, p_cod_oficina, p_cod_usu_oficial, p_cod_departamento, 'N',
                     v_cod_seg_cliente, 'S', 'N'/*v_cod_sec_contable*/, 2);
              EXCEPTION
                 WHEN OTHERS THEN
                    raise_application_error(-20021, 'Error al insertar datos en GE_CLIENTES. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
              END;

            ELSE
               -- si el cliente ya existe lo pasamos a Extractos Clic
              begin
                 update ge_clientes
                    set tip_extracto = 'N'
                  where cod_persona  = v_cod_persona;
               exception
                  when others then
                     raise_application_error(-20021, 'Error al act. tipo extracto en GE_CLIENTES. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
               end;
            END IF;
            goto fin_proceso;
         END IF;

         IF fug_obt_pardinamico('PAG_NOM_CTA_CLI') = 'S' THEN --Solo si se crea cuenta carga/actualiza sueldo
           -- ** carga o actualizacion de sueldos **
           BEGIN
              v_lugar := '12-Concepto';
              SELECT cod_concepto
                INTO v_cod_concepto
                FROM cr_con_ing_egr
               WHERE tipo                      = 'I'
                 AND rtrim(ltrim(descripcion)) = 'SUELDO';
           EXCEPTION
              WHEN OTHERS THEN
                 raise_application_error(-20017, 'Error al buscar el concepto del Ingreso. Nro Documento= '||t.nro_cedula||' '||SQLERRM);
           END;

           BEGIN

              v_lugar := '13-Insert CR_PER_ING_EGRESOS';
              INSERT INTO cr_per_ing_egresos
                 (cod_persona, cod_concepto, ing_egreso, importe)
              VALUES
                 (v_cod_persona, v_cod_concepto, 'I', t.sueldo);

           EXCEPTION
              WHEN dup_val_on_index THEN
                 UPDATE cr_per_ing_egresos
                    SET importe = t.sueldo
                  WHERE cod_persona  = v_cod_persona
                    AND cod_concepto = v_cod_concepto
                    AND ing_egreso   = 'I';
              WHEN OTHERS THEN
                 raise_application_error(-20018, 'Error al insertar datos en CR_PER_ING_EGRESOS . Nro Documento= '||t.nro_cedula||' '||SQLERRM);
           END;

           -- **veo si tiene cargada la informacion laboral
           DECLARE
              v_lug_trabajo VARCHAR2(100);
           BEGIN

              v_lugar := '14-LUG_TRABAJO';
              SELECT descripcion
                INTO v_lug_trabajo
                FROM ge_entes
               WHERE cod_ente = p_cod_empresa;

              UPDATE cr_inf_laborales
                 SET mto_ingreso = t.sueldo,
                     fec_ingreso = t.fec_ingreso,
                     tip_contrato= t.tip_contrato
               WHERE cod_persona = v_cod_persona
                 AND actual      = 'S'
                 AND lug_trabajo = v_lug_trabajo
                 AND cod_moneda  = v_cod_moneda;

              IF SQL%NOTFOUND THEN
                 v_secuencia := 999;
                 LOOP
                    SELECT COUNT(*)
                      INTO existe
                      FROM cr_inf_laborales
                     WHERE cod_persona   = v_cod_persona
                       AND nro_secuencia = v_secuencia;

                    IF existe = 0 THEN
                       INSERT INTO cr_inf_laborales
                          (cod_persona, nro_secuencia, lug_trabajo, tip_cargo, tip_ingreso, actual,
                           cod_moneda, mto_ingreso, observacion, fec_ingreso, cod_ramo, tip_empleo,
                           cod_direccion, cod_telefono, tip_contrato)
                       VALUES
                          (v_cod_persona, v_secuencia, v_lug_trabajo, v_cod_cargo, v_cod_concepto, 'S',
                           v_cod_moneda, t.sueldo, 'PLAN SUELDO', t.fec_ingreso, 28, 'D',
                           v_cod_dir_laboral, v_cod_tel_laboral, t.tip_contrato);
                       EXIT;
                    ELSE
                       v_secuencia := v_secuencia - 1;
                    END IF;

                 END LOOP;
              END IF;
           EXCEPTION
              WHEN OTHERS THEN
                 raise_application_error(-20000, 'Error al crear Informacion laboral '||SQLERRM);
           END;
         END IF;

         -- **CLIENTES** --
         IF v_cli_existe = 'N' THEN

            if p_cod_empresa = '1060' then
               v_cod_sec_contable := 'N';
            else
               v_cod_sec_contable := t.cod_sec_contable;
            end if;
            BEGIN
               INSERT INTO ge_clientes
                  (cod_persona, cod_oficina, cod_usu_oficial, cod_departamento, tip_extracto,
                   cod_seg_cliente, residente, cod_sec_contable, cod_tip_deudor)
               VALUES
                  (v_cod_persona, p_cod_oficina, p_cod_usu_oficial, p_cod_departamento, 'N',
                   v_cod_seg_cliente, 'S', /*'N'*/v_cod_sec_contable, 2);
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20021, 'Error al insertar datos en GE_CLIENTES. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
            END;

         ELSE

            BEGIN
               v_lugar := '15-Update GE_CLIENTES';
               UPDATE ge_clientes
                  SET cod_seg_cliente = v_cod_seg_cliente,
                      tip_extracto    = 'N'  -- extracto clic
                WHERE cod_persona     = v_cod_persona;

            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20022, 'Error al modificar datos en GE_CLIENTES. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
            END;

         END IF;
      ELSE
         -- Si ya existe como persona entonces solo se da de alta la cuenta y como cliente
         v_cod_persona := lf_obt_cod_persona(t.nro_cedula, v_cod_tip_documento);
         BEGIN
            SELECT DISTINCT 'S', tip_extracto
              INTO v_cli_existe, v_tip_extracto
              FROM ge_clientes
             WHERE cod_persona = v_cod_persona;
         EXCEPTION
            WHEN no_data_found THEN
               v_cli_existe := 'N';
            WHEN OTHERS THEN
               raise_application_error(-20004, 'Error al buscar el cliente. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
         END;

         -- **CLIENTES** --
         IF v_cli_existe = 'N' THEN
            BEGIN
               INSERT INTO ge_clientes
                  (cod_persona, cod_oficina, cod_usu_oficial, cod_departamento, tip_extracto,
                   cod_seg_cliente, residente, cod_sec_contable, cod_tip_deudor)
               VALUES
                  (v_cod_persona, p_cod_oficina, p_cod_usu_oficial, p_cod_departamento, 'N',
                   v_cod_seg_cliente, 'S', 'N', 2);
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20021, 'Error al insertar datos en GE_CLIENTES. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
            END;

         ELSE
            BEGIN
               v_lugar := '15-Update GE_CLIENTES';
               UPDATE ge_clientes
                  SET cod_seg_cliente = v_cod_seg_cliente,
                      tip_extracto    = 'N' -- extracto clic
                WHERE cod_persona = v_cod_persona;
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20022, 'Error al modificar datos en GE_CLIENTES. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
            END;
         END IF;
      END IF; -- Fin gen_cuenta = 'N'

      -- **CUENTA CORRIENTE** --
      v_lugar := '16-CTACTE';

      v_denominacion := lf_obt_nombre(t.pri_nombre, t.seg_nombre, t.pri_apellido, t.seg_apellido, 65);
      v_nom_chequera := lf_obt_nombre(t.pri_nombre, t.seg_nombre, t.pri_apellido, t.seg_apellido, 60);

      -- cc_cta_corrientes
      IF fug_obt_pardinamico('PAG_NOM_CTA_CLI') = 'S' THEN
        IF p_cod_modalidad = 41 THEN

           IF t.nro_cta_ahorro IS NOT NULL THEN
              -- esto para cuentas ya existentes como ahorros, se combina con su cuenta corriente nueva
              v_lugar := '17-AH_CTA_VISTAS';
              BEGIN
                 SELECT cod_oficina
                   INTO v_cod_ofi_ahorro
                   FROM ah_cta_vistas a
                  WHERE a.nro_cuenta = t.nro_cta_ahorro
                    AND a.cod_moneda = v_cod_moneda
                    -- DYDMR-1758-ITGF-Inconvenientes con Vinculacion de Cuentas-SC14090-EGC20/05/2015 ('I')
                    AND a.estado     NOT IN ('C', 'P', 'I')
                    AND EXISTS (SELECT 0
                                  FROM ge_cta_clientes b
                                 WHERE b.nro_cuenta  = a.nro_cuenta
                                   AND b.cod_persona = v_cod_persona
                                   AND b.relacion    = 'P');
              EXCEPTION
                 WHEN OTHERS THEN
                    NULL;
              END;
           END IF;

           v_nro_cuenta := lf_obt_cta_corriente(v_cod_persona, t.nro_cedula, 'C', v_denominacion,
                                                p_cod_modulo, nvl(v_cod_ofi_ahorro, p_cod_oficina),
                                                t.sueldo, v_nom_chequera, t.fec_ingreso, t.tip_contrato);

        ELSE

           v_nro_cuenta := lf_obt_cta_aho_vista(v_cod_persona, t.nro_cedula, 'C', v_denominacion,
                                                p_cod_modulo, nvl(v_cod_ofi_ahorro, p_cod_oficina),
                                                t.sueldo, v_nom_chequera, t.tip_contrato);

        END IF;
      END IF;

      IF v_nro_cuenta IS NOT NULL THEN
         -- ge_cta_clientes
         BEGIN
            v_lugar := '19-Insert GE_CTA_CLIENTES';
            INSERT INTO ge_cta_clientes
               (cod_persona, nro_cuenta, dig_verificador, cod_oficina, cod_modulo,
                cod_modalidad, relacion)
            VALUES
               (v_cod_persona, v_nro_cuenta, 0, nvl(v_cod_ofi_ahorro, p_cod_oficina), v_cod_mod_cuenta,
                v_cod_mad_cuenta, 'P');

         EXCEPTION
            WHEN dup_val_on_index THEN
               -- ya existe la cuenta y se está actualizando el ente
               null;
            WHEN OTHERS THEN
               raise_application_error(-20050, 'Error al insertar datos en GE_CTA_CLIENTES. Documento Nro= '||t.nro_cedula||SQLERRM);
         END;

         -- si viene una cuenta de ahorros --
         IF t.nro_cta_ahorro IS NOT NULL THEN
            -- esto para cuentas ya existentes como ahorros, se combina con su cuenta corriente nueva
            DECLARE
               v_combina        VARCHAR2(1) := 'N';
               v_cod_ent_ahorro NUMBER(4);
            BEGIN

               v_lugar := '20-Combinada';
               SELECT 'S', cod_ente
                 INTO v_combina, v_cod_ent_ahorro
                 FROM ah_cta_vistas a
                WHERE a.nro_cuenta = t.nro_cta_ahorro
                  AND a.cod_moneda = v_cod_moneda
                  -- DYDMR-1758-ITGF-Inconvenientes con Vinculacion de Cuentas-SC14090-EGC20/05/2015 ('I')
                  AND a.estado     NOT IN ('C', 'P', 'I')
                  AND EXISTS (SELECT 0
                                FROM ge_cta_clientes b
                               WHERE b.nro_cuenta  = a.nro_cuenta
                                 AND b.cod_persona = v_cod_persona
                                 AND b.relacion    = 'P');

               IF v_combina = 'S' THEN

                  INSERT INTO cc_cta_combinadas
                     (nro_cta_ahorro, nro_cta_cte, sal_minimo, fec_apertura, observaciones)
                  VALUES
                     (t.nro_cta_ahorro, v_nro_cuenta, 0, p_fecha, 'PLAN SUELDO');

                  IF nvl(v_cod_ent_ahorro, -1) <> p_cod_empresa THEN
                     UPDATE ah_cta_vistas
                        SET cod_ente = p_cod_empresa
                      WHERE nro_cuenta = t.nro_cta_ahorro;
                  END IF;

               END IF;
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20022, 'Error al combinar con la cuenta de Ahorro. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
            END;

         END IF;

         BEGIN
            v_lugar := '21-Oficina';
            SELECT cod_oficina
              INTO v_cod_ofi_origen
              FROM ba_usuarios
             WHERE cod_usuario = USER;
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20039, 'Error al buscar la Oficina Origen. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
         END;

         -- ge_movimientos
         v_nro_sec_movimiento := v_nro_sec_movimiento + 1;
         BEGIN

            v_lugar := '22-Insert GE_MOVIMIENTOS';
            INSERT INTO ge_movimientos
               (fecha, hora, cod_usuario, nro_secuencia, fec_valor,
                nro_cuenta, cod_moneda, cod_oficina, est_cuenta, estado,
                cod_ofi_origen, concepto, cod_tra_padre, cod_mod_padre, cod_mad_padre, cod_transaccion,
                cod_modulo, cod_modalidad)
            VALUES
               (p_fecha, to_char(SYSDATE, 'hh24:mi:ss'), USER, v_nro_sec_movimiento, p_fecha,
                v_nro_cuenta, v_cod_moneda, nvl(v_cod_ofi_ahorro, p_cod_oficina), 'A', 'N',
                v_cod_ofi_origen, 'Cambio de Estado', 401, v_cod_mod_cuenta, v_cod_mad_cuenta, 401,
                v_cod_mod_cuenta, v_cod_mad_cuenta);

         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20039, 'Error al insertar en GE_MOVIMIENTOS. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
         END;

         -- ge_ret_cuentas
         FOR ret IN cta_ret LOOP
            v_lugar      := '23-GE_RET_CUENTAS';
            v_ret_existe := 'S';
            BEGIN
               v_lugar := '24';
               INSERT INTO ge_ret_cuentas
                  (cod_retencion, nro_cuenta, can_dia_retencion, observaciones)
               VALUES
                  (ret.cod_retencion, v_nro_cuenta, ret.can_dia_retencion, v_observacion);
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20031, 'Error al insertar datos en GE_RET_CUENTAS. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
            END;
         END LOOP;

         -- ge_tra_prohibidas
         FOR tra IN cta_tra LOOP
            v_tra_existe := 'S';
            BEGIN
               v_lugar := '25-GE_TRA_PROHIBIDAS';
               INSERT INTO ge_tra_prohibidas
                  (cod_transaccion, cod_modulo, cod_modalidad,
                   nro_cuenta, observaciones)
               VALUES
                  (tra.cod_transaccion, tra.cod_mod_transaccion, tra.cod_mad_transaccion,
                   v_nro_cuenta, v_observacion);
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20032, 'Error al insertar datos en GE_TRA_PROHIBIDAS. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
            END;
         END LOOP;

         -- ge_tas_fechas
         FOR tas IN cta_tas LOOP
            v_lugar      := '26-GE_TAS_FECHAS';
            v_tas_existe := 'S';
            BEGIN
               INSERT INTO ge_tas_fechas
                  (cod_tasa, fec_vigencia, nro_cuenta, val_tasa, aplicar, observaciones)
               VALUES
                  (tas.cod_tasa, p_fecha, v_nro_cuenta, tas.valor, 'ST', v_observacion);
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20033, 'Error al insertar datos en GE_TAS_FECHAS. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
            END;
         END LOOP;
         --DYDMR-1816-ITGF - Cancelación de linea sobregiro Cta. Nomina - SC 15209 (v_cod_mod_cuenta -> v_cod_mad_cuenta)
         IF nvl(v_cod_mad_cuenta,p_cod_modalidad) = 41 THEN
            -- actualiza la cuenta corriente --
            BEGIN
               v_lugar := '27-CC_CTA_CORRIENTES';
               UPDATE cc_cta_corrientes
                  SET ret_personalizada = v_ret_existe,
                      tas_personalizada = v_tas_existe,
                      tra_prohibida     = v_tra_existe/*,
                      acu_sobregiro     = 'S'*/ -- DYDMR-4334 ALV
                WHERE nro_cuenta = v_nro_cuenta;
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20037, 'Error al modificar CC_CTA_CORRIENTES. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
            END;

            -- verificacion de cuenta
            BEGIN
               UPDATE cc_cta_corrientes
                  SET estado = v_estado
                WHERE nro_cuenta = v_nro_cuenta;
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20050, 'Error al verificar la cuenta. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
            END;

         ELSE
            -- actualiza la cuenta de ahorro --
            BEGIN
               v_lugar := '27-AH_CTA_VISTAS';
               UPDATE ah_cta_vistas
                  SET ret_personalizada = v_ret_existe,
                      tas_personalizada = v_tas_existe,
                      tra_prohibida     = v_tra_existe
                WHERE nro_cuenta = v_nro_cuenta;
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20037, 'Error al modificar AH_CTA_VISTAS. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
            END;

            -- verificacion de cuenta
            BEGIN
               UPDATE ah_cta_vistas
                  SET estado = v_estado
                WHERE nro_cuenta = v_nro_cuenta;
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20050, 'Error al verificar la cuenta. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
            END;

         END IF;

         -- verificacion de cuenta
         BEGIN
            UPDATE ge_cuentas
               SET est_verificacion = 'V'
             WHERE nro_cuenta = v_nro_cuenta;
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20050, 'Error al verificar la cuenta. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
         END;

         -- Genera Tarjeta si en el parámetro lo inidica y no tiene Tarjeta de Débito --
         IF nvl(rg_par_cuentas.gen_tar_debito, 'N') = 'S' AND
            lf_obt_tar_debito(v_cod_persona, t.nro_cedula, v_nro_cuenta) = 'N' THEN

            v_lugar := '28-Embozado';
            begin
              select upper(substr(t.pri_nombre,1,decode(instr(t.pri_nombre,' ',1),0,length(t.pri_nombre),instr(t.pri_nombre,' ',1))))
                into v_pri_nombre
                from dual;

              select upper(substr(t.pri_nombre,decode(instr(t.pri_nombre,' ',1),0,length(t.pri_nombre),instr(t.pri_nombre,' ',1)) + 1,length(t.pri_nombre)))
                into v_seg_nombre
                from dual;
            exception
              when others then
                 raise_application_error(-20037, 'Error al cortar nombres'||t.nro_cedula||' '||SQLERRM);
            end;

            IF length(lf_obt_nombre(v_pri_nombre, v_seg_nombre, t.pri_apellido, t.seg_apellido, 25)) > 26 THEN
               raise_application_error(-20037, 'Nombre para Embozado mayor a 26 digitos '||t.nro_cedula||' '||SQLERRM);
            END IF;

            v_embozado := lf_obt_nombre(v_pri_nombre, v_seg_nombre, t.pri_apellido, t.seg_apellido, 25);
            v_embozado := translate(v_embozado, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890ÑÁÉÍÓÚ.+´~-|°¬!"#$%&/()=?¡¿*¨{}^`[]_:;,><ÇÃ',
                                                'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890NAEIOU. ');
            --
            BEGIN
               v_lugar           := '29-VEN_TAR_DEBITOS';
               v_anio            := fug_obt_pardinamico('VEN_TAR_DEBITOS');
               v_fec_vencimiento := last_day(add_months(p_fecha, (nvl(v_anio, 3) * 12)));

               INSERT INTO ah_tar_debitos
                  (nro_cuenta, tar_activa, fec_ingreso, cod_persona, embozado, cod_usuario,
                   fec_grabacion, nro_emision, cod_ofi_origen, fec_vencimiento, tip_envio,
                   referencia, cod_est_solicitud, cod_ent_procesadora, tip_tar_debito, nro_bin, renovacion)
               VALUES
                  (v_nro_cuenta, 'N', p_fecha, v_cod_persona, v_embozado, USER,
                   SYSDATE, '01', p_cod_oficina, v_fec_vencimiento, 'D',
                   1, 3, v_cod_pro_bancard, v_tip_tar_debito, v_nro_bin_procesadora, 'N');

            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20038, 'Error al insertar en AH_TAR_DEBITOS documento = '||t.nro_cedula||' '||SQLERRM);
            END;

         END IF;
        --Desde aquí FASE 2 BBVADES 2576

         v_per_cal_lin_sobregiro:= fug_obt_parentes(p_cod_empresa, 'SOB_PER_CALCULO');
         v_por_lim_sueldo := fug_obt_parentes(p_cod_empresa, 'POR_LIM_SUELDO');

         begin
            select cod_modulo
              into v_cod_modulo
              from ge_cuentas c
             where nro_cuenta = v_nro_cuenta;
         exception
            when no_data_found then
               v_cod_modulo:= p_cod_modulo;
         end;

         /*
         PCCRPDNE-1
         1. Si el parametro dinamico PAG_NOM_SOB_CTA es igual a S y el procentaje del límite de sueldo del
         ente está definido genero la linea de sobregiro.
         2. Si el procentaje del límite de sueldo del ente está definido y el campo sobregiro de la tabla
         ge_pag_sue_emp_tmp es igual a "S" o es nulo genero la línea de sobregiro
         */
         if fug_obt_pardinamico('PAG_NOM_SOB_CTA') = 'S' and v_por_lim_sueldo is not null then
            if (v_per_cal_lin_sobregiro is null or v_per_cal_lin_sobregiro = 0) and v_cod_modulo = 4 then
              v_lugar          := '30-GEN_LIN_SOBREGIRO';
              v_mto_sob_sueldo := trunc((t.sueldo*v_por_lim_sueldo)/100); -- OMM DYDMR-4429 12/07/2016 no debe tener decimales
              pag_nom.pr_gen_lin_sobregiro(v_nro_cuenta,p_cod_empresa,'G',v_mto_sob_sueldo/*t.mto_ant_sueldo*/,t.mto_ant_aguinaldo);
           end if;
         else
           if v_por_lim_sueldo is not null and (t.sobregiro = 'S' or t.sobregiro is null) then
             if (v_per_cal_lin_sobregiro is null or v_per_cal_lin_sobregiro = 0) and v_cod_modulo = 4 then
                v_lugar          := '30-GEN_LIN_SOBREGIRO';
                v_mto_sob_sueldo := trunc((t.sueldo*v_por_lim_sueldo)/100); -- OMM DYDMR-4429 12/07/2016 no debe tener decimales
                pag_nom.pr_gen_lin_sobregiro(v_nro_cuenta,p_cod_empresa,'G',v_mto_sob_sueldo/*t.mto_ant_sueldo*/,t.mto_ant_aguinaldo);
             end if;
           end if;
         end if;
         -- Inserta en la tabla historica, para emision de remitos
         BEGIN
            v_lugar := '37-Insert GE_PAG_SUE_EMP';
            INSERT INTO ge_pag_sue_emp
               (cod_empresa, tip_documento, nro_cedula, pri_nombre, seg_nombre, pri_apellido,
                seg_apellido, ape_casada, fec_nacimiento, sexo, est_civil,
                direccion, ciudad, telefono, sueldo, nro_solicitud, error, nro_cuenta, tip_contrato,
                direc_kit, sobregiro, nro_lote, estado, fec_ingreso, profesion, mail, pais, celular,
                fec_vto_documento, cod_pai_fatca, dir_fiscal, cod_pai_fiscal, doc_pais)
            VALUES
               (p_cod_empresa, t.tip_documento, t.nro_cedula, t.pri_nombre, t.seg_nombre, t.pri_apellido,
                t.seg_apellido, t.ape_casada, t.fec_nacimiento, t.sexo, t.est_civil,
                t.direccion, t.ciudad, t.telefono, t.sueldo, t.nro_solicitud, NULL, v_nro_cuenta, t.tip_contrato,
                t.direc_kit, t.sobregiro, NVL(t.nro_lote,0), 'N', t.fec_ingreso, t.profesion, t.mail, t.pais, t.celular,
                t.fec_vto_documento, t.cod_pai_fatca, t.dir_fiscal, t.cod_pai_fiscal, t.doc_pais);
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20042, 'Error al insertar datos en GE_PAG_SUE_EMP. Documento Nro= '||t.nro_cedula||' '||SQLERRM);
         END;
      ELSE
        --si ya tiene una cuenta y está marcado para generar sobregiro genero o recalculo sobregiro para el cliente
        v_mto_sueldo := fug_obt_ing_cliente(v_cod_persona,null);
        v_por_lim_sueldo := fug_obt_parentes(p_cod_empresa, 'POR_LIM_SUELDO');
        v_mto_sob_sueldo := trunc((t.sueldo*v_por_lim_sueldo)/100); -- OMM DYDMR-4429 12/07/2016 no debe tener decimales
        if v_cta_anterior is not null and t.sobregiro = 'S' then
          if v_mto_sueldo <> t.sueldo then
            BEGIN
              SELECT cod_concepto
                INTO v_cod_concepto
                FROM cr_con_ing_egr
               WHERE tipo                      = 'I'
                 AND rtrim(ltrim(descripcion)) = 'SUELDO';
            EXCEPTION
               WHEN OTHERS THEN
                 raise_application_error(-20017, 'Error al buscar el concepto del Ingreso. Nro Documento= '||t.nro_cedula||' '||SQLERRM);
            END;
            BEGIN
              UPDATE cr_per_ing_egresos
                 SET importe = v_mto_sob_sueldo
               WHERE cod_persona  = v_cod_persona
                 AND cod_concepto = v_cod_concepto
                 AND ing_egreso   = 'I';
            EXCEPTION
               WHEN OTHERS THEN
                 raise_application_error(-20018, 'Error al actualizar CR_PER_ING_EGRESOS . Nro Documento= '||t.nro_cedula||' '||SQLERRM);
            END;
            DECLARE
               v_lug_trabajo VARCHAR2(100);
               v_mto_ingreso cr_inf_laborales.mto_ingreso%type;
               v_existe      VARCHAR2(1) DEFAULT 'N';
               v_fec_ingreso cr_inf_laborales.fec_ingreso%type;
            BEGIN
               SELECT descripcion
                 INTO v_lug_trabajo
                 FROM ge_entes
                WHERE cod_ente = p_cod_empresa;
                  BEGIN
                    SELECT nvl(MAX(nro_secuencia),0) + 1
                      INTO v_secuencia
                      FROM cr_inf_laborales
                     WHERE cod_persona = v_cod_persona;
                  EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                      v_secuencia := 1;
                    WHEN OTHERS THEN
                      v_secuencia := 1;
                  END;
                  BEGIN
                    SELECT 'S', mto_ingreso
                       INTO v_existe, v_mto_ingreso
                       FROM cr_inf_laborales
                      WHERE cod_persona = v_cod_persona
                        AND lug_trabajo = v_lug_trabajo;
                  EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                      v_existe := 'N';
                    WHEN OTHERS THEN
                      v_existe := 'N';
                  END;
                  IF v_existe = 'N' THEN
                      UPDATE cr_inf_laborales
                         SET actual = 'N'
                       WHERE cod_persona = v_cod_persona
                         AND cod_moneda = v_cod_moneda;
                      INSERT INTO cr_inf_laborales
                         (cod_persona, nro_secuencia, lug_trabajo, tip_cargo, tip_ingreso, actual,
                          cod_moneda, mto_ingreso, observacion, fec_ingreso, cod_ramo, tip_empleo,
                          cod_direccion, cod_telefono)
                      VALUES
                         (v_cod_persona, v_secuencia, v_lug_trabajo, 43, 23, 'S',
                          v_cod_moneda, t.sueldo, 'PLAN SUELDO', v_fec_ingreso, 28, 'D',
                          v_cod_dir_laboral, v_cod_tel_laboral);
                  ELSIF v_mto_ingreso != t.sueldo THEN
                     UPDATE cr_inf_laborales
                        SET mto_ingreso = t.sueldo,
                            fec_ingreso = v_fec_ingreso
                      WHERE cod_persona = v_cod_persona
                        AND cod_moneda = v_cod_moneda;
                  END IF;
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20000, 'Error al crear Informacion laboral. Persona '||fue_obt_nom_persona(v_cod_persona)||SQLERRM);
            END;
            if fuc_obt_exi_sobregiro(v_cta_anterior) = 'S' then
               pag_nom.pr_gen_lin_sobregiro(v_cta_anterior,p_cod_empresa,'R',v_mto_sob_sueldo,t.mto_ant_aguinaldo);
            else
               pag_nom.pr_gen_lin_sobregiro(v_cta_anterior,p_cod_empresa,'G',v_mto_sob_sueldo,t.mto_ant_aguinaldo);
            end if;
          else
            if fuc_obt_exi_sobregiro(v_cta_anterior) = 'N' then
               pag_nom.pr_gen_lin_sobregiro(v_cta_anterior,p_cod_empresa,'G',v_mto_sob_sueldo,t.mto_ant_aguinaldo);
            end if;
          end if;
        end if;
      END IF;

     ---CROFATCA-132 - IDENTIFICACION DE CLIENTES PERSONAS JURIDICAS - FATCA : ITC-LCABRERA 05/2014
      PAE_FAT.PR_ACT_PER_FATCA(v_cod_persona,'F',null,'S', v_men_fatca, 'S');

      ----Proyecto: CLI_COM_ALIADOS - xpy0038 - 06/2014
      <<fin_proceso>>
      null;
      v_nro_lote := t.nro_lote;
   END LOOP;

   --** Inserta los registros no procesados en la tabla histórico, para emision de remitos
   BEGIN
      v_lugar := '38-Insert GE_PAG_SUE_EMP';
      INSERT INTO ge_pag_sue_emp
         (cod_empresa, tip_documento, nro_cedula, pri_nombre, seg_nombre, pri_apellido,
          seg_apellido, ape_casada, fec_nacimiento, sexo, est_civil, direccion, ciudad,
          telefono, sueldo, nro_solicitud, error, nro_cuenta, tip_contrato, direc_kit, sobregiro,
          nro_lote, estado, fec_ingreso, profesion, mail, pais, celular,
          fec_vto_documento, cod_pai_fatca, dir_fiscal, cod_pai_fiscal, doc_pais)
         SELECT p_cod_empresa, ge.tip_documento, ge.nro_cedula, ge.pri_nombre, ge.seg_nombre, ge.pri_apellido,
                ge.seg_apellido, ge.ape_casada, ge.fec_nacimiento, ge.sexo, ge.est_civil, ge.direccion, ge.ciudad,
                ge.telefono, ge.sueldo, ge.nro_solicitud, ge.error,
                (select nvl(cta.nro_cuenta, null)
                   from ge_cta_clientes cta, ba_personas p, cc_cta_corrientes cc
                  where cta.cod_persona = p.cod_persona
                    and p.nro_documento = ge.nro_cedula
                    and cc.nro_cuenta = cta.nro_cuenta
                    and cta.relacion = 'P'
                    and cc.estado not in ('P','C')
                    and cc.cod_sub_modalidad = 9
                    and cc.cod_ente is not null
                    and rownum = 1
                 union
                 select nvl(cta.nro_cuenta, null)
                   from ge_cta_clientes cta, ba_personas p, ah_cta_vistas ah
                  where cta.cod_persona = p.cod_persona
                    and p.nro_documento = ge.nro_cedula
                    and ah.nro_cuenta = cta.nro_cuenta
                    and cta.relacion = 'P'
                    and ah.estado not in ('P','C')
                    and ah.cod_sub_modalidad = 11
                    and ah.cod_ente is not null
                    and rownum = 1) nro_cuenta,
                --DYDMR-7937
                decode(ge.tip_contrato,'T','T','I'), ge.direc_kit, ge.sobregiro, nvl(ge.nro_lote,0), 'R',
                ge.fec_ingreso, ge.profesion, ge.mail, ge.pais, ge.celular,
                ge.fec_vto_documento, ge.cod_pai_fatca, ge.dir_fiscal, ge.cod_pai_fiscal, ge.doc_pais
           FROM ge_pag_sue_emp_tmp ge
          WHERE cod_empresa = p_cod_empresa
            AND nvl(nro_lote,0) = nvl(v_nro_lote,0)
            AND ge.error is not null
            AND generar = 'S';
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20042,'Error al insertar datos de registros rechazados en GE_PAG_SUE_EMP.'||sqlerrm);
   END;

   --** Elimina los registros de la tabla temporal **--
   BEGIN
      DELETE ge_pag_sue_emp_tmp T
       WHERE cod_empresa = p_cod_empresa
         AND generar     = 'S'
         AND error       is null
         AND nvl(nro_lote,0) = nvl(v_nro_lote,0) ;--DYDMR-8714
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20060, 'Error al eliminar registros de GE_PAG_SUE_EMP_TMP '||SQLERRM);
   END;
   --** **--
   --PROCESO PARA SCORING MASIVO
   begin
      --en caso de reproceso del mismo lote de alta masiva nómina
      begin
         delete GE_LOT_SCO_MASIVO lsm
         where lsm.nro_lote_pro_nomina = v_nro_lote;
      end;

      begin
         insert into GE_LOT_SCO_MASIVO (Nro_Lote_Pro_Nomina, Fec_Ing_Pro_Nomina, Estado)
         values (nvl(v_nro_lote,0), sysdate, 'E');
      EXCEPTION
         WHEN OTHERS THEN
         raise_application_error(-20061, 'Error al registrar el lote para proceso masivo Scoring: '||SQLERRM);
      end;
   end;



EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20019, v_nro_documento||'-'||v_lugar||'-'||SQLERRM);
END;
/

