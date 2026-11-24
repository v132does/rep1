CREATE OR REPLACE PROCEDURE it.prw_pag_int_salarios ( 
    p_cod_intencion    NUMBER,
    p_cod_autorizacion NUMBER,
    p_concepto         VARCHAR2,
    p_nro_cta_debito   ge_cuentas.nro_cuenta%TYPE,
    p_cod_tra_padre    NUMBER,
    p_json             IN CLOB,
    p_resultado        OUT CLOB
) AS
    /*********************************************/
    -- CAPA DE DOMINIO: Definición de entidades y tipos
    /*********************************************/
    
    
    TYPE typ_beneficiario IS RECORD (
        cod_empleado   NUMBER,
        monto          NUMBER,
        nro_cta_credito ge_cuentas.nro_cuenta%TYPE,
        cod_operacion  VARCHAR2(250),
        observacion    VARCHAR2(4000)
    );
    
    TYPE tab_beneficiarios IS TABLE OF typ_beneficiario;
    
    TYPE typ_nomina IS RECORD (
        cod_nomina    NUMBER,
        beneficiarios tab_beneficiarios
    );
    
    TYPE typ_resultado_validacion IS RECORD (
        es_valido VARCHAR2(1),
        cod_error NUMBER,
        mensaje   VARCHAR2(32000)
    );
    
    TYPE typ_contexto_operacion IS RECORD (
        cod_usuario      ba_usuarios.cod_usuario%TYPE,
        fec_actual       DATE,
        fec_valor        DATE,
        hora             VARCHAR2(8),
        horario          VARCHAR2(1),
        es_mov_noc       VARCHAR2(1),
        es_cta_noc       VARCHAR2(1),
        estado_modulo    ba_modulos.estado%TYPE,
        estado_inicial   ba_modulos.estado%TYPE
    );
    
    /*********************************************/
    -- Variables PROCEDIMIENTO PRINCIPAL (Orquestador)
    /*********************************************/
    
    r_nomina        typ_nomina;
    r_cuenta_debito ge_cuentas%ROWTYPE;
    r_contexto      typ_contexto_operacion;
    v_total_debito  NUMBER;
    r_resultado_proc_creditos typ_resultado_validacion;
    r_resultado_proc_debito typ_resultado_validacion;
    v_error_usuario   NUMBER;
    v_mensaje_usuario VARCHAR2(4000);
    v_error_hora      NUMBER;
    v_mensaje_hora    VARCHAR2(4000);
    v_error_horario   NUMBER;
    v_mensaje_horario VARCHAR2(4000);
    r_resultado_validacion_deb typ_resultado_validacion;
    r_resultado_validacion_cre typ_resultado_validacion; 
    v_error_total   NUMBER;
    v_mensaje_total VARCHAR2(4000);
    v_error_cuenta_deb   NUMBER;
    v_mensaje_cuenta_deb VARCHAR2(4000);
    v_error_parseo   NUMBER;
    v_mensaje_parseo VARCHAR2(4000);
    v_concepto   VARCHAR2(100) := SUBSTR('PAGO DE ' ||UPPER(P_CONCEPTO) ,1,100);
    
    -- Variables para control de tiempo
    v_tiempo_inicio      TIMESTAMP;
    v_tiempo_inicio_val  TIMESTAMP;
    v_tiempo_fin_val     TIMESTAMP;
    v_tiempo_inicio_pago TIMESTAMP;
    v_tiempo_fin_pago    TIMESTAMP;
    v_tiempo_total       NUMBER;
    v_tiempo_validacion  NUMBER;
    v_tiempo_pago        NUMBER;
    
    -- Variables para idempotencia
    v_registro_insert  it.bw_estado_pago_intencion%rowtype;
    v_inserto          boolean;
    v_registro_out     it.bw_estado_pago_intencion%rowtype;

    /*********************************************/
    -- Sub-Programas 
    /*********************************************/
    
    FUNCTION fu_gen_ubicacion RETURN VARCHAR2 IS
        v_linea       VARCHAR2(1000);
        v_paquete     VARCHAR2(1000);
        v_llamador    VARCHAR2(1000);
        v_propietario VARCHAR2(1000);
    BEGIN
        owa_util.who_called_me(v_propietario, v_paquete, v_linea, v_llamador);
        RETURN v_paquete || '.' || v_linea;
    END;
    
    FUNCTION fu_cal_tiempo_transcurrido(
        p_tiempo_inicio IN TIMESTAMP,
        p_tiempo_fin    IN TIMESTAMP
    ) RETURN NUMBER IS
        v_tiempo_segundos NUMBER;
    BEGIN
        v_tiempo_segundos := EXTRACT(SECOND FROM (p_tiempo_fin - p_tiempo_inicio)) + 
                             EXTRACT(MINUTE FROM (p_tiempo_fin - p_tiempo_inicio)) * 60;
        RETURN v_tiempo_segundos;
    EXCEPTION
        WHEN OTHERS THEN
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-Error al calcular tiempo transcurrido: ' || SQLERRM, 1, 4000));
            RETURN 0;
    END fu_cal_tiempo_transcurrido;

    /*********************************************/
    -- CAPA DE INFRAESTRUCTURA: Adaptadores externos
    /*********************************************/
    
       
    FUNCTION fu_rep_obt_cuenta(
        p_nro_cuenta    IN ge_cuentas.nro_cuenta%TYPE,
        p_tipo_cuenta   IN VARCHAR2,
        p_cod_error     OUT NUMBER,
        p_mensaje_error OUT VARCHAR2
    ) RETURN ge_cuentas%ROWTYPE IS
        r_cuenta ge_cuentas%ROWTYPE;
    BEGIN
        SELECT * INTO r_cuenta
        FROM ge_cuentas
        WHERE nro_cuenta = p_nro_cuenta;
        
        p_cod_error := 0;
        RETURN r_cuenta;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_cod_error := 30001;
            p_mensaje_error := 'ERR30001: ' || p_tipo_cuenta || ' - No se encontró datos de la cuenta ' || p_nro_cuenta;
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-' || p_mensaje_error, 1, 4000));
            RETURN NULL;
        WHEN OTHERS THEN
            p_cod_error := 30002;
            p_mensaje_error := 'ERR30002: ' || p_tipo_cuenta || ' - Error al obtener los datos de la cuenta ' || p_nro_cuenta || ' - ' || SQLERRM;
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-' || p_mensaje_error, 1, 4000));
            RETURN NULL;
    END fu_rep_obt_cuenta;
    
    -- Servicio de Usuario
    FUNCTION fu_ser_obt_usuario(
        p_tipo_usuario  IN VARCHAR2,
        p_cod_error     OUT NUMBER,
        p_mensaje_error OUT VARCHAR2
    ) RETURN VARCHAR2 IS
        v_cantidad   NUMBER;
        v_secuencia  NUMBER;
        v_indice     NUMBER;
        v_usuario    ba_usuarios.cod_usuario%TYPE;
    BEGIN
        SELECT COUNT(*) INTO v_cantidad
        FROM ba_cod_referencias
        WHERE dominio = 'USU_MOV_SERVICIO'
        AND abreviatura = p_tipo_usuario;
        
        v_secuencia := fue_obt_sig_secuencia('S_SER_PAGSAL');
        v_indice := MOD(v_secuencia, v_cantidad);
        v_usuario := it.fue_obt_val_user_dominio('USU_MOV_SERVICIO', v_indice, p_tipo_usuario);
        
        p_cod_error := 0;
        RETURN v_usuario;
    EXCEPTION
        WHEN OTHERS THEN
            p_cod_error := 40001;
            p_mensaje_error := 'ERR40001: Error al obtener el usuario - ' || SQLERRM;
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-' || p_mensaje_error, 1, 4000));
            RETURN NULL;
    END fu_ser_obt_usuario;
    
    FUNCTION fu_ser_cal_hora(
        p_usuario       IN VARCHAR2,
        p_cod_error     OUT NUMBER,
        p_mensaje_error OUT VARCHAR2
    ) RETURN VARCHAR2 IS
        v_secuencia NUMBER;
        v_indice    NUMBER;
        v_hora      VARCHAR2(8);
        v_ind_usuario NUMBER;
    BEGIN
        IF INSTR(p_usuario, '_', 1) = 0 THEN
            v_ind_usuario := 0;
        ELSE
            v_ind_usuario := SUBSTR(p_usuario, INSTR(p_usuario, '_', 1) + 1, 2);
        END IF;
        
        IF v_ind_usuario > 0 THEN
            v_secuencia := fue_obt_sig_secuencia('S_HOR_MOVPAGSAL' || v_ind_usuario);
        ELSIF v_ind_usuario = 0 THEN
            v_secuencia := fue_obt_sig_secuencia('S_HOR_MOVPAGSAL');
        END IF;
        
        v_indice := MOD(v_secuencia, 86400);
        v_hora := TO_CHAR(TRUNC(v_indice / 3600), 'FM9900') || ':' ||
                  TO_CHAR(TRUNC(MOD(v_indice, 3600) / 60), 'FM00') || ':' ||
                  TO_CHAR(MOD(v_indice, 60), 'FM00');
        
        p_cod_error := 0;
        RETURN v_hora;
    EXCEPTION
        WHEN OTHERS THEN
            p_cod_error := 50001;
            p_mensaje_error := 'ERR50001: Error al obtener la hora - ' || SQLERRM;
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-' || p_mensaje_error, 1, 4000));
            RETURN NULL;
    END fu_ser_cal_hora;

    PROCEDURE fu_ser_ver_horario(
        p_cod_oficina    IN ba_oficinas.cod_oficina%TYPE,
        p_cod_modulo     IN ba_modulos.cod_modulo%TYPE,
        p_contexto       IN OUT typ_contexto_operacion,
        p_cod_error      OUT NUMBER,
        p_mensaje_error  OUT VARCHAR2
    ) IS
        v_est_modulo ba_modulos.estado%TYPE;
    BEGIN
        p_cod_error := 0;
        p_contexto.horario := 'D';
        p_contexto.es_mov_noc := 'N';
        p_contexto.es_cta_noc := 'N';
        p_contexto.fec_actual := pag_cal.fu_obt_fec_actual(p_cod_modulo);
        v_est_modulo := pae_cnf.fu_obt_est_modulo(p_cod_modulo);
        
        IF fug_obt_pardinamico('ACT_NOCTURNO') = 'N' THEN
            p_cod_error := 811;
            p_mensaje_error := 'ERR811: Modulo en proceso de cierre';
            RETURN;
        ELSIF v_est_modulo IN (1, 6) THEN
            p_cod_error := 812;
            p_mensaje_error := 'ERR812: Modulo en proceso de cierre. Estado: ' || v_est_modulo;
            RETURN;
        ELSIF v_est_modulo = 2 THEN
            p_contexto.horario := 'D';
            p_contexto.es_mov_noc := 'N';
            p_contexto.es_cta_noc := 'N';
            p_contexto.fec_actual := pag_cal.fu_obt_fec_actual(p_cod_modulo);
        ELSE
            p_contexto.horario := 'N';
            IF v_est_modulo <> 1 THEN
                p_contexto.fec_actual := pag_cal.fu_obt_fec_habil(p_contexto.fec_actual + 1, 1, p_cod_oficina);
            END IF;
            p_contexto.es_mov_noc := 'S';
            p_contexto.es_cta_noc := 'S';
        END IF;
        
        pag_cta.g_horario := p_contexto.horario;
        p_contexto.fec_valor := TRUNC(SYSDATE);
        p_contexto.estado_modulo := v_est_modulo;
        p_contexto.estado_inicial := v_est_modulo;
    EXCEPTION
        WHEN OTHERS THEN
            p_cod_error := 813;
            p_mensaje_error := 'ERR813: Ocurrio un error en la verificacion de horario ' || SQLERRM;
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-' || p_mensaje_error, 1, 4000));
    END fu_ser_ver_horario;

    /*********************************************/
    -- CAPA DE APLICACIÓN: Casos de uso
    /*********************************************/
    
    FUNCTION fu_parsearjson(
        p_json          IN CLOB,
        p_cod_error     OUT NUMBER,
        p_mensaje_error OUT VARCHAR2
    ) RETURN typ_nomina IS
        v_json_obj      json_object_t;
        v_json_arr      json_array_t;
        v_nomina        typ_nomina;
        v_beneficiario  typ_beneficiario;
    BEGIN
        -- Inicializar la colección de beneficiarios para evitar errores de NULL
        v_nomina.beneficiarios := tab_beneficiarios();
        v_json_obj := json_object_t.parse(p_json);
        v_nomina.cod_nomina := v_json_obj.get_number('id');
        
        IF v_nomina.cod_nomina IS NULL THEN
            p_cod_error := 10002;
            p_mensaje_error := 'ERR10002: El id de la nomina no puede ser nulo';
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-' || p_mensaje_error, 1, 4000));
            RETURN NULL;
        END IF;
        
        v_json_arr := json_array_t(v_json_obj.get('beneficiaries'));
        FOR i IN 0..v_json_arr.get_size - 1 LOOP
            v_json_obj := json_object_t(v_json_arr.get(i));
            v_beneficiario.cod_empleado := v_json_obj.get_number('id');
            v_beneficiario.monto := v_json_obj.get_number('salary');
            v_beneficiario.nro_cta_credito := v_json_obj.get_string('accountNumber');
            v_beneficiario.cod_operacion := NULL;
            v_beneficiario.observacion := NULL;
            
            v_nomina.beneficiarios.EXTEND;
            v_nomina.beneficiarios(v_nomina.beneficiarios.COUNT) := v_beneficiario;
        END LOOP;
        
        p_cod_error := 0;
        RETURN v_nomina;
    EXCEPTION
        WHEN OTHERS THEN
            p_cod_error := 10001;
            p_mensaje_error := 'ERR10001: Error en el Parseo - ' || SQLERRM;
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-' || p_mensaje_error, 1, 4000));
            RETURN NULL;
    END fu_parsearjson;
    
    FUNCTION fu_cal_total(
        p_nomina        IN typ_nomina,
        p_cod_error     OUT NUMBER,
        p_mensaje_error OUT VARCHAR2
    ) RETURN NUMBER IS
        v_total NUMBER := 0;
    BEGIN
        IF p_nomina.beneficiarios IS NOT NULL AND p_nomina.beneficiarios.COUNT > 0 THEN
            FOR i IN 1..p_nomina.beneficiarios.COUNT LOOP
                v_total := v_total + NVL(p_nomina.beneficiarios(i).monto, 0);
            END LOOP;
        END IF;
        
        IF v_total = 0 THEN
            p_cod_error := 60002;
            p_mensaje_error := 'ERR60002: El total Debito no puede ser 0';
            RETURN NULL;
        END IF;
        
        p_cod_error := 0;
        RETURN v_total;
    EXCEPTION
        WHEN OTHERS THEN
            p_cod_error := 60001;
            p_mensaje_error := 'ERR60001: Error al calcular total debito - ' || SQLERRM;
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-' || p_mensaje_error, 1, 4000));
            RETURN NULL;
    END fu_cal_total;
    
    FUNCTION fu_val_cta_debito(
        p_nro_cuenta    IN ge_cuentas.nro_cuenta%TYPE,
        p_cuenta        IN ge_cuentas%ROWTYPE,
        p_monto         IN NUMBER,
        p_cod_tra_padre IN NUMBER
    ) RETURN typ_resultado_validacion IS
        r_resultado              typ_resultado_validacion;
        v_nuevo_estado           ge_cuentas.estado%TYPE;
        v_saldo_disp             NUMBER;
        v_procede                VARCHAR2(1);
        v_cod_tra                NUMBER := 503;
        v_cod_modulo_cue         ge_cuentas.cod_modulo%type;
        v_cod_modalidad_cue      ge_cuentas.cod_modalidad%type;
    BEGIN
        r_resultado.es_valido := 'S';
        r_resultado.cod_error := 0;
        
        pag_cta.pr_ver_operacion(
            p_nro_cuenta, p_cod_tra_padre, p_cuenta.cod_modulo, p_cuenta.cod_modalidad,
            'D', p_cuenta.cod_moneda, p_monto, p_cuenta.cod_oficina,
            v_cod_modulo_cue, v_cod_modalidad_cue,
            v_nuevo_estado, v_saldo_disp, v_procede, v_cod_tra
        );
        
        IF pag_cta.g_cod_error <> 0 OR v_procede = 'N' THEN
            IF INSTR(UPPER(pag_cta.g_msj_error), 'INSUFIC') > 0 THEN
                r_resultado.cod_error := 80001;
                r_resultado.mensaje := 'ERR80001: Cuenta ' || p_nro_cuenta || ' con Saldo Insuficiente p/ el débito de GS ' || p_monto;
            ELSE
                r_resultado.cod_error := 80002;
                r_resultado.mensaje := 'ERR80002: Error durante validacion Cta. Debito ' || p_nro_cuenta || ' - cod. ' || pag_cta.fu_obt_cod_error || ' ' || pag_cta.fu_obt_msj_error;
            END IF;
            r_resultado.es_valido := 'N';
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-' || r_resultado.mensaje, 1, 4000));
        END IF;
        
        RETURN r_resultado;
    EXCEPTION
        WHEN OTHERS THEN
            r_resultado.es_valido := 'N';
            r_resultado.cod_error := 80003;
            r_resultado.mensaje := 'ERR80003: Error en pag_cta.ver_ope ' || p_nro_cuenta || ' - ' || SQLERRM;
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-' || r_resultado.mensaje, 1, 4000));
            RETURN r_resultado;
    END fu_val_cta_debito;
    
    FUNCTION fu_val_cta_credito(
        p_nomina        IN typ_nomina,
        p_beneficiario  IN typ_beneficiario,
        p_cuenta_deb    IN ge_cuentas%ROWTYPE,
        p_cod_tra_padre IN NUMBER
    ) RETURN typ_resultado_validacion IS
        r_resultado         typ_resultado_validacion;
        r_cuenta_cre        ge_cuentas%ROWTYPE;
        v_nuevo_estado      ge_cuentas.estado%TYPE;
        v_saldo_disp        NUMBER;
        v_procede           VARCHAR2(1);
        v_cod_tra           NUMBER := 602;
        v_cod_modulo_cre    ge_cuentas.cod_modulo%TYPE;
        v_cod_modalidad_cre ge_cuentas.cod_modalidad%TYPE;
        v_error             NUMBER;
        v_mensaje           VARCHAR2(4000);
    BEGIN
        r_resultado.es_valido := 'S';
        r_resultado.cod_error := 0;
        
        r_cuenta_cre := fu_rep_obt_cuenta(p_beneficiario.nro_cta_credito, 'CREDITO', v_error, v_mensaje);
        IF r_cuenta_cre.nro_cuenta IS NULL THEN
            r_resultado.es_valido := 'N';
            r_resultado.cod_error := v_error;
            r_resultado.mensaje := v_mensaje;
            RETURN r_resultado;
        END IF;
        
 
        
        IF r_cuenta_cre.cod_moneda != p_cuenta_deb.cod_moneda THEN
            r_resultado.es_valido := 'N';
            r_resultado.cod_error := 70009;
            r_resultado.mensaje := 'ERR70009: La moneda de la cuenta credito no coincide con la cuenta debito';
            prg_ins_log_pag_int_salario(p_cod_intencion, p_nomina.cod_nomina, p_beneficiario.cod_empleado,
                substr(fu_gen_ubicacion() || '-' || r_resultado.mensaje, 1, 4000));
            RETURN r_resultado;
        END IF;
        
        pag_cta.pr_ver_operacion(
            p_beneficiario.nro_cta_credito, p_cod_tra_padre, p_cuenta_deb.cod_modulo, p_cuenta_deb.cod_modalidad,
            'C', r_cuenta_cre.cod_moneda, p_beneficiario.monto, r_cuenta_cre.cod_oficina,
            v_cod_modulo_cre, v_cod_modalidad_cre,
            v_nuevo_estado, v_saldo_disp, v_procede, v_cod_tra
        );
        
        IF pag_cta.g_cod_error <> 0 OR v_procede = 'N' THEN
            IF pag_cta.g_cod_error IN (33, 34) THEN
                CASE fug_obt_est_cuenta(p_beneficiario.nro_cta_credito)
                    WHEN 'C' THEN r_resultado.cod_error := 70001; r_resultado.mensaje := 'ERR70001: Cuenta credito cancelada ' || p_beneficiario.nro_cta_credito;
                    WHEN 'B' THEN r_resultado.cod_error := 70002; r_resultado.mensaje := 'ERR70002: Cuenta credito con bloqueo ' || p_beneficiario.nro_cta_credito;
                    WHEN 'P' THEN r_resultado.cod_error := 70003; r_resultado.mensaje := 'ERR70003: Cuenta credito pendiente de cancelacion ' || p_beneficiario.nro_cta_credito;
                    WHEN 'T' THEN r_resultado.cod_error := 70004; r_resultado.mensaje := 'ERR70004: Cuenta credito con bloqueo total ' || p_beneficiario.nro_cta_credito;
                    WHEN 'X' THEN r_resultado.cod_error := 70005; r_resultado.mensaje := 'ERR70005: Cuenta credito en verificacion ' || p_beneficiario.nro_cta_credito;
                    ELSE r_resultado.cod_error := 70006; r_resultado.mensaje := 'ERR70006: Estado de cuenta credito invalida ' || p_beneficiario.nro_cta_credito;
                END CASE;
            ELSE
                r_resultado.cod_error := 70007;
                r_resultado.mensaje := 'ERR70007: Error durante validacion Cta. Credito ' || p_beneficiario.nro_cta_credito || ' - cod. ' || pag_cta.fu_obt_cod_error || ' ' || pag_cta.fu_obt_msj_error;
            END IF;
            r_resultado.es_valido := 'N';
            prg_ins_log_pag_int_salario(p_cod_intencion, p_nomina.cod_nomina, p_beneficiario.cod_empleado,
                substr(fu_gen_ubicacion() || '-' || r_resultado.mensaje, 1, 4000));
        END IF;
        
        RETURN r_resultado; 
    EXCEPTION
        WHEN OTHERS THEN
            r_resultado.es_valido := 'N';
            r_resultado.cod_error := 70008;
            r_resultado.mensaje := 'ERR70008: Error en validacion Cta. Credito ' || p_beneficiario.nro_cta_credito || ' - ' || SQLERRM;
            prg_ins_log_pag_int_salario(p_cod_intencion, p_nomina.cod_nomina, p_beneficiario.cod_empleado,
                substr(fu_gen_ubicacion() || '-' || r_resultado.mensaje, 1, 4000));
            RETURN r_resultado;
    END fu_val_cta_credito;
    
    FUNCTION fu_pro_debito(
        p_cuenta_debito IN ge_cuentas%ROWTYPE,
        p_total         IN NUMBER,
        p_contexto      IN typ_contexto_operacion,
        pv_concepto      IN VARCHAR2,
        p_cod_tra_padre IN NUMBER,
        p_cod_intencion IN NUMBER
    ) return typ_resultado_validacion IS
        v_estado_actual ba_modulos.estado%TYPE;
        v_nro_secuencia ge_movimientos.nro_secuencia%type;
        v_resultado     typ_resultado_validacion;
    BEGIN
        v_estado_actual := pae_cnf.fu_obt_est_modulo(3);
        v_nro_secuencia := 0; --siempre 0
        
        IF (p_contexto.estado_inicial != v_estado_actual OR v_estado_actual IN (1, 6)) THEN
            v_resultado.es_valido := 'N';
            v_resultado.cod_error := 82001;
            v_resultado.mensaje := 'ERR82001: Entidad en proceso de cierre, vuelva a intentar';
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-' || v_resultado.mensaje, 1, 4000));
            RETURN v_resultado;
        END IF;
        
        pag_cta.pr_set_nro_documento3(p_cod_intencion);
        pag_cta.pr_set_nro_documento2(NULL);
        pag_cta.pr_set_variables(
            p_contexto.cod_usuario, p_contexto.fec_actual, p_cod_tra_padre,
            'N', 'N', v_nro_secuencia, NULL,
            p_cuenta_debito.cod_oficina, p_cuenta_debito.cod_modulo, p_cuenta_debito.cod_modalidad
        );
        
        pag_cta.pr_act_operacion(
            p_cuenta_debito.nro_cuenta, p_contexto.hora, 'D',
            p_cuenta_debito.cod_moneda, p_total, p_cod_tra_padre, 503,
            p_cod_autorizacion, NULL, p_cuenta_debito.cod_oficina,
            p_cuenta_debito.cod_modulo, p_cuenta_debito.cod_modalidad,
            NULL, NULL, pv_concepto, 'N', v_nro_secuencia, p_contexto.fec_valor
        );
        
        IF pag_cta.g_cod_error <> 0 THEN
            IF INSTR(UPPER(pag_cta.g_msj_error), 'INSUFIC') > 0 THEN
                v_resultado.cod_error := 82002;
                v_resultado.mensaje := 'ERR82002: Cuenta ' || p_cuenta_debito.nro_cuenta || ' con Saldo Insuficiente p/ el débito de GS ' || p_total;
            ELSE
                v_resultado.cod_error := 82003;
                v_resultado.mensaje := 'ERR82003: Error pag_cta.act_operacion Cuenta Debito ' || p_cuenta_debito.nro_cuenta || ' - cod. ' || pag_cta.fu_obt_cod_error || ' ' || pag_cta.fu_obt_msj_error;
            END IF;
            v_resultado.es_valido := 'N';
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-' || v_resultado.mensaje, 1, 4000));
            RETURN v_resultado;
        END IF;
        
        v_resultado.es_valido := 'S';
        v_resultado.cod_error := 0;
        return v_resultado;
    EXCEPTION
        WHEN OTHERS THEN
            v_resultado.es_valido := 'N';
            v_resultado.cod_error := 82004;
            v_resultado.mensaje := 'ERR82004: Error pag_cta.act_operacion Cuenta Debito ' || p_cuenta_debito.nro_cuenta || ' - ' || SQLERRM;
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-' || v_resultado.mensaje, 1, 4000));
            return v_resultado;
    END fu_pro_debito;
    
    FUNCTION fu_pro_credito(
        p_nomina        IN OUT typ_nomina,
        p_cuenta_debito IN ge_cuentas%ROWTYPE,
        p_contexto      IN typ_contexto_operacion,
        pv_concepto      IN VARCHAR2,
        p_cod_tra_padre IN NUMBER,
        p_cod_intencion IN NUMBER
    ) return typ_resultado_validacion IS
        v_estado_actual ba_modulos.estado%TYPE;
        v_hora          VARCHAR2(8);
        v_error         NUMBER;
        v_mensaje       VARCHAR2(4000);
        v_nro_secuencia ge_movimientos.nro_secuencia%type;
        v_resultado     typ_resultado_validacion;
    BEGIN
        v_resultado.es_valido := 'S';
        v_resultado.cod_error := 0;
        
        FOR i IN 1..p_nomina.beneficiarios.COUNT LOOP
            v_estado_actual := pae_cnf.fu_obt_est_modulo(3);
            v_nro_secuencia := 0; --Siempre 0
            
            IF (p_contexto.estado_inicial != v_estado_actual OR v_estado_actual IN (1, 6)) THEN
                v_resultado.es_valido := 'N';
                v_resultado.cod_error := 90001;
                v_resultado.mensaje := 'ERR90001: Entidad en proceso de cierre, vuelva a intentar';
                prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                    substr(fu_gen_ubicacion() || '-' || v_resultado.mensaje, 1, 4000));
                RETURN v_resultado;
            END IF;
            
            v_hora := fu_ser_cal_hora(p_contexto.cod_usuario, v_error, v_mensaje);
            IF v_hora IS NULL THEN
                v_resultado.es_valido := 'N';
                v_resultado.cod_error := 90002;
                v_resultado.mensaje := 'ERR90002: Error al obtener hora - ' || v_mensaje;
                RETURN v_resultado;
            END IF;
            
            pag_cta.pr_set_nro_documento3(p_cod_intencion);
            pag_cta.pr_set_nro_documento2(NULL);
            pag_cta.pr_set_variables(
                p_contexto.cod_usuario, p_contexto.fec_actual, p_cod_tra_padre,
                'N', 'N', v_nro_secuencia, NULL,
                p_cuenta_debito.cod_oficina, p_cuenta_debito.cod_modulo, p_cuenta_debito.cod_modalidad
            );
            
            pag_cta.pr_act_operacion(
                p_nomina.beneficiarios(i).nro_cta_credito, v_hora, 'C',
                p_cuenta_debito.cod_moneda, p_nomina.beneficiarios(i).monto,
                p_cod_tra_padre, 602, p_cod_autorizacion, NULL,
                p_cuenta_debito.cod_oficina, p_cuenta_debito.cod_modulo,
                p_cuenta_debito.cod_modalidad, NULL, NULL, pv_concepto,
                'N', v_nro_secuencia, p_contexto.fec_valor
            );
            
            IF pag_cta.g_cod_error <> 0 THEN
                IF pag_cta.g_cod_error IN (33, 34) THEN
                    CASE fug_obt_est_cuenta(p_nomina.beneficiarios(i).nro_cta_credito)
                        WHEN 'C' THEN v_resultado.cod_error := 90011; v_resultado.mensaje := 'ERR90011: Cuenta credito cancelada ' || p_nomina.beneficiarios(i).nro_cta_credito;
                        WHEN 'B' THEN v_resultado.cod_error := 90012; v_resultado.mensaje := 'ERR90012: Cuenta credito con bloqueo ' || p_nomina.beneficiarios(i).nro_cta_credito;
                        WHEN 'P' THEN v_resultado.cod_error := 90013; v_resultado.mensaje := 'ERR90013: Cuenta credito pendiente de cancelacion ' || p_nomina.beneficiarios(i).nro_cta_credito;
                        WHEN 'T' THEN v_resultado.cod_error := 90014; v_resultado.mensaje := 'ERR90014: Cuenta credito con bloqueo total ' || p_nomina.beneficiarios(i).nro_cta_credito;
                        WHEN 'X' THEN v_resultado.cod_error := 90015; v_resultado.mensaje := 'ERR90015: Cuenta credito en verificacion ' || p_nomina.beneficiarios(i).nro_cta_credito;
                        ELSE v_resultado.cod_error := 90016; v_resultado.mensaje := 'ERR90016: Estado de cuenta credito invalida ' || p_nomina.beneficiarios(i).nro_cta_credito;
                    END CASE;
                ELSE
                    v_resultado.cod_error := 90017;
                    v_resultado.mensaje := 'ERR90017: Error durante validacion Cta. Credito ' || p_nomina.beneficiarios(i).nro_cta_credito || ' - cod. ' || pag_cta.fu_obt_cod_error || ' ' || pag_cta.fu_obt_msj_error;
                END IF;
                
                v_resultado.es_valido := 'N';
                p_nomina.beneficiarios(i).cod_operacion := NULL;
                p_nomina.beneficiarios(i).observacion := v_resultado.mensaje;
                prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                    substr(fu_gen_ubicacion() || '-' || v_resultado.mensaje, 1, 4000));
                RETURN v_resultado;
            ELSE
                p_nomina.beneficiarios(i).cod_operacion := p_contexto.cod_usuario || '-' || 
                    TO_CHAR(p_contexto.fec_actual, 'yyyy-mm-dd') || '-' || v_hora;
                p_nomina.beneficiarios(i).observacion := NULL;
            END IF;
        END LOOP;
        return v_resultado;
    EXCEPTION
        WHEN OTHERS THEN
            v_resultado.es_valido := 'N';
            v_resultado.cod_error := 90020;
            v_resultado.mensaje := 'ERR90020: Error al procesar cuentas credito - ' || SQLERRM;
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-' || v_resultado.mensaje, 1, 4000));
            return v_resultado;
    END fu_pro_credito;

    /*********************************************/
    -- CAPA DE PRESENTACIÓN: Formateo de respuesta
    /*********************************************/
    
    FUNCTION fu_con_respuesta(
        p_codigo  IN NUMBER,
        p_mensaje IN VARCHAR2,
        p_nomina  IN typ_nomina DEFAULT NULL
    ) RETURN CLOB IS
        v_json      json_object_t := json_object_t();
        v_data_obj  json_object_t;
        v_benef_arr json_array_t;
        v_benef_obj json_object_t;
    BEGIN
        v_json.put('code', p_codigo);
        v_json.put('message', p_mensaje);
        
        IF p_nomina.cod_nomina IS NOT NULL THEN
            v_data_obj := json_object_t();
            v_data_obj.put('id', p_nomina.cod_nomina);
            v_benef_arr := json_array_t();
            
            FOR i IN 1..p_nomina.beneficiarios.COUNT LOOP
                v_benef_obj := json_object_t();
                v_benef_obj.put('id', p_nomina.beneficiarios(i).cod_empleado);
                v_benef_obj.put('salary', p_nomina.beneficiarios(i).monto);
                v_benef_obj.put('accountNumber', p_nomina.beneficiarios(i).nro_cta_credito);
                v_benef_obj.put('operationId', p_nomina.beneficiarios(i).cod_operacion);
                v_benef_obj.put('observation', p_nomina.beneficiarios(i).observacion);
                v_benef_arr.append(v_benef_obj);
            END LOOP;
            
            -- TREAT convierte el json_array_t a json_element_t para el método put
            v_data_obj.put('beneficiaries', TREAT(v_benef_arr AS json_element_t));
            v_json.put('processResult', v_data_obj);
        ELSE
            v_json.put_null('processResult');
        END IF;

        
        prg_ins_log_intencion(p_cod_intencion, 'INFO',substr( 'FIN: Proceso finalizado con código ' || p_codigo || ' y mensaje: ' || p_mensaje, 1, 4000)); 
        RETURN v_json.to_clob();
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            v_json := json_object_t();
            v_json.put('code', 20001);
            v_json.put('message', 'ERR20001: Error en construir json - ' || SQLERRM);
            v_json.put_null('processResult');
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-code: 20001 - message: ERR20001: Error en construir json - ' || SQLERRM, 1, 4000));
            prg_ins_log_intencion(p_cod_intencion, 'ERROR', 
                substr('code: 20001 - message: ERR20001: Error en construir json - ' || SQLERRM, 1, 4000));
            RETURN v_json.to_clob();
    END fu_con_respuesta;

    /*********************************************/
    -- PROCEDIMIENTO PRINCIPAL (Orquestador)
    /*********************************************/
BEGIN
    -- Log inicio del proceso
    v_tiempo_inicio := SYSTIMESTAMP;
    prg_ins_log_intencion(p_cod_intencion, 'INFO', 'INICIO: Proceso de pago de salarios iniciado');

    BEGIN
        -- Preparar registro para insertar
        v_registro_insert.cod_intencion := p_cod_intencion;
        v_registro_insert.estado := 'PROCESANDO';
        v_registro_insert.respuesta := NULL;
        
        -- Intentar insertar el registro
        it.prg_ins_estado_pago_int(v_registro_insert, v_inserto, v_registro_out);
        
        -- Si ya existía un registro previo, devolver su respuesta
        IF NOT v_inserto THEN
            prg_ins_log_intencion(p_cod_intencion, 'WARN', 
                'Intención ya procesada previamente con estado: ' || v_registro_out.estado);
            p_resultado := v_registro_out.respuesta;
            RETURN;
        END IF;
        
        -- Si se insertó correctamente, continuar con el procesamiento
        prg_ins_log_intencion(p_cod_intencion, 'INFO', 
            'Registro insertado. Continuando con el procesamiento.');
    EXCEPTION
        WHEN OTHERS THEN
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-Error al insertar estado de pago: ' || SQLERRM, 1, 4000));
            p_resultado := fu_con_respuesta(10100, 'ERR10100: Error al verificar estado de procesamiento - ' || SQLERRM);
            RETURN;
    END;
    
    -- 1. Parsear entrada
    BEGIN
        r_nomina := fu_parsearjson(p_json, v_error_parseo, v_mensaje_parseo);
        IF v_error_parseo <> 0 THEN
            p_resultado := fu_con_respuesta(v_error_parseo, v_mensaje_parseo);
            prg_upd_estado_pago_int(p_cod_intencion, 'ERROR_PARSEO', p_resultado);
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-ERR10099: Error inesperado en parseo: ' || SQLERRM, 1, 4000));
            p_resultado := fu_con_respuesta(10099, 'ERR10099: Error inesperado en parseo - ' || SQLERRM);
            prg_upd_estado_pago_int(p_cod_intencion, 'ERROR_EXCEPTION_PARSEO', p_resultado);
            RETURN;
    END;
    
    -- . Verificar horario
    BEGIN
        fu_ser_ver_horario(
            r_cuenta_debito.cod_oficina, 3, r_contexto, v_error_horario, v_mensaje_horario
        );
        IF v_error_horario <> 0 THEN
            p_resultado := fu_con_respuesta(v_error_horario, v_mensaje_horario);
            prg_upd_estado_pago_int(p_cod_intencion, 'ERROR_HORARIO', p_resultado);
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-ERR81099: Error inesperado verificando horario: ' || SQLERRM, 1, 4000));
            p_resultado := fu_con_respuesta(81099, 'ERR81099: Error inesperado verificando horario - ' || SQLERRM);
            prg_upd_estado_pago_int(p_cod_intencion, 'ERROR_EXCEPTION_HORARIO', p_resultado);
            RETURN;
    END;
    
    -- 2. Obtener cuenta débito
    BEGIN
        r_cuenta_debito := fu_rep_obt_cuenta(p_nro_cta_debito, 'DEBITO', v_error_cuenta_deb, v_mensaje_cuenta_deb);
        IF v_error_cuenta_deb <> 0 THEN
            p_resultado := fu_con_respuesta(v_error_cuenta_deb, v_mensaje_cuenta_deb);
            prg_upd_estado_pago_int(p_cod_intencion, 'ERROR_CUENTA_DEBITO', p_resultado);
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-ERR30099: Error inesperado obteniendo cuenta débito: ' || SQLERRM, 1, 4000));
            p_resultado := fu_con_respuesta(30099, 'ERR30099: Error inesperado obteniendo cuenta débito - ' || SQLERRM);
            prg_upd_estado_pago_int(p_cod_intencion, 'ERROR_EXCEPTION_CUENTA_DEBITO', p_resultado);
            RETURN;
    END;
    
    -- 3. Calcular total
    BEGIN

        v_total_debito := fu_cal_total(r_nomina, v_error_total, v_mensaje_total);
        IF v_error_total <> 0 THEN
            p_resultado := fu_con_respuesta(v_error_total, v_mensaje_total);
            prg_upd_estado_pago_int(p_cod_intencion, 'ERROR_TOTAL', p_resultado);
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-ERR60099: Error inesperado calculando total: ' || SQLERRM, 1, 4000));
            p_resultado := fu_con_respuesta(60099, 'ERR60099: Error inesperado calculando total - ' || SQLERRM);
            prg_upd_estado_pago_int(p_cod_intencion, 'ERROR_EXCEPTION_TOTAL', p_resultado);
            RETURN;
    END;
    
    -- 4. Validar cuenta débito
    BEGIN
        v_tiempo_inicio_val := SYSTIMESTAMP;
        prg_ins_log_intencion(p_cod_intencion, 'INFO', 'INICIO VALIDACION: Validando cuentas debito y credito');
        
        r_resultado_validacion_deb := fu_val_cta_debito(
            p_nro_cta_debito, r_cuenta_debito, v_total_debito, p_cod_tra_padre
        );
        IF r_resultado_validacion_deb.es_valido = 'N' THEN
            p_resultado := fu_con_respuesta(r_resultado_validacion_deb.cod_error, r_resultado_validacion_deb.mensaje);
            prg_upd_estado_pago_int(p_cod_intencion, 'ERROR_VALIDACION_DEBITO', p_resultado);
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-ERR80099: Error inesperado validando cuenta débito: ' || SQLERRM, 1, 4000));
            p_resultado := fu_con_respuesta(80099, 'ERR80099: Error inesperado validando cuenta débito - ' || SQLERRM);
            prg_upd_estado_pago_int(p_cod_intencion, 'ERROR_EXCEPTION_VALIDACION_DEBITO', p_resultado);
            RETURN;
    END;
    
    -- 5. Validar cuentas crédito
    DECLARE 
     v_es_valido varchar2(1) := 'S';
    BEGIN
        FOR i IN 1..r_nomina.beneficiarios.COUNT LOOP
            r_resultado_validacion_cre := null;
            
            r_resultado_validacion_cre := fu_val_cta_credito(
                r_nomina, r_nomina.beneficiarios(i), r_cuenta_debito, p_cod_tra_padre
            );
            
            IF r_resultado_validacion_cre.es_valido = 'N' THEN
                r_nomina.beneficiarios(i).observacion := r_resultado_validacion_cre.mensaje;           
                v_es_valido := 'N';
            END IF;
        END LOOP;
        IF v_es_valido = 'N' THEN
            p_resultado := fu_con_respuesta(70000, 'ERR70000: Error al validar cuentas creditos', r_nomina);
            prg_upd_estado_pago_int(p_cod_intencion, 'ERROR_VALIDACION_CREDITO', p_resultado);
            RETURN;
        END IF;
        
        -- Log fin de validación
        v_tiempo_fin_val := SYSTIMESTAMP;
        v_tiempo_validacion := fu_cal_tiempo_transcurrido(v_tiempo_inicio_val, v_tiempo_fin_val);
        prg_ins_log_intencion(p_cod_intencion, 'INFO', 'FIN VALIDACION: Validacion completada en ' || 
                              TO_CHAR(v_tiempo_validacion, '999990.999') || ' segundos');
    EXCEPTION
        WHEN OTHERS THEN
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-ERR70099: Error inesperado validando cuentas crédito: ' || SQLERRM, 1, 4000));
            p_resultado := fu_con_respuesta(70099, 'ERR70099: Error inesperado validando cuentas crédito - ' || SQLERRM);
            prg_upd_estado_pago_int(p_cod_intencion, 'ERROR_EXCEPTION_VALIDACION_CREDITO', p_resultado);
            RETURN;
    END;
    
    
    
    -- 7. Preparar contexto de operación
    BEGIN
        r_contexto.cod_usuario := fu_ser_obt_usuario('PAGSAL', v_error_usuario, v_mensaje_usuario);
        IF v_error_usuario <> 0 THEN
            p_resultado := fu_con_respuesta(v_error_usuario, v_mensaje_usuario);
            prg_upd_estado_pago_int(p_cod_intencion, 'ERROR_USUARIO', p_resultado);
            RETURN;
        END IF;
        
        r_contexto.hora := fu_ser_cal_hora(r_contexto.cod_usuario, v_error_hora, v_mensaje_hora);
        IF v_error_hora <> 0 THEN
            p_resultado := fu_con_respuesta(v_error_hora, v_mensaje_hora);
            prg_upd_estado_pago_int(p_cod_intencion, 'ERROR_HORA', p_resultado);
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-ERR40099: Error inesperado preparando contexto: ' || SQLERRM, 1, 4000));
            p_resultado := fu_con_respuesta(40099, 'ERR40099: Error inesperado preparando contexto - ' || SQLERRM);
            prg_upd_estado_pago_int(p_cod_intencion, 'ERROR_EXCEPTION_CONTEXTO', p_resultado);
            RETURN;
    END;
    
    -- 8. Procesar débito
    BEGIN
       v_tiempo_inicio_pago := SYSTIMESTAMP;
       prg_ins_log_intencion(p_cod_intencion, 'INFO', 'INICIO PAGO: Procesando debito y creditos');
       
       r_resultado_proc_debito := fu_pro_debito(
            r_cuenta_debito, v_total_debito, r_contexto,
            v_concepto, p_cod_tra_padre, p_cod_intencion
        );
        
        IF r_resultado_proc_debito.es_valido = 'N' THEN
            p_resultado := fu_con_respuesta(r_resultado_proc_debito.cod_error, r_resultado_proc_debito.mensaje);
            prg_upd_estado_pago_int(p_cod_intencion, 'ERROR_DEBITO', p_resultado);
            ROLLBACK;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-ERR82099: Error inesperado procesando débito: ' || SQLERRM, 1, 4000));
            p_resultado := fu_con_respuesta(82099, 'ERR82099: Error inesperado procesando débito - ' || SQLERRM);
            prg_upd_estado_pago_int(p_cod_intencion, 'ERROR_EXCEPTION_DEBITO', p_resultado);
            ROLLBACK;
            RETURN;
    END;
    
    -- 9. Procesar créditos 
    BEGIN
       r_resultado_proc_creditos := fu_pro_credito(
            r_nomina, r_cuenta_debito, r_contexto,
            v_concepto, p_cod_tra_padre, p_cod_intencion
        );
        
        IF r_resultado_proc_creditos.es_valido = 'N' THEN
            p_resultado := fu_con_respuesta(r_resultado_proc_creditos.cod_error, r_resultado_proc_creditos.mensaje);
            prg_upd_estado_pago_int(p_cod_intencion, 'ERROR_CREDITO', p_resultado);
            ROLLBACK;
            RETURN;
        END IF;
        
        -- Log fin de pago
        v_tiempo_fin_pago := SYSTIMESTAMP;
        v_tiempo_pago := fu_cal_tiempo_transcurrido(v_tiempo_inicio_pago, v_tiempo_fin_pago);
        prg_ins_log_intencion(p_cod_intencion, 'INFO', 'FIN PAGO: Pago completado en ' || 
                              TO_CHAR(v_tiempo_pago, '999990.999') || ' segundos');
    EXCEPTION
        WHEN OTHERS THEN
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-ERR90099: Error inesperado procesando créditos: ' || SQLERRM, 1, 4000));
            p_resultado := fu_con_respuesta(90099, 'ERR90099: Error inesperado procesando créditos - ' || SQLERRM);
            prg_upd_estado_pago_int(p_cod_intencion, 'ERROR_EXCEPTION_CREDITO', p_resultado);
            ROLLBACK;
            RETURN;
    END;
    
    -- 10. Generar respuesta exitosa
    BEGIN
        
        
        -- Log fin del proceso con resumen de tiempos
        v_tiempo_total := fu_cal_tiempo_transcurrido(v_tiempo_inicio, SYSTIMESTAMP);
        prg_ins_log_intencion(p_cod_intencion, 'INFO', 
            'FIN: Proceso completado exitosamente. Tiempo total: ' || TO_CHAR(v_tiempo_total, '999990.999') || 
            's | Validacion: ' || TO_CHAR(v_tiempo_validacion, '999990.999') || 
            's | Pago: ' || TO_CHAR(v_tiempo_pago, '999990.999') || 's');
        
        p_resultado := fu_con_respuesta(0, 'SUCCESS: Proceso completado exitosamente', r_nomina);
        
        prg_upd_estado_pago_int(p_cod_intencion, 'COMPLETADO', p_resultado);
        
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
                substr(fu_gen_ubicacion() || '-ERR00099: Error inesperado al finalizar proceso: ' || SQLERRM, 1, 4000));
            p_resultado := fu_con_respuesta(99, 'ERR00099: Error inesperado al finalizar proceso - ' || SQLERRM, r_nomina);
            prg_upd_estado_pago_int(p_cod_intencion, 'ERROR_FINALIZACION', p_resultado);
            ROLLBACK;
            RETURN;
    END;
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        prg_ins_log_pag_int_salario(p_cod_intencion, NULL, NULL,
            substr(fu_gen_ubicacion() || '-Error al intentar pagar salarios ' || SQLERRM, 1, 4000));
        p_resultado := fu_con_respuesta(99999, 'ERR99999: Error general al intentar pagar salarios - ' || SQLERRM, r_nomina);
        prg_upd_estado_pago_int(p_cod_intencion, 'ERROR_GENERAL', p_resultado);
END prw_pag_int_salarios;
/