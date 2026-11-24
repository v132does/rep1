CREATE OR REPLACE TRIGGER IT.AC_CB_GAS_DIFERIDOS
    AFTER UPDATE OF ESTADO ON CB_GAS_DIFERIDOS
    FOR EACH ROW
BEGIN
  
    IF :NEW.ESTADO = 'C' AND (:OLD.ESTADO IS NULL OR :OLD.ESTADO <> 'C') THEN
        
        BEGIN
            IT.prg_can_gas_dif(:NEW.COD_CARGO); 
            
        EXCEPTION
            WHEN OTHERS THEN
                IT.PRG_INS_LOG_PROGRAMAS ( 
                    p_cod_programa => 'TRG.AC_CB_GAS_DIFERIDOS',
                    p_det_error    => 'Error al disparar cancelacion del cargo: ' || :NEW.COD_CARGO || ' - ' || SQLERRM,
                    p_cod_persona  => 'MJ',
                    p_nro_cuenta   => NULL
                );
                RAISE;
        END;
        
    END IF;
END;
/ 
