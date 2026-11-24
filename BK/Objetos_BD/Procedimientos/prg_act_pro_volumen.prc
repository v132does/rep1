CREATE OR REPLACE PROCEDURE IT.PRG_ACT_PRO_VOLUMEN
AS
    v_nro_secuencia NUMBER(12);
    v_hor_inicio  VARCHAR2(10);
    v_hor_fin  VARCHAR2(10);
    v_men_error VARCHAR2(400);
BEGIN
    -- Bucle para recorrer la vista --
    FOR rec IN (
        SELECT fecha,
               cod_programa,
               cantidad
          FROM gv_pro_volumenes
    )
    LOOP
        BEGIN
            -- Actualiza los registros en ge_procesos_det_his --
            v_nro_secuencia := NVL(v_nro_secuencia, 0) + 1;
            v_hor_inicio := TO_CHAR(SYSDATE, 'hh24:mi:ss');

            UPDATE ge_procesos_det_his t
               SET t.volumen = rec.cantidad
             WHERE t.cod_programa = rec.cod_programa
               AND t.fecha = rec.fecha;

        EXCEPTION
            WHEN OTHERS THEN
                v_men_error := SQLERRM;
                v_nro_secuencia := NVL(v_nro_secuencia, 0) + 1;
                v_hor_fin := TO_CHAR(SYSDATE, 'hh24:mi:ss');
                PRG_ACT_LOG_PROCESOS('PRG_ACT_PRO_VOLUMEN', v_nro_secuencia, TRUNC(SYSDATE), v_hor_inicio, v_hor_fin,
                                     'Error al actualizar cod_programa: ' || rec.cod_programa || ' - ' || v_men_error);
        END;
    END LOOP;

     COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        v_men_error := SQLERRM;
        v_nro_secuencia := NVL(v_nro_secuencia, 0) + 1;
        v_hor_fin := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        PRG_ACT_LOG_PROCESOS('PRG_ACT_PRO_VOLUMEN', v_nro_secuencia, TRUNC(SYSDATE), v_hor_inicio, v_hor_fin, 'Error general del procedimiento: ' || v_men_error);
END PRG_ACT_PRO_VOLUMEN;
