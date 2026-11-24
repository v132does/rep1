CREATE OR REPLACE PROCEDURE it.PRB_OBT_PUN_EXPEDICION(
        p_tip_comprobante    IN  VARCHAR2,
        p_cod_oficina        IN  ba_oficinas.cod_oficina%TYPE DEFAULT NULL,
        p_cod_modulo         IN  ba_modulos.cod_modulo%TYPE DEFAULT NULL,
        p_pun_expedicion     OUT NUMBER,
        p_es_ofi_generica    OUT VARCHAR2,
        p_error              OUT VARCHAR2
    ) IS
        v_ofi_pto_generico ba_oficinas.cod_oficina%TYPE;
        
    BEGIN
    
        v_ofi_pto_generico  := fug_obt_pardinamico('CON_OFI_PTO_EXP_GENERICO', NULL, NULL, NULL, NULL);
        p_es_ofi_generica  := 'N';
        p_pun_expedicion    := NULL;
        p_error             := NULL;
    
        IF fug_obt_tip_implementacion = 1 THEN
            IF p_tip_comprobante = 'F' THEN
                p_pun_expedicion := fug_obt_pardinamico('PTO_EXP_FACTURA', p_cod_modulo, NULL, NULL, p_cod_oficina);
                IF p_pun_expedicion IS NULL THEN
                    p_pun_expedicion := fug_obt_pardinamico('PTO_EXP_FACTURA', p_cod_modulo, NULL, NULL, v_ofi_pto_generico);
                    p_es_ofi_generica := 'S';
                END IF;
    
            ELSIF p_tip_comprobante = 'N' THEN
                p_pun_expedicion := fug_obt_pardinamico('PTO_EXP_NOT_CREDITO', p_cod_modulo, NULL, NULL, p_cod_oficina);
                IF p_pun_expedicion IS NULL THEN
                    p_pun_expedicion := fug_obt_pardinamico('PTO_EXP_NOT_CREDITO', p_cod_modulo, NULL, NULL, v_ofi_pto_generico);
                    p_es_ofi_generica := 'S';
                END IF;
    
            ELSIF p_tip_comprobante = 'T' THEN
                p_pun_expedicion := fug_obt_pardinamico('PTO_EXP_AUTOFACTURA', NULL, NULL, NULL, p_cod_oficina);
                IF p_pun_expedicion IS NULL THEN
                    p_pun_expedicion := fug_obt_pardinamico('PTO_EXP_AUTOFACTURA', NULL, NULL, NULL, v_ofi_pto_generico);
                    p_es_ofi_generica := 'S';
                END IF;
    
            END IF;
    
        ELSE
            BEGIN
                SELECT TO_NUMBER(val_maximo)
                  INTO p_pun_expedicion
                  FROM ba_cod_referencias
                 WHERE dominio = 'TIP_COM_VENTA'
                   AND val_minimo = p_tip_comprobante;
            EXCEPTION
                WHEN OTHERS THEN
                    p_pun_expedicion := NULL;
                    p_es_ofi_generica := NULL;
                    p_error := 'Falta definir el punto de expedicion para el tipo de comprobante ' || p_tip_comprobante || ' en oficina: ' || p_cod_oficina;
            END;
        END IF;
    
        IF p_pun_expedicion IS NULL THEN
            p_pun_expedicion := NULL;
            p_es_ofi_generica := NULL;
            p_error := 'Falta definir el punto de expedicion para el tipo de comprobante ' || p_tip_comprobante || ' en oficina: ' || p_cod_oficina;
        END IF;
    
    EXCEPTION
        WHEN OTHERS THEN
            p_pun_expedicion := NULL;
            p_es_ofi_generica := NULL;
            p_error := 'Problema al obtener punto de expedición: ' || SQLERRM;
    END PRB_OBT_PUN_EXPEDICION;
    