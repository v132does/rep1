create or replace PACKAGE BODY it.paw_ali IS
    MSG_OK               CONSTANT VARCHAR2(30) := 'OP_APROBADA';
    MSG_ERROR            CONSTANT VARCHAR2(30) := 'OP_ERROR';
    c_op_error           CONSTANT VARCHAR2(15) := 'OP_ERROR';
    g_codCanal           CONSTANT VARCHAR2(3)  := '999';
    v_cod_operacion      varchar2(3);
   --------------------------------------------------------------------------------------------------------------------------------------------
    FUNCTION fu_sol_per_alias (
        p_cod_persona      in varchar2,
        p_modo          IN VARCHAR2 DEFAULT 'A',
        p_tip_ide_cli   IN VARCHAR2,
        p_val_ide_cli   IN VARCHAR2,
        p_tip_ide_alias IN VARCHAR2,
        p_val_ide_alias IN VARCHAR2,
        p_nro_cuenta    IN VARCHAR2,
        p_cta_defecto   IN VARCHAR2,
        p_tip_accion    IN VARCHAR2
    ) RETURN typ_solicitudaltacas IS

        v_retorno                 typ_solicitudaltacas := typ_solicitudaltacas;
        datosclie                 typ_obtregclicas := typ_obtregclicas(NULL, NULL, NULL, NULL, NULL,
                                                      NULL, NULL, NULL, NULL, NULL,
                                                      NULL, NULL, NULL, NULL, NULL,
                                                      NULL, NULL, NULL, NULL, NULL,
                                                      NULL);
        datoscta                  typ_insctacas := typ_insctacas(NULL, NULL, NULL, NULL, NULL,
                                               NULL, NULL, NULL, NULL, NULL,
                                               NULL, NULL, NULL, NULL);
        r_deta                    ge_spi_ali_cas%rowtype;
        g_lugar                   VARCHAR(250);

        v_mensajecaja             typ_mensajecaja;
        v_parametros              VARCHAR2(4000) := NULL;
        v_cod_persona             ba_personas.cod_persona%TYPE;
        v_cod_canal               VARCHAR2(3);
        v_cod_operacion           CONSTANT VARCHAR2(03) := '029';
        v_permiso                 typ_obtenerpermisos;
        trp_tra_invalida          CONSTANT VARCHAR2(15) := 'TRP_TRA_INVALID';
        trp_sin_permiso           CONSTANT VARCHAR2(15) := 'TRP_SIN_PERMISO';
        v_existe_p                VARCHAR2(1);
        v_tipo_per                VARCHAR2(1);
        v_existe_cli              VARCHAR2(1);
        v_existe_cta              VARCHAR2(1);
        v_existe_ali              VARCHAR2(1);
        v_exi_cta                 VARCHAR2(1);
        v_cod_moneda              ba_monedas.cod_moneda%TYPE;
        v_relacion                VARCHAR2(1);
        v_inserta                 BOOLEAN := TRUE;
        rg_datper                 ba_personas%rowtype;
        rg_datperf                ba_per_fisicas%rowtype;
        rg_datperj                ba_per_juridicas%rowtype;
        rg_datdir                 ba_direcciones%rowtype;
        v_apodo                   VARCHAR2(4000) := NULL;--pasaremos null
        v_inf_adicional           VARCHAR2(4000) := NULL;--pasaremos null
        v_det_adicional_pv        VARCHAR2(4000) := NULL;--pasaremos null
        v_departamento            ba_departamentos.descripcion%TYPE := NULL;
        v_ciudad                  ba_ciudades.descripcion%TYPE;
        v_pais                    ba_paises.descripcion%TYPE;
        v_lugar_nacimiento        ba_ciudades.descripcion%TYPE;
        v_nombre                  ba_personas.nom_completo%TYPE;
        v_apellido                ba_personas.nom_completo%TYPE;
        v_genero                  ba_per_fisicas.cod_sexo%TYPE;
        v_fec_nacimiento          ba_per_fisicas.fec_nacimiento%TYPE;
        v_direccion               ba_direcciones.direccion%TYPE;
        v_fec_vto_documento       ba_personas.fec_vto_documento%TYPE;
        v_cod_pais                ba_paises.cod_pais%TYPE;
        v_cod_ciudad              ba_ciudades.cod_ciudad%TYPE;
        v_fec_registro            DATE := sysdate;
        v_fec_ven_registro        DATE := NULL;--pasaremos null
        v_est_alias               VARCHAR2(4000) := 'ACTIVE';
        v_est_solicitud           ge_spi_cli_cas.est_solicitud%TYPE;
        v_tip_cuenta              VARCHAR2(3);
        v_mon_cuenta              ge_cuentas.cod_moneda%TYPE;
        v_fec_ape_cuenta          ge_cuentas.fec_apertura%TYPE;
        v_cod_swi_pte_solicitante ge_snp_transferencias.cod_swi_pte_solicitante%TYPE;
        v_cta_defecto             ge_cuentas.nro_cuenta%TYPE := p_cta_defecto;
        v_existe                  VARCHAR2(1) := 'N';
        v_error                   VARCHAR2(1) := 'N';
        v_msj_error               VARCHAR2(2000) := NULL;
        v_canal                   VARCHAR2(10):='APP';--TRFS-1448-se asigna canal para que no genere circuitos 150-155-160
        v_cli_recor               ge_spi_cli_cas.cli_recordid%TYPE := NULL;
    BEGIN


        v_cod_persona := p_cod_persona;
        v_parametros := 'fu_sol_per_alias: ' --TCE-200
                        || 'p_cod_persona: '
                        || v_cod_persona
                        || 'p_tip_ide_cli: '
                        || p_tip_ide_cli
                        || 'p_tip_ide_alias: '
                        || p_tip_ide_alias
                        || 'p_tip_ide_alias: '
                        || p_tip_ide_alias
                        || 'p_val_ide_alias: '
                        || p_val_ide_alias
                        || 'p_nro_cuenta: '
                        || p_nro_cuenta
                        || 'p_cta_defecto: '
                        || p_cta_defecto
                        || 'p_tip_accion: '
                        || p_tip_accion; 

    /*
    Se valida parametros ingresados y se obtiene valores
    */
        IF p_modo = 'A' THEN
            IF p_tip_ide_cli IN ( 'CI', 'CRC', 'CRP' ) THEN
                BEGIN
                    SELECT
                        *
                    INTO rg_datper
                    FROM
                        ba_personas p
                    WHERE
                        p.cod_persona = v_cod_persona;

                EXCEPTION
                    WHEN no_data_found THEN
                        v_error := 'S';
                        v_msj_error := 'No se encuentra datos de persona:' || v_cod_persona;
                    WHEN OTHERS THEN
                        v_error := 'S';
                        v_msj_error := 'Ocurrio un error al obtener datos de persona:' || v_cod_persona;
                END;

                BEGIN
                    SELECT
                        *
                    INTO rg_datperf
                    FROM
                        ba_per_fisicas p
                    WHERE
                        p.cod_persona = v_cod_persona;

                EXCEPTION
                    WHEN no_data_found THEN
                        v_error := 'S';
                        v_msj_error := 'No se encuentra datos de persona fisica:' || v_cod_persona;
                    WHEN OTHERS THEN
                        v_error := 'S';
                        v_msj_error := 'Ocurrio un error al obtener datos de persona fisica:' || v_cod_persona;
                END;

            ELSE
                v_retorno.nombrerespuesta := 'PRO_'
                                             || v_cod_operacion
                                             || '_'
                                             || '13';
                v_retorno.descripcionrespuesta := 'Error en tip_ide_alias.-' || p_tip_ide_cli;
                v_retorno.error := 'S';
                paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null, v_cod_operacion, null,
                                   v_parametros
                                   || ' '
                                   || paw_uti.fu_generarbitacora(v_retorno.error, v_retorno.nombrerespuesta, v_retorno.descripcionrespuesta, NULL
                                   ),  paw_uti.bitacora_error);

                RETURN v_retorno;
            END IF;
    /*
    Se asignan valores
    */
            BEGIN
                SELECT
                    *
                INTO rg_datdir
                FROM
                    ba_direcciones d
                WHERE
                        d.cod_persona = v_cod_persona
          -- and tipo = 'P'
                    AND principal = 'S';

            EXCEPTION
                WHEN no_data_found THEN
                    v_error := 'S';
                    v_msj_error := 'No se encuentra datos de direccion:' || v_cod_persona;
                WHEN OTHERS THEN
                    v_error := 'S';
                    v_msj_error := 'Ocurrio un error al obtener datos de direccion:' || v_cod_persona;
            END;

            v_cod_pais := rg_datdir.cod_pais;
            v_cod_ciudad := rg_datdir.cod_ciudad;
            v_apellido := rg_datperf.pri_apellido;
            v_genero := rg_datperf.cod_sexo;
            v_fec_nacimiento := rg_datperf.fec_nacimiento;

            BEGIN
                SELECT
                    p.descripcion
                INTO v_pais
                FROM
                    ba_paises p
                WHERE
                    p.cod_pais = v_cod_pais;

            EXCEPTION
                WHEN no_data_found THEN
                    v_error := 'S';
                    v_msj_error := 'No se encuentra datos de pais:' || v_cod_persona;
                WHEN OTHERS THEN
                    v_error := 'S';
                    v_msj_error := 'Ocurrio error al obtener datos de pais:' || v_cod_persona;
            END;

            BEGIN
                SELECT
                    c.descripcion
                INTO v_ciudad
                FROM
                    ba_ciudades c
                WHERE
                        c.cod_pais = rg_datdir.cod_pais
                    AND c.cod_ciudad = rg_datdir.cod_ciudad;

            EXCEPTION
                WHEN no_data_found THEN
                    v_error := 'S';
                    v_msj_error := 'No se encuentra datos de ciudad:' || v_cod_persona;
                WHEN OTHERS THEN
                    v_error := 'S';
                    v_msj_error := 'Ocurrio error al obtener datos de ciudad:' || v_cod_persona;
            END;

            BEGIN
                SELECT
                    dp.descripcion
                INTO v_departamento
                FROM
                    ba_departamentos dp
                WHERE
                    dp.cod_departamento = rg_datdir.cod_departamento;

            EXCEPTION
                WHEN no_data_found THEN
                    BEGIN
                        SELECT
                            d.descripcion
                        INTO v_departamento
                        FROM
                            ba_ciudades      c,
                            ba_departamentos d
                        WHERE
                                c.cod_ciudad = rg_datdir.cod_ciudad
                            AND c.cod_pais = rg_datdir.cod_pais
                            AND d.cod_departamento = c.cod_departamento;

                    EXCEPTION
                        WHEN no_data_found THEN
                            v_departamento := NULL;
                        WHEN OTHERS THEN
                            v_departamento := NULL;
                    END;
                WHEN OTHERS THEN
                    NULL;
            END;
    /*
    Se trata error al recuperar datos
    */
            IF
                nvl(v_error, 'N') = 'S'
                AND p_tip_ide_cli IN ( 'CI', 'CRC', 'CRP' )
            THEN
                v_retorno.nombrerespuesta := 'PRO_'
                                             || v_cod_operacion
                                             || '_'
                                             || '5';
                v_retorno.descripcionrespuesta := 'Error al obtener datos.-' || v_msj_error;
                v_retorno.error := 'S';
                paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null, v_cod_operacion, null
                ,
                                   v_parametros
                                   || ' '
                                   || paw_uti.fu_generarbitacora(v_retorno.error, v_retorno.nombrerespuesta, v_retorno.descripcionrespuesta, NULL
                                   ), paw_uti.bitacora_error);

                RETURN v_retorno;
            END IF;

            v_fec_vto_documento := rg_datper.fec_vto_documento;
            v_nombre := nvl(rg_datperf.pri_nombre, rg_datperj.raz_social);
            v_direccion := rg_datdir.direccion;
    /*
    Recupera datos de la cuenta
    */
            pag_cta.pr_obt_cuenta(p_nro_cuenta);
            IF pag_cta.g_cod_error <> 0 THEN
                v_retorno.nombrerespuesta := 'PRO_'
                                             || v_cod_operacion
                                             || '_'
                                             || '1';
                v_retorno.descripcionrespuesta := 'Error al obtener datos de la cuenta. '
                                                  || pag_cta.g_cod_error
                                                  || ' - '
                                                  || pag_cta.g_msj_error;

                v_retorno.error := 'S';
                paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null, v_cod_operacion, null
                ,
                                   v_parametros
                                   || ' '
                                   || paw_uti.fu_generarbitacora(v_retorno.error, v_retorno.nombrerespuesta, v_retorno.descripcionrespuesta, NULL
                                   ), paw_uti.bitacora_error);

                RETURN v_retorno;
            ELSE

                BEGIN
                    SELECT
                        upper(c.val_maximo)
                    INTO v_tip_cuenta
                    FROM
                        ba_cod_referencias c
                    WHERE
                            c.dominio = 'TIP_CTA_CAS'
                        AND c.val_minimo = pag_cta.g_ctas.cod_modalidad;

                EXCEPTION
                    WHEN no_data_found THEN
                        v_tip_cuenta := NULL;
                    WHEN OTHERS THEN
                        v_tip_cuenta := NULL;
                END;

                v_mon_cuenta := pag_cta.g_ctas.cod_moneda;
                v_fec_ape_cuenta := pag_cta.g_ctas.fec_apertura;
            END IF;

            v_cod_swi_pte_solicitante := pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
            BEGIN
                SELECT
                    'S'
                INTO v_existe
                FROM
                    ba_cod_referencias br
                WHERE
                        br.dominio = 'TIP_IDE_CAS'
                    AND br.val_minimo = p_tip_ide_alias;

            EXCEPTION
                WHEN no_data_found THEN
                    v_existe := 'N';
                WHEN OTHERS THEN
                    v_existe := 'N';
            END;

            IF v_existe = 'N' THEN
                v_retorno.nombrerespuesta := 'PRO_'
                                             || v_cod_operacion
                                             || '_'
                                             || '15';
                v_retorno.descripcionrespuesta := 'Tipo identificador de alias incorrecto';
                v_retorno.error := 'S';
                paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null, v_cod_operacion, null
                ,
                                   v_parametros
                                   || ' '
                                   || paw_uti.fu_generarbitacora(v_retorno.error, v_retorno.nombrerespuesta, v_retorno.descripcionrespuesta, NULL
                                   ), paw_uti.bitacora_error);

                RETURN v_retorno;
            END IF;

            v_parametros := 'FU_PERALIAS: ' --TCE-200
                            || 'p_cod_persona: '
                            || v_cod_persona
                            || 'p_tip_ide_cli: '
                            || p_tip_ide_cli
                            || 'p_val_ide_cli: '
                            || p_val_ide_cli
                            || 'p_fec_ven_doc: '
                            || v_fec_vto_documento
                            || 'p_nombre: '
                            || v_nombre
                            || 'p_apellido: '
                            || v_apellido
                            || 'p_apodo: '
                            || v_apodo
                            || 'p_genero: '
                            || v_genero
                            || 'p_fec_nacimiento: '
                            || v_fec_nacimiento
                            || 'p_lugar_nacimiento: '
                            || v_lugar_nacimiento
                            || 'p_direccion: '
                            || v_direccion
                            || 'p_pais: '
                            || v_pais
                            || 'p_ciudad: '
                            || v_ciudad
                            || 'p_departamento: '
                            || v_departamento
                            || 'p_inf_adicional: '
                            || v_inf_adicional
                            || 'p_det_adicional_pv: '
                            || v_det_adicional_pv
                            || 'p_tip_ide_alias: '
                            || p_tip_ide_alias
                            || 'p_val_ide_alias: '
                            || p_val_ide_alias
                            || 'p_fec_registro: '
                            || v_fec_registro
                            || 'p_fec_ven_registro: '
                            || v_fec_ven_registro
                            || 'p_est_alias: '
                            || v_est_alias
                            || 'p_nro_cuenta: '
                            || p_nro_cuenta
                            || 'p_tip_cuenta: '
                            || v_tip_cuenta
                            || 'p_mon_cuenta: '
                            || v_mon_cuenta
                            || 'p_cod_swi_pte_solicitante: '
                            || v_cod_swi_pte_solicitante
                            || 'p_fec_ape_cuenta: '
                            || v_fec_ape_cuenta
                            || 'p_cta_defecto: '
                            || v_cta_defecto;

            paw_uti.pr_insertarbitacora(v_cod_persona, v_cod_canal, NULL, NULL, NULL,
                               v_parametros, paw_uti.bitacora_entrada);
            datosclie := typ_obtregclicas(NULL, v_cli_recor, p_tip_ide_cli, p_val_ide_cli, v_fec_vto_documento,
                                         NULL, v_nombre, rg_datperf.pri_apellido, v_apodo, v_genero,
                                         v_fec_nacimiento, v_lugar_nacimiento, v_direccion, v_pais, v_ciudad,
                                         v_departamento, v_inf_adicional, v_det_adicional_pv, NULL, 'U',
                                         NULL);

            datoscta := typ_insctacas(NULL, p_nro_cuenta, NULL, NULL, NULL,
                                     v_cod_persona, v_tip_cuenta, v_fec_ape_cuenta, NULL, v_mon_cuenta,
                                     v_cta_defecto, 'U', p_tip_ide_cli, p_val_ide_cli);

            r_deta.nro_referencia := NULL;
            r_deta.nro_cta_solicitante := p_nro_cuenta;
            r_deta.cli_recordid := NULL;
            r_deta.ali_recordid := NULL;
            r_deta.cod_persona := v_cod_persona;
            r_deta.fec_registro := v_fec_registro;
            r_deta.fec_ven_registro := v_fec_ven_registro;
            r_deta.cta_por_defecto := v_cta_defecto;
            r_deta.error := NULL;
            r_deta.est_solicitud := 'U';
            r_deta.tip_identificador := p_tip_ide_alias;
            r_deta.val_identificador := p_val_ide_alias;
            r_deta.est_alias := NULL;
            r_deta.cue_recordid := NULL;
            BEGIN
                SELECT
                    'S',
                    p.tipo
                INTO
                    v_existe_p,
                    v_tipo_per
                FROM
                    ba_personas p
                WHERE
                    p.cod_persona = v_cod_persona;

            EXCEPTION
                WHEN no_data_found THEN
                    v_existe_p := 'N';
                    v_tipo_per := NULL;
            END;

            IF v_existe_p = 'S' THEN
                BEGIN
                    SELECT
                        'S',
                        c.cli_recordid
                    INTO
                        v_existe_cli,
                        v_cli_recor
                    FROM
                        ge_spi_cli_cas c
                    WHERE
                            c.est_solicitud = 'A'
                        AND c.tip_identificador = p_tip_ide_cli
                        AND c.val_identificador = p_val_ide_cli;

                EXCEPTION
                    WHEN no_data_found THEN
                        v_existe_cli := 'N';
                        v_cli_recor := NULL;
                END;

                BEGIN
                    SELECT
                        'S',
                        cod_moneda,
                        c.relacion
                    INTO
                        v_exi_cta,
                        v_cod_moneda,
                        v_relacion
                    FROM
                        ge_cta_clientes c,
                        ge_cuentas      a
                    WHERE
                            c.nro_cuenta = a.nro_cuenta
                        AND a.cod_modulo IN ( 3, 4 )
                        AND a.estado IN ( 'A','D','S','I','N' ) --Modificado por TCE-45
                        AND a.nro_cuenta = p_nro_cuenta
                        AND c.cod_persona = v_cod_persona;

                EXCEPTION
                    WHEN no_data_found THEN
                        v_exi_cta := 'N';
                        v_cod_moneda := NULL;
                        v_relacion := NULL;
                    WHEN OTHERS THEN
                        v_exi_cta := 'N';
                        v_cod_moneda := NULL;
                        v_relacion := NULL;
                END;
         
                IF
                    v_exi_cta = 'S'
                    AND v_cod_moneda = 'GS'
                    AND 
             --NVB-2313 - Si es unipersonal debe entrar
                     ( v_relacion = 'P' OR nvl(fug_obt_naturaleza(v_cod_persona), 'N') = nvl(fug_obt_pardinamico('COD_NAT_UNIPERSONAL'
                    ), 'X') )
                THEN
                    BEGIN
                        SELECT
                            'S'
                        INTO v_existe_cta
                        FROM
                            ge_spi_cta_cas c
         /* TRFS-1099   where c.est_solicitud     in('A', 'U', 'P')  
         /* TRFS-1099*/ WHERE c.est_solicitud     in('A') --TCE-200
                            AND c.tip_identificador = p_tip_ide_cli
                            AND c.identificador = p_val_ide_cli
                            AND c.nro_cta_solicitante = p_nro_cuenta;

                    EXCEPTION
                        WHEN no_data_found THEN
                            v_existe_cta := 'N';
                    END; 
                    BEGIN
                        SELECT
                            'S'
                        INTO v_existe_ali
                        FROM
                            ge_spi_ali_cas c
                        WHERE
                            c.est_solicitud IN ( 'A', 'U', 'P' )
                            AND c.tip_identificador = p_tip_ide_alias
                            AND c.val_identificador = p_val_ide_alias
                            AND c.cod_persona = v_cod_persona;

                    EXCEPTION
                        WHEN no_data_found THEN
                            v_existe_ali := 'N';
                    END;

                    IF v_existe_ali = 'N' THEN
                        IF v_tipo_per = 'F' THEN
                            IF ( rg_datperf.pri_nombre IS NULL OR rg_datperf.pri_apellido IS NULL OR rg_datperf.cod_sexo IS NULL OR rg_datperf.fec_nacimiento
                            IS NULL /*or rg_datperf.cod_ciu_nacimiento is null*/ OR rg_datdir.direccion IS NULL OR rg_datdir.cod_pais
                            IS NULL OR rg_datdir.cod_ciudad IS NULL OR v_departamento IS NULL ) THEN
                                v_inserta := FALSE;
                            END IF;
                        ELSIF v_tipo_per = 'J' THEN
                            IF ( rg_datperj.raz_social IS NULL OR v_direccion IS NULL OR v_pais IS NULL OR v_ciudad IS NULL ) THEN
                                v_inserta := FALSE;
                            END IF;
                        END IF;

                        IF v_inserta THEN
                            g_lugar := 'registra cliente';
                             /*si el cliente ya se dio de alta no vuelve a generar la solicitud  */
                            IF v_existe_cli = 'N' THEN
                                pas_cas.pr_ins_clie_cas(datosclie, v_canal, p_tip_accion);
                            ELSE
                                pas_cas.pr_ini_variables;
                            END IF;

                            IF pas_cas.fu_obt_cod_error <> 0 THEN
                                v_retorno.nombrerespuesta := 'PRO_'
                                                             || v_cod_operacion
                                                             || '_'
                                                             || '2';
                                v_retorno.descripcionrespuesta := 'Error al regitrar solicitud de alta de cliente. '
                                                                  || pas_snp.fu_obt_cod_error
                                                                  || ' - '
                                                                  || pas_snp.fu_obt_msj_error;

                                v_retorno.error := 'S';
                                RETURN v_retorno;
                            ELSE
                                g_lugar := 'registra cuenta';
                                IF V_existe_cli ='N' THEN
                                    v_est_solicitud := 'P';
                                ELSE
                                    /*si el cliente ya se dio de alta la solicitud para el 
                                    alta de cuenta se registra con U  */
                                    v_est_solicitud := 'U';
                                END IF; 
                                /*si la cuenta del cliente ya se dio de alta 
                                 no vuelve a generar la solicitud  */
                                IF v_existe_cta = 'N' THEN
                                    datoscta := typ_insctacas(NULL, p_nro_cuenta, v_cli_recor, NULL, NULL,
                                                             v_cod_persona, v_tip_cuenta, v_fec_ape_cuenta, NULL, v_mon_cuenta,
                                                             p_cta_defecto, v_est_solicitud, p_tip_ide_cli, p_val_ide_cli);

                                    pas_cas.pr_ins_cta_cas(datoscta, v_canal, p_tip_accion);
                                ELSE
                                    pas_cas.pr_ini_variables;
                                END IF;

                                IF pas_cas.fu_obt_cod_error <> 0 THEN
                                    v_retorno.nombrerespuesta := 'PRO_'
                                                                 || v_cod_operacion
                                                                 || '_'
                                                                 || '3';
                                    v_retorno.descripcionrespuesta := 'Error al regitrar solicitud de Cuenta de cliente. '
                                                                      || pas_snp.fu_obt_cod_error
                                                                      || ' - '
                                                                      || pas_snp.fu_obt_msj_error;

                                    v_retorno.error := 'S';
                                    RETURN v_retorno;
                                ELSE
                                    g_lugar := 'registra alias';
									
                    /* TRFS-1099    if V_existe_cli ='N' THEN /*
                    /* TRFS-1099 */ IF V_existe_cli ='N' OR V_existe_cta ='N' THEN --TCE-200
                                        r_deta.est_solicitud := 'P';
                                    ELSE
                                     /*si el cliente ya se dio de alta la solicitud para el 
                                     alta de alias se registra con U  */
                                        r_deta.est_solicitud := 'U';
                                    END IF;

                                    r_deta.nro_referencia := NULL;
                                    r_deta.nro_cta_solicitante := p_nro_cuenta;
                                    r_deta.cli_recordid := v_cli_recor;
                                    r_deta.ali_recordid := NULL;
                                    r_deta.cod_persona := v_cod_persona;
                                    r_deta.fec_registro := v_fec_registro;
                                    r_deta.fec_ven_registro := v_fec_ven_registro;
                                    r_deta.cta_por_defecto := v_cta_defecto;
                                    r_deta.error := NULL;
                                    r_deta.tip_identificador := p_tip_ide_alias;
                                    r_deta.val_identificador := p_val_ide_alias;
                                    r_deta.est_alias := NULL;
                                    r_deta.cue_recordid := NULL;
                                    pas_cas.pr_ins_ali_cas(r_deta, v_canal, p_tip_accion);
                                    IF pas_cas.fu_obt_cod_error <> 0 THEN 
                                      --error de saldo insuficiente
                                        IF pas_snp.fu_obt_cod_error = 20 THEN
                                            v_retorno.nombrerespuesta := 'PRO_'
                                                                         || v_cod_operacion
                                                                         || '_'
                                                                         || '14';
                                            v_retorno.descripcionrespuesta := 'Error al regitrar solicitud de Cuenta de cliente. '
                                                                              || pas_snp.fu_obt_cod_error
                                                                              || ' - '
                                                                              || pas_snp.fu_obt_msj_error;

                                            v_retorno.error := 'S';
                                            paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null, v_cod_operacion
                                            , null,
                                                               v_parametros
                                                               || ' '
                                                               || paw_uti.fu_generarbitacora(v_retorno.error, v_retorno.nombrerespuesta, v_retorno.descripcionrespuesta
                                                               , NULL), paw_uti.bitacora_error);

                                            RETURN v_retorno;
                                        END IF;

                                        v_retorno.nombrerespuesta := 'PRO_'
                                                                     || v_cod_operacion
                                                                     || '_'
                                                                     || '4';
                                        v_retorno.descripcionrespuesta := 'Error al regitrar solicitud de Cuenta de cliente. '
                                                                          || pas_snp.fu_obt_cod_error
                                                                          || ' - '
                                                                          || pas_snp.fu_obt_msj_error;

                                        v_retorno.error := 'S';
                                        paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null, v_cod_operacion, null
                                        ,
                                                           v_parametros
                                                           || ' '
                                                           || paw_uti.fu_generarbitacora(v_retorno.error, v_retorno.nombrerespuesta, v_retorno.descripcionrespuesta
                                                           , NULL), paw_uti.bitacora_error);

                                        RETURN v_retorno;
                                    ELSE
                                        v_retorno.nombrerespuesta := '0';
                                        v_retorno.descripcionrespuesta := 'Solicitud registrada con exito. ';
                                        v_retorno.error := 'N';
                                        paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null, v_cod_operacion, null
                                        ,
                                                           v_parametros
                                                           || ' '
                                                           || paw_uti.fu_generarbitacora(v_retorno.error, v_retorno.nombrerespuesta, v_retorno.descripcionrespuesta
                                                           , NULL), paw_uti.bitacora_error);

                                        RETURN v_retorno;
                                    END IF;

                                END IF;

                            END IF;

                        ELSE
                            v_retorno.nombrerespuesta := 'PRO_'
                                                         || v_cod_operacion
                                                         || '_'
                                                         || '5';
                            v_retorno.descripcionrespuesta := 'Uno o mas campos necesarios son nulos';
                            v_retorno.error := 'S';
                            RETURN v_retorno;
                        END IF;

                    ELSE
                        v_retorno.nombrerespuesta := 'PRO_'
                                                     || v_cod_operacion
                                                     || '_'
                                                     || '6';
                        v_retorno.descripcionrespuesta := 'El alias/cuenta ya existe en el módulo CAS';
                        v_retorno.error := 'S';
                        paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null, v_cod_operacion, null
                        ,
                                           v_parametros
                                           || ' '
                                           || paw_uti.fu_generarbitacora(v_retorno.error, v_retorno.nombrerespuesta, v_retorno.descripcionrespuesta
                                           , NULL), paw_uti.bitacora_error);

                        RETURN v_retorno;
                    END IF;


                ELSIF
                    v_exi_cta = 'S'
                    AND v_cod_moneda <> 'GS'
                    AND v_relacion = 'P'
                THEN
                    v_retorno.nombrerespuesta := 'PRO_'
                                                 || v_cod_operacion
                                                 || '_'
                                                 || '8';
                    v_retorno.descripcionrespuesta := 'La cuenta debe ser en guaranies.';
                    paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null, v_cod_operacion, null
                    ,
                                       v_parametros
                                       || ' '
                                       || paw_uti.fu_generarbitacora(v_retorno.error, v_retorno.nombrerespuesta, v_retorno.descripcionrespuesta
                                       , NULL), paw_uti.bitacora_error);

                    v_retorno.error := 'S';
                    RETURN v_retorno;
                ELSIF
                    v_exi_cta = 'S'
                    AND v_cod_moneda = 'GS'
                    AND v_relacion <> 'P'
                THEN
                    v_retorno.nombrerespuesta := 'PRO_'
                                                 || v_cod_operacion
                                                 || '_'
                                                 || '9';
                    v_retorno.descripcionrespuesta := 'El cliente no es titular de la cuenta.';
                    paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null, v_cod_operacion, null
                    ,
                                       v_parametros
                                       || ' '
                                       || paw_uti.fu_generarbitacora(v_retorno.error, v_retorno.nombrerespuesta, v_retorno.descripcionrespuesta
                                       , NULL), paw_uti.bitacora_error);

                    v_retorno.error := 'S';
                    RETURN v_retorno;
                ELSIF v_exi_cta = 'N' THEN
                    v_retorno.nombrerespuesta := 'PRO_'
                                                 || v_cod_operacion
                                                 || '_'
                                                 || '10';
                    v_retorno.descripcionrespuesta := 'la cuenta no existe o no se encuentra activo.';
                    paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null, v_cod_operacion, null
                    ,
                                       v_parametros
                                       || ' '
                                       || paw_uti.fu_generarbitacora(v_retorno.error, v_retorno.nombrerespuesta, v_retorno.descripcionrespuesta
                                       , NULL), paw_uti.bitacora_error);

                    v_retorno.error := 'S';
                    RETURN v_retorno;
                END IF;

            ELSIF v_existe_p = 'N' THEN
                v_retorno.nombrerespuesta := 'PRO_'
                                             || v_cod_operacion
                                             || '_'
                                             || '12';
                v_retorno.descripcionrespuesta := 'El Cliente no existe. Favor dar de alta';
                v_retorno.error := 'S';
                RETURN v_retorno;
            END IF;

        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            v_retorno.nombrerespuesta := 'PRO_'
                                         || v_cod_operacion
                                         || '_'
                                         || '13';
            v_retorno.descripcionrespuesta := substr(sqlerrm, 1, 2000);
            v_retorno.error := 'S';
            paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null, v_cod_operacion, null
            ,
                               v_parametros
                               || ' '
                               || paw_uti.fu_generarbitacora(v_retorno.error, v_retorno.nombrerespuesta, v_retorno.descripcionrespuesta, NULL
                               ), paw_uti.bitacora_error);

            RETURN v_retorno;
    END fu_sol_per_alias;
------------------------------------------------------------------------------------------------------------

FUNCTION fu_eliminar_alias(p_cod_persona      in varchar2,
                           p_modo          in varchar2 default 'A',
                           p_ali_record_id in varchar2,
                           p_cta_record_id in varchar2,
                           p_accion        in varchar2 default 'ELI') return typ_solicitudaltacas is
  
    v_retorno             typ_solicitudaltacas := typ_solicitudaltacas;
    r_deta                ge_spi_ali_cas%rowtype;
    v_mensajeCaja         typ_mensajeCaja;
    v_cod_persona          ba_personas.cod_persona%type;
    v_cod_operacion        constant varchar2(03) := '042';   
    v_permiso              typ_obtenerPermisos;
    TRP_TRA_INVALIDA       CONSTANT VARCHAR2(15) := 'TRP_TRA_INVALID';
    TRP_SIN_PERMISO        CONSTANT VARCHAR2(15) := 'TRP_SIN_PERMISO';
    v_parametros          varchar2(4000) := null;
    v_error             varchar2(1):='N'; 
    v_msj_error           varchar2(2000):=null;
    /*variables de cta*/
    datoscta       typ_insctacas;  --BWP-1002  
    v_nro_ref_cta             ge_spi_cta_cas.nro_referencia%type;
    v_nro_cta_solicitante     ge_spi_cta_cas.nro_cta_solicitante%type;
    v_cli_recordid_cta        ge_spi_cta_cas.cli_recordid%type;
    v_cta_recordid_cta        ge_spi_cta_cas.cta_recordid%type;
    v_ali_recordid_cta        ge_spi_cta_cas.ali_recordid%type;
    v_tip_cuenta              ge_spi_cta_cas.tip_cuenta%type;
    v_fec_apertura            ge_spi_cta_cas.fec_apertura%type;
    v_fec_cancelacion         ge_spi_cta_cas.fec_cancelacion%type;
    v_moneda                  ge_spi_cta_cas.moneda%type;
    v_cta_por_defecto         ge_spi_cta_cas.cta_por_defecto%type;
    v_est_sol_cta             ge_spi_cta_cas.est_solicitud%type;
    v_tip_ident_cta           ge_spi_cta_cas.tip_identificador%type;
    v_identificador           ge_spi_cta_cas.identificador%type;
    v_est_solicitud       	  ge_spi_cli_cas.est_solicitud%type;
  begin

     /*
     Seteamos el valor del campo codigoUsuario y persona
     */
    v_cod_persona := p_cod_persona;
    
    v_parametros := 'p_cod_persona: '   || p_cod_persona || chr(13)||
                    'p_modo: '          || p_modo || chr(13)||
                    'p_ali_record_id: ' || p_ali_record_id || chr(13)||
                    'p_accion: '        || p_accion;
    
    if p_modo = 'A'  then
      begin
        select *
          into r_deta
          from ge_spi_ali_cas t
         where ali_recordid = p_ali_record_id;
      exception
        when no_data_found then
          v_error:= 'S'; 
          v_msj_error:= 'No se encuentra datos-ali_record_id :'||p_ali_record_id;
        when others then
          v_error:='S';
          v_msj_error:='Ocurrio un error al obtener datos-ali_record_id:'||p_ali_record_id;
      end;
     if nvl(v_error,'N')='S' then
       v_retorno.nombreRespuesta := 'PRO_'||v_cod_operacion||'_'||'1';
       v_retorno.descripcionRespuesta := 'Error al obtener datos ali_recordid-'||v_msj_error;
       v_retorno.error := 'S';
       paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null, v_cod_operacion, null, v_parametros || ' ' || paw_uti.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.bitacora_error);        
       return v_retorno; 
     else
      v_parametros := 'nro_referencia: '      || r_deta.nro_referencia || chr(13)||
                      'tip_identificador: '   || r_deta.tip_identificador || chr(13)||
                      'val_identificador: '   || r_deta.val_identificador || chr(13)||
                      'cod_persona: '         || v_cod_persona || chr(13)||
                      'fec_registro: '        || r_deta.fec_registro|| chr(13)||
                      'fec_ven_registro: '    || r_deta.fec_ven_registro || chr(13)||
                      'nro_cta_solicitante: ' || r_deta.nro_cta_solicitante || chr(13)||
                      'est_alias: '           || r_deta.est_alias || chr(13)||
                      'cli_recordid: '        || r_deta.cli_recordid || chr(13)||
                      'ali_recordid: '        || r_deta.ali_recordid || chr(13)||
                      'cue_recordid: '        || r_deta.cue_recordid || chr(13)||
                      'cta_por_defecto: '     || r_deta.cta_por_defecto || chr(13)||
                      'error: '               || r_deta.error;
    
      paw_uti.pr_insertarbitacora(v_cod_persona, g_codCanal, null, null, null, v_parametros, paw_uti.bitacora_entrada);
      /*datos de cuenta*/--BWP-1002
      begin
        SELECT c.nro_referencia, nro_cta_solicitante, cli_recordid,
                cta_recordid, ali_recordid,c.cod_persona, tip_cuenta, fec_apertura,
                fec_cancelacion,moneda,cta_por_defecto,est_solicitud,
                c.tip_identificador,identificador  
        INTO v_nro_ref_cta, v_nro_cta_solicitante, v_cli_recordid_cta,
              v_cta_recordid_cta, v_ali_recordid_cta,v_cod_persona ,v_tip_cuenta, v_fec_apertura,
              v_fec_cancelacion,v_moneda,v_cta_por_defecto,v_est_sol_cta,
              v_tip_ident_cta,v_identificador
        FROM ge_spi_cta_cas c
        WHERE c.cta_recordid = p_cta_record_id;  
      exception
        when no_data_found then
          v_nro_ref_cta           := null ; 
          v_nro_cta_solicitante   := null ;
          v_cli_recordid_cta      := null ;
          v_cta_recordid_cta      := null ;
          v_ali_recordid_cta      := null ;
          v_cod_persona           := null ;
          v_tip_cuenta            := null ;
          v_fec_apertura          := null ;
          v_fec_cancelacion       := null ;
          v_moneda                := null ;
          v_cta_por_defecto       := null ;
          v_est_sol_cta           := null ;
          v_tip_ident_cta         := null ;
          v_identificador         := null ;
         
      end;
      
      datoscta   := typ_insctacas(v_nro_ref_cta, v_nro_cta_solicitante, v_cli_recordid_cta,
                  v_cta_recordid_cta, v_ali_recordid_cta,v_cod_persona ,v_tip_cuenta, v_fec_apertura,
                  v_fec_cancelacion,v_moneda,v_cta_por_defecto,v_est_solicitud,
                  v_tip_ident_cta,v_identificador);  
      if nvl(v_retorno.error, 'N') = 'N' then
        it.pas_cas.pr_edi_ali_cas(r_deta, p_accion, 'WEBE');--BWP-971
        
       if pas_cas.fu_obt_cod_error <> 0 then
          v_retorno.nombreRespuesta := 'PRO_'||v_cod_operacion||'_'||'1';
          v_retorno.descripcionRespuesta := 'Error al regitrar solicitud de eliminacion de alias '||pas_cas.fu_obt_cod_error || ' - ' ||pas_cas.fu_obt_msj_error;
          paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null, v_cod_operacion, null, v_parametros || ' ' || paw_uti.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.bitacora_error);
          v_retorno.error := 'S';        
        return v_retorno;    
       else
          --'Solicitud edicion Cuenta';
          pas_cas.pr_edi_cta_cas(datoscta, p_accion, 'WEBE');--BWP-1002
          
           if  pas_cas.fu_obt_cod_error <> 0 then                    
                
                 v_retorno.nombreRespuesta := 'PRO_'||v_cod_operacion||'_'||'1';
                 v_retorno.descripcionRespuesta := 'Error al regitrar solicitud de elinacion de cuenta-'||pas_cas.fu_obt_cod_error ||' - ' ||pas_cas.fu_obt_msj_error;
                 paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null, v_cod_operacion, null, v_parametros || ' ' || paw_uti.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.bitacora_error);     
                 v_retorno.error := 'S';   
                 return v_retorno;                
           end if;          
        end if ;
      end if;
    end if;
  end if;
    if nvl(v_retorno.error, 'N') = 'N' then
      v_retorno.nombreRespuesta      := '0';
      v_retorno.descripcionRespuesta := 'Solicitud de eliminacion registrada con exito.';
      paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null, v_cod_operacion, null, v_parametros || ' ' || paw_uti.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.bitacora_error);
      v_retorno.error                := 'N';
      return v_retorno;
    end if;
  
  exception
    WHEN others THEN
        v_retorno.nombreRespuesta     :='PRO_'||v_cod_operacion||'_'||'1';
        v_retorno.descripcionRespuesta:=substr(sqlerrm,1,2000);
        v_retorno.error               :='S';
        paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null, v_cod_operacion, null, v_parametros || ' ' || paw_uti.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.bitacora_error); 
        return v_retorno;
  end fu_eliminar_alias;
------------------------------------------------------------------------------------------------------------  
  FUNCTION fu_Soli_edicion_alias(p_cli_recorid in varchar2,
                              p_cta_recorid in varchar2,
                              p_ali_recorid in varchar2,
                              p_accion      in varchar2) return typ_solicitudPagoSpi is
  
  v_retorno      typ_solicitudPagoSpi := typ_solicitudPagoSpi;               
  datosclie      typ_obtregclicas;    
  datoscta       typ_insctacas;    
  r_deta	       GE_SPI_ALI_CAS%ROWTYPE;  
  
  v_parametros   varchar2(4000):= null;
  
  v_cod_canal    varchar2(3); 
  g_lugar        varchar2(50); 
 
  /*variables de cliente*/
  v_nro_referencia      ge_spi_cli_cas.nro_referencia%type      ;
  v_cli_recordID        ge_spi_cli_cas.cli_recordID%type        ;
  v_tip_iden_cli        ge_spi_cli_cas.tip_identificador%type   ;
  v_val_iden_cli        ge_spi_cli_cas.val_identificador%type   ;
  v_fec_vto_documento   ge_spi_cli_cas.fec_vto_documento%type   ;
  v_residencia          ge_spi_cli_cas.residencia%type          ;
  v_nombre              ge_spi_cli_cas.nombre%type              ;
  v_apellido            ge_spi_cli_cas.apellido%type            ;
  v_apodo               ge_spi_cli_cas.apodo%type               ;
  v_genero              ge_spi_cli_cas.genero%type              ;
  v_fec_nacimiento      ge_spi_cli_cas.fec_nacimiento%type      ;
  v_lugar_nacimiento    ge_spi_cli_cas.lugar_nacimiento%type    ;
  v_direccion           ge_spi_cli_cas.direccion%type           ;
  v_pais                ge_spi_cli_cas.pais%type                ;
  v_ciudad              ge_spi_cli_cas.ciudad%type              ;
  v_departamento        ge_spi_cli_cas.departamento%type        ;
  v_inf_adicional       ge_spi_cli_cas.inf_adicional%type       ;
  v_det_adicional_pv    ge_spi_cli_cas.det_adicional_pv%type    ;
  v_est_cliente         ge_spi_cli_cas.est_cliente%type         ;
  v_est_solicitud       ge_spi_cli_cas.est_solicitud%type       ;
  v_cod_persona         ge_spi_cli_cas.cod_persona%type         ;
  /*variables de cta*/
  v_nro_ref_cta             ge_spi_cta_cas.nro_referencia%type;
  v_nro_cta_solicitante     ge_spi_cta_cas.nro_cta_solicitante%type;
  v_cli_recordid_cta        ge_spi_cta_cas.cli_recordid%type;
  v_cta_recordid_cta        ge_spi_cta_cas.cta_recordid%type;
  v_ali_recordid_cta        ge_spi_cta_cas.ali_recordid%type;
  v_tip_cuenta              ge_spi_cta_cas.tip_cuenta%type;
  v_fec_apertura            ge_spi_cta_cas.fec_apertura%type;
  v_fec_cancelacion         ge_spi_cta_cas.fec_cancelacion%type;
  v_moneda                  ge_spi_cta_cas.moneda%type;
  v_cta_por_defecto         ge_spi_cta_cas.cta_por_defecto%type;
  v_est_sol_cta             ge_spi_cta_cas.est_solicitud%type;
  v_tip_ident_cta           ge_spi_cta_cas.tip_identificador%type;
  v_identificador           ge_spi_cta_cas.identificador%type;
  /*variables alias*/
  v_nro_ref_ali             ge_spi_ali_cas.nro_referencia%type;
  v_tip_iden_ali            ge_spi_ali_cas.tip_identificador%type;
  v_val_iden_ali            ge_spi_ali_cas.val_identificador%type;
  v_fec_registro            ge_spi_ali_cas.fec_registro%type;
  v_fec_ven_registro        ge_spi_ali_cas.fec_ven_registro%type;
  v_nro_cta_soli_ali        ge_spi_ali_cas.nro_cta_solicitante%type;
  v_est_alias               ge_spi_ali_cas.est_alias%type;
  v_est_sol_al              ge_spi_ali_cas.est_solicitud%type;
  v_cli_recordid_ali        ge_spi_ali_cas.cli_recordid%type;
  v_ali_recordid_ali        ge_spi_ali_cas.ali_recordid%type;
  v_cue_recordid_ali        ge_spi_ali_cas.cue_recordid%type;
  v_cta_por_defecto_ali     ge_spi_ali_cas.cta_por_defecto%type;
  
  BEGIN
  
      --No existe canal para personas, se pasa la variable como nulo para los llamados a edicion del alias
      v_cod_canal       := null; 
      
      v_parametros:= 'fu_Soli_edicion_alias: '
                    ||'p_cli_recorid: '    || p_cli_recorid 
                    ||'p_cta_recorid: '    || p_cta_recorid     
                    ||'p_ali_recorid: '    || p_ali_recorid     
                    ||'p_accion: '         || p_accion; 
                    
       /*datos de cliente*/             
        begin
          select nro_referencia,cli_recordID,tip_identificador, val_identificador, 
                fec_vto_documento,residencia,nombre,apellido,apodo,genero,fec_nacimiento,   
                lugar_nacimiento, direccion,pais,ciudad,departamento,inf_adicional,
                det_adicional_pv,est_cliente,est_solicitud, c.cod_persona    
          into v_nro_referencia,v_cli_recordID,v_tip_iden_cli, v_val_iden_cli, 
                v_fec_vto_documento,v_residencia,v_nombre,v_apellido,v_apodo,v_genero,v_fec_nacimiento,   
                v_lugar_nacimiento, v_direccion,v_pais,v_ciudad,v_departamento,v_inf_adicional,
                v_det_adicional_pv,v_est_cliente,v_est_solicitud, v_cod_persona 
          from ge_spi_cli_cas c
          where c.cli_recordid= p_cli_recorid;
        exception
          when no_data_found then
            v_nro_referencia    := null;
            v_cli_recordID          := null;
            v_tip_iden_cli          := null;
            v_val_iden_cli          := null;
            v_fec_vto_documento     := null;
            v_residencia            := null;
            v_nombre              := null;
            v_apellido            := null;
            v_apodo               := null;
            v_genero              := null;
            v_fec_nacimiento        := null;
            v_lugar_nacimiento      := null;
            v_direccion             := null;
            v_pais                := null;
            v_ciudad              := null;
            v_departamento          := null;
            v_inf_adicional         := null;
            v_det_adicional_pv      := null;
            v_est_cliente           := null;
            v_est_solicitud         := null;
        end;
        
        paw_uti.pr_insertarbitacora(v_cod_persona, v_cod_canal, null,null,
                               null,v_parametros,paw_uti.bitacora_entrada);
       /*datos de cuenta*/
        begin
          SELECT c.nro_referencia, nro_cta_solicitante, cli_recordid,
                  cta_recordid, ali_recordid,c.cod_persona, tip_cuenta, fec_apertura,
                  fec_cancelacion,moneda,cta_por_defecto,est_solicitud,
                  c.tip_identificador,identificador  
          INTO v_nro_ref_cta, v_nro_cta_solicitante, v_cli_recordid_cta,
                v_cta_recordid_cta, v_ali_recordid_cta,v_cod_persona ,v_tip_cuenta, v_fec_apertura,
                v_fec_cancelacion,v_moneda,v_cta_por_defecto,v_est_sol_cta,
                v_tip_ident_cta,v_identificador
          FROM GE_SPI_CTA_CAS C
          WHERE C.CTA_RECORDID = p_cta_recorid;  
        exception
          when no_data_found then
            v_nro_ref_cta           := null ; 
            v_nro_cta_solicitante   := null ;
            v_cli_recordid_cta      := null ;
            v_cta_recordid_cta      := null ;
            v_ali_recordid_cta      := null ;
            v_cod_persona           := null ;
            v_tip_cuenta            := null ;
            v_fec_apertura          := null ;
            v_fec_cancelacion       := null ;
            v_moneda                := null ;
            v_cta_por_defecto       := null ;
            v_est_sol_cta           := null ;
            v_tip_ident_cta         := null ;
            v_identificador         := null ;
           
        end;
        /*datos de alias*/
        begin
          select c.nro_referencia,c.tip_identificador,c.val_identificador,c.cod_persona,    
                fec_registro,fec_ven_registro,nro_cta_solicitante,
                est_alias,est_solicitud,cli_recordid,ali_recordid,
                cue_recordid,cta_por_defecto 
                 
          into  v_nro_ref_ali,v_tip_iden_ali,v_val_iden_ali,v_cod_persona,   
                v_fec_registro,v_fec_ven_registro,v_nro_cta_solicitante,
                v_est_alias,v_est_solicitud,v_cli_recordid_ali,v_ali_recordid_ali,
                v_cue_recordid_ali,v_cta_por_defecto_ali  
          from ge_spi_ali_cas c
          where c.ali_recordid= p_ali_recorid;
        exception
          when no_data_found then
          v_nro_ref_ali         := null ;
          v_tip_iden_ali        := null ;
          v_val_iden_ali        := null ; 
          v_fec_registro        := null ;
          v_fec_ven_registro    := null ;
          v_nro_cta_solicitante := null ;
          v_est_alias           := null ;
          v_est_solicitud       := null ;
          v_cli_recordid_ali    := null ;
          v_ali_recordid_ali    := null ;
          v_cue_recordid_ali    := null ;
          v_cta_por_defecto_ali := null ;
            
        end ;        
        
        datosclie  := typ_obtregclicas(v_nro_referencia,v_cli_recordID,v_tip_iden_cli,
                       v_val_iden_cli,v_fec_vto_documento,v_residencia,v_nombre,v_apellido,
                       v_apodo,v_genero,v_fec_nacimiento,v_lugar_nacimiento,v_direccion,v_pais,
                       v_ciudad,v_departamento,v_inf_adicional,v_det_adicional_pv,v_est_cliente,
                       v_est_solicitud,null); 
                       
        datoscta   := typ_insctacas(v_nro_ref_cta, v_nro_cta_solicitante, v_cli_recordid_cta,
                      v_cta_recordid_cta, v_ali_recordid_cta,v_cod_persona ,v_tip_cuenta, v_fec_apertura,
                      v_fec_cancelacion,v_moneda,v_cta_por_defecto,v_est_solicitud,
                      v_tip_ident_cta,v_identificador);  
                      
                     
        r_deta.nro_referencia         := v_nro_ref_ali;
        r_deta.tip_identificador      := v_tip_iden_ali;
        r_deta.val_identificador      := v_val_iden_ali;
        r_deta.cod_persona            := v_cod_persona;    
        r_deta.fec_registro           := v_fec_registro;
        r_deta.fec_ven_registro       := v_fec_ven_registro;
        r_deta.nro_cta_solicitante    := v_nro_cta_solicitante;
        r_deta.est_alias              := v_est_alias;
        r_deta.est_solicitud          := v_est_solicitud;
        r_deta.cli_recordid           := v_cli_recordid_ali;
        r_deta.ali_recordid           := v_ali_recordid_ali;
        r_deta.cue_recordid           := v_cue_recordid_ali;
        r_deta.cta_por_defecto        := v_cta_por_defecto_ali;                                         
                                   
       
       if v_nro_referencia is not null and 
          v_nro_ref_cta is not null    and  
          v_nro_ref_ali is not null  then
          g_lugar :='solicitud  edicion alias';
          pas_cas.pr_edi_ali_cas(r_deta,p_accion,v_cod_canal);
            if  pas_cas.fu_obt_cod_error <> 0 then                    
                    v_retorno.nombreRespuesta := '2';
                    v_retorno.descripcionRespuesta := 'Error al regitrar solicitud de edicion de cuenta . '|| 'en '||g_lugar||' Cod_error: ' ||pas_cas.fu_obt_cod_error ||
                                                       ' - ' ||pas_cas.fu_obt_msj_error;
                    v_retorno.error :='S';
                    return v_retorno; 
            else
              g_lugar:='Solicitud edicion Cuenta';
              pas_cas.pr_edi_cta_cas(datoscta,p_accion,v_cod_canal);
              
               if  pas_cas.fu_obt_cod_error <> 0 then                    
                    v_retorno.nombreRespuesta := '3';
                    v_retorno.descripcionRespuesta := 'Error al regitrar solicitud de edicion de cuenta . '|| 'en '||g_lugar||' Cod_error: ' ||pas_cas.fu_obt_cod_error ||
                                                       ' - ' ||pas_cas.fu_obt_msj_error;
                    v_retorno.error :='S';
                    return v_retorno; 
               else  
                 
                    v_retorno.nombreRespuesta := '0';
                    v_retorno.descripcionRespuesta := 'Solicitud de edicion registrada con exito. ';
                    v_retorno.error :='N';
                    return v_retorno;                    
               end if;          
            end if ;
       else
             v_retorno.nombreRespuesta     :=1;
             v_retorno.descripcionRespuesta:='No se registran datos para la solicitud de Edición';
             v_retorno.error               :='S';
             return v_retorno;
       end if; 
    EXCEPTION
            WHEN others THEN
             v_retorno.nombreRespuesta     :=1;
             v_retorno.descripcionRespuesta:=substr(sqlerrm,1,2000);
             v_retorno.error               :='S';
             return v_retorno;       
    
    end fu_Soli_edicion_alias;  
 ------------------------------------------------------------------------------------------------------------ 
  FUNCTION fu_sol_con_persona(p_cod_persona      in varchar2,
                              p_tip_consulta  IN VARCHAR2,
                              p_tip_identificador IN VARCHAR2,
                              p_val_identificador IN VARCHAR2)
  RETURN typ_sol_con_cas 
  is
   
      v_retorno  typ_sol_con_cas := typ_sol_con_cas;  
      v_msj_bitacora             varchar2(700);
      v_cod_persona              ba_personas.cod_persona%type;
      v_nro_referencia           GE_SPI_CON_CAS.nro_referencia%type;
      c_op_error              CONSTANT VARCHAR2(20) := 'PRO_ERR_SOL_CON_CAS';
  
  begin

    v_cod_persona:=p_cod_persona;
   
    
    v_msj_bitacora  := 'fu_sol_con_cas: g_codCanal: ' || g_codCanal ||' p_tip_consulta: '||p_tip_consulta || ' p_tip_identificador: '||p_tip_identificador
    || ' p_val_identificador: '||p_val_identificador || ' v_cod_persona: '||v_cod_persona;

    paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null, v_cod_operacion,null,
                        v_msj_bitacora ,
                        paw_uti.bitacora_entrada);
    
    

      declare
        v_cod_retorno       number  := 1;
        v_men_retorno       varchar2(2000);
        v_nom_respuesta     VARCHAR2(100);
      begin
       pas_cas.pr_ins_consul_cas(p_tip_consulta => p_tip_consulta,
                               p_tip_identificador => p_tip_identificador,
                               p_val_identificador => p_val_identificador,
                               p_cod_persona => v_cod_persona,
                               p_nro_referencia => v_nro_referencia);

        --Si es distinto a 0, entonces hay error    
        v_cod_retorno:= pas_cas.fu_obt_cod_error;
        v_men_retorno:= pas_cas.fu_obt_msj_error;                
        if v_cod_retorno != 0 then
          v_msj_bitacora:=v_msj_bitacora||' '||'fu_sol_con_cas: '||v_men_retorno;
          paw_uti.pr_mensajeUsuario(c_op_error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
          paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null,null, null, v_msj_bitacora || ' ' || paw_uti.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.bitacora_error);
          RETURN v_retorno;
        else
          v_retorno.nro_referencia := v_nro_referencia;
          v_retorno.nombreRespuesta := '0';
          v_retorno.descripcionRespuesta := 'Solicitud registrada con exito. ';
          v_retorno.error :='N';
          paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null, v_cod_operacion, null, v_msj_bitacora || ' ' || paw_uti.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.bitacora_error);
          return v_retorno; 
        end if;
       
      end;
    RETURN v_retorno;
    
    EXCEPTION
      WHEN others THEN
         v_retorno.nombreRespuesta     :=1;
         v_retorno.descripcionRespuesta:=substr(sqlerrm,1,2000);
         v_retorno.error               :='S';
         paw_uti.pr_insertarbitacora(p_cod_persona,g_codCanal, null,v_cod_operacion,null,
                             paw_uti.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta,v_retorno.descripcionRespuesta, NULL),
                             paw_uti.bitacora_error);
         return v_retorno;
  end fu_sol_con_persona;
 ------------------------------------------------------------------------------------------------------------   
 
 FUNCTION fu_res_con_persona(p_cod_persona    IN VARCHAR2,
                             p_nro_referencia IN VARCHAR2)
   return typ_res_con_cas is
  v_retorno  typ_res_con_cas := typ_res_con_cas;  
  v_msj_bitacora             varchar2(700);
  v_cod_persona              ba_personas.cod_persona%type;
  v_nro_referencia           ge_spi_con_cas.nro_referencia%type;
  c_op_error              CONSTANT VARCHAR2(20) := 'PRO_ERR_RES_CON_CAS';
  rg_datconcas            ge_spi_res_cas%rowtype;
  
  begin

    v_cod_persona:=p_cod_persona;
   
    v_msj_bitacora  := 'fu_res_con_cas: g_codCanal: ' || g_codCanal ||' p_nro_referencia: '||p_nro_referencia  || ' v_cod_persona: '||v_cod_persona;

    paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null, v_cod_operacion,null,
                        v_msj_bitacora ,
                        paw_uti.bitacora_entrada);

      declare
        v_cod_retorno       number  := 0;
        v_men_retorno       varchar2(2000);
        v_nom_respuesta     VARCHAR2(100);
      begin
               begin
                select *
                  into rg_datconcas
                  from ge_spi_res_cas res
                 where res.nro_referencia  = p_nro_referencia;
              exception
                when no_data_found then
                 v_cod_retorno:=1;
                 v_men_retorno:='No se encuentra datos consulta '||p_nro_referencia;
                 null;
                when others then
                  v_cod_retorno:=1;
                 v_men_retorno:='Ocurrio un error al obtener datos de consulta:'||p_nro_referencia||' '||sqlerrm;
                 null;
              end;
                
        if v_cod_retorno != 0 then
          v_msj_bitacora:=v_msj_bitacora||' '||'fu_res_con_cas: '||v_men_retorno;
          paw_uti.pr_mensajeUsuario(c_op_error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
          paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null,null, null, v_msj_bitacora || ' ' || paw_uti.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.bitacora_error);
          RETURN v_retorno;
        else
           -- Devuelve los datos 
              v_retorno.error:=0;
              v_retorno.nombreRespuesta:=null;
               v_retorno.descripcionRespuesta:=null;
              v_retorno.tip_doc_cliente:=rg_datconcas.tip_doc_cliente;
              v_retorno.nro_doc_cliente:=rg_datconcas.nro_doc_cliente;
              v_retorno.nombre :=rg_datconcas.nombre;
              v_retorno.apellido:=rg_datconcas.apellido;
              v_retorno.nro_cuenta:=rg_datconcas.nro_cuenta;
              v_retorno.cod_mon_cta:=rg_datconcas.cod_mon_cta;
              v_retorno.tip_cuenta:=rg_datconcas.tip_cuenta;
              v_retorno.cod_swi_participante:=rg_datconcas.cod_swi_participante;
              v_retorno.nom_swi_participante:=pas_snp.fu_obt_des_participante(rg_datconcas.cod_swi_participante);
              v_retorno.err_cas :=rg_datconcas.error;
             RETURN v_retorno;
        end if;
       
      end;
    
    
    EXCEPTION
      WHEN others THEN
         v_retorno.nombreRespuesta     :=1;
         v_retorno.descripcionRespuesta:=substr(sqlerrm,1,2000);
         v_retorno.error               :='S';
         paw_uti.pr_insertarbitacora(p_cod_persona,g_codCanal, null,v_cod_operacion,null,
                             paw_uti.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta,v_retorno.descripcionRespuesta, NULL),
                             paw_uti.bitacora_error);
         return v_retorno;
  end fu_res_con_persona; 
 ------------------------------------------------------------------------------------------------------------   
  FUNCTION fu_obt_lis_alias_spi (p_cod_persona IN VARCHAR2) 
  RETURN typ_lisaliasspi IS

        c_cod_operacion  CONSTANT VARCHAR2(03) := '107';
        v_retorno        typ_lisaliasspi := typ_lisaliasspi;
        v_permiso        typ_obtenerpermisos;
        v_listaspi       typ_listaaliasspi := typ_listaaliasspi();
        v_msj_bitacora   VARCHAR2(700);
        CURSOR c_datos (
            p_cod_per_solicitante ge_spi_ali_cas.cod_persona%TYPE,
            p_alias               VARCHAR2
        ) IS
        SELECT
            cli_recordid,
            tip_identificador,-- (email,cedula,telefono)
            val_identificador,
            ali_recordid,
            cue_recordid,
            nro_cta_solicitante,
            est_solicitud
        FROM
            ge_spi_ali_cas     cas,
            ba_cod_referencias b
        WHERE
                cas.cod_persona = p_cod_per_solicitante
            AND cas.tip_identificador = b.val_minimo
            AND b.dominio = 'TIP_IDE_CAS'
            AND cas.est_solicitud IN ( 'U', 'A', 'P' )--BWP-946--BWP-970
            AND b.val_minimo = p_alias
            AND cas.nro_referencia = (
                SELECT
                    MAX(c.nro_referencia)
                FROM
                    ge_spi_ali_cas c
                WHERE
                        c.tip_identificador = p_alias
                    AND c.cod_persona = p_cod_per_solicitante
            )
        ORDER BY
            cas.fec_insercion DESC;
  --BWP-778
        CURSOR c_tip_alias IS
        SELECT
            r.val_minimo
        FROM
            ba_cod_referencias r
        WHERE
            r.dominio = 'TIP_IDE_CAS';

    BEGIN

        FOR alias IN c_tip_alias LOOP--BWP-778
            FOR dato IN c_datos(p_cod_persona, alias.val_minimo) LOOP
                DECLARE
                    detallecasspi typ_aliaslistadospi := typ_aliaslistadospi;
                    v_cod_retorno NUMBER := 1;
                    v_men_retorno VARCHAR2(2000);
                BEGIN
                    detallecasspi.cli_recordid := dato.cli_recordid;
                    detallecasspi.tip_identificador := dato.tip_identificador;
                    detallecasspi.val_identificador := dato.val_identificador;
                    detallecasspi.ali_recordid := dato.ali_recordid;
                    detallecasspi.cue_recordid := dato.cue_recordid;
                    detallecasspi.nro_cta_solicitante := dato.nro_cta_solicitante;
                    detallecasspi.est_solicitud := dato.est_solicitud;
                    v_listaspi.extend;
                    v_listaspi(v_listaspi.count) := detallecasspi;
                END;
            END LOOP;
        END LOOP;

        v_msj_bitacora := substr('CantRegistros:' || v_listaspi.count, 1, 200);
        paw_uti.pr_mensajeUsuario(msg_ok, v_retorno.nombrerespuesta, v_retorno.descripcionrespuesta, v_retorno.error);
        paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null, c_cod_operacion, null,
                           v_msj_bitacora
                           || ' '
                           || paw_uti.fu_generarbitacora(v_retorno.error, v_retorno.nombrerespuesta, v_retorno.descripcionrespuesta, NULL
                           ), paw_uti.bitacora_entrada);

        v_retorno.listadetalles := v_listaspi;
        v_retorno.cantregistros := v_listaspi.count;
        RETURN v_retorno;
  EXCEPTION
   WHEN OTHERS THEN
            paw_uti.pr_mensajeUsuario(msg_error, v_retorno.nombrerespuesta, v_retorno.descripcionrespuesta, v_retorno.error);
             paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null, c_cod_operacion, null
            ,
                               v_msj_bitacora
                               || 'ORA-ERR: ['
                               || substr(sqlerrm, 1, 200)
                               || '] '
                               || paw_uti.fu_generarbitacora(v_retorno.error, v_retorno.nombrerespuesta, v_retorno.descripcionrespuesta, NULL
                               ), paw_uti.bitacora_error);

            RETURN v_retorno;
  END fu_obt_lis_alias_spi;
 ------------------------------------------------------------------------------------------------------------   
  FUNCTION fu_obtenerDetalleCuentas(p_cod_persona IN VARCHAR2, 
                                    p_nroCuentaEspecifica IN VARCHAR2 DEFAULT NULL) 
  RETURN typ_obtenerDetalleCuentas IS

      COD_OPERACION  VARCHAR2(3) := '020';
      userInfo       typ_validarSesion;
      v_permiso      typ_obtenerPermisos;
      v_retorno      typ_obtenerDetalleCuentas := typ_obtenerDetalleCuentas;
      v_logmessage   VARCHAR(1000);
   BEGIN

      --Logear parámetros
      v_logMessage := substr('obtenerDetalleCuentas(nroCuentaEspecifica=' || p_nroCuentaEspecifica || ')',0,999);
      paw_uti.pr_insertarbitacora(p_cod_persona, g_codCanal, null, COD_OPERACION, null, v_logMessage, paw_uti.bitacora_entrada);



      --llamamos a paw_can
      
      v_retorno := paw_can.fu_ns_obtenerDetalleCuentas(p_cod_persona,null,g_codCanal,p_nroCuentaEspecifica, null);
      paw_uti.pr_insertarbitacora(userInfo.codigoPersona, g_codCanal, null, COD_OPERACION, userInfo.codigoEmpresa, v_logMessage, paw_uti.BITACORA_SALIDA);
      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_uti.pr_insertarbitacora(userInfo.codigoPersona, g_codCanal, null, COD_OPERACION, userInfo.codigoEmpresa, 'fu_obtenerDetalleCuentas -' || SQLERRM, paw_uti.bitacora_error);
         RETURN v_retorno;
   END fu_obtenerDetalleCuentas;
 ------------------------------------------------------------------------------------------------------------  
   FUNCTION fu_datoCliente( p_codPersona        IN VARCHAR2,
                            p_direccion         IN VARCHAR2 DEFAULT NULL,--No debe ser nulo para p_tipoSolicitud = B. Debe tener mayor a 10 caracteres
                            p_codCiudad         IN VARCHAR2 DEFAULT NULL,--No debe ser nulo para p_tipoSolicitud = B.
                            p_codBarrio         IN VARCHAR2 DEFAULT NULL,--No debe ser nulo para p_tipoSolicitud = B.
                            p_codNumero         IN VARCHAR2 DEFAULT NULL,--numero de casa
                            p_codEdificio       IN VARCHAR2 DEFAULT NULL,
                            p_codPiso           IN VARCHAR2 DEFAULT NULL,
                            p_codDepartamento   IN VARCHAR2 DEFAULT NULL,
                            p_codigoArea        IN VARCHAR2 DEFAULT NULL,
                            p_telefono          IN VARCHAR2 DEFAULT NULL,
                            p_email             IN VARCHAR2 DEFAULT NULL,
                            p_modo              IN VARCHAR2, --Modos-> D: Consulta Detalles, V: Verificar, C: Confirmar
                            p_tipoSolicitud     IN VARCHAR2 DEFAULT NULL--Solo puede ser nulo en el Modo D. A : Direccion, T: Telefono, E; Email, C: Celular, EC: Email Confirmado, CC: Celular Confirmado ATM, CR: Celular Rechazado ATM
                            )
                            RETURN typ_datosCliente IS


     CURSOR c_datosCli(p_codPersona IN VARCHAR2) IS
      SELECT nom_completo,
              bd.direccion direccion,
              bd.numero numero_casa,
              fue_tab_dat_adicional('BA_PERSONAS', 'CELULAR_ONBOARDING',bp.cod_persona) celular,
              trim(bt.area) || '-' || trim(bt.telefono) telefono,
              bt.tipo,
              bt.tip_linea, -- tipo de linea del telefono
              bt.principal as linea_principal, --Indica si el telefono es o no el principal
              fue_tab_dat_adicional('BA_PERSONAS', 'EMAIL_ONBOARDING',bp.cod_persona) dir_correo,
              fue_per_dat_adicional(bp.cod_persona, 'EMAIL_ONB_EMPRESAS') dir_empresas,--BWP-946
              --bp.dir_correo,
              bd.cod_pais,
              FUE_OBT_ISO_PAIS(NVL(bp.COD_PAI_DOCUMENTO, bp.COD_PAIS)) as cod_pai_iso,
              bp.cod_tip_documento,
              fue_obt_des_pais(bd.cod_pais),
              bd.cod_ciudad,--codigoCiudad
              FUE_OBT_DES_CIUDAD(bd.cod_pais, bd.cod_ciudad) as des_ciudad,--descripcioCiudad
              bd.cod_barrio,--codigoBarrio
              FUE_OBT_DES_BARRIO(bd.cod_pais, bd.cod_ciudad, bd.cod_barrio) as des_barrio,--descripcionBarrio
              bp.nro_documento 
         FROM ba_personas bp, ba_direcciones bd, ba_telefonos bt
        WHERE bd.cod_persona(+) = bp.cod_persona
          AND bd.principal(+) = 'S'
          AND bt.cod_persona(+) = bp.cod_persona
          AND bp.cod_persona = p_codPersona
          ORDER by bt.fec_insercion;

    v_retorno                  typ_datosCliente := typ_datosCliente;
    p_sesion                   VARCHAR2(10) := NULL;
    v_cod_persona              VARCHAR2(10);
    v_tip_linea                VARCHAR2(1);
    v_cod_pais                 NUMBER(3);
    v_estado                   VARCHAR2(1);
    userinfo                   typ_validarsesion := typ_validarsesion();
    MSG_G_SIN_DATOS            CONSTANT VARCHAR2(15)  := 'G_SIN_DATOS'; /**No se encontraron registros*/
    MSG_OP_NO_PERMITIDA        CONSTANT VARCHAR2(15)  := 'P_OP_NO_PERM';
    MSG_DAT_DUP                CONSTANT VARCHAR2(15)  := 'G_DAT_DUP'; --Datos duplicados
    MSG_VAL_PENTRADA           CONSTANT VARCHAR2(15)  := 'VAL_PENTRADA'; --Formato incorrecto
    MSG_DAT_PEN_INV            CONSTANT VARCHAR2(15)  := 'DAT_PEN_INV'; --Formato incorrecto
    MSG_DAT_PEN_DUP            CONSTANT VARCHAR2(15)  := 'DAT_PEN_DUP'; --Datos pendientes de confirmacion duplicados
    MSG_PER_NO_FISICA          CONSTANT VARCHAR2(15)  := 'PER_NOFISICA';
    v_can_detalles             NUMBER(3) := 0;
    v_count_otp                NUMBER(3) :=0;
    v_can_dir                  NUMBER(3) :=0;
    v_can_tel                  NUMBER(3) :=0;
    v_can_mail                 NUMBER(3) :=0;
    v_seq_val                  NUMBER := 0;
    EX_PARAM_VACIOS            EXCEPTION;
    EX_PARAM_INCORRECTOS       EXCEPTION;
    v_fec_confirmacion         DATE:= NULL;
    v_fec_caducidad            DATE:= NULL;
    v_tip_mensaje              VARCHAR2(3) := 232;
    v_old_mail                 ba_mails.dir_correo%TYPE;
    v_return                   VARCHAR(10);
    v_men_old_mail             VARCHAR2(2000);
    BEGIN

     -- Se valida la sesion del cliente, siempre que el tipo de solicitud no sea EC (Email Confirmado), o CC (Celular Confirmado)
     IF p_tipoSolicitud is null or p_tipoSolicitud not in ('EC', 'CC','CR') THEN-- Al realizar esta confirmación el cliente no está logueado
       userinfo.codigoPersona := p_codPersona;

       if fug_obt_pardinamico('REG_BITACORA_BW') = 'S' then  
         paw_uti.pr_insertarBitacora(userinfo.codigoPersona, g_codCanal, p_sesion,v_tip_mensaje, NULL, 'fu_datoCliente - g_codCanal: '
         || g_codCanal||' - p_direccion: '||p_direccion||' - p_codCiudad: '||p_codCiudad||' - p_codBarrio: '||p_codBarrio
         ||' -  p_codNumero: '|| p_codNumero ||' - p_codigoArea: '||p_codigoArea||' - p_telefono: '||p_telefono||' - p_email: '||p_email||' - p_modo: '
         ||p_modo||' - p_tipoSolicitud: '||p_tipoSolicitud, paw_uti.BITACORA_ENTRADA);
       end if;
       
       IF paw_bce.fu_caj_homebanking(g_codCanal) = 'N' THEN --Si no es persona fisica o el canal no corresponde a un canal web
            paw_uti.pr_mensajeUsuario(MSG_OP_NO_PERMITIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_uti.pr_insertarBitacora(userinfo.codigoPersona, g_codCanal, p_sesion, v_tip_mensaje, NULL, 'Canal no valido-'||MSG_OP_NO_PERMITIDA, paw_uti.BITACORA_ERROR);
            return v_retorno;
       END IF;
     END IF;
    --Se recupera el codigo de persona
     v_cod_persona := p_codPersona;

     --Se verifica si el cliente es o no de nómina.
     v_retorno.esClienteNomina := fug_es_cli_nomina(v_cod_persona);

     --Se verifica si el cliente posee o no clave dinámica configurada
     select count(*) into v_count_otp from bw_otp_seriales m where m.cod_persona = v_cod_persona
            and m.cod_per_vinculada is null and m.estado = 'A';
     IF v_count_otp > 0 THEN
        v_retorno.poseeClaveDinamica := 'S';
     ELSE
        v_retorno.poseeClaveDinamica := 'N';
     END IF;

   BEGIN --Proyecto Analitica
       select pf.fec_nacimiento, pf.cod_sexo, pa.descripcion
              into v_retorno.fechaNacimiento, v_retorno.genero, v_retorno.descripcionPaisNacionalidad
                   from ba_per_fisicas pf
                        inner join ba_paises pa on (pf.cod_pai_nacionalidad = pa.cod_pais)
                              where cod_persona = v_cod_persona;

     EXCEPTION
       when others then null;
     END;

     --INICIO DE VALIDACIONES
     IF p_modo = 'V' or p_modo = 'C' THEN

        select sysdate into v_fec_confirmacion from dual;

         IF p_tipoSolicitud is null or p_tipoSolicitud not in ('A','T','C','E', 'CC','EC','CR') THEN
                 paw_uti.pr_mensajeUsuario(MSG_VAL_PENTRADA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                 paw_uti.pr_insertarBitacora(userinfo.codigoPersona, g_codCanal, p_sesion, v_tip_mensaje, NULL, 'Tipo de Solicitud incorrecta p_TipoSolicitud: '||p_tipoSolicitud||MSG_VAL_PENTRADA, paw_uti.BITACORA_ERROR);
                 return v_retorno;
         END IF;
         IF pag_gen.FU_ES_PER_FISICA(v_cod_persona)= 'N'THEN --Si no es persona fisica o el canal no corresponde a un canal web
            paw_uti.pr_mensajeUsuario(MSG_PER_NO_FISICA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_uti.pr_insertarBitacora(userinfo.codigoPersona, g_codCanal, p_sesion, v_tip_mensaje, NULL, 'Tipo de Persona  no valido-'||MSG_OP_NO_PERMITIDA, paw_uti.BITACORA_ERROR);
            return v_retorno;
         END IF;

         IF p_tipoSolicitud = 'A' THEN--A=Direccion
            v_estado := 'C';
            IF trim(p_direccion) is null AND trim(p_codNumero) is null THEN
                raise EX_PARAM_VACIOS;
            ELSIF length(p_direccion) < 10 THEN
                raise EX_PARAM_INCORRECTOS;
             END IF;
            --Validacion de datos ya existentes. EN caso que la dirección ya esté catastrada, se retorna un error
            select count(*) into v_can_dir from ba_direcciones d where d.cod_persona = v_cod_persona
                   and upper(trim(d.direccion)) = upper(trim(p_direccion))
                            and (d.cod_ciudad = p_codCiudad or p_codCiudad is null)
                            and (d.cod_barrio = p_codBarrio or p_codBarrio is null) and d.principal = 'S';

            IF v_can_dir > 0 THEN
               paw_uti.pr_mensajeUsuario(MSG_DAT_DUP, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               paw_uti.pr_insertarBitacora(userinfo.codigoPersona, g_codCanal, p_sesion, v_tip_mensaje, NULL, 'Datos duplicados. Los datos enviados ya se encuentran almacenados.  -'||MSG_DAT_DUP, paw_uti.BITACORA_ERROR);
               return v_retorno;
            END IF;

            -- Se recupera información de descripción del pais, ciudad, departamento y barrio en caso que haya odificado esos datos.
            select cod_pais, descripcion into v_cod_pais, v_retorno.descripcionPais from ba_paises where cod_pai_iso = 'PY';
            begin
              if p_codCiudad is not null then
                 select cod_ciudad, descripcion, c.cod_departamento into  v_retorno.codigoCiudad, v_retorno.descripcionCiudad, v_retorno.codigoDepartamento
                                      from ba_ciudades c where c.cod_ciudad = p_codCiudad and c.cod_pais = v_cod_pais;

                 if p_codBarrio is not null then
                    select cod_barrio, descripcion into v_retorno.codigoBarrio, v_retorno.descripcionBarrio
                                        from ba_barrios b where b.cod_pais = v_cod_pais and
                                              b.cod_ciudad = p_codCiudad and b.cod_barrio = p_codBarrio;
                 end if;
              end if;
            exception
                  when others then
                   paw_uti.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                   paw_uti.pr_insertarBitacora(userinfo.codigoPersona, g_codCanal, p_sesion, v_tip_mensaje, NULL, 'No se pudo recuperar la descripcion de ciudad/barrio. - p_codCiudad: '
                          ||p_codCiudad||' - v_cod_pais: '||v_cod_pais||' - p_codBarrio: '||p_codBarrio||SQLERRM, paw_uti.BITACORA_ERROR);
            end;
            begin
              if v_retorno.codigoDepartamento is not null then

                 select  d.descripcion into v_retorno.descripcionDepartamento
                                      from ba_departamentos d where d.cod_departamento = v_retorno.codigoDepartamento;
              end if;
            exception
                  when others then
                   paw_uti.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                   paw_uti.pr_insertarBitacora(userinfo.codigoPersona, g_codCanal, p_sesion, v_tip_mensaje, NULL, 'No se pudo recuperar la descripcion del departamento. -'||SQLERRM, paw_uti.BITACORA_ERROR);
            end;

        ELSIF p_tipoSolicitud = 'T' THEN--T=Teléfono Fijo
              v_estado := 'C';
              v_tip_linea := 'B';
              IF trim(p_telefono) is null AND trim(p_codigoArea) is null THEN
                 raise EX_PARAM_VACIOS;
              ELSIF paw_uti.fu_val_telefono(p_telefono)='N'THEN
                raise EX_PARAM_INCORRECTOS;
              END IF;

              select count(*) into v_can_tel from ba_telefonos t where t.cod_persona = v_cod_persona
                 and trim(t.telefono) = trim(p_telefono) and trim(t.area)=trim(p_codigoArea);

               IF v_can_tel > 0 THEN
                     paw_uti.pr_mensajeUsuario(MSG_DAT_DUP, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                     paw_uti.pr_insertarBitacora(userinfo.codigoPersona, g_codCanal, p_sesion, v_tip_mensaje, NULL, 'Datos duplicados  -'||MSG_DAT_DUP, paw_uti.BITACORA_ERROR);
                     return v_retorno;
               END IF;
         ELSIF p_tipoSolicitud = 'E' THEN--E=Email
              v_estado := 'P';
              v_fec_confirmacion := null;

              --Fecha de caducidad del registro, según lo parametrizado
              select (sysdate + fug_obt_pardinamico('VTO_SOL_ACT_MAIL')) into v_fec_caducidad
                               from dual;

              IF trim(p_email) is null THEN
                 raise EX_PARAM_VACIOS;
              ELSIF paw_uti.fu_validarMail(p_email)= 'N'THEN
                 paw_uti.pr_mensajeUsuario(MSG_VAL_PENTRADA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                 paw_uti.pr_insertarBitacora(userinfo.codigoPersona, g_codCanal, p_sesion, v_tip_mensaje, NULL, 'Correo electrónico no valido. -'||p_modo||'-p_tipoSolicitud'||p_tipoSolicitud||'- p_email: '||p_email, paw_uti.BITACORA_ERROR);
                 return v_retorno;
              END IF;

                select count(*) into v_can_mail from ba_mails m where m.cod_persona = v_cod_persona
                        and upper(trim(m.dir_correo)) = upper(trim(p_email));

                IF v_can_mail > 0 THEN
                     paw_uti.pr_mensajeUsuario(MSG_DAT_DUP, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                     paw_uti.pr_insertarBitacora(userinfo.codigoPersona, g_codCanal, p_sesion, v_tip_mensaje, NULL, 'Datos duplicados  -'||MSG_DAT_DUP, paw_uti.BITACORA_ERROR);
                     return v_retorno;
                END IF;
         ELSIF p_tipoSolicitud = 'C' THEN--C=Celular
              v_tip_linea := 'C';
              v_estado := 'P';
              v_fec_confirmacion := null;

              --Fecha de caducidad del registro, según lo parametrizado
              select (sysdate + fug_obt_pardinamico('VTO_SOL_ACT_CELULAR')) into v_fec_caducidad
                               from dual;

              IF trim(p_telefono) is null AND trim(p_codigoArea) is null THEN
                 raise EX_PARAM_VACIOS;
              ELSIF  paw_uti.fu_val_celular(p_codigoArea||p_telefono)='N'THEN
                raise EX_PARAM_INCORRECTOS;
              END IF;

         END IF;
     ELSIF p_modo is null THEN
           RAISE EX_PARAM_VACIOS;
     END IF; --FIN DE VALIDACIONES


    IF p_modo = 'C' THEN --Confirmacion de la modificacion
          IF p_tipoSolicitud in ('A', 'T', 'C', 'E') THEN

             -- Se pasa a estado Anulado cualquier registro anterior de la persona y del mismo tipo de solicitud que se encuentre en estado Pendiente
             update ba_act_dat_clientes set estado = 'A' where cod_persona = v_cod_persona and estado = 'P' and tip_solicitud = p_tipoSolicitud;
           --Se insertan los datos en la tabla de actualización, el estado depende del dato modificado
             SELECT s_ba_act_datos.NEXTVAL  INTO v_seq_val FROM dual;
             insert into ba_act_dat_clientes (id, cod_persona, direccion, cod_ciudad, cod_barrio,
                                                numero, edificio, departamento,
                                                piso, tel_numero, tel_area, tel_tip_linea, email, estado,fec_caducidad, fec_solicitud, fec_confirmacion, tip_solicitud, migrado)
                                              values(v_seq_val, v_cod_persona, p_direccion, p_codCiudad, p_codBarrio,
                                                                p_codNumero, p_codEdificio, p_codDepartamento, p_codPiso, p_telefono,
                                                                         p_codigoArea, v_tip_linea, p_email, v_estado,v_fec_caducidad, sysdate, v_fec_confirmacion, p_tipoSolicitud, 'N');


          END IF;

          IF p_tipoSolicitud ='A' THEN -- Direccion y Telefono fijo

             BEGIN
                  --Si llego a este punto es porque los datos no son nulos.Se insertan solo si los datos no son duplicados.
                  IF v_can_dir <= 0 THEN
                     update ba_direcciones d set principal = 'N' where d.cod_persona = v_cod_persona and d.principal = 'S';
                     insert into ba_direcciones (cod_persona, cod_direccion, tipo, principal, direccion,cod_pais, cod_ciudad, cod_barrio,
                            numero, departamento, piso, edificio)
                                    values (v_cod_persona,
                                           (select max(cod_direccion)+1 from ba_direcciones where cod_persona = v_cod_persona),
                                           'H', 'S', p_direccion, v_cod_pais, p_codCiudad, p_codBarrio,
                                          p_codNumero, p_codDepartamento, p_codPiso,p_codEdificio);

                   END IF;
                   update ba_act_dat_clientes set migrado ='S', fec_confirmacion = sysdate where id = v_seq_val;
                EXCEPTION
                WHEN DUP_VAL_ON_INDEX THEN
                     update ba_act_dat_clientes set migrado ='E', fec_confirmacion = sysdate where id = v_seq_val;
                     paw_uti.pr_mensajeUsuario(MSG_DAT_DUP, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                     paw_uti.pr_insertarBitacora(userinfo.codigoPersona, g_codCanal, p_sesion, v_tip_mensaje, NULL,SQLERRM||'-'||MSG_DAT_DUP, paw_uti.BITACORA_ERROR);
                     return v_retorno;
                WHEN OTHERS THEN
                     update ba_act_dat_clientes set migrado ='E', fec_confirmacion = sysdate where id = v_seq_val;
                     RAISE;
                END;

          ELSIF p_tipoSolicitud = 'T' THEN

                BEGIN
                   IF v_can_tel <= 0 THEN--Indica que el telefono no existe en la BD aun
                      insert into ba_telefonos (cod_persona, tipo, tip_linea, telefono, principal, area, cod_telefono)
                             values(v_cod_persona, 'H','B', p_telefono, 'N', p_codigoArea,
                                   (select max(cod_telefono)+1 from ba_telefonos where cod_persona = v_cod_persona)
                                   );
                   END IF;
                   update ba_act_dat_clientes set migrado ='S', fec_confirmacion = sysdate where id = v_seq_val;
                EXCEPTION
                WHEN DUP_VAL_ON_INDEX THEN
                     update ba_act_dat_clientes set migrado ='E', fec_confirmacion = sysdate where id = v_seq_val;
                     paw_uti.pr_mensajeUsuario(MSG_DAT_DUP, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                     paw_uti.pr_insertarBitacora(userinfo.codigoPersona, g_codCanal, p_sesion, v_tip_mensaje, NULL,SQLERRM||'-'||MSG_DAT_DUP, paw_uti.BITACORA_ERROR);
                     return v_retorno;
                WHEN OTHERS THEN
                     update ba_act_dat_clientes set migrado ='E', fec_confirmacion = sysdate where id = v_seq_val;
                     RAISE;
                END;
          ELSIF p_tipoSolicitud = 'EC' THEN

                begin
                  --Se recupera el código de persona del mail que se acaba de confirmar
                  select cod_persona, id into v_cod_persona, v_seq_val from ba_act_dat_clientes
                         where upper(trim(email)) = upper(trim(p_email))
                               and estado = 'P' and trunc(fec_caducidad)>=trunc(sysdate)
                                    and tip_solicitud = 'E' and migrado = 'N';

                  -- Almacenamos el email anterior a fin de enviar el mensaje de aviso luego del cambio a esa
                  -- dirección
                  v_old_mail := fug_obt_dir_mail_per(v_cod_persona);

                  update ba_act_dat_clientes set estado = 'C', fec_confirmacion = sysdate where id = v_seq_val; --DDSI-390

                  v_men_old_mail := fug_obt_pardinamico('ACT_DAT_AVI_CAM_EMAIL');

                  v_return := paw_not.fu_env_email_prueba(v_old_mail,
                                              utl_url.escape(v_men_old_mail,
                                              TRUE,
                                              'UTF-8'),
                                              'paw_bem');

                  if v_return = 0 then
                     paw_uti.pr_insertarBitacora(v_cod_persona, g_codCanal, p_sesion, v_tip_mensaje, NULL, ' fu_datoCliente - ret: '||v_return||'; EMAIL de notificacion de cambio correctamente enviado a: '||v_old_mail,paw_uti.BITACORA_SALIDA);
                  else
                     paw_uti.pr_insertarBitacora(v_cod_persona, g_codCanal, p_sesion, v_tip_mensaje, NULL, ' fu_datoCliente - ret: '||v_return||'; EMAIL de notificacion de cambio NO enviado a: '||v_old_mail,paw_uti.BITACORA_ERROR);
                  end if;


                exception
                   when no_data_found then
                  update ba_act_dat_clientes set estado = 'C', migrado = 'E', fec_confirmacion = sysdate where id = v_seq_val;
                     paw_uti.pr_mensajeUsuario(MSG_DAT_PEN_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                     paw_uti.pr_insertarBitacora(v_cod_persona, g_codCanal, p_sesion, v_tip_mensaje, NULL, ' fu_datoCliente - Error al intentar migrar datos de correo.'||SQLERRM||'-' || MSG_ERROR,paw_uti.BITACORA_ERROR);
                     return v_retorno;
                    when too_many_rows then
                     update ba_act_dat_clientes set estado = 'C', migrado = 'E', fec_confirmacion = sysdate where id = v_seq_val;
                     paw_uti.pr_mensajeUsuario(MSG_DAT_PEN_DUP, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                     paw_uti.pr_insertarBitacora(v_cod_persona, g_codCanal, p_sesion, v_tip_mensaje, NULL, ' fu_datoCliente - Error al intentar migrar datos de correo.'||SQLERRM||'-' || MSG_ERROR,paw_uti.BITACORA_ERROR);
                     return v_retorno;
                    when others then
                       update ba_act_dat_clientes set estado = 'C', migrado = 'E', fec_confirmacion = sysdate where id = v_seq_val;
                       paw_uti.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                       paw_uti.pr_insertarBitacora(v_cod_persona, g_codCanal, p_sesion, v_tip_mensaje, NULL, ' fu_datoCliente - Error al intentar migrar datos de correo.'||SQLERRM||'-' || MSG_ERROR,paw_uti.BITACORA_ERROR);
                       return v_retorno;
                end;

          ELSIF p_tipoSolicitud = 'CC' THEN

                  --Se recupera el código de persona del número de celular que se acaba de confirmar
                  select cod_persona, id into v_cod_persona, v_seq_val from ba_act_dat_clientes
                         where trim(tel_area) = trim(p_codigoArea)  and trim(tel_numero) = trim(p_telefono)
                               and estado = 'P' and trunc(fec_caducidad)>=trunc(sysdate)
                                    and tip_solicitud = 'C' and migrado = 'N';

                update ba_act_dat_clientes set estado = 'C', fec_confirmacion = sysdate
                       where cod_persona = v_cod_persona and tip_solicitud = 'C' and estado = 'P';

          END IF;
    ELSIF p_modo = 'D' THEN --Consulta de Detalles. Retorna información del detalle de un cliente.
       FOR reg IN c_datosCli(v_cod_persona)
       LOOP
          v_can_detalles               := v_can_detalles + 1;
          v_retorno.nombreCompleto     := reg.nom_completo;
          v_retorno.direccion          := reg.direccion;
          v_retorno.email              := reg.dir_correo;
          v_retorno.codigoCiudad       := reg.cod_ciudad;
          v_retorno.descripcionCiudad  := reg.des_ciudad;
          v_retorno.codigoBarrio       := reg.cod_barrio;
          v_retorno.descripcionBarrio  := reg.des_barrio;
          v_retorno.numeroCasa         := reg.numero_casa;
          v_retorno.tipoDocumento      := reg.cod_tip_documento;
          v_retorno.codigoPaisIso      := reg.cod_pai_iso;
          v_retorno.nroDocumento       := reg.nro_documento;
          --Los telefonos se reemplazan hasta encontrar el telefono principal, o el último registro modificado por el HB (tipo = H)
          IF reg.tip_linea = 'B' AND (v_retorno.tipoLineaPrincipal is null OR v_retorno.tipoLineaPrincipal != 'B' OR reg.tipo = 'H') THEN
             v_retorno.telefonoFijo  := reg.telefono;
          ELSIF reg.tip_linea = 'C' AND (v_retorno.tipoLineaPrincipal is null OR v_retorno.tipoLineaPrincipal != 'C'  OR reg.tipo = 'H') THEN
             v_retorno.celular := reg.telefono;
          END IF;
             v_retorno.celular := reg.celular;
          IF reg.linea_principal = 'S' THEN
               v_retorno.tipoLineaPrincipal := reg.tip_linea;
          END IF;
       END LOOP;

       -- Valida si encontro datos
       IF v_can_detalles = 0 THEN
          paw_uti.pr_mensajeUsuario(MSG_G_SIN_DATOS, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
          paw_uti.pr_insertarBitacora(userinfo.codigoPersona, g_codCanal, p_sesion, v_tip_mensaje, NULL, ' fu_datoCliente-' || MSG_G_SIN_DATOS, paw_uti.BITACORA_ERROR);
          RETURN v_retorno;
        END IF;
      END IF; --TIPO SOLICITUD = D

     paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
     paw_uti.pr_insertarBitacora(userinfo.codigoPersona, g_codCanal, p_sesion, v_tip_mensaje, NULL, ' fu_datoCliente - '||MSG_OK,  paw_uti.BITACORA_SALIDA);
     RETURN v_retorno;
    EXCEPTION
        WHEN EX_PARAM_VACIOS THEN
             paw_uti.pr_mensajeUsuario(MSG_VAL_PENTRADA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
             paw_uti.pr_insertarBitacora(userinfo.codigoPersona, g_codCanal, p_sesion, v_tip_mensaje, NULL, 'Parámetros obligatorios vacios. p_modo:'
                                                                          ||p_modo||'-p_tipoSolicitud'||p_tipoSolicitud||'-p_direccion: '||p_direccion||
                                                                          '-Numero: '||p_codNumero||'-p_codigoArea: '|| p_codigoArea||'- p_telefono: '|| p_telefono, paw_uti.BITACORA_ERROR);
             return v_retorno;
        WHEN EX_PARAM_INCORRECTOS THEN
           paw_uti.pr_mensajeUsuario(MSG_VAL_PENTRADA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
           paw_uti.pr_insertarBitacora(userinfo.codigoPersona, g_codCanal, p_sesion, v_tip_mensaje, NULL, 'Datos a actualizar no validos-'||p_modo||'-p_tipoSolicitud'||p_tipoSolicitud||'-p_direccion: '||p_direccion||
                                                                          '- Numero: '||p_codNumero||'- p_codigoArea: '|| p_codigoArea||' - p_telefono: '|| p_telefono, paw_uti.BITACORA_ERROR);
                  return v_retorno;
        WHEN OTHERS THEN
             paw_uti.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
             paw_uti.pr_insertarBitacora(userinfo.codigoPersona, g_codCanal, p_sesion, v_tip_mensaje, NULL, ' fu_datoCliente-'||SQLERRM||'-' || MSG_ERROR,paw_uti.BITACORA_ERROR);
             return v_retorno;
    END fu_datoCliente;
 ------------------------------------------------------------------------------------------------------------   
END paw_ali;