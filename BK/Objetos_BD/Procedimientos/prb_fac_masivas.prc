CREATE OR REPLACE PROCEDURE IT.PRB_FAC_MASIVAS IS

    TYPE t_factura              IS TABLE OF it.cb_fac_masivas_tmp%ROWTYPE;
    TYPE t_lib_ventas_tab       IS TABLE OF cb_lib_ventas%ROWTYPE;
    TYPE t_lib_ventas_det_tab   IS TABLE OF cb_lib_ventas_det%ROWTYPE;
--
    v_facturas                  t_factura;
    v_lib_ventas_inserts        t_lib_ventas_tab := t_lib_ventas_tab();
    v_lib_ventas_det_inserts    t_lib_ventas_det_tab := t_lib_ventas_det_tab();
--
    v_nro_factura               cb_lib_ventas.nro_factura%TYPE;
    v_nro_timbrado              cb_lib_ventas.nro_timbrado%TYPE;
    v_fecha                     cb_lib_ventas.fecha%TYPE;
    v_nro_documento             cb_lib_ventas.nro_documento%TYPE;
    v_dig_verificador           cb_lib_ventas.dig_verificador%TYPE;
    v_fec_vig_timbrado          cb_lib_ventas.fec_vig_timbrado%TYPE;
    v_fec_aut_timbrado          cb_lib_ventas.fec_aut_timbrado%TYPE;
    v_lib_ventas_rec            cb_lib_ventas%ROWTYPE;
    v_lib_ventas_det_rec        cb_lib_ventas_det%ROWTYPE;
    v_tip_comprobante           VARCHAR2(1);
    v_cod_modulo                NUMBER := 2;
    v_cod_oficina               NUMBER(3) := nvl(fug_obt_pardinamico('COD_OFI_FAC_MANUAL', v_cod_modulo), 1);
    v_serie                     cb_lib_ventas.serie%TYPE;
    v_existe                    VARCHAR2(1);
    v_error_msg                 VARCHAR2(4000);
    v_cod_programa              VARCHAR2(30) := 'PRB_FAC_MASIVAS';
    v_per_mto_negativo          VARCHAR2(30); 
    v_msj_error_doc             VARCHAR2(1000);
    v_msj_ref                   VARCHAR2(1000);
    v_pun_expedicion            NUMBER(3) := NULL;
    v_es_ofi_generica           VARCHAR2(1) := NULL;
    v_error                     VARCHAR2(1000) := NULL; 
    v_codigo                    NUMBER := NULL;
    v_mon_local                 ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
    v_cod_mod_padre             NUMBER := 2;
    v_cod_mad_padre             NUMBER := 21;
    v_cod_tra_padre             NUMBER := 9999;
    v_gravada                   NUMBER;
    v_impuesto                  NUMBER;
    
    v_nro_fac_referencia        VARCHAR2(20);
    v_fec_fac_referencia        DATE;
    v_nro_tim_referencia        NUMBER;
    
    v_nro_secuencia             cb_lib_ventas_det.nro_secuencia%TYPE;
    r_fact                      it.cb_fac_masivas_tmp%ROWTYPE;
    
    v_cod_persona               cb_lib_ventas.cod_persona%type;
    v_nom_completo              cb_lib_ventas.nom_completo%type;
    v_direccion                 cb_lib_ventas.direccion%type;
    v_telefono                  cb_lib_ventas.telefono%type;
    v_tipo                      ba_personas.tipo%type;
    v_es_contribuyente          VARCHAR2(1) := NULL;
    
    PROCEDURE marcar_error (
        p_codigo_ref IN VARCHAR2)
    IS
    BEGIN
    
        UPDATE it.cb_fac_masivas_tmp
        SET estado = 'E'
        WHERE codigo = p_codigo_ref;
        
        COMMIT;
        
    END;

BEGIN
    
    v_per_mto_negativo := NVL(fug_obt_pardinamico('PER_MON_NEG_FAC_MANUAL'), 'N');
    
    SELECT *
    BULK COLLECT INTO v_facturas
    FROM it.cb_fac_masivas_tmp
    WHERE estado = 'P'
    ORDER BY codigo;
    
    
    v_codigo := null;

    FOR i IN 1 .. v_facturas.COUNT LOOP
       r_fact := v_facturas(i);
        
        v_error_msg         := NULL;
        v_msj_error_doc     := NULL;
        v_msj_ref           := NULL;
        
        --Cambio de factura
        IF r_fact.codigo != nvl(v_codigo, 0) THEN
            BEGIN
                v_codigo            := r_fact.codigo;
                v_tip_comprobante   := r_fact.tip_comprobante;
                v_fecha             := r_fact.fecha;
                v_dig_verificador   := null;
                
                BEGIN
                    SELECT cod_persona, nro_documento, nom_completo, fue_obt_dir_principa(cod_persona), fue_obt_tel_principa(cod_persona), tipo, decode(tip_iva, 'NC', 'N', 'CO', 'S', NULL, 'N')
                      INTO v_cod_persona, v_nro_documento, v_nom_completo, v_direccion, v_telefono, v_tipo, v_es_contribuyente
                      FROM ba_personas
                     WHERE nro_documento = r_fact.nro_documento;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        v_error_msg :=  v_error_msg ||'No hay un cliente con este número de documento: ' || v_nro_documento;
                        PRG_INS_LOG_PROGRAMAS(v_cod_programa,v_error_msg || '. Codigo = ' || r_fact.codigo || '.',null, null);
                        marcar_error(r_fact.codigo);  
                        CONTINUE;
                END;   
                
               
                IF v_tipo = 'J' THEN
                    v_msj_error_doc := fue_val_tip_doc_ruc(v_nro_documento);
                    IF v_msj_error_doc IS NOT NULL THEN
                        v_error_msg := v_error_msg || v_msj_error_doc || ' ';
                    ELSE
                        IF INSTR(v_nro_documento, '-') > 0 THEN
                            v_nro_documento := SUBSTR(v_nro_documento, 1, INSTR(v_nro_documento, '-')-1);
                            v_dig_verificador   := SUBSTR(v_nro_documento, -1);
                        ELSE
                            v_dig_verificador   := fue_obt_ruc_dig_verificador(v_nro_documento);
                        END IF;
                    END IF;
                END IF;
                
                --si es contribuyente se debe buscar el ruc - FIELDESK-161560
                IF  v_es_contribuyente = 'S' THEN 
                    IF INSTR(v_nro_documento, '-') > 0 THEN
                        v_nro_documento := SUBSTR(v_nro_documento, 1, INSTR(v_nro_documento, '-')-1);
                        v_dig_verificador   := SUBSTR(v_nro_documento, -1);
                    ELSE
                        v_dig_verificador   := fue_obt_ruc_dig_verificador(v_nro_documento);
                    END IF;
                END IF;
                
                -- PP_VALIDAR_NRO_FAC_REFERENCIA: Nro de factura de referencia 
                -- Obligatorio en notas de crédito/débito
                IF r_fact.tip_comprobante IN ('D','N') THEN
                    IF r_fact.nro_fac_referencia IS NULL THEN
                        v_error_msg := v_error_msg || 'Debes ingresar el Nro. de Factura Referencia.';
                    ELSE 
                        v_msj_ref := fub_val_for_nro_factura(r_fact.nro_fac_referencia);
                        IF v_msj_ref IS NOT NULL THEN
                            v_error_msg := v_error_msg || v_msj_ref || ' ';
                        END IF;
                    END IF;
                END IF;
                
                -- PP_VALIDAR_TIP_VENTA: Tipo de venta obligatorio en factura    
                IF r_fact.tip_comprobante = 'F' AND r_fact.tip_venta IS NULL THEN
                    v_error_msg := v_error_msg || 'Debes ingresar el Tipo de Venta. ';
                END IF;

                IF v_error_msg IS NOT NULL THEN --Validaciones si hubo algún error
                    PRG_INS_LOG_PROGRAMAS(v_cod_programa,v_error_msg || ' Codigo = ' || r_fact.codigo || '.',null, null);
                    marcar_error(r_fact.codigo); 
                    CONTINUE;
                END IF; 
                
                IF r_fact.tip_comprobante = 'N' THEN
                    BEGIN
                        SELECT nro_factura, fecha, nro_timbrado
                          INTO v_nro_fac_referencia, v_fec_fac_referencia, v_nro_tim_referencia
                          FROM cb_lib_ventas
                         WHERE nro_factura = r_fact.nro_fac_referencia
                           AND cod_persona = v_cod_persona;
                    EXCEPTION
                        WHEN no_data_found THEN
                            raise_application_error(-20001, 'No se encontro la factura de referencia.');
                        WHEN too_many_rows THEN
                            raise_application_error(-20001, 'Se encontro mas de una factura de referencia.');
                        WHEN OTHERS THEN
                            RAISE;
                    END;
                END IF;
            
            EXCEPTION
                WHEN OTHERS THEN
                    PRG_INS_LOG_PROGRAMAS(v_cod_programa,sqlerrm || ' Codigo = ' || r_fact.codigo || '.',null, null);
                    marcar_error(r_fact.codigo);
                    CONTINUE;
            END;
        END IF;
        
        BEGIN
            IF NVL(r_fact.iva, 'X') NOT IN ('E', '5', '10') THEN
                v_error_msg := v_error_msg || 'El iva debe ser Exento (E), 5% (5) o 10% (10). Valor actual: ' || r_fact.iva ;
            END IF;
            -- PP_VALIDAR_MONTO: Monto debe ser mayor a cero y sin decimales en moneda local
            IF v_per_mto_negativo = 'N' AND NVL(r_fact.valor_unitario, 0) <= 0 THEN
                v_error_msg := v_error_msg || 'Debe ingresar un monto mayor a cero.';
            END IF;
            
            IF r_fact.cod_moneda = pag_gen.fu_obt_mon_local THEN
                IF r_fact.valor_unitario <> TRUNC(r_fact.valor_unitario) THEN
                    v_error_msg := v_error_msg || 'Monto en moneda local no puede tener decimales.';
                END IF;
            END IF;
            
            -- PP_VALIDAR_TAS_IMPUESTO: Autofactura no puede tener IVA
            IF v_tip_comprobante = 'T' AND NVL(r_fact.iva, 'X') <> 'E' THEN
                v_error_msg := v_error_msg || 'El tipo de comprobante Autofactura no puede tener IVA.';
            END IF;    
            
            IF v_error_msg IS NOT NULL THEN
                PRG_INS_LOG_PROGRAMAS(v_cod_programa,v_error_msg || ' Codigo = ' || r_fact.codigo,null, null);
                marcar_error(r_fact.codigo);               
            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                PRG_INS_LOG_PROGRAMAS(v_cod_programa,v_error_msg,r_fact.codigo, null);
                marcar_error(r_fact.codigo);
        END;
    END LOOP;
    
    SELECT *
    BULK COLLECT INTO v_facturas
    FROM it.cb_fac_masivas_tmp
    WHERE estado = 'P'
    ORDER BY codigo;
    
    v_codigo := null;
    FOR i IN 1 .. v_facturas.COUNT LOOP
       r_fact := v_facturas(i);
        SAVEPOINT pre_factura;
        
        --Cambio de factura
        IF r_fact.codigo != nvl(v_codigo, 0) THEN
            BEGIN
                v_codigo            := r_fact.codigo;
                v_tip_comprobante   := r_fact.tip_comprobante;
                v_fecha             := r_fact.fecha;
                v_nro_factura 		:= NULL;
                v_dig_verificador   := NULL;
                
                BEGIN
                    SELECT cod_persona, nro_documento, nom_completo, fue_obt_dir_principa(cod_persona), fue_obt_tel_principa(cod_persona), tipo, decode(tip_iva, 'NC', 'N', 'CO', 'S', NULL, 'N')
                      INTO v_cod_persona, v_nro_documento, v_nom_completo, v_direccion, v_telefono, v_tipo, v_es_contribuyente
                      FROM ba_personas
                     WHERE nro_documento = r_fact.nro_documento;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        v_error_msg :=  v_error_msg ||'No hay un cliente con este número de documento: ' || v_nro_documento;
                        PRG_INS_LOG_PROGRAMAS(v_cod_programa,v_error_msg || '. Codigo = ' || r_fact.codigo || '.',null, null);
                        CONTINUE;
                END;   
                
                IF v_tipo = 'J' or v_es_contribuyente = 'S' THEN
                    IF INSTR(v_nro_documento, '-') > 0 THEN
                            v_nro_documento := SUBSTR(v_nro_documento, 1, INSTR(v_nro_documento, '-')-1);
                            v_dig_verificador   := SUBSTR(v_nro_documento, -1);
                    ELSE
                        v_dig_verificador   := fue_obt_ruc_dig_verificador(v_nro_documento);
                    END IF;
                END IF;
    
                --Pasó las validaciones iniciales
                
                -- Obtener número de factura
                pab_iva.pr_obt_nro_factura(
                    v_cod_oficina,
                    r_fact.fecha,
                    v_tip_comprobante,
                    v_nro_factura,
                    v_nro_timbrado,
                    v_fec_vig_timbrado
                );
                
                -- Punto de expedición
                prb_obt_pun_expedicion(v_tip_comprobante, v_cod_oficina, v_cod_modulo, v_pun_expedicion, v_es_ofi_generica, v_error);
                
                IF v_error IS NOT NULL THEN
                    PRG_INS_LOG_PROGRAMAS(v_cod_programa,v_error || ' Codigo = ' || r_fact.codigo || '.',null, null);
                    v_nro_factura := NULL;
                    v_error := NULL;
                    CONTINUE;
                END IF;
                
                -- Formar número de factura
                v_nro_factura := LPAD(fug_obt_pardinamico('COD_OFI_HACIENDA', NULL, NULL, NULL, v_cod_oficina), 3, '0') || '-' ||
                                 LPAD(v_pun_expedicion, 3, '0') || '-' ||
                                 LPAD(TO_CHAR(v_nro_factura), 7, '0');
                        
                -- Fecha de autorización del timbrado
                BEGIN
                
                    SELECT fec_ini_timbrado
                    INTO v_fec_aut_timbrado
                    FROM cb_par_comprobantes
                    WHERE nro_timbrado = v_nro_timbrado
                      AND tipo = v_tip_comprobante
                      AND cod_oficina = v_cod_oficina;
                      
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        v_fec_aut_timbrado := NULL;
                END;
                
                -- Si está activa facturación electrónica, debe tomar datos del timbrado definido para facturación electrónica  
                IF it.fug_obt_pardinamico('GE_ACT_FAC_ELECTRONICA') = 'S' THEN
                    v_serie := it.fug_obt_serie(v_tip_comprobante, v_cod_oficina, v_nro_timbrado);

                    BEGIN
                        SELECT 'S' INTO v_existe
                        FROM cb_lib_ventas
                        WHERE nro_factura = v_nro_factura
                          AND tip_comprobante = v_tip_comprobante
                          AND nro_timbrado = v_nro_timbrado
                          AND serie = v_serie
                          AND ROWNUM = 1;

                        IF NVL(v_existe,'N') = 'S' THEN
                            v_error_msg := 'La factura ya fue grabada con el mismo numero y misma serie, verifique: numero = ' || v_nro_factura || ', tipo = ' || v_tip_comprobante || ', timbrado = ' || v_nro_timbrado || '.';
                        END IF;

                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN NULL;
                        WHEN OTHERS THEN
                            v_error_msg := v_error_msg || 'Error al obtener datos timbrado facturación electrónica: ' || SQLERRM || ').';
                    END;
                ELSE
                    BEGIN
                         
                        SELECT 'S' INTO v_existe
                        FROM cb_lib_ventas
                        WHERE nro_factura = v_nro_factura
                          AND tip_comprobante = v_tip_comprobante
                          AND nro_timbrado = v_nro_timbrado
                          AND ROWNUM = 1;

                        IF NVL(v_existe,'N') = 'S' THEN
                            v_error_msg := 'La factura manual ya fue grabada, verifique: numero = ' || v_nro_factura || ', tipo = ' || v_tip_comprobante || ', timbrado = ' || v_nro_timbrado || '.';
                        END IF;

                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN NULL;
                        WHEN OTHERS THEN
                            v_error_msg := 'Error al obtener datos timbrado facturación manual: ' || SQLERRM || ').';
                    END;
                END IF;
                
                IF v_error_msg IS NOT NULL THEN
                    PRG_INS_LOG_PROGRAMAS(v_cod_programa,v_error_msg || ' Codigo = ' || r_fact.codigo || '.',null, null);
                    v_nro_factura := NULL;
                    v_error_msg := NULL;
                    CONTINUE;
                END IF; 
                
                --Se obtuvieron los datos necesarios para el insert de la Factura/Nota de Crédito
                -- Preparar registros para inserción masiva
                v_lib_ventas_rec.nro_factura        := v_nro_factura;
                v_lib_ventas_rec.nro_timbrado       := v_nro_timbrado;
                v_lib_ventas_rec.fecha              := v_fecha;
                v_lib_ventas_rec.cod_oficina        := v_cod_oficina;
                v_lib_ventas_rec.tip_comprobante    := v_tip_comprobante;
                v_lib_ventas_rec.tip_venta          := r_fact.tip_venta;
                IF r_fact.tip_venta = 'CR' THEN
                    v_lib_ventas_rec.can_cuota      := 1;
                END IF;
                v_lib_ventas_rec.cod_persona        := v_cod_persona;
                v_lib_ventas_rec.nom_completo       := v_nom_completo;
                v_lib_ventas_rec.nro_documento      := v_nro_documento;
                v_lib_ventas_rec.mto_exento         := 0;
                v_lib_ventas_rec.mto_gravado_5      := 0;
                v_lib_ventas_rec.mto_gravado_10     := 0;
                v_lib_ventas_rec.impuesto_5         := 0;
                v_lib_ventas_rec.impuesto_10        := 0;
                v_lib_ventas_rec.dig_verificador    := v_dig_verificador;
                v_lib_ventas_rec.impreso            := 'N';
                v_lib_ventas_rec.procesado          := 'N';
                v_lib_ventas_rec.direccion          := v_direccion;
                v_lib_ventas_rec.telefono           := v_telefono;
                v_lib_ventas_rec.fec_vig_timbrado   := v_fec_vig_timbrado;
                v_lib_ventas_rec.fec_aut_timbrado   := v_fec_aut_timbrado;
                v_lib_ventas_rec.cod_moneda         := r_fact.cod_moneda;
                v_lib_ventas_rec.serie              := v_serie;
                
                IF r_fact.tip_comprobante = 'N' THEN
                    BEGIN
                        SELECT nro_factura, fecha, nro_timbrado
                          INTO v_lib_ventas_rec.nro_fac_referencia, v_lib_ventas_rec.fec_fac_referencia, v_lib_ventas_rec.nro_tim_referencia
                          FROM cb_lib_ventas
                         WHERE nro_factura = r_fact.nro_fac_referencia
                           AND nro_timbrado = v_nro_timbrado
                           AND cod_persona = v_cod_persona;
                    EXCEPTION
                        WHEN no_data_found THEN
                            raise_application_error(-20001, 'No se encontro la factura de referencia.');
                        WHEN too_many_rows THEN
                            raise_application_error(-20001, 'Se encontro mas de una factura de referencia.');
                        WHEN OTHERS THEN
                            RAISE;
                    END;
                END IF;
                
                v_lib_ventas_rec.estado             := null;
                
                v_lib_ventas_inserts.EXTEND;
                v_lib_ventas_inserts(v_lib_ventas_inserts.COUNT) := v_lib_ventas_rec;
                
                v_nro_secuencia := 0;                
            
            EXCEPTION
                WHEN OTHERS THEN
                    PRG_INS_LOG_PROGRAMAS(v_cod_programa,sqlerrm || ' Codigo = ' || r_fact.codigo || '.',null, null);
                    v_nro_factura := NULL;
                    CONTINUE;
            END;
        END IF;
        
        IF v_nro_factura IS NULL THEN -- fallo algo en al procesar la cabecera (solo para casos de facturas con mas de un item)
            CONTINUE;
        END IF;
        
        BEGIN
            --Se obtuvieron los datos necesarios para el insert de la Factura/Nota de Crédito
            v_lib_ventas_det_rec                    := null;
            v_nro_secuencia                         := v_nro_secuencia + 1;
            v_lib_ventas_det_rec.fecha              := r_fact.fecha;
            v_lib_ventas_det_rec.hora               := to_char(sysdate, 'hh24:mi:ss');
            v_lib_ventas_det_rec.cod_usuario        := user;
            v_lib_ventas_det_rec.nro_secuencia      := v_nro_secuencia;
            v_lib_ventas_det_rec.nro_factura        := v_nro_factura;
            v_lib_ventas_det_rec.tip_comprobante    := v_tip_comprobante;
            v_lib_ventas_det_rec.nro_timbrado       := v_nro_timbrado;
            v_lib_ventas_det_rec.cod_ofi_origen     := v_cod_oficina;
            v_lib_ventas_det_rec.cod_mod_padre      := v_cod_mod_padre;
            v_lib_ventas_det_rec.cod_mad_padre      := v_cod_mad_padre;
            v_lib_ventas_det_rec.cod_tra_padre      := v_cod_tra_padre;
            v_lib_ventas_det_rec.nro_documento      := null;
            v_lib_ventas_det_rec.descripcion        := r_fact.descripcion;
            v_lib_ventas_det_rec.cod_moneda         := r_fact.cod_moneda;
            v_lib_ventas_det_rec.mto_exento         := 0;
            v_lib_ventas_det_rec.mto_exento_gs      := 0;
            v_lib_ventas_det_rec.mto_gravado_5      := 0;
            v_lib_ventas_det_rec.impuesto_5         := 0;
            v_lib_ventas_det_rec.mto_gra_5_gs       := 0;
            v_lib_ventas_det_rec.impuesto_5_gs      := 0;
            v_lib_ventas_det_rec.mto_gravado_10     := 0;
            v_lib_ventas_det_rec.impuesto_10        := 0;
            v_lib_ventas_det_rec.mto_gra_10_gs      := 0;
            v_lib_ventas_det_rec.impuesto_10_gs     := 0;
            
            IF r_fact.cod_moneda = v_mon_local then
                v_lib_ventas_det_rec.cotizacion   := 1;
            ELSE
                v_lib_ventas_det_rec.cotizacion   := fug_obt_cotizacion(r_fact.cod_moneda);
            END IF;
            
            IF r_Fact.iva = 'E' THEN
                v_lib_ventas_det_rec.mto_exento         := r_fact.cantidad * r_fact.valor_unitario;
                v_lib_ventas_det_rec.mto_exento_gs      := round(r_fact.cantidad * r_fact.valor_unitario * v_lib_ventas_det_rec.cotizacion);    
            ELSE
                v_impuesto  := r_fact.cantidad * r_fact.valor_unitario * TO_NUMBER(r_Fact.iva) / (100 + TO_NUMBER(r_Fact.iva));
                v_gravada   := (r_fact.cantidad * r_fact.valor_unitario) - v_impuesto;
                IF r_fact.cod_moneda = v_mon_local then
                    v_impuesto  := round(v_impuesto);
                    v_gravada   := round(v_gravada);
                ELSE
                    v_impuesto  := round(v_impuesto, 2);
                    v_gravada   := round(v_gravada, 2);
                END IF;                        
            END IF;
            
            IF r_Fact.iva = '5' THEN
                v_lib_ventas_det_rec.mto_gravado_5  := v_gravada;
                v_lib_ventas_det_rec.impuesto_5     := v_impuesto;
                v_lib_ventas_det_rec.mto_gra_5_gs   := round(v_gravada * v_lib_ventas_det_rec.cotizacion);
                v_lib_ventas_det_rec.impuesto_5_gs  := round(v_impuesto * v_lib_ventas_det_rec.cotizacion);   
            END IF;
            
            IF r_Fact.iva = '10' THEN
                v_lib_ventas_det_rec.mto_gravado_10 := v_gravada;
                v_lib_ventas_det_rec.impuesto_10    := v_impuesto;
                v_lib_ventas_det_rec.mto_gra_10_gs  := round(v_gravada * v_lib_ventas_det_rec.cotizacion);
                v_lib_ventas_det_rec.impuesto_10_gs := round(v_impuesto * v_lib_ventas_det_rec.cotizacion); 
            END IF;
            
            v_lib_ventas_det_rec.nro_cuenta       := null;
            v_lib_ventas_det_rec.aju_impuesto_5   := null;
            v_lib_ventas_det_rec.aju_impuesto_10  := null;
            v_lib_ventas_det_rec.tip_comprobante  := r_fact.tip_comprobante;
           
            v_lib_ventas_det_inserts.EXTEND;
            v_lib_ventas_det_inserts(v_lib_ventas_det_inserts.COUNT) := v_lib_ventas_det_rec;

            UPDATE it.cb_fac_masivas_tmp
            SET estado = 'T'
            WHERE codigo = r_fact.codigo;

        EXCEPTION
            WHEN OTHERS THEN
                PRG_INS_LOG_PROGRAMAS(v_cod_programa,v_error_msg || '. Codigo = ' || r_fact.codigo || '.',null, null);
                ROLLBACK TO pre_factura;
        END;
    END LOOP;

    -- Inserta las facturas OK --Cabecera
    IF v_lib_ventas_inserts.COUNT > 0 THEN
    
        FORALL i IN 1 .. v_lib_ventas_inserts.COUNT
            INSERT INTO cb_lib_ventas VALUES v_lib_ventas_inserts(i);
        
        FORALL i IN 1 .. v_lib_ventas_inserts.COUNT
            INSERT INTO cb_fac_masivas_his (fecha, nro_factura, fec_factura, tip_comprobante)VALUES (TRUNC(sysdate), v_lib_ventas_inserts(i).nro_factura, v_lib_ventas_inserts(i).fecha, v_lib_ventas_inserts(i).tip_comprobante);
            
    END IF;

    -- Inserta las facturas OK --Detalle
    IF v_lib_ventas_det_inserts.COUNT > 0 THEN
    
        FORALL i IN 1 .. v_lib_ventas_det_inserts.COUNT
            INSERT INTO cb_lib_ventas_det VALUES v_lib_ventas_det_inserts(i);
            
    END IF;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        PRG_INS_LOG_PROGRAMAS(v_cod_programa,SQLERRM,null, null);
END;
/
