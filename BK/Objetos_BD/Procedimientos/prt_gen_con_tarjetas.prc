CREATE OR REPLACE PROCEDURE IT.prt_gen_con_tarjetas
(
   p_nro_mov_documento IN ta_det_conciliaciones.nro_mov_bancard%TYPE,
   p_fecha             IN ta_det_conciliaciones.fec_valor%TYPE,
   p_cod_ent_credito   IN ta_det_conciliaciones.cod_ent_credito%TYPE,
   p_monto             IN ta_det_conciliaciones.monto%TYPE,
   p_tip_conciliacion  IN ta_det_conciliaciones.tip_conciliacion%TYPE,
   p_conciliar         IN VARCHAR2 DEFAULT 'C'
) IS

   v_nro_conciliacion ge_movimientos.nro_conciliacion%TYPE;



BEGIN

   -- Inicializamos secuencia del Nro. de Conciliación
   v_nro_conciliacion := fue_obt_sig_secuencia('S_NRO_CON_PROCESADORA');

      BEGIN
         UPDATE cc_movimientos_his
            SET nro_conciliacion = CASE
                                      WHEN p_conciliar = 'C' THEN
                                       v_nro_conciliacion
                                      WHEN p_conciliar = 'D' THEN
                                       NULL
                                      ELSE
                                       v_nro_conciliacion
                                   END
          WHERE nro_documento3 = p_nro_mov_documento
            AND (cod_banco = p_cod_ent_credito OR nro_documento2 = p_cod_ent_credito)
            AND monto = p_monto
            AND cod_mod_padre = 9
            AND cod_mad_padre = 91
            AND cod_modalidad IN (42, 46)
            AND monto > 0
            AND (cod_banco IS NOT NULL OR nro_documento2 IS NOT NULL)
            AND nvl(nro_conciliacion, 1) > 0
            AND fec_valor = p_fecha;
      IF SQL%ROWCOUNT = 0 THEN
        begin
           UPDATE ge_movimientos
            SET nro_conciliacion = CASE
                                      WHEN p_conciliar = 'C' THEN
                                       v_nro_conciliacion
                                      WHEN p_conciliar = 'D' THEN
                                       NULL
                                      ELSE
                                       v_nro_conciliacion
                                   END
          WHERE nro_documento3 = p_nro_mov_documento
            AND fec_valor = p_fecha
            AND (cod_banco = p_cod_ent_credito OR nro_documento2 = p_cod_ent_credito)
            AND monto = p_monto
            AND cod_mod_padre = 9
            AND cod_mad_padre = 91
            AND cod_modalidad IN (42, 46)
            AND monto > 0
            AND (cod_banco IS NOT NULL OR nro_documento2 IS NOT NULL)
            AND nvl(nro_conciliacion, 1) > 0;
          EXCEPTION
               WHEN OTHERS THEN
                  -- Si no pudo actualizar la conciliación de forma automática, se realizará de forma manual.
                  NULL;
          END;
       END IF;


      EXCEPTION
         WHEN OTHERS THEN
            -- Si no pudo actualizar la conciliación de forma automática, se realizará de forma manual.
            NULL;
      END;

      BEGIN
         UPDATE ta_det_conciliaciones_his
            SET nro_conciliacion = CASE
                                      WHEN p_conciliar = 'C' THEN
                                       v_nro_conciliacion
                                      WHEN p_conciliar = 'D' THEN
                                       NULL
                                      ELSE
                                       v_nro_conciliacion
                                   END,
                tip_conciliacion = p_tip_conciliacion,
                fec_conciliacion = p_fecha
          WHERE nro_mov_bancard = p_nro_mov_documento
            AND EXISTS (SELECT 1
                   FROM cc_movimientos_his
                  WHERE nro_documento3 = p_nro_mov_documento
                    AND (cod_banco = p_cod_ent_credito OR nro_documento2 = p_cod_ent_credito)
                    AND monto = p_monto
                    AND cod_mod_padre = 9
                    AND cod_mad_padre = 91
                    AND cod_modalidad IN (42, 46)
                    AND monto > 0
                    AND (cod_banco IS NOT NULL OR nro_documento2 IS NOT NULL)
                    AND nvl(nro_conciliacion, 1) > 0)
                    AND fec_valor = p_fecha;
         IF SQL%ROWCOUNT = 0 THEN
            BEGIN
               UPDATE ta_det_conciliaciones
                  SET nro_conciliacion = CASE
                                            WHEN p_conciliar = 'C' THEN
                                             v_nro_conciliacion
                                            WHEN p_conciliar = 'D' THEN
                                             NULL
                                            ELSE
                                             v_nro_conciliacion
                                         END,
                      tip_conciliacion = p_tip_conciliacion,
                      fec_conciliacion = p_fecha
                WHERE nro_mov_bancard = p_nro_mov_documento
                  AND ((EXISTS
                (SELECT 1
                         FROM cc_movimientos_his
                        WHERE nro_documento3 = p_nro_mov_documento
                          AND (cod_banco = p_cod_ent_credito OR nro_documento2 = p_cod_ent_credito)
                          AND monto = p_monto
                          AND cod_mod_padre = 9
                          AND cod_mad_padre = 91
                          AND cod_modalidad IN (42, 46)
                          AND monto > 0
                          AND (cod_banco IS NOT NULL OR nro_documento2 IS NOT NULL)
                          AND nvl(nro_conciliacion, 1) > 0))
                   OR (EXISTS
                 (SELECT 1
                         FROM ge_movimientos
                        WHERE fec_valor = p_fecha
                          AND nro_documento3 = p_nro_mov_documento
                          AND (cod_banco = p_cod_ent_credito OR nro_documento2 = p_cod_ent_credito)
                          AND monto = p_monto
                          AND cod_mod_padre = 9
                          AND cod_mad_padre = 91
                          AND cod_modalidad IN (42, 46)
                          AND monto > 0
                          AND (cod_banco IS NOT NULL OR nro_documento2 IS NOT NULL)
                          AND nvl(nro_conciliacion, 1) > 0)));
            EXCEPTION
               WHEN OTHERS THEN
                  -- Si no pudo actualizar la conciliación de forma automática, se realizará de forma manual.
                  NULL;
            END;
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            -- Si no pudo actualizar la conciliación de forma automática, se realizará de forma manual.
            NULL;
      END;

EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE <= -20000 THEN
         RAISE;
      ELSE
         raise_application_error(-20999,
                                 'Error al intentar generar automáticamente la conciliación de tarjetas: ' ||
                                  SQLERRM);
      END IF;
END;
/

