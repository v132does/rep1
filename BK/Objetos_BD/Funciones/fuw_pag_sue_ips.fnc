CREATE OR REPLACE FUNCTION IT.fuw_pag_sue_ips( p_nro_cta_debito   IN ge_cuentas.nro_cuenta%type,
                                               p_nro_doc_deb      IN ba_personas.nro_documento%type,
                                               p_nro_cta_credito  IN ge_cuentas.nro_cuenta%type,
                                               p_nro_doc_cre      IN ba_personas.nro_documento%type,
                                               p_importe          IN NUMBER,
                                               p_tip_operacion    IN VARCHAR2,
                                               p_nro_operacion    IN NUMBER,
                                               p_modo             IN VARCHAR2 DEFAULT 'V',
                                               p_nro_lote         IN NUMBER
                                              ) RETURN clob IS

    v_error                VARCHAR2(1)     := 'N';
    v_cod_respuesta        VARCHAR2(50)    := 'OK';
    v_des_respuesta        VARCHAR2(1000)  := 'Operacion realizada con exito';
    v_data                 json_object_t   :=json_object_t();
    v_data_moneda          json_object_t   :=json_object_t();   --objeto moneda;
  
    C_OBT_DAT_ENT          CONSTANT VARCHAR2(60) := 'ERR_OBT_DAT_ENT_';
    C_OBT_CUE_DEB          CONSTANT VARCHAR2(60) := 'ERR_OBT_CUE_DEB_';
    C_OBT_CUE_CRE          CONSTANT VARCHAR2(60) := 'ERR_OBT_CUE_CRE_';
    C_VAL_CUE_DCR          CONSTANT VARCHAR2(60) := 'ERR_VAL_CUE_DCR_';
    C_MOV_GEN_DCR          CONSTANT VARCHAR2(60) := 'ERR_MOV_GEN_DCR_';
    C_VAL_DAT_ENT          CONSTANT VARCHAR2(60) := 'ERR_VAL_DAT_ENT_';
    C_GEN_PAG_SUE          CONSTANT VARCHAR2(60) := 'ERR_GEN_PAG_SUE_';
    /*UES-1503 - glopez*/
    C_OBT_HORARIO          CONSTANT VARCHAR2(60) := 'ERR_OBT_HORARIO_';
  
    v_cod_tip_cue_cre      VARCHAR2(5);
    v_cod_tip_cue_deb      VARCHAR2(5);
    v_cod_mon_cre          ge_cuentas.cod_moneda%type;
    v_cod_mon_deb          ge_cuentas.cod_moneda%type;
    v_des_mon_deb          ba_monedas.descripcion%type;
    v_des_mon_cre          ba_monedas.descripcion%type;
    v_des_tip_cue_cre      ge_modalidades.descripcion%type;
    v_des_tip_cue_deb      ge_modalidades.descripcion%type;
    v_cod_mod_deb          ge_cuentas.cod_modulo%type;
    v_cod_mod_cre          ge_cuentas.cod_modulo%type;
    v_cod_mad_deb          ge_cuentas.cod_modalidad%type;
    v_cod_mad_cre          ge_cuentas.cod_modalidad%type;
    v_nom_cue_deb          ge_cuentas.denominacion%type;
    v_nom_cue_cre          ge_cuentas.denominacion%type;
    v_cod_ente             ge_entes.cod_ente%type;
    v_des_ente             ge_entes.descripcion%type;
    v_cod_per_deb          ba_personas.cod_persona%type;
    v_cod_per_cre          ba_personas.cod_persona%type;
    v_nro_cta_deb_ente     ge_cuentas.nro_cuenta%type;
    v_cod_ent_cre          ge_entes.cod_ente%type;
    v_cod_ent_deb          ge_entes.cod_ente%type;
    v_des_est_cue_deb      VARCHAR2(150);
    v_des_est_cue_cre      VARCHAR2(150);
    v_tip_doc_per_cre      VARCHAR2(150);
    v_tip_doc_per_deb      VARCHAR2(150);

  
    v_concepto             ge_movimientos.concepto%type;
    v_nro_cta_deb_jub      ge_cuentas.nro_cuenta%type;
    v_nro_cta_deb_pre      ge_cuentas.nro_cuenta%type;
    v_nro_cta_deb_sue      ge_cuentas.nro_cuenta%type;
    v_cod_tra_pad_aho_jub  ge_movimientos.cod_tra_padre%type; 
    v_cod_tra_pad_cte_jub  ge_movimientos.cod_tra_padre%type; 
    v_cod_tra_deb_ips      ge_movimientos.cod_transaccion%type; 
    v_cod_tra_aho_jub      ge_movimientos.cod_transaccion%type;
    v_cod_tra_cte_jub      ge_movimientos.cod_transaccion%type;
    v_cod_tra_aho_pre      ge_movimientos.cod_transaccion%type;
    v_cod_tra_cte_pre      ge_movimientos.cod_transaccion%type;
    v_cod_tra_aho_sue      ge_movimientos.cod_transaccion%type;
    v_cod_tra_cte_sue      ge_movimientos.cod_transaccion%type;
    v_cod_tra_padre        ge_movimientos.cod_tra_padre%type;
    v_cod_tra_debito       ge_movimientos.cod_transaccion%type;
    v_cod_tra_credito      ge_movimientos.cod_transaccion%type;
  
    v_est_debito           ge_cuentas.estado%TYPE;
    v_est_credito          ge_cuentas.estado%TYPE;
    v_nvo_est_debito       ge_cuentas.estado%TYPE;
    v_nvo_est_credito      ge_cuentas.estado%TYPE;
    v_sal_dis_deb          ge_movimientos.monto%TYPE;
    v_sal_dis_cre          ge_movimientos.monto%TYPE;
  
    v_nro_secuencia        ge_movimientos.nro_secuencia%TYPE  := 0;
    v_cod_usuario          ge_movimientos.cod_usuario%TYPE    := USER;
    v_hora                 ge_movimientos.hora%TYPE           := fug_ini_hora(SYSDATE, 'HH24:MI:SS');
    v_fec_actual           ge_calendarios.fec_actual%TYPE     := pag_cal.fu_obt_fec_actual(1);
    v_fec_insercion        ge_movimientos.fec_valor%type;
    v_hor_insercion        VARCHAR2(50);
    v_pro_deb              VARCHAR2(1);
    v_pro_cre              VARCHAR2(1);
  
    v_nro_cta_debito       ge_cuentas.nro_cuenta%type; 
    v_nro_cta_credito      ge_cuentas.nro_cuenta%type;    
    v_nro_doc_per_cre      ba_personas.nro_documento%type;
    v_nro_doc_per_deb      ba_personas.nro_documento%type; 
    v_importe              ge_movimientos.monto%type;     
    v_tip_operacion        VARCHAR2(3);                    
    v_nro_operacion        NUMBER;                        
    v_modo                 VARCHAR2(1); 
    v_nro_lote_ref         NUMBER;        
    v_nom_per_deb          ba_personas.nom_completo%type;   
    v_nom_per_cre          ba_personas.nom_completo%type;  
    v_cod_ofi_origen       ge_movimientos.cod_ofi_origen%type;
    v_exi_mov              VARCHAR(1):= 'N';
    v_tipo                 ge_pag_sue_ips.tip_proceso%type;
    v_nro_lote_ips         ge_pag_sue_ips.nro_lote%type;
    v_nro_lote_sue         ge_pag_sueldos.nro_lote%type;
    v_nro_doc_per_deb_cta  ba_personas.nro_documento%type;
    v_nro_doc_per_cre_cta  ba_personas.nro_documento%type;
  
    /*UES-1503 - glopez*/
    v_mod_estado           ba_modulos.estado%TYPE;
    v_horario              VARCHAR2(1);
    v_es_mov_noc           VARCHAR2(1);
    v_es_cta_noc           VARCHAR2(1);
    v_fec_valor            ge_calendarios.fec_actual%type;
    v_est_inicial          ba_modulos.estado%type;

    /*UES-1503 - Se agrega para verificar si se puede ejecutar durante el cierre*/
    procedure lp_ver_horario(p_cod_ofi_origen ba_oficinas.cod_oficina%type,
                           p_modulo         in ba_modulos.cod_modulo%type,
                           p_horario        out varchar2,
                           p_es_mov_noc     out varchar2,
                           p_es_cta_noc     out varchar2,
                           p_fec_actual     out date,
                           p_fec_valor      out date,
                           p_cod_error      out varchar2,
                           p_men_error      out varchar2,
                           v_error          out varchar2) is

        v_est_modulo ba_modulos.estado%type;
    begin
        p_cod_error  := '';
        v_error      := 'N';
        p_horario    := 'D'; -- dia normal
        p_es_mov_noc := 'N'; -- para grabar en las tablas nocturnas
        p_es_cta_noc := 'N';
        p_fec_actual := pag_cal.fu_obt_fec_actual(p_modulo);
        v_est_modulo := pae_cnf.fu_obt_est_modulo(p_modulo);


        if fug_obt_pardinamico('ACT_NOCTURNO') = 'N' then
            p_cod_error := C_OBT_HORARIO||'1';
            p_men_error := 'Modulo en proceso de cierre';
            v_error     := 'S';
        elsif v_est_modulo in (1,6) then
            p_cod_error := C_OBT_HORARIO||'2';
            p_men_error := 'Modulo en proceso de cierre. Estado: ' || v_est_modulo;
            v_error     := 'S';
        elsif v_est_modulo = 2 then
            p_horario    := 'D'; -- dia normal
            p_es_mov_noc := 'N'; -- para grabar en las tablas nocturnas
            p_es_cta_noc := 'N';
            p_fec_actual := pag_cal.fu_obt_fec_actual(p_modulo);
            v_error      := 'N';
        else
            p_horario := 'N'; -- noche
            if v_est_modulo <> 1 then
                p_fec_actual := pag_cal.fu_obt_fec_habil(p_fec_actual + 1,
                                                     1,
                                                     p_cod_ofi_origen);
            end if;
            p_es_mov_noc := 'S'; -- para grabar en las tablas nocturnas
            p_es_cta_noc := 'S'; -- solo para que llavee la cuenta nocturna
            v_error      := 'N';
        end if;
        pag_cta.g_horario := p_horario;
        p_fec_valor       := trunc(sysdate);
        v_mod_estado      := v_est_modulo;
    EXCEPTION
        WHEN OTHERS THEN
            v_error      := 'S';
            p_cod_error  := C_OBT_HORARIO||'3';
            p_men_error  := 'Ocurrio un error en la verificacion de horario ' || sqlerrm;
    END lp_ver_horario;
    
    FUNCTION fu_obt_response(p_error varchar2, p_cod_respuesta varchar2, p_des_respuesta varchar2, p_data json_object_t) 
        RETURN clob IS
        v_response json_object_t := json_object_t();
    BEGIN
        v_response.put('error'                ,p_error);
        v_response.put('nombreRespuesta'      ,p_cod_respuesta);
        v_response.put('descripcionRespuesta' ,p_des_respuesta);
        v_response.put('data'                 ,p_data);
        RETURN v_response.to_clob;
    END fu_obt_response;   
  
  
    FUNCTION fu_cta_valida(p_nro_cuenta    VARCHAR2,
                        p_nro_documento IN VARCHAR2
                        ) RETURN VARCHAR2 IS
        v_sino          VARCHAR2(01) := 'N';
        v_tip_persona   VARCHAR2(1);
        v_cod_persona   VARCHAR2(20);
        v_nro_documento VARCHAR2(20) := p_nro_documento;

    BEGIN
        SELECT tipo, a.cod_persona
        INTO v_tip_persona, v_cod_persona
        FROM ba_personas b, ge_cta_clientes a
        WHERE a.nro_cuenta = p_nro_cuenta
        AND a.relacion = 'P'
        AND a.cod_persona = b.cod_persona;
        BEGIN
            IF v_tip_persona = 'J' THEN
                -- empresa
                -- busqueda por principal para ver si es el documento de la empresa
                SELECT 'S'
                INTO v_sino
                FROM ba_personas a
                WHERE a.cod_persona   = v_cod_persona
                AND a.nro_documento = v_nro_documento;
            ELSE
                -- la cuenta es de una persona fisica
                SELECT 'S'
                INTO v_sino
                FROM ba_personas b
                WHERE b.nro_documento = v_nro_documento
                AND b.cod_persona IN (SELECT x.cod_persona
                                          FROM ge_cta_clientes x
                                         WHERE x.nro_cuenta = p_nro_cuenta
                                           AND x.cod_persona = b.cod_persona)
                AND rownum = 1; -- primero que encuentre
            END IF;
        END;
        RETURN v_sino;
    EXCEPTION
        WHEN OTHERS THEN
            v_sino := 'N';
            RETURN v_sino;
    END fu_cta_valida;
 
    PROCEDURE pr_ins_bitacora(p_mensaje IN VARCHAR2) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        v_linea    VARCHAR2(1000);
        v_objeto   VARCHAR2(1000);
        v_llamador VARCHAR2(1000);
        v_duenho   VARCHAR2(1000);   
    BEGIN
        OWA_UTIL.WHO_CALLED_ME(v_duenho, v_objeto, v_linea, v_llamador);
      
        INSERT INTO GE_PAG_SUE_IPS_LOG
         (FECHA, nro_lote, nro_orden, MENSAJE)
        VALUES
         (SYSDATE, NULL, NULL, v_objeto || '.' || v_linea || ': ' || p_mensaje);
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
            ROLLBACK;
    END pr_ins_bitacora; 
  
    PROCEDURE pr_obt_dat_ente(p_cod_ente     IN NUMBER,
                           p_error         IN OUT VARCHAR2, 
                           p_cod_respuesta IN OUT VARCHAR2, 
                           p_des_respuesta IN OUT VARCHAR2 
                           ) IS
  
    BEGIN
   
        IF p_cod_ente IS NULL THEN
            p_error         := 'S';
            p_cod_respuesta := C_OBT_DAT_ENT||1;
            p_des_respuesta := 'No existe un parametro definido para el ente IPS';
            RETURN;   
        END IF;
   
        -- Obtenemos datos del ente
        BEGIN
            SELECT a.descripcion
            INTO v_des_ente
            FROM ge_entes a
            WHERE a.cod_ente    = v_cod_ente
            AND a.tipo        = 'SU'
            AND it.fug_obt_parentes(a.cod_ente, 'SER_ACTIVO') = 'S';
        EXCEPTION
            WHEN no_data_found THEN
                p_error := 'S';
                p_cod_respuesta := C_OBT_DAT_ENT||2;
                p_des_respuesta := 'No existe un ente configurado';
                RETURN; 
            WHEN too_many_rows THEN
                p_error := 'S';
                p_cod_respuesta := C_OBT_DAT_ENT||3;
                p_des_respuesta := 'Existe mas de un Ente ingresado';
                RETURN;
            WHEN OTHERS THEN
                p_error := 'S';
                p_cod_respuesta := C_OBT_DAT_ENT||4;
                p_des_respuesta := 'Error al obtener datos del ente '||sqlerrm ;
                RETURN;
        END;
   
        v_nro_cta_deb_jub := fug_obt_parentes(p_cod_ente, 'NRO_CTA_DEB_JUB');
        IF v_nro_cta_deb_jub IS NULL THEN
            p_error         := 'S';
            p_cod_respuesta := C_OBT_DAT_ENT||5;
            p_des_respuesta := 'ATENCION. La empresa no posee Nro de cuenta para pago a jubilados. Verifique!!!';
            RETURN;
        END IF;
    
        v_nro_cta_deb_pre := fug_obt_parentes(p_cod_ente, 'NRO_CTA_DEB_PRE');
        IF v_nro_cta_deb_pre IS NULL THEN
            p_error         := 'S';
            p_cod_respuesta := C_OBT_DAT_ENT||6;
            p_des_respuesta := 'ATENCION. La empresa no posee Nro de Cuenta para pago de prestamos. Verifique!!!';
            RETURN;
        END IF;
    
        v_nro_cta_deb_sue := fug_obt_parentes(p_cod_ente, 'NRO_CTA_DEB_SUE');
        IF v_nro_cta_deb_sue IS NULL THEN
            p_error         := 'S';
            p_cod_respuesta := C_OBT_DAT_ENT||7;
            p_des_respuesta := 'ATENCION. La empresa no posee Nro de Cuenta para pago de sueldos . Verifique!!!';
            RETURN;
        END IF;
    
        IF v_tip_operacion = 'IJ' THEN   --IPS JUBILADOS
            v_nro_cta_deb_ente := v_nro_cta_deb_jub;
        ELSIF v_tip_operacion = 'IP' THEN  --IPS PRESTAMOS
            v_nro_cta_deb_ente := v_nro_cta_deb_pre;
        ELSIF v_tip_operacion = 'IS' THEN  --IPS SUELDOS 
            v_nro_cta_deb_ente := v_nro_cta_deb_sue;
        END IF; 
   
        IF v_nro_cta_deb_ente != v_nro_cta_debito then
            p_error := 'S';
            p_cod_respuesta := C_OBT_DAT_ENT||8;
            p_des_respuesta := 'La cuenta Debito ingresada no corresponde al ente';
            RETURN;    
        END IF;
  
        v_cod_tra_pad_aho_jub := fug_obt_parentes(p_cod_ente, 'COD_TRA_PAD_AHO_JUB');
        IF v_cod_tra_pad_aho_jub IS NULL THEN
            p_error         := 'S';
            p_cod_respuesta := C_OBT_DAT_ENT||9;
            p_des_respuesta := 'ATENCION. La empresa no posee Transacción Padre para el modulo de ahorro para el pago a  Jubilados. Verifique!!!';
            RETURN;
        END IF;
    
        v_cod_tra_pad_cte_jub := fug_obt_parentes(p_cod_ente, 'COD_TRA_PAD_CTE_JUB');
        IF v_cod_tra_pad_cte_jub IS NULL THEN
            p_error         := 'S';
            p_cod_respuesta := C_OBT_DAT_ENT||10;
            p_des_respuesta := 'ATENCION. La empresa no posee Transacción Padre para el modulo cuenta corriente para pago a jubilados. Verifique!!!';
            RETURN;
        END IF;
  
        v_cod_tra_deb_ips  := fug_obt_parentes(p_cod_ente, 'COD_TRA_DEB_IPS');
        IF v_cod_tra_deb_ips IS NULL THEN
            p_error         := 'S';
            p_cod_respuesta := C_OBT_DAT_ENT||11;
            p_des_respuesta := 'ATENCION. La empresa no posee Transacción Débito para Ips. Verifique!!!';
            RETURN;
        END IF;
    
        v_cod_tra_aho_jub := fug_obt_parentes(p_cod_ente, 'COD_TRA_AHO_JUB');
        IF v_cod_tra_aho_jub IS NULL THEN
            p_error         := 'S';
            p_cod_respuesta := C_OBT_DAT_ENT||12;
            p_des_respuesta := 'ATENCION. La empresa no posee Transacción Credito modulo ahorro para Jubilados. Verifique!!!';
            RETURN;
        END IF;
    
        v_cod_tra_cte_jub := fug_obt_parentes(p_cod_ente, 'COD_TRA_CTE_JUB');
        IF v_cod_tra_cte_jub IS NULL THEN
            p_error         := 'S';
            p_cod_respuesta := C_OBT_DAT_ENT||13;
            p_des_respuesta := 'ATENCION. La empresa no posee Transacción Credito modulo cuenta corriente para Jubilados. Verifique!!!';
            RETURN;
        END IF;
    
        v_cod_tra_aho_pre := fug_obt_parentes(p_cod_ente, 'COD_TRA_AHO_PRE');
        IF v_cod_tra_aho_pre IS NULL THEN
            p_error         := 'S';
            p_cod_respuesta := C_OBT_DAT_ENT||14;
            p_des_respuesta := 'ATENCION. La empresa no posee Transacción Credito modulo ahorro para Prestamos. Verifique!!!';
            RETURN;
        END IF;
    
        v_cod_tra_cte_pre := fug_obt_parentes(p_cod_ente, 'COD_TRA_CTE_PRE');
        IF v_cod_tra_cte_pre IS NULL THEN
            p_error         := 'S';
            p_cod_respuesta := C_OBT_DAT_ENT||15;
            p_des_respuesta := 'ATENCION. La empresa no posee Transacción Credito modulo cuenta corriente para Prestamos. Verifique!!!';
            RETURN;
        END IF;
    
        v_cod_tra_aho_sue := fug_obt_parentes(p_cod_ente, 'COD_TRA_AHO_SUE');
        IF v_cod_tra_aho_sue IS NULL THEN
            p_error         := 'S';
            p_cod_respuesta := C_OBT_DAT_ENT||16;
            p_des_respuesta := 'ATENCION. La empresa no posee Transacción Credito modulo ahorro para Sueldos. Verifique!!!';
            RETURN;
        END IF;
    
        v_cod_tra_cte_sue := fug_obt_parentes(p_cod_ente, 'COD_TRA_CTE_SUE');
        IF v_cod_tra_cte_sue IS NULL THEN
            p_error         := 'S';
            p_cod_respuesta := C_OBT_DAT_ENT||17;
            p_des_respuesta := 'ATENCION. La empresa no posee Transacción Credito modulo cuenta corriente  para Sueldos. Verifique!!!';
            RETURN;
        END IF;
    
    END pr_obt_dat_ente;
  
  
    PROCEDURE pr_val_parametros(p_error  IN OUT VARCHAR2, 
                              p_cod_respuesta IN OUT VARCHAR2, 
                              p_des_respuesta IN OUT VARCHAR2) IS

    BEGIN
    
        IF v_modo IS NULL THEN
            p_error         := 'S';
            p_cod_respuesta := C_VAL_DAT_ENT||1;
            p_des_respuesta := 'Debe ingredar un modo';
            RETURN; 
        ELSIF v_modo NOT IN ('V','C') THEN
            p_error         := 'S';
            p_cod_respuesta :=  C_VAL_DAT_ENT||2;
            p_des_respuesta := 'El modo debe contener el valor V o C';
            RETURN; 
        END IF;
    
        IF v_tip_operacion IS NULL THEN
            p_error         := 'S';
            p_cod_respuesta :=  C_VAL_DAT_ENT||3;
            p_des_respuesta := 'Debe ingresar un tipo de operacion';
            RETURN; 
        ELSIF v_tip_operacion NOT IN ('IJ','IP','IS') THEN
            p_error         := 'S';
            p_cod_respuesta := C_VAL_DAT_ENT||4;
            p_des_respuesta := 'El tipo de operacion debe contener alguno de estos valores ( IJ, IP, IS )';
            RETURN; 
        END IF;
    
        IF v_nro_cta_debito IS NULL AND v_modo = 'C' THEN
            p_error         := 'S';
            p_cod_respuesta := C_VAL_DAT_ENT||5;
            p_des_respuesta := 'Debe ingresar una Cuenta para el debito';
            RETURN; 
        ELSIF ( v_nro_cta_debito IS NULL AND v_modo = 'V' AND v_nro_cta_credito IS NULL ) THEN
            p_error         := 'S';
            p_cod_respuesta := C_VAL_DAT_ENT||6;
            p_des_respuesta := 'Debe ingresar una Cuenta para realizar la validacion';   
            RETURN;           
        END IF;
    
        IF v_nro_cta_credito IS NULL AND v_modo = 'C' THEN
            p_error         := 'S';
            p_cod_respuesta := C_VAL_DAT_ENT||7;
            p_des_respuesta := 'Debe ingresar una Cuenta para el Credito';
            RETURN; 
        ELSIF ( v_nro_cta_credito IS NULL AND v_modo = 'V' AND v_nro_cta_debito IS NULL ) THEN
            p_error         := 'S';
            p_cod_respuesta := C_VAL_DAT_ENT||8;
            p_des_respuesta := 'Debe ingresar una Cuenta para realizar la validacion'; 
            RETURN; 
        END IF;
    
        IF ( v_nro_doc_per_deb IS NULL AND v_nro_cta_debito IS NOT NULL AND v_modo = 'V') THEN 
            p_error         := 'S';
            p_cod_respuesta := C_VAL_DAT_ENT||9;
            p_des_respuesta := 'Debe ingresar el nro de documento de la cuenta debito';
            RETURN; 
        END IF;
    
        IF ( v_nro_doc_per_cre IS NULL AND v_nro_cta_credito IS NOT NULL AND v_modo = 'V' ) THEN
            p_error         := 'S';
            p_cod_respuesta := C_VAL_DAT_ENT||10;
            p_des_respuesta := 'Debe ingresar el nro de documento de la cuenta credito'; 
            RETURN; 
        END IF;   
    END pr_val_parametros;
  
    PROCEDURE pr_obt_dat_cue_debito(p_error  IN OUT VARCHAR2, 
                                  p_cod_respuesta IN OUT VARCHAR2, 
                                  p_des_respuesta IN OUT VARCHAR2
                                  ) IS 
    BEGIN
        -- Obtenemos datos de la cuenta  
        BEGIN
            SELECT paw_bce.fu_tip_cuenta(a.cod_modulo, a.cod_modalidad) cod_tip_cuenta,
                fug_obt_des_modal(a.cod_modulo, a.cod_modalidad) des_tip_cuenta,
                a.denominacion nom_cuenta,
                a.cod_moneda cod_moneda,
                a.cod_modulo,
                a.cod_modalidad,
                g.cod_persona,
                p.nom_completo nom_cliente, 
                d.abreviatura tip_documento,
                p.nro_documento,
                a.estado,
                c.descripcion des_estado
            INTO v_cod_tip_cue_deb,
                v_des_tip_cue_deb,
                v_nom_cue_deb,
                v_cod_mon_deb,
                v_cod_mod_deb,
                v_cod_mad_deb,
                v_cod_per_deb,
                v_nom_per_deb,
                v_tip_doc_per_deb,
                v_nro_doc_per_deb_cta,
                v_est_debito,
                v_des_est_cue_deb
            FROM ge_cuentas a,
                ge_cta_clientes g,
                ge_est_cuentas c,
                ba_personas p,
                ba_tip_documentos d
            WHERE a.nro_cuenta        = nvl(v_nro_cta_debito,v_nro_cta_deb_ente)
                AND g.nro_cuenta        = a.nro_cuenta
                AND g.relacion          = 'P'
                AND g.cod_persona       = p.cod_persona
                AND a.cod_modulo        = c.cod_modulo
                AND a.cod_modalidad     = c.cod_modalidad
                AND a.estado            = c.estado
                AND p.cod_tip_documento = d.cod_tip_documento;
        EXCEPTION
            WHEN no_data_found THEN
                p_cod_respuesta   := C_OBT_CUE_DEB||1;
                p_des_respuesta   := 'Cuenta debito inexistente '||nvl(v_nro_cta_debito,v_nro_cta_deb_ente);
                p_error           := 'S';
                RETURN;
            WHEN too_many_rows THEN
                p_cod_respuesta   := C_OBT_CUE_DEB||2;
                p_des_respuesta   := 'Cuenta debito duplicada '||nvl(v_nro_cta_debito,v_nro_cta_deb_ente);
                p_error           := 'S';
                RETURN;
            WHEN others THEN
                p_cod_respuesta   := C_OBT_CUE_DEB||3;
                p_des_respuesta   := 'Cuenta debito invalida '||nvl(v_nro_cta_debito,v_nro_cta_deb_ente)||' '||SQLERRM;
                p_error           := 'S';
                RETURN;
        END;
   
        IF v_cod_mon_deb IS NOT NULL THEN
            v_des_mon_deb := it.fue_obt_des_moneda(v_cod_mon_deb);
        END IF;
   
        CASE v_est_debito
            WHEN 'C' THEN
                p_cod_respuesta   := C_OBT_CUE_DEB||13;
                p_des_respuesta   := 'Cuenta debito cancelada '||nvl(v_nro_cta_debito,v_nro_cta_deb_ente);
                p_error           := 'S';
                RETURN;
            WHEN 'B' THEN
                p_cod_respuesta   := C_OBT_CUE_DEB||14;
                p_des_respuesta   := 'Cuenta debito con bloqueo '||nvl(v_nro_cta_debito,v_nro_cta_deb_ente);
                p_error           := 'S';
                RETURN;
            WHEN 'I' THEN
                p_cod_respuesta   := C_OBT_CUE_DEB||15;
                p_des_respuesta   := 'Cuenta debito inactiva '||nvl(v_nro_cta_debito,v_nro_cta_deb_ente);
                p_error           := 'S';
                RETURN;
            WHEN 'P' THEN
                p_cod_respuesta   := C_OBT_CUE_DEB||16;
                p_des_respuesta   := 'Cuenta debito pendiente de cancelacion '||nvl(v_nro_cta_debito,v_nro_cta_deb_ente);
                p_error           := 'S';
                RETURN;
            WHEN 'T' THEN
                p_cod_respuesta   := C_OBT_CUE_DEB||17;
                p_des_respuesta   := 'Cuenta debito con bloqueo total '||nvl(v_nro_cta_debito,v_nro_cta_deb_ente);
                p_error           := 'S';
                RETURN;
            WHEN 'X' THEN
                p_cod_respuesta   := C_OBT_CUE_DEB||18;
                p_des_respuesta   := 'Cuenta debito en verificacion '||nvl(v_nro_cta_debito,v_nro_cta_deb_ente);
                p_error           := 'S';
                RETURN;
            WHEN 'A' THEN
                p_cod_respuesta   := C_OBT_CUE_DEB||19;
                p_des_respuesta   := 'No se puede realizar debitos en cuentas con estado abierto '||nvl(v_nro_cta_debito,v_nro_cta_deb_ente);
                p_error           := 'S';   
            WHEN 'D' THEN
                p_cod_respuesta   := C_OBT_CUE_DEB||20;
                p_des_respuesta   := 'La cuenta está bloqueada para débitos '||nvl(v_nro_cta_debito,v_nro_cta_deb_ente);
                p_error           := 'S';
                RETURN;
            WHEN 'S' THEN
                p_error           := 'N'; 
            WHEN 'N' THEN
                p_error           := 'N';                
            ELSE 
                p_cod_respuesta   := C_OBT_CUE_DEB||4;
                p_des_respuesta   := 'El estado de la cuenta debito no es valida '||v_est_debito || ' ' || nvl(v_nro_cta_debito,v_nro_cta_deb_ente);
                p_error           := 'S';
                RETURN;
        END CASE;
   
        IF v_cod_mad_deb NOT IN (31, 41, 38, 39, 334) THEN -- solo cuentas de ahorros y cuentas corrientes
            p_cod_respuesta   := C_OBT_CUE_DEB||5;
            p_des_respuesta   := 'La modalidad de cuenta debito no permitida '||v_cod_mad_deb;
            p_error           := 'S';
            RETURN;
        END IF;
   
        IF  v_nro_cta_debito IS NOT NULL THEN
          
            BEGIN
                SELECT t.cod_ente
                INTO v_cod_ent_deb
                FROM ah_cta_vistas t
                WHERE t.nro_cuenta = TRIM(v_nro_cta_debito)
                AND t.cod_modalidad IN (31, 41, 38, 39, 334);
            EXCEPTION
                WHEN no_data_found THEN
                    BEGIN
                        SELECT t.cod_ente
                        INTO v_cod_ent_deb
                        FROM cc_cta_corrientes t
                        WHERE t.nro_cuenta =  v_nro_cta_debito
                        AND t.cod_modalidad = 41;
                    EXCEPTION 
                        WHEN no_data_found THEN
                            p_cod_respuesta := C_OBT_CUE_DEB||6;
                            p_des_respuesta := 'La cuenta debito no tiene configurado el ente';
                            p_error         := 'S';
                            RETURN;
                    END;
                WHEN others THEN
                    p_cod_respuesta := C_OBT_CUE_DEB||7;
                    p_des_respuesta := 'Error al obtener ente de la cuenta  '||sqlerrm;
                    p_error         := 'S';
                    RETURN;
            END;
     
            -- validar importe en negativo
            IF  v_importe <= 0  THEN
                p_cod_respuesta := C_OBT_CUE_DEB||8;
                p_des_respuesta := 'Monto invalido no puede ser negativo o igual a cero';
                p_error         := 'S';
                RETURN;
            END IF;
  
            -- Validacion de Cuenta Debito
            IF v_nro_cta_deb_ente IS NOT NULL THEN
                IF ( v_nro_cta_deb_ente != v_nro_cta_debito ) THEN
                    p_error         := 'S';
                    p_cod_respuesta :=  C_OBT_CUE_DEB||9;
                    p_des_respuesta := 'La cuenta configurada en el ente no coincide con el nro de cuenta ingresado';
                    RETURN;
                END IF;
            ELSE 
                p_error         := 'S';
                p_cod_respuesta :=  C_OBT_CUE_DEB||10;
                p_des_respuesta := 'No existe una cuenta debito para el ente';
                RETURN;
            END IF;
  
            -- Validamos que la persona pertenesca a la cuenta 
            IF v_nro_doc_per_deb IS NOT NULL THEN
                IF fu_cta_valida(v_nro_cta_debito, v_nro_doc_per_deb) = 'N' THEN
                    p_cod_respuesta  := C_OBT_CUE_DEB||11;
                    p_des_respuesta  := 'El nro de documento ingresado no pertenece a la cuenta debito';
                    p_error          := 'S';
                    RETURN;
                END IF;
            ELSE 
                IF v_nro_doc_per_deb IS NULL AND v_modo = 'C' THEN
                    v_nro_doc_per_deb := v_nro_doc_per_deb_cta;
                END IF;
            END IF;
     
            IF ( v_modo = 'V' AND v_nro_cta_debito IS NOT NULL AND v_nro_cta_credito IS NOT NULL ) THEN
                p_cod_respuesta := C_OBT_CUE_DEB||12;
                p_des_respuesta := 'Para la validacion se requiere una sola cuenta como parametro de entrada ';
                p_error         := 'S';
                RETURN;
            END IF;
       
        END IF;   
     
    END; 
     
    PROCEDURE pr_obt_dat_cue_credito(p_error IN OUT VARCHAR2, 
                                   p_cod_respuesta IN OUT VARCHAR2, 
                                   p_des_respuesta IN OUT VARCHAR2
                                  ) IS 
    BEGIN
        -- Obtenemos datos de la cuenta  
        BEGIN
            SELECT paw_bce.fu_tip_cuenta(a.cod_modulo, a.cod_modalidad) cod_tip_cuenta,
            fug_obt_des_modal(a.cod_modulo, a.cod_modalidad) des_tip_cuenta,
            a.denominacion nom_cuenta,
            a.cod_moneda cod_moneda,
            a.cod_modulo,
            a.cod_modalidad,
            g.cod_persona,
            p.nom_completo nom_cliente, 
            d.abreviatura tip_documento,
            p.nro_documento, 
            a.estado,
            c.descripcion des_estado
            INTO v_cod_tip_cue_cre,
            v_des_tip_cue_cre,
            v_nom_cue_cre,
            v_cod_mon_cre,
            v_cod_mod_cre,
            v_cod_mad_cre,
            v_cod_per_cre,
            v_nom_per_cre,
            v_tip_doc_per_cre,
            v_nro_doc_per_cre_cta,
            v_est_credito,
            v_des_est_cue_cre
            FROM ge_cuentas a,
            ge_cta_clientes g,
            ge_est_cuentas c,
            ba_personas p,
            ba_tip_documentos d
            WHERE a.nro_cuenta        = v_nro_cta_credito
            AND g.nro_cuenta        = a.nro_cuenta
            AND g.relacion          = 'P'
            AND g.cod_persona       = p.cod_persona
            AND a.cod_modulo        = c.cod_modulo
            AND a.cod_modalidad     = c.cod_modalidad
            AND a.estado            = c.estado
            AND p.cod_tip_documento = d.cod_tip_documento;
        EXCEPTION
            WHEN no_data_found THEN
                p_cod_respuesta   := C_OBT_CUE_CRE||1;
                p_des_respuesta   := 'Cuenta credito inexistente '||v_nro_cta_credito;
                p_error           := 'S';
                RETURN;
            WHEN too_many_rows THEN
                p_cod_respuesta   := C_OBT_CUE_CRE||2;
                p_des_respuesta   := 'Cuenta credito duplicada '||v_nro_cta_credito;
                p_error           := 'S';
                RETURN;
            WHEN others THEN
                p_cod_respuesta   := C_OBT_CUE_CRE||3;
                p_des_respuesta   := 'Cuenta debito invalida '||SQLERRM;
                p_error           := 'S';
                RETURN;
        END;
   
        IF v_cod_mon_cre IS NOT NULL THEN
            v_des_mon_cre := it.fue_obt_des_moneda(v_cod_mon_cre);
        END IF;
   
        CASE v_est_credito
            WHEN 'C' THEN
                p_cod_respuesta   := C_OBT_CUE_CRE||13;
                p_des_respuesta   := 'Cuenta credito cancelada '||v_nro_cta_credito;
                p_error         := 'S';
                RETURN;
            WHEN 'B' THEN
                p_cod_respuesta   := C_OBT_CUE_CRE||14;
                p_des_respuesta   := 'Cuenta credito con bloqueo '||v_nro_cta_credito;
                p_error         := 'S';
                RETURN;
            WHEN 'I' THEN
                p_error         := 'N';
            WHEN 'P' THEN
                p_cod_respuesta   := C_OBT_CUE_CRE||15
                p_des_respuesta   := 'Cuenta credito pendiente de cancelacion '||v_nro_cta_credito;
                p_error         := 'S';
                RETURN;
            WHEN 'T' THEN
                p_cod_respuesta   := C_OBT_CUE_CRE||16;
                p_des_respuesta   := 'Cuenta credito con bloqueo total '||v_nro_cta_credito;
                p_error         := 'S';
                RETURN;
            WHEN 'X' THEN
                p_cod_respuesta   := C_OBT_CUE_CRE||17;
                p_des_respuesta   := 'Cuenta credito en verificacion '||v_nro_cta_credito;
                p_error         := 'S';
                RETURN;
            WHEN 'A' THEN
                p_error           := 'N';   
            WHEN 'D' THEN
                p_error           := 'N'; 
            WHEN 'S' THEN
                p_error           := 'N'; 
            WHEN 'N' THEN
                p_error           := 'N';    
            ELSE 
                p_cod_respuesta   := C_OBT_CUE_CRE||4;
                p_des_respuesta   := 'El estado de la cuenta credito no es valida '||v_est_credito || ' ' ||v_nro_cta_credito;
                p_error           := 'S';
                RETURN;
        END CASE;
   
        IF ( v_cod_mad_cre NOT IN (31, 41, 38, 39, 334) )  THEN -- solo cuentas de ahorros y cuentas corrientes  
            p_cod_respuesta   := C_OBT_CUE_CRE||5;
            p_des_respuesta   := 'Modalidad de cuenta credito no permitida  '||v_cod_mad_cre;
            p_error           := 'S';
            RETURN;
        END IF;
   
        IF ( v_nro_cta_credito IS NOT NULL ) THEN
            BEGIN
                SELECT t.cod_ente
                INTO v_cod_ent_cre
                FROM ah_cta_vistas t
                WHERE t.nro_cuenta = TRIM(v_nro_cta_credito)
                AND t.cod_modalidad IN (31, 41,38, 39, 334);
            EXCEPTION
                WHEN no_data_found THEN
                    BEGIN
                        SELECT t.cod_ente
                        INTO v_cod_ent_cre
                        FROM cc_cta_corrientes t
                        WHERE t.nro_cuenta =  v_nro_cta_credito
                        AND t.cod_modalidad = 41;
                    EXCEPTION 
                        WHEN no_data_found THEN
                            p_cod_respuesta := C_OBT_CUE_CRE||6;
                            p_des_respuesta := 'La cuenta credito no tiene configurado el ente';
                            p_error         := 'S';
                            RETURN;
                    END;
                WHEN others THEN
                    p_cod_respuesta := C_OBT_CUE_CRE||7;
                    p_des_respuesta := 'Error al obtener ente de la cuenta credito '||sqlerrm;
                    p_error         := 'S';
                    RETURN;
            END;
      
            IF nvl(v_cod_ent_cre,0) != v_cod_ente THEN
                p_cod_respuesta := C_OBT_CUE_CRE||8;
                p_des_respuesta := 'La cuenta credito no pertenece al ente o no ha sido configurado';
                p_error         := 'S';
                RETURN;
            END IF;
     
            -- validar importe en negativo
            IF  ( v_modo = 'V' AND v_importe < 0 ) THEN
                p_cod_respuesta := C_OBT_CUE_CRE||9;
                p_des_respuesta := 'Monto invalido no puede ser negativo';
                p_error         := 'S';
                RETURN;
            ELSIF ( v_modo = 'C' AND v_importe <= 0 ) THEN
                p_cod_respuesta := C_OBT_CUE_CRE||10;
                p_des_respuesta := 'Monto invalido no puede ser negativo o igual a 0';
                p_error         := 'S';
                RETURN;
            END IF;
   
            -- Validamos que la persona pertenesca a la cuenta 
            IF v_nro_doc_per_cre IS NOT NULL THEN
                IF fu_cta_valida(v_nro_cta_credito, v_nro_doc_per_cre) = 'N' THEN
                    p_cod_respuesta  := C_OBT_CUE_CRE||11;
                    p_des_respuesta  := 'El nro de documento ingresado no pertenece a la cuenta credito';
                    p_error          := 'S';
                    RETURN;
                END IF;
            ELSE 
                IF v_nro_doc_per_cre IS NULL AND v_modo = 'C' THEN
                    v_nro_doc_per_cre := v_nro_doc_per_cre_cta;
                END IF;
            END IF;
    
        ELSE
            p_cod_respuesta  := C_OBT_CUE_CRE||12;
            p_des_respuesta  := 'Debe ingresar una cuenta credito para validar';
            p_error          := 'S';
            RETURN;
        END IF;   
     
    END; 
  
  
    FUNCTION fu_obt_mov_user(p_tip_user in ba_cod_referencias.abreviatura%type)
        return varchar2 is
        v_nro_sec  number;
        v_can_user number;
        v_nro_user number;
        v_user     ba_usuarios.cod_usuario%type;

    BEGIN
        select count(*)
        into v_can_user
        from ba_cod_referencias
        where dominio     = 'USU_MOV_SERVICIO'
        and abreviatura = p_tip_user;

        v_nro_sec  := fue_obt_sig_secuencia('S_SER_UAPIIPS');
        v_nro_user := mod(v_nro_sec, v_can_user);
        v_user     := it.FUE_OBT_VAL_USER_DOMINIO('USU_MOV_SERVICIO', v_nro_user, p_tip_user);
        return v_user;
    EXCEPTION
        WHEN OTHERS THEN
            null;
    END;
  
    FUNCTION fu_obt_hora(p_cod_usuario varchar2) return varchar2 is
        v_hora        ge_movimientos.hora%type;
        v_nro_sec     number;
        v_nro_hor     number;
        v_ind_usuario number;

    BEGIN
        if instr(p_cod_usuario, '_', 1) = 0 then
            v_ind_usuario := 0;
        else
            --El substr tiene como valor 2 ya que el usuario puede tener más de dos caracteres _15  _11 _10
            v_ind_usuario := substr(p_cod_usuario, instr(p_cod_usuario, '_', 1) + 1, 2);
        end if;

        if v_ind_usuario > 0 then
            v_nro_sec := fue_obt_sig_secuencia('s_hor_movuapiips' /*||'_'*/|| v_ind_usuario);
        elsif v_ind_usuario = 0 then
            v_nro_sec := fue_obt_sig_secuencia('s_hor_movuapiips');
        end if;

        v_nro_hor := mod(v_nro_sec, 86400);

        v_hora := TO_CHAR(trunc(v_nro_hor / 3600), 'FM9900') || ':' ||
              TO_CHAR(TRUNC(MOD(v_nro_hor, 3600) / 60), 'FM00') || ':' ||
              TO_CHAR(MOD(v_nro_hor, 60), 'FM00');

        return v_hora;
    EXCEPTION
        WHEN OTHERS THEN
            raise_application_error(-20000, 'No se puede obtener la hora del movimiento. ' || sqlerrm);
    END;
  
    PROCEDURE pr_ins_pag_sue_ips(p_error IN OUT VARCHAR2,
                              p_cod_respuesta IN OUT VARCHAR2,
                              p_des_respuesta IN OUT VARCHAR2
                              ) IS 
        v_nro_orden ge_pag_sue_ips_det.nro_orden%type;
    BEGIN
        /*UPDATE ge_pag_sue_ips i
        SET i.mto_debito         = i.mto_debito + v_importe
        WHERE i.nro_lot_referencia = v_nro_lote_ref;
        IF SQL%NOTFOUND THEN
            BEGIN
                SELECT s_nro_lote_ips.nextval
                INTO v_nro_lote_ips  
                FROM dual;
                
                INSERT INTO it.ge_pag_sue_ips
                (nro_lote, cod_ente, nom_archivo, chk_sum_archivo, nro_cta_pag_salario, nro_cta_operativa, fec_acreditacion, fec_vencimiento, mto_debito, tipo, estado, tip_proceso, nro_lot_referencia)
                VALUES
                (v_nro_lote_ips, v_cod_ente, 'PAG_SUELDOS_HB1', 'PAG_SUELDOS_HB1', v_nro_cta_debito, v_nro_cta_debito, TRUNC(sysdate), TRUNC(sysdate), v_importe, v_tipo, 'P', 'P', v_nro_lote_ref);
        END IF;  */     
        BEGIN               
            MERGE INTO it.ge_pag_sue_ips dest
            USING (SELECT v_nro_lote_ips nro_lote_ips, 
            v_cod_ente cod_ente, 
            'PAG_SUELDOS_HB1' nom_archivo, 
            'PAG_SUELDOS_HB1' chk_sum_archivo,
            v_nro_cta_debito nro_cta_pag_salario, 
            v_nro_cta_debito nro_cta_operativa,
            TRUNC(sysdate) fec_acreditacion, 
            TRUNC(sysdate) fec_vencimiento, 
            v_importe mto_debito,
            v_tipo tipo, 
            'P' estado, 
            'P' tip_proceso, 
            v_nro_lote_ref nro_lot_referencia
            FROM dual) src
            ON (dest.nro_lot_referencia = src.nro_lot_referencia)
            WHEN MATCHED THEN 
                UPDATE SET dest.mto_debito = nvl(dest.mto_debito,0) + src.mto_debito
                WHERE dest.nro_lot_referencia = src.nro_lot_referencia
            WHEN NOT MATCHED THEN
                INSERT (nro_lote, cod_ente, nom_archivo, chk_sum_archivo, nro_cta_pag_salario, nro_cta_operativa,
                    fec_acreditacion, fec_vencimiento, mto_debito, tipo, estado, tip_proceso, nro_lot_referencia)
                VALUES (s_nro_lote_ips.nextval, src.cod_ente, src.nom_archivo, src.chk_sum_archivo, src.nro_cta_pag_salario, src.nro_cta_operativa,
                    src.fec_acreditacion, src.fec_vencimiento, src.mto_debito, src.tipo, src.estado, src.tip_proceso, src.nro_lot_referencia);                            
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLCODE = -1 THEN -- unique key 
                    UPDATE ge_pag_sue_ips t
                    SET t.mto_debito = nvl(t.mto_debito,0) + v_importe
                    WHERE t.nro_lot_referencia = v_nro_lote_ref;
                    pr_ins_bitacora('update ge_pag_sue_ips - '||'cta:'||v_nro_cta_debito||','||'importe:'||v_importe||','||'nroComp.'||v_nro_operacion||','||'nroLoteRef:'||v_nro_lote_ref);
                ELSE 
                    p_error         := 'S';
                    p_cod_respuesta := C_GEN_PAG_SUE||1;
                    p_des_respuesta := 'Error al insertar pag. sueldos ips '||sqlerrm;
                    ROLLBACK;
                    RETURN;
                END IF;
        END;

        -- Obtenemos el nro de lote de ips generado anteriormente para el lote de referencia 
        IF  v_nro_lote_ips IS NULL THEN
            BEGIN
                SELECT t.nro_lote
                INTO v_nro_lote_ips
                FROM ge_pag_sue_ips t
                WHERE t.nro_lot_referencia = v_nro_lote_ref;
            EXCEPTION 
                WHEN OTHERS THEN
                    p_error         := 'S';
                    p_cod_respuesta := C_GEN_PAG_SUE||2;
                    p_des_respuesta := 'Error al obtener el nro lote ips generado pag. sueldos ips '||sqlerrm;
                    RETURN; 
            END;
        END IF;
      
        BEGIN
            SELECT NVL(MAX(d.nro_orden),0)+1
            INTO v_nro_orden
            FROM ge_pag_sue_ips_det d
            WHERE d.nro_lote =  v_nro_lote_ips;
        EXCEPTION 
            WHEN OTHERS THEN
                v_nro_orden := 1;
        END;
     
        
        BEGIN
            INSERT INTO it.ge_pag_sue_ips_det
            (nro_orden, nro_lote, nro_comprobante, nro_cta_jubilado, nro_doc_jubilado, nom_jubilado, importe, fe_vida, estado, fec_acreditacion)
            VALUES
            (v_nro_orden, v_nro_lote_ips, v_nro_operacion, v_nro_cta_credito, v_nro_doc_per_cre, v_nom_cue_cre, v_importe, 'S', 'A', TRUNC(sysdate));
        EXCEPTION 
            WHEN OTHERS THEN
                p_error         := 'S';
                p_cod_respuesta := C_GEN_PAG_SUE||3;
                p_des_respuesta := 'Error al insertar detalle de pag. sueldos ips '||sqlerrm;
                ROLLBACK;
                RETURN;          
        END;
     
    END pr_ins_pag_sue_ips;
         
    PROCEDURE pr_ins_pag_sue(p_error         IN OUT VARCHAR2,
                           p_cod_respuesta IN OUT VARCHAR2,
                           p_des_respuesta IN OUT VARCHAR2
                           ) IS
        v_nro_secuencia ge_pag_sueldos.nro_secuencia%type;
    BEGIN
        -- Insertamos tambien en la tabla ge_pag_sueldos 
        /* UPDATE ge_pag_sueldos s
        SET s.monto       = s.monto + v_importe
        WHERE s.nro_lot_ips = v_nro_lote_ips
        AND s.tipo        = 'D'
        AND s.cod_ente    = v_cod_ente
        AND s.fec_proceso = trunc(sysdate);
        IF SQL%NOTFOUND THEN
            BEGIN 
                SELECT s_nro_lote_sue.nextval 
                INTO v_nro_lote_sue  
                FROM dual;
              
                INSERT INTO it.ge_pag_sueldos
                (cod_usuario, cod_ente, fec_proceso, nro_secuencia, cod_modalidad, nro_cuenta, cod_moneda, fec_envio, tipo, monto, estado, cod_proceso, cod_modulo, procesado, nro_documento, nro_lote, nro_lot_ips)
                VALUES
                (v_cod_usuario, v_cod_ente, trunc(sysdate), 1, v_cod_mad_deb, v_nro_cta_debito, v_cod_mon_deb, trunc(sysdate), 'D', v_importe, 'N', 0, v_cod_mod_deb, 'S', v_nro_doc_per_deb, v_nro_lote_sue, v_nro_lote_ips);      
        */
        BEGIN                 
            MERGE INTO it.ge_pag_sueldos dest
            USING ( SELECT v_cod_usuario cod_usuario, 
                        v_cod_ente cod_ente, 
                        TRUNC(sysdate)fec_proceso, 
                        1 nro_secuencia, 
                        v_cod_mad_deb cod_modalidad, 
                        v_nro_cta_debito nro_cta_debito, 
                        v_cod_mon_deb cod_mon_debito, 
                        TRUNC(sysdate) fec_envio, 
                        'D' tipo, 
                        v_importe importe, 
                        'N' 
                        estado, 
                        0 cod_proceso, 
                        v_cod_mod_deb cod_modulo, 
                        'S' procesado, 
                        v_nro_doc_per_deb nro_documento, 
                        v_nro_lote_sue nro_lote, 
                        v_nro_lote_ips nro_lote_ips
                        FROM dual ) src
            ON ( dest.nro_lot_ips     = src.nro_lote_ips 
                        AND dest.tipo        = 'D' 
                        AND dest.cod_ente    = src.cod_ente 
                        AND dest.fec_proceso = src.fec_proceso
                        )
            WHEN MATCHED THEN
                UPDATE SET dest.monto = nvl(dest.monto,0) + src.importe
                WHERE dest.nro_lot_ips = src.nro_lote_ips
                AND dest.tipo        = 'D'
                AND dest.cod_ente    = src.cod_ente
                AND dest.fec_proceso = trunc(sysdate)
            WHEN NOT MATCHED THEN
                INSERT (cod_usuario, cod_ente, fec_proceso, nro_secuencia, cod_modalidad, nro_cuenta, cod_moneda, 
                    fec_envio, tipo, monto, estado, cod_proceso, cod_modulo, procesado, nro_documento, 
                    nro_lote, nro_lot_ips)
                VALUES (src.cod_usuario, src.cod_ente, src.fec_proceso, src.nro_secuencia, src.cod_modalidad,
                    src.nro_cta_debito, src.cod_mon_debito, src.fec_envio, src.tipo, src.importe, src.estado, 
                    src.cod_proceso, src.cod_modulo, src.procesado, src.nro_documento, s_nro_lote_sue.nextval, src.nro_lote_ips);  
        EXCEPTION 
            WHEN OTHERS THEN               
                p_error           := 'S';
                p_cod_respuesta   := C_GEN_PAG_SUE||4;
                p_des_respuesta   := 'Error al insertar en ge_pag_sueldos para el debito' || v_nro_cta_debito || '-' ||sqlerrm;                          
                ROLLBACK;
                RETURN;                
        END;
   
        IF v_nro_lote_sue IS NULL THEN
            BEGIN
                SELECT p.nro_lote
                INTO v_nro_lote_sue
                FROM ge_pag_sueldos p
                WHERE p.cod_ente    = v_cod_ente
                AND p.nro_lot_ips = v_nro_lote_ips
                AND p.nro_lote    is not null
                AND p.fec_proceso = trunc(sysdate)
                AND rownum = 1;
            EXCEPTION
                WHEN OTHERS THEN
                    p_error           := 'S';
                    p_cod_respuesta   := C_GEN_PAG_SUE||5;
                    p_des_respuesta   := 'Error al insertar en ge_pag_sueldos ' || v_nro_cta_credito || '-' ||sqlerrm;                          
                    ROLLBACK;              
                    RETURN;   
            END;
        END IF;
      
        BEGIN
            SELECT NVL(MAX(d.nro_secuencia),0)+1
            INTO v_nro_secuencia
            FROM ge_pag_sueldos d
            WHERE d.cod_ente    = v_cod_ente
            AND d.nro_lot_ips = v_nro_lote_ips
            AND d.fec_proceso = trunc(sysdate)
            AND d.nro_lote    = v_nro_lote_sue;
        EXCEPTION 
            WHEN OTHERS THEN
                v_nro_secuencia := 1;
        END;  
            
        BEGIN         
            INSERT INTO it.ge_pag_sueldos
            (cod_usuario, cod_ente, fec_proceso, nro_secuencia, cod_modalidad, nro_cuenta, cod_moneda, fec_envio, tipo, monto, estado, cod_proceso, cod_modulo, procesado, nro_documento, nro_lote, nro_lot_ips)
            VALUES
            (v_cod_usuario, v_cod_ente, trunc(sysdate), v_nro_secuencia, v_cod_mad_cre, v_nro_cta_credito, v_cod_mon_cre,  trunc(sysdate), 'C', v_importe, 'N', 0, v_cod_mod_cre, 'S', v_nro_doc_per_cre, v_nro_lote_sue, v_nro_lote_ips);      
        EXCEPTION 
            WHEN OTHERS THEN 
                v_error           := 'S';
                v_cod_respuesta   := C_GEN_PAG_SUE||6;
                v_des_respuesta   := 'Error al insertar en ge_pag_sueldos ' || v_nro_cta_credito || '-' ||sqlerrm;                          
                ROLLBACK;            
                RETURN;
        END; 
    END pr_ins_pag_sue;               

BEGIN
    begin 
        pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; 
    end;           
    -- Proceso principaL
    -- Asignacion de parametros
    v_nro_cta_debito   := p_nro_cta_debito;
    v_nro_cta_credito  := p_nro_cta_credito;
    v_nro_doc_per_deb  := p_nro_doc_deb;
    v_nro_doc_per_cre  := p_nro_doc_cre;
    v_importe          := nvl(p_importe,0);
    v_tip_operacion    := p_tip_operacion;   
    v_nro_operacion    := p_nro_operacion;
    v_modo             := p_modo;
    v_nro_lote_ref     := p_nro_lote;  

    v_cod_usuario    := fu_obt_mov_user('UAPIIPS');
    v_hora           := fu_obt_hora(v_cod_usuario);
    v_cod_ofi_origen := fug_obt_ofi_usuario(v_cod_usuario);  
   
    -- Validacion de parametros de entrada
    pr_val_parametros(v_error, v_cod_respuesta, v_des_respuesta);
   
    IF ( v_error = 'S' OR v_cod_respuesta != 'OK' ) THEN
        pr_ins_bitacora(v_cod_respuesta||' '||v_des_respuesta);
        RETURN  fu_obt_response(v_error, v_cod_respuesta, v_des_respuesta, v_data);    
    END IF;
   
    v_cod_ente       := fug_obt_pardinamico('COD_ENT_IPS');
    -- Obtenemos datos del ente y validamos
    pr_obt_dat_ente(v_cod_ente,
                v_error,
                v_cod_respuesta,
                v_des_respuesta
                );
    IF ( v_error = 'S' OR v_cod_respuesta != 'OK' ) THEN
        pr_ins_bitacora(v_cod_respuesta||' '||v_des_respuesta);
        RETURN fu_obt_response(v_error,v_cod_respuesta, v_des_respuesta, v_data);
    END IF;
  
  
    -- Se reliza controles para la cuenta debito o credito para la verificacion 
    IF  ( v_modo = 'V'  AND v_nro_cta_debito IS NOT NULL )  THEN
        
        -- Obtenemos datos de la cuenta Debito y lo validamos
        pr_obt_dat_cue_debito(v_error, 
                            v_cod_respuesta, 
                            v_des_respuesta);
        
        IF ( v_error = 'S' OR v_cod_respuesta != 'OK' ) THEN
            pr_ins_bitacora(v_cod_respuesta||' '||v_des_respuesta);
            RETURN fu_obt_response(v_error,v_cod_respuesta, v_des_respuesta, v_data);
        END IF;
              
    ELSIF  ( v_modo = 'V' AND v_nro_cta_credito IS NOT NULL ) THEN
    
        -- Obtenemos datos de la cuenta Debito y en base al nro de cuenta debito proveniente del ente
        pr_obt_dat_cue_debito(v_error, 
                            v_cod_respuesta, 
                            v_des_respuesta);
        
        IF ( v_error = 'S' OR v_cod_respuesta != 'OK' ) THEN
            pr_ins_bitacora(v_cod_respuesta||' '||v_des_respuesta);
            RETURN fu_obt_response(v_error,v_cod_respuesta, v_des_respuesta, v_data);
        END IF;
        
        -- Obtenemos datos de la cuenta Credito y lo validamos 
        pr_obt_dat_cue_credito(v_error, 
                            v_cod_respuesta, 
                            v_des_respuesta);
        
        IF ( v_error = 'S' OR v_cod_respuesta != 'OK' ) THEN
            pr_ins_bitacora(v_cod_respuesta||' '||v_des_respuesta);
            RETURN fu_obt_response(v_error,v_cod_respuesta, v_des_respuesta, v_data);
        END IF;

    ELSIF ( v_modo = 'C' AND v_nro_cta_debito IS NOT NULL AND v_nro_cta_credito IS NOT NULL ) THEN
    
        -- Obtenemos datos de la cuenta Debito y lo validamos
        pr_obt_dat_cue_debito(v_error, 
                              v_cod_respuesta, 
                              v_des_respuesta);
        
        IF ( v_error = 'S' OR v_cod_respuesta != 'OK' ) THEN
            pr_ins_bitacora(v_cod_respuesta||' '||v_des_respuesta);
            RETURN fu_obt_response(v_error,v_cod_respuesta, v_des_respuesta, v_data);
        END IF;
        
        -- Obtenemos datos de la cuenta Credito y lo validamos 
        pr_obt_dat_cue_credito(v_error, 
                            v_cod_respuesta, 
                            v_des_respuesta);
        
        IF ( v_error = 'S' OR v_cod_respuesta != 'OK' ) THEN
            pr_ins_bitacora(v_cod_respuesta||' '||v_des_respuesta);
            RETURN fu_obt_response(v_error,v_cod_respuesta, v_des_respuesta, v_data);
        END IF;
    END IF;
  
    --Asignamos los codigos de transacciones Credito dependiendo del tipo de operacion
    IF v_tip_operacion = 'IJ' THEN   --IPS JUBILADOS
        -- Cod. tra. credito 
        IF  ( v_cod_mod_cre = 3  ) THEN      
            v_cod_tra_credito := v_cod_tra_aho_jub;
        ELSIF ( v_cod_mod_cre = 4 ) THEN     
            v_cod_tra_credito := v_cod_tra_cte_jub;
        END IF;
        v_concepto        := 'Pago de Sueldos/Jubilados IPS';
        v_tipo            := 'J';
     
    ELSIF v_tip_operacion = 'IP' THEN  --IPS PRESTAMOS
        -- Cod. tra. credito
        IF ( v_cod_mod_cre = 3 ) THEN 
            v_cod_tra_credito := v_cod_tra_aho_pre;
        ELSIF ( v_cod_mod_cre = 4 ) THEN 
            v_cod_tra_credito := v_cod_tra_cte_pre;
        END IF;
        v_concepto        := 'Pago de Prestamos IPS';
        v_tipo            := 'C';
     
    ELSIF v_tip_operacion = 'IS' THEN  --IPS SUELDOS 
        -- Cod. tra. credito
        IF ( v_cod_mod_cre = 3 ) THEN
            v_cod_tra_credito := v_cod_tra_aho_sue;       
        ELSIF ( v_cod_mod_cre = 4 ) THEN 
            v_cod_tra_credito := v_cod_tra_cte_sue;
        END IF; 
        v_concepto        := 'Pago de Sueldos IPS';
        v_tipo            := 'S';
     
    END IF; 
  
    -- Un solo codigo de transaccion Padre para todas las operaciones
    IF ( v_cod_mod_deb = 3 ) THEN       
        v_cod_tra_padre   := v_cod_tra_pad_aho_jub;
    ELSIF ( v_cod_mod_deb = 4 ) THEN    
        v_cod_tra_padre   := v_cod_tra_pad_cte_jub;
    END IF;
   
    -- Un solo codigo de transaccion debito para todas las operaciones
    v_cod_tra_debito  := v_cod_tra_deb_ips;
 
 
    -- VERIFICACION DE CUENTA
    IF v_modo = 'V' THEN
      
        IF v_nro_cta_debito IS NOT NULL THEN
            BEGIN
                pag_cta.pr_ver_operacion(v_nro_cta_debito, 
                                v_cod_tra_padre, 
                                v_cod_mod_deb,
                                v_cod_mad_deb, 
                                'D', 
                                v_cod_mon_deb, 
                                v_importe, 
                                v_cod_ofi_origen,
                                v_cod_mod_deb, 
                                v_cod_mad_deb, 
                                v_nvo_est_debito, 
                                v_sal_dis_deb,
                                v_pro_deb, 
                                v_cod_tra_debito
                                );
                IF pag_cta.g_cod_error <> 0 OR v_pro_deb = 'N' THEN
                    IF  instr(upper(pag_cta.G_MSJ_ERROR), 'INSUFIC') > 0 THEN
                        v_error          := 'S';
                        v_cod_respuesta  := C_VAL_CUE_DCR||'1';
                        v_des_respuesta  := 'Cuenta '||v_nro_cta_debito||' con Saldo Insuficiente p/ el débito de GS '||v_importe;
                        pr_ins_bitacora(v_cod_respuesta||' '||v_des_respuesta);
                        RETURN fu_obt_response(v_error,v_cod_respuesta, v_des_respuesta, v_data);
                    ELSE
                        v_error          := 'S';
                        v_cod_respuesta  := C_VAL_CUE_DCR||'2';
                        v_des_respuesta  := 'Error durante validacion Cta. Debito ' || v_nro_cta_debito || '-' ||' cod. '||pag_cta.fu_obt_cod_error||' '||
                                          pag_cta.fu_obt_msj_error;
                        pr_ins_bitacora(v_cod_respuesta||' '||v_des_respuesta);                  
                        RETURN fu_obt_response(v_error,v_cod_respuesta, v_des_respuesta, v_data);
                    END IF;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    v_error          := 'S';
                    v_cod_respuesta  := C_VAL_CUE_DCR||'3';
                    v_des_respuesta  := 'Error en pag_cta.ver_ope ' || v_nro_cta_debito || '-' ||SQLERRM;
                    pr_ins_bitacora(v_cod_respuesta||' '||v_des_respuesta);
                    RETURN fu_obt_response(v_error,v_cod_respuesta, v_des_respuesta, v_data);
            END;
           
            -- Retornamos la salida de la validacion de los datos 
            v_data.put('nroDocumento',    v_nro_doc_per_deb);
            v_data.put('tipoDocumento',   v_tip_doc_per_deb);
            v_data.put('nombre',          v_nom_per_deb);
            -- creamos el objeto moneda 
            v_data_moneda.put('codMoneda',   v_cod_mon_deb);
            v_data_moneda.put('desMoneda',   v_cod_mon_deb);
            -- asignamos el objeto moneda al objeto principal 
            v_data.put('moneda',          v_data_moneda);
            v_data.put('estado',          v_est_debito);
            v_data.put('desEstado',       v_des_est_cue_deb);
            v_data.put('saldoDisponible', v_sal_dis_deb);
             
        ELSE 
         
            BEGIN
                pag_cta.pr_ver_operacion(v_nro_cta_credito, 
                                    v_cod_tra_padre, 
                                    v_cod_mod_deb,
                                    v_cod_mad_deb, 
                                    'C', 
                                    v_cod_mon_cre, 
                                    v_importe, 
                                    v_cod_ofi_origen,
                                    v_cod_mod_cre, 
                                    v_cod_mad_cre, 
                                    v_nvo_est_credito, 
                                    v_sal_dis_cre,
                                    v_pro_cre, 
                                    v_cod_tra_credito
                                    );
                IF pag_cta.g_cod_error <> 0 OR v_pro_cre = 'N' THEN
                    v_error          := 'S';
                    IF pag_cta.g_cod_error IN (33, 34) THEN
                        CASE fug_obt_est_cuenta(v_nro_cta_credito)
                            WHEN 'C' THEN
                                v_cod_respuesta   := C_VAL_CUE_DCR||7;
                                v_des_respuesta   := 'Cuenta credito cancelada '||v_nro_cta_credito;
                            WHEN 'B' THEN
                                v_cod_respuesta   := C_VAL_CUE_DCR||8;
                                v_des_respuesta   := 'Cuenta credito con bloqueo '||v_nro_cta_credito;
                            WHEN 'P' THEN
                                v_cod_respuesta   := C_VAL_CUE_DCR||9;
                                v_des_respuesta   := 'Cuenta credito pendiente de cancelacion '||v_nro_cta_credito;
                            WHEN 'T' THEN
                                v_cod_respuesta   := C_VAL_CUE_DCR||10;
                                v_des_respuesta   := 'Cuenta credito con bloqueo total '||v_nro_cta_credito;
                            WHEN 'X' THEN
                                v_cod_respuesta   := C_VAL_CUE_DCR||11;
                                v_des_respuesta   := 'Cuenta credito en verificacion '||v_nro_cta_credito;
                            ELSE 
                                v_cod_respuesta   := C_VAL_CUE_DCR||12;
                                v_des_respuesta   := 'Estado de cuenta credito invalida '||v_nro_cta_credito;
                        END CASE;
                    ELSE
                        v_cod_respuesta  := C_VAL_CUE_DCR||4;
                        v_des_respuesta  := 'Error durante validacion Cta. Credito ' || v_nro_cta_credito || '-' ||' cod. '||pag_cta.fu_obt_cod_error||' '||
                                    pag_cta.fu_obt_msj_error;
                    END IF;

                    pr_ins_bitacora(v_cod_respuesta||' '||v_des_respuesta);                                    
                    RETURN fu_obt_response(v_error,v_cod_respuesta, v_des_respuesta, v_data);
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    v_error          := 'S';
                    v_cod_respuesta  := C_VAL_CUE_DCR||5;
                    v_des_respuesta  := 'Error en pag_cta.ver_ope Cta. Credito' || v_nro_cta_credito || '-' ||SQLERRM;
                    pr_ins_bitacora(v_cod_respuesta||' '||v_des_respuesta);
                    RETURN fu_obt_response(v_error,v_cod_respuesta, v_des_respuesta, v_data);
            END;
            v_sal_dis_cre := pag_cta.FU_SAL_DISPONIBLE;
            -- Retornamos la salida de la validacion de los datos 
            v_data.put('nroDocumento',    v_nro_doc_per_cre);
            v_data.put('tipoDocumento',   v_tip_doc_per_cre);
            v_data.put('nombre',          v_nom_per_cre);
            -- creamos el objeto moneda 
            v_data_moneda.put('codMoneda', v_cod_mon_cre);
            v_data_moneda.put('desMoneda', v_des_mon_cre);
            -- signamos el objeto moneda al objeto principal 
            v_data.put('moneda',          v_data_moneda);
            v_data.put('estado',          v_est_credito);
            v_data.put('desEstado',       v_des_est_cue_cre);
            v_data.put('saldoDisponible', v_sal_dis_cre);
            
        END IF;
       
    END IF;
   
    -- Realizamos el Debito y Credito 
    IF p_modo = 'C' THEN
        -- Si todo fue ok se registra el pago de sueldo IPS  
        pr_ins_pag_sue_ips(v_error, v_cod_respuesta, v_des_respuesta);
        
        IF v_error = 'S' OR v_cod_respuesta != 'OK' THEN
            pr_ins_bitacora(v_cod_respuesta||' '||v_des_respuesta);
            ROLLBACK;
            RETURN fu_obt_response(v_error,v_cod_respuesta, v_des_respuesta, v_data);
        END IF;
        
        -- Si todo fue ok se registra el pago de sueldo
        pr_ins_pag_sue(v_error, v_cod_respuesta, v_des_respuesta);   
        
        IF v_error = 'S' OR v_cod_respuesta != 'OK' THEN
            pr_ins_bitacora(v_cod_respuesta||' '||v_des_respuesta);
            ROLLBACK;
            RETURN fu_obt_response(v_error,v_cod_respuesta, v_des_respuesta, v_data);
        END IF;
        
        -- Antes de realizar el debito, credito verificamos que ya no exista un movimiento con la misma 
        -- fecha, cuenta, importe, nro_documento, nro operacion (IPS)
        BEGIN
            SELECT DISTINCT 'S'
            INTO v_exi_mov
            FROM ge_movimientos t
            WHERE t.fecha          = v_fec_actual
            AND t.nro_cuenta     = v_nro_cta_credito
            AND t.monto          = v_importe
            AND t.nro_documento  = v_nro_lote_sue
            AND t.nro_documento2 = v_nro_operacion;
        EXCEPTION 
            WHEN OTHERS THEN
                v_exi_mov := 'N';
        END;
       
        IF v_exi_mov = 'S' THEN
            v_error          := 'S';
            v_cod_respuesta  := C_VAL_CUE_DCR||6;
            v_des_respuesta  := 'Ya existe un movimiento generado para esta cuenta con el mismo monto';
            pr_ins_bitacora(v_cod_respuesta||' '||v_des_respuesta);
            ROLLBACK;
            RETURN fu_obt_response(v_error,v_cod_respuesta, v_des_respuesta, v_data);
        END IF;  
       
        -- Procesamos el Debito
        pag_cta.pr_set_nro_documento3(v_cod_ente);
        pag_cta.pr_set_nro_documento2(v_nro_operacion); --Nro de comprobante de ips
        pag_cta.pr_set_variables(v_cod_usuario,
                            v_fec_actual,
                            v_cod_tra_padre,
                            'N',
                            'N',
                            v_nro_secuencia,
                            null,
                            v_cod_ofi_origen,
                            v_cod_mod_deb,
                            v_cod_mad_deb);
        BEGIN
            --Se agrega este bloque nuevo, el cual se encargar de encontrar el horario y setear en pag_cta

            lp_ver_horario(v_cod_ofi_origen,
                    '3', --siempre debe tomar el 3 para validar el horario, por ser el maestro de los módulos
                    v_horario,
                    v_es_mov_noc,
                    v_es_cta_noc,
                    v_fec_actual,
                    v_fec_valor,
                    v_cod_respuesta,
                    v_des_respuesta,
                    v_error);

            IF nvl(v_error, 'N') = 'S' THEN

                pr_ins_bitacora(v_cod_respuesta||' '||v_des_respuesta);
                ROLLBACK;
                RETURN fu_obt_response(v_error,v_cod_respuesta, v_des_respuesta, v_data);

            END IF;
            v_est_inicial:=v_mod_estado;
        EXCEPTION
            WHEN OTHERS THEN
                v_error          := 'S';
                v_cod_respuesta  := C_OBT_HORARIO||'4';
                v_des_respuesta  := 'Error al obtener horario ' || sqlerrm;
                pr_ins_bitacora(v_cod_respuesta||' '||v_des_respuesta);
                ROLLBACK;
                RETURN fu_obt_response(v_error,v_cod_respuesta, v_des_respuesta, v_data);
        END;

        DECLARE
            v_est_actual          ba_modulos.estado%type;
        BEGIN
            v_est_actual:=pae_cnf.fu_obt_est_modulo(3);
            if (v_est_inicial!=v_est_actual or v_est_actual in (1,6)) then
                v_error          := 'S';
                v_cod_respuesta  := C_OBT_HORARIO||'5';
                v_des_respuesta  := 'Entidad en proceso de cierre, vuelva a intentar';
                pr_ins_bitacora(v_cod_respuesta||' '||v_des_respuesta);
                ROLLBACK;
                RETURN fu_obt_response(v_error,v_cod_respuesta, v_des_respuesta, v_data);
            end if;
            --Realizamos el debito
            pag_cta.pr_act_operacion(v_nro_cta_debito,
                                v_hora,
                                'D', 
                                v_cod_mon_deb, 
                                v_importe, 
                                v_cod_tra_padre,
                                v_cod_tra_debito,
                                v_nro_lote_sue, 
                                NULL,
                                v_cod_ofi_origen,
                                v_cod_mod_deb,
                                v_cod_mad_deb,
                                NULL,
                                NULL,
                                v_concepto, 
                                'N',
                                v_nro_secuencia, 
                                v_fec_actual);
            IF pag_cta.g_cod_error <> 0 THEN
                IF  instr(upper(pag_cta.G_MSJ_ERROR), 'INSUFIC') > 0 THEN
                    v_error          := 'S';
                    v_cod_respuesta  := C_MOV_GEN_DCR||'1';
                    v_des_respuesta  := 'Cuenta '||v_nro_cta_debito||' con Saldo Insuficiente p/ el débito de GS '||v_importe;
                    pr_ins_bitacora(v_cod_respuesta||' '||v_des_respuesta);
                    ROLLBACK;
                    RETURN fu_obt_response(v_error,v_cod_respuesta, v_des_respuesta, v_data);
                ELSE
                    v_error          := 'S';
                    v_cod_respuesta  := C_MOV_GEN_DCR||'2';
                    v_des_respuesta  := 'Error pag_cta.act_operacion Cuenta Debito '|| v_nro_cta_debito || '-' ||' cod. '||pag_cta.fu_obt_cod_error||'    '||
                                      pag_cta.fu_obt_msj_error;
                    pr_ins_bitacora(v_cod_respuesta||' '||v_des_respuesta);                   
                    ROLLBACK;
                    RETURN fu_obt_response(v_error,v_cod_respuesta, v_des_respuesta, v_data);
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                v_error          := 'S';
                v_cod_respuesta  := C_MOV_GEN_DCR||'3';
                v_des_respuesta  := 'Error pag_cta.act_operacion Cuenta Debito'|| v_nro_cta_debito || '-' ||sqlerrm;
                pr_ins_bitacora(v_cod_respuesta||' '||v_des_respuesta);
                ROLLBACK;
                RETURN fu_obt_response(v_error,v_cod_respuesta, v_des_respuesta, v_data); 
        END;
        -- Procesamos el credito
        pag_cta.pr_set_nro_documento3(v_cod_ente);
        pag_cta.pr_set_nro_documento2(v_nro_operacion); --Nro de comprobante de ips
        pag_cta.pr_set_variables(v_cod_usuario,
                                v_fec_actual,
                                v_cod_tra_padre,
                                'N',
                                'N',
                                v_nro_secuencia,
                                null,
                                v_cod_ofi_origen,
                                v_cod_mod_deb,
                                v_cod_mad_deb
                                );
        DECLARE
            v_est_actual          ba_modulos.estado%type;
        BEGIN
            v_est_actual:=pae_cnf.fu_obt_est_modulo(3);
            if (v_est_inicial!=v_est_actual or v_est_actual in (1,6)) then
                v_error          := 'S';
                v_cod_respuesta  := C_OBT_HORARIO||'6';
                v_des_respuesta  := 'Entidad en proceso de cierre, vuelva a intentar';
                pr_ins_bitacora(v_cod_respuesta||' '||v_des_respuesta);
                ROLLBACK;
                RETURN fu_obt_response(v_error,v_cod_respuesta, v_des_respuesta, v_data);
            end if;
            -- Realizamod el Credito       
            pag_cta.pr_act_operacion(v_nro_cta_credito, 
                                v_hora,
                                'C', 
                                v_cod_mon_deb,
                                v_importe, 
                                v_cod_tra_padre,
                                v_cod_tra_credito, 
                                v_nro_lote_sue,
                                NULL,
                                v_cod_ofi_origen,
                                v_cod_mod_deb,
                                v_cod_mad_deb,
                                NULL,
                                NULL,
                                v_concepto,
                                'N',
                                v_nro_secuencia, 
                                v_fec_actual);
            IF  pag_cta.g_cod_error <> 0  THEN
                v_error          := 'S';
                IF pag_cta.g_cod_error IN (33, 34) THEN
                    CASE fug_obt_est_cuenta(v_nro_cta_credito)
                        WHEN 'C' THEN
                            v_cod_respuesta   := C_MOV_GEN_DCR||6;
                            v_des_respuesta   := 'Cuenta credito cancelada '||v_nro_cta_credito;
                        WHEN 'B' THEN
                            v_cod_respuesta   := C_MOV_GEN_DCR||7;
                            v_des_respuesta   := 'Cuenta credito con bloqueo '||v_nro_cta_credito;
                        WHEN 'P' THEN
                            v_cod_respuesta   := C_MOV_GEN_DCR||8;
                            v_des_respuesta   := 'Cuenta credito pendiente de cancelacion '||v_nro_cta_credito;
                        WHEN 'T' THEN
                            v_cod_respuesta   := C_MOV_GEN_DCR||9;
                            v_des_respuesta   := 'Cuenta credito con bloqueo total '||v_nro_cta_credito;
                        WHEN 'X' THEN
                            v_cod_respuesta   := C_MOV_GEN_DCR||10;
                            v_des_respuesta   := 'Cuenta credito en verificacion '||v_nro_cta_credito;
                        ELSE
                            v_cod_respuesta   := C_MOV_GEN_DCR||11;
                            v_des_respuesta   := 'Estado de cuenta credito invalida '||v_nro_cta_credito;
                    END CASE;
                ELSE
                    v_cod_respuesta  := C_MOV_GEN_DCR||4;
                    v_des_respuesta  := 'Error pag_cta.act_operacion Cta. Credito ' || v_nro_cta_credito || '-' ||' cod. '||pag_cta.fu_obt_cod_error||' '||
                                      pag_cta.fu_obt_msj_error;
                END IF;

                pr_ins_bitacora(v_cod_respuesta||' '||v_des_respuesta);
                ROLLBACK;
                RETURN fu_obt_response(v_error,v_cod_respuesta, v_des_respuesta, v_data);
            END IF;
        EXCEPTION 
            WHEN OTHERS THEN
                v_error          := 'S';
                v_cod_respuesta  := C_MOV_GEN_DCR||5;
                v_des_respuesta  := 'Error pag_cta.act_operacion Cta. Credito ' || v_nro_cta_credito || '-' ||sqlerrm;
                pr_ins_bitacora(v_cod_respuesta||' '||v_des_respuesta);
                ROLLBACK;
                RETURN fu_obt_response(v_error,v_cod_respuesta, v_des_respuesta, v_data);
        END;
        -- Datos necesarios para la salida     
        BEGIN
            SELECT t.fec_valor,
            TO_CHAR(t.fec_insercion,'HH24:MI:SS') hor_insercion
            INTO v_fec_insercion,
            v_hor_insercion
            FROM ge_movimientos t
            WHERE t.fecha       = v_fec_actual
            AND t.hora        = v_hora
            AND t.cod_usuario = v_cod_usuario
            AND t.nro_cuenta  = v_nro_cta_credito;
        EXCEPTION 
            WHEN OTHERS THEN
                v_fec_insercion := v_fec_actual;
                v_hor_insercion := v_hora;
        END;
      
        -- Retornamos el objeto respuesta
        v_data.put('nroCuentaDebito',  v_nro_cta_debito);
        v_data.put('nroCuentaCredito', v_nro_cta_credito);
        v_data.put('importe',          v_importe);
        v_data.put('nroOperacion',     v_nro_operacion);
        v_data.put('tipoOperacion',    v_tip_operacion);
        v_data.put('nroTransaccion',   to_char(v_nro_lote_sue)||to_char(v_fec_actual,'DDMMYYYY')||replace(v_hora,':',''));
        v_data.put('nroLote',          v_nro_lote_ref);
        v_data.put('fechaOperacion',   v_fec_insercion);
        v_data.put('fechaProceso',     v_fec_actual);
        v_data.put('horaProceso',      v_hor_insercion);
  
    END IF;
    COMMIT;
    RETURN fu_obt_response(v_error,v_cod_respuesta, v_des_respuesta, v_data);    
 
END;