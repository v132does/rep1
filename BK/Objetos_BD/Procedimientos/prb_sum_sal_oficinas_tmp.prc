CREATE OR REPLACE PROCEDURE IT.prb_sum_sal_oficinas_tmp IS

-- Definición de Variables.
v_sal_mon_rub_ant   number := 0;
v_deb_mon_rubro     number := 0;
v_cre_mon_rubro     number := 0;
v_sal_equ_loc_ant   number := 0;
v_sal_equ_local     number := 0;
v_fec_actual        date        := pag_cal.fu_obt_fec_actual(1);
v_fec_anterior      date        := pag_cal.FU_OBT_FEC_ANT_HAB(v_fec_actual,null);
v_cod_mon_fuerte    varchar2(4) := pag_gen.fu_obt_mon_fuerte;
v_cod_mon_local     varchar2(4) := pag_gen.fu_obt_mon_local;

-- Cursores.
CURSOR c_cuentas IS
   SELECT a.cod_oficina, b.cod_rub_padre, b.cod_moneda,
      SUM(nvl(sal_mon_loc_ant,0)) sal_mon_loc_ant,
      SUM(nvl(deb_mon_local,0)) deb_mon_local,
      SUM(nvl(cre_mon_local,0)) cre_mon_local,
      SUM(nvl(sal_mon_rub_ant,0)) sal_mon_rub_ant,
      SUM(nvl(deb_mon_rubro,0)) deb_mon_rubro,
      SUM(nvl(cre_mon_rubro,0)) cre_mon_rubro,
      SUM(nvl(sal_equ_loc_ant,0)) sal_equ_loc_ant,
      SUM(nvl(deb_equ_local,0)) deb_equ_local,
      SUM(nvl(cre_equ_local,0)) cre_equ_local,
      SUM(nvl(mto_aju_cambiario,0)) mto_aju_cambiario
     FROM cb_sal_oficinas_tmp a,cb_rubros b
    WHERE a.cod_rubro = b.cod_rubro
      AND b.imputable = 'S'
      AND a.usu_insercion = user
    GROUP BY a.cod_oficina, b.cod_rub_padre, b.cod_moneda;

CURSOR c_act_sal_equivalente IS
   SELECT a.cod_oficina,
          b.cod_rubro,
          b.cod_moneda,
          NVL(sal_mon_rub_ant,0) sal_mon_rub_ant
     FROM cb_sal_oficinas_tmp a,cb_rubros b
    WHERE a.cod_rubro = b.cod_rubro
      AND b.imputable = 'S'
      AND b.cod_moneda != v_cod_mon_local
      AND a.usu_insercion = user;
      
CURSOR c_act_movimientos IS
   SELECT a.cod_oficina,
          b.cod_rubro,
          b.cod_moneda,
          NVL(a.sal_mon_rub_ant,0) + NVL(a.deb_mon_rubro,0) - NVL(a.cre_mon_rubro,0) sal_mon_rubro,
          NVL(a.sal_equ_loc_ant,0) sal_equ_local
     FROM cb_sal_oficinas_tmp a,cb_rubros b
    WHERE a.cod_rubro = b.cod_rubro
      AND b.imputable = 'S'
      AND b.cod_moneda != v_cod_mon_local
      AND a.usu_insercion = user;

-- Procedimientos.
PROCEDURE lp_sum_sal_oficinas(p_cod_oficina IN NUMBER,
                              p_cod_rub_padre IN CHAR,
                              p_sal_mon_loc_ant IN NUMBER,
                              p_deb_mon_local IN NUMBER,
                              p_cre_mon_local  IN NUMBER,
                              p_sal_mon_rub_ant IN NUMBER,
                              p_deb_mon_rubro IN NUMBER,
                              p_cre_mon_rubro IN NUMBER,
                              p_sal_equ_loc_ant IN NUMBER,
                              p_deb_equ_local IN NUMBER,
                              p_cre_equ_local IN NUMBER,
                              p_mto_aju_cambiario IN NUMBER) IS

  v_nro_cuenta    VARCHAR2(15);
  v_cod_rub_padre VARCHAR2(15);
  v_existe        VARCHAR2(01);
BEGIN
   SELECT cod_rubro, cod_rub_padre
     INTO v_nro_cuenta, v_cod_rub_padre
     FROM cb_rubros
    WHERE cod_rubro = p_cod_rub_padre;
       IF SQL%FOUND THEN <<CICLO>> LOOP
          BEGIN
             SELECT cod_rubro, cod_rub_padre
               INTO v_nro_cuenta, v_cod_rub_padre
               FROM cb_rubros
              WHERE cod_rubro = v_cod_rub_padre;

             IF SQL%FOUND THEN
                BEGIN
                   SELECT 'X' INTO v_existe
                     FROM cb_sal_oficinas_tmp
                    WHERE cod_oficina = p_cod_oficina
                      AND cod_rubro = v_nro_cuenta
                      AND usu_insercion = user
                      FOR UPDATE OF cod_rubro;
                EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                      INSERT INTO cb_sal_oficinas_tmp (cod_oficina, cod_rubro, fecha, usu_insercion) VALUES (p_cod_oficina, v_nro_cuenta, v_fec_actual, USER);
                   WHEN OTHERS THEN
                      RAISE_APPLICATION_ERROR(-20000,'Error al bloquear el rubro '||v_nro_cuenta||' - Ofic '||p_cod_oficina||' - '||sqlerrm);
                END;
                IF SQL%FOUND THEN
                   ----------------------------------------
                   UPDATE cb_sal_oficinas_tmp
                      SET sal_mon_loc_ant = nvl(sal_mon_loc_ant,0) + nvl(p_sal_mon_loc_ant,0),
                          deb_mon_local = nvl(deb_mon_local,0) + nvl(p_deb_mon_local,0),
                          cre_mon_local =  nvl(cre_mon_local,0) + nvl(p_cre_mon_local,0),
                          sal_mon_rub_ant = nvl(sal_mon_rub_ant,0) + nvl(p_sal_mon_rub_ant,0),
                          deb_mon_rubro = nvl(deb_mon_rubro,0) + nvl(p_deb_mon_rubro,0),
                          cre_mon_rubro = nvl(cre_mon_rubro,0) + nvl(p_cre_mon_rubro,0),
                          sal_equ_loc_ant = nvl(sal_equ_loc_ant,0) + nvl(p_sal_equ_loc_ant,0),
                          deb_equ_local = nvl(deb_equ_local,0) + nvl(p_deb_equ_local,0),
                          cre_equ_local = nvl(cre_equ_local,0) + nvl(p_cre_equ_local,0),
                          mto_aju_cambiario = nvl(mto_aju_cambiario,0) + nvl(p_mto_aju_cambiario,0)
                    WHERE cod_oficina = p_cod_oficina
                      AND cod_rubro = v_nro_cuenta
                      AND usu_insercion = user;
                END IF;
             END IF;
          EXCEPTION
             WHEN NO_DATA_FOUND THEN
                EXIT;
          END;
        END LOOP CICLO;
       END IF;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20000,'ERROR. Codigo de la Cuenta '||p_cod_rub_padre||' inexistente en Plan de Cuenta');
END;

-- Funciones.
FUNCTION FU_CON_MON_A_MONEDA(P_COD_MON_ORIGINAL IN BA_MONEDAS.COD_MONEDA%TYPE,
                             P_COD_MON_DESTINO IN BA_MONEDAS.COD_MONEDA%TYPE,
                             P_MTO_MON_ORIGINAL IN NUMBER,
                             P_COT_MON_ORIGINAL IN NUMBER DEFAULT NULL,
                             P_FECHA IN DATE DEFAULT NULL)
RETURN NUMBER
IS
   -- Variables.
   v_cod_mon_base     ba_monedas.cod_moneda%TYPE;
   v_mto_mon_destino  NUMBER;
   v_cot_mon_destino  NUMBER;
   v_cot_mon_original NUMBER := P_COT_MON_ORIGINAL;
   v_redondeo         NUMBER(2);
   v_lugar            VARCHAR2(100);
   v_fecha            DATE := P_FECHA;

BEGIN
    v_lugar := 'obtener moneda base';
    v_cod_mon_base  := pag_gen.fu_obt_mon_local();
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',NULL,NULL,p_cod_mon_destino);
    IF p_cod_mon_original = p_cod_mon_destino  THEN
       v_mto_mon_destino := P_mto_mon_original;
       IF p_cod_mon_original <> v_cod_mon_base THEN
          IF v_cot_mon_original is null and v_cot_mon_destino IS NOT NULL THEN
             v_cot_mon_original := v_cot_mon_destino;
          ELSIF v_cot_mon_original IS NULL THEN
             v_cot_mon_original := fug_obt_cotizacion(p_cod_mon_original);
          END IF;
          v_cot_mon_destino := v_cot_mon_original;
       ELSE
          v_cot_mon_destino := 1;
          v_cot_mon_original := 1;
       END IF;
    ELSE
       IF p_cod_mon_original <> v_cod_mon_base and p_cod_mon_destino = v_cod_mon_base THEN
          --convertir moneda original a base o destino
          v_fecha := NVL(v_fecha, PAG_CAL.FU_OBT_FEC_ACTUAL(1));
          IF v_cot_mon_original IS NULL THEN
             v_cot_mon_original := fug_obt_cotizacion(p_cod_mon_original, v_fecha);
          END IF;
          v_cot_mon_destino := 1;
          v_mto_mon_destino := round(p_mto_mon_original * v_cot_mon_original,v_redondeo);
       ELSIF p_cod_mon_original = v_cod_mon_base and p_cod_mon_destino <> v_cod_mon_base THEN
          -- pasar moneda original a moneda base
          IF v_cot_mon_destino IS NULL THEN
             v_cot_mon_destino := fug_obt_cotizacion(p_cod_mon_destino);
          END IF;
          v_cot_mon_original := 1;
          v_mto_mon_destino := ROUND(p_mto_mon_original/v_cot_mon_destino,v_redondeo);
       ELSIF p_cod_mon_original <> v_cod_mon_base and p_cod_mon_destino <> v_cod_mon_base THEN
          v_fecha := NVL(v_fecha, PAG_CAL.FU_OBT_FEC_ACTUAL(2));
          IF v_cot_mon_original IS NULL THEN
             v_cot_mon_original := fug_obt_cotizacion(p_cod_mon_original,v_fecha);
          END IF;
          v_mto_mon_destino := p_mto_mon_original * v_cot_mon_original;
          v_cot_mon_destino := fug_obt_cotizacion(p_cod_mon_destino,v_fecha);
          v_mto_mon_destino := ROUND(v_mto_mon_destino/v_cot_mon_destino,v_redondeo);
       END IF;
    END IF;
    --
    RETURN v_mto_mon_destino;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,v_lugar || ' - ' ||SQLERRM);
END;

-- Proceso Principal.
BEGIN
   -- cero todas las cuentas no imputables
   UPDATE cb_sal_oficinas_tmp a
      SET sal_mon_loc_ant = 0,
          deb_mon_local = 0,
          cre_mon_local = 0,
          sal_mon_rub_ant = 0,
          deb_mon_rubro = 0,
          cre_mon_rubro = 0,
          sal_equ_loc_ant = 0,
          deb_equ_local = 0,
          cre_equ_local = 0
    WHERE EXISTS (SELECT 0
                    FROM cb_rubros b
                   WHERE b.cod_rubro = a.cod_rubro
                     AND b.imputable = 'N')
             AND usu_insercion = user;

   -- Actualizo el importe equivalente de los saldos contables del dia anterior.
   FOR reg IN c_act_sal_equivalente LOOP
       --
       v_sal_equ_loc_ant  := fu_con_mon_a_moneda(reg.cod_moneda,v_cod_mon_local,reg.sal_mon_rub_ant,null,v_fec_anterior);
       --
       UPDATE cb_sal_oficinas_tmp
         SET sal_equ_loc_ant = v_sal_equ_loc_ant,
             sal_mon_loc_ant = sal_mon_loc_ant - (sal_mon_loc_ant - v_sal_equ_loc_ant)
       WHERE cod_rubro = reg.cod_rubro
         AND cod_oficina = reg.cod_oficina
         AND usu_insercion = user;

   END LOOP;
   
   FOR reg IN c_act_movimientos LOOP

       v_sal_equ_local         := fu_con_mon_a_moneda(reg.cod_moneda,v_cod_mon_local,reg.sal_mon_rubro,null,v_fec_actual);
       --
       UPDATE cb_sal_oficinas_tmp
         SET mto_aju_cambiario = NVL(v_sal_equ_local,0) - NVL(reg.sal_equ_local,0)
       WHERE cod_rubro = reg.cod_rubro
         AND cod_oficina = reg.cod_oficina
         AND usu_insercion = user;

   END LOOP;

   -- sumarizo las cuentas
   FOR reg IN c_cuentas LOOP

      v_sal_mon_rub_ant       := fu_con_mon_a_moneda(reg.cod_moneda,v_cod_mon_fuerte,reg.sal_mon_rub_ant,null,v_fec_actual);
      v_deb_mon_rubro         := fu_con_mon_a_moneda(reg.cod_moneda,v_cod_mon_fuerte,reg.deb_mon_rubro,null,v_fec_actual);
      v_cre_mon_rubro         := fu_con_mon_a_moneda(reg.cod_moneda,v_cod_mon_fuerte,reg.cre_mon_rubro,null,v_fec_actual);


      UPDATE cb_sal_oficinas_tmp
         SET sal_mon_loc_ant = sal_mon_loc_ant + reg.sal_mon_loc_ant,
             deb_mon_local = deb_mon_local + reg.deb_mon_local,
             cre_mon_local = cre_mon_local + reg.cre_mon_local,
             sal_mon_rub_ant = sal_mon_rub_ant + v_sal_mon_rub_ant,
             deb_mon_rubro = deb_mon_rubro + v_deb_mon_rubro,
             cre_mon_rubro = cre_mon_rubro + v_cre_mon_rubro,
             sal_equ_loc_ant = sal_equ_loc_ant + reg.sal_equ_loc_ant,
             deb_equ_local = deb_equ_local + reg.deb_equ_local,
             cre_equ_local = cre_equ_local + reg.cre_equ_local,
             mto_aju_cambiario = mto_aju_cambiario + reg.mto_aju_cambiario
       WHERE cod_rubro = reg.cod_rub_padre
         AND cod_oficina = reg.cod_oficina
         AND usu_insercion = user;

      -- actualizo los demas padres.
      lp_sum_sal_oficinas(reg.cod_oficina,
                          reg.cod_rub_padre,
                          reg.sal_mon_loc_ant ,
                          reg.deb_mon_local,
                          reg.cre_mon_local,
                          v_sal_mon_rub_ant,
                          v_deb_mon_rubro,
                          v_cre_mon_rubro,
                          reg.sal_equ_loc_ant,
                          reg.deb_equ_local,
                          reg.cre_equ_local,
                          reg.mto_aju_cambiario);

  END LOOP;
END;
/

