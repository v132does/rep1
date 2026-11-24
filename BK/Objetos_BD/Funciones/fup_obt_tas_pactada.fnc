CREATE OR REPLACE FUNCTION IT.fup_obt_tas_pactada
(
   p_nro_solicitud IN pr_solicitudes.nro_solicitud%TYPE,
   p_cod_modalidad IN pr_solicitudes.cod_modalidad%TYPE
) RETURN NUMBER IS
   v_tasa pr_sol_tasas.val_tasa%TYPE;
BEGIN
   DECLARE
      CURSOR tasas IS
         SELECT t.val_tasa
           FROM pr_sol_tasas t
          WHERE t.nro_solicitud = p_nro_solicitud
            AND fec_vigencia <=
                (SELECT fec_inicio FROM pr_solicitudes WHERE nro_solicitud = p_nro_solicitud)
         
         UNION ALL
         
         SELECT p.val_tasa
           FROM pr_sol_cargos p
          WHERE p.nro_solicitud = p_nro_solicitud
            AND p.cod_transaccion = fug_obt_pardinamico('COD_TRA_CAR_COMISION')
            AND fug_obt_tip_implementacion = 1
            AND fug_obt_pardinamico('MAD_ANT_EXPORTADOR') = p_cod_modalidad;
   BEGIN
      FOR x IN tasas LOOP
         BEGIN
            v_tasa := nvl(v_tasa, 0) + x.val_tasa;
         END;
      END LOOP;
      RETURN v_tasa;
   END;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'FUP_OBT_TAS_PACTADA ' || SQLERRM);
END;
/

