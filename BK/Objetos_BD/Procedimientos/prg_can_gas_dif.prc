create or replace PROCEDURE IT.prg_can_gas_dif (p_cod_cargo IN NUMBER) IS
    
 /* MJ 13-Jul-2026 
   Procedimiento lanzado por el TRG TRG_CB_GAS_DIFERIDOS cuando se cambia el estado de un gasto diferidos en asientos futuros 
   Se inserta un registro en cb_asientos que engloba el gasto cancelado
 */   
    
    PRAGMA AUTONOMOUS_TRANSACTION; --Transaccion autonoma por llamado de trigger
    v_gas_dif_tot_pendiente INT;
    v_cod_oficina           VARCHAR2(10); 
    v_nro_asiento           NUMBER;
    v_cod_modulo            VARCHAR2(10);
    v_cod_modalidad         VARCHAR2(10);
    v_cod_ofi_origen        VARCHAR2(10);
    v_ofi_integrada         VARCHAR2(1);
    v_confirmado            VARCHAR2(1);
    v_fecha                 DATE := pag_cal.fu_obt_fec_actual(2);
    
    
BEGIN 
    v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');

    SELECT cod_oficina, cod_modulo, cod_modalidad, 
           cod_ofi_origen, ofi_integrada, confirmado
    INTO   v_cod_oficina, v_cod_modulo, v_cod_modalidad, 
           v_cod_ofi_origen, v_ofi_integrada, v_confirmado
    FROM   CB_ASI_FUTUROS 
    WHERE COD_CARGO = p_cod_cargo
    AND ROWNUM = 1;


    SELECT SUM(TOT_CONTROL) 
    INTO v_gas_dif_tot_pendiente
    FROM CB_ASI_FUTUROS
    WHERE COD_CARGO = p_cod_cargo
    AND NRO_ASI_REAL IS NULL; 

    INSERT INTO CB_ASIENTOS (
                            FECHA, 
                            COD_OFICINA, 
                            NRO_ASIENTO, 
                            COD_USUARIO, 
                            COD_MODULO, 
                            COD_MODALIDAD, 
                            TOT_CONTROL, 
                            ACTUALIZADO, 
                            OFI_INTEGRADA, 
                            CONFIRMADO, 
                            COD_OFI_ORIGEN, 
                            COD_CARGO
                             )
                             
                     VALUES (
                            v_fecha, 
                            v_cod_oficina, 
                            v_nro_asiento, 
                            USER, 
                            v_cod_modulo, 
                            v_cod_modalidad, 
                            v_gas_dif_tot_pendiente, 
                            'S', 
                            v_ofi_integrada, 
                            v_confirmado, 
                            v_cod_ofi_origen, 
                            p_cod_cargo
                            );

    v_gas_dif_tot_pendiente := v_gas_dif_tot_pendiente / 2;

    INSERT INTO CB_ASIENTOS_DET (
                            fecha, 
                            cod_oficina, 
                            nro_asiento, 
                            nro_linea, 
                            cod_rubro, 
                            tip_movimiento, 
                            mto_mon_rubro, 
                            mto_mon_local, 
                            descripcion,
                            referencia, 
                            protegido, 
                            actualizado, 
                            val_cotizacion, 
                            distribuido, 
                            ref_movimiento, 
                            fec_valor, 
                            usu_insercion, 
                            fec_insercion, 
                            usu_modificacion, 
                            fec_modificacion
                            )
                            
                            
                            SELECT  
                                v_fecha,
                                d.cod_oficina,
                                v_nro_asiento,
                                d.nro_linea,
                                CASE d.tip_movimiento
                                    WHEN 'C' THEN d.rubro_original_d   
                                    WHEN 'D' THEN d.rubro_original_c    
                                    ELSE d.cod_rubro
                                END AS cod_rubro,
                                d.tip_movimiento,
                                d.mto_mon_rubro,
                                v_gas_dif_tot_pendiente,
                                d.descripcion,
                                d.referencia,
                                d.protegido,
                                'S',
                                d.val_cotizacion,
                                d.distribuido,
                                d.ref_movimiento,
                                d.fec_valor_fut,   
                                USER,
                                v_fecha,
                                USER,
                                v_fecha
                            FROM (
                                    SELECT d.*,
                                           f.fecha AS fec_valor_fut,
                                           MAX(CASE WHEN d.tip_movimiento = 'D' THEN d.cod_rubro END)  --Ventana para invertir cod_rubro en cancelaciones
                                               OVER (PARTITION BY d.cod_oficina, d.nro_asiento, d.fecha) AS rubro_original_d,
                                           MAX(CASE WHEN d.tip_movimiento = 'C' THEN d.cod_rubro END) 
                                               OVER (PARTITION BY d.cod_oficina, d.nro_asiento, d.fecha) AS rubro_original_c,
                                           ROW_NUMBER() OVER (PARTITION BY d.tip_movimiento ORDER BY d.nro_linea) AS rn
                                    FROM cb_asi_futuros_det d
                                    JOIN cb_asi_futuros f
                                        ON  f.cod_oficina  = d.cod_oficina
                                        AND f.nro_asiento  = d.nro_asiento
                                        AND f.fecha        = d.fecha
                                    WHERE f.cod_cargo      = p_cod_cargo
                                      AND f.nro_asi_real   IS NULL
                                      AND d.tip_movimiento IN ('D', 'C')
                                ) d
                            WHERE d.rn = 1;

    DELETE CB_ASI_FUTUROS 
    WHERE COD_CARGO = p_cod_cargo 
    AND NRO_ASI_REAL IS NULL;
      
    COMMIT;
      
    EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IT.PRG_INS_LOG_PROGRAMAS ( 
            p_cod_programa => 'PRG_CAN_GAS_DIF',
            p_det_error    => TO_CHAR(systimestamp) || ' - Error al cancelar gasto diferido : ' || p_cod_cargo || ' - ' || SQLERRM,
            p_cod_persona  => NULL,
            p_nro_cuenta   => NULL
        );
        RAISE;
END prg_can_gas_dif;
