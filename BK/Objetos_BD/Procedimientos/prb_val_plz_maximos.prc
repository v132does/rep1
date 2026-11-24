CREATE OR REPLACE PROCEDURE IT.prb_val_plz_maximos IS
   --Nuevo proceso de base de datos que se ejecutará en el cierre contable 
   --y que analizará los rubros que se encuentren con el indicador de Transitorio tildado ('S').

   v_fec_actual DATE := pag_cal.fu_obt_fec_actual(2);

   --cursor que obtiene los saldos de rubros transitorios
   CURSOR saldos IS
      SELECT nvl(c.sal_mon_loc_ant, 0) + (nvl(c.deb_mon_local, 0) - nvl(c.cre_mon_local, 0)) saldo_mon_local,
             nvl(c.sal_mon_rub_ant, 0) + (nvl(c.deb_mon_rubro, 0) - nvl(c.cre_mon_rubro, 0)) saldo_mon_extranjera,
             a.cod_rubro,
             a.plz_maximo
        FROM cb_rubros a, cb_sal_consolidados c
       WHERE a.cod_rubro = c.cod_rubro
         AND a.transitorio = 'S';
   --cursor que busca saldos anteriores y dias habiles transcurridos
   CURSOR plazos(p_cod_rubro IN VARCHAR2) IS
      SELECT a.cod_rubro,
             a.sal_mon_local,
             a.sal_mon_rubro,
             fuh_obt_dif_dias(a.fecha, trunc(v_fec_actual)) dias_habiles,
             a.fecha,
             a.plz_maximo
        FROM cb_rub_plz_maximos a
       WHERE a.cod_rubro = p_cod_rubro;

   --variable para dias de exceso
   v_dias_exceso NUMBER;

   --funcion que retorna true o false para actualizar o insertar en cb_rub_plz_maximos
   FUNCTION fp_existe_plz_maximos(p_cod_rubro IN VARCHAR2) RETURN BOOLEAN IS
      v_existe NUMBER := 0;
   BEGIN
      SELECT 1 INTO v_existe FROM cb_rub_plz_maximos a WHERE a.cod_rubro = p_cod_rubro;
      IF SQL%FOUND THEN
         RETURN TRUE;
      END IF;
      IF v_existe = 1 THEN
         RETURN TRUE;
      ELSIF v_existe = 0 THEN
         RETURN FALSE;
      END IF;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN FALSE;
      WHEN too_many_rows THEN
         RETURN TRUE;
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Error en fp_existe_plz_maximos ' || SQLERRM);
   END;

   --inicio
BEGIN
   FOR a IN saldos LOOP
      IF a.saldo_mon_local <> 0 OR a.saldo_mon_extranjera <> 0 THEN
         IF fp_existe_plz_maximos(a.cod_rubro) THEN
            FOR b IN plazos(a.cod_rubro) LOOP
            
               IF b.dias_habiles > b.plz_maximo THEN
                  v_dias_exceso := trunc(v_fec_actual) - (b.fecha + b.plz_maximo);
               ELSE
                  v_dias_exceso := 0;
               END IF;
            
               UPDATE cb_rub_plz_maximos
                  SET sal_mon_loc_anterior = b.sal_mon_local,
                      sal_mon_local        = a.saldo_mon_local,
                      sal_mon_rub_anterior = b.sal_mon_rubro,
                      sal_mon_rubro        = a.saldo_mon_extranjera,
                      dia_exceso           = v_dias_exceso,
                      plz_maximo           = a.plz_maximo
                WHERE cod_rubro = b.cod_rubro;
            
            END LOOP;
         ELSE
            INSERT INTO cb_rub_plz_maximos
               (cod_rubro, fecha, plz_maximo, dia_exceso, sal_mon_local, sal_mon_rubro)
            VALUES
               (a.cod_rubro, trunc(v_fec_actual), a.plz_maximo, 0, a.saldo_mon_local,
                a.saldo_mon_extranjera);
         
         END IF;
      ELSE
         IF fp_existe_plz_maximos(a.cod_rubro) THEN
            DELETE cb_rub_plz_maximos WHERE cod_rubro = a.cod_rubro;
         
         END IF;
      END IF;
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error en prb_act_rub_plz_maximos ' || SQLERRM);
END;
/

