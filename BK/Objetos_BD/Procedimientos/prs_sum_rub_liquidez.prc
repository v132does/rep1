CREATE OR REPLACE PROCEDURE it.prs_sum_rub_liquidez(p_fecha DATE DEFAULT NULL) IS
   v_cod_mon_fuerte ba_monedas.cod_moneda%TYPE ;
   v_cod_mon_local  ba_monedas.cod_moneda%TYPE ;
   v_fec_actual     ge_calendarios.fec_actual%TYPE;
   v_cod_grupo      cb_gru_rubros.cod_gru_rubro%TYPE;
   
   CURSOR cta IS
      SELECT fecha,
             a.cod_moneda,
             to_char(a.cod_cuenta) cod_cuenta,
             SUM(importe) importe,
             plazo,
             cod_rub_padre,
             c.cod_rubro,
             decode(a.cod_moneda,
                    '6100', 
                    v_cod_mon_fuerte, 
                    '6900', 
                    v_cod_mon_local
                    ) AS cod_mon
        FROM sb_liq_diarios a, cb_gru_rubros_det b, cb_rubros c
       WHERE to_char(a.cod_cuenta) = substr(b.cod_rubro, 1, 10)
         AND b.cod_rubro = c.cod_rubro
         AND a.cod_moneda = decode(b.cod_moneda, 'USD', 6100, 6900)
         AND b.cod_gru_rubro = v_cod_grupo
         AND fecha = v_fec_actual
       GROUP BY a.fecha, a.cod_moneda, cod_cuenta, plazo, cod_rub_padre, c.cod_rubro;
 
   BEGIN
      
      v_cod_mon_fuerte := pag_gen.fu_obt_mon_fuerte;
      v_cod_mon_local  := pag_gen.fu_obt_mon_local;
      v_cod_grupo      := fug_obt_pardinamico('GRU_RUB_LIQ_DIARIA');
      
      IF p_fecha IS NOT NULL THEN
         v_fec_actual := p_fecha;
      ELSE
         v_fec_actual := pag_cal.fu_obt_fec_actual(1);
      END IF;
      -- sumarizo las cuentas
      FOR reg IN cta LOOP
       
       BEGIN
      
          MERGE INTO sb_liq_diarios d
          USING (SELECT distinct a.cod_rubro AS cdcuent
                   FROM cb_rubros a
                   JOIN cb_gru_rubros_det b
                     ON a.cod_rubro      = b.cod_rubro  
                  WHERE b.cod_moneda     = reg.cod_mon 
                    AND b.cod_gru_rubro  = v_cod_grupo
                  START WITH a.cod_rubro =
                             (SELECT r.cod_rub_padre
                                FROM cb_rubros r
                                JOIN cb_gru_rubros_det rd
                                  ON r.cod_rubro      = rd.cod_rubro
                               WHERE rd.cod_rubro     = reg.cod_rubro
                                 AND rd.cod_moneda    = reg.cod_mon
                                 AND rd.cod_gru_rubro = v_cod_grupo
                              )
                              CONNECT BY PRIOR a.cod_rub_padre =  a.cod_rubro 
                              ) s
           ON (d.cod_cuenta   = (SUBSTR(s.cdcuent, 1, 10))   
          AND d.fecha         = v_fec_actual 
          AND d.cod_moneda    = reg.cod_moneda
          AND d.plazo         = reg.plazo )
          WHEN MATCHED THEN
            UPDATE SET d.importe = NVL(d.importe, 0) + NVL(reg.importe, 0)
          WHEN NOT MATCHED THEN
            INSERT
              (d.fecha, d.cod_cuenta, d.plazo, d.tipo, d.cod_moneda, d.importe)
            VALUES
              (
               v_fec_actual,
               SUBSTR(s.cdcuent, 1, 10),
               reg.plazo,
               'I',
               reg.cod_moneda,
               decode(reg.plazo, null, 0, nvl(reg.importe,0))
              );
       EXCEPTION
        WHEN OTHERS THEN
            raise_application_error(-20000, 'Error al procesar el rubro ' || reg.cod_cuenta || SQLERRM);
       END;
        
      END LOOP;
   EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000,'Error en ejecucion de prs_sum_rub_liquidez' || SQLERRM);  
   END;
/
