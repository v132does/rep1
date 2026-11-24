CREATE OR REPLACE PROCEDURE IT.prt_can_aut_paquetes IS
   v_fec_actual DATE := pag_cal.fu_obt_fec_actual(1);
   v_cantidad   NUMBER(3) := 0;
   
   CURSOR c_clientes IS         
      SELECT p.cod_paquete, p.cod_persona, p.nro_secuencia, p.nro_cuenta
        FROM ge_paq_clientes c, ge_paq_cuentas p, ge_par_dinamicos g 
        WHERE c.cod_paquete = p.cod_paquete
         AND c.estado = 'N'
         AND c.fec_final IS NULL
         AND c.fec_inicio > (v_fec_actual - 90)
         AND p.cod_paquete = c.cod_paquete
         AND p.cod_persona = c.cod_persona
         AND p.nro_secuencia = c.nro_secuencia
         AND p.cod_modulo = 5
         AND g.cod_modulo = p.cod_modulo
         AND g.cod_modalidad = p.cod_modalidad
         AND nvl(g.cod_sub_modalidad, '0') = nvl(p.cod_sub_modalidad, '0')
         AND g.parametro = 'CAN_PRO_PAQUETE'
         AND g.val_parametro > 0;
         
BEGIN
   FOR i IN c_clientes LOOP
      v_cantidad := 0;
      BEGIN
         SELECT COUNT(1)
           INTO v_cantidad
           FROM ta_cobros
          WHERE estado = 'P'
            AND observacion = 'Registro procesado'
            AND nro_cuenta = i.nro_cuenta
            AND fec_proceso BETWEEN (v_fec_actual - 90) AND v_fec_actual;
      EXCEPTION
         WHEN no_data_found THEN
            v_cantidad := 0;
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Error al consultar cantidad de Cobros:' || SQLERRM);
      END;
      IF v_cantidad = 0 THEN
         UPDATE ge_paq_clientes
            SET estado    = 'C', --Pasar a Estado Cancelado
                fec_final = v_fec_actual
          WHERE cod_paquete = i.cod_paquete
            AND cod_persona = i.cod_persona
            AND nro_secuencia = i.nro_secuencia;
         --Se inserta un registro en la tabla de novedades
         --para que se envien los parametros de tipo de tarjeta
         INSERT INTO ta_cta_tarjetas_nov
            (nro_cuenta, fecha, usu_insercion, fec_insercion, fec_modificacion, usu_modificacion, observacion)
         VALUES
            (i.nro_cuenta, v_fec_actual, substr(USER, 1, 10), SYSDATE, SYSDATE, substr(USER, 1, 10), 'Desvinculación de Paquete');
      END IF;
   END LOOP;
END;
/

